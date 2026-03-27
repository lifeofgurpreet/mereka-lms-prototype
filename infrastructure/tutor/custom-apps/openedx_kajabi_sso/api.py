"""
Business logic for Kajabi SSO integration.

This module provides the core functionality for importing Kajabi users and managing
SSO links.

@spec: kajabi-sso
@covers: AC-SSO-002, AC-SSO-004, AC-SSO-005, AC-NEG-SSO-001, AC-NEG-SSO-003
"""

import csv
import logging
from typing import Optional, Dict, Any
from django.contrib.auth import get_user_model
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.conf import settings
from django.db import transaction
from django.utils import timezone

from .models import KajabiSsoLink, KajabiImportBatch

logger = logging.getLogger(__name__)
User = get_user_model()


def import_kajabi_csv(
    csv_file_path: str,
    imported_by: Optional[User] = None,
    send_welcome: bool = True
) -> KajabiImportBatch:
    """
    Import Kajabi users from CSV file.

    CSV format (with header):
        email,first_name,last_name,kajabi_user_id

    For each row:
    1. Normalize email to lowercase (AC-SSO-004)
    2. Check if user exists → link (don't create duplicate)
    3. If no user exists → create user with unique username
    4. Create/update KajabiSsoLink (idempotent via get_or_create)
    5. Send welcome email if enabled (AC-SSO-005)
    6. Track statistics in KajabiImportBatch

    Args:
        csv_file_path: Path to CSV file
        imported_by: User who initiated the import (optional)
        send_welcome: Whether to send welcome emails to new users (default: True)

    Returns:
        KajabiImportBatch object with import statistics

    @covers AC-SSO-002, AC-SSO-004, AC-SSO-005, AC-NEG-SSO-001
    """
    # Create import batch record
    batch = KajabiImportBatch.objects.create(
        csv_filename=csv_file_path.split('/')[-1],
        imported_by=imported_by,
        status='pending'
    )

    try:
        batch.mark_in_progress()

        with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
            reader = csv.DictReader(csvfile)

            # Validate CSV headers
            required_columns = {'email', 'first_name', 'last_name'}
            if not required_columns.issubset(reader.fieldnames or []):
                raise ValueError(f"CSV missing required columns: {required_columns}")

            row_number = 1  # Start at 1 (header is row 0)
            for row in reader:
                row_number += 1
                batch.total_rows += 1

                try:
                    # Extract and normalize data (AC-SSO-004)
                    email = row['email'].lower().strip()
                    first_name = row['first_name'].strip()
                    last_name = row['last_name'].strip()
                    kajabi_user_id = row.get('kajabi_user_id', '').strip() or None

                    if not email:
                        batch.add_error(row_number, "Missing email")
                        continue

                    # Process user import (atomic transaction per user)
                    with transaction.atomic():
                        result = _import_single_user(
                            email=email,
                            first_name=first_name,
                            last_name=last_name,
                            kajabi_user_id=kajabi_user_id,
                            send_welcome=send_welcome
                        )

                        # Update batch statistics
                        if result['action'] == 'created':
                            batch.created_count += 1
                        elif result['action'] == 'linked':
                            batch.linked_count += 1
                        elif result['action'] == 'skipped':
                            batch.skipped_count += 1

                except Exception as e:
                    logger.error(f"Error importing row {row_number}: {e}")
                    batch.add_error(row_number, str(e))

        # Mark batch as completed
        batch.mark_completed()
        logger.info(
            f"Kajabi import completed: {batch.created_count} created, "
            f"{batch.linked_count} linked, {batch.skipped_count} skipped, "
            f"{batch.error_count} errors"
        )

    except Exception as e:
        logger.error(f"Kajabi import batch failed: {e}")
        batch.mark_failed(str(e))
        raise

    return batch


def _import_single_user(
    email: str,
    first_name: str,
    last_name: str,
    kajabi_user_id: Optional[str] = None,
    send_welcome: bool = True
) -> Dict[str, Any]:
    """
    Import a single Kajabi user (internal helper).

    This function is called for each row in the CSV. It handles user creation,
    SSO link creation, and welcome email sending.

    Args:
        email: User email (already normalized to lowercase)
        first_name: User first name
        last_name: User last name
        kajabi_user_id: Kajabi external user ID (optional)
        send_welcome: Whether to send welcome email

    Returns:
        Dict with 'action' (created/linked/skipped) and 'user' object

    @covers AC-SSO-002, AC-SSO-004, AC-NEG-SSO-001
    """
    # Check if SSO link already exists (AC-NEG-SSO-001)
    existing_link = KajabiSsoLink.objects.filter(kajabi_email=email).first()
    if existing_link:
        logger.debug(f"Kajabi SSO link already exists for {email}, skipping")
        return {'action': 'skipped', 'user': existing_link.user}

    # Check if user exists by email (case-insensitive lookup, AC-SSO-004)
    user = User.objects.filter(email__iexact=email).first()

    if user:
        # Link existing user to Kajabi SSO
        sso_link = link_kajabi_user(
            email=email,
            user=user,
            kajabi_user_id=kajabi_user_id
        )
        logger.info(f"Linked existing user {user.username} to Kajabi SSO")
        action = 'linked'
    else:
        # Create new user
        username = generate_unique_username(email)
        user = User.objects.create_user(
            username=username,
            email=email,
            first_name=first_name,
            last_name=last_name,
            is_active=True
        )

        # Create SSO link
        sso_link = link_kajabi_user(
            email=email,
            user=user,
            kajabi_user_id=kajabi_user_id
        )
        logger.info(f"Created new user {user.username} with Kajabi SSO link")
        action = 'created'

    # Send welcome email (AC-SSO-005, AC-NEG-SSO-003)
    if send_welcome and action == 'created':
        send_welcome_email(user, sso_link)

    return {'action': action, 'user': user}


