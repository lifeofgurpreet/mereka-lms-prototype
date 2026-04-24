import uuid

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ("sites", "0002_alter_domain_unique"),
    ]

    operations = [
        migrations.CreateModel(
            name="TenantSiteMapping",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("enterprise_customer_uuid", models.UUIDField(db_index=True, help_text="EnterpriseCustomer UUID from edx-enterprise", unique=True)),
                ("slug", models.SlugField(db_index=True, help_text="URL-safe tenant identifier (e.g., 'acme-corp')", max_length=100, unique=True)),
                ("name", models.CharField(help_text="Tenant display name", max_length=255)),
                ("is_active", models.BooleanField(db_index=True, default=True, help_text="Whether this tenant is active")),
                (
                    "branding_config",
                    models.JSONField(
                        blank=True,
                        default=dict,
                        help_text=(
                            "Per-tenant branding: logo_url, favicon_url, primary_color, "
                            "secondary_color, footer_text, sender_alias"
                        ),
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "site",
                    models.OneToOneField(
                        help_text="Django Site for this tenant (domain routing)",
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="tenant_mapping",
                        to="sites.site",
                    ),
                ),
            ],
            options={
                "verbose_name": "Tenant Site Mapping",
                "verbose_name_plural": "Tenant Site Mappings",
                "db_table": "openedx_tenant_cache_tenantsitemapping",
            },
        ),
        migrations.CreateModel(
            name="TenantSiteConfiguration",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                (
                    "values",
                    models.JSONField(
                        blank=True,
                        default=dict,
                        help_text=(
                            "SiteConfiguration JSON overlay: "
                            "logo_url, favicon_url, primary_color, secondary_color, "
                            "footer_text, sender_alias, custom_css_url, "
                            "PLATFORM_NAME, SITE_NAME, etc."
                        ),
                    ),
                ),
                (
                    "mfe_config",
                    models.JSONField(
                        blank=True,
                        default=dict,
                        help_text=(
                            "MFE-specific configuration injected at runtime: "
                            "LOGO_URL, LOGO_TRADEMARK_URL, LOGO_WHITE_URL, "
                            "FAVICON_URL, SITE_NAME, COLORS, MARKETING_URLS"
                        ),
                    ),
                ),
                ("is_active", models.BooleanField(default=True, help_text="Whether this configuration is active")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "tenant",
                    models.OneToOneField(
                        help_text="Tenant this configuration belongs to",
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="site_config",
                        to="openedx_tenant_cache.tenantsitemapping",
                    ),
                ),
            ],
            options={
                "verbose_name": "Tenant Site Configuration",
                "verbose_name_plural": "Tenant Site Configurations",
                "db_table": "openedx_tenant_cache_tenantsiteconfiguration",
            },
        ),
    ]
