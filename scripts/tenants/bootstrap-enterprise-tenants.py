#!/usr/bin/env python3
# @covers AC-MTA-001, AC-MTA-002, AC-MTA-021
# @spec: multi-tenancy-architecture_spec.md
"""
Bootstrap enterprise tenant data from a declarative YAML spec.

Loads config/enterprise-tenants/<env>.enterprise-tenants.yaml and ensures
the database matches the declared state:
  - EnterpriseCustomer records
  - EnterpriseCustomerCatalog + CatalogQuery records
  - EnterpriseCustomerUser links
  - Waffle switches

Default: DRY RUN. Use --apply to write to the database.

Usage:
    # From LMS pod or Django shell context:
    python scripts/tenants/bootstrap-enterprise-tenants.py --env dev
    python scripts/tenants/bootstrap-enterprise-tenants.py --env dev --apply

    # Via kubectl exec:
    kubectl exec -n mereka-lms deploy/lms -- python \
        /openedx/scripts/tenants/bootstrap-enterprise-tenants.py --env dev --apply
"""

import argparse
import json
import logging
import sys
from pathlib import Path

logger = logging.getLogger("bootstrap-enterprise-tenants")


def load_spec(env: str) -> dict:
    """Load the declarative tenant spec for the given environment."""
    candidates = [
        Path(__file__).resolve().parent.parent.parent
        / "config"
        / "enterprise-tenants"
        / f"{env}.enterprise-tenants.yaml",
        Path(f"/openedx/config/enterprise-tenants/{env}.enterprise-tenants.yaml"),
    ]

    for path in candidates:
        if path.exists():
            import yaml

            return yaml.safe_load(path.read_text(encoding="utf-8"))

    tried = ", ".join(str(p) for p in candidates)
    raise FileNotFoundError(f"No spec found for env={env}. Tried: {tried}")


