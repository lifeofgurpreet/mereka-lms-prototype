"""
Email preferences and GDPR consent management for Open edX.

This Django app provides:
- Per-user email category preferences (marketing, transactional, announcements)
- GDPR-compliant consent tracking with version control
- One-click unsubscribe via HMAC-signed URLs (RFC 8058)
- REST API for preference management
- ACE dispatch integration for preference enforcement
- Admin API for GDPR SAR (Subject Access Request) compliance

@spec: email-notifications-pipeline_spec.md (Phase 2: Notification Preferences)
@bead: mereka-lms-bnw1
@covers: AC-020 through AC-024, AC-043, AC-044, AC-045
"""

__version__ = '1.0.0'

default_app_config = 'openedx_email_preferences.apps.OpenedxEmailPreferencesConfig'
