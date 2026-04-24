"""
iOS-specific URL configuration.

@spec: Mobile Phase 2 - iOS Stabilization (mereka-lms-36f7)
@spec: Mobile Phase 4 - iOS Release (mereka-lms-39ty)
@covers: AC-MOB-008 through AC-MOB-023
"""

from django.urls import path, include
from .ios_views import (
    PKCEChallengeView,
    TokenRefreshView,
    TokenRevokeView,
    APNsDeliveryView,
)

app_name = "mobile_api_ios"

urlpatterns = [
    # PKCE OAuth2 flow (AC-MOB-008)
    path(
        "auth/pkce/challenge/",
        PKCEChallengeView.as_view(),
        name="pkce-challenge"
    ),
    # Token lifecycle (AC-MOB-009, AC-MOB-010, AC-MOB-011)
    path(
        "auth/token/refresh/",
        TokenRefreshView.as_view(),
        name="token-refresh"
    ),
    path(
        "auth/token/revoke/",
        TokenRevokeView.as_view(),
        name="token-revoke"
    ),
    # APNs push notifications (AC-MOB-012)
    path(
        "notifications/apns/",
        APNsDeliveryView.as_view(),
        name="apns-delivery"
    ),

    # Phase 4: Offline mode and Universal Links (AC-MOB-016 through AC-MOB-019)
    path("", include("openedx_mobile_api.ios_offline_urls")),

    # Phase 4: App Store release (AC-MOB-020 through AC-MOB-023)
    path("", include("openedx_mobile_api.ios_release_urls")),
]
