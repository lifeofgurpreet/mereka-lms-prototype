"""
iOS offline mode URL configuration.

@spec: Mobile Phase 4 - iOS Release (mereka-lms-39ty)
@covers: AC-MOB-016, AC-MOB-017, AC-MOB-018, AC-MOB-019
"""

from django.urls import path
from .ios_offline_views import (
    OfflineCourseListView,
    OfflineCourseDownloadView,
    OfflineCourseProgressView,
    OfflineCourseDeleteView,
    OfflineVideoListView,
    UniversalLinkVerificationView,
)

urlpatterns = [
    # Offline courses
    path("offline/courses/", OfflineCourseListView.as_view(), name="offline-courses-list"),
    path("offline/courses/<str:course_id>/download/", OfflineCourseDownloadView.as_view(), name="offline-course-download"),
    path("offline/courses/<str:course_id>/progress/", OfflineCourseProgressView.as_view(), name="offline-course-progress"),
    path("offline/courses/<str:course_id>/", OfflineCourseDeleteView.as_view(), name="offline-course-delete"),

    # Offline videos
    path("offline/courses/<str:course_id>/videos/", OfflineVideoListView.as_view(), name="offline-videos-list"),

    # Universal Links verification
    path("universal-links/verify/", UniversalLinkVerificationView.as_view(), name="universal-link-verify"),
]
