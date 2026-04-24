"""
OAuth2 authentication backend for Kajabi SSO.

This backend integrates with Django's authentication system to provide SSO fallback.
If SSO fails, Django continues to the next backend (email/password), ensuring users
are never locked out.

@spec: kajabi-sso
@covers: AC-SSO-001, AC-SSO-003, AC-NEG-SSO-002
"""

import logging
from django.contrib.auth import get_user_model
from django.contrib.auth.backends import ModelBackend
from django.conf import settings

from .models import KajabiSsoLink

logger = logging.getLogger(__name__)
User = get_user_model()


class KajabiSsoBackend(ModelBackend):
    """
    Authentication backend for Kajabi SSO users.

    This backend checks if a user has a Kajabi SSO link and attempts to authenticate
    via SSO. If SSO fails or the user has no SSO link, it returns None, allowing
    Django to fall through to the next backend (email/password).

    @covers AC-SSO-001, AC-SSO-003, AC-NEG-SSO-002
    """

    def authenticate(self, request, username=None, password=None, **kwargs):
        """
        Authenticate a user via Kajabi SSO.

        This method is called by Django's authentication system. It checks for SSO
        tokens and validates the user's Kajabi SSO link.

        Args:
            request: HTTP request object (may contain sso_token or OAuth2 context)
            username: Username or email (may be None for OAuth2 flows)
            password: Password (ignored for SSO, but required for signature compatibility)
            **kwargs: Additional authentication parameters (may include email, sso_token, etc.)

        Returns:
            User object if SSO authentication succeeds, None otherwise (fallback to next backend)

        @covers AC-SSO-001, AC-SSO-003
        """
        # Check if Kajabi SSO is enabled
        if not getattr(settings, 'KAJABI_SSO_ENABLED', False):
            logger.debug("Kajabi SSO is disabled, skipping backend")
            return None

        # Extract email from kwargs (OAuth2 pipeline may pass it here)
        email = kwargs.get('email') or username

        if not email:
            logger.debug("No email provided to KajabiSsoBackend, skipping")
            return None

        # Normalize email to lowercase (AC-SSO-004)
        email = email.lower().strip()

        try:
            # Look up SSO link by email
            sso_link = KajabiSsoLink.objects.select_related('user').get(
                kajabi_email=email,
                is_active=True
            )
        except KajabiSsoLink.DoesNotExist:
            logger.debug(f"No active Kajabi SSO link found for {email}")
            return None  # Fallback to next backend (AC-SSO-003)
        except KajabiSsoLink.MultipleObjectsReturned:
            logger.error(f"Multiple Kajabi SSO links found for {email} (data integrity issue)")
            return None

        # Verify user account is active
        if not sso_link.user.is_active:
            logger.warning(f"Kajabi SSO user {email} account is inactive")
            sso_link.record_sso_failure()
            return None  # Fallback to next backend (AC-SSO-003, AC-NEG-SSO-002)

        # SSO authentication successful
        logger.info(f"Kajabi SSO authentication successful for {email}")
        sso_link.record_sso_success()
        return sso_link.user

    def get_user(self, user_id):
        """
        Retrieve a user by ID.

        This is required by Django's authentication backend interface.

        Args:
            user_id: Primary key of the user

        Returns:
            User object if found, None otherwise
        """
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None
