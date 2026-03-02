"""
Initial migration for mereka_tenancy app.

Creates the TenantConfig model that extends EnterpriseCustomer
with branding, SSO, and feature flag configuration.
"""

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ("enterprise", "__first__"),
    ]

    operations = [
        migrations.CreateModel(
            name="TenantConfig",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "slug",
                    models.SlugField(
                        db_index=True,
                        help_text="URL-safe tenant identifier (e.g. 'acme-corp'). Must be unique.",
                        max_length=63,
                        unique=True,
                    ),
                ),
                (
                    "branding_config",
                    models.JSONField(
                        blank=True,
                        default=dict,
                        help_text=(
                            "Per-tenant branding overrides: logo_url, favicon_url, "
                            "primary_color, secondary_color, footer_content."
                        ),
                    ),
                ),
                (
                    "sso_config",
                    models.JSONField(
                        blank=True,
                        default=dict,
                        help_text="SSO/SAML/OIDC configuration for this tenant (idp_slug, entity_id).",
                    ),
                ),
                (
                    "feature_flags",
                    models.JSONField(
                        blank=True,
                        default=dict,
                        help_text="Per-tenant feature flag overrides (key \u2192 bool).",
                    ),
                ),
                (
                    "is_active",
                    models.BooleanField(
                        default=True,
                        help_text="Whether this tenant is currently active.",
                    ),
                ),
                (
                    "provisioned_at",
                    models.DateTimeField(
                        auto_now_add=True,
                        help_text="Timestamp when this tenant was first provisioned.",
                    ),
                ),
                (
                    "updated_at",
                    models.DateTimeField(
                        auto_now=True,
                        help_text="Timestamp of last configuration change.",
                    ),
                ),
                (
                    "enterprise_customer",
                    models.OneToOneField(
                        help_text="The EnterpriseCustomer this tenant configuration extends.",
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="tenant_config",
                        to="enterprise.enterprisecustomer",
                    ),
                ),
            ],
            options={
                "verbose_name": "Tenant Configuration",
                "verbose_name_plural": "Tenant Configurations",
            },
        ),
    ]
