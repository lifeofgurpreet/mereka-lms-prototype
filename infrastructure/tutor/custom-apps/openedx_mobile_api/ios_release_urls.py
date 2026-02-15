"""
iOS App Store release URL configuration.

@spec: Mobile Phase 4 - iOS Release (mereka-lms-39ty)
@covers: AC-MOB-020, AC-MOB-021, AC-MOB-022, AC-MOB-023
"""

from django.urls import path
from .ios_release_views import (
    AppStoreMetadataView,
    AppStoreScreenshotsView,
    AppStoreReviewNotesView,
    IOSBrandingView,
)

urlpatterns = [
    # App Store metadata
    path("app-store/metadata/", AppStoreMetadataView.as_view(), name="app-store-metadata-default"),
    path("app-store/metadata/<str:language>/", AppStoreMetadataView.as_view(), name="app-store-metadata"),

    # App Store screenshots
    path("app-store/screenshots/<str:language>/<str:device_type>/", AppStoreScreenshotsView.as_view(), name="app-store-screenshots"),

    # App Store review notes (staff only)
    path("app-store/review-notes/<str:version>/", AppStoreReviewNotesView.as_view(), name="app-store-review-notes"),

    # iOS branding
    path("branding/", IOSBrandingView.as_view(), name="ios-branding-default"),
    path("branding/<str:org_slug>/", IOSBrandingView.as_view(), name="ios-branding"),
]
