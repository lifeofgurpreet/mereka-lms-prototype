"""
Mobile Backend API for Open edX

Provides backend infrastructure for native mobile apps:
- Tenant branding configuration API
- FCM push notification device registration
- Deep linking well-known files (AASA for iOS, assetlinks.json for Android)
- App version compatibility checks

@spec: Mobile Backend API (mereka-lms-2gck)
@covers: AC-MOB-001 through AC-MOB-007
"""

default_app_config = "openedx_mobile_api.apps.MobileAPIConfig"
