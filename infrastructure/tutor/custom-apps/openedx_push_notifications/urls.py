"""
URL configuration for push notification device registration API.

@spec: email-notifications-pipeline_spec.md
"""

from django.urls import path

from .views import DeviceRegistrationView

app_name = 'openedx_push_notifications'

urlpatterns = [
    path('register/', DeviceRegistrationView.as_view(), name='device-register'),
]
