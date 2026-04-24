"""
Mux Upload URL Configuration

URL routing for Mux video upload API endpoints.

@spec: video-pipeline-delivery_spec.md (Phase 3)
"""

from django.urls import path
from . import views

app_name = 'openedx_mux_upload'

urlpatterns = [
    # Direct upload creation
    path(
        'create/',
        views.create_direct_upload_view,
        name='create-direct-upload'
    ),

    # Upload status
    path(
        '<str:upload_id>/status/',
        views.get_upload_status_view,
        name='get-upload-status'
    ),

    # List uploads
    path(
        'list/',
        views.list_uploads_view,
        name='list-uploads'
    ),

    # Mux webhook handler
    path(
        'webhook/',
        views.mux_webhook_handler,
        name='mux-webhook'
    ),
]
