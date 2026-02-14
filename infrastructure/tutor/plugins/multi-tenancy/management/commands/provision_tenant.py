# @covers AC-MTA-001, AC-MTA-002, AC-MTA-021
# @spec: multi-tenancy-architecture_spec.md
"""
Django management command to provision a new tenant.

Usage:
    manage.py lms provision_tenant \
        --slug acme-corp \
        --name "Acme Corp" \
        --domain acme.academyv2.mereka.io \
        [--contact-email admin@acme.com] \
        [--country MY] \
        [--dry-run]

Idempotent: running twice for the same slug skips already-created records.

Creates:
  1. Django Site for the tenant domain
  2. SiteConfiguration with required fields (PLATFORM_NAME, SITE_NAME, etc.)
  3. EnterpriseCustomer linked to the Site
  4. TenantConfig (mereka_tenancy extension)
  5. OAuth2 Application for tenant API access (django-oauth-toolkit)
  6. Waffle Switches for per-tenant feature flags
"""

import logging
import uuid as uuid_lib

from django.core.management.base import BaseCommand, CommandError

logger = logging.getLogger(__name__)

# Waffle switches created per tenant. Values are defaults (on/off).
TENANT_WAFFLE_SWITCHES = {
    "enterprise.enable_learner_portal": True,
    "enterprise.enable_analytics_screen": True,
    "enterprise.enable_audit_enrollment": False,
    "enterprise.enable_portal_code_management": False,
    "enterprise.enable_integrated_learner_portal_search": True,
}


