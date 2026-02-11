"""
Views for MFE OAuth fix.

This module provides a fixed version of the mfe_context endpoint that properly
returns OAuth providers for the current site.
"""

# @spec platform-middleware-custom-apps AC-MPC-013: Provide /api/mfe_context endpoint with OAuth providers
# @spec platform-middleware-custom-apps AC-MPC-015: Query OAuth2ProviderConfig for current site
# @spec platform-middleware-custom-apps AC-MPC-016: Rename "Authentik" providers to "Mereka"
# @spec auth-sso-enterprise: Support OAuth provider visibility for MFE login pages

import logging
from django.conf import settings
from django.contrib.sites.shortcuts import get_current_site
from django.http import JsonResponse
from django.views import View
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt

logger = logging.getLogger(__name__)


@method_decorator(csrf_exempt, name='dispatch')
class MFEContextView(View):
    """
    API endpoint that returns OAuth provider context for MFE authentication.

    This view fixes the issue where OAuth providers were not being returned
    for the academyv2.mereka.io site (site_id=6).
    """

    def get(self, request):
        """
        Handle GET request to return OAuth provider context.

        Returns:
            JsonResponse with contextData containing OAuth providers.
        """
        try:
            # Get the current site
            current_site = get_current_site(request)
            site_id = current_site.id

            logger.info(f"MFE context requested for site: {current_site.domain} (ID: {site_id})")

            # Initialize response data
            context_data = {
                'contextData': {
                    'providers': []
                },
                'registrationFields': {},
                'optionalFields': {}
            }

            # Try to get OAuth providers from third_party_auth
            try:
                try:
                    from common.djangoapps.third_party_auth.models import OAuth2ProviderConfig
                except ImportError:
                    from third_party_auth.models import OAuth2ProviderConfig

                # Query for enabled and visible OAuth providers for this site
                providers = OAuth2ProviderConfig.objects.filter(
                    site=current_site,
                    enabled=True,
                    visible=True
                ).select_related('site')

                logger.info(f"Found {providers.count()} OAuth providers for site {site_id}")

                # Build provider data for MFE
                provider_list = []
                for provider in providers:
                    # Get the backend name (e.g., 'oauth2-authentik')
                    backend_name = provider.backend_name or provider.slug or 'oauth2'
                    display_name = provider.name
                    provider_slug = (provider.slug or "").lower()
                    provider_name = (provider.name or "").lower()
                    backend_key = (backend_name or "").lower()
                    if "authentik" in provider_slug or "authentik" in provider_name or "authentik" in backend_key:
                        display_name = "Mereka"

                    # Construct the provider data
                    provider_data = {
                        'id': f"oa2-{provider.slug}" if provider.slug else f"oa2-{provider.name.lower()}",
                        'name': display_name,
                        'loginUrl': f"/auth/login/{backend_name}/?auth_entry=login&next=/dashboard",
                        'registerUrl': f"/auth/login/{backend_name}/?auth_entry=register&next=/dashboard",
                    }

                    # Add icon URL if available
                    if hasattr(provider, 'icon_class') and provider.icon_class:
                        provider_data['iconClass'] = provider.icon_class
                    if hasattr(provider, 'icon_image') and provider.icon_image:
                        provider_data['iconImage'] = str(provider.icon_image.url) if provider.icon_image else None

                    provider_list.append(provider_data)
                    logger.info(f"Added provider: {provider.name} (slug: {provider.slug}, backend: {backend_name})")

                context_data['contextData']['providers'] = provider_list

            except ImportError as e:
                logger.error(f"Failed to import third_party_auth: {e}")
            except Exception as e:
                logger.error(f"Error fetching OAuth providers: {e}", exc_info=True)

            # Try to get registration field requirements
            try:
                from openedx.core.djangoapps.user_authn.views.register import get_registration_extension_form

                # Get optional and required fields
                # This is a simplified version - adjust based on your needs
                context_data['optionalFields'] = {
                    'extended_profile': [],
                }

            except Exception as e:
                logger.warning(f"Could not fetch registration fields: {e}")

            logger.info(f"Returning {len(context_data['contextData']['providers'])} providers")
            return JsonResponse(context_data)

        except Exception as e:
            logger.error(f"Error in MFEContextView: {e}", exc_info=True)
            return JsonResponse({
                'contextData': {
                    'providers': []
                },
                'registrationFields': {},
                'optionalFields': {},
                'error': str(e)
            }, status=500)
