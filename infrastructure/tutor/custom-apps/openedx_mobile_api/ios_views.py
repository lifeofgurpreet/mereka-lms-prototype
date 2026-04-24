"""
iOS-specific API views.

@spec: Mobile Phase 2 - iOS Stabilization (mereka-lms-36f7)
@covers: AC-MOB-008, AC-MOB-009, AC-MOB-010, AC-MOB-011, AC-MOB-012
"""

import logging
from django.db import models
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, AllowAny

from .ios_auth import PKCEChallenge, MobileToken, APNsNotification
from .ios_serializers import (
    PKCEChallengeSerializer,
    TokenRefreshSerializer,
    TokenRevokeSerializer,
    APNsNotificationSerializer,
)

logger = logging.getLogger(__name__)


class PKCEChallengeView(APIView):
    """
    POST /api/mobile/v1/ios/auth/pkce/challenge/

    Generate PKCE challenge for OAuth 2.0 flow.

    @covers: AC-MOB-008 - OAuth 2.0 + PKCE flow
    """

    permission_classes = [AllowAny]

    def post(self, request):
        """
        Generate PKCE challenge.

        @covers: AC-MOB-008 - PKCE challenge generation
        """
        try:
            # Generate PKCE challenge
            pkce = PKCEChallenge.create_challenge()

            serializer = PKCEChallengeSerializer(pkce)
            return Response(serializer.data, status=status.HTTP_201_CREATED)

        except Exception as e:
            logger.error(f"Failed to generate PKCE challenge: {e}")
            return Response(
                {"error": "Failed to generate PKCE challenge"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class TokenRefreshView(APIView):
    """
    POST /api/mobile/v1/ios/auth/token/refresh/

    Refresh access token using refresh token.

    @covers: AC-MOB-009 - Proactive token refresh <5min before expiry
    @covers: AC-MOB-010 - 401 triggers one refresh attempt
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        """
        Refresh access token.

        @covers: AC-MOB-009 - Single-flight refresh (no duplicate refreshes)
        @covers: AC-MOB-010 - One refresh attempt on 401
        """
        serializer = TokenRefreshSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {"error": "Invalid request data", "details": serializer.errors},
                status=status.HTTP_400_BAD_REQUEST
            )

        refresh_token = serializer.validated_data["refresh_token"]

        try:
            # Find active token
            mobile_token = MobileToken.objects.get(
                refresh_token=refresh_token,
                is_active=True
            )

            # Check if refresh token is expired
            if timezone.now() >= mobile_token.refresh_expires_at:
                logger.warning(
                    f"Refresh token expired for user {mobile_token.user.username}"
                )
                return Response(
                    {"error": "Refresh token expired"},
                    status=status.HTTP_401_UNAUTHORIZED
                )

            # Generate new access token (in production, use OAuth2 library)
            # This is a placeholder - integrate with django-oauth-toolkit or similar
            import secrets
            from datetime import timedelta

            new_access_token = secrets.token_urlsafe(32)
            new_expires_at = timezone.now() + timedelta(hours=1)

            # Refresh token (single-flight - AC-MOB-009)
            mobile_token.refresh(new_access_token, new_expires_at)

            logger.info(
                f"Refreshed access token for user {mobile_token.user.username} "
                f"(refresh count: {mobile_token.refresh_count})"
            )

            return Response({
                "access_token": new_access_token,
                "expires_at": new_expires_at.isoformat(),
                "token_type": "Bearer",
            }, status=status.HTTP_200_OK)

        except MobileToken.DoesNotExist:
            logger.warning(f"Invalid or inactive refresh token")
            return Response(
                {"error": "Invalid refresh token"},
                status=status.HTTP_401_UNAUTHORIZED
            )
        except Exception as e:
            logger.error(f"Failed to refresh token: {e}")
            return Response(
                {"error": "Failed to refresh token"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class TokenRevokeView(APIView):
    """
    POST /api/mobile/v1/ios/auth/token/revoke/

    Revoke access and refresh tokens (logout).

    @covers: AC-MOB-011 - Logout revokes tokens server-side
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        """
        Revoke tokens.

        @covers: AC-MOB-011 - Server-side token revocation
        """
        serializer = TokenRevokeSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {"error": "Invalid request data", "details": serializer.errors},
                status=status.HTTP_400_BAD_REQUEST
            )

        token = serializer.validated_data.get("access_token") or \
                serializer.validated_data.get("refresh_token")

        if not token:
            return Response(
                {"error": "Either access_token or refresh_token required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # Find token by access or refresh token
            mobile_token = MobileToken.objects.filter(
                user=request.user,
                is_active=True
            ).filter(
                models.Q(access_token=token) | models.Q(refresh_token=token)
            ).first()

            if mobile_token:
                mobile_token.revoke()
                logger.info(f"Revoked token for user {request.user.username}")
                return Response(
                    {"status": "revoked"},
                    status=status.HTTP_200_OK
                )
            else:
                logger.warning(f"Token not found for user {request.user.username}")
                return Response(
                    {"error": "Token not found"},
                    status=status.HTTP_404_NOT_FOUND
                )

        except Exception as e:
            logger.error(f"Failed to revoke token: {e}")
            return Response(
                {"error": "Failed to revoke token"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class APNsDeliveryView(APIView):
    """
    POST /api/mobile/v1/ios/notifications/apns/

    Record APNs notification delivery and track deep link navigation.

    @covers: AC-MOB-012 - Push notification tap navigation
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        """
        Send APNs notification.

        @covers: AC-MOB-012 - Deep link navigation
        """
        serializer = APNsNotificationSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {"error": "Invalid request data", "details": serializer.errors},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Create notification record
        notification = APNsNotification.objects.create(
            user=request.user,
            device_token=serializer.validated_data["device_token"],
            notification_type=serializer.validated_data["notification_type"],
            title=serializer.validated_data["title"],
            body=serializer.validated_data["body"],
            deep_link_url=serializer.validated_data.get("deep_link_url", ""),
            course_id=serializer.validated_data.get("course_id", ""),
            content_id=serializer.validated_data.get("content_id", ""),
        )

        # In production, send to APNs here
        # For now, just log (AC-MOB-014 - no tokens/secrets in logs)
        logger.info(
            f"APNs notification created: {notification.notification_type} "
            f"for user {request.user.username}"
        )

        return Response(
            {"status": "queued", "notification_id": notification.id},
            status=status.HTTP_201_CREATED
        )
