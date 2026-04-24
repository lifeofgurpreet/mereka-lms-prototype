"""
URL configuration for email preferences API.

@spec: email-notifications-pipeline_spec.md
@bead: mereka-lms-bnw1
"""

from django.urls import path

from .views import (
    email_preferences_view,
    one_click_unsubscribe_view,
    consent_records_admin_view,
)

app_name = 'openedx_email_preferences'

urlpatterns = [
    # User preferences API
    path('', email_preferences_view, name='email-preferences'),

    # One-click unsubscribe (RFC 8058)
    path('unsubscribe/<str:token>/', one_click_unsubscribe_view, name='one-click-unsubscribe'),

    # Admin API for GDPR SAR
    path('admin/consent-records/', consent_records_admin_view, name='admin-consent-records'),
]
