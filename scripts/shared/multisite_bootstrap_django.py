#!/usr/bin/env python3
"""Bootstrap django.contrib.sites + SiteConfiguration entries for multi-tenant LMS domains.

This version uses Django ORM instead of PyMySQL for better compatibility with LMS pods.
"""

from __future__ import annotations

import os
import sys
import textwrap
from dataclasses import dataclass
from urllib.parse import urlparse


@dataclass(frozen=True)
class SiteDefinition:
    domain: str
    name: str
    orgs: list[str]
    site_values: dict[str, object]


REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_DEFINITIONS_PATH = os.path.join(REPO_ROOT, "infrastructure", "tutor", "multisite-sites.yml")
DEFAULT_SHARED_HOST_ALLOWLIST_PATH = os.path.join(
    REPO_ROOT, "infrastructure", "tutor", "multisite-shared-host-allowlist.txt"
)


def _load_yaml(path: str) -> dict:
    try:
        import yaml  # type: ignore
    except Exception as exc:  # pragma: no cover
        raise RuntimeError("PyYAML is required to load multisite-sites.yml") from exc
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def load_definitions() -> tuple[list[dict], list[SiteDefinition]]:
    """
    Load org + site definitions from infrastructure/tutor/multisite-sites.yml.

    The pod runner (`scripts/infra/apply-multisite-config.sh`) copies the YAML to
    a temp path and sets MULTISITE_DEFINITIONS_PATH accordingly.
    """
    path = os.environ.get("MULTISITE_DEFINITIONS_PATH") or DEFAULT_DEFINITIONS_PATH
    payload = _load_yaml(path)

    orgs = payload.get("organizations") or []
    sites = payload.get("sites") or []
    definitions: list[SiteDefinition] = []
    for s in sites:
        domain = (s or {}).get("domain") or ""
        name = (s or {}).get("name") or domain
        org_list = (s or {}).get("orgs") or []
        site_values = (s or {}).get("site_values") or {}
        if not domain:
            continue
        definitions.append(
            SiteDefinition(
                domain=domain,
                name=name,
                orgs=list(org_list),
                site_values=dict(site_values),
            )
        )

    return list(orgs), definitions


def hero_html(*, eyebrow: str, heading: str, body: str, primary_label: str, primary_href: str, secondary_label: str, secondary_href: str, accent: str, background: str) -> str:
    return textwrap.dedent(
        f"""
        <section class=\"site-hero\" style=\"background:{background};color:{accent};padding:3rem;border-radius:1.5rem;text-align:center;box-shadow:0 30px 80px rgba(15,23,42,.25);\">
          <p style=\"letter-spacing:.3em;text-transform:uppercase;font-weight:600;margin-bottom:1rem;color:{accent};\">{eyebrow}</p>
          <h1 style=\"margin-bottom:1rem;font-size:2.5rem;color:#fff;\">{heading}</h1>
          <p style=\"max-width:640px;margin:0 auto 2rem;color:#f4f4f5;\">{body}</p>
          <div style=\"display:flex;gap:1rem;justify-content:center;flex-wrap:wrap;\">
            <a href=\"{primary_href}\" style=\"background:{accent};color:#0f172a;padding:.85rem 1.75rem;border-radius:999px;font-weight:600;\">{primary_label}</a>
            <a href=\"{secondary_href}\" style=\"border:2px solid {accent};color:{accent};padding:.75rem 1.5rem;border-radius:999px;font-weight:600;\">{secondary_label}</a>
          </div>
        </section>
        """
    ).strip()


ORGANIZATIONS, SITE_DEFINITIONS = load_definitions()
OIDC_PROVIDER_DISPLAY_NAME = os.environ.get("OIDC_PROVIDER_DISPLAY_NAME", "Sign in with Mereka")


def _extract_host(url_or_host: object) -> str:
    value = str(url_or_host or "").strip()
    if not value:
        return ""
    parsed = urlparse(value if "://" in value else f"https://{value}")
    return (parsed.netloc or parsed.path or "").strip().lower()


