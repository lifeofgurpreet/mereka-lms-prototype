# @covers AC-001, AC-002, AC-021
# @spec: multi-tenancy-architecture_spec.md
"""
Django management command to provision a new tenant.

Usage:
    manage.py lms provision_tenant \
        --slug acme-corp \
        --name "Acme Corp" \
        --domain acme.academyv2.mereka.io \
        [--contact-email admin@acme.com] \
        [--country MY]

Idempotent: running twice for the same slug skips already-created records.
"""

import logging
import uuid as uuid_lib

from django.core.management.base import BaseCommand, CommandError

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "Provision a new tenant (EnterpriseCustomer + Site + SiteConfiguration + TenantConfig)."

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

    def handle(self, *args, **options):
        slug = options["slug"]
        name = options["name"]
        domain = options["domain"]
        contact_email = options["contact_email"]
        country = options["country"]

        self._validate_inputs(slug, domain)

        site = self._get_or_create_site(domain, name)
        site_config = self._get_or_create_site_configuration(site, name)
        enterprise_customer = self._get_or_create_enterprise_customer(
            slug, name, site, contact_email, country
        )
        tenant_config = self._get_or_create_tenant_config(
            enterprise_customer, slug
        )

        # Store enterprise UUID in SiteConfiguration for middleware resolution.
        values = site_config.site_values or {}
        if str(enterprise_customer.uuid) != values.get("ENTERPRISE_CUSTOMER_UUID"):
            values["ENTERPRISE_CUSTOMER_UUID"] = str(enterprise_customer.uuid)
            site_config.site_values = values
            site_config.save(update_fields=["site_values"])
            self.stdout.write(f"  Updated SiteConfiguration with ENTERPRISE_CUSTOMER_UUID")

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

        # Check for duplicate domain belonging to another site.
        existing = Site.objects.filter(domain__iexact=domain).first()
        if existing:
            # Will be reused — not an error (idempotency).
            pass

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

    def _get_or_create_site_configuration(self, site, name):
        from openedx.core.djangoapps.site_configuration.models import SiteConfiguration

        defaults = {
            "site_values": {
                "SITE_NAME": name,
                "platform_name": name,
                "ENABLE_ENTERPRISE_INTEGRATION": True,
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
