"""
REST API views for in-app notifications.

@spec: email-notifications-pipeline_spec.md
@covers: AC-010, AC-011, AC-012, AC-013, AC-014
"""

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination

from .models import Notification
from .serializers import NotificationSerializer, UnreadCountSerializer


class NotificationPagination(PageNumberPagination):
    """Pagination for notification list."""

    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


class NotificationViewSet(viewsets.ModelViewSet):
    """
    ViewSet for in-app notifications.

    Provides:
    - List: GET /api/notifications/v1/
    - Retrieve: GET /api/notifications/v1/{id}/
    - Delete: DELETE /api/notifications/v1/{id}/
    - Mark as read: PATCH /api/notifications/v1/{id}/read/
    - Mark all read: POST /api/notifications/v1/mark-all-read/
    - Unread count: GET /api/notifications/v1/unread-count/
    """

    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = NotificationPagination

    def get_queryset(self):
        """
        Get notifications for the authenticated user in their org.

        Filters:
        - read: boolean filter for read/unread
        - message_type: filter by notification type

        @covers AC-011, AC-012, AC-014
        """
        user = self.request.user
        org_slug = self._get_user_org_slug()

        # Get active notifications (non-expired, user's org only)
        queryset = Notification.get_active_notifications(user, org_slug)

        # Apply filters
        read_filter = self.request.query_params.get('read')
        if read_filter is not None:
            read_value = read_filter.lower() in ('true', '1', 'yes')
            queryset = queryset.filter(read=read_value)

        message_type = self.request.query_params.get('message_type')
        if message_type:
            queryset = queryset.filter(message_type=message_type)

        return queryset

    def _get_user_org_slug(self):
        """
        Get the user's current organization slug.

        In production, this would derive from user profile or session.
        For now, use a default or request parameter.
        """
        # TODO: Integrate with multi-tenancy spec to get org_slug from user profile
        return self.request.query_params.get('org_slug', 'default')

    def destroy(self, request, *args, **kwargs):
        """
        Delete a notification (user-initiated).

        @covers: Notification deletion requirement
        """
        instance = self.get_object()

        # Verify user owns this notification
        if instance.user != request.user:
            return Response(
                {"error": "You do not have permission to delete this notification"},
                status=status.HTTP_403_FORBIDDEN
            )

        instance.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['patch'], url_path='read')
    def mark_read(self, request, pk=None):
        """
        Mark a single notification as read.

        PATCH /api/notifications/v1/{id}/read/

        @covers: AC-010 requirement
        """
        notification = self.get_object()

        # Verify user owns this notification
        if notification.user != request.user:
            return Response(
                {"error": "You do not have permission to modify this notification"},
                status=status.HTTP_403_FORBIDDEN
            )

        notification.mark_read()
        serializer = self.get_serializer(notification)
        return Response(serializer.data)

    @action(detail=False, methods=['post'], url_path='mark-all-read')
    def mark_all_read(self, request):
        """
        Mark all unread notifications as read for the authenticated user.

        POST /api/notifications/v1/mark-all-read/

        @covers AC-013
        """
        user = request.user
        org_slug = self._get_user_org_slug()

        count = Notification.mark_all_read(user, org_slug)

        return Response({
            "message": f"Marked {count} notifications as read",
            "count": count
        })

    @action(detail=False, methods=['get'], url_path='unread-count')
    def unread_count(self, request):
        """
        Get count of unread notifications for the authenticated user.

        GET /api/notifications/v1/unread-count/

        Returns: {"unread_count": 5}

        @covers AC-010
        """
        user = request.user
        org_slug = self._get_user_org_slug()

        count = Notification.get_unread_count(user, org_slug)

        serializer = UnreadCountSerializer({"unread_count": count})
        return Response(serializer.data)
