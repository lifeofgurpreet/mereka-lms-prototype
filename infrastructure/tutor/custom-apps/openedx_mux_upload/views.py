"""
Mux Upload Views

REST API endpoints for Mux video upload workflow.

@spec: video-pipeline-delivery_spec.md (Phase 3)
@covers: AC-VPD-003, AC-VPD-004
"""

import os
import logging
from django.conf import settings
from django.views.decorators.csrf import csrf_exempt
from django.http import HttpResponse
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from opaque_keys.edx.keys import CourseKey
from opaque_keys import InvalidKeyError

from .models import MuxUpload
from .serializers import (
    CreateDirectUploadSerializer,
    MuxUploadSerializer,
    MuxWebhookEventSerializer,
)
from .utils import create_direct_upload, get_asset, verify_mux_webhook_signature

logger = logging.getLogger(__name__)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_direct_upload_view(request):
    """
    Create a Mux direct upload URL for Studio video upload.

    POST /api/mux/upload/create/

    Request Body:
        {
            "course_key": "course-v1:MerekaAcademy+COURSE101+2024",
            "filename": "lesson-1-intro.mp4",
            "filesize_bytes": 52428800,
            "video_title": "Lesson 1: Introduction"
        }

    Response (200 OK):
        {
            "upload_id": "abcd1234",
            "upload_url": "https://storage.googleapis.com/...",
            "timeout": 172800,
            "mux_upload_id": 42
        }

    Error Responses:
        - 400 Bad Request: Invalid course_key or missing required fields
        - 500 Internal Server Error: Mux API failure

    Performance Target: <= 2 seconds (AC-VPD-003)

    @covers: AC-VPD-003
    """
    serializer = CreateDirectUploadSerializer(data=request.data)
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

    # Check feature flag
    if not getattr(settings, 'ENABLE_MUX_STUDIO_UPLOAD', False):
        return Response(
            {'error': 'Mux Studio upload is not enabled. Set ENABLE_MUX_STUDIO_UPLOAD=true.'},
            status=status.HTTP_503_SERVICE_UNAVAILABLE
        )

    # Create Mux direct upload via API
    try:
        new_asset_settings = {
            'playback_policy': ['public'],  # Default to public; signed playback in Phase 5
            'passthrough': f"course_key={course_key}",
        }

        mux_upload_data = create_direct_upload(
            timeout=172800,  # 48 hours
            cors_origin='*',  # Allow CORS for Studio frontend
            new_asset_settings=new_asset_settings
        )

    except Exception as e:
        logger.error(f"Mux direct upload creation failed: {str(e)}")
        return Response(
            {'error': f'Failed to create Mux upload: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

    # Create MuxUpload database record
    mux_upload = MuxUpload.objects.create(
        user=request.user,
        course_key=course_key,
        upload_id=mux_upload_data['id'],
        status='pending',
        filename=serializer.validated_data.get('filename'),
        filesize_bytes=serializer.validated_data.get('filesize_bytes'),
        video_title=serializer.validated_data.get('video_title'),
    )

    logger.info(
        f"Mux direct upload created: user={request.user.username}, "
        f"course={course_key}, upload_id={mux_upload_data['id']}, "
        f"db_id={mux_upload.id}"
    )

    return Response({
        'upload_id': mux_upload_data['id'],
        'upload_url': mux_upload_data['url'],
        'timeout': mux_upload_data['timeout'],
        'mux_upload_id': mux_upload.id,
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_upload_status_view(request, upload_id):
    """
    Get the status of a Mux upload.

    GET /api/mux/upload/{upload_id}/status/

    Response (200 OK):
        {
            "id": 42,
            "upload_id": "abcd1234",
            "status": "ready",
            "asset_id": "xyz789",
            "playback_id": "efg456",
            "error_message": null,
            ...
        }

    Error Responses:
        - 404 Not Found: Upload ID does not exist
    """
    try:
        mux_upload = MuxUpload.objects.get(upload_id=upload_id, user=request.user)
    except MuxUpload.DoesNotExist:
        return Response(
            {'error': 'Upload not found'},
            status=status.HTTP_404_NOT_FOUND
        )

    serializer = MuxUploadSerializer(mux_upload)
    return Response(serializer.data, status=status.HTTP_200_OK)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])  # Webhooks don't use session auth
def mux_webhook_handler(request):
    """
    Handle Mux webhook events.

    POST /api/mux/webhook/

    Expected Events:
        - video.upload.asset_created: Upload completed, asset created
        - video.asset.ready: Video transcoding completed
        - video.asset.errored: Video processing failed

    Webhook Payload:
        {
            "type": "video.asset.ready",
            "data": {
                "id": "asset_id",
                "status": "ready",
                "playback_ids": [{"id": "playback_id", "policy": "public"}],
                ...
            }
        }

    Security:
        - Mux-Signature header verification (optional, recommended for production)
        - IP allowlist (optional)

    Response:
        - 200 OK: Event processed successfully
        - 400 Bad Request: Invalid payload
        - 404 Not Found: Upload ID not found in database

    @covers: AC-VPD-004
    """
    # Verify webhook signature (optional but recommended)
    webhook_secret = os.environ.get('MUX_WEBHOOK_SECRET')
    if webhook_secret:
        mux_signature = request.headers.get('Mux-Signature', '')
        if not verify_mux_webhook_signature(request.body, mux_signature, webhook_secret):
            logger.warning("Mux webhook signature verification failed")
            return HttpResponse("Invalid signature", status=403)

    # Parse webhook payload
    serializer = MuxWebhookEventSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    event_type = serializer.validated_data['type']
    event_data = serializer.validated_data['data']

    logger.info(f"Mux webhook received: type={event_type}, data_id={event_data.get('id')}")

    # Handle different event types
    if event_type == 'video.upload.asset_created':
        # Upload completed, asset created (but not yet transcoded)
        upload_id = event_data.get('id')
        asset_id = event_data.get('asset_id')

        try:
            mux_upload = MuxUpload.objects.get(upload_id=upload_id)
            mux_upload.status = 'processing'
            mux_upload.asset_id = asset_id
            mux_upload.webhook_payload = event_data
            mux_upload.save(update_fields=['status', 'asset_id', 'webhook_payload', 'updated_at'])

            logger.info(f"Upload asset created: upload_id={upload_id}, asset_id={asset_id}")

        except MuxUpload.DoesNotExist:
            logger.warning(f"Upload not found in database: upload_id={upload_id}")
            return HttpResponse("Upload not found", status=404)

    elif event_type == 'video.asset.ready':
        # Video transcoding completed
        asset_id = event_data.get('id')
        playback_ids = event_data.get('playback_ids', [])
        playback_id = playback_ids[0]['id'] if playback_ids else None

        try:
            # Find upload by asset_id
            mux_upload = MuxUpload.objects.get(asset_id=asset_id)
            mux_upload.mark_ready(asset_id=asset_id, playback_id=playback_id)
            mux_upload.webhook_payload = event_data
            mux_upload.save(update_fields=['webhook_payload'])

            logger.info(
                f"Asset ready: asset_id={asset_id}, playback_id={playback_id}, "
                f"upload_id={mux_upload.upload_id}"
            )

        except MuxUpload.DoesNotExist:
            logger.warning(f"Upload not found for asset: asset_id={asset_id}")
            return HttpResponse("Asset not found", status=404)

    elif event_type == 'video.asset.errored':
        # Video processing failed
        asset_id = event_data.get('id')
        error_messages = event_data.get('errors', {}).get('messages', [])
        error_message = '; '.join(error_messages) if error_messages else 'Unknown error'

        try:
            mux_upload = MuxUpload.objects.get(asset_id=asset_id)
            mux_upload.mark_errored(error_message=error_message)
            mux_upload.webhook_payload = event_data
            mux_upload.save(update_fields=['webhook_payload'])

            logger.error(
                f"Asset errored: asset_id={asset_id}, "
                f"upload_id={mux_upload.upload_id}, error={error_message}"
            )

        except MuxUpload.DoesNotExist:
            logger.warning(f"Upload not found for errored asset: asset_id={asset_id}")
            return HttpResponse("Asset not found", status=404)

    else:
        # Unhandled event type (log but don't fail)
        logger.info(f"Unhandled Mux webhook event type: {event_type}")

    return HttpResponse("OK", status=200)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_uploads_view(request):
    """
    List Mux uploads for the current user.

    GET /api/mux/upload/list/?course_key=...&status=...

    Query Parameters:
        - course_key (optional): Filter by course
        - status (optional): Filter by status (pending, ready, errored, etc.)

    Response (200 OK):
        {
            "count": 10,
            "results": [...]
        }
    """
    queryset = MuxUpload.objects.filter(user=request.user)

    # Filter by course_key
    course_key_str = request.query_params.get('course_key')
    if course_key_str:
        try:
            course_key = CourseKey.from_string(course_key_str)
            queryset = queryset.filter(course_key=course_key)
        except InvalidKeyError:
            return Response(
                {'error': 'Invalid course_key format'},
                status=status.HTTP_400_BAD_REQUEST
            )

    # Filter by status
    status_filter = request.query_params.get('status')
    if status_filter:
        queryset = queryset.filter(status=status_filter)

    serializer = MuxUploadSerializer(queryset, many=True)

    return Response({
        'count': queryset.count(),
        'results': serializer.data,
    }, status=status.HTTP_200_OK)
