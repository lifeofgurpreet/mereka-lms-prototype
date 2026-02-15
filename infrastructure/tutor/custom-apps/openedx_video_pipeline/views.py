import logging

from django.conf import settings
from rest_framework import status
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import MctVideoMapping, MigrationReport
from .mux_client import get_asset_metadata
from .serializers import (
    MctVideoMappingSerializer,
    MigrationReportSerializer,
    PlaybackCheckRequestSerializer,
    VideoHealthSerializer,
)
from .validators import generate_migration_report, validate_playback_health

logger = logging.getLogger(__name__)


class VideoHealthCheckView(APIView):
    """
    GET /api/video-pipeline/health/

    Returns overall migration health status.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        mappings = MctVideoMapping.objects.all()

        total_videos = mappings.count()
        ready_count = mappings.filter(mux_status='ready').count()
        preparing_count = mappings.filter(mux_status='preparing').count()
        errored_count = mappings.filter(mux_status='errored').count()
        playback_verified_count = mappings.filter(playback_verified=True).count()

        expected_count = getattr(settings, 'MCT_EXPECTED_VIDEO_COUNT', 503)
        is_migration_complete = ready_count == expected_count

        data = {
            'total_videos': total_videos,
            'ready_count': ready_count,
            'preparing_count': preparing_count,
            'errored_count': errored_count,
            'playback_verified_count': playback_verified_count,
            'is_migration_complete': is_migration_complete,
        }

        serializer = VideoHealthSerializer(data)
        return Response(serializer.data)


class VideoMappingListView(APIView):
    """
    GET /api/video-pipeline/mappings/

    Lists MctVideoMapping entries with optional filters.
    Query params: ?status=ready&language=en&course_key=...
    """

    permission_classes = [IsAdminUser]

    def get(self, request):
        mappings = MctVideoMapping.objects.all()

        # Apply filters
        mux_status = request.query_params.get('status')
        if mux_status:
            mappings = mappings.filter(mux_status=mux_status)

        language = request.query_params.get('language')
        if language:
            mappings = mappings.filter(content_language=language)

        course_key = request.query_params.get('course_key')
        if course_key:
            mappings = mappings.filter(course_key=course_key)

        # Pagination
        page_size = int(request.query_params.get('page_size', 50))
        page = int(request.query_params.get('page', 1))

        start = (page - 1) * page_size
        end = start + page_size

        total_count = mappings.count()
        mappings_page = mappings[start:end]

        serializer = MctVideoMappingSerializer(mappings_page, many=True)

        return Response({
            'total_count': total_count,
            'page': page,
            'page_size': page_size,
            'results': serializer.data,
        })


class VideoPlaybackCheckView(APIView):
    """
    POST /api/video-pipeline/playback-check/

    Triggers playback health check for all or a sample of videos.
    Request body: {"sample_size": 10} or {"asset_ids": ["id1","id2"]}
    """

    permission_classes = [IsAdminUser]

    def post(self, request):
        serializer = PlaybackCheckRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        sample_size = serializer.validated_data.get('sample_size')
        asset_ids = serializer.validated_data.get('asset_ids')

        # Determine which mappings to check
        if asset_ids:
            mappings = MctVideoMapping.objects.filter(mux_asset_id__in=asset_ids)
        else:
            mappings = MctVideoMapping.objects.all()

        # Run playback health check
        results = validate_playback_health(mappings, sample_size=sample_size)

        return Response({
            'message': 'Playback health check completed',
            'results': results,
        })


class MigrationReportView(APIView):
    """
    GET /api/video-pipeline/report/

    Returns latest MigrationReport or generates a new one.
    Query param: ?refresh=true to force regeneration.
    """

    permission_classes = [IsAdminUser]

    def get(self, request):
        refresh = request.query_params.get('refresh', 'false').lower() == 'true'

        if refresh:
            # Generate new report
            report_data = generate_migration_report()
            return Response(report_data)
        else:
            # Return latest existing report
            latest = MigrationReport.objects.first()
            if latest:
                serializer = MigrationReportSerializer(latest)
                return Response(serializer.data)
            else:
                # No reports exist, generate one
                report_data = generate_migration_report()
                return Response(report_data)


class VideoMetadataView(APIView):
    """
    GET /api/video-pipeline/metadata/<asset_id>/

    Returns video metadata from Mux API.
    """

    permission_classes = [IsAdminUser]

    def get(self, request, asset_id):
        metadata = get_asset_metadata(asset_id)

        if not metadata:
            return Response(
                {'error': f'Failed to retrieve metadata for asset {asset_id}'},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response(metadata)


# ── Phase 2: XBlock Integration, Subtitles, Protection, Analytics ─────

class XBlockConfigView(APIView):
    """
    GET /api/video-pipeline/xblock-config/<playback_id>/

    Returns Video XBlock configuration for a Mux playback ID.
    Uses playback_id only — never exposes asset_id (AC-VPD-013).
    """

    permission_classes = [IsAuthenticated]

    def get(self, request, playback_id):
        from .xblock_config import build_xblock_config
        from .subtitles import get_subtitle_tracks_for_xblock

        # Look up the mapping to get the asset_id for subtitle lookup
        mapping = MctVideoMapping.objects.filter(mux_playback_id=playback_id).first()
        asset_id = mapping.mux_asset_id if mapping else None

        # Get subtitle tracks if we have an asset_id
        subtitle_tracks = []
        if asset_id:
            subtitle_tracks = get_subtitle_tracks_for_xblock(asset_id)

        # Check if course is restricted
        course_is_restricted = False
        if mapping:
            course_is_restricted = request.query_params.get('restricted', 'false').lower() == 'true'

        config = build_xblock_config(
            playback_id=playback_id,
            course_is_restricted=course_is_restricted,
            subtitle_tracks=subtitle_tracks,
        )

        return Response(config)


class SubtitleUploadView(APIView):
    """
    POST /api/video-pipeline/subtitles/upload/

    Upload a subtitle file to a Mux asset.
    Request body: {"asset_id": "...", "subtitle_url": "...", "language_code": "en", "name": "English"}
    """

    permission_classes = [IsAdminUser]

    def post(self, request):
        from .subtitles import upload_subtitle_track

        asset_id = request.data.get('asset_id')
        subtitle_url = request.data.get('subtitle_url')
        language_code = request.data.get('language_code')
        name = request.data.get('name')
        closed_captions = request.data.get('closed_captions', False)

        if not asset_id or not subtitle_url:
            return Response(
                {'error': 'asset_id and subtitle_url are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            track_data = upload_subtitle_track(
                asset_id=asset_id,
                subtitle_url=subtitle_url,
                language_code=language_code,
                name=name,
                closed_captions=closed_captions,
            )
        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        if not track_data:
            return Response(
                {'error': 'Failed to upload subtitle track'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response(track_data, status=status.HTTP_201_CREATED)


class SubtitleListView(APIView):
    """
    GET /api/video-pipeline/subtitles/<asset_id>/

    List subtitle tracks for a Mux asset.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request, asset_id):
        from .subtitles import list_subtitle_tracks

        tracks = list_subtitle_tracks(asset_id)
        return Response({'tracks': tracks})


