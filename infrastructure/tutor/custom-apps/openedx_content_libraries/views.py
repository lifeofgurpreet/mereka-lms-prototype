"""
API views for Content Libraries v2 extensions.

@spec: content-libraries-v2
"""
import logging

from django.conf import settings
from rest_framework import status
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView

from .api import (
    create_library, publish_library, rollback_library,
    soft_delete_library, restore_library,
    check_orphaned_references, create_platform_templates_library,
    get_tenant_libraries, grant_library_role, revoke_library_role,
    check_library_permission, enable_public_read, disable_public_read,
    log_library_access,
)
from .models import (
    LibraryMetadata, LibraryVersion, LibraryCourseReference,
    LibraryRole, LibraryAccessLog,
)
from .serializers import (
    LibraryMetadataSerializer, LibraryVersionSerializer,
    LibraryCourseReferenceSerializer, LibraryRoleSerializer,
    LibraryAccessLogSerializer,
)

logger = logging.getLogger(__name__)


class LibraryListView(APIView):
    """
    List libraries with metadata (AC-LIB-014, AC-LIB-015).

    Filters by tenant org unless user is superuser.
    Includes public libraries if LIBRARY_PUBLIC_READ_ENABLED=True.

    AC-NEG-LIB-007: Cross-tenant libraries are NOT returned.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Check if tenant isolation is enabled
        tenant_isolation_enabled = getattr(
            settings, 'LIBRARY_TENANT_ISOLATION_ENABLED', False
        )
        public_read_enabled = getattr(
            settings, 'LIBRARY_PUBLIC_READ_ENABLED', False
        )

        if tenant_isolation_enabled and not request.user.is_superuser:
            # Get user's tenant UUID
            try:
                from openedx_tenant_cache.isolation import get_user_tenant_uuid
                tenant_uuid = get_user_tenant_uuid(request.user)

                if tenant_uuid:
                    # Use tenant-scoped filtering
                    libraries = get_tenant_libraries(
                        tenant_uuid,
                        include_public=public_read_enabled,
                    )
                else:
                    # No tenant context, only show public libraries
                    if public_read_enabled:
                        libraries = LibraryMetadata.objects.filter(
                            is_deleted=False,
                            allow_public_read=True,
                        )
                    else:
                        libraries = LibraryMetadata.objects.none()
                        logger.warning(
                            "User %s has no tenant context, no libraries returned",
                            request.user.id,
                        )
            except ImportError:
                logger.warning(
                    "openedx_tenant_cache not available, falling back to all libraries"
                )
                libraries = LibraryMetadata.objects.filter(is_deleted=False)
        else:
            # No tenant isolation or superuser
            libraries = LibraryMetadata.objects.filter(is_deleted=False)
            org = request.query_params.get('org')
            if org:
                libraries = libraries.filter(org=org)

        serializer = LibraryMetadataSerializer(libraries, many=True)
        return Response(serializer.data)


class LibraryPublishView(APIView):
    """
    Publish all draft changes in a library (AC-LIB-007, AC-LIB-016).

    RBAC enforcement (AC-LIB-016):
    - Requires library_admin or library_author role
    - library_reader receives HTTP 403
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, library_key):
        # RBAC enforcement (AC-LIB-016)
        rbac_enabled = getattr(settings, 'LIBRARY_RBAC_ENABLED', False)

        if rbac_enabled and not request.user.is_superuser:
            # Check for library_admin or library_author role
            has_permission = (
                check_library_permission(
                    library_key, request.user, LibraryRole.ROLE_AUTHOR
                ) or
                check_library_permission(
                    library_key, request.user, LibraryRole.ROLE_ADMIN
                )
            )

            if not has_permission:
                # Log role escalation attempt
                try:
                    metadata = LibraryMetadata.objects.get(
                        library_key=library_key, is_deleted=False
                    )
                    log_library_access(
                        library=metadata,
                        user=request.user,
                        action=LibraryAccessLog.ACTION_ROLE_ESCALATION_ATTEMPT,
                        request=request,
                    )
                except LibraryMetadata.DoesNotExist:
                    pass

                return Response(
                    {'error': 'Insufficient permissions. Requires library_admin or library_author role.'},
                    status=status.HTTP_403_FORBIDDEN,
                )

        commit_message = request.data.get('commit_message', '')
        try:
            version = publish_library(library_key, user=request.user,
                                       commit_message=commit_message)
            return Response(LibraryVersionSerializer(version).data)
        except LibraryMetadata.DoesNotExist:
            return Response({'error': 'Library not found'}, status=404)


class LibraryRollbackView(APIView):
    """Rollback a library to a previous version (AC-LIB-012)."""
    permission_classes = [IsAuthenticated, IsAdminUser]

    def post(self, request, library_key):
        target_version = request.data.get('version_number')
        if not target_version:
            return Response({'error': 'version_number required'}, status=400)
        try:
            version = rollback_library(library_key, int(target_version),
                                        user=request.user)
            return Response(LibraryVersionSerializer(version).data)
        except (LibraryMetadata.DoesNotExist, LibraryVersion.DoesNotExist):
            return Response({'error': 'Library or version not found'}, status=404)


class LibraryVersionListView(APIView):
    """List versions for a library."""
    permission_classes = [IsAuthenticated]

    def get(self, request, library_key):
        try:
            metadata = LibraryMetadata.objects.get(library_key=library_key)
            versions = metadata.versions.all()
            return Response(LibraryVersionSerializer(versions, many=True).data)
        except LibraryMetadata.DoesNotExist:
            return Response({'error': 'Library not found'}, status=404)


class LibrarySoftDeleteView(APIView):
    """Soft-delete or restore a library (AC-LIB-009)."""
    permission_classes = [IsAuthenticated, IsAdminUser]

    def delete(self, request, library_key):
        try:
            soft_delete_library(library_key, user=request.user)
            return Response({'status': 'deleted'})
        except LibraryMetadata.DoesNotExist:
            return Response({'error': 'Library not found'}, status=404)

    def post(self, request, library_key):
        """Restore a soft-deleted library."""
        try:
            restore_library(library_key)
            return Response({'status': 'restored'})
        except LibraryMetadata.DoesNotExist:
            return Response({'error': 'Library not found'}, status=404)


