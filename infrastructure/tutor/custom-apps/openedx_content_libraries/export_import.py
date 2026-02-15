"""
Cross-tenant library export/import.

@covers: AC-LIB-026 (tenant can create libraries immediately),
         AC-LIB-032 (no cross-tenant access in code paths)
"""
import json
import logging
import uuid

from django.conf import settings
from django.db import transaction
from django.utils import timezone

logger = logging.getLogger(__name__)


def export_library_for_tenant(library_key, exporting_tenant_uuid):
    """
    Export a library for cross-tenant sharing.

    Only exports libraries the tenant owns or public libraries.
    AC-LIB-032: Enforces tenant ownership check.
    """
    from .models import LibraryMetadata, LibraryComponent

    metadata = LibraryMetadata.objects.get(library_key=library_key, is_deleted=False)

    # Security: only own libraries or public
    if not metadata.allow_public_read:
        if str(metadata.tenant_uuid) != str(exporting_tenant_uuid):
            logger.warning(
                "Cross-tenant export blocked: tenant %s tried to export library %s (owned by %s)",
                exporting_tenant_uuid, library_key, metadata.tenant_uuid,
            )
            raise PermissionError("Cannot export another tenant's library")

    components = LibraryComponent.objects.filter(
        library=metadata, is_deleted=False,
    )

    export_data = {
        'format': 'mereka-library-export-v1',
        'exported_at': timezone.now().isoformat(),
        'source_tenant_uuid': str(exporting_tenant_uuid),
        'library': {
            'library_key': metadata.library_key,
            'org': metadata.org,
            'title': metadata.title,
            'description': metadata.description,
        },
        'components': [
            {
                'usage_key': c.usage_key,
                'block_type': c.block_type,
                'display_name': c.display_name,
            }
            for c in components
        ],
        'component_count': components.count(),
    }

    logger.info(
        "Library exported: %s by tenant %s (%d components)",
        library_key, exporting_tenant_uuid, components.count(),
    )

    return export_data


def import_library_for_tenant(export_data, importing_tenant_uuid, new_org=None, user=None):
    """
    Import a library into a tenant's namespace.

    Creates a new library with the importing tenant's UUID.
    AC-LIB-032: Sets tenant_uuid to importing tenant.
    AC-LIB-026: New tenant can create libraries immediately.
    """
    from .models import LibraryMetadata, LibraryComponent
    from . import api

    source_lib = export_data.get('library', {})
    org = new_org or source_lib.get('org', 'Imported')
    source_key = source_lib.get('library_key', '')

    # Generate new library key for the importing tenant
    import_id = str(uuid.uuid4())[:8]
    new_key = f"lib:{org}:imported-{import_id}"

    with transaction.atomic():
        metadata = api.create_library(
            library_key=new_key,
            org=org,
            title=f"[Imported] {source_lib.get('title', 'Untitled')}",
            description=source_lib.get('description', ''),
            user=user,
        )
        metadata.tenant_uuid = importing_tenant_uuid
        metadata.save(update_fields=['tenant_uuid', 'updated_at'])

        # Import components
        imported_count = 0
        for comp_data in export_data.get('components', []):
            comp_key = f"lb:{new_key}:component+type@{comp_data['block_type']}+block@imported-{uuid.uuid4().hex[:8]}"
            api.add_component(
                library_key=new_key,
                usage_key=comp_key,
                block_type=comp_data['block_type'],
                display_name=comp_data.get('display_name', ''),
                user=user,
            )
            imported_count += 1

    logger.info(
        "Library imported: %s -> %s for tenant %s (%d components)",
        source_key, new_key, importing_tenant_uuid, imported_count,
    )

    return {
        'new_library_key': new_key,
        'source_library_key': source_key,
        'importing_tenant_uuid': str(importing_tenant_uuid),
        'components_imported': imported_count,
    }
