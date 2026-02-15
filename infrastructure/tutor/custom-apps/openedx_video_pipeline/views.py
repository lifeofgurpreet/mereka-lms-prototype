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