class LibraryUpdateNotificationsView(APIView):
    """List references with updates available (AC-LIB-010)."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        refs = LibraryCourseReference.objects.filter(
            has_update_available=True,
        )
        course_key = request.query_params.get('course_key')
        if course_key:
            refs = refs.filter(course_key=course_key)
        return Response(LibraryCourseReferenceSerializer(refs, many=True).data)


class OrphanCheckView(APIView):
    """Check for orphaned Blockstore references (AC-LIB-013)."""
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request, library_key):
        orphans = check_orphaned_references(library_key)
        return Response({
            'library_key': library_key,
            'orphaned_count': len(orphans),
            'orphans': [
                {'bundle_uuid': str(o.bundle_uuid), 'ref_type': o.ref_type}
                for o in orphans
            ],
        })


# ── Phase 2: Tenant Libraries Views ────────────────────────────────────


class LibraryRoleView(APIView):
    """
    Manage RBAC roles for a library (AC-LIB-016, AC-LIB-017).

    GET: List all roles for a library
    POST: Grant a role to a user (admin only)
    DELETE: Revoke a role from a user (admin only, last-admin prevention)
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, library_key):
        """List all roles for a library."""
        try:
            metadata = LibraryMetadata.objects.get(
                library_key=library_key, is_deleted=False
            )
            roles = LibraryRole.objects.filter(library=metadata)
            return Response(LibraryRoleSerializer(roles, many=True).data)
        except LibraryMetadata.DoesNotExist:
            return Response({'error': 'Library not found'}, status=404)

    def post(self, request, library_key):
        """Grant a role to a user (admin only)."""
        # Check admin permission
        if not request.user.is_superuser:
            has_admin = check_library_permission(
                library_key, request.user, LibraryRole.ROLE_ADMIN
            )
            if not has_admin:
                return Response(
                    {'error': 'Only library admins can grant roles.'},
                    status=status.HTTP_403_FORBIDDEN,
                )

        from django.contrib.auth import get_user_model
        User = get_user_model()

        username = request.data.get('username')
        role = request.data.get('role')

        if not username or not role:
            return Response(
                {'error': 'username and role are required'},
                status=400,
            )

        try:
            user = User.objects.get(username=username)
            role_obj = grant_library_role(
                library_key, user, role, granted_by=request.user
            )
            return Response(LibraryRoleSerializer(role_obj).data)
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=404)
        except LibraryMetadata.DoesNotExist:
            return Response({'error': 'Library not found'}, status=404)

    def delete(self, request, library_key):
        """
        Revoke a role from a user (AC-LIB-017).

        Last-admin prevention: rejects removing the last admin.
        """
        # Check admin permission
        if not request.user.is_superuser:
            has_admin = check_library_permission(
                library_key, request.user, LibraryRole.ROLE_ADMIN
            )
            if not has_admin:
                return Response(
                    {'error': 'Only library admins can revoke roles.'},
                    status=status.HTTP_403_FORBIDDEN,
                )

        from django.contrib.auth import get_user_model
        User = get_user_model()

        username = request.data.get('username')
        if not username:
            return Response(
                {'error': 'username is required'},
                status=400,
            )

        try:
            user = User.objects.get(username=username)
            revoke_library_role(library_key, user, revoked_by=request.user)
            return Response({'status': 'role revoked'})
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=404)
        except LibraryMetadata.DoesNotExist:
            return Response({'error': 'Library not found'}, status=404)
        except LibraryRole.DoesNotExist:
            return Response({'error': 'Role not found'}, status=404)
        except ValueError as e:
            # Last-admin prevention (AC-LIB-017)
            return Response({'error': str(e)}, status=400)


class LibraryPublicReadView(APIView):
    """
    Manage public read access for a library (AC-LIB-015, AC-NEG-LIB-008).

    POST: Enable public read (makes library visible to all tenants)
    DELETE: Disable public read (rejected if library has been forked)
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, library_key):
        """Enable public read access (AC-LIB-015)."""
        # Check admin permission
        if not request.user.is_superuser:
            has_admin = check_library_permission(
                library_key, request.user, LibraryRole.ROLE_ADMIN
            )
            if not has_admin:
                return Response(
                    {'error': 'Only library admins can enable public read.'},
                    status=status.HTTP_403_FORBIDDEN,
                )

        try:
            metadata = enable_public_read(library_key, request.user)
            return Response(LibraryMetadataSerializer(metadata).data)
        except LibraryMetadata.DoesNotExist:
            return Response({'error': 'Library not found'}, status=404)

    def delete(self, request, library_key):
        """
        Disable public read access (AC-NEG-LIB-008).

        Rejected if library has been forked by other tenants.
        """
        # Check admin permission
        if not request.user.is_superuser:
            has_admin = check_library_permission(
                library_key, request.user, LibraryRole.ROLE_ADMIN
            )
            if not has_admin:
                return Response(
                    {'error': 'Only library admins can disable public read.'},
                    status=status.HTTP_403_FORBIDDEN,
                )

        try:
            metadata = disable_public_read(library_key, request.user)
            return Response(LibraryMetadataSerializer(metadata).data)
        except LibraryMetadata.DoesNotExist:
            return Response({'error': 'Library not found'}, status=404)
        except ValueError as e:
            # Fork prevention (AC-NEG-LIB-008)
            return Response({'error': str(e)}, status=400)
