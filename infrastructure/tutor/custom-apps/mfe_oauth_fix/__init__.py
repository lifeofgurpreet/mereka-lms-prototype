"""
Custom Django app to fix /api/mfe_context OAuth provider visibility.

This app overrides the default mfe_context endpoint to properly return
OAuth providers configured for the current site.
"""

default_app_config = 'mfe_oauth_fix.apps.MFEOAuthFixConfig'
