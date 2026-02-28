"""
Cross-tenant API isolation enforcement.

@spec: multi-tenancy-architecture_spec.md
@covers: AC-TEN-007, AC-TEN-008, AC-TEN-010, AC-TEN-012

SECURITY-CRITICAL: Any cross-tenant data leakage is P0.
All enterprise-scoped API endpoints MUST use TenantIsolationMixin
or enforce_tenant_isolation to prevent cross-tenant access.
"""

import functools
import logging

from django.conf import settings
from rest_framework import status
from rest_framework.exceptions import PermissionDenied

logger = logging.getLogger(__name__)


def get_request_tenant_uuid(request):
    """
    Get the tenant UUID for the current request.

    Returns the enterprise_customer_uuid attached by tenant middleware,
    or None for non-tenant requests.
    """
    return (
        getattr(request, 'tenant_uuid', None)
        or getattr(request, '_tenant_uuid', None)
    )


def get_user_tenant_uuid(user):
    """
    Resolve tenant UUID for a user via EnterpriseCustomerUser linkage.

    Returns UUID string or None.
    """
    if not user or not user.is_authenticated:
        return None

    try:
        from enterprise.models import EnterpriseCustomerUser
        ecu = EnterpriseCustomerUser.objects.filter(
            user_id=user.id,
            active=True,
        ).select_related('enterprise_customer').first()
        if ecu:
            return str(ecu.enterprise_customer.uuid)
    except (ImportError, Exception):
        pass

    # Fallback: middleware-attached UUID
    return None


def check_tenant_access(request, target_tenant_uuid):
    """
    Check if the request has access to the target tenant's data.

    Rules:
    - Platform superusers can access all tenants
    - Enterprise admins can only access their own tenant
    - Non-enterprise users are denied access to tenant-scoped resources

    Returns True if access is allowed, raises PermissionDenied otherwise.
    """
    if not target_tenant_uuid:
        return True  # Non-tenant-scoped resource

    # Superusers bypass tenant isolation
    if request.user.is_superuser:
        return True

    request_tenant = get_request_tenant_uuid(request)
    user_tenant = get_user_tenant_uuid(request.user)

    # Use request tenant or user tenant
    caller_tenant = request_tenant or user_tenant

    if not caller_tenant:
        logger.warning(
            "Tenant access denied: user %s has no tenant context, "
            "attempted access to tenant %s",
            request.user.id, target_tenant_uuid,
        )
        raise PermissionDenied(
            "You do not have access to this tenant's resources."
        )

    if str(caller_tenant) != str(target_tenant_uuid):
        logger.warning(
            "Cross-tenant access blocked: user %s (tenant %s) "
            "attempted access to tenant %s",
            request.user.id, caller_tenant, target_tenant_uuid,
        )
        raise PermissionDenied(
            "You do not have access to this tenant's resources."
        )

    return True


def enforce_tenant_isolation(view_func):
    """
    Decorator for function-based views that enforces tenant isolation.

    The view function must accept `tenant_uuid` as a keyword argument.
    """
    @functools.wraps(view_func)
    def wrapper(request, *args, **kwargs):
        target_tenant = kwargs.get('tenant_uuid') or kwargs.get('enterprise_uuid')
        if target_tenant:
            check_tenant_access(request, target_tenant)
        return view_func(request, *args, **kwargs)
    return wrapper


class TenantIsolationMixin:
    """
    DRF view mixin that enforces cross-tenant isolation.

    Ensures that API consumers can only access data belonging
    to their own enterprise tenant. Superusers bypass this check.

    Usage:
        class MyCatalogView(TenantIsolationMixin, APIView):
            def get_tenant_uuid(self, request):
                return request.query_params.get('enterprise_uuid')
    """

    def get_tenant_uuid(self, request):
        """
        Override to extract the target tenant UUID from the request.

        Default: uses tenant UUID from middleware.
        """
        return get_request_tenant_uuid(request)

    def check_permissions(self, request):
        """Enforce tenant isolation before standard permission checks."""
        super().check_permissions(request)
        target_tenant = self.get_tenant_uuid(request)
        if target_tenant:
            check_tenant_access(request, target_tenant)

    def filter_queryset_by_tenant(self, queryset, tenant_uuid_field='enterprise_customer_uuid'):
        """
        Filter a queryset to only include records for the request's tenant.

        For superusers, returns the full queryset.
        For enterprise users, filters by their tenant UUID.
        """
        request = self.request
        if request.user.is_superuser:
            return queryset

        caller_tenant = get_request_tenant_uuid(request) or get_user_tenant_uuid(request.user)
        if not caller_tenant:
            return queryset.none()

        return queryset.filter(**{tenant_uuid_field: caller_tenant})
