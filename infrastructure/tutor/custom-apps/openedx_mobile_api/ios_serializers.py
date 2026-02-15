"""
iOS-specific serializers.

@spec: Mobile Phase 2 - iOS Stabilization (mereka-lms-36f7)
@covers: AC-MOB-008, AC-MOB-009, AC-MOB-011, AC-MOB-012, AC-MOB-014
"""

from rest_framework import serializers
from .ios_auth import PKCEChallenge, MobileToken, APNsNotification


class PKCEChallengeSerializer(serializers.ModelSerializer):
    """
    Serializer for PKCE challenge.

    @covers: AC-MOB-008 - PKCE flow
    @covers: AC-MOB-014 - No secrets in response (PKCE verifier excluded)
    """

    class Meta:
        model = PKCEChallenge
        fields = [
            "code_challenge",
            "code_challenge_method",
            "state",
            "expires_at",
        ]
        # NOTE: PKCE verifier is NEVER returned (AC-MOB-014 - no secrets exposed)


class TokenRefreshSerializer(serializers.Serializer):
    """
    Serializer for token refresh request.

    @covers: AC-MOB-009 - Token refresh
    """

    refresh_token = serializers.CharField(max_length=255, required=True)


class TokenRevokeSerializer(serializers.Serializer):
    """
    Serializer for token revocation request.

    @covers: AC-MOB-011 - Token revocation
    """

    access_token = serializers.CharField(max_length=255, required=False)
    refresh_token = serializers.CharField(max_length=255, required=False)


class APNsNotificationSerializer(serializers.ModelSerializer):
    """
    Serializer for APNs notification.

    @covers: AC-MOB-012 - Push notification with deep link
    @covers: AC-MOB-014 - No device tokens in logs
    """

    class Meta:
        model = APNsNotification
        fields = [
            "device_token",
            "notification_type",
            "title",
            "body",
            "deep_link_url",
            "course_id",
            "content_id",
        ]

    def validate_device_token(self, value):
        """Validate device token format (AC-MOB-014 - no exposure in errors)."""
        if not value or len(value) < 10:
            raise serializers.ValidationError("Invalid device token format")
        return value
