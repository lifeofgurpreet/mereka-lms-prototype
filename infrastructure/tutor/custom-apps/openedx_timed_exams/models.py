"""Django models for Timed Exams"""
from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.core.validators import MinValueValidator, MaxValueValidator
from opaque_keys.edx.django.models import CourseKeyField, UsageKeyField
import hashlib
import logging

User = get_user_model()
logger = logging.getLogger(__name__)


class ExamTimeExtension(models.Model):
    """Time extensions for students with accommodations"""

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='exam_time_extensions')
    course_id = CourseKeyField(max_length=255, db_index=True)
    usage_key = UsageKeyField(max_length=255, blank=True, null=True)  # Specific exam (optional)

    # Extension configuration
    multiplier = models.DecimalField(
        max_digits=3,
        decimal_places=2,
        default=1.5,
        validators=[MinValueValidator(1.0), MaxValueValidator(5.0)],
        help_text="Time multiplier (e.g., 1.5 for 50% extra time, 2.0 for double time)"
    )
    additional_minutes = models.IntegerField(
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(9999)],
        help_text="Additional minutes to add (after applying multiplier)"
    )

    # Accommodation details
    reason = models.CharField(
        max_length=255,
        blank=True,
        help_text="Reason for accommodation (e.g., 'Documented disability', 'Medical condition')"
    )
    documentation = models.TextField(
        blank=True,
        help_text="Link to documentation or approval reference"
    )

    # Approval workflow
    approved_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='approved_time_extensions'
    )
    approved_at = models.DateTimeField(null=True, blank=True)

    # Validity period
    valid_from = models.DateTimeField(default=timezone.now)
    valid_until = models.DateTimeField(null=True, blank=True, help_text="Leave blank for no expiry")

    # Status
    is_active = models.BooleanField(default=True, db_index=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'timed_exams_time_extension'
        verbose_name = 'Exam Time Extension'
        verbose_name_plural = 'Exam Time Extensions'
        unique_together = [['user', 'course_id', 'usage_key']]
        indexes = [
            models.Index(fields=['user', 'course_id', 'is_active']),
            models.Index(fields=['valid_from', 'valid_until']),
        ]

    def __str__(self):
        multiplier_str = f"{self.multiplier}x"
        if self.additional_minutes > 0:
            multiplier_str += f" +{self.additional_minutes}min"
        return f"{self.user.username} - {self.course_id} ({multiplier_str})"

    def is_valid_now(self):
        """Check if extension is currently valid"""
        if not self.is_active:
            return False

        now = timezone.now()
        if self.valid_from > now:
            return False

        if self.valid_until and self.valid_until < now:
            return False

        return True

    def calculate_extended_time(self, base_minutes):
        """Calculate extended time in minutes given base duration"""
        extended = int(base_minutes * float(self.multiplier))
        extended += self.additional_minutes
        return extended

    @classmethod
    def get_active_extension(cls, user, course_id, usage_key=None):
        """Get active time extension for user in course/exam"""
        now = timezone.now()

        # Try specific exam first
        if usage_key:
            extension = cls.objects.filter(
                user=user,
                course_id=course_id,
                usage_key=usage_key,
                is_active=True,
                valid_from__lte=now
            ).filter(
                models.Q(valid_until__isnull=True) | models.Q(valid_until__gte=now)
            ).first()

            if extension:
                return extension

        # Fall back to course-wide extension
        extension = cls.objects.filter(
            user=user,
            course_id=course_id,
            usage_key__isnull=True,
            is_active=True,
            valid_from__lte=now
        ).filter(
            models.Q(valid_until__isnull=True) | models.Q(valid_until__gte=now)
        ).first()

        return extension


class ExamSession(models.Model):
    """Track active exam sessions for timer enforcement and multi-device detection"""

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='exam_sessions')
    course_id = CourseKeyField(max_length=255, db_index=True)
    usage_key = UsageKeyField(max_length=255)

    # Session details
    session_key = models.CharField(max_length=128, unique=True, db_index=True)
    device_fingerprint = models.CharField(
        max_length=64,
        db_index=True,
        help_text="SHA-256 hash of user agent + client hints"
    )
    ip_address_hash = models.CharField(
        max_length=64,
        help_text="SHA-256 hash of IP address (privacy-preserving)"
    )

    # Timing
    started_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(db_index=True)
    last_activity_at = models.DateTimeField(auto_now=True)

    # Base and extended time
    base_duration_minutes = models.IntegerField()
    extended_duration_minutes = models.IntegerField(help_text="Duration with accommodations applied")
    time_extension = models.ForeignKey(
        ExamTimeExtension,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='exam_sessions'
    )

    # Status
    status = models.CharField(
        max_length=20,
        choices=[
            ('active', 'Active'),
            ('submitted', 'Submitted'),
            ('expired', 'Expired (Auto-submitted)'),
            ('terminated', 'Terminated (Multi-device)'),
        ],
        default='active',
        db_index=True
    )

    # Auto-submission
    auto_submitted = models.BooleanField(default=False)
    auto_submitted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'timed_exams_session'
        verbose_name = 'Exam Session'
        verbose_name_plural = 'Exam Sessions'
        indexes = [
            models.Index(fields=['user', 'course_id', 'status']),
            models.Index(fields=['expires_at', 'status']),
            models.Index(fields=['device_fingerprint', 'user']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.usage_key} ({self.status})"

    @property
    def remaining_time_seconds(self):
        """Calculate remaining time in seconds"""
        if self.status != 'active':
            return 0

        now = timezone.now()
        if now >= self.expires_at:
            return 0

        return int((self.expires_at - now).total_seconds())

    @property
    def is_expired(self):
        """Check if session has expired"""
        return timezone.now() >= self.expires_at

    @staticmethod
    def hash_value(value):
        """SHA-256 hash for privacy-preserving storage"""
        return hashlib.sha256(value.encode('utf-8')).hexdigest()

    @classmethod
    def create_session(cls, user, course_id, usage_key, duration_minutes, request):
        """Create new exam session with device fingerprint"""
        from datetime import timedelta
        import uuid

        # Check for time extension
        extension = ExamTimeExtension.get_active_extension(user, course_id, usage_key)
        extended_duration = duration_minutes

        if extension:
            extended_duration = extension.calculate_extended_time(duration_minutes)
            logger.info(
                f'Time extension applied: {user.username} - {usage_key} - '
                f'{duration_minutes}min → {extended_duration}min ({extension.multiplier}x)'
            )

        # Generate device fingerprint
        user_agent = request.META.get('HTTP_USER_AGENT', '')
        client_hints = request.META.get('HTTP_SEC_CH_UA', '')
        device_fingerprint = cls.hash_value(f"{user_agent}|{client_hints}")

        # Hash IP address
        ip_address = request.META.get('REMOTE_ADDR', '')
        ip_address_hash = cls.hash_value(ip_address)

        # Create session
        session_key = uuid.uuid4().hex
        expires_at = timezone.now() + timedelta(minutes=extended_duration)

        session = cls.objects.create(
            user=user,
            course_id=course_id,
            usage_key=usage_key,
            session_key=session_key,
            device_fingerprint=device_fingerprint,
            ip_address_hash=ip_address_hash,
            base_duration_minutes=duration_minutes,
            extended_duration_minutes=extended_duration,
            time_extension=extension,
            expires_at=expires_at,
            status='active'
        )

        logger.info(f'Exam session created: {session_key} - {user.username} - {usage_key}')
        return session

    @classmethod
    def get_active_session(cls, user, usage_key):
        """Get active session for user/exam"""
        return cls.objects.filter(
            user=user,
            usage_key=usage_key,
            status='active'
        ).first()

    @classmethod
    def detect_multi_device(cls, user, usage_key, device_fingerprint):
        """Detect if user has active session on different device"""
        active_sessions = cls.objects.filter(
            user=user,
            usage_key=usage_key,
            status='active'
        )

        # Check for different device fingerprint
        for session in active_sessions:
            if session.device_fingerprint != device_fingerprint:
                return session

        return None

    def submit(self):
        """Mark session as submitted"""
        if self.status == 'active':
            self.status = 'submitted'
            self.save(update_fields=['status', 'last_activity_at'])
            logger.info(f'Exam session submitted: {self.session_key}')

    def auto_submit(self):
        """Auto-submit session when time expires"""
        if self.status == 'active':
            self.status = 'expired'
            self.auto_submitted = True
            self.auto_submitted_at = timezone.now()
            self.save(update_fields=['status', 'auto_submitted', 'auto_submitted_at', 'last_activity_at'])
            logger.info(f'Exam session auto-submitted: {self.session_key}')

    def terminate(self, reason='multi_device'):
        """Terminate session (e.g., multi-device detection)"""
        if self.status == 'active':
            self.status = 'terminated'
            self.save(update_fields=['status', 'last_activity_at'])
            logger.warning(f'Exam session terminated ({reason}): {self.session_key}')


class ExamGradeRelease(models.Model):
    """Control when exam grades are released to students"""

    course_id = CourseKeyField(max_length=255, db_index=True)
    usage_key = UsageKeyField(max_length=255, unique=True)

    # Release configuration
    release_mode = models.CharField(
        max_length=20,
        choices=[
            ('immediate', 'Immediate (after submission)'),
            ('window_close', 'When exam window closes'),
            ('manual', 'Manual release by instructor'),
            ('scheduled', 'Scheduled date/time'),
        ],
        default='window_close'
    )

    # Window close time (for window_close mode)
    window_close_at = models.DateTimeField(null=True, blank=True)

    # Scheduled release (for scheduled mode)
    release_at = models.DateTimeField(null=True, blank=True)

    # Manual release
    released_manually = models.BooleanField(default=False)
    released_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='released_exam_grades'
    )
    released_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'timed_exams_grade_release'
        verbose_name = 'Exam Grade Release'
        verbose_name_plural = 'Exam Grade Releases'
        indexes = [
            models.Index(fields=['course_id']),
            models.Index(fields=['release_mode', 'window_close_at']),
        ]

    def __str__(self):
        return f"{self.usage_key} - {self.get_release_mode_display()}"

    def should_release_now(self):
        """Check if grades should be released now"""
        if self.release_mode == 'immediate':
            return True

        if self.release_mode == 'manual':
            return self.released_manually

        if self.release_mode == 'window_close':
            if self.window_close_at and timezone.now() >= self.window_close_at:
                return True

        if self.release_mode == 'scheduled':
            if self.release_at and timezone.now() >= self.release_at:
                return True

        return False

    def manual_release(self, user):
        """Manually release grades"""
        self.released_manually = True
        self.released_by = user
        self.released_at = timezone.now()
        self.save(update_fields=['released_manually', 'released_by', 'released_at'])
        logger.info(f'Exam grades manually released: {self.usage_key} by {user.username}')
