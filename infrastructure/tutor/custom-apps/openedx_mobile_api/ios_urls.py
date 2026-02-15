"""
iOS-specific URL configuration.

@spec: Mobile Phase 2 - iOS Stabilization (mereka-lms-36f7)
@covers: AC-MOB-008, AC-MOB-009, AC-MOB-010, AC-MOB-011, AC-MOB-012
"""

from django.urls import path
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
]
