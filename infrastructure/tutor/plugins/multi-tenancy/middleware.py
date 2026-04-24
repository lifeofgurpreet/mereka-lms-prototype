# @covers AC-MTA-012, AC-MTA-013, AC-MTA-014
# @spec: multi-tenancy-architecture_spec.md
"""
Tenant resolution middleware for Open edX multi-tenancy.

Resolves tenant from request hostname using the chain:
  hostname → Site → SiteConfiguration → EnterpriseCustomer → TenantConfig

Sets request.tenant_uuid and request.tenant_slug for downstream code.
Adds X-Tenant-ID response header for observability.
"""

import logging

logger = logging.getLogger(__name__)


class TenantResolutionMiddleware:
    """Resolve tenant context from the request hostname."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Public tenant context used by newer code paths.
        request.tenant_uuid = None
        request.tenant_slug = None
        # Backward-compatible aliases used by existing tenant-cache helpers.
        request._tenant_uuid = None
        request._tenant_slug = None

        host = request.get_host().split(":")[0]

        try:
            from django.contrib.sites.models import Site

            site = Site.objects.filter(domain__iexact=host).select_related().first()
            if site is None:
                # Strip common prefixes (apps., studio., preview.) and retry.
                for prefix in ("apps.", "studio.", "preview."):
                    if host.startswith(prefix):
                        bare = host[len(prefix) :]
                        site = Site.objects.filter(domain__iexact=bare).first()
                        if site is not None:
                            break

            if site is not None:
                site_config = getattr(site, "configuration", None)
                if site_config is not None:
                    enterprise_uuid = site_config.site_values.get("ENTERPRISE_CUSTOMER_UUID")
                    if enterprise_uuid:
                        tenant_uuid = str(enterprise_uuid)
                        request.tenant_uuid = tenant_uuid
                        request._tenant_uuid = tenant_uuid
                        # Attempt to resolve slug from TenantConfig.
                        try:
                            from mereka_tenancy.models import TenantConfig

                            tc = TenantConfig.objects.filter(
                                enterprise_customer__uuid=enterprise_uuid,
                                is_active=True,
                            ).first()
                            if tc:
                                request.tenant_slug = tc.slug
                                request._tenant_slug = tc.slug
                        except Exception:
                            logger.debug(
                                "TenantConfig lookup failed for uuid=%s",
                                enterprise_uuid,
                                exc_info=True,
                            )
        except Exception:
            logger.debug("Tenant resolution failed for host=%s", host, exc_info=True)

        response = self.get_response(request)

        tenant_uuid = request.tenant_uuid or request._tenant_uuid
        if tenant_uuid:
            response["X-Tenant-ID"] = str(tenant_uuid)

        return response
