"""
Management command to provision a new tenant.

@spec: multi-tenancy-architecture_spec.md
@covers: AC-MTA-001, AC-MTA-002, AC-MTA-021
"""
import uuid
import logging

from django.core.management.base import BaseCommand, CommandError
from django.contrib.sites.models import Site
from django.db import transaction

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Provision a new tenant with all required resources'

    def add_arguments(self, parser):
        parser.add_argument('--slug', required=True, help='URL-safe tenant slug')
        parser.add_argument('--name', required=True, help='Tenant display name')
        parser.add_argument('--domain', required=True, help='Primary domain')
        parser.add_argument('--contact-email', default='', help='Admin contact email')
        parser.add_argument('--country', default='', help='ISO 3166-1 country code')
        parser.add_argument('--enterprise-uuid', default='', help='Existing EnterpriseCustomer UUID (auto-generated if empty)')

    def handle(self, *args, **options):
        slug = options['slug']
        name = options['name']
        domain = options['domain']
        contact_email = options['contact_email']
        country = options['country']
        enterprise_uuid_str = options['enterprise_uuid']

        # Step 0: Validate slug format
        self._validate_slug(slug)

        self.stdout.write(f'\n=== Provisioning Tenant: {name} ({slug}) ===\n')

        with transaction.atomic():
            # Step 1: Create or get Django Site
            site, site_created = self._ensure_site(domain, name)

            # Step 2: Create or get EnterpriseCustomer (via edx-enterprise)
            enterprise_uuid = self._ensure_enterprise_customer(
                slug, name, site, contact_email, country, enterprise_uuid_str
            )

            # Step 3: Create or get TenantSiteMapping
            mapping, mapping_created = self._ensure_tenant_mapping(
                enterprise_uuid, site, slug, name
            )

            # Step 4: Create or get TenantSiteConfiguration
            config, config_created = self._ensure_site_configuration(mapping, name)

            # Step 5: Create or get enterprise catalog
            catalog_created = self._ensure_enterprise_catalog(enterprise_uuid, name)

            # Step 6: Create or get subscription plan (placeholder)
            sub_created = self._ensure_subscription_plan(enterprise_uuid, name)

            # Step 7: Create or get access policy (placeholder)
            policy_created = self._ensure_access_policy(enterprise_uuid, name)

            # Step 8: SAML/OIDC placeholder
            self._ensure_idp_placeholder(enterprise_uuid, slug)

            # Step 9: Integrated channels placeholder
            self._ensure_channels_placeholder(enterprise_uuid, slug)

            # Step 10: Ensure branding directory
            self._ensure_branding_directory(slug)

        # Step 11: Summary
        self.stdout.write(self.style.SUCCESS(f'\n=== Provisioning Summary for {name} ==='))
        self.stdout.write(f'  Enterprise UUID: {enterprise_uuid}')
        self.stdout.write(f'  Site:            {domain} ({"created" if site_created else "already exists"})')
        self.stdout.write(f'  Mapping:         {"created" if mapping_created else "already exists"}')
        self.stdout.write(f'  Configuration:   {"created" if config_created else "already exists"}')
        self.stdout.write(self.style.SUCCESS('\nTenant provisioned successfully.'))

    def _validate_slug(self, slug):
        """Validate slug format: lowercase alphanumeric with hyphens."""
        import re
        if not re.match(r'^[a-z0-9][a-z0-9_-]*$', slug):
            raise CommandError(
                f"Invalid slug '{slug}': must be lowercase alphanumeric, "
                "hyphens, and underscores only, starting with alphanumeric"
            )
        if len(slug) > 100:
            raise CommandError(f"Slug '{slug}' exceeds 100 characters")

    def _ensure_site(self, domain, name):
        """Step 1: Create or get Django Site."""
        site, created = Site.objects.get_or_create(
            domain=domain,
            defaults={'name': name},
        )
        status = 'Created' if created else 'Already exists'
        self.stdout.write(f'  [1/11] Django Site ({domain}): {status}')
        return site, created

    def _ensure_enterprise_customer(self, slug, name, site, contact_email, country, uuid_str):
        """Step 2: Create or get EnterpriseCustomer."""
        try:
            from enterprise.models import EnterpriseCustomer

            if uuid_str:
                # Use existing UUID
                ent_uuid = uuid.UUID(uuid_str)
                ec = EnterpriseCustomer.objects.filter(uuid=ent_uuid).first()
                if ec:
                    self.stdout.write(f'  [2/11] EnterpriseCustomer ({ent_uuid}): Already exists')
                    return ent_uuid
                else:
                    raise CommandError(f"EnterpriseCustomer with UUID {uuid_str} not found")

            # Check by slug/name
            ec = EnterpriseCustomer.objects.filter(slug=slug).first()
            if ec:
                self.stdout.write(f'  [2/11] EnterpriseCustomer ({ec.uuid}): Already exists (slug match)')
                return ec.uuid

            # Create new EnterpriseCustomer
            kwargs = {
                'name': name,
                'slug': slug,
                'active': True,
                'enable_data_sharing_consent': True,
                'enforce_data_sharing_consent': 'at_enrollment',
                'site': site,
            }
            if contact_email:
                kwargs['contact_email'] = contact_email
            if country:
                kwargs['country'] = country

            ec = EnterpriseCustomer.objects.create(**kwargs)
            self.stdout.write(f'  [2/11] EnterpriseCustomer ({ec.uuid}): Created')
            return ec.uuid

        except ImportError:
            # edx-enterprise not available — generate UUID for mapping only
            if uuid_str:
                ent_uuid = uuid.UUID(uuid_str)
            else:
                ent_uuid = uuid.uuid4()
            self.stdout.write(
                f'  [2/11] EnterpriseCustomer ({ent_uuid}): '
                f'Skipped (edx-enterprise not installed); UUID generated for mapping'
            )
            return ent_uuid

    def _ensure_tenant_mapping(self, enterprise_uuid, site, slug, name):
        """Step 3: Create or get TenantSiteMapping."""
        from openedx_tenant_cache.models import TenantSiteMapping

        mapping = TenantSiteMapping.objects.filter(slug=slug).first()
        if mapping:
            self.stdout.write(f'  [3/11] TenantSiteMapping ({slug}): Already exists')
            return mapping, False

        # Also check by enterprise UUID
        mapping = TenantSiteMapping.objects.filter(
            enterprise_customer_uuid=enterprise_uuid
        ).first()
        if mapping:
            self.stdout.write(f'  [3/11] TenantSiteMapping ({slug}): Already exists (UUID match)')
            return mapping, False

        mapping = TenantSiteMapping.objects.create(
            enterprise_customer_uuid=enterprise_uuid,
            site=site,
            slug=slug,
            name=name,
            is_active=True,
            branding_config={},
        )
        self.stdout.write(f'  [3/11] TenantSiteMapping ({slug}): Created')
        return mapping, True

    def _ensure_site_configuration(self, mapping, name):
        """Step 4: Create or get TenantSiteConfiguration."""
        from openedx_tenant_cache.models import TenantSiteConfiguration

        try:
            config = TenantSiteConfiguration.objects.get(tenant=mapping)
            self.stdout.write(f'  [4/11] TenantSiteConfiguration: Already exists')
            return config, False
        except TenantSiteConfiguration.DoesNotExist:
            pass

        config = TenantSiteConfiguration.objects.create(
            tenant=mapping,
            values={
                'PLATFORM_NAME': name,
                'SITE_NAME': name,
                'logo_url': '',
                'favicon_url': '',
                'primary_color': '#1a73e8',
                'secondary_color': '#4285f4',
                'footer_text': f'© {name}',
                'sender_alias': name,
            },
            mfe_config={
                'SITE_NAME': name,
                'LOGO_URL': '',
                'LOGO_TRADEMARK_URL': '',
                'LOGO_WHITE_URL': '',
                'FAVICON_URL': '',
            },
            is_active=True,
        )
        self.stdout.write(f'  [4/11] TenantSiteConfiguration: Created')
        return config, True

    def _ensure_enterprise_catalog(self, enterprise_uuid, name):
        """Step 5: Create enterprise catalog (placeholder if module unavailable)."""
        try:
            from enterprise.models import EnterpriseCustomerCatalog
            catalog = EnterpriseCustomerCatalog.objects.filter(
                enterprise_customer__uuid=enterprise_uuid,
            ).first()
            if catalog:
                self.stdout.write(f'  [5/11] Enterprise Catalog: Already exists')
                return False
            # Create default catalog — includes all courses
            from enterprise.models import EnterpriseCustomer
            ec = EnterpriseCustomer.objects.get(uuid=enterprise_uuid)
            EnterpriseCustomerCatalog.objects.create(
                enterprise_customer=ec,
                title=f'{name} - Default Catalog',
                content_filter={},
            )
            self.stdout.write(f'  [5/11] Enterprise Catalog: Created (default — all courses)')
            return True
        except (ImportError, Exception) as e:
            self.stdout.write(
                f'  [5/11] Enterprise Catalog: Skipped ({type(e).__name__})'
            )
            return False

    def _ensure_subscription_plan(self, enterprise_uuid, name):
        """Step 6: Subscription plan placeholder."""
        self.stdout.write(
            f'  [6/11] Subscription Plan: Placeholder (configure via admin)'
        )
        return False

    def _ensure_access_policy(self, enterprise_uuid, name):
        """Step 7: Access policy placeholder."""
        self.stdout.write(
            f'  [7/11] Access Policy: Placeholder (configure via admin)'
        )
        return False

    def _ensure_idp_placeholder(self, enterprise_uuid, slug):
        """Step 8: SAML/OIDC identity provider placeholder."""
        self.stdout.write(
            f'  [8/11] SAML/OIDC Provider: Placeholder '
            f'(use scripts/tenants/configure-tenant-idp.sh --tenant-slug {slug})'
        )

    def _ensure_channels_placeholder(self, enterprise_uuid, slug):
        """Step 9: Integrated channels placeholder."""
        self.stdout.write(
            f'  [9/11] Integrated Channels: Placeholder (configure via admin)'
        )

    def _ensure_branding_directory(self, slug):
        """Step 10: Ensure branding assets directory exists."""
        import os
        from django.conf import settings

        branding_dir = getattr(
            settings, 'TENANT_BRANDING_DIR',
            os.path.join(os.path.dirname(__file__), '..', '..', '..', 'themes', 'mereka', 'tenants')
        )
        tenant_dir = os.path.join(branding_dir, slug)
        logos_dir = os.path.join(tenant_dir, 'logos')
        favicons_dir = os.path.join(tenant_dir, 'favicons')
        styles_dir = os.path.join(tenant_dir, 'styles')

        created = False
        for d in [logos_dir, favicons_dir, styles_dir]:
            if not os.path.exists(d):
                os.makedirs(d, exist_ok=True)
                created = True

        status = 'Created' if created else 'Already exists'
        self.stdout.write(f'  [10/11] Branding directory ({slug}/): {status}')
