"""URL patterns for Video Content Protection API"""
from django.urls import path

from .views import check_video_access_view, generate_signed_url_view

app_name = 'openedx_video_protection'

urlpatterns = [
    path('signed-url/', generate_signed_url_view, name='generate_signed_url'),
    path('check-access/', check_video_access_view, name='check_video_access'),
]
