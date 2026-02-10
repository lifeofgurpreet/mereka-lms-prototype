# Content Libraries v2 Architecture Overview
_Audience: Engineering + Architecture • Last updated: 2026-02-10_

## System Overview

Content Libraries v2 is a Blockstore-backed component authoring system that enables granular, reusable XBlock components to be authored once, versioned with draft/published lifecycle, and referenced across multiple courses. Libraries replace the legacy "copy-paste" content model with a "reference and sync" model, solving the "update once, propagate everywhere" problem at enterprise scale.

**Key differentiator**: Blockstore provides git-like versioning for learning content, enabling content teams to manage curriculum at scale with version control, rollback, and differential updates.

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Studio (CMS)                                │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Authoring MFE (frontend-app-authoring)                  │   │
│  │  - Library management UI                                 │   │
│  │  - Component editor                                      │   │
│  └────────────────────┬─────────────────────────────────────┘   │
└───────────────────────┼─────────────────────────────────────────┘
                        │ REST API
                        ▼
         ┌──────────────────────────────┐
         │   Content Libraries App      │
         │   (Django app in CMS)        │
         │   - /api/libraries/v2/       │
         │   - Library CRUD             │
         │   - Component management     │
         │   - Publishing workflow      │
         └──────────┬───────────────────┘
                    │
                    ▼
         ┌──────────────────────────────┐
         │      Blockstore              │
         │   (Django app in CMS)        │
         │   - Bundle storage           │
         │   - Versioning (git-like)    │
         │   - Draft/published commits  │
         └──────────┬───────────────────┘
                    │
                    ▼
         ┌──────────────────────────────┐
         │   Object Storage (GCS)       │
         │   - Library bundles          │
         │   - XBlock content files     │
         │   - Version snapshots        │
         └──────────────────────────────┘

Course Integration:
┌─────────────────────────────────────────┐
│   Course (Studio)                       │
│   ┌─────────────────────────────────┐   │
│   │ library_content XBlock          │   │
│   │ - Randomized component selection│   │
│   │ - Fixed component reference     │   │
│   │ - Sync from library action      │   │
│   └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

---

## Data Flow

### Library Creation Flow
1. **Author** creates library via Studio UI
2. **API**: `POST /api/libraries/v2/` with `org`, `slug`, `title`
3. **Libraries App**: Creates `ContentLibrary` model record in MySQL
4. **Blockstore**: Creates bundle collection for library
5. **GCS**: Initializes empty bundle in object storage
6. **Response**: Returns library metadata with unique `library_key` (`lib:{org}:{slug}`)

### Component Authoring Flow
1. **Author** adds component (e.g., Problem XBlock) to library
2. **API**: `POST /api/libraries/v2/{library_key}/blocks/` with `block_type: problem`
3. **Blockstore**: Creates bundle for component (draft state)
4. **Author** edits component content via Studio editor
5. **API**: `PATCH /api/libraries/v2/{library_key}/blocks/{usage_key}` with content
6. **Blockstore**: Writes draft bundle to GCS
7. **Library**: Flags `has_unpublished_changes: true`

### Publishing Flow
1. **Author** clicks "Publish" in library UI
2. **API**: `POST /api/libraries/v2/{library_key}/commit/` with optional message
3. **Blockstore**: Commits all draft bundles (creates new version snapshot)
4. **Timestamp**: Records commit timestamp, author, change summary
5. **Library**: Resets `has_unpublished_changes: false`
6. **Search**: Re-indexes library content in Meilisearch/Elasticsearch
7. **Courses**: Courses referencing library see "update available" notification

### Cross-Course Reuse Flow
1. **Author** adds `library_content` XBlock to course unit
2. **Config**: Selects source library, component count, filters
3. **LMS Runtime**: On course unit load, fetches published components from library
4. **Randomization** (if configured): Selects N random components per learner
5. **Rendering**: Components render in course unit as if native to course
6. **Sync**: Author explicitly syncs to pull latest library updates (opt-in)

---

## Integration Points

### Blockstore
- **Architecture**: Integrated Django app (not separate microservice in Redwood)
- **Storage Backend**: Google Cloud Storage (production), local filesystem (dev)
- **APIs**:
  - `create_bundle()` - Initialize new component bundle
  - `write_draft_file()` - Write draft content
  - `commit()` - Publish draft as new version
  - `read_bundle()` - Read published bundle content

