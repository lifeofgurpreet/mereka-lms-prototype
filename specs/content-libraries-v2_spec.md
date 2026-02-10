---
title: "Content Libraries v2 Management & Enterprise Usage"
type: "feature_spec"
status: "draft"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
links:
  related_docs:
    - "docs/architecture/content-libraries-overview.md"
    - "docs/runbooks/content-libraries-runbook.md"
    - "docs/operations/TROUBLESHOOTING.md"
  related_specs:
    - "specs/multi-tenancy-architecture_spec.md"
    - "specs/enterprise-microservices_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/tutor-configuration_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/disaster-recovery-business-continuity_spec.md"
    - "specs/data-privacy-gdpr-compliance_spec.md"
    - "specs/analytics-pipeline_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

A comprehensive management and enterprise usage framework for Open edX Content Libraries v2, the modern component-based content authoring system available in the Redwood release. Content Libraries v2 replaces the legacy Content Libraries v1 system with a Blockstore-backed architecture that enables granular, reusable XBlock components to be authored once in a library, versioned with explicit draft/published lifecycle, and referenced across multiple courses without duplication.

This spec covers the full lifecycle of Content Libraries v2 on the Mereka Academy platform: library creation and organization, component-based authoring with XBlock support, versioning with draft/published workflow, cross-course content reuse via library content blocks, enterprise multi-tenant library access controls, content search and discovery, usage analytics, backup and recovery, performance optimization for scale, and integration with the existing course authoring pipeline in Studio. The system builds on the `openedx.core.djangoapps.content_libraries` Django app already enabled in the Mereka LMS/CMS settings (confirmed in `deploy/k8s/base/apps/openedx/settings/lms/production.py`).

The architecture relies on Blockstore as the underlying storage and versioning engine. In Redwood, Blockstore is integrated as a Django app within the LMS/CMS process (not a separate service), storing library content bundles in the configured object storage backend (local filesystem or Google Cloud Storage). Each library is a Blockstore collection of typed bundles, where each bundle maps to an XBlock component. Libraries expose a REST API (`/api/libraries/v2/`) consumed by Studio and the authoring MFE (`frontend-app-authoring`).

## Why it matters

Mereka Academy serves multiple enterprise clients (tenants) who need curated, reusable learning content that can be maintained in one place and deployed across many courses. Without a formal Content Libraries v2 strategy, content authors duplicate XBlock components across courses manually, updates require touching every course individually, there is no version history for content changes, and enterprise tenants have no mechanism to share approved content templates within their organization while preventing cross-tenant content access.

Content Libraries v2 solves the "update once, propagate everywhere" problem that becomes critical at enterprise scale. When a compliance training module changes, updating a single library component propagates the change to every course that references it. When an enterprise client provides branded assessment templates, those live in a tenant-scoped library that their content authors can reuse across all courses. When content quality review is needed, the draft/published workflow provides a gate between authoring and learner visibility.

This spec establishes the contracts for how libraries are created, governed, versioned, shared, and operated -- ensuring that the platform's content authoring infrastructure scales with the multi-tenant enterprise model defined in `specs/multi-tenancy-architecture_spec.md`.

## Success looks like

- Content authors can create, populate, version, and publish Content Libraries v2 from Studio within the existing authoring workflow
- A library component updated and published in one place automatically becomes available for sync across all courses referencing it, with course authors choosing when to accept updates
- Enterprise tenants can create organization-scoped libraries visible only to their content team, with zero library content leakage across tenants
- Platform operators can search, categorize, and audit library content across the platform for compliance and quality purposes
- Library content survives disaster recovery scenarios: backups include all library bundles and metadata, restore recreates libraries to the last known good state
- Libraries with 1,000+ components load their listing pages in Studio within 3 seconds at p95
- Content Library analytics show per-component usage frequency across courses, enabling data-driven content strategy

---

# Agent Contract

## Scope

- In scope:
  - Content Libraries v2 architecture within the Mereka Redwood deployment (Blockstore integration, Django app configuration)
  - Library lifecycle: creation, configuration, component authoring, versioning, publishing, deprecation, deletion
  - XBlock component management within libraries: adding, editing, removing, reordering component types
  - Custom XBlock integration and validation within libraries
  - Cross-course content reuse via `library_content` XBlocks (randomized and fixed references)
  - Library access control model: user roles (admin, author, reader), organization-based access, team permissions
  - Multi-tenant library isolation: enterprise customer-scoped libraries, cross-tenant access prevention
  - Content search, tagging, and categorization within libraries (Studio search integration)
  - Library usage tracking and analytics (which courses reference which library components)
  - Library content backup, export, import, and disaster recovery
  - Performance optimization for large libraries (pagination, lazy loading, search indexing)
  - Content review workflows using draft/published versioning
  - Library REST API contracts (`/api/libraries/v2/`)
  - Studio and authoring MFE integration for library management
  - Integration with enterprise catalog for tenant-scoped library discovery

- Out of scope:
  - Content Libraries v1 (legacy) -- deprecated; this spec covers v2 only
  - Individual course content creation (covered by standard Studio workflows)
  - Video transcoding and delivery pipelines (covered by `specs/video-pipeline-delivery_spec.md`)
  - Payment and licensing for library access (covered by `specs/ecommerce-purchase-gateway_spec.md`)
  - Mobile app library browsing (covered by `specs/mobile-apps-enterprise_spec.md`)
  - Custom XBlock development (authoring new XBlock types is outside this spec; this spec covers integrating existing XBlocks into libraries)
  - Blockstore infrastructure changes (storage backend selection is an infrastructure decision)

