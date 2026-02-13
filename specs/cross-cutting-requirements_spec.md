---
title: "Cross-Cutting Requirements"
type: "feature_spec"
status: "completed"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
version: "1.0.0"
depends_on: []
links:
  related_docs:
    - "docs/operations/TROUBLESHOOTING.md"
    - "docs/architecture/multi-tenancy-overview.md"
  related_specs:
    - "specs/multi-tenancy-architecture_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/data-privacy-gdpr-compliance_spec.md"
---

# Human Summary

## What we're building
A canonical set of cross-cutting requirements that apply to e
very service, spec, and deployment in the Mereka Academy plat
form. Instead of duplicating tenant isolation, observability,
secrets management, and common NFR thresholds across 26 indi
vidual specs, this document defines them once. Individual spe
cs inherit these requirements and only specify domain-specifi
c overrides.

## Why it matters
Without a single source of truth for cross-cutting concerns,
each spec independently re-states the same requirements with
minor wording differences. This leads to contradictions, make
s auditing impossible, and increases maintenance burden. This
spec is the "constitution" -- if a requirement applies to mo
re than two specs, it belongs here.

## Success looks like
- Every spec references this document instead of restating sh
ared requirements
- Auditors can verify platform-wide compliance by checking on
e document plus domain-specific overrides
- New specs automatically inherit the cross-cutting contract
by adding this spec to their `related_specs`

---

# Agent Contract

## Scope
- Tenant isolation contract (applies to all services handling
tenant data)
- Observability requirements (metrics, logs, traces, dashboar
ds, alerts)
- Secrets management pattern (Infisical → GCP SM → ExternalSe
crets → K8s → env vars)
- Common NFR thresholds (latency, availability, security base
line)
- Tenant offboarding workflow requirements
- Error handling and resilience patterns
- Technology decisions that apply platform-wide

## Non-goals
- Domain-specific requirements (those stay in individual spec
s)
- Implementation details for any specific service
- Overriding domain-specific NFR targets (individual specs ma
y set stricter thresholds)

## Assumptions
- GKE cluster in `mereka-lms` namespace is the deployment tar
get
- Cloud SQL (MySQL 8) is the primary relational database
- MongoDB Atlas (cluster-mereka-lms.2pjex4s.mongodb.net) for
document storage
- Redis (deployed in-cluster) for caching and event bus (Redi
s Streams)
- Infisical at secrets.mereka.io is the secrets source of tru
th
- Open edX Ulmo (v21) is the platform release
- Multi-tenancy uses the shared-everything model with Enterpr
iseCustomer as tenant boundary

---

## Requirements

### 1. Tenant Isolation Contract

Every service, API, and data pipeline in the Mereka Academy p
latform MUST enforce tenant isolation:

- The system MUST use `EnterpriseCustomer.uuid` as the canoni
cal tenant identifier across all services
- The system MUST enforce tenant-scoped queryset filtering at
the Django ORM layer (or equivalent data access layer) for e
very read operation
- The system MUST enforce tenant-scoped permission checks on
every API endpoint that returns tenant data
- The system MUST NOT allow any API response to include data
belonging to a tenant other than the authenticated tenant
- The system MUST log tenant context (`tenant_id`) in every s
tructured log entry for requests touching tenant data
- The system MUST include `tenant_id` as a label/dimension in
all metrics emitted for tenant-scoped operations
- The system MUST support automated tenant isolation verifica
tion tests that attempt cross-tenant access and verify denial
- The system SHOULD support per-tenant rate limiting to preve
nt noisy-neighbor effects

**Tenant Offboarding**:
- The system MUST support complete data export for a tenant w
ithin 7 days of offboarding request
- The system MUST support verifiable data deletion for a tena
nt within 30 days of offboarding confirmation
- The system MUST produce a cryptographic deletion certificat
e upon completion of tenant offboarding
- Each spec that handles tenant data MUST document which data
stores are affected by tenant offboarding

### 2. Observability Requirements

Every service deployed in the `mereka-lms` namespace MUST imp
lement:

**Metrics** (Prometheus):
- The service MUST expose a `/metrics` endpoint (or sidecar)
with Prometheus-format metrics
- The service MUST emit request rate, error rate, and latency
histograms (RED metrics)
- The service MUST emit resource utilization metrics (CPU, me
mory, connections)
- The service SHOULD emit domain-specific business metrics (e
.g., enrollments/sec, payments/sec)
- All metrics MUST include `service`, `tenant_id` (where appl
icable), and `environment` labels

