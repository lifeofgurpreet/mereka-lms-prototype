# @covers AC-020, AC-021, AC-022, AC-023
# @spec: email-notifications-pipeline_spec.md
"""
DRF views for notification preferences.

AC-020: Default preferences API (GET /api/notifications/v1/preferences/)
AC-021: User preference update (PUT preferences)
AC-022: One-click unsubscribe (GET with HMAC token)
AC-023: Audit log for preference changes
"""

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from django.http import HttpResponse
from django.db import transaction

from .models import NotificationPreference, PreferenceAuditLog
from .serializers import NotificationPreferenceSerializer, PreferencesUpdateSerializer
from .utils import (
    get_default_preferences,
    validate_unsubscribe_token,
    hash_ip_address,
)


class PreferencesListView(APIView):
    """
    GET /api/notifications/v1/preferences/

    AC-020: Returns user preferences with defaults filled in.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get user's notification preferences (with defaults)."""
        user_id = request.user.id

        # Get existing preferences
        existing_prefs = NotificationPreference.objects.filter(user_id=user_id)
        existing_dict = {
            (pref.message_type, pref.channel): pref
            for pref in existing_prefs
        }

        # Fill in defaults for missing preferences
        default_prefs = get_default_preferences(user_id)
        all_prefs = []

        for default_pref in default_prefs:
            key = (default_pref['message_type'], default_pref['channel'])
            if key in existing_dict:
                # Use existing preference
                all_prefs.append(existing_dict[key])
            else:
                # Use default (not saved to DB yet)
                all_prefs.append(default_pref)

        # Serialize
        serializer = NotificationPreferenceSerializer(all_prefs, many=True)
        return Response(serializer.data)


class PreferencesUpdateView(APIView):
    """
    PUT /api/notifications/v1/preferences/

    AC-021: Update user preferences (per-channel toggles)
    AC-023: Create audit log entries
    """
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def put(self, request):
        """Update user's notification preferences."""
        user_id = request.user.id

        # Validate request
        serializer = PreferencesUpdateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        preferences = serializer.validated_data['preferences']
        consent_version = serializer.validated_data.get('consent_version')

        # Get IP address for audit log
        ip_address = self._get_client_ip(request)
        ip_hash = hash_ip_address(ip_address) if ip_address else None

        # Update each preference
        for pref_data in preferences:
            message_type = pref_data['message_type']
            channel = pref_data['channel']
            enabled = pref_data['enabled']

            # Get or create preference
            pref, created = NotificationPreference.objects.get_or_create(
                user_id=user_id,
                message_type=message_type,
                channel=channel,
                defaults={'enabled': enabled, 'consent_version': consent_version}
            )

            old_value = None if created else pref.enabled

            # Update if changed
            if not created and pref.enabled != enabled:
                pref.enabled = enabled
                pref.consent_version = consent_version
                pref.save()

            # Create audit log entry
            PreferenceAuditLog.objects.create(
                user_id=user_id,
                message_type=message_type,
                channel=channel,
                old_value=old_value,
                new_value=enabled,
                consent_version=consent_version,
                ip_address_hash=ip_hash,
                change_source='api',
            )

        return Response({'status': 'success'}, status=status.HTTP_200_OK)

    def _get_client_ip(self, request):
        """Extract client IP address from request."""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0].strip()
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip


class UnsubscribeView(APIView):
    """
    GET /api/notifications/v1/unsubscribe/?token=<hmac_token>

    AC-022: One-click unsubscribe (validates HMAC-SHA256 token, disables bulk_campaign + course_announcement email)
    AC-023: Create audit log entry
    """
    permission_classes = []  # No authentication required (uses token)

    @transaction.atomic
    def get(self, request):
        """
        One-click unsubscribe from bulk emails.

        Disables:
        - bulk_campaign (email)
        - course_announcement (email)
        """
        token = request.GET.get('token')
        if not token:
            return HttpResponse('Missing token parameter', status=400)

        # Validate token
        token_data = validate_unsubscribe_token(token)
        if not token_data:
            return HttpResponse('Invalid or expired token', status=400)

        user_id = token_data['user_id']
        email = token_data['email']

        # Get IP address for audit log
        ip_address = self._get_client_ip(request)
        ip_hash = hash_ip_address(ip_address) if ip_address else None

        # Disable bulk_campaign and course_announcement email
        message_types_to_disable = ['bulk_campaign', 'course_announcement']

        for message_type in message_types_to_disable:
            # Get or create preference
            pref, created = NotificationPreference.objects.get_or_create(
                user_id=user_id,
                message_type=message_type,
                channel='email',
                defaults={'enabled': False}
            )

            old_value = None if created else pref.enabled

            # Update if not already disabled
            if pref.enabled:
                pref.enabled = False
                pref.save()

            # Create audit log entry
            PreferenceAuditLog.objects.create(
                user_id=user_id,
                message_type=message_type,
                channel='email',
                old_value=old_value,
                new_value=False,
                ip_address_hash=ip_hash,
                change_source='unsubscribe',
            )

        return HttpResponse(
            f'Successfully unsubscribed {email} from bulk emails. '
            'You will no longer receive marketing campaigns or course announcements.',
            status=200
        )

    def _get_client_ip(self, request):
        """Extract client IP address from request."""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0].strip()
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip
