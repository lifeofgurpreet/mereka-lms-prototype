#!/usr/bin/env python3
"""Bootstrap django.contrib.sites + SiteConfiguration entries for multi-tenant LMS domains.

This version uses Django ORM instead of PyMySQL for better compatibility with LMS pods.
"""

from __future__ import annotations

import os
import sys
import json
import textwrap
from dataclasses import dataclass
from typing import Dict, List
from urllib.parse import urlparse


@dataclass(frozen=True)
class SiteDefinition:
    domain: str
    name: str
    orgs: List[str]
    site_values: Dict[str, object]


REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_DEFINITIONS_PATH = os.path.join(REPO_ROOT, "infrastructure", "tutor", "multisite-sites.yml")


def _load_yaml(path: str) -> dict:
    try:
        import yaml  # type: ignore
    except Exception as exc:  # pragma: no cover
        raise RuntimeError("PyYAML is required to load multisite-sites.yml") from exc
    with open(path, "r", encoding="utf-8") as f:
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


def upsert_sites(definitions: List[SiteDefinition], dry_run: bool) -> None:
    """Create or update Site and SiteConfiguration records."""
    from django.contrib.sites.models import Site
    from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
    from django.conf import settings

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
        rendered_values["course_org_filter"] = definition.orgs

        # MFE config API returns `settings.MFE_CONFIG` unless the current site's
        # SiteConfiguration provides `MFE_CONFIG` overrides. For multisite, we
        # must override tenant-specific URLs (LMS/STUDIO/MFE base) so MFEs don't
        # drift back to the primary LMS domain.
        lms_root = (rendered_values.get("LMS_ROOT_URL") or "").rstrip("/")
        cms_root = (rendered_values.get("CMS_ROOT_URL") or "").rstrip("/")
        mfe_base = (rendered_values.get("MFE_BASE_URL") or "").rstrip("/")
        if lms_root:
            mfe_host = ""
            if mfe_base:
                try:
                    parsed = urlparse(mfe_base)
                    mfe_host = parsed.netloc or ""
                except Exception:
                    mfe_host = ""

            default_cfg = dict(getattr(settings, "MFE_CONFIG", {}) or {})
            overrides: dict[str, object] = {}
            # Tenant-specific core URLs.
            overrides["LMS_BASE_URL"] = lms_root
            overrides["LOGIN_URL"] = f"{lms_root}/login"
            overrides["LOGOUT_URL"] = f"{lms_root}/logout"
            overrides["MARKETING_SITE_BASE_URL"] = lms_root
            overrides["REFRESH_ACCESS_TOKEN_ENDPOINT"] = f"{lms_root}/login_refresh"
            overrides["FAVICON_URL"] = f"{lms_root}/favicon.ico"
            overrides["LOGO_URL"] = f"{lms_root}/theming/asset/images/logo.png"
            overrides["LOGO_WHITE_URL"] = f"{lms_root}/theming/asset/images/logo.png"
            overrides["LOGO_TRADEMARK_URL"] = f"{lms_root}/theming/asset/images/logo.png"
            if cms_root:
                overrides["STUDIO_BASE_URL"] = cms_root
            if mfe_host:
                overrides["BASE_URL"] = mfe_host
                # Keep AUTHN MFE URLs in sync when the MFE host changes.
                if "AUTHN_MICROFRONTEND_URL" in default_cfg:
                    overrides["AUTHN_MICROFRONTEND_URL"] = f"https://{mfe_host}/authn"

            # Store overrides only; the API merges with settings.MFE_CONFIG.
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


def upsert_oidc_provider_configs(definitions: List[SiteDefinition], dry_run: bool) -> None:
    """
    Ensure OIDC provider configs exist and are enabled for each site.

    Without this, hitting `/auth/login/oidc/` can 500 with:
      "Can't fetch setting of a disabled backend/provider."
    """
    from django.conf import settings
    from django.contrib.sites.models import Site
    from common.djangoapps.third_party_auth.models import OAuth2ProviderConfig

    key = getattr(settings, "SOCIAL_AUTH_OIDC_KEY", "mereka-lms")

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

        if latest and latest.enabled and latest.visible and (latest.key or "") == key:
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
            name="Authentik",
            slug="authentik",
            secondary=False,
            # Keep secrets out of DB; lms/cms settings inject via env.
            key=key,
            secret="",
            other_settings="",
        )
        obj.save()
        print(f"Created OIDC provider config: site={site.domain} id={obj.id} enabled={obj.enabled}")


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
    args = parser.parse_args()

    dry_run = not args.apply

    if dry_run:
        print("=" * 60)
        print("DRY RUN MODE - No changes will be made")
        print("=" * 60)

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
    upsert_organizations(dry_run=False)
    print()
    upsert_sites(SITE_DEFINITIONS, dry_run=False)
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
