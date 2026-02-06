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


@dataclass(frozen=True)
class SiteDefinition:
    domain: str
    name: str
    orgs: List[str]
    site_values: Dict[str, object]


ORGANIZATIONS = [
    {
        "short_name": "MEREKA",
        "name": "Mereka Academy",
        "description": "Mereka Academy main site catalog.",
    },
    {
        "short_name": "BIJIBIJI",
        "name": "Biji-Biji Academy",
        "description": "Biji-Biji Academy microsite catalog.",
    },
    {
        "short_name": "SKILLOURFUTURE",
        "name": "Skill Our Future",
        "description": "Skill Our Future microsite catalog.",
    },
]

PRIMARY_DOMAIN = os.environ.get("MEREKA_LMS_DOMAIN", "academyv2.mereka.io")
BIJI_DOMAIN = os.environ.get("MEREKA_BIJI_DOMAIN", "academy.biji-biji.com")
SKILLOURFUTURE_DOMAIN = os.environ.get(
    "MEREKA_SKILLOURFUTURE_DOMAIN",
    "skillourfuture.academy.mereka.io",
)


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


SITE_DEFINITIONS = [
    SiteDefinition(
        domain=PRIMARY_DOMAIN,
        name="Mereka Academy",
        orgs=["MEREKA"],
        site_values={
            "domain": PRIMARY_DOMAIN,
            "site_name": "Mereka Academy",
            "platform_name": "Mereka Academy",
            "THEME_NAME": "mereka",
            "ENABLE_COMPREHENSIVE_THEMING": True,
            "ENABLE_ACCOUNT_MICROFRONTEND": True,
            "ENABLE_PROFILE_MICROFRONTEND": True,
            "course_org_filter": ["MEREKA"],
            "logo_image": f"https://{PRIMARY_DOMAIN}/static/mereka/images/logo-horizontal.png",
            "logo_url": "/",
            "favicon_path": "mereka/images/favicon.ico",
            "homepage_banner_enabled": False,
        },
    ),
    SiteDefinition(
        domain=BIJI_DOMAIN,
        name="Biji-Biji Academy",
        orgs=["BIJIBIJI"],
        site_values={
            "domain": BIJI_DOMAIN,
            "site_name": "Biji-Biji Academy",
            "platform_name": "Biji-Biji Academy",
            "THEME_NAME": "mereka",
            "ENABLE_COMPREHENSIVE_THEMING": True,
            "ENABLE_ACCOUNT_MICROFRONTEND": True,
            "ENABLE_PROFILE_MICROFRONTEND": True,
            "course_org_filter": ["BIJIBIJI"],
            "logo_image": f"https://{PRIMARY_DOMAIN}/static/mereka/images/logo-horizontal.png",
            "logo_url": "/",
            "favicon_path": "mereka/images/favicon.ico",
            "homepage_banner_enabled": False,
        },
    ),
    SiteDefinition(
        domain=SKILLOURFUTURE_DOMAIN,
        name="Skill Our Future",
        orgs=["SKILLOURFUTURE"],
        site_values={
            "domain": SKILLOURFUTURE_DOMAIN,
            "site_name": "Skill Our Future",
            "platform_name": "Skill Our Future",
            "THEME_NAME": "mereka",
            "ENABLE_COMPREHENSIVE_THEMING": True,
            "ENABLE_ACCOUNT_MICROFRONTEND": True,
            "ENABLE_PROFILE_MICROFRONTEND": True,
            "course_org_filter": ["SKILLOURFUTURE"],
            "logo_image": f"https://{PRIMARY_DOMAIN}/static/mereka/images/logo-horizontal.png",
            "logo_url": "/",
            "favicon_path": "mereka/images/favicon.ico",
            "homepage_banner_enabled": True,
            "homepage_overlay_html": hero_html(
                eyebrow="Skill Our Future",
                heading="Future-proof talent for Southeast Asia's green and digital economy.",
                body="Live cohorts, micro-credentials, and career accelerators designed with regional employers.",
                primary_label="Start learning",
                primary_href="/courses",
                secondary_label="Talk to our team",
                secondary_href="mailto:team@mereka.io",
                accent="#7dd3fc",
                background="#111b47",
            ),
        },
    ),
]


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
