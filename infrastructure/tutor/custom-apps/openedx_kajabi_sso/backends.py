"""
OAuth2 authentication backend for Kajabi SSO.

@spec: Kajabi SSO Migration (mereka-lms-f98)
@covers: AC-SSO-001, AC-SSO-003
"""

import logging
from django.contrib.auth import get_user_model
from django.contrib.auth.backends import ModelBackend
from social_core.backends.oauth import BaseOAuth2

from .models import KajabiSSOUser

logger = logging.getLogger(__name__)
User = get_user_model()


class KajabiOAuth2Backend(BaseOAuth2):
    """
    OAuth2 backend for Kajabi SSO integration.

    @covers: AC-SSO-001 - OAuth2 client registration and user matching

    This backend integrates with Kajabi's OAuth2 provider to authenticate
    migrated users via SSO.
    """

    name = "kajabi"
    AUTHORIZATION_URL = "https://app.kajabi.com/oauth/authorize"
    ACCESS_TOKEN_URL = "https://app.kajabi.com/oauth/token"
    ACCESS_TOKEN_METHOD = "POST"
    REDIRECT_STATE = False
    SCOPE_SEPARATOR = " "
    EXTRA_DATA = [
        ("id", "kajabi_user_id"),
        ("email", "kajabi_email"),
        ("name", "full_name"),
    ]

    def get_user_details(self, response):
        """
        Extract user details from OAuth2 response.

        @covers: AC-SSO-001 - User matching via email
        """
        return {
            "username": response.get("email", "").split("@")[0],
            "email": response.get("email", ""),
            "first_name": response.get("first_name", ""),
            "last_name": response.get("last_name", ""),
            "fullname": response.get("name", ""),
        }

    def user_data(self, access_token, *args, **kwargs):
        """Fetch user data from Kajabi API using access token."""
        headers = {"Authorization": f"Bearer {access_token}"}
        try:
            response = self.get_json(
                "https://app.kajabi.com/api/v1/user",
                headers=headers
            )
            return response
        except Exception as e:
            logger.error(f"Failed to fetch Kajabi user data: {e}")
            return {}

    def get_user_id(self, details, response):
        """Return unique user ID from Kajabi."""
        return response.get("id")


class KajabiSSOFallbackBackend(ModelBackend):
    """
    Fallback authentication backend for email/password login.

    @covers: AC-SSO-003 - SSO failure fallback to email/password (no lockout)

    This backend allows users to authenticate with email/password if SSO
    fails or is unavailable, preventing account lockout.
    """

    def authenticate(self, request, username=None, password=None, **kwargs):
        """
        Authenticate user via email/password if SSO fails.

        @covers: AC-SSO-003 - No lockout on SSO failure
        """
        if username is None or password is None:
            return None

        try:
            # Try to authenticate with username
            user = super().authenticate(request, username=username, password=password, **kwargs)
            if user:
                # Check if user has SSO enabled
                try:
                    kajabi_sso = KajabiSSOUser.objects.get(user=user)
                    if kajabi_sso.fallback_to_password:
                        logger.info(
                            f"User {user.username} authenticated via fallback "
                            f"(SSO enabled but fallback allowed)"
                        )
                        return user
                    else:
                        logger.warning(
                            f"User {user.username} attempted fallback login "
                            f"but fallback is disabled"
                        )
                        return None
                except KajabiSSOUser.DoesNotExist:
                    # User doesn't have SSO enabled, allow normal login
                    return user

            # Try email-based authentication
            try:
                user_by_email = User.objects.get(email=username)
                if user_by_email.check_password(password):
                    try:
                        kajabi_sso = KajabiSSOUser.objects.get(user=user_by_email)
                        if kajabi_sso.fallback_to_password:
                            logger.info(
                                f"User {user_by_email.username} authenticated via "
                                f"email fallback (SSO enabled but fallback allowed)"
                            )
                            return user_by_email
                        else:
                            logger.warning(
                                f"User {user_by_email.username} attempted email "
                                f"fallback but fallback is disabled"
                            )
                            return None
                    except KajabiSSOUser.DoesNotExist:
                        # User doesn't have SSO enabled, allow normal login
                        return user_by_email
            except User.DoesNotExist:
                pass

            return None

        except Exception as e:
            logger.error(f"Error in Kajabi SSO fallback authentication: {e}")
            return None