### Studio Authoring MFE
- **Endpoint**: `https://studio.academyv2.mereka.io/library/{library_key}`
- **Features**:
  - Library listing and filtering
  - Component addition/editing/removal
  - Publish workflow
  - Usage analytics (which courses reference library)

### LMS Runtime
- **Integration**: `library_content` XBlock references library via `library_key`
- **Content Resolution**: LMS queries library API for published components
- **Sync**: Course authors trigger sync from Studio (pulls latest published versions)

### Search Index (Meilisearch/Elasticsearch)
- **Indexing**: Triggered on library publish event
- **Fields Indexed**: Library title, description, component content (HTML, problem text)
- **Search**: Full-text search across libraries, filtered by organization

---

## Key Design Decisions

### 1. Blockstore Integration: Embedded vs. Separate Service
**Decision**: Blockstore runs as Django app within CMS process (not separate service)

**Rationale**:
- **Redwood architecture**: Upstream moved from microservice to integrated app.
- **Simplicity**: No separate deployment, service discovery, or authentication layer.
- **Performance**: Direct function calls instead of HTTP requests.

**Trade-offs**:
- CMS process consumes more memory/CPU for Blockstore operations.
- Cannot scale Blockstore independently from CMS.

### 2. Object Storage Backend: Local Filesystem vs. GCS
**Decision**: Google Cloud Storage for production, local filesystem for dev

**Rationale**:
- **Durability**: GCS provides 99.999999999% durability (11 nines).
- **Scalability**: No local disk space constraints.
- **Backups**: GCS versioning and lifecycle policies provide automatic backups.

**Trade-offs**:
- Network latency for bundle reads/writes (mitigated by caching).
- GCS API costs (minimal at expected scale).

### 3. Sync Strategy: Auto-Sync vs. Opt-In Sync
**Decision**: Opt-in sync (course authors explicitly trigger updates)

**Rationale**:
- **Control**: Auto-sync could break courses if library updates introduce breaking changes.
- **Stability**: Courses remain stable until author reviews and accepts updates.
- **Audit trail**: Explicit sync creates clear change log.

**Trade-offs**:
- Updates are not instant (requires manual action).
- Risk of courses running outdated library content indefinitely.

### 4. Multi-Tenancy: Organization-Based Access vs. Custom ACLs
**Decision**: Organization-based access (libraries scoped to Open edX organizations)

**Rationale**:
- **Consistency**: Matches Studio's existing course access model.
- **Simplicity**: No custom ACL implementation required.
- **Enterprise support**: Organizations map directly to `EnterpriseCustomer` tenants.

**Trade-offs**:
- Cannot share libraries across organizations without making them globally public.
- No per-component access controls within a library.

### 5. Versioning: Linear History vs. Branching
**Decision**: Linear commit history (no branching)

**Rationale**:
- **Simplicity**: Branching model (like git branches) adds UI complexity.
- **Use case**: Content authoring is typically sequential, not parallel development.
- **Rollback**: Linear history supports rollback to any prior version.

**Trade-offs**:
- No feature branches for experimental content.
- Concurrent edits by multiple authors require coordination.

---

## Performance Considerations

### Library Listing (1000+ libraries)
- **Strategy**: Pagination (default 20 items per page) + Redis caching
- **Query optimization**: Index on `org`, `library_type`, `created_at`, `modified_at`
- **Target**: p95 latency <300ms for listing page

### Component Listing (1000+ components)
- **Strategy**: Lazy loading + search index for filtering
- **Query optimization**: Index on `library_key`, `block_type`, `usage_key`
- **Target**: p95 latency <3s for large library component view

### Search Indexing
- **Trigger**: Async task on library publish (Celery worker)
- **Index size**: ~100KB per library (average)
- **Target**: Re-index completes within 30 seconds of publish

---

## Related Specs and ADRs
- **Spec**: `specs/content-libraries-v2_spec.md`
- **Runbook**: `docs/runbooks/content-libraries-runbook.md`
- **Multi-Tenancy**: `specs/multi-tenancy-architecture_spec.md`
- **Tutor Configuration**: `specs/tutor-configuration_spec.md`
- **K8s Deployment**: `specs/k8s-deployment_spec.md`