def _load_shared_host_allowlist() -> set[str]:
    """
    Optional allowlist for temporary shared hosts.

    Sources:
      - MULTISITE_SHARED_HOST_ALLOWLIST: comma-separated hosts
      - MULTISITE_SHARED_HOST_ALLOWLIST_FILE: newline-separated hosts, '#' comments allowed
    """
    allowed: set[str] = set()
    inline = os.environ.get("MULTISITE_SHARED_HOST_ALLOWLIST", "")
    for raw in inline.split(","):
        host = _extract_host(raw)
        if host:
            allowed.add(host)

    allowlist_file = (
        os.environ.get("MULTISITE_SHARED_HOST_ALLOWLIST_FILE", "").strip()
        or DEFAULT_SHARED_HOST_ALLOWLIST_PATH
    )
    if allowlist_file and os.path.exists(allowlist_file):
        with open(allowlist_file, encoding="utf-8") as f:
            for line in f:
                token = line.split("#", 1)[0].strip()
                if not token:
                    continue
                host = _extract_host(token.split()[0])
                if host:
                    allowed.add(host)
    return allowed


def _collect_host_owners(definitions: list[SiteDefinition], field: str) -> dict[str, set[str]]:
    owners: dict[str, set[str]] = {}
    for definition in definitions:
        raw = definition.domain if field == "domain" else (definition.site_values.get(field) or "")
        host = _extract_host(raw)
        if not host:
            continue
        owners.setdefault(host, set()).add(definition.domain)
    return owners


def _is_non_enterprise_domain(domain: str) -> bool:
    domain = (domain or "").strip().lower()
    if not domain:
        return False
    return (
        domain.endswith(".mereka.dev")
        or ".staging." in domain
        or domain.startswith("preview.")
        or domain.startswith("staging.")
    )


@dataclass(frozen=True)
class HostCollision:
    """Structured record of a cross-tenant host collision detected before any DB write."""

    field: str
    host: str
    owners: tuple[str, ...]
    file_source: str
    allowlisted: bool
    enterprise_violation: bool


def build_collision_report(
    definitions: list[SiteDefinition],
    allow_shared_hosts: set[str],
    file_source: str = "",
) -> list[HostCollision]:
    """
    Return structured collision records for all fields.

    Each record captures the field name, the shared host, all tenant domain owners,
    the YAML file it was loaded from, and whether the collision is allowlist-approved
    or an enterprise violation.

    This is the source of truth consumed by both validate_site_host_ownership (for
    error strings) and the dry-run collision report printed before any DB writes.
    """
    collisions: list[HostCollision] = []
    source = file_source or os.environ.get("MULTISITE_DEFINITIONS_PATH") or DEFAULT_DEFINITIONS_PATH

    for field in ("domain", "LMS_ROOT_URL", "CMS_ROOT_URL", "MFE_BASE_URL"):
        owners_map = _collect_host_owners(definitions, field)
        for host, tenant_domains in sorted(owners_map.items()):
            domains = tuple(sorted(tenant_domains))
            if len(domains) <= 1:
                continue

            allowlisted = field in ("CMS_ROOT_URL", "MFE_BASE_URL") and host in allow_shared_hosts
            enterprise_violation = allowlisted and any(
                not _is_non_enterprise_domain(d) for d in domains
            )

            collisions.append(
                HostCollision(
                    field=field,
                    host=host,
                    owners=domains,
                    file_source=source,
                    allowlisted=allowlisted,
                    enterprise_violation=enterprise_violation,
                )
            )
    return collisions


def print_collision_report(collisions: list[HostCollision]) -> None:
    """Print a deterministic, human-readable collision report to stdout."""
    if not collisions:
        print("Host ownership check: OK (no shared hosts detected)")
        return

    print("Host ownership collision report:")
    print(f"  {'FIELD':<20} {'HOST':<45} {'OWNERS'}")
    print(f"  {'-'*20} {'-'*45} {'-'*40}")
    for c in collisions:
        status = "ALLOWLISTED" if c.allowlisted and not c.enterprise_violation else "COLLISION"
        if c.enterprise_violation:
            status = "ENTERPRISE-VIOLATION"
        owners_str = ", ".join(c.owners)
        print(f"  {c.field:<20} {c.host:<45} {owners_str}")
        print(f"  {'':20} {'status':>10}: {status}  source: {c.file_source}")


