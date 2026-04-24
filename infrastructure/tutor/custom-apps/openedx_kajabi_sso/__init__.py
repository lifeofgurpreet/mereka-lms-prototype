"""
Kajabi SSO/OAuth Integration for Open edX.

This Django app handles SSO for Kajabi-migrated users and provides bulk import
functionality for Kajabi user databases.

@spec: kajabi-sso
@covers: AC-SSO-001 through AC-SSO-005
"""

__version__ = '1.0.0'

default_app_config = 'openedx_kajabi_sso.apps.OpenedxKajabiSsoConfig'
