"""
Utility functions for Kajabi SSO.

@spec: Kajabi SSO Migration (mereka-lms-f98)
@covers: AC-SSO-004, AC-SSO-005
"""

import logging
import re
from django.contrib.auth import get_user_model
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django.conf import settings

from .models import KajabiSSOUser

logger = logging.getLogger(__name__)
User = get_user_model()


def normalize_email(email):
    """
    Normalize email for deduplication.

    @covers: AC-SSO-004 - Email deduplication

    Lowercases email and strips whitespace.
    """
    if not email:
        return ""
    return email.strip().lower()


def normalize_username(username):
    """
    Normalize username for deduplication.

    @covers: AC-SSO-004 - Username deduplication

    Lowercases username, removes special characters, ensures uniqueness.
    """
    if not username:
        return ""

    # Lowercase and remove special characters
    normalized = re.sub(r"[^\w\-.]", "", username.lower())

    # Ensure not empty
    if not normalized:
        normalized = "user"

    return normalized


def find_existing_user_by_email(email):
    """
    Find existing user by email (case-insensitive).

    @covers: AC-SSO-004 - Email deduplication

    Returns:
        User or None
    """
    normalized = normalize_email(email)
    if not normalized:
        return None

    try:
        return User.objects.get(email__iexact=normalized)
    except User.DoesNotExist:
        return None
    except User.MultipleObjectsReturned:
        # Multiple users with same email (shouldn't happen, but handle it)
        logger.warning(f"Multiple users found with email {normalized}")
        return User.objects.filter(email__iexact=normalized).first()


def generate_unique_username(base_username, email=None):
    """
    Generate unique username by appending numbers if needed.

    @covers: AC-SSO-004 - Username deduplication

    Args:
        base_username: Desired username
        email: User email (used as fallback)

    Returns:
        Unique username
    """
    if not base_username and email:
        base_username = email.split("@")[0]

    normalized = normalize_username(base_username)

    # Check if username is available
    if not User.objects.filter(username=normalized).exists():
        return normalized

    # Append numbers until we find unique username
    counter = 1
    while True:
        candidate = f"{normalized}{counter}"
        if not User.objects.filter(username=candidate).exists():
            return candidate
        counter += 1
        if counter > 9999:
            # Safety limit to prevent infinite loop
            raise ValueError(f"Could not generate unique username for {base_username}")


def send_welcome_email(user, kajabi_sso_user):
    """
    Send welcome email with SSO setup instructions.

    @covers: AC-SSO-005 - Welcome email with SSO instructions

    Args:
        user: Django User instance
        kajabi_sso_user: KajabiSSOUser instance

    Returns:
        bool: True if email sent successfully
    """
    if kajabi_sso_user.welcome_email_sent:
        logger.info(f"Welcome email already sent to {user.email}")
        return False

    try:
        # Email context
        context = {
            "user": user,
            "platform_name": settings.PLATFORM_NAME if hasattr(settings, "PLATFORM_NAME") else "Mereka Academy",
            "lms_url": settings.LMS_ROOT_URL if hasattr(settings, "LMS_ROOT_URL") else "https://academyv2.mereka.io",
            "support_email": settings.CONTACT_EMAIL if hasattr(settings, "CONTACT_EMAIL") else "support@mereka.io",
        }

        # Render email templates
        subject = f"Welcome to {context['platform_name']} - SSO Setup Complete"
        html_message = render_to_string("kajabi_sso/welcome_email.html", context)
        plain_message = strip_tags(html_message)

        # Send email
        send_mail(
            subject=subject,
            message=plain_message,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            html_message=html_message,
            fail_silently=False,
        )

        # Mark as sent
        kajabi_sso_user.mark_welcome_email_sent()

        logger.info(f"Welcome email sent to {user.email}")
        return True

    except Exception as e:
        logger.error(f"Failed to send welcome email to {user.email}: {e}")
        return False


def get_or_create_kajabi_user(kajabi_user_id, email, username=None, first_name="", last_name=""):
    """
    Get or create user and link to Kajabi SSO.

    @covers: AC-SSO-001 - User matching via email
    @covers: AC-SSO-002 - Bulk import create/link
    @covers: AC-SSO-004 - Email + username deduplication

    Args:
        kajabi_user_id: Kajabi user ID
        email: User email
        username: Desired username (optional)
        first_name: User first name (optional)
        last_name: User last name (optional)

    Returns:
        tuple: (user, kajabi_sso_user, operation)
        operation: "create", "link", or "skip_duplicate"
    """
    normalized_email = normalize_email(email)

    # Check if SSO link already exists
    try:
        kajabi_sso_user = KajabiSSOUser.objects.get(kajabi_user_id=kajabi_user_id)
        logger.info(f"Kajabi user {kajabi_user_id} already linked to {kajabi_sso_user.user.username}")
        return kajabi_sso_user.user, kajabi_sso_user, "skip_duplicate"
    except KajabiSSOUser.DoesNotExist:
        pass

    # Check if user exists by email
    existing_user = find_existing_user_by_email(normalized_email)

    if existing_user:
        # Link existing user to SSO
        kajabi_sso_user = KajabiSSOUser.objects.create(
            user=existing_user,
            kajabi_user_id=kajabi_user_id,
            kajabi_email=normalized_email,
            sso_enabled=True,
            fallback_to_password=True,
        )
        logger.info(f"Linked existing user {existing_user.username} to Kajabi SSO")
        return existing_user, kajabi_sso_user, "link"

    # Create new user
    unique_username = generate_unique_username(username, normalized_email)

    new_user = User.objects.create(
        username=unique_username,
        email=normalized_email,
        first_name=first_name,
        last_name=last_name,
        is_active=True,
    )

    # Set unusable password (SSO-only by default, but fallback enabled)
    new_user.set_unusable_password()
    new_user.save()

    # Create SSO link
    kajabi_sso_user = KajabiSSOUser.objects.create(
        user=new_user,
        kajabi_user_id=kajabi_user_id,
        kajabi_email=normalized_email,
        sso_enabled=True,
        fallback_to_password=True,
    )

    logger.info(f"Created new user {new_user.username} and linked to Kajabi SSO")
    return new_user, kajabi_sso_user, "create"
