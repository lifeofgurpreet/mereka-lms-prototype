"""
Middleware to fix /api/mfe_context OAuth provider visibility.

This middleware intercepts responses from the /api/mfe_context endpoint
and ensures OAuth providers are properly included.
"""

# @covers AC-013, AC-014, AC-015, AC-016
# @spec: platform-middleware-custom-apps_spec.md

import json
import logging

from django.contrib.sites.shortcuts import get_current_site
from django.utils.deprecation import MiddlewareMixin

from mfe_oauth_fix.constants import MFE_CONTEXT_SOURCE_HEADER, MFE_CONTEXT_SOURCE_VIEW
from mfe_oauth_fix.redirects import learner_home_next_path

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
        if not request.path.startswith("/api/mfe_context"):
            return response

        # The URL override view already owns the full provider population path.
        # When that view marks the response, skip JSON parsing and fallback DB work.
        if response.get(MFE_CONTEXT_SOURCE_HEADER) == MFE_CONTEXT_SOURCE_VIEW:
            return response

        # Only process JSON responses with 200 status
        if response.status_code != 200:
            return response

        content_type = response.get("Content-Type", "")
        if "application/json" not in content_type:
            return response

        try:
            # Parse the response JSON
            data = json.loads(response.content.decode("utf-8"))

            # Check if providers array is empty or missing
            context_data = data.get("contextData", {})
            providers = context_data.get("providers", [])

            if providers:
                updated = False
                for provider in providers:
                    provider_name = (provider.get("name") or "").lower()
                    provider_id = (provider.get("id") or "").lower()
                    login_url = (provider.get("loginUrl") or "").lower()
                    register_url = (provider.get("registerUrl") or "").lower()
                    if (
                        "authentik" in provider_name
                        or "authentik" in provider_id
                        or "authentik" in login_url
                        or "authentik" in register_url
                    ):
                        provider["name"] = "Mereka"
                        updated = True

                if updated:
                    context_data["providers"] = providers
                    data["contextData"] = context_data

                    updated_content = json.dumps(data).encode("utf-8")
                    response.content = updated_content
                    response["Content-Length"] = len(updated_content)

                return response

            if not providers:
                logger.info(
                    "Empty providers array detected in /api/mfe_context, attempting to fix..."
                )

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
                        site=current_site, enabled=True, visible=True
                    ).select_related("site")

                    logger.info(
                        f"Found {oauth_providers.count()} OAuth providers for site {site_id}"
                    )

                    # Keep provider callbacks aligned with the configured learner-home.
                    learner_home_next = learner_home_next_path()
                    fixed_providers = []
                    for provider in oauth_providers:
                        # Get the backend name (e.g., 'oauth2-authentik')
                        backend_name = provider.backend_name or f"oauth2-{provider.slug}"

                        display_name = provider.name
                        provider_slug = (provider.slug or "").lower()
                        provider_name = (provider.name or "").lower()
                        backend_key = (backend_name or "").lower()
                        if (
                            "authentik" in provider_slug
                            or "authentik" in provider_name
                            or "authentik" in backend_key
                        ):
                            display_name = "Mereka"

                        # Construct the provider data
                        provider_data = {
                            "id": (
                                f"oa2-{provider.slug}"
                                if provider.slug
                                else f"oa2-{provider.name.lower().replace(' ', '-')}"
                            ),
                            "name": display_name,
                            "loginUrl": f"/auth/login/{backend_name}/?auth_entry=login&next={learner_home_next}",
                            "registerUrl": f"/auth/login/{backend_name}/?auth_entry=register&next={learner_home_next}",
                        }

                        # Add icon information if available
                        if hasattr(provider, "icon_class") and provider.icon_class:
                            provider_data["iconClass"] = provider.icon_class
                        if hasattr(provider, "icon_image") and provider.icon_image:
                            try:
                                provider_data["iconImage"] = (
                                    provider.icon_image.url if provider.icon_image else None
                                )
                            except Exception:
                                pass

                        fixed_providers.append(provider_data)
                        logger.info(
                            f"Added provider: {provider.name} (slug: {provider.slug}, backend: {backend_name})"
                        )

                    if fixed_providers:
                        # Update the response data
                        context_data["providers"] = fixed_providers
                        data["contextData"] = context_data

                        # Encode the updated JSON
                        updated_content = json.dumps(data).encode("utf-8")
                        response.content = updated_content
                        response["Content-Length"] = len(updated_content)

                        logger.info(
                            f"Successfully fixed /api/mfe_context response with {len(fixed_providers)} providers"
                        )
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