**Logs** (Loki via Promtail):
- The service MUST emit structured JSON logs to stdout/stderr
- Log entries MUST include: timestamp, level, service name, r
equest_id, tenant_id (where applicable)
- The service MUST NOT log PII (emails, names, passwords) at
INFO level or below
- PII in DEBUG logs MUST be masked or redacted
- Log retention: 30 days hot (Loki), 90 days cold (GCS archiv
e)

**Traces** (Tempo via OpenTelemetry):
- The service SHOULD emit distributed traces via OTLP (gRPC p
ort 4317 or HTTP port 4318)
- Trace spans MUST propagate the `traceparent` header across
service boundaries
- Trace sampling: 10% for normal traffic, 100% for error resp
onses

**Dashboards** (Grafana):
- Each service MUST have a Grafana dashboard showing RED metr
ics, error breakdown, and resource utilization
- Enterprise-facing dashboards MUST support tenant filtering

**Alerts**:
- Each service MUST define alerts for: error rate > 5% sustai
ned for 5 minutes, p95 latency > 2x target for 10 minutes, po
d restart count > 3 in 15 minutes
- Critical alerts MUST route to PagerDuty/Slack `#ops-alerts`
- Warning alerts MUST route to Slack `#ops-warnings`

### 3. Secrets Management Pattern

All services MUST follow the established secrets pipeline:

```
Infisical (source of truth) → GCP Secret Manager → ExternalSe
crets Operator → K8s Secrets → Pod env vars
```

- All secrets MUST be prefixed with `MEREKA_LMS_` in Infisica
l and GCP Secret Manager
- Application code MUST consume secrets via `os.environ.get()
` (Python) or equivalent environment variable access
- NEVER hardcode secrets in source code, Docker images, or He
lm values
- ExternalSecrets sync interval: 1 hour (configurable per sec
ret for high-frequency rotation)
- Secret rotation MUST complete end-to-end (Infisical to runn
ing pods) in under 30 minutes with zero downtime
- Pre-commit hooks MUST scan for hardcoded secrets before eve
ry commit
- CI pipelines MUST include secret scanning as a blocking che
ck

### 4. Common NFR Thresholds

These are platform-wide defaults. Individual specs MAY set st
ricter thresholds but MUST NOT relax them without documented
justification.

**Availability**:
- Production services: >= 99.9% monthly uptime (43 min downti
me/month max)
- Maintenance windows: scheduled, communicated 48 hours in ad
vance, max 2 hours

**Latency**:
- API responses: p95 < 500ms, p99 < 2000ms (individual specs
may set stricter targets)
- Page loads (LMS): p95 < 3 seconds
- Webhook processing: p95 < 5 seconds end-to-end

**Security**:
- All external traffic MUST use TLS 1.2+ (TLS 1.3 preferred)
- All internal service-to-service communication SHOULD use mT
LS or network policies
- Authentication: OAuth2/JWT for API access, session cookies
for browser access
- Authorization: role-based (RBAC) with tenant-scoped permiss
ions
- Input validation: all user input MUST be validated at the A
PI boundary
- OWASP Top 10 mitigations MUST be verified for every new ser
vice

**Resilience**:
- All services MUST implement health check endpoints (`/healt
hz` for liveness, `/readyz` for readiness)
- All services MUST handle graceful shutdown (SIGTERM with 30
-second drain period)
- All services SHOULD implement circuit breakers for external
dependencies
- All services MUST define resource requests and limits in K8
s manifests
- All database operations MUST use connection pooling

**Data Integrity**:
- All write operations to financial data MUST be idempotent
- All async job processing MUST implement at-least-once deliv
ery with deduplication
- Database migrations MUST be backward-compatible (no breakin
g schema changes without feature flags)

