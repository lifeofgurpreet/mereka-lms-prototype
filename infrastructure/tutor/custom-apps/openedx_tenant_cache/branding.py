"""
MFE branding configuration injection from SiteConfiguration.

@spec: multi-tenancy-architecture_spec.md
@covers: MFE branding configuration injection working

Reads TenantSiteConfiguration at runtime and provides branding
data to MFE via the mfe_config API endpoint.
"""

import logging

from django.conf import settings

from .cache import tenant_cache_get, tenant_cache_set

logger = logging.getLogger(__name__)

# Cache TTL for branding config (5 minutes)
BRANDING_CACHE_TTL = 300


def get_tenant_branding(enterprise_uuid):
    """
    Get branding configuration for a tenant.

    Checks cache first, falls back to database lookup.
    Returns a dict with MFE-compatible branding keys.
    """
    # Try cache
    cached = tenant_cache_get(enterprise_uuid, 'branding', 'mfe_config')
    if cached is not None:
        from .metrics import record_cache_hit
        record_cache_hit(enterprise_uuid)
        return cached

    from .metrics import record_cache_miss
    record_cache_miss(enterprise_uuid)

    # Database lookup
    branding = _load_branding_from_db(enterprise_uuid)

    # Cache the result
    tenant_cache_set(enterprise_uuid, 'branding', 'mfe_config', branding, BRANDING_CACHE_TTL)

    return branding


def _load_branding_from_db(enterprise_uuid):
    """Load branding from TenantSiteConfiguration."""
    from .models import TenantSiteMapping

    defaults = {
        'LOGO_URL': getattr(settings, 'DEFAULT_ORG_LOGO_URL', ''),
        'LOGO_TRADEMARK_URL': '',
        'LOGO_WHITE_URL': '',
        'FAVICON_URL': '',
        'SITE_NAME': getattr(settings, 'DEFAULT_ORG_DISPLAY_NAME', 'Mereka Academy'),
        'PRIMARY_COLOR': getattr(settings, 'DEFAULT_ORG_PRIMARY_COLOR', '#1a73e8'),
        'SECONDARY_COLOR': getattr(settings, 'DEFAULT_ORG_ACCENT_COLOR', '#4285f4'),
        'ACCENT_COLOR': getattr(settings, 'DEFAULT_ORG_ACCENT_COLOR', '#295cad'),
        'TEXT_ON_PRIMARY': '#ffffff',
        'FOOTER_TEXT': '',
    }

    try:
        mapping = TenantSiteMapping.get_by_uuid(enterprise_uuid)
        if not mapping:
            return defaults

        # Check for TenantSiteConfiguration
        try:
            config = mapping.site_config
            if config and config.is_active:
                mfe = config.mfe_config or {}
                merged = config.get_merged_config()

                # Map to MFE config keys
                defaults['LOGO_URL'] = mfe.get('LOGO_URL', merged.get('logo_url', '')) or defaults['LOGO_URL']
                defaults['LOGO_TRADEMARK_URL'] = mfe.get('LOGO_TRADEMARK_URL', '') or defaults['LOGO_TRADEMARK_URL']
                defaults['LOGO_WHITE_URL'] = mfe.get('LOGO_WHITE_URL', '') or defaults['LOGO_WHITE_URL']
                defaults['FAVICON_URL'] = mfe.get('FAVICON_URL', merged.get('favicon_url', '')) or defaults['FAVICON_URL']
                defaults['SITE_NAME'] = mfe.get('SITE_NAME', mapping.name) or defaults['SITE_NAME']
                defaults['PRIMARY_COLOR'] = merged.get('primary_color', '') or defaults['PRIMARY_COLOR']
                defaults['SECONDARY_COLOR'] = merged.get('secondary_color', '') or defaults['SECONDARY_COLOR']
                defaults['ACCENT_COLOR'] = mfe.get('ACCENT_COLOR', merged.get('accent_color', '')) or defaults['ACCENT_COLOR']
                defaults['TEXT_ON_PRIMARY'] = mfe.get('TEXT_ON_PRIMARY', merged.get('text_on_primary_color', '')) or defaults['TEXT_ON_PRIMARY']
                defaults['FOOTER_TEXT'] = merged.get('footer_text', '') or defaults['FOOTER_TEXT']

                # Include any additional MFE config
                for k, v in mfe.items():
                    if k not in defaults and v:
                        defaults[k] = v
        except Exception:
            pass  # No site config yet

        # Fall back to branding_config on mapping
        if mapping.branding_config:
            bc = mapping.branding_config
            if not defaults['LOGO_URL'] and bc.get('logo_url'):
                defaults['LOGO_URL'] = bc['logo_url']
            if not defaults['FAVICON_URL'] and bc.get('favicon_url'):
                defaults['FAVICON_URL'] = bc['favicon_url']
            if not defaults['SITE_NAME']:
                defaults['SITE_NAME'] = mapping.name

    except Exception:
        logger.exception("Failed to load branding for tenant %s", enterprise_uuid)

    return defaults


def inject_mfe_branding(request, mfe_config_dict):
    """
    Inject tenant branding into MFE config response.

    Called by the mfe_config API view to overlay tenant branding
    on top of default platform MFE configuration.

    Args:
        request: Django HttpRequest (with tenant_uuid/_tenant_uuid from middleware)
        mfe_config_dict: Base MFE config dict to augment

    Returns:
        Modified mfe_config_dict with tenant branding overlay
    """
    tenant_uuid = getattr(request, 'tenant_uuid', None) or getattr(request, '_tenant_uuid', None)
    if not tenant_uuid:
        return mfe_config_dict

    # Check feature flag
    if not getattr(settings, 'ENABLE_MULTI_TENANT_BRANDING', False):
        return mfe_config_dict

    branding = get_tenant_branding(tenant_uuid)
    if branding:
        mfe_config_dict.update({
            k: v for k, v in branding.items() if v
        })

    return mfe_config_dict