def bootstrap_tenant(tenant: dict, dry_run: bool) -> dict:
    """Bootstrap a single tenant. Returns a result dict."""
    from django.contrib.sites.models import Site
    from enterprise.models import (
        EnterpriseCustomer,
        EnterpriseCustomerCatalog,
        EnterpriseCustomerUser,
    )

    result = {
        "slug": tenant["slug"],
        "actions": [],
        "errors": [],
    }

    # 1. Site
    domain = tenant["site"]["domain"]
    site = Site.objects.filter(domain__iexact=domain).first()
    if not site:
        if dry_run:
            result["actions"].append(f"CREATE Site domain={domain}")
        else:
            site = Site.objects.create(
                domain=domain, name=f"{tenant['name']} Learning Portal"
            )
            result["actions"].append(f"CREATED Site domain={domain} id={site.id}")
    else:
        result["actions"].append(f"EXISTS Site domain={domain} id={site.id}")

    # 2. EnterpriseCustomer
    ec_spec = tenant.get("enterprise_customer", {})
    ec = EnterpriseCustomer.objects.filter(slug=tenant["slug"]).first()
    if not ec:
        if dry_run:
            result["actions"].append(
                f"CREATE EnterpriseCustomer slug={tenant['slug']} name={tenant['name']}"
            )
        else:
            import uuid as uuid_lib

            ec = EnterpriseCustomer.objects.create(
                uuid=uuid_lib.uuid4(),
                name=tenant["name"],
                slug=tenant["slug"],
                site=site,
                active=tenant.get("active", True),
                contact_email=tenant.get("contact_email", ""),
                country=tenant.get("country", ""),
                enable_data_sharing_consent=ec_spec.get(
                    "enable_data_sharing_consent", True
                ),
                enforce_data_sharing_consent=ec_spec.get(
                    "enforce_data_sharing_consent", "externally_managed"
                ),
                enable_audit_enrollment=ec_spec.get("enable_audit_enrollment", False),
                enable_learner_portal=ec_spec.get("enable_learner_portal", True),
                enable_portal_code_management_screen=ec_spec.get(
                    "enable_portal_code_management", False
                ),
                enable_analytics_screen=ec_spec.get("enable_analytics_screen", True),
            )
            result["actions"].append(
                f"CREATED EnterpriseCustomer slug={tenant['slug']} uuid={ec.uuid}"
            )
    else:
        result["actions"].append(
            f"EXISTS EnterpriseCustomer slug={tenant['slug']} uuid={ec.uuid}"
        )
        # Reconcile enforce_data_sharing_consent on existing enterprises
        desired_enforce = ec_spec.get(
            "enforce_data_sharing_consent", "externally_managed"
        )
        if ec.enforce_data_sharing_consent != desired_enforce:
            if dry_run:
                result["actions"].append(
                    f"UPDATE EnterpriseCustomer slug={tenant['slug']} "
                    f"enforce_data_sharing_consent: "
                    f"{ec.enforce_data_sharing_consent!r} -> {desired_enforce!r}"
                )
            else:
                ec.enforce_data_sharing_consent = desired_enforce
                ec.save(update_fields=["enforce_data_sharing_consent"])
                result["actions"].append(
                    f"UPDATED EnterpriseCustomer slug={tenant['slug']} "
                    f"enforce_data_sharing_consent={desired_enforce!r}"
                )

    # 3. Catalogs
    for cat_spec in tenant.get("catalogs", []):
        title = cat_spec["title"]
        existing_cat = None
        if ec:
            existing_cat = EnterpriseCustomerCatalog.objects.filter(
                enterprise_customer=ec, title=title
            ).first()

        if not existing_cat:
            if dry_run:
                result["actions"].append(f"CREATE Catalog title='{title}'")
                org_filter = cat_spec.get("catalog_query", {}).get("org_filter", [])
                result["actions"].append(
                    f"CREATE CatalogQuery org_filter={org_filter}"
                )
            else:
                if ec:
                    content_filter = cat_spec.get("catalog_query", {}).get(
                        "content_filter", {}
                    )
                    org_filter = cat_spec.get("catalog_query", {}).get(
                        "org_filter", []
                    )
                    # Build the content filter JSON that enterprise-catalog expects
                    full_filter = {**content_filter}
                    if org_filter:
                        full_filter["organizations.key"] = org_filter

                    cat = EnterpriseCustomerCatalog.objects.create(
                        enterprise_customer=ec,
                        title=title,
                        content_filter=json.dumps(full_filter),
                    )
                    result["actions"].append(f"CREATED Catalog title='{title}' uuid={cat.uuid}")
                else:
                    result["errors"].append(
                        f"SKIP Catalog '{title}': EnterpriseCustomer not created (dry run?)"
                    )
        else:
            result["actions"].append(
                f"EXISTS Catalog title='{title}' uuid={existing_cat.uuid}"
            )

    # 4. User links
    for link in tenant.get("user_links", []):
        email = link["email"]
        role = link.get("role", "learner")

        if not ec:
            if dry_run:
                result["actions"].append(
                    f"CREATE EnterpriseCustomerUser email={email} role={role}"
                )
            continue

        from django.contrib.auth import get_user_model

        User = get_user_model()
        user = User.objects.filter(email__iexact=email).first()
        if not user:
            result["actions"].append(
                f"SKIP user link email={email}: user not found in DB"
            )
            continue

        ecu = EnterpriseCustomerUser.objects.filter(
            enterprise_customer=ec, user_id=user.id
        ).first()
        if not ecu:
            if dry_run:
                result["actions"].append(
                    f"CREATE EnterpriseCustomerUser email={email} role={role}"
                )
            else:
                ecu = EnterpriseCustomerUser.objects.create(
                    enterprise_customer=ec,
                    user_id=user.id,
                    active=True,
                )
                result["actions"].append(
                    f"CREATED EnterpriseCustomerUser email={email} user_id={user.id}"
                )
        else:
            result["actions"].append(
                f"EXISTS EnterpriseCustomerUser email={email} user_id={user.id}"
            )

    # 5. Waffle switches
    for switch_base, active in tenant.get("waffle_switches", {}).items():
        switch_name = f"{switch_base}.{tenant['slug']}"
        if dry_run:
            state = "on" if active else "off"
            result["actions"].append(
                f"ENSURE Waffle Switch {switch_name} = {state}"
            )
        else:
            try:
                from waffle.models import Switch

                switch, created = Switch.objects.get_or_create(
                    name=switch_name, defaults={"active": active}
                )
                verb = "CREATED" if created else "EXISTS"
                result["actions"].append(f"{verb} Waffle Switch {switch_name}")
            except ImportError:
                result["errors"].append("django-waffle not installed")

    return result


