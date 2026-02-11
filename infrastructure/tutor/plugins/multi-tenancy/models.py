# @covers AC-001, AC-002
# @spec: multi-tenancy-architecture_spec.md
"""
Tenant configuration model extending Open edX EnterpriseCustomer.

EnterpriseCustomer already provides: uuid, name, slug, site, active.
TenantConfig adds: branding, SSO config, feature flags, and provisioning metadata.

Isolation is at the ORM queryset level — NOT separate databases.
"""

from django.db import models


class TenantConfig(models.Model):
    """Extended configuration for an EnterpriseCustomer acting as a tenant."""

    enterprise_customer = models.OneToOneField(
        "enterprise.EnterpriseCustomer",
        on_delete=models.CASCADE,
        related_name="tenant_config",
        help_text="The EnterpriseCustomer this tenant configuration extends.",
    )
    slug = models.SlugField(
        max_length=63,
        unique=True,
        db_index=True,
        help_text="URL-safe tenant identifier (e.g. 'acme-corp'). Must be unique.",
    )
    branding_config = models.JSONField(
        default=dict,
        blank=True,
        help_text=(
            "Per-tenant branding overrides: logo_url, favicon_url, "
            "primary_color, secondary_color, footer_content."
        ),
    )
    sso_config = models.JSONField(
        default=dict,
        blank=True,
        help_text="SSO/SAML/OIDC configuration for this tenant (idp_slug, entity_id).",
    )
    feature_flags = models.JSONField(
        default=dict,
        blank=True,
        help_text="Per-tenant feature flag overrides (key → bool).",
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Whether this tenant is currently active.",
    )
    provisioned_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Timestamp when this tenant was first provisioned.",
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="Timestamp of last configuration change.",
    )

    class Meta:
        app_label = "mereka_tenancy"
        verbose_name = "Tenant Configuration"
        verbose_name_plural = "Tenant Configurations"

    def __str__(self):
        return f"TenantConfig({self.slug})"
