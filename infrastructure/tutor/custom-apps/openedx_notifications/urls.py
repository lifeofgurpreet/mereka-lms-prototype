"""
URL configuration for in-app notifications API.

@spec: email-notifications-pipeline_spec.md
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import NotificationViewSet

app_name = 'openedx_notifications'

# DRF router for notification endpoints
router = DefaultRouter()
router.register(r'', NotificationViewSet, basename='notification')

urlpatterns = [
    path('', include(router.urls)),
]
