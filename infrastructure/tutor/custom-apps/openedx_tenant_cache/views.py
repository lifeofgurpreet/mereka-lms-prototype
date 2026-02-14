"""
API views for tenant configuration and branding.

@spec: multi-tenancy-architecture_spec.md
"""

import logging

from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import TenantSiteConfiguration, TenantSiteMapping
from .serializers import TenantSiteConfigurationSerializer, TenantSiteMappingSerializer

logger = logging.getLogger(__name__)


class TenantListView(APIView):
    """List active tenants (admin only)."""

    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        """List all active tenant mappings."""
        tenants = TenantSiteMapping.objects.filter(is_active=True).select_related('site')
        serializer = TenantSiteMappingSerializer(tenants, many=True)
        return Response(serializer.data)


class TenantBrandingView(APIView):
    """Get branding configuration for a tenant."""

    permission_classes = [IsAuthenticated]

    def get(self, request, tenant_slug):
        """Get branding config for a specific tenant."""
        from .branding import get_tenant_branding

        mapping = TenantSiteMapping.get_by_slug(tenant_slug)
        if not mapping:
            return Response({'error': 'Tenant not found'}, status=404)

        branding = get_tenant_branding(str(mapping.enterprise_customer_uuid))
        return Response(branding)
