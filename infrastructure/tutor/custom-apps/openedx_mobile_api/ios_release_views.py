"""
iOS App Store release API views.

@spec: Mobile Phase 4 - iOS Release (mereka-lms-39ty)
@covers: AC-MOB-020, AC-MOB-021, AC-MOB-022, AC-MOB-023
"""

import logging
from django.core.cache import cache
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, AllowAny

from .ios_release import (
    AppStoreMetadata,
    AppStoreScreenshot,
    AppStoreReviewNotes,
    IOSBrandingExtension,
)
from .ios_release_serializers import (
    AppStoreMetadataSerializer,
    AppStoreScreenshotSerializer,
    AppStoreReviewNotesSerializer,
    IOSBrandingExtensionSerializer,
)

logger = logging.getLogger(__name__)


class AppStoreMetadataView(APIView):
    """
    GET /api/mobile/v1/ios/app-store/metadata/<language>/

    Get App Store metadata for specific language.

    @covers: AC-MOB-020 - App Store metadata configuration
    """

    permission_classes = [AllowAny]

    def get(self, request, language="en-US"):
        """
        Retrieve App Store metadata.

        @covers: AC-MOB-020 - Metadata retrieval with caching
        """
        try:
            # Cache metadata for 1 hour
            cache_key = f"app_store_metadata:{language}"
            cached_metadata = cache.get(cache_key)

            if cached_metadata:
                return Response(cached_metadata, status=status.HTTP_200_OK)

            # Get active metadata for language
            metadata = AppStoreMetadata.objects.filter(
                language=language,
                is_active=True
            ).first()

            if not metadata:
                # Fallback to English if requested language not found
                metadata = AppStoreMetadata.objects.filter(
                    language="en-US",
                    is_active=True
                ).first()

            if not metadata:
                return Response(
                    {"error": "No metadata found"},
                    status=status.HTTP_404_NOT_FOUND
                )

            serializer = AppStoreMetadataSerializer(metadata)
            cache.set(cache_key, serializer.data, timeout=3600)  # 1 hour

            return Response(serializer.data, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Failed to retrieve App Store metadata: {e}")
            return Response(
                {"error": "Failed to retrieve metadata"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class AppStoreScreenshotsView(APIView):
    """
    GET /api/mobile/v1/ios/app-store/screenshots/<language>/<device_type>/

    Get screenshots for specific device type.

    @covers: AC-MOB-021 - Screenshots configuration
    """

    permission_classes = [AllowAny]

    def get(self, request, language="en-US", device_type="iphone_67"):
        """
        Retrieve screenshots for device type.

        @covers: AC-MOB-021 - Screenshot retrieval
        """
        try:
            # Get metadata first
            metadata = AppStoreMetadata.objects.filter(
                language=language,
                is_active=True
            ).first()

            if not metadata:
                return Response(
                    {"error": "No metadata found"},
                    status=status.HTTP_404_NOT_FOUND
                )

            # Get screenshots for device type
            screenshots = AppStoreScreenshot.objects.filter(
                metadata=metadata,
                device_type=device_type
            )

            serializer = AppStoreScreenshotSerializer(screenshots, many=True)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Failed to retrieve screenshots: {e}")
            return Response(
                {"error": "Failed to retrieve screenshots"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class AppStoreReviewNotesView(APIView):
    """
    GET /api/mobile/v1/ios/app-store/review-notes/<version>/

    Get review notes for specific version (staff only).

    @covers: AC-MOB-022 - Review notes and test credentials
    """

    permission_classes = [IsAuthenticated]

    def get(self, request, version):
        """
        Retrieve review notes (staff only).

        @covers: AC-MOB-022 - Review notes retrieval
        """
        if not request.user.is_staff:
            return Response(
                {"error": "Staff access required"},
                status=status.HTTP_403_FORBIDDEN
            )

        try:
            review_notes = AppStoreReviewNotes.objects.get(version=version)
            serializer = AppStoreReviewNotesSerializer(review_notes)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except AppStoreReviewNotes.DoesNotExist:
            return Response(
                {"error": "Review notes not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            logger.error(f"Failed to retrieve review notes: {e}")
            return Response(
                {"error": "Failed to retrieve review notes"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class IOSBrandingView(APIView):
    """
    GET /api/mobile/v1/ios/branding/<org_slug>/

    Get iOS-specific branding configuration.

    @covers: AC-MOB-023 - iOS multi-tenant branding
    """

    permission_classes = [AllowAny]

    def get(self, request, org_slug="mereka"):
        """
        Retrieve iOS branding config.

        @covers: AC-MOB-023 - iOS branding retrieval with caching
        """
        try:
            # Cache branding for 10 minutes
            cache_key = f"ios_branding:{org_slug}"
            cached_branding = cache.get(cache_key)

            if cached_branding:
                return Response(cached_branding, status=status.HTTP_200_OK)

            # Get branding config
            branding = IOSBrandingExtension.objects.get(org_slug=org_slug)
            serializer = IOSBrandingExtensionSerializer(branding)

            cache.set(cache_key, serializer.data, timeout=600)  # 10 minutes

            return Response(serializer.data, status=status.HTTP_200_OK)

        except IOSBrandingExtension.DoesNotExist:
            return Response(
                {"error": "Branding config not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            logger.error(f"Failed to retrieve iOS branding: {e}")
            return Response(
                {"error": "Failed to retrieve branding"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
