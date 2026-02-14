"""
Models for tenant foundation: SiteConfiguration overlay and tenant registry.

@spec: multi-tenancy-architecture_spec.md
@covers: EnterpriseCustomer ↔ Django Site mapping, SiteConfiguration overlays
"""

import uuid

from django.db import models
from django.contrib.sites.models import Site


class TenantSiteMapping(models.Model):
    """
    Maps an EnterpriseCustomer UUID to a Django Site for domain routing.

    This model establishes the EnterpriseCustomer ↔ Django Site link
    required for multi-tenant SiteConfiguration resolution.

    The actual EnterpriseCustomer model lives in edx-enterprise;
    this mapping uses the UUID as a stable foreign reference.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    enterprise_customer_uuid = models.UUIDField(
        unique=True,
        db_index=True,
        help_text="EnterpriseCustomer UUID from edx-enterprise"
    )

    site = models.OneToOneField(
        Site,
        on_delete=models.CASCADE,
        related_name='tenant_mapping',
        help_text="Django Site for this tenant (domain routing)"
    )

    slug = models.SlugField(
        max_length=100,
        unique=True,
        db_index=True,
        help_text="URL-safe tenant identifier (e.g., 'acme-corp')"
    )

    name = models.CharField(
        max_length=255,
        help_text="Tenant display name"
    )

    is_active = models.BooleanField(
        default=True,
        db_index=True,
        help_text="Whether this tenant is active"
    )

    branding_config = models.JSONField(
        default=dict,
        blank=True,
        help_text=(
            "Per-tenant branding: logo_url, favicon_url, primary_color, "
            "secondary_color, footer_text, sender_alias"
        )
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'openedx_tenant_cache_tenantsitemapping'
        verbose_name = 'Tenant Site Mapping'
        verbose_name_plural = 'Tenant Site Mappings'

    def __str__(self):
        return f"{self.name} ({self.slug}) -> {self.site.domain}"

    @classmethod
    def get_by_uuid(cls, enterprise_uuid):
        """Look up tenant by EnterpriseCustomer UUID."""
        return cls.objects.filter(
            enterprise_customer_uuid=enterprise_uuid,
            is_active=True,
        ).select_related('site').first()

    @classmethod
    def get_by_site(cls, site):
        """Look up tenant by Django Site."""
        return cls.objects.filter(
            site=site,
            is_active=True,
        ).first()

    @classmethod
    def get_by_slug(cls, slug):
        """Look up tenant by slug."""
        return cls.objects.filter(
            slug=slug,
            is_active=True,
        ).select_related('site').first()


class TenantSiteConfiguration(models.Model):
    """
    Per-tenant JSON overlays for SiteConfiguration.

    Stores branding overrides (logos, colors, footer) that the
    MFE reads at runtime via the mfe_config API.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    tenant = models.OneToOneField(
        TenantSiteMapping,
        on_delete=models.CASCADE,
        related_name='site_config',
        help_text="Tenant this configuration belongs to"
    )

    values = models.JSONField(
        default=dict,
        blank=True,
        help_text=(
            "SiteConfiguration JSON overlay: "
            "logo_url, favicon_url, primary_color, secondary_color, "
            "footer_text, sender_alias, custom_css_url, "
            "PLATFORM_NAME, SITE_NAME, etc."
        )
    )

    mfe_config = models.JSONField(
        default=dict,
        blank=True,
        help_text=(
            "MFE-specific configuration injected at runtime: "
            "LOGO_URL, LOGO_TRADEMARK_URL, LOGO_WHITE_URL, "
            "FAVICON_URL, SITE_NAME, COLORS, MARKETING_URLS"
        )
    )

    is_active = models.BooleanField(
        default=True,
        help_text="Whether this configuration is active"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'openedx_tenant_cache_tenantsiteconfiguration'
        verbose_name = 'Tenant Site Configuration'
        verbose_name_plural = 'Tenant Site Configurations'

    def __str__(self):
        return f"Config for {self.tenant.name}"

    def get_merged_config(self):
        """
        Merge tenant branding config with SiteConfiguration values.

        Priority: values > tenant.branding_config > defaults.
        """
        defaults = {
            'logo_url': '',
            'favicon_url': '',
            'primary_color': '#1a73e8',
            'secondary_color': '#4285f4',
            'footer_text': '',
            'sender_alias': '',
        }
        merged = {**defaults}

        # Layer tenant branding
        if self.tenant.branding_config:
            merged.update({
                k: v for k, v in self.tenant.branding_config.items() if v
            })

        # Layer site config values (highest priority)
        if self.values:
            merged.update({
                k: v for k, v in self.values.items() if v
            })

        return merged
