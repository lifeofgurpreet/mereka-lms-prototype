# @covers AC-020, AC-021
# @spec: email-notifications-pipeline_spec.md
"""
DRF serializers for notification preferences.

AC-020: Default preferences API
AC-021: User preference update
"""

from rest_framework import serializers

from .models import SYSTEM_CRITICAL_TYPES, NotificationPreference


class NotificationPreferenceSerializer(serializers.ModelSerializer):
    """Serializer for notification preferences."""

    class Meta:
        model = NotificationPreference
        fields = ["user_id", "message_type", "channel", "enabled", "consent_version", "updated_at"]
        read_only_fields = ["updated_at"]

    def validate(self, data):
        """
        Validate preference update.

        System-critical types (password_reset, account_activation) cannot be disabled.
        """
        message_type = data.get("message_type")
        enabled = data.get("enabled")

        # Prevent disabling system-critical types
        if message_type in SYSTEM_CRITICAL_TYPES and not enabled:
            raise serializers.ValidationError(
                f"Cannot disable system-critical notification type: {message_type}"
            )

        return data


class PreferencesUpdateSerializer(serializers.Serializer):
    """
    Serializer for bulk preference updates.

    AC-021: User preference update (PUT preferences, per-channel toggles)
    """

    preferences = serializers.ListField(
        child=serializers.DictField(), help_text="List of preference updates"
    )
    consent_version = serializers.CharField(
        required=False, allow_null=True, help_text="Version of consent policy accepted"
    )

    def validate_preferences(self, value):
        """Validate preference list structure."""
        for pref in value:
            if not all(k in pref for k in ["message_type", "channel", "enabled"]):
                raise serializers.ValidationError(
                    "Each preference must have message_type, channel, and enabled fields"
                )

            # Prevent disabling system-critical types
            if pref["message_type"] in SYSTEM_CRITICAL_TYPES and not pref["enabled"]:
                raise serializers.ValidationError(
                    f"Cannot disable system-critical notification type: {pref['message_type']}"
                )

        return value
