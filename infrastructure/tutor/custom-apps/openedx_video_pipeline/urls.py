from django.urls import path

from . import views

app_name = 'openedx_video_pipeline'

urlpatterns = [
    path('health/', views.VideoHealthCheckView.as_view(), name='health-check'),
    path('mappings/', views.VideoMappingListView.as_view(), name='mapping-list'),
    path('playback-check/', views.VideoPlaybackCheckView.as_view(), name='playback-check'),
    path('report/', views.MigrationReportView.as_view(), name='migration-report'),
    path('metadata/<str:asset_id>/', views.VideoMetadataView.as_view(), name='video-metadata'),
    # Phase 2: XBlock integration, subtitles, protection, analytics
    path('xblock-config/<str:playback_id>/', views.XBlockConfigView.as_view(), name='xblock-config'),
    path('subtitles/upload/', views.SubtitleUploadView.as_view(), name='subtitle-upload'),
    path('subtitles/<str:asset_id>/', views.SubtitleListView.as_view(), name='subtitle-list'),
    path('completion/<str:video_id>/', views.VideoCompletionView.as_view(), name='video-completion'),
    path('completion/course/<str:course_key>/', views.CourseVideoCompletionView.as_view(), name='course-completion'),
    path('events/', views.VideoEventReceiverView.as_view(), name='video-events'),
]