def validate_site_host_ownership(definitions: list[SiteDefinition], allow_shared_hosts: set[str]) -> list[str]:
    """Return error strings for collisions that must block DB writes.

    Delegates collision detection to build_collision_report so both the error path
    and the dry-run report use identical logic.
    """
    errors: list[str] = []
    for c in build_collision_report(definitions, allow_shared_hosts):
        if c.allowlisted and not c.enterprise_violation:
            continue
        if c.enterprise_violation:
            errors.append(
                f"{c.field} host '{c.host}' allowlisted but used by enterprise domains {list(c.owners)} "
                "(allowlist is preview/dev/staging only)"
            )
        else:
            errors.append(
                f"{c.field} host '{c.host}' is shared by tenants {list(c.owners)} (must be unique or allowlisted)"
            )
    return errors


def select_shared_mfe_host_owners(
    definitions: list[SiteDefinition], allow_shared_hosts: set[str]
) -> dict[str, str]:
    """
    Pick one canonical tenant domain to manage each allowlisted shared MFE host.

    Preference order:
      1. non-preview tenant domain
      2. first sorted domain as deterministic fallback
    """
    host_owners = _collect_host_owners(definitions, "MFE_BASE_URL")
    selected: dict[str, str] = {}
    for host in sorted(allow_shared_hosts):
        domains = sorted(host_owners.get(host, set()))
        if not domains:
            continue
        selected[host] = next(
            (domain for domain in domains if not domain.startswith("preview.")),
            domains[0],
        )
    return selected


def setup_django():
    """Initialize Django environment."""
    # In K8s we run with Tutor settings, which include OIDC settings and other overrides.
    # Keep the pod-provided module if present; otherwise default to tutor production.
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "lms.envs.tutor.production")
    import django
    django.setup()


def upsert_organizations(dry_run: bool) -> None:
    """Create or update organization records."""
    from organizations.models import Organization

    for record in ORGANIZATIONS:
        if dry_run:
            print(f"[dry-run] Would ensure organization {record['short_name']}")
            continue

        org, created = Organization.objects.update_or_create(
            short_name=record["short_name"],
            defaults={
                "name": record["name"],
                "description": record["description"],
                "active": True,
            }
        )
        action = "Created" if created else "Updated"
        print(f"{action} organization: {org.short_name} - {org.name}")