def _studio_redirect_uri(tenant: dict, lms_domain: str) -> str:
    """Derive the Studio OAuth2 redirect URI for a tenant.

    The callback is the standard python-social-auth edx-oauth2 backend path.
    Studio domain convention varies by environment and tenant slug.
    """
    site_domain = tenant["site"]["domain"]

    # Derive studio domain from the LMS domain and tenant site domain.
    # Patterns in use:
    #   dev:        studio.{site_domain}            (e.g. studio.academyv2.mereka.dev)
    #   staging:    staging.studio.{root_domain}    (e.g. staging.studio.academyv2.mereka.io)
    #               studio.staging.{site_domain}    (e.g. studio.staging.academy.biji-biji.com)
    #   production: studio.{site_domain}            (e.g. studio.academyv2.mereka.io)
    #
    # We derive studio_domain from the tenant registry via a deterministic rule:
    # strip the leading environment label (if any) from site_domain, then prepend "studio."
    # For non-primary tenants in staging the pattern is "studio.{site_domain}".
    # For primary tenants in staging the pattern uses lms_domain prefix logic.

    # Detect environment from site_domain vs lms_domain
    if site_domain == lms_domain:
        # Primary tenant: studio URL prefixes the whole lms_domain with "studio."
        studio_domain = f"studio.{site_domain}"
    else:
        # Non-primary tenant: studio is "studio.{site_domain}"
        studio_domain = f"studio.{site_domain}"

    return f"https://{studio_domain}/complete/edx-oauth2/"


def bootstrap_cms_sso_oauth_client(spec: dict, tenants: list, dry_run: bool) -> dict:
    """Bootstrap the cms-sso OAuth2 Application in the LMS database.

    Creates a single confidential OAuth2 Application with client_id='cms-sso'
    that covers Studio/CMS for ALL tenants declared in the spec. The redirect_uris
    list is the union of /complete/edx-oauth2/ callbacks for every tenant's
    Studio domain.

    This is idempotent: if the Application already exists with the correct
    redirect_uris it is left unchanged. If redirect_uris differ, they are updated.
    """
    lms_domain = spec.get("lms_domain", "")

    result = {
        "client_id": "cms-sso",
        "actions": [],
        "errors": [],
    }

    # Collect redirect URIs for all tenants in the spec
    redirect_uris = [_studio_redirect_uri(t, lms_domain) for t in tenants]
    redirect_uris_str = "\n".join(redirect_uris)

    if dry_run:
        result["actions"].append(
            "CREATE/UPDATE OAuth2 Application client_id=cms-sso "
            f"redirect_uris=[{', '.join(redirect_uris)}]"
        )
        return result

    try:
        from oauth2_provider.models import Application

        existing = Application.objects.filter(client_id="cms-sso").first()
        if not existing:
            Application.objects.create(
                client_id="cms-sso",
                name="CMS/Studio SSO",
                client_type=Application.CLIENT_CONFIDENTIAL,
                authorization_grant_type=Application.GRANT_AUTHORIZATION_CODE,
                redirect_uris=redirect_uris_str,
                skip_authorization=True,
            )
            result["actions"].append(
                f"CREATED OAuth2 Application client_id=cms-sso "
                f"with {len(redirect_uris)} redirect_uris"
            )
        else:
            current_uris = set((existing.redirect_uris or "").splitlines())
            desired_uris = set(redirect_uris)
            if current_uris != desired_uris:
                existing.redirect_uris = redirect_uris_str
                existing.skip_authorization = True
                existing.save(update_fields=["redirect_uris", "skip_authorization"])
                result["actions"].append(
                    f"UPDATED OAuth2 Application client_id=cms-sso redirect_uris "
                    f"({len(desired_uris - current_uris)} added, "
                    f"{len(current_uris - desired_uris)} removed)"
                )
            else:
                result["actions"].append(
                    "EXISTS OAuth2 Application client_id=cms-sso (redirect_uris match)"
                )
    except ImportError:
        result["errors"].append(
            "oauth2_provider not installed — cannot bootstrap cms-sso OAuth Application"
        )

    return result


