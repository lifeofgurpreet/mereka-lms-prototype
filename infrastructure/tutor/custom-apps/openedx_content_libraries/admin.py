"""Django admin for Content Libraries v2 extensions."""
from django.contrib import admin
from .models import (
    LibraryMetadata, LibraryVersion, LibraryComponent,
    LibraryCourseReference, BlockstoreReference,
    LibraryRole, LibraryAccessLog, TenantLibraryQuota,
)


@admin.register(LibraryMetadata)
class LibraryMetadataAdmin(admin.ModelAdmin):
    list_display = ['title', 'library_key', 'org', 'tenant_uuid',
                    'allow_public_read', 'is_deleted',
                    'published_component_count', 'last_published_at']
    list_filter = ['is_deleted', 'org', 'allow_public_read']
    search_fields = ['library_key', 'title', 'org']
    readonly_fields = ['id', 'created_at', 'updated_at', 'allow_public_read_locked_at']


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


@admin.register(LibraryRole)
class LibraryRoleAdmin(admin.ModelAdmin):
    list_display = ['library', 'user', 'role', 'granted_by', 'granted_at']
    list_filter = ['role']
    search_fields = ['library__library_key', 'user__username']
    readonly_fields = ['id', 'granted_at']


@admin.register(LibraryAccessLog)
class LibraryAccessLogAdmin(admin.ModelAdmin):
    list_display = ['library', 'user', 'action', 'source_tenant_uuid',
                    'target_tenant_uuid', 'ip_address', 'timestamp']
    list_filter = ['action', 'timestamp']
    search_fields = ['library__library_key', 'user__username', 'ip_address']
    readonly_fields = ['id', 'timestamp']
    date_hierarchy = 'timestamp'


@admin.register(TenantLibraryQuota)
class TenantLibraryQuotaAdmin(admin.ModelAdmin):
    list_display = ['tenant_uuid', 'max_libraries', 'max_components',
                    'rate_limit_per_minute', 'updated_at']
    search_fields = ['tenant_uuid']
    readonly_fields = ['id', 'created_at', 'updated_at']
