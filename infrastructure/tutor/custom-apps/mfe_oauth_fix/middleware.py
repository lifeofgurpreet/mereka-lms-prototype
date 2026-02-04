"""
Middleware to fix /api/mfe_context OAuth provider visibility.

This middleware intercepts responses from the /api/mfe_context endpoint
and ensures OAuth providers are properly included.
"""

import json
import logging
from django.utils.deprecation import MiddlewareMixin
from django.contrib.sites.shortcuts import get_current_site

logger = logging.getLogger(__name__)


class MFEOAuthFixMiddleware(MiddlewareMixin):
    """
    Middleware that fixes the /api/mfe_context endpoint response.

    This middleware intercepts the response and adds OAuth providers
    that may have been filtered out by the default endpoint logic.
    """

    def process_response(self, request, response):
        """
        Process the response and fix OAuth providers if needed.

        Args:
            request: The HTTP request
            response: The HTTP response

        Returns:
            Modified response if /api/mfe_context, otherwise original response
        """
        # Only process /api/mfe_context endpoint
        if not request.path.startswith('/api/mfe_context'):
            return response

        # Only process JSON responses with 200 status
        if response.status_code != 200:
            return response

        content_type = response.get('Content-Type', '')
        if 'application/json' not in content_type:
            return response

        try:
            # Parse the response JSON
            data = json.loads(response.content.decode('utf-8'))

            # Check if providers array is empty or missing
            context_data = data.get('contextData', {})
            providers = context_data.get('providers', [])

            if not providers:
                logger.info("Empty providers array detected in /api/mfe_context, attempting to fix...")

                # Get the current site
                current_site = get_current_site(request)
                site_id = current_site.id

                logger.info(f"Current site: {current_site.domain} (ID: {site_id})")

                # Fetch OAuth providers from database
                try:
                    try:
                        from common.djangoapps.third_party_auth.models import OAuth2ProviderConfig
                    except ImportError:
                        from third_party_auth.models import OAuth2ProviderConfig

                    # Query for enabled and visible OAuth providers for this site
                    oauth_providers = OAuth2ProviderConfig.objects.filter(
                        site=current_site,
                        enabled=True,
                        visible=True
                    ).select_related('site')

                    logger.info(f"Found {oauth_providers.count()} OAuth providers for site {site_id}")

                    # Build provider data for MFE
                    fixed_providers = []
                    for provider in oauth_providers:
                        # Get the backend name (e.g., 'oauth2-authentik')
                        backend_name = provider.backend_name or f"oauth2-{provider.slug}"

                        # Construct the provider data
                        provider_data = {
                            'id': f"oa2-{provider.slug}" if provider.slug else f"oa2-{provider.name.lower().replace(' ', '-')}",
                            'name': provider.name,
                            'loginUrl': f"/auth/login/{backend_name}/?auth_entry=login&next=/dashboard",
                            'registerUrl': f"/auth/login/{backend_name}/?auth_entry=register&next=/dashboard",
                        }

                        # Add icon information if available
                        if hasattr(provider, 'icon_class') and provider.icon_class:
                            provider_data['iconClass'] = provider.icon_class
                        if hasattr(provider, 'icon_image') and provider.icon_image:
                            try:
                                provider_data['iconImage'] = provider.icon_image.url if provider.icon_image else None
                            except Exception:
                                pass

                        fixed_providers.append(provider_data)
                        logger.info(f"Added provider: {provider.name} (slug: {provider.slug}, backend: {backend_name})")

                    if fixed_providers:
                        # Update the response data
                        context_data['providers'] = fixed_providers
                        data['contextData'] = context_data

                        # Encode the updated JSON
                        updated_content = json.dumps(data).encode('utf-8')
                        response.content = updated_content
                        response['Content-Length'] = len(updated_content)

                        logger.info(f"Successfully fixed /api/mfe_context response with {len(fixed_providers)} providers")
                    else:
                        logger.warning(f"No OAuth providers found for site {site_id}")

                except ImportError as e:
                    logger.error(f"Failed to import third_party_auth: {e}")
                except Exception as e:
                    logger.error(f"Error fetching OAuth providers: {e}", exc_info=True)

        except json.JSONDecodeError as e:
            logger.error(f"Failed to decode JSON response: {e}")
        except Exception as e:
            logger.error(f"Error in MFEOAuthFixMiddleware: {e}", exc_info=True)

        return response
