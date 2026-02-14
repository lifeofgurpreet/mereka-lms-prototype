"""
REST API views for email preferences.

@spec: email-notifications-pipeline_spec.md
@bead: mereka-lms-bnw1
@covers: AC-020, AC-021, AC-022, AC-023
"""

import logging
from django.contrib.auth import get_user_model
from django.shortcuts import get_object_or_404
from django.http import HttpResponse, JsonResponse
from django.views.decorators.http import require_http_methods
from django.views.decorators.csrf import csrf_exempt
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from rest_framework.response import Response
from django_ratelimit.decorators import ratelimit

from .models import UserEmailPreference, ConsentRecord
from .serializers import (
    EmailPreferencesResponseSerializer,
    EmailPreferencesUpdateSerializer,
    ConsentRecordSerializer,
)
from .utils import verify_unsubscribe_token

logger = logging.getLogger(__name__)

User = get_user_model()


@api_view(['GET', 'PUT'])
@permission_classes([IsAuthenticated])
@ratelimit(key='user', rate='60/m', method='ALL')
def email_preferences_view(request):
    """
    Get or update email preferences for authenticated user.

    GET: Returns current preferences with defaults
    PUT: Updates preferences and creates audit trail

    Rate limit: 60 requests per minute per user

    @covers AC-020, AC-021, AC-023
    """
    user = request.user

    # Check rate limit
    if getattr(request, 'limited', False):
        return Response(
            {"error": "Rate limit exceeded. Maximum 60 requests per minute."},
            status=status.HTTP_429_TOO_MANY_REQUESTS
        )

    if request.method == 'GET':
        # Get user preferences with defaults
        preferences = UserEmailPreference.get_user_preferences(user)

        serializer = EmailPreferencesResponseSerializer({
            'preferences': preferences
        })

        return Response(serializer.data)

    elif request.method == 'PUT':
        # Update preferences
        serializer = EmailPreferencesUpdateSerializer(data=request.data)

        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        # Get client IP for audit trail
        ip_address = get_client_ip(request)

        # Update each preference
        updated_count = 0
        for pref_data in serializer.validated_data['preferences']:
            category = pref_data['category']
            opted_in = pref_data['opted_in']
            consent_version = pref_data.get('consent_version', 'v1.0-2026-02-14')

            UserEmailPreference.update_user_preference(
                user=user,
                category=category,
                opted_in=opted_in,
                consent_version=consent_version,
                ip_address=ip_address,
            )

            updated_count += 1

        # Return updated preferences
        preferences = UserEmailPreference.get_user_preferences(user)

        logger.info(
            f"Updated {updated_count} email preferences for user {user.username}"
        )

        return Response({
            'preferences': preferences,
            'updated_count': updated_count,
        })


@csrf_exempt
@require_http_methods(["GET", "POST"])
def one_click_unsubscribe_view(request, token):
    """
    One-click unsubscribe endpoint (RFC 8058 compliant).

    Supports both GET (link in email) and POST (client one-click).

    No authentication required - token proves identity.

    @covers AC-022
    """
    # Verify token
    user_id, category = verify_unsubscribe_token(token)

    if user_id is None or category is None:
        return HttpResponse(
            "Invalid or expired unsubscribe link. Please contact support.",
            status=400
        )

    # Get user
    try:
        user = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return HttpResponse("User not found.", status=404)

    # Get client IP for audit trail
    ip_address = get_client_ip(request)

    # Update preference
    UserEmailPreference.update_user_preference(
        user=user,
        category=category,
        opted_in=False,
        consent_version='v1.0-2026-02-14',
        ip_address=ip_address,
    )

    # Log unsubscribe
    logger.info(
        f"One-click unsubscribe: user={user.username}, category={category}, "
        f"ip_hash={UserEmailPreference._hash_ip(ip_address)}"
    )

    # Return success message
    if request.method == 'POST':
        return JsonResponse({
            'success': True,
            'message': f'You have been unsubscribed from {category} emails.',
        })
    else:
        return HttpResponse(
            f"<html><body>"
            f"<h1>Unsubscribe Successful</h1>"
            f"<p>You have been unsubscribed from <strong>{category}</strong> emails.</p>"
            f"<p>You can manage all your email preferences in your account settings.</p>"
            f"</body></html>",
            content_type='text/html'
        )


@api_view(['GET'])
@permission_classes([IsAdminUser])
def consent_records_admin_view(request):
    """
    Admin API to retrieve consent records for GDPR SAR.

    Requires staff permission.

    Query params:
    - user: username or user ID
    - category: filter by category

    @covers AC-044
    """
    # Get query parameters
    user_param = request.query_params.get('user')
    category = request.query_params.get('category')

    if not user_param:
        return Response(
            {"error": "Missing required parameter: user"},
            status=status.HTTP_400_BAD_REQUEST
        )

    # Find user
    try:
        # Try as user ID first
        if user_param.isdigit():
            user = User.objects.get(id=int(user_param))
        else:
            # Try as username
            user = User.objects.get(username=user_param)
    except User.DoesNotExist:
        return Response(
            {"error": f"User not found: {user_param}"},
            status=status.HTTP_404_NOT_FOUND
        )

    # Get consent records
    records = ConsentRecord.get_user_consent_history(user)

    if category:
        records = records.filter(category=category)

    # Serialize
    serializer = ConsentRecordSerializer(records, many=True)

    # Log admin access for audit trail
    logger.info(
        f"GDPR SAR: Admin {request.user.username} accessed consent records "
        f"for user {user.username}"
    )

    return Response({
        'user': user.username,
        'user_id': user.id,
        'total_records': records.count(),
        'records': serializer.data,
    })


def get_client_ip(request):
    """Extract client IP address from request."""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip
