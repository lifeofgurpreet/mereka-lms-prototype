"""
URL routing for email digests and analytics API.

@spec: email-notifications-pipeline_spec.md
"""

from django.urls import path

from .views import (
    ClickTrackingView,
    DigestPreferenceView,
    DigestRunListView,
    EmailAnalyticsDashboardView,
    OpenTrackingView,
)

app_name = 'openedx_email_digests'

urlpatterns = [
    # Digest preferences (authenticated users)
    path('preferences/', DigestPreferenceView.as_view(), name='digest-preferences'),

    # Click/open tracking (public endpoints)
    path(
        'track/click/<str:tracking_id>/',
        ClickTrackingView.as_view(),
        name='click-tracking',
    ),
    path(
        'track/open/<str:tracking_id>.png',
        OpenTrackingView.as_view(),
        name='open-tracking',
    ),

    # Admin analytics
    path('analytics/', EmailAnalyticsDashboardView.as_view(), name='analytics-dashboard'),
    path('runs/', DigestRunListView.as_view(), name='digest-runs'),
]
