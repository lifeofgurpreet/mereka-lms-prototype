# @covers AC-024
# @spec: email-notifications-pipeline_spec.md
"""
Middleware to add List-Unsubscribe headers to bulk_campaign emails.

AC-024: List-Unsubscribe headers in bulk_campaign emails
"""

import logging

logger = logging.getLogger(__name__)


class ListUnsubscribeMiddleware:
    """
    Add List-Unsubscribe headers to outgoing bulk_campaign emails.

    This middleware integrates with the ACE email pipeline to inject
    List-Unsubscribe headers for bulk_campaign messages.

    Note: This is a placeholder pattern. Full integration requires:
    1. Hooking into ACE message rendering
    2. Generating unsubscribe token for recipient
    3. Adding headers before email send

    For now, this demonstrates the structure. Full implementation
    will be in Phase 3 (ACE integration).
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        return response

    @staticmethod
    def add_unsubscribe_header(message, unsubscribe_url):
        """
        Add List-Unsubscribe header to email message.

        Args:
            message: Email message object
            unsubscribe_url: One-click unsubscribe URL with HMAC token

        Example:
            List-Unsubscribe: <https://academyv2.mereka.io/api/notifications/v1/unsubscribe/?token=...>
            List-Unsubscribe-Post: List-Unsubscribe=One-Click
        """
        if hasattr(message, 'extra_headers'):
            message.extra_headers = message.extra_headers or {}
            message.extra_headers['List-Unsubscribe'] = f'<{unsubscribe_url}>'
            message.extra_headers['List-Unsubscribe-Post'] = 'List-Unsubscribe=One-Click'
            logger.info(f"Added List-Unsubscribe header: {unsubscribe_url}")
