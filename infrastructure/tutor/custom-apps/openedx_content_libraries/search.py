"""
Meilisearch integration for Content Libraries v2 search.

@covers: AC-LIB-021 (search <2s)
"""
import logging
import time

from django.conf import settings

logger = logging.getLogger(__name__)

LIBRARY_INDEX_NAME = 'content_libraries'
COMPONENT_INDEX_NAME = 'library_components'


def get_meilisearch_client():
    """Get Meilisearch client using existing platform configuration."""
    try:
        import meilisearch
        host = getattr(settings, 'MEILISEARCH_URL', 'http://meilisearch:7700')
        api_key = getattr(settings, 'MEILISEARCH_API_KEY', '')
        return meilisearch.Client(host, api_key)
    except ImportError:
        logger.warning("meilisearch package not available")
        return None


def ensure_indexes():
    """Create/update Meilisearch indexes for libraries and components."""
    client = get_meilisearch_client()
    if not client:
        return False

    try:
        # Library index
        client.create_index(LIBRARY_INDEX_NAME, {'primaryKey': 'id'})
        lib_index = client.index(LIBRARY_INDEX_NAME)
        lib_index.update_filterable_attributes([
            'org', 'tenant_uuid', 'is_deleted', 'allow_public_read',
        ])
        lib_index.update_searchable_attributes([
            'title', 'description', 'org', 'library_key',
        ])
        lib_index.update_sortable_attributes([
            'updated_at', 'published_component_count', 'title',
        ])

        # Component index
        client.create_index(COMPONENT_INDEX_NAME, {'primaryKey': 'id'})
        comp_index = client.index(COMPONENT_INDEX_NAME)
        comp_index.update_filterable_attributes([
            'library_key', 'block_type', 'is_deleted', 'has_unpublished_changes',
            'tenant_uuid',
        ])
        comp_index.update_searchable_attributes([
            'display_name', 'usage_key', 'block_type',
        ])
        comp_index.update_sortable_attributes([
            'last_published_at', 'display_name',
        ])

        logger.info("Meilisearch indexes created/updated: %s, %s",
                     LIBRARY_INDEX_NAME, COMPONENT_INDEX_NAME)
        return True
    except Exception:
        logger.exception("Failed to create Meilisearch indexes")
        return False


def index_library(library_metadata):
    """Index a single library in Meilisearch."""
    client = get_meilisearch_client()
    if not client:
        return

    try:
        doc = {
            'id': str(library_metadata.id),
            'library_key': library_metadata.library_key,
            'org': library_metadata.org,
            'title': library_metadata.title,
            'description': library_metadata.description,
            'tenant_uuid': str(library_metadata.tenant_uuid) if library_metadata.tenant_uuid else None,
            'allow_public_read': library_metadata.allow_public_read,
            'is_deleted': library_metadata.is_deleted,
            'published_component_count': library_metadata.published_component_count,
            'draft_component_count': library_metadata.draft_component_count,
            'updated_at': library_metadata.updated_at.isoformat() if library_metadata.updated_at else None,
        }
        client.index(LIBRARY_INDEX_NAME).add_documents([doc])
    except Exception:
        logger.exception("Failed to index library: %s", library_metadata.library_key)


def index_component(component):
    """Index a single component in Meilisearch."""
    client = get_meilisearch_client()
    if not client:
        return

    try:
        doc = {
            'id': str(component.id),
            'library_key': component.library.library_key,
            'usage_key': component.usage_key,
            'block_type': component.block_type,
            'display_name': component.display_name,
            'is_deleted': component.is_deleted,
            'has_unpublished_changes': component.has_unpublished_changes,
            'tenant_uuid': str(component.library.tenant_uuid) if component.library.tenant_uuid else None,
            'last_published_at': component.last_published_at.isoformat() if component.last_published_at else None,
        }
        client.index(COMPONENT_INDEX_NAME).add_documents([doc])
    except Exception:
        logger.exception("Failed to index component: %s", component.usage_key)


