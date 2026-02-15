"""
Serializers for Mobile Backend API.

@spec: Mobile Backend API (mereka-lms-2gck)
@covers: AC-MOB-001, AC-MOB-002, AC-MOB-007
"""

from rest_framework import serializers
from .models import MobileDevice, MobileBrandingConfig, MobileAppVersion


class MobileDeviceSerializer(serializers.ModelSerializer):
    """
    Serializer for device registration.

    @covers: AC-MOB-002 - Device registration
    @covers: AC-MOB-007 - No secrets exposed
    """

    class Meta:
        model = MobileDevice
        fields = [
            "id",
            "device_token",
            "platform",
            "app_version",
            "os_version",
            "device_name",
            "is_active",
            "last_active",
            "created_at",
        ]
        read_only_fields = ["id", "last_active", "created_at"]

    def validate_device_token(self, value):
        """Validate device token format (AC-MOB-007 - no secret exposure)."""
        if not value or len(value) < 10:
            raise serializers.ValidationError("Invalid device token format")
        return value


class MobileBrandingConfigSerializer(serializers.ModelSerializer):
    """
    Serializer for branding configuration.

    @covers: AC-MOB-001 - Branding config API
    @covers: AC-MOB-007 - No secrets exposed (exclude sensitive fields)
    """

    feature_flags = serializers.SerializerMethodField()

    class Meta:
        model = MobileBrandingConfig
        fields = [
            "org_slug",
            "org_name",
            "primary_color",
            "secondary_color",
            "logo_url",
            "logo_square_url",
            "splash_background_color",
            "feature_flags",
            "min_ios_version",
            "min_android_version",
            "custom_config",
        ]

    def get_feature_flags(self, obj):
        """Return feature flags (AC-MOB-001)."""
        return {
            "dark_mode": obj.enable_dark_mode,
            "push_notifications": obj.enable_push_notifications,
            "offline_mode": obj.enable_offline_mode,
        }


class MobileAppVersionSerializer(serializers.ModelSerializer):
    """
    Serializer for app version compatibility.

    @covers: AC-MOB-001 - App version compatibility check
    """

    class Meta:
        model = MobileAppVersion
        fields = [
            "platform",
            "version",
            "min_supported_version",
            "is_deprecated",
            "force_update",
            "release_notes",
            "released_at",
        ]


class DeviceRegistrationSerializer(serializers.Serializer):
    """
    Serializer for device registration request.

    @covers: AC-MOB-002 - Idempotent device registration
    """

    device_token = serializers.CharField(max_length=255, required=True)
    platform = serializers.ChoiceField(choices=["ios", "android"], required=True)
    app_version = serializers.CharField(max_length=50, required=False, allow_blank=True)
    os_version = serializers.CharField(max_length=50, required=False, allow_blank=True)
    device_name = serializers.CharField(max_length=100, required=False, allow_blank=True)


class DeviceUnregistrationSerializer(serializers.Serializer):
    """
    Serializer for device unregistration request.

    @covers: AC-MOB-003 - Device deletion
    """

    device_token = serializers.CharField(max_length=255, required=True)