### 5. Technology Decisions (Platform-Wide)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Event bus | Redis Streams | Already deployed, sufficient fo
r current scale, simpler operations |
| Relational DB (platform) | MySQL 8 (Cloud SQL) | Open edX s
tandard, existing infrastructure |
| Relational DB (new services) | PostgreSQL (Cloud SQL) | Bet
ter for financial data, JSON support, available in cluster |
| Document DB | MongoDB Atlas | Zero maintenance, automatic b
ackups, managed scaling |
| Cache / Queue | Redis (in-cluster) | Caching, Celery broker
, event bus (Redis Streams) |
| Container registry | Artifact Registry (asia-southeast1) |
GCP-native, low latency |
| Secrets | Infisical → GCP SM → ExternalSecrets | Establishe
d pipeline, auditable |
| Observability | Prometheus + Loki + Tempo + Grafana | Deplo
yed on VPS, battle-tested |
| CI/CD | GitHub Actions + ArgoCD | GitOps model, declarative
|
| Search (forum) | Meilisearch | Lightweight, already deploye
d for forum v2 |

### 6. Error Handling and Resilience Patterns

- The system MUST NOT silently swallow exceptions (empty catc
h blocks are forbidden)
- All error responses MUST include a machine-readable error c
ode and human-readable message
- All error responses MUST NOT leak internal implementation d
etails (stack traces, SQL queries, file paths) to external ca
llers
- Background job failures MUST be logged with full context an
d retried with exponential backoff
- Circuit breakers MUST log state transitions (open/half-open
/closed)
- All services MUST implement structured error logging with:
error code, error message, stack trace (internal), request co
ntext, tenant context

### 7. Acceptance Criteria Naming Standard

All specs MUST use prefixed AC identifiers to enable unambiguous cross-spec references:

**Format**: `AC-{PREFIX}-{NNN}` where:
- `{PREFIX}` is a 2-5 character spec abbreviation (e.g., CCR for cross-cutting, K8S for k8s-deployment, AUTH for auth-sso)
- `{NNN}` is a zero-padded 3-digit sequential number within the spec

**Prefix Registry**:

| Spec | Prefix | Example |
|------|--------|---------|
| cross-cutting-requirements | CCR | AC-CCR-001 |
| k8s-deployment | K8S | AC-K8S-001 |
| secrets-management | SEC | AC-SEC-001 |
| tutor-configuration | TUT | AC-TUT-001 |
| multi-tenancy-architecture | MTA | AC-MTA-001 |
| auth-sso-enterprise | AUTH | AC-AUTH-001 |
| ci-cd-pipeline | CICD | AC-CICD-001 |
| enterprise-microservices | ENT | AC-ENT-001 |
| ecommerce-purchase-gateway | ECOM | AC-ECOM-001 |
| forum-service-migration | FRM | AC-FRM-001 |
| video-pipeline-delivery | VPD | AC-VPD-001 |
| observability-stack | OBS | AC-OBS-001 |
| branding-system | BRD | AC-BRD-001 |
| email-notifications-pipeline | EML | AC-EML-001 |
| badges-credentials-enterprise | BCR | AC-BCR-001 |
| mobile-apps-enterprise | MOB | AC-MOB-001 |
| content-libraries-v2 | LIB | AC-LIB-001 |
| advanced-assessment-xqueue | AXQ | AC-AXQ-001 |
| data-migrations-kajabi-mct | MIG | AC-MIG-001 |
| data-privacy-gdpr-compliance | DPR | AC-DPR-001 |
| proctoring-integration | PRO | AC-PRO-001 |
| slo-sla-service-level-management | SLO | AC-SLO-001 |
| disaster-recovery-business-continuity | DRC | AC-DRC-001 |
| design-tokens-system | DTS | AC-DTS-001 |
| external-registration-hubspot | HUB | AC-HUB-001 |
| multi-site-domains | MSD | AC-MSD-001 |
| analytics-pipeline | APL | AC-APL-001 |
| mongodb-atlas-integration | MAI | AC-MAI-001 |
| repository-structure | REP | AC-REP-001 |
| platform-middleware-custom-apps | PMW | AC-PMW-001 |
| tutor-configuration-resilience | TCR | AC-TCR-001 |

**Cross-spec references** MUST use the full prefixed ID: "see AC-MTA-003 in multi-tenancy-architecture_spec.md".

### 8. Spec Versioning Standard

All specs MUST include a `version` field in YAML frontmatter using semantic versioning:

```yaml
version: "1.0.0"
```

- **Major** (X.0.0): Breaking changes to requirements, ACs removed or fundamentally changed
- **Minor** (1.X.0): New requirements or ACs added, non-breaking changes
- **Patch** (1.0.X): Typo fixes, clarifications, resolved open questions