def upsert_sites(
    definitions: list[SiteDefinition],
    dry_run: bool,
    unique_mfe_hosts: set[str],
    shared_mfe_host_owners: dict[str, str],
) -> None:
    """Create or update Site and SiteConfiguration records."""
    from django.conf import settings
    from django.contrib.sites.models import Site
    from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
    try:
        from enterprise.models import EnterpriseCustomer
    except Exception:
        EnterpriseCustomer = None

    for definition in definitions:
        if dry_run:
            print(f"[dry-run] Would ensure site {definition.domain} -> {definition.name}")
            print(f"           course_org_filter={definition.orgs}")
            continue

        # Create or update Site
        site, created = Site.objects.update_or_create(
            domain=definition.domain,
            defaults={"name": definition.name}
        )
        action = "Created" if created else "Updated"
        print(f"{action} site: {site.domain} - {site.name}")

        # Prepare site values
        rendered_values = dict(definition.site_values)
        if "course_org_filter" not in rendered_values:
            rendered_values["course_org_filter"] = definition.orgs
        existing_site_config = SiteConfiguration.objects.filter(site=site).order_by("-id").first()
        existing_values = dict(existing_site_config.site_values or {}) if existing_site_config else {}
        enterprise_uuid = str(existing_values.get("ENTERPRISE_CUSTOMER_UUID") or "").strip()
        if EnterpriseCustomer is not None:
            ec_qs = EnterpriseCustomer.objects.filter(site=site)
            if hasattr(EnterpriseCustomer, "created"):
                ec = ec_qs.order_by("-created").first()
            elif hasattr(EnterpriseCustomer, "modified"):
                ec = ec_qs.order_by("-modified").first()
            else:
                ec = ec_qs.first()
            if ec is not None:
                enterprise_uuid = str(ec.uuid)
        if enterprise_uuid:
            rendered_values["ENTERPRISE_CUSTOMER_UUID"] = enterprise_uuid

        # MFE config API returns `settings.MFE_CONFIG` unless the current site's
        # SiteConfiguration provides `MFE_CONFIG` overrides. For multisite, we
        # must override tenant-specific URLs (LMS/STUDIO/MFE base) so MFEs don't
        # drift back to the primary LMS domain.
        lms_root = (rendered_values.get("LMS_ROOT_URL") or "").rstrip("/")
        cms_root = (rendered_values.get("CMS_ROOT_URL") or "").rstrip("/")
        mfe_base = (rendered_values.get("MFE_BASE_URL") or "").rstrip("/")
        overrides: dict[str, object] = {}
        if lms_root:
            mfe_host = ""
            if mfe_base:
                try:
                    parsed = urlparse(mfe_base)
                    mfe_host = parsed.netloc or ""
                except Exception:
                    mfe_host = ""

            default_cfg = dict(getattr(settings, "MFE_CONFIG", {}) or {})
            # Some deployments treat SiteConfiguration.MFE_CONFIG as authoritative and
            # do not reliably merge missing keys from settings.MFE_CONFIG. Keep the
            # auth/session contract explicit here so runtime behavior stays deterministic.
            overrides["LMS_BASE_URL"] = lms_root
            overrides["LOGIN_URL"] = f"{lms_root}/login"
            overrides["LOGOUT_URL"] = f"{lms_root}/logout"
            overrides["MARKETING_SITE_BASE_URL"] = lms_root
            overrides["REFRESH_ACCESS_TOKEN_ENDPOINT"] = "/login_refresh"
            overrides["DISABLE_ENTERPRISE_LOGIN"] = default_cfg.get("DISABLE_ENTERPRISE_LOGIN", True)
            overrides["ACCESS_TOKEN_COOKIE_NAME"] = (
                default_cfg.get("ACCESS_TOKEN_COOKIE_NAME")
                or "edx-jwt-cookie-header-payload"
            )
            overrides["USER_INFO_COOKIE_NAME"] = (
                default_cfg.get("USER_INFO_COOKIE_NAME")
                or "user-info"
            )
            overrides["SESSION_COOKIE_SAMESITE"] = (
                default_cfg.get("SESSION_COOKIE_SAMESITE")
                or "None"
            )
            overrides["CSRF_COOKIE_SAMESITE"] = (
                default_cfg.get("CSRF_COOKIE_SAMESITE")
                or "None"
            )
            for domain_key in ("SESSION_COOKIE_DOMAIN", "CSRF_COOKIE_DOMAIN"):
                domain_value = default_cfg.get(domain_key)
                if domain_value:
                    overrides[domain_key] = domain_value
            theme_name = (
                rendered_values.get("THEME_NAME")
                or rendered_values.get("DEFAULT_SITE_THEME")
                or "mereka"
            )
            if mfe_base:
                # Prefer MFE-static branding assets when available. In dev/staging, LMS
                # themed-asset redirects for logo-horizontal*.png can resolve to unhashed
                # static paths that 404, while apps host serves stable /static/images/*.
                overrides["FAVICON_URL"] = f"{mfe_base}/static/images/favicon.ico"
                overrides["LOGO_URL"] = f"{mfe_base}/static/images/logo-horizontal.png"
                overrides["LOGO_WHITE_URL"] = f"{mfe_base}/static/images/logo-horizontal-white.png"
                overrides["LOGO_TRADEMARK_URL"] = f"{mfe_base}/static/images/logo.png"
            else:
                # Fallback path when no MFE base URL is configured.
                overrides["FAVICON_URL"] = f"{lms_root}/theming/asset/{theme_name}/images/favicon.ico"
                overrides["LOGO_URL"] = f"{lms_root}/theming/asset/{theme_name}/images/logo-horizontal.png"
                overrides["LOGO_WHITE_URL"] = f"{lms_root}/theming/asset/{theme_name}/images/logo-horizontal-white.png"
                overrides["LOGO_TRADEMARK_URL"] = f"{lms_root}/theming/asset/{theme_name}/images/logo.png"
            if cms_root:
                overrides["STUDIO_BASE_URL"] = cms_root
            if mfe_host:
                overrides["BASE_URL"] = mfe_host
                authn_url = f"https://{mfe_host}/authn"
                overrides["AUTHN_MICROFRONTEND_URL"] = authn_url
                overrides["AUTHN_MICROFRONTEND_DOMAIN"] = authn_url
            else:
                authn_url = default_cfg.get("AUTHN_MICROFRONTEND_URL")
                authn_domain = default_cfg.get("AUTHN_MICROFRONTEND_DOMAIN")
                if authn_url:
                    overrides["AUTHN_MICROFRONTEND_URL"] = authn_url
                if authn_domain:
                    overrides["AUTHN_MICROFRONTEND_DOMAIN"] = authn_domain

            # Store explicit contract keys so runtime does not depend on merge behavior.
            rendered_values["MFE_CONFIG"] = overrides

        # Create or update SiteConfiguration
        site_config, created = SiteConfiguration.objects.update_or_create(
            site=site,
            defaults={
                "enabled": True,
                "site_values": rendered_values,
            }
        )
        action = "Created" if created else "Updated"
        print(f"{action} site configuration for: {site.domain}")
        print(f"  - platform_name: {rendered_values.get('platform_name')}")
        print(f"  - theme: {rendered_values.get('THEME_NAME')}")
        print(f"  - organizations: {rendered_values.get('course_org_filter')}")
        print(f"  - enterprise_uuid: {rendered_values.get('ENTERPRISE_CUSTOMER_UUID', 'unset')}")

        # Ensure MFE host itself resolves through SiteConfiguration overrides.
        # Without this, requests to apps.<domain> can miss tenant MFE_CONFIG and
        # fall back to global defaults (e.g., broken logo/theming URLs).
        if (
            mfe_base
            and overrides
            and not definition.domain.startswith("preview.")
        ):
            try:
                mfe_host = urlparse(mfe_base).netloc or ""
            except Exception:
                mfe_host = ""
            canonical_owner = shared_mfe_host_owners.get(mfe_host, "")
            should_manage_shared_host = (
                mfe_host in unique_mfe_hosts
                or canonical_owner == definition.domain
            )
            if mfe_host and mfe_host != definition.domain and should_manage_shared_host:
                mfe_site, mfe_site_created = Site.objects.update_or_create(
                    domain=mfe_host,
                    defaults={"name": f"{definition.name} Apps"},
                )
                mfe_site_action = "Created" if mfe_site_created else "Updated"
                print(f"{mfe_site_action} site: {mfe_site.domain} - {mfe_site.name}")

                mfe_site_values = dict(rendered_values)
                mfe_site_values["domain"] = mfe_host
                mfe_site_values["MFE_CONFIG"] = dict(overrides)

                mfe_site_config, mfe_sc_created = SiteConfiguration.objects.update_or_create(
                    site=mfe_site,
                    defaults={
                        "enabled": True,
                        "site_values": mfe_site_values,
                    },
                )
                mfe_sc_action = "Created" if mfe_sc_created else "Updated"
                print(f"{mfe_sc_action} site configuration for: {mfe_site.domain}")
            elif mfe_host and mfe_host != definition.domain:
                if canonical_owner and canonical_owner != definition.domain:
                    print(
                        f"Skipped MFE host SiteConfiguration upsert for shared host '{mfe_host}' "
                        f"(tenant: {definition.domain}; canonical owner: {canonical_owner})"
                    )
                    continue
                print(
                    f"Skipped MFE host SiteConfiguration upsert for shared host '{mfe_host}' "
                    f"(tenant: {definition.domain})"
                )


