"""
In-app notification tray and ACE channel for Open edX.

This Django app provides:
- Notification store backed by MySQL
- REST API for notification tray (list, read, unread count, delete)
- ACE in_app channel for notification delivery
- Multi-tenant notification isolation by org_slug
- Notification expiry and purge logic

@spec: email-notifications-pipeline_spec.md (Phase 3: In-App Notifications)
@covers: AC-010 through AC-014
"""

__version__ = '1.0.0'

default_app_config = 'openedx_notifications.apps.OpenedxNotificationsConfig'
