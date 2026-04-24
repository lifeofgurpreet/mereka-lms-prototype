"""
URL configuration for MFE OAuth fix.

This overrides the /api/mfe_context endpoint to properly return OAuth providers.
"""

from django.urls import path
from .views import MFEContextView

urlpatterns = [
    path('api/mfe_context', MFEContextView.as_view(), name='mfe_context'),
]