The `last_updated` field records when, `version` records what changed.

### 9. Feature Flag Management Pattern

All feature flags across the platform MUST follow this standard:

**Naming Convention**:
- Prefix: `ENABLE_` for boolean flags, `{DOMAIN}_` for domain-specific flags
- Format: `ENABLE_{DOMAIN}_{FEATURE}` (e.g., `ENABLE_ORA2_FILE_UPLOADS`, `ENABLE_GATEWAY_FULFILLMENT`)
- All uppercase with underscores

**Implementation Mechanism** (in priority order):
1. **Django Waffle flags** (preferred): Toggleable via Django admin without restart. Use for per-tenant and gradual rollout flags.
2. **Open edX FEATURES dict**: Set via Tutor config (`tutor config save --set FEATURES_ENABLE_X=true`). Requires pod restart.
3. **Environment variables**: Set via ExternalSecrets or ConfigMap. Requires pod restart.

**Default Values**:
- New features MUST default to `off` (disabled) in production
- Established features MUST default to `on` (enabled)
- Each spec MUST document the default value and rationale for each flag

**Per-Tenant Overridability**:
- Flags that affect tenant-visible behavior SHOULD be configurable per `enterprise_customer_uuid` via Waffle flag overrides
- Flags that affect infrastructure (CI/CD, deployment, monitoring) are global only
- Each spec MUST document whether each flag is global or per-tenant

**Rolling Update Behavior**:
- Waffle flags: Take effect immediately without restart (hot toggle)
- FEATURES dict / env vars: Take effect on next pod restart; during rolling update, old and new pods may have different flag states
- Feature flag changes MUST NOT corrupt data: disabling a flag hides UI but preserves existing data
- Mixed flag states during rolling updates MUST NOT cause errors (both true and false must be safe concurrently)

**Feature Flag Registry**:
Each spec maintains its own feature flag list in a `### Feature Flags` subsection of Rollout & Rollback. The canonical list of all platform flags is generated by aggregating these sections.

---

### Non-Functional Requirements

(This section intentionally references back to Section 4 "Common NFR Thresholds" above. Individual specs define domain-specific NFRs that override or extend these baselines.)

---

## Acceptance Criteria

- [ ] AC-CCR-001: Given any API endpoint that returns tenant
data, when a request is made with tenant A's credentials, the
n the response MUST contain zero records belonging to any oth
er tenant
- [ ] AC-CCR-002: Given any service deployed in the mereka-lm
s namespace, when the service is running, then it MUST expose
Prometheus metrics at /metrics (or via sidecar)
- [ ] AC-CCR-003: Given any service deployed in the mereka-lm
s namespace, when the service emits logs, then all log entrie
s MUST be structured JSON with timestamp, level, service, and
request_id fields
- [ ] AC-CCR-004: Given any secret consumed by a service, whe
n the secret is accessed, then it MUST be read from an enviro
nment variable (not hardcoded, not from a config file committ
ed to git)
- [ ] AC-CCR-005: Given the pre-commit hook is installed, whe
n a developer attempts to commit a file containing a hardcode
d secret pattern, then the commit MUST be rejected
- [ ] AC-CCR-006: Given any production API endpoint, when mea
sured over a 30-day window, then p95 latency MUST be below 50
0ms and availability MUST be >= 99.9%
- [ ] AC-CCR-007: Given a tenant offboarding request, when th
e offboarding process completes, then a cryptographic deletio
n certificate MUST be produced listing all data stores from w
hich tenant data was removed
- [ ] AC-CCR-008: Given any service receiving external traffi
c, when a TLS handshake is initiated, then the service MUST n
egotiate TLS 1.2 or higher
- [ ] AC-CCR-009: Given any new service being deployed, when
the K8s manifest is reviewed, then it MUST include resource r
equests, resource limits, liveness probe, and readiness probe
- [ ] AC-CCR-010: Given any write operation to financial data
(payments, refunds, entitlements), when the operation is exe
cuted, then it MUST be idempotent (re-execution produces the
same result)
- [ ] AC-CCR-011: Given any background job failure, when the
failure is logged, then the log entry MUST include error code
, error message, full context (job ID, tenant ID, input param
eters), and stack trace
- [ ] AC-CCR-012: Given a Redis Streams event is published, w
hen a consumer processes the event, then it MUST implement id
empotent handling with deduplication by event ID

