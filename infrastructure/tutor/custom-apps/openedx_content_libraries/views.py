"""
API views for Content Libraries v2 extensions.

@spec: content-libraries-v2
"""
import logging

from rest_framework import status
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView

from .api import (
    create_library, publish_library, rollback_library,
    soft_delete_library, restore_library,
    check_orphaned_references, create_platform_templates_library,
)
from .models import LibraryMetadata, LibraryVersion, LibraryCourseReference
from .serializers import (
    LibraryMetadataSerializer, LibraryVersionSerializer,
    LibraryCourseReferenceSerializer,
)

logger = logging.getLogger(__name__)


class LibraryListView(APIView):
    """List libraries with metadata."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        libraries = LibraryMetadata.objects.filter(is_deleted=False)
        org = request.query_params.get('org')
        if org:
            libraries = libraries.filter(org=org)
        serializer = LibraryMetadataSerializer(libraries, many=True)
        return Response(serializer.data)


class LibraryPublishView(APIView):
    """Publish all draft changes in a library (AC-LIB-007)."""
    permission_classes = [IsAuthenticated, IsAdminUser]

    def post(self, request, library_key):
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
