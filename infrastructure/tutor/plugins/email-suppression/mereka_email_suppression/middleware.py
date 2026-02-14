# @covers AC-033, AC-034, AC-035
# @spec: email-notifications-pipeline_spec.md
"""
Email suppression middleware for Open edX.

Intercepts outbound emails and checks against suppression list.
Skips check for critical transactional emails (password_reset, account_activation).
"""

import logging

from django.core.mail import EmailMultiAlternatives
from django.core.mail.backends.base import BaseEmailBackend

from mereka_email_suppression.models import EmailSuppression

logger = logging.getLogger(__name__)


# Critical email types that bypass suppression check
BYPASS_SUPPRESSION_TYPES = [
    'password_reset',
    'account_activation',
    'email_change_confirmation',
]


class SuppressionCheckEmailBackend(BaseEmailBackend):
    """
    Email backend wrapper that checks suppression list before sending.

    Wraps the configured email backend and filters recipients against
    the EmailSuppression table.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Get the real backend from Django settings
        from django.conf import settings
        backend_path = getattr(
            settings,
            'EMAIL_BACKEND_REAL',
            'django.core.mail.backends.smtp.EmailBackend'
        )

        # Import and instantiate the real backend
        module_path, class_name = backend_path.rsplit('.', 1)
        module = __import__(module_path, fromlist=[class_name])
        backend_class = getattr(module, class_name)
        self.backend = backend_class(*args, **kwargs)

    def send_messages(self, email_messages):
        """
        Send messages after filtering against suppression list.

        Args:
            email_messages: List of EmailMessage objects

        Returns:
            int: Number of successfully sent emails
        """
        filtered_messages = []

        for message in email_messages:
            # Check if this is a critical email type that bypasses suppression
            should_bypass = self._should_bypass_suppression(message)

            if should_bypass:
                filtered_messages.append(message)
                continue

            # Filter recipients against suppression list
            filtered_to = self._filter_recipients(message.to)
            filtered_cc = self._filter_recipients(message.cc) if hasattr(message, 'cc') else []
            filtered_bcc = self._filter_recipients(message.bcc) if hasattr(message, 'bcc') else []

            # Skip message if all recipients are suppressed
            if not filtered_to and not filtered_cc and not filtered_bcc:
                logger.warning(
                    f'All recipients suppressed for email: {message.subject}'
                )
                continue

            # Update message with filtered recipients
            message.to = filtered_to
            if hasattr(message, 'cc'):
                message.cc = filtered_cc
            if hasattr(message, 'bcc'):
                message.bcc = filtered_bcc

            filtered_messages.append(message)

        # Send filtered messages using real backend
        if filtered_messages:
            return self.backend.send_messages(filtered_messages)

        return 0

    def _should_bypass_suppression(self, message):
        """
        Check if message should bypass suppression check.

        Looks for message type in headers or subject.
        """
        # Check custom header for message type
        message_type = message.extra_headers.get('X-ACE-Message-Type', '') if hasattr(message, 'extra_headers') else ''

        if any(bypass_type in message_type for bypass_type in BYPASS_SUPPRESSION_TYPES):
            return True

        # Check subject for critical keywords
        subject_lower = message.subject.lower()
        if any(keyword in subject_lower for keyword in ['password reset', 'activate your account', 'verify your email']):
            return True

        return False

    def _filter_recipients(self, recipients):
        """
        Filter recipients against suppression list.

        Args:
            recipients: List of email addresses

        Returns:
            list: Filtered list of email addresses
        """
        if not recipients:
            return []

        filtered = []
        for recipient in recipients:
            if not EmailSuppression.is_email_suppressed(recipient):
                filtered.append(recipient)
            else:
                logger.info(f'Suppressed recipient: {recipient}')

        return filtered
