"""
Video Analytics Views

REST API endpoints for video playback event tracking and analytics retrieval.

@spec: video-pipeline-delivery_spec.md (Phase 4)
@bead: mereka-lms-17jr
"""

import hashlib
import logging
from django.conf import settings
from django.utils import timezone
from datetime import timedelta
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from rest_framework.response import Response
from opaque_keys.edx.keys import CourseKey
from opaque_keys import InvalidKeyError

from .models import VideoPlaybackEvent, VideoAnalyticsSummary
from .serializers import (
    RecordVideoEventSerializer,
    VideoPlaybackEventSerializer,
    VideoAnalyticsSummarySerializer,
    VideoAnalyticsQuerySerializer,
)

logger = logging.getLogger(__name__)


def _hash_ip_address(ip_address):
    """
    Hash IP address for privacy (data minimization).

    Args:
        ip_address (str): Client IP address

    Returns:
        str: SHA-256 hash of IP (first 16 chars)
    """
    if not ip_address:
        return None
    return hashlib.sha256(ip_address.encode('utf-8')).hexdigest()[:16]


def _get_client_ip(request):
    """
    Extract client IP address from request.

    Args:
        request: Django request object

    Returns:
        str: Client IP address
    """
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0].strip()
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip


def _get_org_slug(course_key):
    """
    Extract organization slug from course key.

    Args:
        course_key: CourseKey instance

    Returns:
        str: Organization slug
    """
    return str(course_key.org)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def record_video_event_view(request):
    """
    Record a video playback event from the client.

    POST /api/video/v1/events/

    Request Body:
        {
            "course_key": "course-v1:MerekaAcademy+COURSE101+2024",
            "video_id": "abcd1234efgh5678",
            "event_type": "played",
            "position": 10.5,
            "duration": 300.0,
            "session_id": "session-uuid"
        }

    Response (201 Created):
        {
            "id": 42,
            "user": 123,
            "course_key": "course-v1:MerekaAcademy+COURSE101+2024",
            "video_id": "abcd1234efgh5678",
            "event_type": "played",
            "position": 10.5,
            "duration": 300.0,
            "timestamp": "2026-02-14T12:00:00Z",
            "org_slug": "MerekaAcademy",
            "session_id": "session-uuid"
        }

    Error Responses:
        - 400 Bad Request: Invalid course_key or missing required fields
        - 503 Service Unavailable: Feature disabled (ENABLE_VIDEO_ANALYTICS=false)

    Rate Limit: None (client-side events expected to be frequent)

    @bead: mereka-lms-17jr
    """
    # Check feature flag
    if not getattr(settings, 'ENABLE_VIDEO_ANALYTICS', False):
        return Response(
            {'error': 'Video analytics is not enabled. Set ENABLE_VIDEO_ANALYTICS=true.'},
            status=status.HTTP_503_SERVICE_UNAVAILABLE
        )

    serializer = RecordVideoEventSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    # Validate course_key format
    try:
        course_key = CourseKey.from_string(serializer.validated_data['course_key'])
    except InvalidKeyError as e:
        return Response(
            {'error': f'Invalid course_key format: {str(e)}'},
            status=status.HTTP_400_BAD_REQUEST
        )

    # Extract metadata
    org_slug = _get_org_slug(course_key)
    ip_address = _get_client_ip(request)
    ip_hash = _hash_ip_address(ip_address)
    user_agent = request.META.get('HTTP_USER_AGENT', '')[:500]

    # Create event
    try:
        event = VideoPlaybackEvent.record_event(
            user=request.user,
            course_key=course_key,
            video_id=serializer.validated_data['video_id'],
            event_type=serializer.validated_data['event_type'],
            position=serializer.validated_data['position'],
            duration=serializer.validated_data.get('duration'),
            org_slug=org_slug,
            session_id=serializer.validated_data.get('session_id'),
            user_agent=user_agent,
            ip_address_hash=ip_hash,
        )
    except Exception as e:
        logger.error(f"Failed to record video event: {str(e)}")
        return Response(
            {'error': f'Failed to record event: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

    # Return created event
    response_serializer = VideoPlaybackEventSerializer(event)
    return Response(response_serializer.data, status=status.HTTP_201_CREATED)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_video_analytics_view(request):
    """
    Get aggregated video analytics for instructor dashboard.

    GET /api/video/v1/analytics/?course_key=...&video_id=...&start_date=...&end_date=...

    Query Parameters:
        - course_key (optional): Filter by course
        - video_id (optional): Filter by video
        - start_date (optional): Filter from date (YYYY-MM-DD)
        - end_date (optional): Filter to date (YYYY-MM-DD)
        - org_slug (optional): Filter by organization

    Response (200 OK):
        {
            "count": 5,
            "results": [
                {
                    "course_key": "course-v1:MerekaAcademy+COURSE101+2024",
                    "video_id": "abcd1234",
                    "org_slug": "MerekaAcademy",
                    "date": "2026-02-14",
                    "play_count": 150,
                    "unique_viewers": 75,
                    "completion_count": 60,
                    "completion_rate": 0.8,
                    "completion_rate_percent": 80.0,
                    "avg_watch_time": 245.5,
                    "total_watch_time": 18412.5,
                    "avg_position_reached": 270.2
                }
            ]
        }

    Permissions:
        - Instructors/staff can view analytics for their courses
        - Admins can view analytics for all courses

    @bead: mereka-lms-17jr
    """
    # Check feature flag
    if not getattr(settings, 'ENABLE_VIDEO_ANALYTICS', False):
        return Response(
            {'error': 'Video analytics is not enabled. Set ENABLE_VIDEO_ANALYTICS=true.'},
            status=status.HTTP_503_SERVICE_UNAVAILABLE
        )

    # Parse query parameters
    query_serializer = VideoAnalyticsQuerySerializer(data=request.query_params)
    if not query_serializer.is_valid():
        return Response(query_serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    # Build queryset
    queryset = VideoAnalyticsSummary.objects.all()

    # Filter by course_key
    course_key_str = query_serializer.validated_data.get('course_key')
    if course_key_str:
        try:
            course_key = CourseKey.from_string(course_key_str)
            queryset = queryset.filter(course_key=course_key)

            # Authorization check: non-staff users can only view their own courses
            if not request.user.is_staff:
                # Check if user has instructor/staff role in this course
                # (This is simplified; real implementation should check CourseAccessRole)
                from lms.djangoapps.courseware.access import has_access
                if not has_access(request.user, 'instructor', course_key):
                    return Response(
                        {'error': 'You do not have permission to view analytics for this course.'},
                        status=status.HTTP_403_FORBIDDEN
                    )

        except InvalidKeyError:
            return Response(
                {'error': 'Invalid course_key format'},
                status=status.HTTP_400_BAD_REQUEST
            )

    # Filter by video_id
    video_id = query_serializer.validated_data.get('video_id')
    if video_id:
        queryset = queryset.filter(video_id=video_id)

    # Filter by date range
    start_date = query_serializer.validated_data.get('start_date')
    if start_date:
        queryset = queryset.filter(date__gte=start_date)

    end_date = query_serializer.validated_data.get('end_date')
    if end_date:
        queryset = queryset.filter(date__lte=end_date)
    else:
        # Default to last 30 days if no end_date specified
        if not start_date:
            queryset = queryset.filter(
                date__gte=timezone.now().date() - timedelta(days=30)
            )

    # Filter by org_slug
    org_slug = query_serializer.validated_data.get('org_slug')
    if org_slug:
        queryset = queryset.filter(org_slug=org_slug)

    # Order by date descending
    queryset = queryset.order_by('-date', 'video_id')

    # Serialize and return
    serializer = VideoAnalyticsSummarySerializer(queryset, many=True)

    return Response({
        'count': queryset.count(),
        'results': serializer.data,
    }, status=status.HTTP_200_OK)
