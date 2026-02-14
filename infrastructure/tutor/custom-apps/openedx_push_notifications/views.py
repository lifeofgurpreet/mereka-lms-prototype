"""
REST API views for push notification device registration.

@spec: email-notifications-pipeline_spec.md
@covers: AC-015, AC-017
"""

import logging

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import DeviceRegistration
from .serializers import (
    DeviceRegistrationRequestSerializer,
    DeviceRegistrationSerializer,
    DeviceUnregisterRequestSerializer,
)

logger = logging.getLogger(__name__)


class DeviceRegistrationView(APIView):
    """
    Device token registration and unregistration.

    POST /api/mobile/v1/notifications/register/
        Register or update a device token for push notifications.

    DELETE /api/mobile/v1/notifications/register/
        Unregister a device token (e.g. on user logout).
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        """
        Register or update a device token.

        @covers AC-015
        """
        serializer = DeviceRegistrationRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        device, created = DeviceRegistration.register_or_update(
            user=request.user,
            device_token=serializer.validated_data['device_token'],
            platform=serializer.validated_data['platform'],
            org_slug=serializer.validated_data['org_slug'],
            app_version=serializer.validated_data.get('app_version', ''),
        )

        logger.info(
            "Device %s for user %s (platform=%s, org=%s)",
            "registered" if created else "updated",
            request.user.username,
            device.platform,
            device.org_slug,
        )

        response_serializer = DeviceRegistrationSerializer(device)
        return Response(
            response_serializer.data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    def delete(self, request):
        """
        Unregister a device token (user logout).

        @covers AC-017
        """
        serializer = DeviceUnregisterRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        updated = DeviceRegistration.unregister(
            user=request.user,
            device_token=serializer.validated_data['device_token'],
        )

        if updated:
            logger.info(
                "Device unregistered for user %s",
                request.user.username,
            )
            return Response(status=status.HTTP_204_NO_CONTENT)

        return Response(
            {"detail": "Device token not found"},
            status=status.HTTP_404_NOT_FOUND,
        )
