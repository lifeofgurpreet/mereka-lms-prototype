"""
Kajabi SSO/OAuth Integration for Open edX

Provides seamless SSO login for Kajabi-migrated users via OAuth2,
bulk CSV import with email deduplication, SSO fallback to email/password,
and welcome email notifications.

@spec: Kajabi SSO Migration (mereka-lms-f98)
@covers: AC-SSO-001 through AC-SSO-005
"""

default_app_config = "openedx_kajabi_sso.apps.KajabiSSOConfig"
