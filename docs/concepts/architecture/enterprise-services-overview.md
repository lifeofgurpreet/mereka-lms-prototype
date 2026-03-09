# Enterprise Microservices Architecture Overview
_Audience: Engineering + Architecture • Last updated: 2026-02-10_

## System Overview

The enterprise microservices suite enables "many clients" enterprise functionality on Mereka Academy. Five independent services -- enterprise-catalog, license-manager, enterprise-access, enterprise-subsidy, and enterprise-integrated-channels -- run as K8s Deployments in the `mereka-lms` namespace, sharing MySQL/Redis infrastructure and communicating via internal HTTP and Redis Streams event bus. The system supports multi-tenant operation where each `EnterpriseCustomer` represents an independent client organization.

**Key differentiator**: Upstream Open edX services deployed on Mereka's GKE infrastructure with zero forking, enabling rapid community feature adoption.

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Frontend Layer                               │
│  ┌────────────────────┐  ┌────────────────────────────────┐     │
│  │ Admin Portal MFE   │  │ Learner Portal MFE             │     │
│  │ (enterprise admins)│  │ (enterprise learners)          │     │
│  └────────┬───────────┘  └────────┬───────────────────────┘     │
└───────────┼──────────────────────┼─────────────────────────────┘
            │                      │
            │ REST APIs            │
            ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│              Enterprise Microservices (5 services)              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ enterprise-catalog                                       │   │
│  │ - Content curation (per-tenant catalogs)                 │   │
│  │ - Content metadata sync from LMS                         │   │
│  │ - Catalog queries with filtering                         │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ license-manager                                          │   │
│  │ - License pool CRUD                                      │   │
│  │ - Seat allocation/revocation                             │   │
│  │ - Subscription renewal                                   │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ enterprise-access                                        │   │
│  │ - Access policy evaluation                               │   │
│  │ - Subsidy-based enrollment                               │   │
│  │ - SSO/SAML integration                                   │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ enterprise-subsidy                                       │   │
│  │ - Subsidy ledger management                              │   │
│  │ - Transaction tracking                                   │   │
│  │ - Balance/quota enforcement                              │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ enterprise-integrated-channels                           │   │
│  │ - Data sync to Degreed, Cornerstone, SAP SuccessFactors │   │
│  │ - Completion/progress export                             │   │
│  │ - Webhook receivers for external events                  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
            │                      │
            ▼                      ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ MySQL (Cloud SQL)│  │ Redis Streams    │  │ LMS (Open edX)   │
│ - 5 logical DBs  │  │ - Event bus      │  │ - Enrollment API │
│ - Shared instance│  │ - Celery queue   │  │ - User API       │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

---

## Data Flow

### Enterprise Catalog Query Flow
1. **Admin** logs into enterprise admin portal
2. **Portal MFE** calls `GET /api/v1/enterprise-catalogs/?enterprise_customer={uuid}`
3. **enterprise-catalog** service:
   - Queries MySQL for catalogs with `enterprise_customer_uuid = uuid`
   - Applies content filters (e.g., `content_type=course`, `content_key=course-v1:*`)
   - Enriches with metadata from LMS (course titles, thumbnails)
4. **Response**: JSON array of courses in tenant's catalog
5. **Portal MFE** renders course listing

### License Allocation Flow
1. **Admin** uploads CSV of learner emails via admin portal
2. **Portal MFE** calls `POST /api/v1/subscriptions/{plan-id}/licenses/assign` with email list
3. **license-manager** service:
   - Validates plan has available seats
   - Creates `License` records (status: `allocated`)
   - Emits `LICENSE_ALLOCATED` event to Redis Streams
4. **LMS** consumes event, sends invitation email to learners
5. **Learner** clicks invitation link → auto-redirects to learner portal
6. **Learner Portal MFE** shows "Activate License" button
7. **Learner** activates → `POST /api/v1/licenses/{uuid}/activate`
8. **license-manager** updates license (status: `activated`)
9. **LMS** creates enrollments for all courses in catalog

### Integrated Channel Sync Flow (Degreed Example)
1. **Celery beat** triggers daily sync task: `transmit_learner_data`
2. **enterprise-integrated-channels** service:
   - Queries LMS for completions since last sync
   - Filters by `enterprise_customer_uuid`
   - Transforms to Degreed API format
3. **Service** calls Degreed API: `POST /api/v2/completions`
4. **Degreed** returns 200 OK (or 4xx/5xx on error)
5. **Service** logs sync result, updates `last_sync_timestamp`
6. **On failure**: Retry with exponential backoff (max 3 attempts)

---

## Integration Points

### LMS (Open edX)
- **Enrollment API**: `POST /api/enrollment/v1/enrollment`
- **User API**: `GET /api/user/v1/accounts/{username}`
- **Course API**: `GET /api/courses/v1/courses/{course-id}`
- **Authentication**: OAuth2 service-to-service (JWT tokens)

### MySQL (Cloud SQL)
- **Logical Databases**:
  - `enterprise_catalog`
  - `license_manager`
  - `enterprise_access`
  - `enterprise_subsidy`
  - `integrated_channels`
- **Connection**: Cloud SQL proxy sidecar in each pod

