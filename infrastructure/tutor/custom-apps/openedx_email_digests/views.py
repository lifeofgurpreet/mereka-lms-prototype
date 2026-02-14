"""
REST API views for digest preferences, click/open tracking, and analytics.

@spec: email-notifications-pipeline_spec.md
@covers: AC-040, AC-041, AC-042
"""

import logging
import uuid

from django.http import HttpResponse, HttpResponseRedirect
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import DigestPreference, DigestRun, EmailEvent
from .serializers import (
    DigestPreferenceSerializer,
    DigestRunSerializer,
    EmailAnalyticsQuerySerializer,
    EmailEventSerializer,
)

logger = logging.getLogger(__name__)

# 1x1 transparent PNG pixel for open tracking
TRACKING_PIXEL = (
    b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01'
    b'\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89'
    b'\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01'
    b'\r\n\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
)


class DigestPreferenceView(APIView):
    """Manage digest preferences for the authenticated user."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get digest preferences for current user."""
        org_slug = request.query_params.get('org_slug', 'default')
        pref = DigestPreference.get_preference(request.user, org_slug)
        if pref:
            return Response(DigestPreferenceSerializer(pref).data)
        return Response({
            'frequency': 'none',
            'org_slug': org_slug,
            'message_types': [],
            'user_timezone': 'Asia/Kuala_Lumpur',
        })

    def post(self, request):
        """Create or update digest preference."""
        serializer = DigestPreferenceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        org_slug = serializer.validated_data.get('org_slug', 'default')
        pref, _ = DigestPreference.objects.update_or_create(
            user=request.user,
            org_slug=org_slug,
            defaults={
                'frequency': serializer.validated_data['frequency'],
                'message_types': serializer.validated_data.get('message_types', []),
                'user_timezone': serializer.validated_data.get(
                    'user_timezone', 'Asia/Kuala_Lumpur'
                ),
                'is_active': True,
            }
        )
        return Response(DigestPreferenceSerializer(pref).data)


class ClickTrackingView(APIView):
    """
    Click tracking redirect endpoint.

    Logs the click event and redirects to the original URL.
    Must complete redirect within 200ms (spec requirement).

    @covers AC-041
    """

    permission_classes = []  # Public endpoint (accessed from email links)
    authentication_classes = []

    def get(self, request, tracking_id):
        """Record click event and redirect to original URL."""
        try:
            event = EmailEvent.objects.get(
                tracking_id=tracking_id,
                event_type='click',
            )
        except EmailEvent.DoesNotExist:
            # Tracking ID not found — redirect to homepage
            logger.warning("Click tracking ID not found: %s", tracking_id)
            return HttpResponseRedirect('/')

        # Record the click (update existing placeholder or create new)
        EmailEvent.record_event(
            message_id=event.message_id,
            event_type='click',
            user=event.user,
            campaign_id=event.campaign_id,
            template_category=event.template_category,
            org_slug=event.org_slug,
            tracking_id=f"{tracking_id}-{uuid.uuid4().hex[:8]}",
            url=event.url,
            user_agent=request.META.get('HTTP_USER_AGENT', ''),
            ip_address=_get_client_ip(request),
            timestamp=timezone.now(),
        )

        logger.info("Click tracked: tracking_id=%s url=%s", tracking_id, event.url)
        return HttpResponseRedirect(event.url)


class OpenTrackingView(APIView):
    """
    Open tracking via 1x1 transparent pixel.

    Returns a transparent PNG and records the open event.

    @covers AC-040
    """

    permission_classes = []  # Public endpoint (loaded by email client)
    authentication_classes = []

    def get(self, request, tracking_id):
        """Record open event and return tracking pixel."""
        try:
            event = EmailEvent.objects.filter(
                tracking_id=tracking_id,
            ).first()

            if event:
                EmailEvent.record_event(
                    message_id=event.message_id,
                    event_type='open',
                    user=event.user,
                    campaign_id=event.campaign_id,
                    template_category=event.template_category,
                    org_slug=event.org_slug,
                    tracking_id=f"open-{tracking_id}-{uuid.uuid4().hex[:8]}",
                    user_agent=request.META.get('HTTP_USER_AGENT', ''),
                    ip_address=_get_client_ip(request),
                    timestamp=timezone.now(),
                )
                logger.info("Open tracked: tracking_id=%s", tracking_id)
        except Exception:
            logger.exception("Error recording open event for %s", tracking_id)

        # Always return the pixel regardless of tracking success
        response = HttpResponse(TRACKING_PIXEL, content_type='image/png')
        response['Cache-Control'] = 'no-store, no-cache, must-revalidate'
        return response


class EmailAnalyticsDashboardView(APIView):
    """
    Admin analytics dashboard API.

    Returns engagement metrics: open rate, click rate, bounce rate,
    delivery rate per template and campaign. Per-tenant isolation enforced.

    @covers AC-042
    """

    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        """
        Query email analytics.

        Query params:
            org_slug (required): Tenant slug for isolation
            template: Filter by template category
            campaign_id: Filter by campaign ID
            days: Lookback period (default 30)
        """
        org_slug = request.query_params.get('org_slug')
        if not org_slug:
            return Response(
                {'error': 'org_slug is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        template_category = request.query_params.get('template')
        campaign_id = request.query_params.get('campaign_id')
        days = int(request.query_params.get('days', '30'))

        stats = EmailEvent.get_aggregate_stats(
            org_slug=org_slug,
            template_category=template_category,
            campaign_id=campaign_id,
            days=days,
        )

        return Response({
            'org_slug': org_slug,
            'period_days': days,
            'template': template_category,
            'campaign_id': campaign_id,
            **stats,
        })


class DigestRunListView(APIView):
    """List digest runs for admin monitoring."""

    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        """List recent digest runs."""
        org_slug = request.query_params.get('org_slug', 'default')
        runs = DigestRun.objects.filter(org_slug=org_slug)[:50]
        serializer = DigestRunSerializer(runs, many=True)
        return Response(serializer.data)


def _get_client_ip(request):
    """Extract client IP from request, respecting X-Forwarded-For."""
    xff = request.META.get('HTTP_X_FORWARDED_FOR')
    if xff:
        return xff.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')
