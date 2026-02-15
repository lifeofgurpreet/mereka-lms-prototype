"""
Models for Content Libraries v2 extensions.

@spec: content-libraries-v2
@covers: AC-LIB-007 through AC-LIB-013
"""
import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone


class LibraryMetadata(models.Model):
    """
    Extended metadata for a Content Library v2.

    Links to the upstream ContentLibrary model via library_key.
    Tracks soft-delete state, org ownership, and publish status.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    library_key = models.CharField(
        max_length=255,
        unique=True,
        db_index=True,
        help_text="Library key (e.g., lib:Mereka:platform-templates)"
    )

    org = models.CharField(
        max_length=255,
        db_index=True,
        help_text="Organization that owns this library"
    )

    # Tenant isolation (AC-LIB-014)
    tenant_uuid = models.UUIDField(
        null=True, blank=True,
        db_index=True,
        help_text="Enterprise customer UUID for tenant isolation"
    )

    title = models.CharField(max_length=500, help_text="Library display title")
    description = models.TextField(blank=True, default='')

    # Public library support (AC-LIB-015)
    allow_public_read = models.BooleanField(
        default=False,
        db_index=True,
        help_text="Allow all tenants to read this library (platform-global)"
    )
    allow_public_read_locked_at = models.DateTimeField(
        null=True, blank=True,
        help_text="Timestamp when public read was enabled (prevents reversal if forked)"
    )

    # Soft-delete support (AC-LIB-009)
    is_deleted = models.BooleanField(default=False, db_index=True)
    deleted_at = models.DateTimeField(null=True, blank=True)
    deleted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='deleted_libraries',
    )

    # Publish tracking
    last_published_at = models.DateTimeField(null=True, blank=True)
    last_published_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='published_libraries',
    )
    draft_component_count = models.IntegerField(default=0)
    published_component_count = models.IntegerField(default=0)

    # Retention policy (AC-NEG-LIB-005)
    retention_days = models.IntegerField(
        default=30,
        help_text="Days to retain soft-deleted library before permanent deletion"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='created_libraries',
    )

    class Meta:
        db_table = 'openedx_content_libraries_metadata'
        verbose_name = 'Library Metadata'
        verbose_name_plural = 'Library Metadata'
        ordering = ['-updated_at']

    def __str__(self):
        return f"{self.title} ({self.library_key})"

    def soft_delete(self, user=None):
        """Soft-delete this library (AC-LIB-009)."""
        self.is_deleted = True
        self.deleted_at = timezone.now()
        self.deleted_by = user
        self.save(update_fields=['is_deleted', 'deleted_at', 'deleted_by', 'updated_at'])

    def restore(self):
        """Restore a soft-deleted library (AC-LIB-009)."""
        self.is_deleted = False
        self.deleted_at = None
        self.deleted_by = None
        self.save(update_fields=['is_deleted', 'deleted_at', 'deleted_by', 'updated_at'])

    @property
    def can_permanent_delete(self):
        """Check if retention period has passed (AC-NEG-LIB-005)."""
        if not self.is_deleted or not self.deleted_at:
            return False
        from datetime import timedelta
        return timezone.now() >= self.deleted_at + timedelta(days=self.retention_days)


class LibraryVersion(models.Model):
    """
    Tracks published versions of a library for rollback (AC-LIB-012).

    Each publish creates a new version snapshot. Rollback restores
    the exact prior state by replaying from a version snapshot.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    library = models.ForeignKey(
        LibraryMetadata,
        on_delete=models.CASCADE,
        related_name='versions',
    )

    version_number = models.PositiveIntegerField(
        help_text="Sequential version number (1, 2, 3...)"
    )

    # Blockstore bundle version reference
    bundle_version = models.CharField(
        max_length=255,
        help_text="Blockstore bundle version hash/ID"
    )

    component_count = models.IntegerField(default=0)

    # Snapshot of component keys at this version
    component_keys = models.JSONField(
        default=list,
        help_text="List of component usage keys at this version"
    )

    # Publish metadata
    published_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True, blank=True,
        on_delete=models.SET_NULL,
    )
    published_at = models.DateTimeField(auto_now_add=True)

    commit_message = models.TextField(
        blank=True, default='',
        help_text="Optional description of changes in this version"
    )

    # Atomic publish tracking (AC-LIB-007)
    publish_status = models.CharField(
        max_length=20,
        choices=[
            ('pending', 'Pending'),
            ('in_progress', 'In Progress'),
            ('completed', 'Completed'),
            ('failed', 'Failed'),
            ('rolled_back', 'Rolled Back'),
        ],
        default='pending',
    )
    publish_duration_ms = models.IntegerField(
        null=True, blank=True,
        help_text="Time taken to publish in milliseconds"
    )

    class Meta:
        db_table = 'openedx_content_libraries_version'
        verbose_name = 'Library Version'
        verbose_name_plural = 'Library Versions'
        unique_together = [('library', 'version_number')]
        ordering = ['-version_number']

    def __str__(self):
        return f"{self.library.library_key} v{self.version_number}"