class VideoCompletionView(APIView):
    """
    GET /api/video-pipeline/completion/<video_id>/

    Get video completion status for the current user.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request, video_id):
        from .completion import VideoCompletionStatus

        course_key = request.query_params.get('course_key')
        if not course_key:
            return Response(
                {'error': 'course_key query parameter is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            completion = VideoCompletionStatus.objects.get(
                user=request.user, video_id=video_id, course_key=course_key,
            )
            return Response({
                'video_id': completion.video_id,
                'course_key': completion.course_key,
                'completion_percentage': completion.completion_percentage,
                'is_complete': completion.is_complete,
                'max_position_reached': completion.max_position_reached,
                'last_position': completion.last_position,
                'play_count': completion.play_count,
                'first_played_at': completion.first_played_at.isoformat() if completion.first_played_at else None,
                'completed_at': completion.completed_at.isoformat() if completion.completed_at else None,
            })
        except VideoCompletionStatus.DoesNotExist:
            return Response({
                'video_id': video_id,
                'course_key': course_key,
                'completion_percentage': 0.0,
                'is_complete': False,
                'max_position_reached': 0.0,
                'last_position': 0.0,
                'play_count': 0,
            })


class CourseVideoCompletionView(APIView):
    """
    GET /api/video-pipeline/completion/course/<course_key>/

    Get aggregated video completion summary for a course. Admin only.
    """

    permission_classes = [IsAdminUser]

    def get(self, request, course_key):
        from .completion import VideoCompletionStatus

        summary = VideoCompletionStatus.get_course_completion_summary(course_key)
        return Response(summary)


class VideoEventReceiverView(APIView):
    """
    POST /api/video-pipeline/events/

    Receive video playback events and route to:
    1. Completion tracking (update progress)
    2. xAPI emission (to ClickHouse/Aspects)

    Request body:
    {
        "video_id": "playback_id_here",
        "course_key": "course-v1:...",
        "event_type": "played|paused|seeked|completed",
        "position": 120.5,
        "duration": 300.0,
        "session_id": "optional-session-id"
    }

    No PII (email, IP) stored in analytics events (AC-NEG).
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        video_id = request.data.get('video_id')
        course_key = request.data.get('course_key')
        event_type = request.data.get('event_type')
        position = request.data.get('position', 0.0)
        duration = request.data.get('duration')
        session_id = request.data.get('session_id')

        if not video_id or not course_key or not event_type:
            return Response(
                {'error': 'video_id, course_key, and event_type are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        valid_events = ('played', 'paused', 'seeked', 'completed')
        if event_type not in valid_events:
            return Response(
                {'error': f'event_type must be one of: {", ".join(valid_events)}'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # 1. Update completion tracking
        from .completion import VideoCompletionStatus
        completion = VideoCompletionStatus.update_progress(
            user=request.user,
            video_id=video_id,
            course_key=course_key,
            position=float(position),
            duration=float(duration) if duration else None,
            event_type=event_type,
        )

        # 2. Emit xAPI event (no PII — user_id only)
        from .xapi_emitter import emit_video_xapi_event
        emit_video_xapi_event(
            user_id=request.user.id,
            video_id=video_id,
            course_key=course_key,
            event_type=event_type,
            position=float(position),
            duration=float(duration) if duration else None,
            session_id=session_id,
        )

        return Response({
            'status': 'ok',
            'completion_percentage': completion.completion_percentage,
            'is_complete': completion.is_complete,
        }, status=status.HTTP_200_OK)
