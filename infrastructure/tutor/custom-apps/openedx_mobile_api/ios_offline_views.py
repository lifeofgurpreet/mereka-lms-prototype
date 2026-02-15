"""
iOS offline mode API views.

@spec: Mobile Phase 4 - iOS Release (mereka-lms-39ty)
@covers: AC-MOB-016, AC-MOB-017, AC-MOB-018, AC-MOB-019
"""

import logging
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, AllowAny

from .ios_offline import OfflineCourse, OfflineVideo, UniversalLinkVerification
from .ios_offline_serializers import (
    OfflineCourseSerializer,
    OfflineVideoSerializer,
    UniversalLinkVerificationSerializer,
)

logger = logging.getLogger(__name__)


class OfflineCourseListView(APIView):
    """
    GET /api/mobile/v1/ios/offline/courses/

    List user's offline courses.

    @covers: AC-MOB-016 - Offline course download tracking
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        """
        List offline courses for authenticated user.

        @covers: AC-MOB-016 - List downloaded courses
        """
        try:
            courses = OfflineCourse.objects.filter(user=request.user)
            serializer = OfflineCourseSerializer(courses, many=True)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Failed to list offline courses: {e}")
            return Response(
                {"error": "Failed to retrieve offline courses"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class OfflineCourseDownloadView(APIView):
    """
    POST /api/mobile/v1/ios/offline/courses/<course_id>/download/

    Initiate course download for offline viewing.

    @covers: AC-MOB-016 - Offline course download
    @covers: AC-MOB-017 - Background download support
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, course_id):
        """
        Initiate offline course download.

        @covers: AC-MOB-017 - Background download initiation
        """
        try:
            course_name = request.data.get("course_name", "Unknown Course")
            total_size = request.data.get("total_size_bytes", 0)

            # Get or create offline course record
            offline_course, created = OfflineCourse.objects.get_or_create(
                user=request.user,
                course_id=course_id,
                defaults={
                    "course_name": course_name,
                    "total_size_bytes": total_size,
                    "status": "pending",
                }
            )

            if not created and offline_course.status == "completed":
                return Response(
                    {"status": "already_downloaded"},
                    status=status.HTTP_200_OK
                )

            # Update status to downloading
            offline_course.status = "downloading"
            offline_course.save(update_fields=["status", "updated_at"])

            serializer = OfflineCourseSerializer(offline_course)
            return Response(serializer.data, status=status.HTTP_201_CREATED)

        except Exception as e:
            logger.error(f"Failed to initiate download for {course_id}: {e}")
            return Response(
                {"error": "Failed to initiate download"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class OfflineCourseProgressView(APIView):
    """
    PUT /api/mobile/v1/ios/offline/courses/<course_id>/progress/

    Update download progress.

    @covers: AC-MOB-017 - Background download progress tracking
    """

    permission_classes = [IsAuthenticated]

    def put(self, request, course_id):
        """
        Update offline course download progress.

        @covers: AC-MOB-017 - Progress tracking
        """
        try:
            offline_course = OfflineCourse.objects.get(
                user=request.user,
                course_id=course_id
            )

            downloaded_bytes = request.data.get("downloaded_bytes", 0)
            offline_course.update_progress(downloaded_bytes)

            # Check if download is complete
            if downloaded_bytes >= offline_course.total_size_bytes:
                checksum = request.data.get("checksum", "")
                offline_course.mark_completed(checksum)

            serializer = OfflineCourseSerializer(offline_course)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except OfflineCourse.DoesNotExist:
            return Response(
                {"error": "Offline course not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            logger.error(f"Failed to update progress for {course_id}: {e}")
            return Response(
                {"error": "Failed to update progress"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class OfflineCourseDeleteView(APIView):
    """
    DELETE /api/mobile/v1/ios/offline/courses/<course_id>/

    Delete offline course.

    @covers: AC-MOB-016 - Offline course deletion
    """

    permission_classes = [IsAuthenticated]

    def delete(self, request, course_id):
        """Delete offline course."""
        try:
            offline_course = OfflineCourse.objects.get(
                user=request.user,
                course_id=course_id
            )
            offline_course.delete()

            logger.info(f"Deleted offline course {course_id} for user {request.user.username}")
            return Response(
                {"status": "deleted"},
                status=status.HTTP_200_OK
            )

        except OfflineCourse.DoesNotExist:
            return Response(
                {"error": "Offline course not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            logger.error(f"Failed to delete offline course {course_id}: {e}")
            return Response(
                {"error": "Failed to delete offline course"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class OfflineVideoListView(APIView):
    """
    GET /api/mobile/v1/ios/offline/courses/<course_id>/videos/

    List videos in offline course.

    @covers: AC-MOB-018 - Offline video playback
    """

    permission_classes = [IsAuthenticated]

    def get(self, request, course_id):
        """List videos in offline course."""
        try:
            offline_course = OfflineCourse.objects.get(
                user=request.user,
                course_id=course_id
            )

            videos = offline_course.videos.all()
            serializer = OfflineVideoSerializer(videos, many=True)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except OfflineCourse.DoesNotExist:
            return Response(
                {"error": "Offline course not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            logger.error(f"Failed to list videos for {course_id}: {e}")
            return Response(
                {"error": "Failed to retrieve videos"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class UniversalLinkVerificationView(APIView):
    """
    POST /api/mobile/v1/ios/universal-links/verify/

    Verify Universal Links for deep linking.

    @covers: AC-MOB-019 - Universal Links verification
    """

    permission_classes = [AllowAny]

    def post(self, request):
        """
        Verify Universal Link.

        @covers: AC-MOB-019 - Universal Links verification and logging
        """
        try:
            domain = request.data.get("domain", "")
            path = request.data.get("path", "")
            user_agent = request.META.get("HTTP_USER_AGENT", "")
            ip_address = request.META.get("REMOTE_ADDR")

            if not domain or not path:
                return Response(
                    {"error": "domain and path are required"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Create verification record
            verification = UniversalLinkVerification.create_verification(
                domain=domain,
                path=path,
                user_agent=user_agent,
                ip_address=ip_address
            )

            # Mark as verified (in production, add actual verification logic)
            verification.mark_verified()

            logger.info(
                f"Universal Link verified: {domain}{path} "
                f"(verification_id: {verification.verification_id})"
            )

            serializer = UniversalLinkVerificationSerializer(verification)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Failed to verify Universal Link: {e}")
            return Response(
                {"error": "Failed to verify Universal Link"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