def upsert_oidc_provider_configs(definitions: list[SiteDefinition], dry_run: bool) -> None:
    """
    Ensure OIDC provider configs exist and are enabled for each site.

    Without this, hitting `/auth/login/oidc/` can 500 with:
      "Can't fetch setting of a disabled backend/provider."
    """
    from common.djangoapps.third_party_auth.models import OAuth2ProviderConfig
    from django.conf import settings
    from django.contrib.sites.models import Site

    key = getattr(settings, "SOCIAL_AUTH_OIDC_KEY", "mereka-lms")
    configured_secret = (
        (getattr(settings, "SOCIAL_AUTH_OAUTH_SECRETS", {}) or {}).get("oidc")
        or getattr(settings, "SOCIAL_AUTH_OIDC_SECRET", "")
        or ""
    )

    for definition in definitions:
        site = Site.objects.filter(domain=definition.domain).first()
        if not site:
            if dry_run:
                print(f"[dry-run] Would create Site for OIDC provider: {definition.domain}")
                continue
            site = Site.objects.create(domain=definition.domain, name=definition.name)

        if dry_run:
            print(f"[dry-run] Would ensure OIDC provider config for site={site.domain} (key={key})")
            continue

        qs = OAuth2ProviderConfig.objects.filter(site=site, backend_name="oidc").order_by("-change_date", "-id")
        latest = qs.first()

        latest_secret = ""
        if latest is not None:
            try:
                latest_secret = latest.get_setting("SECRET") or ""
            except Exception:
                latest_secret = ""

        if (
            latest
            and latest.enabled
            and latest.visible
            and (latest.key or "") == key
            and (latest.name or "") == OIDC_PROVIDER_DISPLAY_NAME
            and bool(latest_secret)
        ):
            print(
                f"OIDC provider config OK: site={site.domain} latest_id={latest.id} total={qs.count()}"
            )
            continue

        # ConfigurationModel semantics: creating a new row is the safest way to
        # ensure the *current* config (latest) is enabled, even if older rows exist.
        obj = OAuth2ProviderConfig(
            site=site,
            backend_name="oidc",
            enabled=True,
            visible=True,
            name=OIDC_PROVIDER_DISPLAY_NAME,
            slug="authentik",
            secondary=False,
            # Keep a valid secret in DB so token exchange remains stable even if
            # SOCIAL_AUTH_OAUTH_SECRETS drifts at runtime.
            key=key,
            secret=configured_secret,
            other_settings="",
        )
        obj.save()
        print(
            f"Created OIDC provider config: site={site.domain} id={obj.id} "
            f"enabled={obj.enabled} secret_set={bool(configured_secret)}"
        )