def link_kajabi_user(
    email: str,
    user: Optional[User] = None,
    kajabi_user_id: Optional[str] = None
) -> KajabiSsoLink:
    """
    Link a Kajabi user to an LMS account.

    If user is not provided, lookup by email (case-insensitive).

    Args:
        email: Kajabi email (normalized to lowercase)
        user: Open edX user object (optional, will lookup by email if not provided)
        kajabi_user_id: Kajabi external user ID (optional)

    Returns:
        KajabiSsoLink object (created or existing)

    @covers AC-SSO-001, AC-SSO-004
    """
    # Normalize email (AC-SSO-004)
    email = email.lower().strip()

    # Lookup user if not provided
    if user is None:
        user = User.objects.filter(email__iexact=email).first()
        if user is None:
            raise ValueError(f"No user found with email {email}")

    # Get or create SSO link (idempotent)
    sso_link, created = KajabiSsoLink.objects.get_or_create(
        user=user,
        defaults={
            'kajabi_email': email,
            'kajabi_user_id': kajabi_user_id,
            'sso_provider': getattr(settings, 'KAJABI_SSO_CLIENT_SLUG', 'mereka-kajabi-sso'),
            'is_active': True,
        }
    )

    # Update kajabi_user_id if provided and different
    if not created and kajabi_user_id and sso_link.kajabi_user_id != kajabi_user_id:
        sso_link.kajabi_user_id = kajabi_user_id
        sso_link.save(update_fields=['kajabi_user_id', 'updated_at'])

    return sso_link


def send_welcome_email(user: User, kajabi_sso_link: KajabiSsoLink) -> bool:
    """
    Send welcome email with SSO setup instructions.

    Only sends if:
    1. KAJABI_WELCOME_EMAIL_ENABLED is True
    2. welcome_email_sent is False (AC-NEG-SSO-003)

    Args:
        user: Open edX user object
        kajabi_sso_link: KajabiSsoLink object

    Returns:
        True if email was sent, False otherwise

    @covers AC-SSO-005, AC-NEG-SSO-003
    """
    # Check if welcome emails are enabled
    if not getattr(settings, 'KAJABI_WELCOME_EMAIL_ENABLED', False):
        logger.debug("Kajabi welcome emails are disabled, skipping")
        return False

    # Check if email already sent (AC-NEG-SSO-003)
    if kajabi_sso_link.welcome_email_sent:
        logger.debug(f"Welcome email already sent to {user.email}, skipping")
        return False

    try:
        # Prepare email context
        context = {
            'first_name': user.first_name or user.username,
            'last_name': user.last_name,
            'email': user.email,
            'lms_url': getattr(settings, 'LMS_ROOT_URL', 'https://academyv2.mereka.io'),
            'support_email': getattr(settings, 'KAJABI_WELCOME_EMAIL_SUPPORT', 'support@mereka.io'),
        }

        # Render email templates
        subject = "Welcome to Mereka Academy — Set up your SSO login"
        html_message = render_to_string('openedx_kajabi_sso/welcome_email.html', context)
        text_message = render_to_string('openedx_kajabi_sso/welcome_email.txt', context)

        # Send email
        from_email = getattr(settings, 'KAJABI_WELCOME_EMAIL_FROM', 'noreply@mereka.io')
        send_mail(
            subject=subject,
            message=text_message,
            html_message=html_message,
            from_email=from_email,
            recipient_list=[user.email],
            fail_silently=False,
        )

        # Mark email as sent
        kajabi_sso_link.mark_welcome_email_sent()
        logger.info(f"Sent Kajabi welcome email to {user.email}")
        return True

    except Exception as e:
        logger.error(f"Failed to send welcome email to {user.email}: {e}")
        return False


def generate_unique_username(email: str) -> str:
    """
    Generate a unique username from an email address.

    Strategy:
    1. Try email prefix (part before @)
    2. If taken, append _1, _2, etc.
    3. Truncate to 30 chars (Django User.username max length)

    Args:
        email: Email address

    Returns:
        Unique username (max 30 chars)

    @covers AC-SSO-004
    """
    # Extract email prefix
    base_username = email.split('@')[0]

    # Truncate to leave room for suffix (_999 = 4 chars)
    base_username = base_username[:26]

    # Check if username is available
    username = base_username
    counter = 1

    while User.objects.filter(username=username).exists():
        # Append counter
        username = f"{base_username}_{counter}"
        counter += 1

        # Safety check to prevent infinite loop
        if counter > 9999:
            # Fallback to UUID if we somehow hit this limit
            import uuid
            username = f"kajabi_{uuid.uuid4().hex[:20]}"
            break

    return username[:30]  # Ensure we never exceed Django's limit
