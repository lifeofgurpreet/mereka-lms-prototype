"""
DRF serializers for push notification device registration API.

@spec: email-notifications-pipeline_spec.md
"""

from rest_framework import serializers

from .models import DeviceRegistration


class DeviceRegistrationSerializer(serializers.ModelSerializer):
    """Serializer for device registration responses."""

    class Meta:
        model = DeviceRegistration
        fields = [
            'id',
            'device_token',
            'platform',
            'app_version',
            'org_slug',
            'is_active',
            'registered_at',
            'last_seen_at',
        ]
        read_only_fields = [
            'id',
            'is_active',
            'registered_at',
            'last_seen_at',
        ]


class DeviceRegistrationRequestSerializer(serializers.Serializer):
    """Serializer for device registration POST requests."""

    device_token = serializers.CharField(max_length=512)
    platform = serializers.ChoiceField(choices=DeviceRegistration.PLATFORM_CHOICES)
    app_version = serializers.CharField(max_length=50, required=False, default='')
    org_slug = serializers.CharField(max_length=255)


class DeviceUnregisterRequestSerializer(serializers.Serializer):
    """Serializer for device unregistration DELETE requests."""

    device_token = serializers.CharField(max_length=512)