---

## Edge Cases

1. **Tenant isolation bypass via URL manipulation**: Direct o
bject reference attacks where a user modifies a UUID in a URL
to access another tenant's resource. Mitigation: all queryse
t filters must include tenant_id, not rely solely on object U
UIDs.

2. **Secret rotation during active requests**: A secret rotat
es while requests are in-flight using the old secret value. M
itigation: services must support both old and new secret valu
es during a configurable overlap window (default: 5 minutes).

3. **Observability data as PII vector**: Structured logs, met
rics labels, or trace attributes inadvertently contain PII (e
.g., user email in a log message). Mitigation: PII scrubbing
rules in Promtail config and code review checklists.

4. **Cross-tenant metric pollution**: A metric query without
tenant_id filter aggregates data across tenants, exposing rel
ative usage patterns. Mitigation: Grafana dashboards must def
ault to tenant-filtered views; aggregate views restricted to
platform admins.

5. **Event bus message ordering**: Redis Streams guarantees o
rdering within a single stream, but consumers processing even
ts from multiple streams may observe out-of-order events. Mit
igation: consumers must handle out-of-order events gracefully
(use event timestamps, not processing order).

6. **Cascading failure from shared infrastructure**: A MySQL
connection pool exhaustion in one service causes connection f
ailures in all services sharing the same Cloud SQL instance.
Mitigation: per-service connection limits, circuit breakers,
and independent connection pools.

---

## Observability

(This spec defines the observability requirements for all oth
er specs. The observability section here covers how to verify
these cross-cutting requirements themselves.)

### Metrics
- `cross_cutting_compliance_score` gauge: percentage of servi
ces meeting all cross-cutting requirements (target: 100%)
- `tenant_isolation_test_failures` counter: number of automat
ed tenant isolation test failures (target: 0)
- `secret_scan_violations` counter: number of hardcoded secre
t detections in CI (target: 0)

### Alerts
- Alert if any service in mereka-lms namespace lacks a /metri
cs endpoint for > 1 hour
- Alert if tenant isolation test suite reports any failure
- Alert if secret scanning CI check fails on main branch

### Dashboards
- Platform compliance dashboard showing per-service adherence
to cross-cutting requirements
- Tenant isolation test results dashboard

---

## Rollout & Rollback

### Rollout Plan
1. Publish this spec and gain team consensus
2. Update all 26 specs to reference this document in their `r
elated_specs`
3. Implement automated compliance checks (CI workflow that ve
rifies cross-cutting requirements)
4. Progressively enforce requirements as services are deploye
d or updated

### Feature Flags
- No feature flags needed -- these are requirements, not feat
ures

### Backward Compatibility
- Existing services that do not yet meet all requirements are
grandfathered with a compliance timeline
- New services MUST meet all requirements before production d
eployment

### Rollback Steps
- Requirements are additive -- no rollback needed
- If a requirement proves infeasible, update this spec with d
ocumented justification for relaxation

---

## Open Questions

1. ~~Should per-tenant rate limiting be a MUST or SHOULD?~~ **RESOLVED**: Keep as SHOULD for v1. Upgrade to MUST once traffic patterns from first 3 enterprise clients are measured (target: Q3 2026).
2. ~~What is the compliance timeline for existing services to meet all cross-cutting requirements?~~ **RESOLVED**: 90 days from spec approval. Already-deployed services (LMS, Studio, Forum) get 180-day remediation window for non-critical items.
3. ~~Should mTLS between services be mandatory or recommended?~~ **RESOLVED**: Keep as SHOULD. GKE Network Policies provide namespace-level isolation. mTLS adds complexity with minimal gain for single-cluster. Revisit for multi-cluster.
4. ~~What is the retention policy for tenant offboarding deletion certificates?~~ **RESOLVED**: 7 years for regulatory compliance (Malaysia PDPA + potential EU GDPR). Store in GCS with lifecycle policy.
5. Should we define a standard error code taxonomy across all services? **STATUS**: Deferred to post-v1. Not blocking any current implementation.
6. ~~What is the maximum number of concurrent tenants the shared-everything model must support?~~ **RESOLVED**: 50 tenants as defined in multi-tenancy-architecture_spec.md.
