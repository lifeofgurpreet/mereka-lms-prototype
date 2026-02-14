"""Django admin for Content Libraries v2 extensions."""
from django.contrib import admin
from .models import (
    LibraryMetadata, LibraryVersion, LibraryComponent,
    LibraryCourseReference, BlockstoreReference,
)


@admin.register(LibraryMetadata)
class LibraryMetadataAdmin(admin.ModelAdmin):
    list_display = ['title', 'library_key', 'org', 'is_deleted',
                    'published_component_count', 'last_published_at']
    list_filter = ['is_deleted', 'org']
    search_fields = ['library_key', 'title', 'org']
    readonly_fields = ['id', 'created_at', 'updated_at']


@admin.register(LibraryVersion)
class LibraryVersionAdmin(admin.ModelAdmin):
    list_display = ['library', 'version_number', 'publish_status',
                    'component_count', 'published_at', 'publish_duration_ms']
    list_filter = ['publish_status']
    search_fields = ['library__library_key']
    readonly_fields = ['id', 'published_at']


@admin.register(LibraryComponent)
class LibraryComponentAdmin(admin.ModelAdmin):
    list_display = ['display_name', 'library', 'block_type',
                    'has_unpublished_changes', 'is_deleted']
    list_filter = ['block_type', 'has_unpublished_changes', 'is_deleted']
    search_fields = ['usage_key', 'display_name']
    readonly_fields = ['id', 'created_at']


@admin.register(LibraryCourseReference)
class LibraryCourseReferenceAdmin(admin.ModelAdmin):
    list_display = ['library', 'course_key', 'reference_type',
                    'has_update_available', 'synced_version']
    list_filter = ['reference_type', 'has_update_available']
    search_fields = ['course_key', 'library__library_key']
    readonly_fields = ['id', 'created_at', 'updated_at']


@admin.register(BlockstoreReference)
class BlockstoreReferenceAdmin(admin.ModelAdmin):
    list_display = ['library', 'bundle_uuid', 'ref_type',
                    'is_orphaned', 'last_verified_at']
    list_filter = ['ref_type', 'is_orphaned']
    search_fields = ['bundle_uuid']
    readonly_fields = ['id', 'created_at']