class LibraryComponent(models.Model):
    """
    Tracks individual components within a library.

    Components are XBlocks (HTML, Problem, Video, etc.) stored
    in Blockstore and authored via Studio.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    library = models.ForeignKey(
        LibraryMetadata,
        on_delete=models.CASCADE,
        related_name='components',
    )

    usage_key = models.CharField(
        max_length=500,
        unique=True,
        db_index=True,
        help_text="XBlock usage key within the library"
    )

    block_type = models.CharField(
        max_length=100,
        db_index=True,
        help_text="XBlock type (html, problem, video, etc.)"
    )

    display_name = models.CharField(max_length=500, blank=True, default='')

    # Draft/published state
    has_unpublished_changes = models.BooleanField(
        default=True,
        help_text="Whether this component has draft changes not yet published"
    )

    last_draft_at = models.DateTimeField(auto_now=True)
    last_published_at = models.DateTimeField(null=True, blank=True)

    # Soft-delete
    is_deleted = models.BooleanField(default=False, db_index=True)

    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True, blank=True,
        on_delete=models.SET_NULL,
    )

    class Meta:
        db_table = 'openedx_content_libraries_component'
        verbose_name = 'Library Component'
        verbose_name_plural = 'Library Components'
        ordering = ['block_type', 'display_name']

    def __str__(self):
        return f"{self.display_name or self.usage_key} ({self.block_type})"


class LibraryCourseReference(models.Model):
    """
    Tracks where library components are used across courses (AC-LIB-013).

    This enables:
    - "Update available" notifications (AC-LIB-010)
    - Orphan detection for Blockstore cleanup (AC-LIB-013)
    - Impact analysis before library changes
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    library = models.ForeignKey(
        LibraryMetadata,
        on_delete=models.CASCADE,
        related_name='course_references',
    )

    component = models.ForeignKey(
        LibraryComponent,
        null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='course_references',
    )

    course_key = models.CharField(
        max_length=500,
        db_index=True,
        help_text="Course key where the library/component is used"
    )

    # Reference type
    reference_type = models.CharField(
        max_length=30,
        choices=[
            ('library_content', 'library_content XBlock (random pool)'),
            ('library_v2_ref', 'library_v2_ref XBlock (direct reference)'),
        ],
        default='library_content',
    )

    # XBlock usage key in the course
    usage_key_in_course = models.CharField(
        max_length=500,
        help_text="Usage key of the referencing XBlock in the course"
    )

    # Version tracking for update notifications (AC-LIB-010)
    synced_version = models.PositiveIntegerField(
        null=True, blank=True,
        help_text="Library version this reference was last synced to"
    )

    has_update_available = models.BooleanField(
        default=False,
        db_index=True,
        help_text="True when source library has newer version than synced"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'openedx_content_libraries_course_reference'
        verbose_name = 'Library Course Reference'
        verbose_name_plural = 'Library Course References'
        unique_together = [('course_key', 'usage_key_in_course')]

    def __str__(self):
        return f"{self.library.library_key} -> {self.course_key}"


class BlockstoreReference(models.Model):
    """
    Tracks Blockstore bundle/draft references for cleanup (AC-LIB-013).

    Ensures no orphaned Blockstore data exists after library deletion.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    library = models.ForeignKey(
        LibraryMetadata,
        on_delete=models.CASCADE,
        related_name='blockstore_refs',
    )

    bundle_uuid = models.UUIDField(
        db_index=True,
        help_text="Blockstore bundle UUID"
    )

    draft_uuid = models.UUIDField(
        null=True, blank=True,
        help_text="Blockstore draft UUID (if unpublished changes exist)"
    )

    ref_type = models.CharField(
        max_length=30,
        choices=[
            ('bundle', 'Published bundle'),
            ('draft', 'Draft'),
            ('snapshot', 'Version snapshot'),
        ],
        default='bundle',
    )

    is_orphaned = models.BooleanField(
        default=False,
        db_index=True,
        help_text="True if this reference has no associated library"
    )

    last_verified_at = models.DateTimeField(
        null=True, blank=True,
        help_text="When this reference was last verified as valid"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'openedx_content_libraries_blockstore_ref'
        verbose_name = 'Blockstore Reference'
        verbose_name_plural = 'Blockstore References'

    def __str__(self):
        return f"{self.ref_type}: {self.bundle_uuid}"


class LibraryRole(models.Model):
    """
    RBAC for content libraries (AC-LIB-016, AC-LIB-017).

    Roles:
    - library_admin: Full control (publish, manage roles, delete)
    - library_author: Edit content, cannot publish or manage access
    - library_reader: Read-only access, cannot modify or publish

    AC-LIB-017: Removing the last admin is rejected.
    AC-NEG-LIB-009: Role escalation prevention.
    """
    ROLE_ADMIN = 'library_admin'
    ROLE_AUTHOR = 'library_author'
    ROLE_READER = 'library_reader'

    ROLE_CHOICES = [
        (ROLE_ADMIN, 'Library Admin'),
        (ROLE_AUTHOR, 'Library Author'),
        (ROLE_READER, 'Library Reader'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    library = models.ForeignKey(
        LibraryMetadata,
        on_delete=models.CASCADE,
        related_name='roles',
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='library_roles',
    )

    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default=ROLE_READER,
    )

    granted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='granted_library_roles',
    )

    granted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'openedx_content_libraries_role'
        verbose_name = 'Library Role'
        verbose_name_plural = 'Library Roles'
        unique_together = [('library', 'user')]
        ordering = ['library', 'role', 'user']

    def __str__(self):
        return f"{self.user.username} - {self.role} - {self.library.library_key}"


class LibraryAccessLog(models.Model):
    """
    Security audit log for library access attempts (AC-LIB-018).

    Tracks:
    - Cross-tenant access attempts (AC-NEG-LIB-007)
    - Role escalation attempts (AC-NEG-LIB-009)
    - Access grants/denials
    """
    ACTION_CROSS_TENANT_ATTEMPT = 'cross_tenant_attempt'
    ACTION_ROLE_ESCALATION_ATTEMPT = 'role_escalation_attempt'
    ACTION_ACCESS_GRANTED = 'access_granted'
    ACTION_ACCESS_DENIED = 'access_denied'

    ACTION_CHOICES = [
        (ACTION_CROSS_TENANT_ATTEMPT, 'Cross-tenant access attempt'),
        (ACTION_ROLE_ESCALATION_ATTEMPT, 'Role escalation attempt'),
        (ACTION_ACCESS_GRANTED, 'Access granted'),
        (ACTION_ACCESS_DENIED, 'Access denied'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    library = models.ForeignKey(
        LibraryMetadata,
        null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='access_logs',
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
    )

    action = models.CharField(
        max_length=30,
        choices=ACTION_CHOICES,
        db_index=True,
    )

    source_tenant_uuid = models.UUIDField(
        null=True, blank=True,
        help_text="Tenant UUID of the requesting user"
    )

    target_tenant_uuid = models.UUIDField(
        null=True, blank=True,
        help_text="Tenant UUID of the target library"
    )

    request_path = models.CharField(
        max_length=500,
        blank=True, default='',
        help_text="API endpoint path"
    )

    ip_address = models.GenericIPAddressField(
        null=True, blank=True,
        help_text="IP address of the requester"
    )

    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = 'openedx_content_libraries_access_log'
        verbose_name = 'Library Access Log'
        verbose_name_plural = 'Library Access Logs'
        ordering = ['-timestamp']

    def __str__(self):
        return f"{self.action} - {self.user.username} - {self.timestamp}"


class TenantLibraryQuota(models.Model):
    """
    Per-tenant library quota configuration (AC-LIB-026).

    Allows platform admins to set per-tenant limits for libraries
    and components. Defaults are used if no record exists.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    tenant_uuid = models.UUIDField(
        unique=True,
        db_index=True,
        help_text="Enterprise customer UUID"
    )

    max_libraries = models.IntegerField(
        default=100,
        help_text="Maximum number of libraries this tenant can create"
    )

    max_components = models.IntegerField(
        default=10000,
        help_text="Maximum total components across all libraries"
    )

    rate_limit_per_minute = models.IntegerField(
        default=60,
        help_text="Maximum API calls per minute for library operations"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'openedx_content_libraries_tenant_quota'
        verbose_name = 'Tenant Library Quota'
        verbose_name_plural = 'Tenant Library Quotas'

    def __str__(self):
        return f"Quota: {self.tenant_uuid} (libs={self.max_libraries}, comps={self.max_components})"
