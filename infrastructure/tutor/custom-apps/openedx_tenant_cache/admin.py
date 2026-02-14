"""
Django admin configuration for tenant models.

@spec: multi-tenancy-architecture_spec.md
"""

from django.contrib import admin

from .models import TenantSiteConfiguration, TenantSiteMapping


@admin.register(TenantSiteMapping)
class TenantSiteMappingAdmin(admin.ModelAdmin):
    """Admin for tenant site mappings."""

    list_display = [
        'name', 'slug', 'enterprise_customer_uuid',
        'site', 'is_active', 'updated_at',
    ]
    list_filter = ['is_active']
    search_fields = ['name', 'slug', 'enterprise_customer_uuid']
    readonly_fields = ['id', 'created_at', 'updated_at']
    raw_id_fields = ['site']


@admin.register(TenantSiteConfiguration)
class TenantSiteConfigurationAdmin(admin.ModelAdmin):
    """Admin for tenant site configurations."""

    list_display = ['tenant', 'is_active', 'updated_at']
    list_filter = ['is_active']
    readonly_fields = ['id', 'created_at', 'updated_at']
    raw_id_fields = ['tenant']
