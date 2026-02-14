"""
Superset Row-Level Security (RLS) policy definitions for ClickHouse.

@spec: multi-tenancy-architecture_spec.md
@covers: AC-TEN-013 — Superset RLS policies enforce per-tenant row filtering

These policies are applied in Superset to ensure analytics dashboards
show only data belonging to the requesting tenant.
"""

import logging

logger = logging.getLogger(__name__)

# RLS policy definitions for Superset
# Each policy maps a ClickHouse table to a filter clause
# that restricts rows to the current user's enterprise_customer_uuid.
SUPERSET_RLS_POLICIES = {
    'xapi_events_all': {
        'description': 'Filter xAPI events by enterprise_customer_uuid',
        'clause': "enterprise_customer_uuid = '{{ tenant_uuid }}'",
        'tables': ['xapi_events_all'],
        'group_key': 'enterprise_customer_uuid',
    },
    'course_enrollments': {
        'description': 'Filter enrollments by org_id mapped to tenant',
        'clause': "org_id IN (SELECT org_id FROM tenant_org_mapping WHERE enterprise_customer_uuid = '{{ tenant_uuid }}')",
        'tables': ['course_enrollments'],
        'group_key': 'org_id',
    },
    'grades': {
        'description': 'Filter grades by org_id mapped to tenant',
        'clause': "org_id IN (SELECT org_id FROM tenant_org_mapping WHERE enterprise_customer_uuid = '{{ tenant_uuid }}')",
        'tables': ['grades', 'persistent_grades'],
        'group_key': 'org_id',
    },
    'certificates': {
        'description': 'Filter certificates by org_id mapped to tenant',
        'clause': "org_id IN (SELECT org_id FROM tenant_org_mapping WHERE enterprise_customer_uuid = '{{ tenant_uuid }}')",
        'tables': ['certificates'],
        'group_key': 'org_id',
    },
}


def get_rls_policy_sql(table_name, tenant_uuid):
    """
    Get the SQL WHERE clause for a given table and tenant.

    Args:
        table_name: ClickHouse table name
        tenant_uuid: Enterprise customer UUID

    Returns:
        SQL WHERE clause string, or None if no policy defined
    """
    policy = SUPERSET_RLS_POLICIES.get(table_name)
    if not policy:
        return None
    return policy['clause'].replace('{{ tenant_uuid }}', str(tenant_uuid))


def get_all_rls_policies():
    """Return all RLS policy definitions for Superset configuration."""
    return SUPERSET_RLS_POLICIES


def generate_superset_rls_config(tenant_uuid, tenant_name):
    """
    Generate Superset RLS configuration JSON for a tenant.

    This can be imported into Superset via the API or CLI.

    Args:
        tenant_uuid: Enterprise customer UUID
        tenant_name: Human-readable tenant name

    Returns:
        List of RLS rule dicts for Superset API
    """
    rules = []
    for key, policy in SUPERSET_RLS_POLICIES.items():
        rules.append({
            'name': f'{tenant_name} - {policy["description"]}',
            'filter_type': 'Regular',
            'tables': policy['tables'],
            'clause': policy['clause'].replace('{{ tenant_uuid }}', str(tenant_uuid)),
            'group_key': policy['group_key'],
            'description': (
                f'Auto-generated RLS policy for tenant {tenant_name} '
                f'(UUID: {tenant_uuid})'
            ),
        })
    return rules
