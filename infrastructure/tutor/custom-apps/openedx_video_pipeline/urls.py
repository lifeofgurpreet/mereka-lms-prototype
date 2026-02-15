from django.urls import path

from . import views

app_name = 'openedx_video_pipeline'

urlpatterns = [
    path('health/', views.VideoHealthCheckView.as_view(), name='health-check'),
    path('mappings/', views.VideoMappingListView.as_view(), name='mapping-list'),
    path('playback-check/', views.VideoPlaybackCheckView.as_view(), name='playback-check'),
    path('report/', views.MigrationReportView.as_view(), name='migration-report'),
    path('metadata/<str:asset_id>/', views.VideoMetadataView.as_view(), name='video-metadata'),
]
