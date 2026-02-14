"""
DRF serializers for email preferences API.

@spec: email-notifications-pipeline_spec.md
@bead: mereka-lms-bnw1
"""

from rest_framework import serializers
from .models import UserEmailPreference, ConsentRecord


class EmailPreferenceSerializer(serializers.Serializer):
    """Serializer for individual email category preference."""

    category = serializers.CharField()
    opted_in = serializers.BooleanField()
    consent_version = serializers.CharField(required=False)


class EmailPreferencesResponseSerializer(serializers.Serializer):
    """Serializer for GET /api/user/v1/preferences/email/ response."""

    preferences = serializers.DictField(
        child=serializers.BooleanField(),
        help_text="Mapping of category to opted_in status"
    )


class EmailPreferencesUpdateSerializer(serializers.Serializer):
    """Serializer for PUT /api/user/v1/preferences/email/ request."""

    preferences = serializers.ListField(
        child=EmailPreferenceSerializer(),
        help_text="List of preference updates"
    )

    def validate_preferences(self, value):
        """Validate preference updates."""
        valid_categories = ['marketing', 'transactional', 'announcements', 'reminders', 'discussions']

        for pref in value:
            if pref.get('category') not in valid_categories:
                raise serializers.ValidationError(
                    f"Invalid category: {pref.get('category')}. "
                    f"Valid categories: {', '.join(valid_categories)}"
                )

        return value


class ConsentRecordSerializer(serializers.ModelSerializer):
    """Serializer for consent records (GDPR SAR)."""

    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = ConsentRecord
        fields = [
            'id',
            'username',
            'category',
            'old_value',
            'new_value',
            'consent_version',
            'ip_address_hash',
            'source',
            'timestamp',
        ]
        read_only_fields = fields
