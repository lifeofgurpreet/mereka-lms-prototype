"""
Redis cache key namespacing for multi-tenant isolation.

@spec: multi-tenancy-architecture_spec.md
@covers: Redis cache keys namespaced by tenant UUID

Format: enterprise:{uuid}:{key_type}:{key_id}

Tenant-specific cache MUST be prefixed with enterprise_customer_uuid.
Shared platform data (non-tenant-scoped) MAY use shared cache keys.
"""

import logging

from django.core.cache import cache

logger = logging.getLogger(__name__)

# Cache namespace format (spec requirement)
NAMESPACE_FORMAT = "enterprise:{uuid}:{key_type}:{key_id}"


def tenant_cache_key(enterprise_uuid, key_type, key_id):
    """
    Build a namespaced cache key for tenant-specific data.

    Args:
        enterprise_uuid: EnterpriseCustomer UUID string
        key_type: Category of cached data (e.g., 'catalog', 'config', 'branding')
        key_id: Specific item identifier

    Returns:
        Namespaced cache key string

    Example:
        tenant_cache_key('acme-uuid', 'catalog', 'course-v1:Mereka+ENT101+2026')
        => 'enterprise:acme-uuid:catalog:course-v1:Mereka+ENT101+2026'
    """
    return f"enterprise:{enterprise_uuid}:{key_type}:{key_id}"


def tenant_cache_get(enterprise_uuid, key_type, key_id, default=None):
    """
    Get a value from tenant-namespaced cache.

    Returns default if key not found or cache unavailable.
    """
    key = tenant_cache_key(enterprise_uuid, key_type, key_id)
    try:
        return cache.get(key, default)
    except Exception:
        logger.warning("Cache get failed for key %s", key)
        return default


def tenant_cache_set(enterprise_uuid, key_type, key_id, value, timeout=None):
    """
    Set a value in tenant-namespaced cache.

    Args:
        enterprise_uuid: Tenant UUID
        key_type: Cache category
        key_id: Item identifier
        value: Value to cache
        timeout: TTL in seconds (None = default)
    """
    key = tenant_cache_key(enterprise_uuid, key_type, key_id)
    try:
        cache.set(key, value, timeout=timeout)
    except Exception:
        logger.warning("Cache set failed for key %s", key)


def tenant_cache_delete(enterprise_uuid, key_type, key_id):
    """Delete a value from tenant-namespaced cache."""
    key = tenant_cache_key(enterprise_uuid, key_type, key_id)
    try:
        cache.delete(key)
    except Exception:
        logger.warning("Cache delete failed for key %s", key)


def tenant_cache_clear_all(enterprise_uuid):
    """
    Clear all cached data for a tenant.

    Uses key pattern matching if available (Redis), otherwise
    logs a warning that manual cleanup is needed.
    """
    pattern = f"enterprise:{enterprise_uuid}:*"
    try:
        # Try Redis-specific pattern delete
        client = cache.client.get_client()
        if hasattr(client, 'keys'):
            keys = client.keys(pattern)
            if keys:
                client.delete(*keys)
                logger.info("Cleared %d cache keys for tenant %s", len(keys), enterprise_uuid)
                return len(keys)
    except Exception:
        logger.warning(
            "Pattern-based cache clear unavailable for tenant %s; "
            "individual key deletion required",
            enterprise_uuid,
        )
    return 0


class TenantCacheNamespace:
    """
    Context manager for tenant-scoped cache operations.

    Usage:
        with TenantCacheNamespace('acme-uuid') as ns:
            ns.set('config', 'theme', {'primary_color': '#ff0000'})
            theme = ns.get('config', 'theme')
    """

    def __init__(self, enterprise_uuid):
        self.uuid = str(enterprise_uuid)

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def key(self, key_type, key_id):
        """Build namespaced key."""
        return tenant_cache_key(self.uuid, key_type, key_id)

    def get(self, key_type, key_id, default=None):
        """Get from tenant namespace."""
        return tenant_cache_get(self.uuid, key_type, key_id, default)

    def set(self, key_type, key_id, value, timeout=None):
        """Set in tenant namespace."""
        tenant_cache_set(self.uuid, key_type, key_id, value, timeout)

    def delete(self, key_type, key_id):
        """Delete from tenant namespace."""
        tenant_cache_delete(self.uuid, key_type, key_id)

    def clear_all(self):
        """Clear all keys in this namespace."""
        return tenant_cache_clear_all(self.uuid)
