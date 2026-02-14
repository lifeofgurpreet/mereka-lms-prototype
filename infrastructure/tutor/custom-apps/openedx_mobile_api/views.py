"""
API Views for Mobile Backend.

@spec: Mobile Backend API (mereka-lms-2gck)
@covers: AC-MOB-001 through AC-MOB-007
"""

import logging
from django.core.cache import cache
from django.http import Http404
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, AllowAny

from .models import MobileDevice, MobileBrandingConfig
from .serializers import (
    MobileBrandingConfigSerializer,
    DeviceRegistrationSerializer,
    DeviceUnregistrationSerializer,
    MobileDeviceSerializer,
)

logger = logging.getLogger(__name__)


class MobileBrandingConfigView(APIView):
    """
    GET /api/mobile/v1/config/{org_slug}/

    Returns tenant branding configuration for mobile apps.

    @covers: AC-MOB-001 - Branding config API with p95 <= 500ms
    @covers: AC-MOB-007 - No secrets exposed
    """

    permission_classes = [AllowAny]

    def get(self, request, org_slug):
        """
        Get branding config for organization.

        @covers: AC-MOB-001 - p95 <= 500ms (cached)
        """
        # Cache key for branding config
        cache_key = f"mobile_branding_config:{org_slug}"
        cache_timeout = 300  # 5 minutes

        # Try to get from cache first (AC-MOB-001 performance)
        cached_config = cache.get(cache_key)
        if cached_config:
            logger.info(f"Returning cached branding config for {org_slug}")
            return Response(cached_config)

        # Fetch from database
        try:
            config = MobileBrandingConfig.objects.get(org_slug=org_slug)
        except MobileBrandingConfig.DoesNotExist:
            logger.warning(f"Branding config not found for org: {org_slug}")
            raise Http404(f"Branding config not found for organization: {org_slug}")

        # Serialize and cache
        serializer = MobileBrandingConfigSerializer(config)
        data = serializer.data

        # Cache for performance (AC-MOB-001)
        cache.set(cache_key, data, cache_timeout)

        logger.info(f"Returning branding config for {org_slug}")
        return Response(data)


class DeviceRegistrationView(APIView):
    """
    POST /api/mobile/v1/notifications/register/
    DELETE /api/mobile/v1/notifications/register/

    Register or unregister mobile devices for push notifications.

    @covers: AC-MOB-002 - Idempotent device registration
    @covers: AC-MOB-003 - Device deletion
    @covers: AC-MOB-006 - FCM server key stored securely
    @covers: AC-MOB-007 - No secrets exposed
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        """
        Register device for push notifications.

        @covers: AC-MOB-002 - Idempotent registration (re-register = no duplicate)
        """
        serializer = DeviceRegistrationSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {"error": "Invalid request data", "details": serializer.errors},
                status=status.HTTP_400_BAD_REQUEST
            )

        device_token = serializer.validated_data["device_token"]
        platform = serializer.validated_data["platform"]
        app_version = serializer.validated_data.get("app_version", "")
        os_version = serializer.validated_data.get("os_version", "")
        device_name = serializer.validated_data.get("device_name", "")

        # Idempotent registration (AC-MOB-002)
        device, created = MobileDevice.objects.get_or_create(
            device_token=device_token,
            defaults={
                "user": request.user,
                "platform": platform,
                "app_version": app_version,
                "os_version": os_version,
                "device_name": device_name,
                "is_active": True,
            }
        )

        if not created:
            # Re-registration: update fields and reactivate
            device.user = request.user
            device.platform = platform
            device.app_version = app_version
            device.os_version = os_version
            device.device_name = device_name
            device.reactivate()
            logger.info(
                f"Re-registered device {device_token[:20]}... for user {request.user.username}"
            )
        else:
            logger.info(
                f"Registered new device {device_token[:20]}... for user {request.user.username}"
            )

        response_serializer = MobileDeviceSerializer(device)
        return Response(
            {
                "status": "registered" if created else "updated",
                "device": response_serializer.data
            },
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
        )

    def delete(self, request):
        """
        Unregister device from push notifications.

        @covers: AC-MOB-003 - Device deletion
        """
        serializer = DeviceUnregistrationSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {"error": "Invalid request data", "details": serializer.errors},
                status=status.HTTP_400_BAD_REQUEST
            )

        device_token = serializer.validated_data["device_token"]

        try:
            device = MobileDevice.objects.get(
                device_token=device_token,
                user=request.user
            )
            device.deactivate()
            logger.info(
                f"Deactivated device {device_token[:20]}... for user {request.user.username}"
            )
            return Response(
                {"status": "unregistered"},
                status=status.HTTP_200_OK
            )
        except MobileDevice.DoesNotExist:
            logger.warning(
                f"Device not found for deletion: {device_token[:20]}... "
                f"(user: {request.user.username})"
            )
            return Response(
                {"error": "Device not found"},
                status=status.HTTP_404_NOT_FOUND
            )