## Non-goals

- Building a custom library management UI outside of Studio and the upstream authoring MFE -- we use the upstream `frontend-app-authoring` library management views
- Supporting real-time collaborative editing of library components by multiple authors simultaneously -- Blockstore does not support concurrent writes to the same bundle
- Implementing a library marketplace or storefront where tenants can purchase library content from third parties
- Supporting library federation across multiple Open edX instances (inter-instance library sharing)
- Migrating existing Content Libraries v1 to v2 automatically -- migration is manual and outside this spec's scope (though the API supports import)
- Building a custom content review/approval workflow engine -- we use draft/published lifecycle and organizational permissions as the review gate
- Supporting per-component access controls within a single library -- access is at the library level, not component level

## Assumptions

- The `openedx.core.djangoapps.content_libraries` Django app is enabled in both LMS and CMS settings (confirmed: `deploy/k8s/base/apps/openedx/settings/lms/production.py` line 288-289)
- Blockstore is running as an integrated Django app within the LMS/CMS process (Redwood architecture), not as a separate microservice
- The `frontend-app-authoring` MFE includes the Content Libraries v2 management UI (Redwood default)
- MongoDB Atlas stores courseware (modulestore) but Content Libraries v2 uses Blockstore (filesystem/object storage), not MongoDB
- The existing enterprise multi-tenancy architecture (`specs/multi-tenancy-architecture_spec.md`) provides the tenant identity model (`EnterpriseCustomer`) and organization model that libraries will be scoped to
- The existing Studio user permission model supports the `CONTENT_LIBRARY_CREATOR` role for library creation authorization
- Google Cloud Storage is the target object storage backend for Blockstore bundles in production (per `infrastructure/terraform/modules/storage/README.md`)
- The platform runs Tutor 18.2.2 (Redwood) which includes the Content Libraries v2 REST API at `/api/libraries/v2/`
- Meilisearch or Elasticsearch (depending on Redwood configuration) provides the content search index for libraries

---

## Requirements

### Functional

#### Library Lifecycle Management

- The system MUST support creating Content Libraries v2 via the Studio UI and the REST API (`POST /api/libraries/v2/`)
- The system MUST require a unique `library_key` identifier for each library, following the format `lib:{org}:{slug}` where `org` is the owning organization and `slug` is a URL-safe identifier
- The system MUST associate each library with exactly one Open edX organization, which serves as the primary access control boundary
- The system MUST support configuring a library with the following metadata: `title` (display name), `description` (purpose and contents), `license` (content license type), `library_type` (e.g., `complex` for mixed content, or a specific block type for type-restricted libraries)
- The system MUST support a `has_unpublished_changes` flag on each library that indicates whether draft changes exist that have not been published
- The system MUST support soft-deletion of libraries: deleted libraries MUST be recoverable for 30 days before permanent removal
- The system SHOULD support library archival as a distinct state from deletion, allowing libraries to be hidden from active listings without data removal

#### Component-Based Authoring

- The system MUST support adding XBlock components to a library, where each component is a Blockstore bundle within the library's collection
- The system MUST support the following core XBlock types in libraries: `html` (HTML content), `problem` (assessment/problem), `video` (video reference), `drag-and-drop-v2`, `openassessment` (ORA2), and `discussion`
- The system SHOULD support adding any installed XBlock type to a library, provided the XBlock implements the `student_view` and `studio_view` mixins
- The system MUST assign each component a unique `usage_key` within the library namespace
- The system MUST support editing component content via Studio's component editor (inline or modal)
- The system MUST support removing components from a library; removal MUST NOT affect courses that have already synced the component (courses retain their last-synced copy)
- The system MUST support reordering components within a library for organizational purposes
- The system MUST track the component count per library and expose it via the API response

#### Versioning and Publishing

- The system MUST implement a two-phase content lifecycle: **draft** (work in progress, visible only to authors) and **published** (committed snapshot, available for course reference)
- The system MUST support publishing all draft changes in a library as an atomic operation via `POST /api/libraries/v2/{library_key}/commit/`
- The system MUST record each publish event with a timestamp, the publishing user, and a change summary
- The system MUST support reverting a library to a previous published version (rollback to a prior commit in Blockstore)
- The system MUST ensure that courses referencing library components see only the **published** version unless explicitly opted into draft previews
- The system SHOULD maintain a version history of at least the last 50 published versions per library
- The system MUST prevent publishing if no draft changes exist (idempotent but informative -- return success with "no changes to publish" message)
- The system MUST support viewing the diff between the current draft and the last published version via the authoring MFE

#### Cross-Course Content Reuse

- The system MUST support embedding library content in courses via the `library_content` XBlock, which references a specific library by `library_key`
- The system MUST support two reuse modes:
  - **Randomized selection**: the `library_content` XBlock selects a configurable number of components randomly from the library for each learner (the existing `max_count` parameter)
  - **Fixed reference**: a specific component from a library is embedded in a course unit (the `library_v2_ref` block type in Redwood)
- The system MUST support a "sync from library" action in Studio that pulls the latest published version of referenced library components into the course
- The system MUST NOT auto-sync library changes to courses -- course authors MUST explicitly trigger sync to accept updates (opt-in update model)
- The system MUST display a notification in Studio when a course references a library component that has newer published versions available
- The system SHOULD display the number of courses referencing a given library or component via the library management API
- The system MUST ensure that if a library is deleted, courses retain their last-synced copies of components (no cascading content loss)