class Command(BaseCommand):
    help = (
        "Provision a new tenant: EnterpriseCustomer + Site + SiteConfiguration "
        "+ TenantConfig + OAuth2 Application + Waffle Switches."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--slug",
            required=True,
            help="URL-safe tenant slug (e.g. 'acme-corp'). Must be unique.",
        )
        parser.add_argument(
            "--name",
            required=True,
            help="Human-readable tenant name (e.g. 'Acme Corp').",
        )
        parser.add_argument(
            "--domain",
            required=True,
            help="Primary domain for this tenant (e.g. 'acme.academyv2.mereka.io').",
        )
        parser.add_argument(
            "--contact-email",
            default="",
            help="Primary contact email for the tenant.",
        )
        parser.add_argument(
            "--country",
            default="",
            help="ISO 3166-1 alpha-2 country code (e.g. 'MY').",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            default=False,
            help="Show what would be done without making changes.",
        )

    def handle(self, *args, **options):
        slug = options["slug"]
        name = options["name"]
        domain = options["domain"]
        contact_email = options["contact_email"]
        country = options["country"]
        dry_run = options["dry_run"]

        self._validate_inputs(slug, domain)

        if dry_run:
            self._print_dry_run(slug, name, domain, contact_email, country)
            return

        site = self._get_or_create_site(domain, name)
        site_config = self._get_or_create_site_configuration(site, name, slug, domain)
        enterprise_customer = self._get_or_create_enterprise_customer(
            slug, name, site, contact_email, country
        )
        self._get_or_create_tenant_config(enterprise_customer, slug)

        # Store enterprise UUID in SiteConfiguration for middleware resolution.
        values = site_config.site_values or {}
        if str(enterprise_customer.uuid) != values.get("ENTERPRISE_CUSTOMER_UUID"):
            values["ENTERPRISE_CUSTOMER_UUID"] = str(enterprise_customer.uuid)
            site_config.site_values = values
            site_config.save(update_fields=["site_values"])
            self.stdout.write("  Updated SiteConfiguration with ENTERPRISE_CUSTOMER_UUID")

        self._get_or_create_oauth2_application(slug, name, domain)
        self._get_or_create_waffle_switches(slug)

        self.stdout.write(self.style.SUCCESS(
            f"\nTenant '{slug}' provisioned successfully."
        ))
        self.stdout.write(f"  UUID: {enterprise_customer.uuid}")
        self.stdout.write(f"  Domain: {domain}")
        self.stdout.write(f"  Site ID: {site.id}")
        self.stdout.write("")
        self.stdout.write("Manual steps remaining:")
        self.stdout.write("  1. Add DNS record for the domain (Cloudflare)")
        self.stdout.write("  2. Add domain to ALLOWED_HOSTS and CSRF_TRUSTED_ORIGINS")
        self.stdout.write("  3. Configure SSO/SAML IdP (if applicable)")
        self.stdout.write("  4. Upload branding assets to theme directory")
        self.stdout.write("  5. Create enterprise catalog and subscription plans")
        self.stdout.write("  6. Run: scripts/qa/verify-tenant-isolation.sh")

    def _validate_inputs(self, slug, domain):
        """Fail-fast on invalid inputs."""
        from django.contrib.sites.models import Site

        if not slug.replace("-", "").replace("_", "").isalnum():
            raise CommandError(
                f"Invalid slug '{slug}': must be alphanumeric with hyphens/underscores."
            )

        if len(slug) > 63:
            raise CommandError(
                f"Slug '{slug}' too long: max 63 characters."
            )

        # Check for duplicate domain belonging to a DIFFERENT tenant's site.
        existing_site = Site.objects.filter(domain__iexact=domain).first()
        if existing_site:
            from enterprise.models import EnterpriseCustomer

            ec = EnterpriseCustomer.objects.filter(site=existing_site).first()
            if ec and ec.slug != slug:
                raise CommandError(
                    f"Domain '{domain}' is already assigned to tenant '{ec.slug}'. "
                    "One domain can belong to only one tenant."
                )

    def _print_dry_run(self, slug, name, domain, contact_email, country):
        """Show what provisioning would do without executing."""
        self.stdout.write(self.style.WARNING("\n=== DRY RUN ==="))
        self.stdout.write(f"Would provision tenant '{slug}':")
        self.stdout.write(f"  1. Create/reuse Django Site: domain={domain}")
        self.stdout.write(f"  2. Create/reuse SiteConfiguration with:")
        self.stdout.write(f"       PLATFORM_NAME={name}")
        self.stdout.write(f"       SITE_NAME={name}")
        self.stdout.write(f"       ENABLE_ENTERPRISE_INTEGRATION=True")
        self.stdout.write(f"  3. Create/reuse EnterpriseCustomer: slug={slug}, name={name}")
        if contact_email:
            self.stdout.write(f"       contact_email={contact_email}")
        if country:
            self.stdout.write(f"       country={country}")
        self.stdout.write(f"  4. Create/reuse TenantConfig: slug={slug}")
        self.stdout.write(f"  5. Create/reuse OAuth2 Application: client_id=tenant-{slug}")
        self.stdout.write(f"  6. Create/reuse Waffle Switches:")
        for switch_name, default in TENANT_WAFFLE_SWITCHES.items():
            self.stdout.write(f"       {switch_name}.{slug} = {default}")
        self.stdout.write(self.style.WARNING("\nNo changes made (dry run)."))

    def _get_or_create_site(self, domain, name):
        from django.contrib.sites.models import Site

        site, created = Site.objects.get_or_create(
            domain=domain,
            defaults={"name": f"{name} Learning Portal"},
        )
        if created:
            self.stdout.write(f"  Created Site: {site.domain} (id={site.id})")
        else:
            self.stdout.write(f"  Site already exists: {site.domain} (id={site.id})")
        return site

    def _get_or_create_site_configuration(self, site, name, slug, domain):
        from openedx.core.djangoapps.site_configuration.models import SiteConfiguration

        defaults = {
            "site_values": {
                "SITE_NAME": name,
                "PLATFORM_NAME": name,
                "platform_name": name,
                "LMS_ROOT_URL": f"https://{domain}",
                "LMS_BASE_URL": f"https://{domain}",
                "ENABLE_ENTERPRISE_INTEGRATION": True,
                "ENABLE_THIRD_PARTY_AUTH": True,
                "course_org_filter": [slug],
            },
            "enabled": True,
        }

        site_config, created = SiteConfiguration.objects.get_or_create(
            site=site,
            defaults=defaults,
        )
        if created:
            self.stdout.write(f"  Created SiteConfiguration for site {site.domain}")
        else:
            self.stdout.write(f"  SiteConfiguration already exists for site {site.domain}")
        return site_config

    def _get_or_create_enterprise_customer(self, slug, name, site, contact_email, country):
        from enterprise.models import EnterpriseCustomer

        existing = EnterpriseCustomer.objects.filter(slug=slug).first()
        if existing:
            self.stdout.write(
                f"  EnterpriseCustomer already exists: {existing.name} "
                f"(uuid={existing.uuid})"
            )
            return existing

        ec = EnterpriseCustomer.objects.create(
            uuid=uuid_lib.uuid4(),
            name=name,
            slug=slug,
            site=site,
            active=True,
            contact_email=contact_email or "",
            country=country or "",
        )
        self.stdout.write(f"  Created EnterpriseCustomer: {ec.name} (uuid={ec.uuid})")
        return ec

    def _get_or_create_tenant_config(self, enterprise_customer, slug):
        from mereka_tenancy.models import TenantConfig

        tc, created = TenantConfig.objects.get_or_create(
            enterprise_customer=enterprise_customer,
            defaults={
                "slug": slug,
                "is_active": True,
            },
        )
        if created:
            self.stdout.write(f"  Created TenantConfig: {tc.slug}")
        else:
            self.stdout.write(f"  TenantConfig already exists: {tc.slug}")
        return tc

    def _get_or_create_oauth2_application(self, slug, name, domain):
        """Create an OAuth2 Application for this tenant's API access."""
        try:
            from oauth2_provider.models import Application
            from django.contrib.auth import get_user_model

            User = get_user_model()
            client_id = f"tenant-{slug}"

            existing = Application.objects.filter(client_id=client_id).first()
            if existing:
                self.stdout.write(f"  OAuth2 Application already exists: {client_id}")
                return existing

            # Use the service worker user if available, otherwise first superuser.
            service_user = (
                User.objects.filter(username="lms_worker").first()
                or User.objects.filter(is_superuser=True).first()
            )
            if not service_user:
                self.stdout.write(
                    self.style.WARNING(
                        "  SKIP: No suitable user for OAuth2 Application (need lms_worker or superuser)"
                    )
                )
                return None

            app = Application.objects.create(
                client_id=client_id,
                name=f"{name} Tenant Application",
                client_type=Application.CLIENT_CONFIDENTIAL,
                authorization_grant_type=Application.GRANT_CLIENT_CREDENTIALS,
                redirect_uris=f"https://{domain}/complete/edx-oauth2/",
                user=service_user,
            )
            self.stdout.write(f"  Created OAuth2 Application: {client_id}")
            return app
        except ImportError:
            self.stdout.write(
                self.style.WARNING("  SKIP: django-oauth-toolkit not installed")
            )
            return None

    def _get_or_create_waffle_switches(self, slug):
        """Create per-tenant Waffle switches for feature flags."""
        try:
            from waffle.models import Switch

            for switch_base, default_active in TENANT_WAFFLE_SWITCHES.items():
                switch_name = f"{switch_base}.{slug}"
                switch, created = Switch.objects.get_or_create(
                    name=switch_name,
                    defaults={"active": default_active},
                )
                if created:
                    state = "on" if default_active else "off"
                    self.stdout.write(f"  Created Waffle Switch: {switch_name} ({state})")
                else:
                    self.stdout.write(f"  Waffle Switch already exists: {switch_name}")
        except ImportError:
            self.stdout.write(
                self.style.WARNING("  SKIP: django-waffle not installed")
            )
