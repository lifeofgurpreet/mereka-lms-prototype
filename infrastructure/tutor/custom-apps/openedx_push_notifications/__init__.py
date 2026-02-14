"""
Push notification dispatch via Firebase Cloud Messaging (FCM) for Open edX.

This Django app provides:
- Device token registration and lifecycle management
- ACE push channel for FCM delivery
- Batch push sender (500 per request to FCM)
- Multi-tenant device isolation by org_slug

@spec: email-notifications-pipeline_spec.md (Phase 4: Push Notifications)
@covers: AC-015 through AC-019
"""

__version__ = '1.0.0'

default_app_config = 'openedx_push_notifications.apps.OpenedxPushNotificationsConfig'
