"""
Multi-tenant library quotas and rate limiting.

@covers: AC-LIB-026 (new tenant can create immediately),
         AC-LIB-029 (page loads <2s at scale)
"""
import logging
import time
from functools import wraps

from django.conf import settings
from django.core.cache import cache
from django.utils import timezone

logger = logging.getLogger(__name__)

# Default quota limits per tenant
DEFAULT_LIBRARY_QUOTA = 100
DEFAULT_COMPONENT_QUOTA = 10000
DEFAULT_RATE_LIMIT_PER_MINUTE = 60


def get_tenant_quota(tenant_uuid, quota_type='libraries'):
    """
    Get quota limit for a tenant.

    Checks for tenant-specific override, falls back to defaults.
    """
    cache_key = f'library_quota:{tenant_uuid}:{quota_type}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    defaults = {
        'libraries': getattr(settings, 'LIBRARY_TENANT_MAX_LIBRARIES', DEFAULT_LIBRARY_QUOTA),
        'components': getattr(settings, 'LIBRARY_TENANT_MAX_COMPONENTS', DEFAULT_COMPONENT_QUOTA),
    }

    # Check for tenant-specific override
    try:
        from .models import TenantLibraryQuota
        quota = TenantLibraryQuota.objects.get(tenant_uuid=tenant_uuid)
        value = getattr(quota, f'max_{quota_type}', defaults.get(quota_type, 0))
    except Exception:
        value = defaults.get(quota_type, 0)

    cache.set(cache_key, value, timeout=300)
    return value


def check_quota(tenant_uuid, quota_type='libraries'):
    """
    Check if tenant has remaining quota.

    Returns (allowed, current_usage, max_allowed).
    """
    from .models import LibraryMetadata, LibraryComponent

    max_allowed = get_tenant_quota(tenant_uuid, quota_type)

    if quota_type == 'libraries':
        current = LibraryMetadata.objects.filter(
            tenant_uuid=tenant_uuid, is_deleted=False,
        ).count()
    elif quota_type == 'components':
        current = LibraryComponent.objects.filter(
            library__tenant_uuid=tenant_uuid, is_deleted=False,
        ).count()
    else:
        return True, 0, 0

    return current < max_allowed, current, max_allowed


def check_rate_limit(tenant_uuid, action='api_call'):
    """
    Rate limiting per org/tenant using Redis cache.

    Returns (allowed, current_count, limit).
    """
    limit = getattr(settings, 'LIBRARY_RATE_LIMIT_PER_MINUTE', DEFAULT_RATE_LIMIT_PER_MINUTE)
    cache_key = f'library_ratelimit:{tenant_uuid}:{action}'

    current = cache.get(cache_key, 0)
    if current >= limit:
        logger.warning(
            "Rate limit exceeded: tenant=%s, action=%s, count=%d, limit=%d",
            tenant_uuid, action, current, limit,
        )
        return False, current, limit

    cache.set(cache_key, current + 1, timeout=60)
    return True, current + 1, limit


def enforce_quota(view_func):
    """Decorator to enforce library quotas on create operations."""
    @wraps(view_func)
    def wrapper(self, request, *args, **kwargs):
        if not getattr(settings, 'LIBRARY_QUOTAS_ENABLED', False):
            return view_func(self, request, *args, **kwargs)

        try:
            from openedx_tenant_cache.isolation import get_user_tenant_uuid
            tenant_uuid = get_user_tenant_uuid(request.user)
        except ImportError:
            tenant_uuid = None

        if tenant_uuid:
            allowed, current, maximum = check_quota(tenant_uuid)
            if not allowed:
                from rest_framework.response import Response
                return Response(
                    {
                        'error': f'Library quota exceeded ({current}/{maximum})',
                        'current': current,
                        'maximum': maximum,
                    },
                    status=429,
                )

        return view_func(self, request, *args, **kwargs)
    return wrapper


def enforce_rate_limit(view_func):
    """Decorator to enforce rate limiting per tenant."""
    @wraps(view_func)
    def wrapper(self, request, *args, **kwargs):
        if not getattr(settings, 'LIBRARY_RATE_LIMITING_ENABLED', False):
            return view_func(self, request, *args, **kwargs)

        try:
            from openedx_tenant_cache.isolation import get_user_tenant_uuid
            tenant_uuid = get_user_tenant_uuid(request.user)
        except ImportError:
            tenant_uuid = None

        if tenant_uuid:
            allowed, current, limit = check_rate_limit(tenant_uuid)
            if not allowed:
                from rest_framework.response import Response
                return Response(
                    {
                        'error': 'Rate limit exceeded',
                        'retry_after_seconds': 60,
                    },
                    status=429,
                )

        return view_func(self, request, *args, **kwargs)
    return wrapper
