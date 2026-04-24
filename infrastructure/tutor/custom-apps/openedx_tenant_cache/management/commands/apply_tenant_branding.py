"""
Apply branding configuration from JSON file to a tenant's SiteConfiguration.

@spec: multi-tenancy-architecture_spec.md
@covers: AC-TEN-009 — Per-tenant branding from SiteConfiguration
"""
import json
import logging
import re

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Apply branding configuration from JSON file to a tenant'
    HEX_COLOR_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")

    def _hex_color(self, value, field_name, *, default=None, required=False):
        if value is None or value == "":
            if required:
                raise CommandError(f"Missing required field: {field_name}")
            return default
        if not isinstance(value, str) or not self.HEX_COLOR_RE.match(value):
            raise CommandError(f"Invalid color for {field_name}: expected #RRGGBB")
        return value.lower()

    def _build_site_and_mfe_config(self, branding, tenant_slug):
        config_slug = branding.get("slug")
        if config_slug and config_slug != tenant_slug:
            raise CommandError(
                f"Branding file slug '{config_slug}' does not match --tenant-slug '{tenant_slug}'"
            )

        colors = branding.get("colors")
        if not isinstance(colors, dict):
            raise CommandError("Branding file must define a top-level 'colors' object")

        logos = branding.get("logos")
        if not isinstance(logos, dict):
            raise CommandError("Branding file must define a top-level 'logos' object")

        footer = branding.get("footer")
        if footer is None:
            footer = {}
        if not isinstance(footer, dict):
            raise CommandError("Branding file 'footer' field must be an object when present")

        tenant_name = branding.get("name") or tenant_slug
        if not isinstance(tenant_name, str) or not tenant_name.strip():
            raise CommandError("Branding file field 'name' must be a non-empty string")
        tenant_name = tenant_name.strip()

        primary_color = self._hex_color(colors.get("primary"), "colors.primary", required=True)
        secondary_color = self._hex_color(
            colors.get("secondary"),
            "colors.secondary",
            default="#237072",
        )
        accent_color = self._hex_color(
            colors.get("accent"),
            "colors.accent",
            default="#295cad",
        )
        text_on_primary = self._hex_color(
            colors.get("text_on_primary"),
            "colors.text_on_primary",
            default="#ffffff",
        )

        logo_url = logos.get("logo_url", "")
        logo_square_url = logos.get("logo_square_url", "") or logo_url
        logo_white_url = logos.get("logo_white_url", "") or logo_url
        favicon_url = logos.get("favicon_url", "")
        public_footer = (
            (getattr(settings, "MFE_CONFIG", {}) or {}).get("MEREKA_PUBLIC_FOOTER")
            or getattr(settings, "MEREKA_PUBLIC_FOOTER", {})
            or {}
        )

        site_config = {
            "PLATFORM_NAME": tenant_name,
            "SITE_NAME": tenant_name,
            "logo_url": logo_url,
            "favicon_url": favicon_url,
            "primary_color": primary_color,
            "secondary_color": secondary_color,
            "accent_color": accent_color,
            "text_on_primary_color": text_on_primary,
            "footer_text": footer.get("text", ""),
            "sender_alias": tenant_name,
        }

        mfe_config = {
            "SITE_NAME": tenant_name,
            "LOGO_URL": logo_url,
            "LOGO_TRADEMARK_URL": logo_square_url,
            "LOGO_WHITE_URL": logo_white_url,
            "FAVICON_URL": favicon_url,
            "PRIMARY_COLOR": primary_color,
            "SECONDARY_COLOR": secondary_color,
            "ACCENT_COLOR": accent_color,
            "BRAND_PRIMARY": primary_color,
            "BRAND_SECONDARY": secondary_color,
            "BRAND_ACCENT": accent_color,
            "TEXT_ON_PRIMARY": text_on_primary,
            "MEREKA_PUBLIC_FOOTER": public_footer,
        }

        return site_config, mfe_config

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

        from openedx_tenant_cache.models import TenantSiteMapping, TenantSiteConfiguration

        mapping = TenantSiteMapping.get_by_slug(slug)
        if not mapping:
            raise CommandError(f"Tenant '{slug}' not found")

        site_config, mfe_config = self._build_site_and_mfe_config(branding, slug)

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
            'accent_color': site_config.get('accent_color', ''),
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