#### Library Access Controls and Permissions

- The system MUST enforce role-based access to libraries with the following roles:
  - **Library Admin**: full control -- create, edit, delete, publish, manage permissions, configure settings
  - **Library Author**: add and edit components, publish (if permitted by library settings), cannot delete the library or manage permissions
  - **Library Reader**: view library contents and copy/reference components to courses, cannot edit library content
- The system MUST restrict library creation to users with the `CONTENT_LIBRARY_CREATOR` Django permission or staff/superuser status
- The system MUST scope library visibility by organization: users can only see libraries belonging to organizations they are members of, unless the library is explicitly marked as publicly readable
- The system MUST support marking a library as `allow_public_read` (boolean), which makes its contents viewable by any authenticated user (but not editable)
- The system MUST enforce that the library creator is automatically assigned the Library Admin role
- The system MUST support granting and revoking access to individual users via the API (`POST/DELETE /api/libraries/v2/{library_key}/team/`)
- The system MUST log all permission changes (grant, revoke, role change) for audit purposes

#### Multi-Tenant Library Management

- The system MUST enforce tenant-scoped library isolation: libraries created within an organization that maps to an `EnterpriseCustomer` MUST be visible only to users within that enterprise customer's organization (per `specs/multi-tenancy-architecture_spec.md`)
- The system MUST prevent cross-tenant library access: a user authenticated under tenant A's enterprise context MUST NOT be able to list, view, or reference libraries belonging to tenant B's organization
- The system MUST support a platform-global library scope for libraries owned by the Mereka Academy organization (the platform operator), which MAY be made available to all tenants via `allow_public_read`
- The system SHOULD support "shared library catalogs" where a platform operator can designate specific libraries as available to specific enterprise customers without making them globally public
- The system MUST ensure that enterprise catalog queries (`/api/v1/enterprise-catalogs/`) include library content availability when relevant, so enterprise admins can discover which libraries their organization has access to
- The system MUST ensure that library access enforcement uses the same organization membership model as Studio course access, preventing isolation bypasses through API-only access paths
- The system MUST include `organization` and `enterprise_customer_uuid` (where applicable) in library API responses to enable tenant-aware UI rendering

#### Content Search, Discovery, and Categorization

