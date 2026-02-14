"""
URL patterns for notification preferences API.
"""

from django.urls import path
from .views import PreferencesListView, PreferencesUpdateView, UnsubscribeView

app_name = 'mereka_email_preferences'

urlpatterns = [
    # GET /api/notifications/v1/preferences/ - AC-020
    path('', PreferencesListView.as_view(), name='preferences-list'),

    # PUT /api/notifications/v1/preferences/ - AC-021
    path('update/', PreferencesUpdateView.as_view(), name='preferences-update'),

    # GET /api/notifications/v1/unsubscribe/?token=<hmac> - AC-022
    path('unsubscribe/', UnsubscribeView.as_view(), name='unsubscribe'),
]
