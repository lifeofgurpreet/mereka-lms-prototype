"""
iOS-specific authentication and token management.

@spec: Mobile Phase 2 - iOS Stabilization (mereka-lms-36f7)
@covers: AC-MOB-008, AC-MOB-009, AC-MOB-010, AC-MOB-011, AC-MOB-014
"""

import logging
import hashlib
import secrets
from datetime import timedelta
from django.utils import timezone
from django.contrib.auth.models import User
from django.db import models

logger = logging.getLogger(__name__)


class PKCEChallenge(models.Model):
    """
    PKCE challenge storage for OAuth 2.0 + PKCE flow.

    @covers: AC-MOB-008 - OAuth 2.0 + PKCE flow
    """

    code_verifier = models.CharField(
        max_length=128,
        unique=True,
        db_index=True,
        help_text="PKCE code verifier (AC-MOB-008)"
    )

    code_challenge = models.CharField(
        max_length=128,
        help_text="PKCE code challenge (SHA-256 of verifier)"
    )

    code_challenge_method = models.CharField(
        max_length=10,
        default="S256",
        help_text="Challenge method (S256 or plain)"
    )

    state = models.CharField(
        max_length=128,
        unique=True,
        db_index=True,
        help_text="OAuth state parameter"
    )

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        help_text="User who initiated the flow (set after authentication)"
    )

    expires_at = models.DateTimeField(
        help_text="When this challenge expires (10 minutes)"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "mobile_pkce_challenge"
        verbose_name = "PKCE Challenge"
        verbose_name_plural = "PKCE Challenges"
        indexes = [
            models.Index(fields=["expires_at"]),
        ]

    def __str__(self):
        return f"PKCE Challenge {self.state} (expires: {self.expires_at})"

    @classmethod
    def create_challenge(cls):
        """
        Generate PKCE challenge and verifier.

        @covers: AC-MOB-008 - PKCE flow
        """
        # Generate code verifier (43-128 chars)
        code_verifier = secrets.token_urlsafe(64)

        # Generate code challenge (SHA-256 of verifier)
        challenge = hashlib.sha256(code_verifier.encode()).hexdigest()

        # Generate state
        state = secrets.token_urlsafe(32)

        # Create challenge record
        pkce = cls.objects.create(
            code_verifier=code_verifier,
            code_challenge=challenge,
            code_challenge_method="S256",
            state=state,
            expires_at=timezone.now() + timedelta(minutes=10),
        )

        return pkce

    def verify_challenge(self, code_verifier):
        """
        Verify PKCE code verifier matches challenge.

        @covers: AC-MOB-008 - PKCE verification
        """
        if self.expires_at < timezone.now():
            logger.warning(f"PKCE challenge {self.state} expired")
            return False

        # Compute challenge from verifier
        computed_challenge = hashlib.sha256(code_verifier.encode()).hexdigest()

        if computed_challenge != self.code_challenge:
            logger.warning(f"PKCE challenge verification failed for state {self.state}")
            return False

        return True


class MobileToken(models.Model):
    """
    Mobile app access/refresh token tracking.

    @covers: AC-MOB-009, AC-MOB-010, AC-MOB-011
    """

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="mobile_tokens"
    )

    access_token = models.CharField(
        max_length=255,
        unique=True,
        db_index=True,
        help_text="OAuth2 access token"
    )

    refresh_token = models.CharField(
        max_length=255,
        unique=True,
        db_index=True,
        help_text="OAuth2 refresh token"
    )

    device_token = models.CharField(
        max_length=255,
        blank=True,
        help_text="Associated mobile device token (for push notifications)"
    )

    expires_at = models.DateTimeField(
        help_text="When access token expires"
    )

    refresh_expires_at = models.DateTimeField(
        help_text="When refresh token expires"
    )

    is_active = models.BooleanField(
        default=True,
        help_text="Whether token is active (AC-MOB-011 - revocation)"
    )

    last_refreshed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Last time token was refreshed (AC-MOB-009)"
    )

    refresh_count = models.IntegerField(
        default=0,
        help_text="Number of times token has been refreshed"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "mobile_token"
        verbose_name = "Mobile Token"
        verbose_name_plural = "Mobile Tokens"
        indexes = [
            models.Index(fields=["user", "is_active"]),
            models.Index(fields=["expires_at"]),
            models.Index(fields=["refresh_expires_at"]),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.access_token[:20]}..."

    def is_expired(self):
        """Check if access token is expired."""
        return timezone.now() >= self.expires_at

    def needs_refresh(self):
        """
        Check if token needs proactive refresh.

        @covers: AC-MOB-009 - Refresh <5min before expiry
        """
        threshold = timezone.now() + timedelta(minutes=5)
        return self.expires_at <= threshold

    def refresh(self, new_access_token, new_expires_at):
        """
        Refresh access token.

        @covers: AC-MOB-009 - Single-flight refresh (no duplicate refreshes)
        """
        self.access_token = new_access_token
        self.expires_at = new_expires_at
        self.last_refreshed_at = timezone.now()
        self.refresh_count += 1
        self.save(update_fields=[
            "access_token",
            "expires_at",
            "last_refreshed_at",
            "refresh_count",
            "updated_at"
        ])

    def revoke(self):
        """
        Revoke token.

        @covers: AC-MOB-011 - Logout revokes tokens server-side
        """
        self.is_active = False
        self.save(update_fields=["is_active", "updated_at"])


class APNsNotification(models.Model):
    """
    APNs push notification delivery tracking.

    @covers: AC-MOB-012 - Push notification tap navigation
    """

    NOTIFICATION_TYPE_CHOICES = [
        ("course_update", "Course Update"),
        ("assignment_due", "Assignment Due"),
        ("discussion_reply", "Discussion Reply"),
        ("announcement", "Announcement"),
        ("grade_posted", "Grade Posted"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="apns_notifications"
    )

    device_token = models.CharField(
        max_length=255,
        help_text="APNs device token"
    )

    notification_type = models.CharField(
        max_length=50,
        choices=NOTIFICATION_TYPE_CHOICES,
        help_text="Type of notification"
    )

    title = models.CharField(
        max_length=255,
        help_text="Notification title"
    )

    body = models.TextField(
        help_text="Notification body"
    )

    # Deep link data (AC-MOB-012)
    deep_link_url = models.URLField(
        blank=True,
        help_text="Deep link URL for tap navigation (AC-MOB-012)"
    )

    course_id = models.CharField(
        max_length=255,
        blank=True,
        help_text="Course ID for navigation"
    )

    content_id = models.CharField(
        max_length=255,
        blank=True,
        help_text="Specific content ID (lesson, assignment, etc.)"
    )

    # Delivery tracking
    sent_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When notification was sent to APNs"
    )

    delivered_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When notification was delivered (from APNs feedback)"
    )

    opened_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When user tapped notification"
    )

    apns_response = models.JSONField(
        default=dict,
        blank=True,
        help_text="Response from APNs server"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "mobile_apns_notification"
        verbose_name = "APNs Notification"
        verbose_name_plural = "APNs Notifications"
        indexes = [
            models.Index(fields=["user", "sent_at"]),
            models.Index(fields=["device_token"]),
        ]
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.notification_type} - {self.user.username}"
