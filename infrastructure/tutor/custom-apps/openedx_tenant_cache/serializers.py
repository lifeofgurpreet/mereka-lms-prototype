"""
DRF serializers for tenant models.

@spec: multi-tenancy-architecture_spec.md
"""

from rest_framework import serializers

from .models import TenantSiteConfiguration, TenantSiteMapping


class TenantSiteMappingSerializer(serializers.ModelSerializer):
    """Serializer for tenant site mappings."""

    site_domain = serializers.CharField(source='site.domain', read_only=True)

    class Meta:
        model = TenantSiteMapping
        fields = [
            'id', 'enterprise_customer_uuid', 'site', 'site_domain',
            'slug', 'name', 'is_active', 'branding_config',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class TenantSiteConfigurationSerializer(serializers.ModelSerializer):
    """Serializer for tenant site configurations."""

    tenant_name = serializers.CharField(source='tenant.name', read_only=True)

    class Meta:
        model = TenantSiteConfiguration
        fields = [
            'id', 'tenant', 'tenant_name', 'values', 'mfe_config',
            'is_active', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
