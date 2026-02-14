"""DRF serializers for Content Libraries v2 extensions."""
from rest_framework import serializers
from .models import (
    LibraryMetadata, LibraryVersion, LibraryComponent,
    LibraryCourseReference, BlockstoreReference,
)


class LibraryMetadataSerializer(serializers.ModelSerializer):
    class Meta:
        model = LibraryMetadata
        fields = [
            'id', 'library_key', 'org', 'title', 'description',
            'is_deleted', 'deleted_at',
            'last_published_at', 'draft_component_count',
            'published_component_count', 'retention_days',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


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
