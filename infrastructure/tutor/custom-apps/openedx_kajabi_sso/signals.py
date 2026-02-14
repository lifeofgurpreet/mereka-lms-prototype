"""
Signal handlers for Kajabi SSO.

@spec: Kajabi SSO Migration (mereka-lms-f98)
@covers: AC-SSO-001
"""

import logging
from django.contrib.auth.signals import user_logged_in
from django.dispatch import receiver

from .models import KajabiSSOUser

logger = logging.getLogger(__name__)


@receiver(user_logged_in)
def record_sso_login(sender, request, user, **kwargs):
    """
    Record SSO login timestamp when user logs in.

    @covers: AC-SSO-001 - Track SSO login activity
    """
    try:
        kajabi_sso = KajabiSSOUser.objects.get(user=user)
        # Only record if login is via SSO (check session backend)
        backend = request.session.get("_auth_user_backend", "")
        if "kajabi" in backend.lower():
            kajabi_sso.record_sso_login()
            logger.info(f"Recorded SSO login for {user.username}")
    except KajabiSSOUser.DoesNotExist:
        # User doesn't have SSO enabled, skip
        pass
    except Exception as e:
        logger.error(f"Error recording SSO login for {user.username}: {e}")
