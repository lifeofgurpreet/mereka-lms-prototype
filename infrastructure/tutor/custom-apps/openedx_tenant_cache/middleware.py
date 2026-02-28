"""
Tenant-aware middleware for cache namespacing and request metrics.

@spec: multi-tenancy-architecture_spec.md
@covers: Redis cache isolation, Prometheus tenant metrics
"""

import logging
import time

from django.conf import settings
from django.utils.deprecation import MiddlewareMixin

logger = logging.getLogger(__name__)


class TenantCacheMiddleware(MiddlewareMixin):
    """
    Middleware that resolves the tenant for each request and attaches
    the enterprise_customer_uuid to the request for downstream use.

    Also records Prometheus metrics for per-tenant request counts.
    """

    def process_request(self, request):
        """Resolve tenant UUID from request and attach to request object."""
        # Backward-compatible private attributes.
        request._tenant_uuid = None
        request._tenant_slug = None
        # Public aliases used by newer middleware and helpers.
        request.tenant_uuid = None
        request.tenant_slug = None
        request._tenant_start_time = time.monotonic()

        try:
            from django.contrib.sites.models import Site
            current_site = Site.objects.get_current(request)

            from .models import TenantSiteMapping
            mapping = TenantSiteMapping.get_by_site(current_site)
            if mapping:
                tenant_uuid = str(mapping.enterprise_customer_uuid)
                request._tenant_uuid = tenant_uuid
                request.tenant_uuid = tenant_uuid
                request._tenant_slug = mapping.slug
                request.tenant_slug = mapping.slug
        except Exception:
            pass  # Non-tenant request; proceed without tenant context

    def process_response(self, request, response):
        """Record per-tenant request metrics."""
        tenant_uuid = getattr(request, '_tenant_uuid', None)

        if tenant_uuid:
            try:
                from .metrics import record_tenant_request
                elapsed = time.monotonic() - getattr(request, '_tenant_start_time', time.monotonic())
                record_tenant_request(tenant_uuid, elapsed)
            except Exception:
                pass

        return response
