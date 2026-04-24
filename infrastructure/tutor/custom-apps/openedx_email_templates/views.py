"""
REST API views for email templates and bulk campaigns.

@spec: email-notifications-pipeline_spec.md
@covers: AC-027, AC-028, AC-029, AC-030
"""

import logging

from rest_framework import status
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Campaign, CampaignRecipient, Template
from .serializers import (
    CampaignCreateSerializer,
    CampaignDetailSerializer,
    CampaignListSerializer,
    TemplateSerializer,
)

logger = logging.getLogger(__name__)


class TemplateListView(APIView):
    """List and create email templates (admin only)."""

    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        """List templates, optionally filtered by category and org_slug."""
        queryset = Template.objects.filter(is_active=True)

        category = request.query_params.get('category')
        if category:
            queryset = queryset.filter(category=category)

        org_slug = request.query_params.get('org_slug')
        if org_slug:
            queryset = queryset.filter(org_slug=org_slug)

        serializer = TemplateSerializer(queryset, many=True)
        return Response(serializer.data)

    def post(self, request):
        """Create a new email template."""
        serializer = TemplateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class CampaignListView(APIView):
    """List and create bulk campaigns (admin only)."""

    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        """List campaigns for the given org_slug."""
        org_slug = request.query_params.get('org_slug', 'default')
        queryset = Campaign.objects.filter(org_slug=org_slug)

        status_filter = request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)

        serializer = CampaignListSerializer(queryset, many=True)
        return Response(serializer.data)

    def post(self, request):
        """Create a new campaign (draft status)."""
        serializer = CampaignCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        campaign = serializer.save(created_by=request.user)
        return Response(
            CampaignDetailSerializer(campaign).data,
            status=status.HTTP_201_CREATED,
        )


class CampaignActionView(APIView):
    """Campaign actions: send, schedule, pause, resume, cancel."""

    permission_classes = [IsAuthenticated, IsAdminUser]

    def post(self, request, campaign_id, action):
        """Execute an action on a campaign."""
        try:
            campaign = Campaign.objects.get(id=campaign_id)
        except Campaign.DoesNotExist:
            return Response(
                {'error': 'Campaign not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if action == 'send':
            return self._send(campaign)
        elif action == 'schedule':
            scheduled_at = request.data.get('scheduled_at')
            if not scheduled_at:
                return Response(
                    {'error': 'scheduled_at required'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            campaign.schedule(scheduled_at)
            return Response(CampaignDetailSerializer(campaign).data)
        elif action == 'pause':
            campaign.pause()
            return Response(CampaignDetailSerializer(campaign).data)
        elif action == 'resume':
            campaign.resume()
            return Response(CampaignDetailSerializer(campaign).data)
        elif action == 'cancel':
            campaign.cancel()
            return Response(CampaignDetailSerializer(campaign).data)
        else:
            return Response(
                {'error': f'Unknown action: {action}'},
                status=status.HTTP_400_BAD_REQUEST,
            )

    def _send(self, campaign):
        """Trigger campaign sending via Celery task."""
        if campaign.status not in ('draft', 'scheduled'):
            return Response(
                {'error': f'Cannot send campaign in {campaign.status} status'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from .tasks import execute_campaign
        execute_campaign.delay(str(campaign.id))

        return Response(
            {'status': 'queued', 'campaign_id': str(campaign.id)},
            status=status.HTTP_202_ACCEPTED,
        )
