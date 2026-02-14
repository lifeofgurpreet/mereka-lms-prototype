"""
xAPI event tagging with enterprise_customer_uuid.

@spec: multi-tenancy-architecture_spec.md
@covers: xAPI event producer tags events with enterprise_customer_uuid

All xAPI events produced by tenant learners are tagged with
the enterprise_customer_uuid for analytics isolation in ClickHouse.
"""

import logging

from django.conf import settings

logger = logging.getLogger(__name__)


def get_enterprise_uuid_for_user(user):
    """
    Resolve the enterprise_customer_uuid for a user.

    Checks EnterpriseCustomerUser linkage via edx-enterprise,
    falls back to TenantSiteMapping lookup.

    Returns UUID string or None if user is not enterprise-linked.
    """
    if not user or not user.is_authenticated:
        return None

    # Try edx-enterprise EnterpriseCustomerUser
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

    # Fallback: TenantSiteMapping via current site
    try:
        from .models import TenantSiteMapping
        from django.contrib.sites.models import Site
        current_site = Site.objects.get_current()
        mapping = TenantSiteMapping.get_by_site(current_site)
        if mapping:
            return str(mapping.enterprise_customer_uuid)
    except Exception:
        pass

    return None


def tag_xapi_event(event_data, user=None, enterprise_uuid=None):
    """
    Tag an xAPI event dict with enterprise_customer_uuid.

    If enterprise_uuid is not provided, resolves from user.
    The column in ClickHouse is nullable — None is valid for
    non-enterprise users.

    Args:
        event_data: dict containing xAPI event fields
        user: Django User instance (optional)
        enterprise_uuid: Pre-resolved UUID string (optional)

    Returns:
        Modified event_data dict with enterprise_customer_uuid field
    """
    if enterprise_uuid is None and user is not None:
        enterprise_uuid = get_enterprise_uuid_for_user(user)

    event_data['enterprise_customer_uuid'] = enterprise_uuid

    if enterprise_uuid:
        logger.debug(
            "xAPI event tagged with enterprise_customer_uuid=%s",
            enterprise_uuid,
        )

    return event_data


def get_clickhouse_schema_extension():
    """
    Return the ClickHouse column definition for enterprise_customer_uuid.

    This is used by migration/setup scripts to extend the xAPI events table.
    The column MUST be nullable (existing events have no UUID).

    Returns:
        SQL string for ALTER TABLE
    """
    return (
        "ALTER TABLE xapi_events_all "
        "ADD COLUMN IF NOT EXISTS enterprise_customer_uuid Nullable(UUID) "
        "AFTER org_id"
    )