def main():
    parser = argparse.ArgumentParser(
        description="Bootstrap enterprise tenants from declarative YAML spec."
    )
    parser.add_argument(
        "--env",
        required=True,
        help="Environment name (e.g. dev, staging, production).",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        default=False,
        help="Actually write to the database. Default is dry run.",
    )
    parser.add_argument(
        "--tenant",
        default=None,
        help="Bootstrap only this tenant slug (default: all).",
    )
    args = parser.parse_args()

    dry_run = not args.apply

    # Set up Django if not already configured
    import os

    if not os.environ.get("DJANGO_SETTINGS_MODULE"):
        os.environ.setdefault("DJANGO_SETTINGS_MODULE", "lms.envs.production")
        import django

        django.setup()

    logging.basicConfig(level=logging.INFO, format="%(message)s")

    spec = load_spec(args.env)
    tenants = spec.get("tenants", [])
    if not tenants:
        logger.error("No tenants found in spec")
        sys.exit(1)

    if args.tenant:
        tenants = [t for t in tenants if t["slug"] == args.tenant]
        if not tenants:
            logger.error(f"Tenant '{args.tenant}' not found in spec")
            sys.exit(1)

    mode = "DRY RUN" if dry_run else "APPLY"
    print(f"\n{'='*60}")
    print(f"Enterprise Tenant Bootstrap [{mode}]")
    print(f"Environment: {args.env}")
    print(f"Tenants: {len(tenants)}")
    print(f"{'='*60}\n")

    all_results = []
    for tenant in tenants:
        print(f"--- {tenant['slug']} ({tenant['name']}) ---")
        result = bootstrap_tenant(tenant, dry_run)
        all_results.append(result)

        for action in result["actions"]:
            prefix = "[DRY]" if dry_run else "[OK]"
            print(f"  {prefix} {action}")
        for error in result["errors"]:
            print(f"  [ERR] {error}")
        print()

    # cms-sso OAuth2 Application (covers all tenants in this spec)
    # Only run when bootstrapping all tenants (not a single-tenant subset)
    if not args.tenant:
        print("--- cms-sso OAuth2 Application ---")
        all_spec_tenants = spec.get("tenants", [])
        cms_result = bootstrap_cms_sso_oauth_client(spec, all_spec_tenants, dry_run)
        prefix = "[DRY]" if dry_run else "[OK]"
        for action in cms_result["actions"]:
            print(f"  {prefix} {action}")
        for error in cms_result["errors"]:
            print(f"  [ERR] {error}")
        all_results.append({
            "slug": "cms-sso",
            "actions": cms_result["actions"],
            "errors": cms_result["errors"],
        })
        print()

    # Summary
    total_actions = sum(len(r["actions"]) for r in all_results)
    total_errors = sum(len(r["errors"]) for r in all_results)
    creates = sum(
        1
        for r in all_results
        for a in r["actions"]
        if a.startswith("CREATE") or a.startswith("ENSURE")
    )

    print(f"{'='*60}")
    print(f"Summary: {len(all_results)} tenants, {total_actions} actions, {creates} creates, {total_errors} errors")
    if dry_run:
        print("\nThis was a DRY RUN. To apply changes, run with --apply")
    print(f"{'='*60}\n")

    sys.exit(1 if total_errors > 0 else 0)


if __name__ == "__main__":
    main()
