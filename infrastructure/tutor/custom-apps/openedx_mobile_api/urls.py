"""
URL configuration for Mobile Backend API.

@spec: Mobile Backend API (mereka-lms-2gck)
@covers: AC-MOB-001, AC-MOB-002, AC-MOB-003
"""

from django.urls import path, include
from .views import MobileBrandingConfigView, DeviceRegistrationView

app_name = "mobile_api"

urlpatterns = [
    # Branding config (AC-MOB-001)
    path(
        "config/<str:org_slug>/",
        MobileBrandingConfigView.as_view(),
        name="branding-config"
    ),
    # Device registration (AC-MOB-002, AC-MOB-003)
    path(
        "notifications/register/",
        DeviceRegistrationView.as_view(),
        name="device-registration"
    ),
    # iOS-specific endpoints (Phase 2)
    path(
        "ios/",
        include("openedx_mobile_api.ios_urls")
    ),
]