def reindex_all():
    """Full reindex of all libraries and components. Batch by 1000."""
    from .models import LibraryMetadata, LibraryComponent

    client = get_meilisearch_client()
    if not client:
        return {'libraries': 0, 'components': 0, 'error': 'No client'}

    ensure_indexes()

    lib_count = 0
    comp_count = 0
    batch_size = 1000

    # Index libraries in batches
    libraries = LibraryMetadata.objects.filter(is_deleted=False)
    batch = []
    for lib in libraries.iterator(chunk_size=batch_size):
        batch.append({
            'id': str(lib.id),
            'library_key': lib.library_key,
            'org': lib.org,
            'title': lib.title,
            'description': lib.description,
            'tenant_uuid': str(lib.tenant_uuid) if lib.tenant_uuid else None,
            'allow_public_read': lib.allow_public_read,
            'is_deleted': lib.is_deleted,
            'published_component_count': lib.published_component_count,
            'draft_component_count': lib.draft_component_count,
            'updated_at': lib.updated_at.isoformat() if lib.updated_at else None,
        })
        if len(batch) >= batch_size:
            client.index(LIBRARY_INDEX_NAME).add_documents(batch)
            lib_count += len(batch)
            batch = []
    if batch:
        client.index(LIBRARY_INDEX_NAME).add_documents(batch)
        lib_count += len(batch)

    # Index components in batches
    components = LibraryComponent.objects.filter(is_deleted=False).select_related('library')
    batch = []
    for comp in components.iterator(chunk_size=batch_size):
        batch.append({
            'id': str(comp.id),
            'library_key': comp.library.library_key,
            'usage_key': comp.usage_key,
            'block_type': comp.block_type,
            'display_name': comp.display_name,
            'is_deleted': comp.is_deleted,
            'has_unpublished_changes': comp.has_unpublished_changes,
            'tenant_uuid': str(comp.library.tenant_uuid) if comp.library.tenant_uuid else None,
            'last_published_at': comp.last_published_at.isoformat() if comp.last_published_at else None,
        })
        if len(batch) >= batch_size:
            client.index(COMPONENT_INDEX_NAME).add_documents(batch)
            comp_count += len(batch)
            batch = []
    if batch:
        client.index(COMPONENT_INDEX_NAME).add_documents(batch)
        comp_count += len(batch)

    logger.info("Reindexed %d libraries and %d components", lib_count, comp_count)
    return {'libraries': lib_count, 'components': comp_count}


def search_libraries(query, tenant_uuid=None, filters=None, limit=20, offset=0):
    """
    Search libraries via Meilisearch (AC-LIB-021).

    Respects tenant isolation — results filtered by tenant_uuid.
    Returns results in <2s (AC-LIB-021).
    """
    client = get_meilisearch_client()
    if not client:
        return {'hits': [], 'total': 0, 'query': query, 'processing_time_ms': 0}

    start = time.monotonic()

    search_params = {
        'limit': limit,
        'offset': offset,
    }

    # Build filter for tenant isolation
    filter_parts = ['is_deleted = false']
    if tenant_uuid:
        filter_parts.append(
            f'(tenant_uuid = "{tenant_uuid}" OR allow_public_read = true)'
        )
    if filters:
        filter_parts.extend(filters)

    search_params['filter'] = ' AND '.join(filter_parts)

    try:
        result = client.index(LIBRARY_INDEX_NAME).search(query, search_params)
        elapsed_ms = int((time.monotonic() - start) * 1000)

        return {
            'hits': result.get('hits', []),
            'total': result.get('estimatedTotalHits', 0),
            'query': query,
            'processing_time_ms': elapsed_ms,
        }
    except Exception:
        logger.exception("Library search failed for query: %s", query)
        return {'hits': [], 'total': 0, 'query': query, 'processing_time_ms': 0}


def search_components(query, library_key=None, tenant_uuid=None, block_type=None,
                       limit=20, offset=0):
    """
    Search library components via Meilisearch (AC-LIB-021).

    Supports filtering by library, tenant, and block type.
    """
    client = get_meilisearch_client()
    if not client:
        return {'hits': [], 'total': 0, 'query': query, 'processing_time_ms': 0}

    start = time.monotonic()

    search_params = {
        'limit': limit,
        'offset': offset,
    }

    filter_parts = ['is_deleted = false']
    if library_key:
        filter_parts.append(f'library_key = "{library_key}"')
    if tenant_uuid:
        filter_parts.append(f'tenant_uuid = "{tenant_uuid}"')
    if block_type:
        filter_parts.append(f'block_type = "{block_type}"')

    search_params['filter'] = ' AND '.join(filter_parts)

    try:
        result = client.index(COMPONENT_INDEX_NAME).search(query, search_params)
        elapsed_ms = int((time.monotonic() - start) * 1000)

        return {
            'hits': result.get('hits', []),
            'total': result.get('estimatedTotalHits', 0),
            'query': query,
            'processing_time_ms': elapsed_ms,
        }
    except Exception:
        logger.exception("Component search failed for query: %s", query)
        return {'hits': [], 'total': 0, 'query': query, 'processing_time_ms': 0}
