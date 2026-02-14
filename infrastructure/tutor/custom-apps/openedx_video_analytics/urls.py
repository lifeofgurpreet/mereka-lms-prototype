"""
Video Analytics URL Configuration

URL routing for video analytics API endpoints.

@spec: video-pipeline-delivery_spec.md (Phase 4)
@bead: mereka-lms-17jr
"""

from django.urls import path
from . import views

app_name = 'openedx_video_analytics'

urlpatterns = [
    # Record video playback event
    path(
        'events/',
        views.record_video_event_view,
        name='record-event'
    ),

    # Get aggregated analytics
    path(
        'analytics/',
        views.get_video_analytics_view,
        name='get-analytics'
    ),
]
