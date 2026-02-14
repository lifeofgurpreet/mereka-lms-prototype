"""API views for Video Content Protection"""
import logging

from django.conf import settings
from opaque_keys import InvalidKeyError
from opaque_keys.edx.keys import CourseKey
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import SignedPlaybackToken, VideoAccessLog
from .serializers import SignedPlaybackURLRequestSerializer, SignedPlaybackURLResponseSerializer
from .utils import (
    extract_org_slug_from_course_key,
    generate_signed_playback_url,
    get_client_ip,
    hash_ip_address,
    is_rate_limited,
)

logger = logging.getLogger(__name__)


def _check_enrollment(user, course_key):
    """
    Check if user is enrolled in the course.

    Args:
        user: User instance
        course_key: CourseKey instance

    Returns:
        True if enrolled, False otherwise
    """
    try:
        # Import here to avoid circular dependency
        from common.djangoapps.student.models import CourseEnrollment

        return CourseEnrollment.is_enrolled(user, course_key)
    except Exception as e:
        logger.error(f'Failed to check enrollment for {user.username} in {course_key}: {e}')
        return False


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def generate_signed_url_view(request):
    """
    Generate a signed playback URL for Mux video.

    Requires:
    - User must be authenticated
    - User must be enrolled in the course
    - ENABLE_MUX_SIGNED_PLAYBACK feature flag must be enabled
    - Rate limit: 100 requests/hour/user

    Request body:
    {
        "playback_id": "abcd1234efgh5678",
        "course_key": "course-v1:MerekaAcademy+COURSE101+2024",
        "expiry_hours": 12  // Optional, defaults to 12
    }

    Response (201 Created):
    {
        "url": "https://stream.mux.com/abcd1234.m3u8?token=...",
        "expires_at": "2026-02-15T00:00:00Z",
        "playback_id": "abcd1234efgh5678"
    }

    Error responses:
    - 400: Invalid request (missing fields, invalid course key)
    - 403: Not enrolled, feature disabled, or rate limited
    - 500: Token generation failed
    """
    # Check feature flag
    enable_signed_playback = getattr(settings, 'ENABLE_MUX_SIGNED_PLAYBACK', False)
    if not enable_signed_playback:
        VideoAccessLog.log_access(
            user=request.user,
            course_key=request.data.get('course_key', ''),
            video_id=request.data.get('playback_id', ''),
            status=VideoAccessLog.ACCESS_DENIED,
            denial_reason='feature_disabled',
            ip_address_hash=hash_ip_address(get_client_ip(request)),
        )
        return Response(
            {'error': 'Signed playback is not enabled. Contact administrator.'},
            status=503,
        )

    # Validate request
    serializer = SignedPlaybackURLRequestSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=400)

    validated_data = serializer.validated_data
    playback_id = validated_data['playback_id']
    course_key_str = validated_data['course_key']
    expiry_hours = validated_data.get('expiry_hours', 12)

    # Parse course key
    try:
        course_key = CourseKey.from_string(course_key_str)
    except InvalidKeyError:
        return Response({'error': f'Invalid course key: {course_key_str}'}, status=400)

    # Check enrollment
    if not _check_enrollment(request.user, course_key):
        ip_hash = hash_ip_address(get_client_ip(request))
        org_slug = extract_org_slug_from_course_key(course_key)

        VideoAccessLog.log_access(
            user=request.user,
            course_key=course_key,
            video_id=playback_id,
            status=VideoAccessLog.ACCESS_DENIED,
            denial_reason='not_enrolled',
            ip_address_hash=ip_hash,
            org_slug=org_slug,
        )

        logger.warning(
            f'User {request.user.username} not enrolled in {course_key}, '
            f'denied signed URL for {playback_id}'
        )
        return Response(
            {'error': 'You must be enrolled in this course to access video content.'},
            status=403,
        )

    # Check rate limit
    if is_rate_limited(request.user, max_requests=100, window_hours=1):
        return Response(
            {'error': 'Rate limit exceeded. Try again later.'},
            status=429,
        )

    # Generate signed URL
    try:
        # Get domain restriction from settings (optional)
        audience = getattr(settings, 'MUX_PLAYBACK_AUDIENCE', None)

        signed_url_data = generate_signed_playback_url(
            playback_id=playback_id,
            user_id=request.user.id,
            expiry_hours=expiry_hours,
            audience=audience,
        )

        # Save token to database for audit
        ip_hash = hash_ip_address(get_client_ip(request))
        org_slug = extract_org_slug_from_course_key(course_key)
        user_agent = request.META.get('HTTP_USER_AGENT', '')[:500]

        SignedPlaybackToken.objects.create(
            user=request.user,
            course_key=course_key,
            video_id=playback_id,
            org_slug=org_slug,
            token=signed_url_data['token'],
            expires_at=signed_url_data['expires_at'],
            ip_address_hash=ip_hash,
            user_agent=user_agent,
        )

        # Log successful access
        VideoAccessLog.log_access(
            user=request.user,
            course_key=course_key,
            video_id=playback_id,
            status=VideoAccessLog.ACCESS_GRANTED,
            ip_address_hash=ip_hash,
            org_slug=org_slug,
        )

        logger.info(
            f'Generated signed URL for {request.user.username} - '
            f'{playback_id} (expires: {signed_url_data["expires_at"]})'
        )

        # Return response
        response_serializer = SignedPlaybackURLResponseSerializer(signed_url_data)
        return Response(response_serializer.data, status=201)

    except ValueError as e:
        logger.error(f'Failed to generate signed URL for {playback_id}: {e}')
        return Response({'error': str(e)}, status=500)
    except Exception as e:
        logger.exception(f'Unexpected error generating signed URL for {playback_id}')
        return Response({'error': 'Internal server error'}, status=500)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_video_access_view(request):
    """
    Check if user has access to a video (enrollment check only).

    Useful for frontend to determine whether to request signed URL.

    Query params:
    - course_key: Course key (required)

    Response (200 OK):
    {
        "has_access": true,
        "feature_enabled": true,
        "enrollment_status": "enrolled"
    }
    """
    course_key_str = request.query_params.get('course_key')
    if not course_key_str:
        return Response({'error': 'course_key is required'}, status=400)

    try:
        course_key = CourseKey.from_string(course_key_str)
    except InvalidKeyError:
        return Response({'error': f'Invalid course key: {course_key_str}'}, status=400)

    # Check enrollment
    is_enrolled = _check_enrollment(request.user, course_key)

    # Check feature flag
    feature_enabled = getattr(settings, 'ENABLE_MUX_SIGNED_PLAYBACK', False)

    return Response(
        {
            'has_access': is_enrolled and feature_enabled,
            'feature_enabled': feature_enabled,
            'enrollment_status': 'enrolled' if is_enrolled else 'not_enrolled',
        },
        status=200,
    )