### Redis Streams (Event Bus)
- **Events**:
  - `LICENSE_ALLOCATED` → LMS sends invitation
  - `LICENSE_REVOKED` → LMS revokes enrollments
  - `COURSE_COMPLETED` → Integrated channels sync
  - `ENTERPRISE_CUSTOMER_CREATED` → Provision downstream services

### Third-Party Integrations
- **Degreed**: `POST /api/v2/completions`
- **Cornerstone OnDemand**: `POST /services/api/x/content/completion`
- **SAP SuccessFactors**: `POST /learning/odatav4/public/admin/ocn/v1/CompletionCertificate`
- **Canvas LMS**: `POST /api/v1/users/{user}/courses/{course}/enrollments`

---

## Key Design Decisions

### 1. Deployment: Separate Services vs. Monolith
**Decision**: Deploy as 5 separate K8s Deployments

**Rationale**:
- **Upstream pattern**: Open edX community maintains these as independent repos.
- **Independent scaling**: Can scale `enterprise-catalog` (high traffic) independently from `license-manager`.
- **Fault isolation**: Catalog service outage doesn't affect license allocation.

**Trade-offs**:
- More operational overhead (5 deployments, 5 configs, 5 observability targets).
- Inter-service communication overhead (HTTP requests vs. function calls).

### 2. Database: Shared MySQL vs. Separate Databases
**Decision**: Shared Cloud SQL instance with 5 logical databases

**Rationale**:
- **Cost**: One Cloud SQL instance is cheaper than 5 separate instances.
- **Maintenance**: One backup, one failover, one monitoring config.
- **Performance**: Cloud SQL can handle 5 lightweight workloads easily.

**Trade-offs**:
- Shared connection pool (noisy neighbor risk).
- Cannot tune MySQL per-service (e.g., different cache sizes).

### 3. Event Bus: Redis Streams vs. Kafka
**Decision**: Redis Streams

**Rationale**:
- **Existing infrastructure**: Redis already deployed for Celery task queue.
- **Simplicity**: Redis Streams easier to operate than Kafka (no ZooKeeper).
- **Scale**: Sufficient for expected event volume (1000s events/day, not millions).

**Trade-offs**:
- Limited retention (vs. Kafka's configurable retention).
- No cross-region replication (Redis Streams is local to cluster).

### 4. Multi-Tenancy: Per-Tenant Databases vs. Shared Database
**Decision**: Shared database with `enterprise_customer_uuid` filtering

**Rationale**:
- **Consistency**: Matches LMS's multi-tenancy pattern (same isolation model).
- **Scalability**: 50+ tenants share one database (vs. 50 database instances).
- **Upstream alignment**: Open edX enterprise services designed for shared DB.

**Trade-offs**:
- Requires strict queryset filtering (data leakage risk).
- All tenants affected by database outage (no per-tenant isolation).

### 5. Admin Portal: Custom vs. Upstream MFE
**Decision**: Deploy upstream `frontend-app-admin-portal` MFE

**Rationale**:
- **Zero maintenance**: No forking, automatic upstream feature updates.
- **Community support**: Issues/questions answered by Open edX community.
- **Feature completeness**: Upstream MFE covers 90% of use cases.

**Trade-offs**:
- Cannot customize UI deeply (e.g., cannot rebrand for white-label clients).
- Must wait for upstream for new features (vs. implementing ourselves).

---

## API Contracts

### Enterprise Catalog API
```
GET /api/v1/enterprise-catalogs/?enterprise_customer={uuid}
Response: [
  {
    "uuid": "...",
    "title": "Client Corp Catalog",
    "content_count": 150,
    "content_filter": {"content_type": "course"}
  }
]

GET /api/v1/enterprise-catalogs/{catalog-id}/courses/
Response: [
  {
    "course_id": "course-v1:...",
    "title": "Intro to Python",
    "image_url": "https://...",
    "price": "$99.00"
  }
]
```

### License Manager API
```
POST /api/v1/subscriptions/{plan-id}/licenses/assign
Body: {"emails": ["learner1@client.com", "learner2@client.com"]}
Response: {"assigned": 2, "failed": 0}

GET /api/v1/licenses/?enterprise_customer={uuid}
Response: [
  {
    "uuid": "...",
    "user_email": "learner1@client.com",
    "status": "activated",
    "activation_date": "2024-12-01"
  }
]
```

---

## Performance Targets

| Service | Metric | Target |
|---------|--------|--------|
| enterprise-catalog | Catalog query latency (p95) | <300ms |
| license-manager | License allocation latency (p95) | <2s |
| enterprise-access | Policy evaluation latency (p95) | <100ms |
| enterprise-subsidy | Transaction logging latency (p95) | <500ms |
| integrated-channels | Sync completion (1000 records) | <10 minutes |

---

## Related Specs and ADRs
- **Spec**: `specs/enterprise-microservices_spec.md`
- **Runbook**: `docs/archive/superseded/runbooks/enterprise-services-runbook.md`
- **Architecture**: `docs/architecture/overviews/enterprise-services-overview.md`
- **Multi-Tenancy**: `specs/multi-tenancy-architecture_spec.md`
- **K8s Deployment**: `specs/k8s-deployment_spec.md`
- **Secrets Management**: `specs/secrets-management_spec.md`
