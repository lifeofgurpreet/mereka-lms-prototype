"""
URL configuration for DID document endpoint.

@covers AC-CRED-010
@spec: verifiable-credentials-issuer_spec.md (CRED-020)
"""

from django.urls import path

from .views import did_document_view

app_name = 'credentials_vc_issuer'

urlpatterns = [
    path('.well-known/did.json', did_document_view, name='did-document'),
]
