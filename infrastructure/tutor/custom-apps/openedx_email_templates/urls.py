"""
URL routing for email templates and campaigns API.

@spec: email-notifications-pipeline_spec.md
"""

from django.urls import path

from .views import CampaignActionView, CampaignListView, TemplateListView

app_name = 'openedx_email_templates'

urlpatterns = [
    path('templates/', TemplateListView.as_view(), name='template-list'),
    path('campaigns/', CampaignListView.as_view(), name='campaign-list'),
    path(
        'campaigns/<uuid:campaign_id>/<str:action>/',
        CampaignActionView.as_view(),
        name='campaign-action',
    ),
]