def upsert_waffle_flags(dry_run: bool) -> None:
    """Ensure MFE redirect flags are enabled for account/profile."""
    from waffle.models import Flag

    flags = {
        "account.redirect_to_microfrontend": True,
        "learner_profile.redirect_to_microfrontend": True,
    }

    for name, enabled in flags.items():
        if dry_run:
            print(f"[dry-run] Would set waffle flag {name} => {enabled}")
            continue

        flag, created = Flag.objects.update_or_create(
            name=name,
            defaults={"everyone": enabled},
        )
        action = "Created" if created else "Updated"
        print(f"{action} waffle flag: {name} => everyone={enabled}")


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview operations without applying changes",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply changes to database",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help=(
            "Check host ownership collisions and print deterministic collision report. "
            "Exits non-zero if any blocking collision is detected. "
            "Does NOT initialize Django or touch the database."
        ),
    )
    parser.add_argument(
        "--scope",
        choices=("full", "sites"),
        default="full",
        help="Apply full multisite bootstrap or only django_site/SiteConfiguration rows",
    )
    args = parser.parse_args()

    dry_run = not args.apply
    sites_only = args.scope == "sites"
    strict_host_ownership = os.environ.get("STRICT_TENANT_HOST_OWNERSHIP", "1") != "0"
    allow_shared_hosts = _load_shared_host_allowlist()

    collisions = build_collision_report(SITE_DEFINITIONS, allow_shared_hosts)
    ownership_errors = validate_site_host_ownership(SITE_DEFINITIONS, allow_shared_hosts)
    unique_mfe_hosts = {
        host for host, owners in _collect_host_owners(SITE_DEFINITIONS, "MFE_BASE_URL").items()
        if len(owners) == 1
    }
    shared_mfe_host_owners = select_shared_mfe_host_owners(SITE_DEFINITIONS, allow_shared_hosts)

    # --check: pure collision report, no Django, exits non-zero on blocking collisions
    if args.check:
        print("=" * 60)
        print("HOST OWNERSHIP CHECK (no DB writes)")
        print("=" * 60)
        if allow_shared_hosts:
            print(f"Shared host allowlist active: {sorted(allow_shared_hosts)}")
        else:
            print("Shared host allowlist active: []")
        print()
        print_collision_report(collisions)
        if ownership_errors:
            print("\nBlocking collisions detected:")
            for err in ownership_errors:
                print(f"  - {err}")
            print("\nFix: ensure each enterprise host is owned by exactly one tenant,")
            print("     or add preview/dev/staging hosts to the allowlist file:")
            print(f"     {DEFAULT_SHARED_HOST_ALLOWLIST_PATH}")
            sys.exit(1)
        print("\nNo blocking collisions. Host ownership OK.")
        sys.exit(0)

    if dry_run:
        print("=" * 60)
        print("DRY RUN MODE - No changes will be made")
        print("=" * 60)

    if allow_shared_hosts:
        print(f"Shared host allowlist active: {sorted(allow_shared_hosts)}")
        if shared_mfe_host_owners:
            print(f"Shared MFE host canonical owners: {shared_mfe_host_owners}")
    else:
        print("Shared host allowlist active: []")

    # Always print the collision report in dry-run mode so operators can see the
    # ownership state before any DB writes happen.
    if dry_run:
        print()
        print_collision_report(collisions)

    if ownership_errors:
        print("\nHost ownership validation errors:")
        for err in ownership_errors:
            print(f"  - {err}")
        if strict_host_ownership:
            print("\nAborting due to STRICT_TENANT_HOST_OWNERSHIP=1")
            sys.exit(1)
        print("\nContinuing with STRICT_TENANT_HOST_OWNERSHIP=0")

    # Initialize Django
    setup_django()

    # Show planned changes
    print("\nOrganizations to create/update:")
    for org in ORGANIZATIONS:
        print(f"  - {org['short_name']}: {org['name']}")

    print("\nSites to create/update:")
    for site in SITE_DEFINITIONS:
        print(f"  - {site.domain}: {site.name}")
        print(f"    Organizations: {', '.join(site.orgs)}")
        print(f"    Platform name: {site.site_values.get('platform_name')}")

    print()

    if dry_run:
        print("Run with --apply to execute these changes")
        return

    print("=" * 60)
    print("APPLYING CHANGES")
    print("=" * 60)
    print()

    # Apply changes
    if sites_only:
        upsert_sites(
            SITE_DEFINITIONS,
            dry_run=False,
            unique_mfe_hosts=unique_mfe_hosts,
            shared_mfe_host_owners=shared_mfe_host_owners,
        )
    else:
        upsert_organizations(dry_run=False)
        print()
        upsert_sites(
            SITE_DEFINITIONS,
            dry_run=False,
            unique_mfe_hosts=unique_mfe_hosts,
            shared_mfe_host_owners=shared_mfe_host_owners,
        )
        print()
        upsert_oidc_provider_configs(SITE_DEFINITIONS, dry_run=False)
        print()
        upsert_waffle_flags(dry_run=False)

    print()
    print("=" * 60)
    print("Site configuration applied successfully!")
    print("=" * 60)
    print()
    print("Verify changes:")
    print("  1. Visit https://academyv2.mereka.io")
    print("  2. Visit https://academy.biji-biji.com")
    print("  3. Visit https://skillourfuture.academy.mereka.io")
    print()
    print("If changes don't appear, restart LMS pods:")
    print("  kubectl rollout restart deployment/lms -n mereka-lms")


if __name__ == "__main__":
    main()