- The system MUST index library content in the platform search index (Meilisearch or Elasticsearch, per Redwood configuration) to enable full-text search across library titles, descriptions, and component content
- The system MUST support filtering library listings by: organization, library type, tag, creation date range, and modification date range
- The system MUST support tagging libraries and individual components with taxonomy-based tags (using Open edX's content tagging system introduced in Redwood)
- The system MUST support pagination of library listings and component listings with configurable page sizes (default 20 items per page)
- The system MUST support sorting library listings by: title (alphabetical), date created, date modified, and component count
- The system SHOULD support searching within a specific library for components matching a text query
- The system MUST ensure search results respect access controls: users MUST NOT see libraries or components they lack permission to view in search results
- The system MUST re-index library content after each publish event to keep the search index current

#### Library Analytics and Usage Tracking

- The system MUST track library usage metrics: which courses reference each library, and how many `library_content` or `library_v2_ref` blocks reference each component
- The system MUST expose library usage data via the API (`GET /api/libraries/v2/{library_key}/links/`) to show all courses consuming library content
- The system MUST track component-level usage: for each component, the system MUST record the count of course units that embed or reference it
- The system SHOULD integrate library usage events into the analytics pipeline (per `specs/analytics-pipeline_spec.md`) so that xAPI events from library-sourced content include the `library_key` in the event context
- The system MUST support generating a library usage report showing: total libraries, total components, total references across courses, most-referenced components, and orphaned libraries (no course references)
- The system SHOULD track learner interaction metrics for library-sourced content (completion rates, assessment scores) at the library component level, aggregated across all courses that reference the component
- The system MUST scope analytics visibility to the user's organization: enterprise admins see usage data only for libraries within their organization

#### Backup, Recovery, and Disaster Recovery

- The system MUST include Content Libraries v2 data in the platform backup strategy (per `specs/disaster-recovery-business-continuity_spec.md`)
- Library metadata (titles, descriptions, permissions, organization associations) stored in MySQL MUST be backed up via the existing Cloud SQL backup schedule
- Library content bundles stored in Blockstore (GCS or filesystem) MUST be backed up independently via GCS bucket versioning or periodic snapshots
- The system MUST support exporting a single library as an OLX (Open Learning XML) archive via `GET /api/libraries/v2/{library_key}/export/`
- The system MUST support importing a library from an OLX archive via `POST /api/libraries/v2/import/`
- The system MUST ensure that library restore from backup preserves all component content, version history, and permission assignments
- The system SHOULD support per-library export as a scheduled job for critical libraries, storing exports in a designated GCS bucket
- Recovery Time Objective (RTO) for library content MUST be no greater than the platform RTO defined in `specs/disaster-recovery-business-continuity_spec.md`

#### Content Quality Assurance and Review Workflows

- The system MUST use the draft/published versioning model as the primary quality gate: content is visible to learners only after an explicit publish action
- The system MUST support restricting publish permissions to Library Admins only, enabling a workflow where Library Authors submit draft changes and Library Admins review and publish
- The system SHOULD support a "preview" mode in Studio where Library Admins can view draft library content as it would appear to learners before publishing
- The system MUST log all publish events with the publishing user's identity, enabling accountability for content changes
- The system SHOULD support inline commenting on library components via Studio for review feedback (if supported by the authoring MFE)
- The system MUST support reverting a published library to a previous version if a quality issue is discovered post-publish

#### Library Migration, Export, and Import

- The system MUST support exporting any library as a tar.gz OLX archive containing all component content, metadata, and version history
- The system MUST support importing libraries from OLX archives, creating new libraries or updating existing ones
- The system MUST validate imported content before committing: XBlock types must be installed, content must parse without errors
- The system MUST reject imports that contain XBlock types not installed on the platform, with a clear error listing the missing types
- The system SHOULD support bulk library creation via a management command (`manage.py create_libraries_from_csv`) for enterprise onboarding scenarios
- The system MUST support migrating library content between organizations (e.g., when transferring a library from one tenant to another) via export + import with updated organization ownership

### Non-Functional Requirements

#### Performance

- Library listing API (`GET /api/libraries/v2/`) MUST respond within 500ms at p95 for organizations with up to 100 libraries
- Library component listing (`GET /api/libraries/v2/{library_key}/blocks/`) MUST respond within 1000ms at p95 for libraries with up to 1,000 components
- Library search queries MUST return results within 2000ms at p95 for indexes containing up to 50,000 components across all libraries
- Publishing a library with up to 500 components MUST complete within 30 seconds
- Exporting a library with up to 1,000 components MUST complete within 60 seconds
- The `library_content` XBlock MUST resolve and render library components for learners within 500ms at p95 (after initial cache population)
- Library content sync ("update from library" in Studio) for a course with up to 50 library references MUST complete within 30 seconds

#### Security

- All library API endpoints MUST require authentication (session-based or OAuth2 JWT)
- All library API endpoints MUST enforce organization-based access controls at the view/permission layer, not just at the UI layer
- Library content MUST NOT be accessible via direct Blockstore bundle URLs without passing through the library access control layer
- Cross-tenant library access attempts MUST return HTTP 403 and MUST be logged as security events
- Library export archives MUST NOT include embedded credentials, API keys, or sensitive configuration
- The system MUST enforce CSRF protection on all library mutation endpoints (POST, PUT, PATCH, DELETE)

#### Scalability

- The platform MUST support at least 500 total libraries across all organizations without degrading API response times beyond the stated NFR thresholds
- The platform MUST support at least 50,000 total components across all libraries without degrading search performance beyond the stated NFR thresholds
- Blockstore storage MUST scale horizontally via GCS bucket capacity (no single-machine filesystem limits in production)
- The search index MUST support incremental updates (re-index individual libraries on publish, not full re-index)

#### Accessibility

- Library management interfaces in Studio and the authoring MFE MUST comply with WCAG 2.1 Level AA (per the upstream Open edX accessibility commitment)
- Library content editing modals MUST be keyboard-navigable
- Component type selectors MUST include aria-labels for screen readers

---

## Acceptance Criteria

### Library Lifecycle

- [ ] AC-001: Given a user with `CONTENT_LIBRARY_CREATOR` permission and organization "Mereka", when they call `POST /api/libraries/v2/` with `{"org": "Mereka", "slug": "compliance-2026", "title": "Compliance Training 2026", "description": "Mandatory compliance modules", "type": "complex"}`, then a library is created with key `lib:Mereka:compliance-2026` and the response includes `id`, `org`, `slug`, `title`, `has_unpublished_changes: false`, `allow_public_read: false`
- [ ] AC-002: Given library `lib:Mereka:compliance-2026` exists, when the same `POST` is sent with the same slug, then the response is HTTP 400 with an error indicating the slug is already in use
- [ ] AC-003: Given library `lib:Mereka:compliance-2026` with 5 components, when a Library Admin calls `DELETE /api/libraries/v2/lib:Mereka:compliance-2026/`, then the library is soft-deleted and no longer appears in listing responses, but can be restored within 30 days

### Component Authoring

- [ ] AC-004: Given library `lib:Mereka:compliance-2026`, when a Library Author calls `POST /api/libraries/v2/lib:Mereka:compliance-2026/blocks/` with `{"block_type": "html", "definition_id": "intro-module"}`, then an HTML XBlock component is added to the library and `has_unpublished_changes` becomes `true`
- [ ] AC-005: Given a library with 10 components, when a Library Author edits the content of component `intro-module` via the OLX update endpoint, then the component content is updated in draft and `has_unpublished_changes` remains `true`
- [ ] AC-006: Given a library with a `problem` type component, when a Library Author adds a `video` type component, then both components coexist in the library (mixed-type library support)
- [ ] AC-007: Given a library, when a user attempts to add a component of an XBlock type not installed on the platform, then the response is HTTP 400 with "XBlock type '{type}' is not installed"

### Versioning and Publishing

- [ ] AC-008: Given library `lib:Mereka:compliance-2026` with unpublished draft changes, when a Library Admin calls `POST /api/libraries/v2/lib:Mereka:compliance-2026/commit/`, then all draft changes are committed, `has_unpublished_changes` becomes `false`, and a version record is created with the publisher's username and timestamp
- [ ] AC-009: Given library `lib:Mereka:compliance-2026` with no unpublished changes, when `POST /commit/` is called, then the response is HTTP 200 with a message "No changes to publish" and no new version record is created
- [ ] AC-010: Given a library with 3 published versions, when a Library Admin calls the revert endpoint for version 2, then the library content reverts to the state of version 2 and `has_unpublished_changes` becomes `true` (the revert is staged as a draft, requiring another publish)
- [ ] AC-011: Given a library with a recently published component "quiz-1", when a course author views a course referencing that component in Studio, then Studio shows the published version of "quiz-1" (not any subsequent draft changes)

### Cross-Course Content Reuse

- [ ] AC-012: Given library `lib:Mereka:compliance-2026` with 20 published problem components, when a course author adds a `library_content` XBlock to a course unit and configures it with `source_library_id=lib:Mereka:compliance-2026` and `max_count=5`, then each learner sees 5 randomly selected problems from the library
- [ ] AC-013: Given a `library_v2_ref` block in a course pointing to component "quiz-1" in library `lib:Mereka:compliance-2026`, when the library author updates and publishes "quiz-1", then Studio displays a notification on the course unit indicating "Library content has updates available"
- [ ] AC-014: Given the notification from AC-013, when the course author clicks "Update from library", then the course unit receives the latest published version of "quiz-1"
- [ ] AC-015: Given a library that is deleted after a course has synced its content, then the course retains its last-synced copies and continues to function without errors for learners

### Access Controls

- [ ] AC-016: Given a user who is a member of organization "Acme" (an enterprise tenant), when they call `GET /api/libraries/v2/`, then only libraries belonging to organization "Acme" and libraries with `allow_public_read: true` are returned
- [ ] AC-017: Given a user who is a member of organization "Acme", when they call `GET /api/libraries/v2/lib:Beta:internal-training/`, then the response is HTTP 403
- [ ] AC-018: Given a Library Admin, when they call `POST /api/libraries/v2/lib:Mereka:compliance-2026/team/` with `{"username": "author1", "access_level": "author"}`, then author1 is granted Library Author access and a permission change audit log entry is created
- [ ] AC-019: Given a Library Author, when they attempt to call `DELETE /api/libraries/v2/lib:Mereka:compliance-2026/`, then the response is HTTP 403 (authors cannot delete libraries)

### Multi-Tenant Isolation

- [ ] AC-020: Given enterprise tenant "Acme" with organization "AcmeCorp" and enterprise tenant "Beta" with organization "BetaCorp", when an Acme admin creates library `lib:AcmeCorp:acme-training`, then Beta users calling `GET /api/libraries/v2/` do NOT see `lib:AcmeCorp:acme-training` in results
- [ ] AC-021: Given a platform-global library `lib:Mereka:shared-templates` with `allow_public_read: true`, when a user from any enterprise tenant calls `GET /api/libraries/v2/`, then `lib:Mereka:shared-templates` appears in results with read-only access
- [ ] AC-022: Given a Beta user, when they attempt to add a component from `lib:AcmeCorp:acme-training` to a course via Studio, then the operation is denied and a security event is logged

### Search and Discovery

- [ ] AC-023: Given 50 libraries across 5 organizations, when a user from organization "Mereka" searches for "compliance" in the library listing, then only libraries from "Mereka" (and public libraries) containing "compliance" in the title, description, or component content are returned
- [ ] AC-024: Given a library with 100 components, when the listing API is called with `?page_size=20&page=3`, then components 41-60 are returned with pagination metadata
- [ ] AC-025: Given a library component tagged with taxonomy tag "assessments > multiple-choice", when a user searches for libraries with tag "assessments", then the library containing that component appears in results

### Analytics

- [ ] AC-026: Given library `lib:Mereka:compliance-2026` referenced by 3 courses, when `GET /api/libraries/v2/lib:Mereka:compliance-2026/links/` is called, then the response lists all 3 courses with their course keys and the specific components referenced
- [ ] AC-027: Given a learner completing a problem sourced from library `lib:Mereka:compliance-2026`, when the xAPI event is emitted, then the event context includes `library_key: lib:Mereka:compliance-2026`

### Backup and Recovery

- [ ] AC-028: Given library `lib:Mereka:compliance-2026` with 50 components, when `GET /api/libraries/v2/lib:Mereka:compliance-2026/export/` is called, then a valid tar.gz OLX archive is returned containing all component content and metadata
- [ ] AC-029: Given a valid OLX archive exported from AC-028, when `POST /api/libraries/v2/import/` is called with the archive and `{"org": "Mereka", "slug": "compliance-restored"}`, then a new library is created with identical content to the original
- [ ] AC-030: Given an OLX archive containing a component of type `custom_xblock_v3` (not installed), when import is attempted, then the response is HTTP 400 listing the unsupported XBlock type

### Performance

- [ ] AC-031: Given 100 libraries in organization "Mereka", when `GET /api/libraries/v2/?org=Mereka` is called, then the response is returned within 500ms at p95
- [ ] AC-032: Given a library with 1,000 components, when `GET /api/libraries/v2/{library_key}/blocks/?page_size=50` is called, then the first page is returned within 1000ms at p95
- [ ] AC-033: Given a library with 500 components, when the publish endpoint is called, then the operation completes within 30 seconds

---

## Edge Cases

### Component Authoring Failures

- **Invalid XBlock OLX**: If a Library Author uploads OLX content for a component that fails schema validation, the system MUST reject the update with a descriptive error and leave the component in its prior state. The system MUST NOT store partially valid OLX
- **XBlock type uninstalled after component creation**: If an XBlock type is uninstalled from the platform after components of that type exist in a library, the library listing MUST still render (showing the component as "unsupported type") but editing MUST be disabled for those components. Publishing MUST still work (the OLX is stored as-is regardless of runtime availability)
- **Maximum component limit**: If a library approaches resource limits (e.g., 10,000+ components), the system MUST enforce a configurable per-library component limit. Exceeding the limit MUST return HTTP 400 with "Component limit exceeded"

### Versioning Edge Cases

- **Concurrent publish attempts**: If two Library Admins attempt to publish the same library simultaneously, the system MUST serialize the operations (first publish succeeds, second publish either succeeds with no changes or includes the first publisher's changes). Blockstore's bundle versioning provides natural optimistic concurrency control
- **Revert to deleted component state**: If a library is reverted to a version where a component existed that has since been deleted, the revert MUST restore the component content from the version history. If the component's XBlock type is no longer installed, the restored component MUST be marked as "unsupported type"
- **Orphaned drafts**: If a Library Author creates draft changes but the system is restarted before publishing, the drafts MUST persist in Blockstore's draft layer. The system MUST NOT lose uncommitted work due to process restarts

### Cross-Course Reuse Edge Cases

- **Library deleted while sync in progress**: If a library is deleted while a course is performing a "sync from library" operation, the sync operation MUST fail gracefully with an error message "Library no longer available" and MUST NOT corrupt the existing course content
- **Library component type mismatch**: If a `library_content` XBlock is configured to pull from a library but the library's published components include types not compatible with the course context (e.g., a library containing `openassessment` blocks referenced in a section that doesn't support ORA2), the system MUST skip incompatible components during randomized selection and log a warning
- **Empty library referenced**: If a course references a library that has zero published components, the `library_content` XBlock MUST render an appropriate message for course authors in Studio ("This library has no published content") and MUST render as empty (no error) for learners
- **Circular references**: The system MUST prevent a library component from referencing another library (no library-within-library nesting). The `library_content` XBlock type MUST NOT be addable as a component within a library

### Access Control Edge Cases

- **Organization removal**: If a user is removed from an organization, they MUST immediately lose access to all libraries owned by that organization. Active Studio sessions MUST deny library operations on the next API call
- **Library admin removes themselves**: If the last Library Admin of a library removes themselves, the system MUST prevent the operation and return an error "Cannot remove the last admin of a library"
- **Public library with enterprise content**: If a library marked `allow_public_read` contains content that references enterprise-specific resources (e.g., branded assets), the system MUST NOT prevent the public read flag from being set, but SHOULD warn the Library Admin that the library may contain enterprise-specific references

### Multi-Tenant Edge Cases

- **Organization mapped to multiple tenants**: If a single Open edX organization is erroneously associated with multiple `EnterpriseCustomer` records, the system MUST use the organization as the access boundary (not the enterprise customer UUID). Library access follows organization membership, with enterprise isolation layered on top
- **Tenant offboarding with active libraries**: If a tenant is offboarded (per `specs/multi-tenancy-architecture_spec.md`), their organization's libraries MUST be included in the data export. After the grace period, library content bundles MUST be deleted from Blockstore storage, and library metadata MUST be removed from MySQL
- **Shared course with tenant-scoped library**: If a course shared across tenants references a library that is scoped to only one tenant's organization, learners from the other tenant MUST see the last-synced content in the course (content was synced into the course structure) but MUST NOT have direct access to browse the library

### Import/Export Edge Cases

- **Large archive import**: If an OLX archive exceeds 500MB, the system MUST support chunked upload and asynchronous processing. The import endpoint MUST return HTTP 202 with a task ID, and the client MUST poll for completion
- **Duplicate slug on import**: If an import specifies a slug that already exists in the target organization, the system MUST reject the import with HTTP 409 "Library with slug '{slug}' already exists in organization '{org}'"
- **Version history on import**: Imported libraries MUST start with a clean version history (version 1) in the target system. The original version history is not transferred

### Retry/Timeout Behavior

- Library publish operations MUST be idempotent: retrying a failed publish MUST NOT create duplicate version entries
- Library export operations MUST be resumable: if a download is interrupted, the client can re-request the export (the system SHOULD cache the generated archive for 1 hour)
- Search re-indexing after publish MUST retry up to 3 times with exponential backoff (1s, 4s, 16s) if the search service is temporarily unavailable. If all retries fail, the system MUST log an error and mark the library as "index stale" for the next scheduled re-index job

### Rate Limits

- Library mutation endpoints (create, edit, publish, delete) MUST be rate-limited to 60 requests per minute per user to prevent accidental or malicious bulk operations
- Library listing and read endpoints MUST be rate-limited to 300 requests per minute per user
- Library export endpoints MUST be rate-limited to 5 requests per minute per user to prevent storage abuse

---

## Observability

### Logs

- **Library lifecycle events**: All library creation, deletion, archival, and restore operations MUST be logged with: `library_key`, `organization`, `actor_user_id`, `action`, `timestamp`, `outcome`
- **Component authoring events**: Component additions, edits, and removals MUST be logged with: `library_key`, `component_usage_key`, `block_type`, `actor_user_id`, `action`, `timestamp`
- **Publish events**: Every publish operation MUST log: `library_key`, `version_number`, `component_count`, `actor_user_id`, `timestamp`, `duration_ms`
- **Access control events**: Permission grants, revocations, and denied access attempts MUST be logged with: `library_key`, `target_user_id` (hashed for non-platform-admins), `role`, `actor_user_id`, `action`, `timestamp`
- **Cross-tenant access denials**: Denied library access due to organization/tenant mismatch MUST be logged as security events with: `requesting_user_id_hash`, `requesting_org`, `target_library_key`, `target_org`, `endpoint`, `timestamp`
- **Import/Export events**: All import and export operations MUST log: `library_key`, `archive_size_bytes`, `component_count`, `actor_user_id`, `action`, `timestamp`, `outcome`
- Logs MUST NOT contain raw library content (OLX), user emails, or authentication tokens

### Metrics

- `content_library_count` (gauge, labels: `organization`, `library_type`) -- total libraries per organization
- `content_library_component_count` (gauge, labels: `organization`, `library_key`) -- components per library
- `content_library_api_requests_total` (counter, labels: `endpoint`, `method`, `status_code`, `organization`) -- API traffic
- `content_library_api_latency_seconds` (histogram, labels: `endpoint`, `method`, `organization`) -- API latency
- `content_library_publish_duration_seconds` (histogram, labels: `organization`) -- publish operation duration
- `content_library_publish_total` (counter, labels: `organization`, `outcome`) -- publish events (success/failure)
- `content_library_export_size_bytes` (histogram, labels: `organization`) -- export archive sizes
- `content_library_import_total` (counter, labels: `organization`, `outcome`) -- import events (success/failure/rejected)
- `content_library_sync_total` (counter, labels: `organization`, `outcome`) -- course sync events
- `content_library_search_index_lag_seconds` (gauge) -- time since last successful search index update
- `content_library_cross_tenant_denial_total` (counter, labels: `requesting_org`, `target_org`) -- cross-tenant access denials
- `content_library_references_total` (gauge, labels: `library_key`) -- number of courses referencing each library

### Alerts

- **Critical**: `content_library_cross_tenant_denial_total` rate > 10 in 5 minutes from the same user -- potential unauthorized access attempt
- **Critical**: `content_library_publish_total{outcome="failure"}` > 5 in 10 minutes -- Blockstore or database issue affecting content publishing
- **Warning**: `content_library_search_index_lag_seconds` > 3600 -- search index more than 1 hour behind publish events
- **Warning**: `content_library_api_latency_seconds` p95 > 2x threshold for any endpoint sustained for 15 minutes -- performance degradation
- **Info**: `content_library_count` changes -- new library created or library deleted (operational awareness)
- **Info**: `content_library_export_size_bytes` > 100MB -- large export (potential storage impact)

### Dashboards

- **Content Libraries Overview**: Total libraries (by organization), total components, publish frequency trend, most active libraries (by publish count and component count), libraries with stale search indexes
- **Library Performance**: API latency by endpoint (p50, p95, p99), publish duration trend, export/import throughput, search query latency
- **Library Usage**: Top referenced libraries (by course count), orphaned libraries (zero references), component-level usage heat map, sync frequency per course
- **Library Security**: Cross-tenant denial log, permission change audit trail, rate limit hits by user
- **Tenant Library Health**: Per-tenant library count, component count, publish activity, storage consumption (Blockstore bundle sizes)

---

## Rollout & Rollback

### Rollout Plan

#### Phase 0: Verification and Baseline (Week 1)

1. Verify `content_libraries` Django app is active in LMS and CMS production settings (already confirmed in codebase)
2. Verify Blockstore is integrated and functional: create a test library via `manage.py` or the Django admin
3. Verify the `frontend-app-authoring` MFE includes Content Libraries v2 views (check MFE build configuration)
4. Establish baseline: document current library count, if any, and confirm API endpoints respond
5. Enable library observability metrics and logging (Phase 0 does not gate library access -- it instruments what exists)
6. Verify GCS bucket for Blockstore storage is provisioned and accessible (`lms-blockstore` bucket per Terraform config)

#### Phase 1: Platform Operator Libraries (Week 2-3)

1. Create the first production library (`lib:Mereka:platform-templates`) owned by the Mereka organization
2. Populate with 10-20 commonly reused components (HTML templates, standard problem types, branding blocks)
3. Verify library CRUD operations via Studio and API
4. Verify draft/publish workflow end-to-end: create component, edit, publish, verify in course preview
5. Verify cross-course reuse: add `library_content` XBlock to a test course, confirm randomized selection works
6. Verify library export and import round-trip
7. Run library performance benchmarks (baseline response times for listing, component loading, publish)
8. Enable search indexing for library content

#### Phase 2: Single-Tenant Enterprise Libraries (Week 4-5)

1. Create a library for the first enterprise tenant's organization
2. Verify organization-based access controls: tenant users see their libraries, not Mereka-internal libraries
3. Verify cross-tenant isolation: second tenant users cannot list or access first tenant's libraries
4. Enable `allow_public_read` on `lib:Mereka:platform-templates` and verify tenants can reference it
5. Verify library-sourced content in tenant-scoped courses
6. Train enterprise content authors on library workflows (documentation deliverable)

#### Phase 3: Multi-Tenant Scale and Analytics (Week 6-8)

1. Create libraries for all active enterprise tenants
2. Enable library usage tracking (course reference counting)
3. Enable xAPI event tagging with `library_key` for library-sourced content
4. Build library analytics dashboard in Superset (per-tenant scoped)
5. Load test with 100 libraries and 5,000 components across 10 organizations
6. Tune search index, pagination, and caching based on load test results
7. Enable nightly library backup exports for critical libraries

#### Phase 4: Advanced Workflows and Hardening (Week 9-12)

1. Implement bulk library creation tooling for enterprise onboarding
2. Implement library usage report generation
3. Enable all observability alerts
4. Load test with 500 libraries and 50,000 components
5. Document library disaster recovery runbook
6. Conduct security review of library access control paths
7. Run cross-tenant isolation verification for library endpoints (integration with `scripts/qa/verify-tenant-isolation.sh`)

### Feature Flags

- `CONTENT_LIBRARIES_V2_ENABLED` -- master gate for Content Libraries v2 UI in Studio (default: on in Redwood; verify setting)
- `CONTENT_LIBRARIES_SEARCH_ENABLED` -- gate for search indexing and search UI in library management (default: off; enable after Phase 1 step 8)
- `CONTENT_LIBRARIES_ANALYTICS_ENABLED` -- gate for library usage tracking and xAPI event tagging (default: off; enable after Phase 3 step 2)
- `CONTENT_LIBRARIES_BULK_IMPORT_ENABLED` -- gate for bulk library import/creation management commands (default: off; enable after Phase 4 step 1)
- `CONTENT_LIBRARIES_PUBLIC_READ_ENABLED` -- gate for the `allow_public_read` feature on libraries (default: off; enable after Phase 2 step 4)

### Backward Compatibility

- Enabling Content Libraries v2 management MUST NOT affect existing course content that does not reference libraries
- Existing Content Libraries v1 (if any exist) MUST continue to function alongside v2; v1 and v2 libraries are separate namespaces in Open edX
- Enabling search indexing for libraries MUST NOT affect the course search index or degrade course search performance
- Library analytics integration MUST NOT add measurable latency to the xAPI event pipeline (event enrichment is asynchronous)
- All existing specs' acceptance criteria MUST continue to pass after Content Libraries v2 management features are enabled

### Rollback Steps

#### Disable Library UI in Studio

1. Set `CONTENT_LIBRARIES_V2_ENABLED=false` in Studio/CMS settings
2. Library management UI is hidden from Studio; existing libraries and their content are preserved in Blockstore
3. Courses referencing library content continue to function (references are resolved from synced copies in course structure)
4. Re-enable when issues are resolved

#### Disable Library Search Indexing

1. Set `CONTENT_LIBRARIES_SEARCH_ENABLED=false`
2. Library search returns no results; library listing still works via database queries
3. Search index data is preserved; no re-index needed on re-enable
4. Re-enable when search service issues are resolved

#### Disable Library Analytics

1. Set `CONTENT_LIBRARIES_ANALYTICS_ENABLED=false`
2. New xAPI events no longer include `library_key` context
3. Existing analytics data is preserved in ClickHouse
4. Re-enable when analytics pipeline issues are resolved

#### Emergency: Blockstore Data Corruption

1. Stop all CMS workers to prevent further writes
2. Identify the affected library(ies) from error logs
3. Restore Blockstore GCS bucket from the latest snapshot (GCS versioning)
4. Restore library metadata from Cloud SQL backup if needed
5. Re-index restored libraries in the search index
6. Restart CMS workers
7. Verify restored libraries via the API
8. File a P0 incident report with root cause analysis

#### Emergency: Cross-Tenant Library Leakage

1. Immediately disable `CONTENT_LIBRARIES_PUBLIC_READ_ENABLED` to remove all public library access
2. Review access logs for the affected time window
3. Identify and patch the access control bypass
4. Re-enable public read after fix verification
5. Notify affected tenants per incident response policy
6. Run cross-tenant isolation tests for library endpoints

---

## Open Questions

1. **Blockstore storage backend for production**: Should Blockstore use GCS bucket `lms-blockstore` (referenced in Terraform module) or the local filesystem with periodic GCS sync? GCS provides durability and scalability but may add latency for small reads. Need infrastructure team input on whether Blockstore's GCS backend is production-tested in the Redwood release.

2. **Search engine selection**: Redwood supports both Meilisearch and Elasticsearch for content search. Which search engine is deployed (or will be deployed) on the Mereka GKE cluster? Library search indexing depends on this choice. Need infrastructure team confirmation.

3. **Content Libraries v1 migration**: Do any Content Libraries v1 libraries exist on the current platform? If so, should they be migrated to v2 or left as-is? v1 libraries use a different storage model (modulestore-backed). Need content team inventory.

4. **Per-component access controls**: Should we support restricting access to individual components within a library (e.g., some components visible only to admins, others visible to all library readers)? This is listed as a non-goal, but some enterprise clients may request it. Need product decision.

5. **Library versioning retention policy**: How many published versions should be retained per library? The spec suggests "at least 50" but there is no upper bound. Unlimited retention increases storage costs. Need to decide on a retention policy (e.g., keep last 100 versions, or time-based: keep all versions from the last 12 months). Need operations input.

6. **Content review workflow formality**: Should we implement a formal review workflow (e.g., "submit for review" state, reviewer assignment, approval/rejection flow) beyond the draft/published model? The current spec uses publish permissions as the review gate, which may be insufficient for enterprise clients with compliance-heavy content. Need product requirements from enterprise clients.

7. **Library content licensing and DRM**: Should libraries support per-library or per-component content licensing metadata beyond the basic `license` field? Some enterprise clients may require tracking that specific library content is licensed from third parties with usage restrictions. Need legal and product input.

8. **Cross-organization library sharing without public read**: Should we implement a "shared library catalog" mechanism where a platform operator can grant specific organizations access to specific libraries (more granular than `allow_public_read` which is all-or-nothing)? The spec mentions this as a SHOULD requirement. Need product prioritization.

9. **Library storage quotas**: Should per-organization or per-tenant storage quotas be enforced for library content in Blockstore? Without quotas, a single tenant could consume disproportionate storage. Need commercial and infrastructure input.

10. **Async publish for large libraries**: Should the publish endpoint support asynchronous operation for libraries with 500+ components? The current spec requires 30-second completion, but very large libraries may exceed this. If async, the API would return HTTP 202 with a task ID. Need engineering feasibility assessment.
