"""DRF serializers for Content Libraries v2 extensions."""
from rest_framework import serializers
from .models import (
    LibraryMetadata, LibraryVersion, LibraryComponent,
    LibraryCourseReference, BlockstoreReference,
    LibraryRole, LibraryAccessLog,
)


class LibraryMetadataSerializer(serializers.ModelSerializer):
    class Meta:
        model = LibraryMetadata
        fields = [
            'id', 'library_key', 'org', 'title', 'description',
            'tenant_uuid', 'allow_public_read', 'allow_public_read_locked_at',
            'is_deleted', 'deleted_at',
            'last_published_at', 'draft_component_count',
            'published_component_count', 'retention_days',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'allow_public_read_locked_at']


class LibraryVersionSerializer(serializers.ModelSerializer):
    library_key = serializers.CharField(source='library.library_key', read_only=True)

    class Meta:
        model = LibraryVersion
        fields = [
            'id', 'library_key', 'version_number', 'bundle_version',
            'component_count', 'component_keys', 'published_at',
            'commit_message', 'publish_status', 'publish_duration_ms',
        ]
        read_only_fields = ['id', 'published_at']


class LibraryComponentSerializer(serializers.ModelSerializer):
    library_key = serializers.CharField(source='library.library_key', read_only=True)

    class Meta:
        model = LibraryComponent
        fields = [
            'id', 'library_key', 'usage_key', 'block_type',
            'display_name', 'has_unpublished_changes',
            'last_draft_at', 'last_published_at', 'is_deleted',
            'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class LibraryCourseReferenceSerializer(serializers.ModelSerializer):
    library_key = serializers.CharField(source='library.library_key', read_only=True)

    class Meta:
        model = LibraryCourseReference
        fields = [
            'id', 'library_key', 'course_key', 'reference_type',
            'usage_key_in_course', 'synced_version',
            'has_update_available', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class LibraryRoleSerializer(serializers.ModelSerializer):
    """Serializer for LibraryRole (AC-LIB-016)."""
    library_key = serializers.CharField(source='library.library_key', read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    granted_by_username = serializers.CharField(
        source='granted_by.username', read_only=True, allow_null=True
    )

    class Meta:
        model = LibraryRole
        fields = [
            'id', 'library_key', 'username', 'role',
            'granted_by_username', 'granted_at',
        ]
        read_only_fields = ['id', 'granted_at']


class LibraryAccessLogSerializer(serializers.ModelSerializer):
    """Serializer for LibraryAccessLog (AC-LIB-018)."""
    library_key = serializers.CharField(
        source='library.library_key', read_only=True, allow_null=True
    )
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = LibraryAccessLog
        fields = [
            'id', 'library_key', 'username', 'action',
            'source_tenant_uuid', 'target_tenant_uuid',
            'request_path', 'ip_address', 'timestamp',
        ]
        read_only_fields = ['id', 'timestamp']
