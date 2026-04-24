"""
Django app configuration for credentials_vc_issuer.
"""

from django.apps import AppConfig


class CredentialsVcIssuerConfig(AppConfig):
    """App configuration for Verifiable Credentials issuer identity."""

    default_auto_field = 'django.db.models.BigAutoField'
    name = 'credentials_vc_issuer'
    verbose_name = 'Verifiable Credentials Issuer Identity'
