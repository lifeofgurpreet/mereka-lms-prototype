"""
API views for tenant configuration and branding.

@spec: multi-tenancy-architecture_spec.md
"""

import logging

from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .isolation import TenantIsolationMixin, get_request_tenant_uuid
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


class TenantCatalogIsolationView(TenantIsolationMixin, APIView):
    """
    Enterprise catalog listing with cross-tenant isolation.

    AC-TEN-007: Tenant A admin sees zero catalogs from tenant B.
    """

    permission_classes = [IsAuthenticated]

    def get_tenant_uuid(self, request):
        return get_request_tenant_uuid(request) or request.query_params.get('enterprise_uuid')

    def get(self, request):
        """List enterprise catalogs for the requesting tenant only."""
        tenant_uuid = self.get_tenant_uuid(request)
        if not tenant_uuid:
            return Response({'results': [], 'count': 0})

        try:
            from enterprise.models import EnterpriseCustomerCatalog
            catalogs = EnterpriseCustomerCatalog.objects.filter(
                enterprise_customer__uuid=tenant_uuid,
            ).values('uuid', 'title', 'created')
            return Response({
                'results': list(catalogs),
                'count': catalogs.count(),
            })
        except ImportError:
            return Response({
                'results': [],
                'count': 0,
                'detail': 'Enterprise catalogs not available',
            })


class TenantAnalyticsIsolationView(TenantIsolationMixin, APIView):
    """
    Analytics summary with cross-tenant isolation.

    AC-TEN-010: Tenant B admin sees zero events from tenant A.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Return analytics event count for the requesting tenant only."""
        tenant_uuid = get_request_tenant_uuid(request)
        if not tenant_uuid:
            return Response({
                'tenant_uuid': None,
                'event_count': 0,
                'detail': 'No tenant context',
            })

        # Try ClickHouse if available
        event_count = 0
        try:
            from event_sink_clickhouse.sinks import ClickHouseConnection
            conn = ClickHouseConnection()
            result = conn.execute(
                "SELECT count() FROM xapi_events_all "
                f"WHERE enterprise_customer_uuid = '{tenant_uuid}'"
            )
            event_count = result[0][0] if result else 0
        except (ImportError, Exception):
            pass  # ClickHouse not available

        return Response({
            'tenant_uuid': tenant_uuid,
            'event_count': event_count,
        })
