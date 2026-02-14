"""
Apply branding configuration from JSON file to a tenant's SiteConfiguration.

@spec: multi-tenancy-architecture_spec.md
@covers: AC-TEN-009 — Per-tenant branding from SiteConfiguration
"""
import json
import logging

from django.core.management.base import BaseCommand, CommandError

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Apply branding configuration from JSON file to a tenant'

    def add_arguments(self, parser):
        parser.add_argument(
            '--tenant-slug', required=True,
            help='Tenant slug to apply branding to',
        )
        parser.add_argument(
            '--branding-file', required=True,
            help='Path to branding JSON file',
        )
        parser.add_argument(
            '--dry-run', action='store_true',
            help='Show what would be applied without making changes',
        )

    def handle(self, *args, **options):
        slug = options['tenant_slug']
        branding_file = options['branding_file']
        dry_run = options['dry_run']

        # Load branding JSON
        try:
            with open(branding_file, 'r') as f:
                branding = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            raise CommandError(f"Failed to read branding file: {e}")

        # Validate
        if branding.get('tenant_slug') and branding['tenant_slug'] != slug:
            raise CommandError(
                f"Branding file slug '{branding['tenant_slug']}' "
                f"does not match --tenant-slug '{slug}'"
            )

        from openedx_tenant_cache.models import TenantSiteMapping, TenantSiteConfiguration

        mapping = TenantSiteMapping.get_by_slug(slug)
        if not mapping:
            raise CommandError(f"Tenant '{slug}' not found")

        site_config = branding.get('site_configuration', {})
        mfe_config = branding.get('mfe_config', {})

        self.stdout.write(f'\n=== Applying Branding: {slug} ===')
        self.stdout.write(f'  Site config keys: {list(site_config.keys())}')
        self.stdout.write(f'  MFE config keys:  {list(mfe_config.keys())}')

        if dry_run:
            self.stdout.write(self.style.WARNING('\n  DRY RUN — no changes made.'))
            return

        try:
            config = TenantSiteConfiguration.objects.get(tenant=mapping)
            # Merge with existing
            existing_values = config.values or {}
            existing_mfe = config.mfe_config or {}
            existing_values.update(site_config)
            existing_mfe.update(mfe_config)
            config.values = existing_values
            config.mfe_config = existing_mfe
            config.save()
            self.stdout.write(self.style.SUCCESS('  Updated existing TenantSiteConfiguration.'))
        except TenantSiteConfiguration.DoesNotExist:
            TenantSiteConfiguration.objects.create(
                tenant=mapping,
                values=site_config,
                mfe_config=mfe_config,
                is_active=True,
            )
            self.stdout.write(self.style.SUCCESS('  Created new TenantSiteConfiguration.'))

        # Also update branding_config on the mapping
        mapping.branding_config = {
            'logo_url': site_config.get('logo_url', ''),
            'favicon_url': site_config.get('favicon_url', ''),
            'primary_color': site_config.get('primary_color', ''),
            'secondary_color': site_config.get('secondary_color', ''),
            'footer_text': site_config.get('footer_text', ''),
            'sender_alias': site_config.get('sender_alias', ''),
        }
        mapping.save()
        self.stdout.write(self.style.SUCCESS('  Updated TenantSiteMapping.branding_config.'))

        # Clear branding cache
        from openedx_tenant_cache.cache import tenant_cache_delete
        tenant_cache_delete(str(mapping.enterprise_customer_uuid), 'branding', 'mfe_config')
        self.stdout.write('  Cache cleared for branding.')

        self.stdout.write(self.style.SUCCESS(f'\nBranding applied successfully for {slug}.'))
