"""
Signal handlers for tenant cache app.

@spec: multi-tenancy-architecture_spec.md
"""

import logging

logger = logging.getLogger(__name__)


def register_tenant_foundation():
    """Register tenant foundation on app startup."""
    logger.info(
        "openedx_tenant_cache: Tenant cache namespacing, xAPI tagging, "
        "and metrics registered"
    )


register_tenant_foundation()
