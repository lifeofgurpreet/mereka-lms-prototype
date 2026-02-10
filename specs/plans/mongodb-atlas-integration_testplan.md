---
spec: mongodb-atlas-integration_spec.md
tier: 1
status: draft
last_updated: "2026-02-10"
---

# Test Plan: MongoDB Atlas Integration

**Source Spec**: `specs/mongodb-atlas-integration_spec.md`

---

## Test Framework

This project uses **shell verification scripts** (`scripts/qa/verify-*.sh`, `scripts/qa/audit-*.sh`) as the primary test infrastructure. There is no pytest/vitest/jest setup for infrastructure specs. Tests are organized as:

| Test Type | Tool | Location |
|-----------|------|----------|
| `shell_verification` | Bash scripts (repo-local checks) | `scripts/qa/verify-*.sh` |
| `kubectl_check` | kubectl commands (runtime checks) | Inline in verification scripts |
| `manual_verification` | Human checklist | Documented belowwith justification |

---

## Test Matrix

### Acceptance Criteria Tests

| AC # | Test Case | Type | File / Command | Mocks/Fixtures |
|------|-----------|------|----------------|----------------|
| AC-001 | LMS logs show SRV connection attempts (`grep mongodb` in logs) | `kubectl_check` | `scripts/qa/verify-mongodb-atlas-integration.sh` | Live LMS pod logs |
| AC-002 | K8s LMS pod logs contain "Connected to MongoDB" oratlas host reference | `kubectl_check` | `scripts/qa/verify-mongodb-atlas-integration.sh` | Live LMS pod |
| AC-003 | Course creation in Studio persists to Atlas `openedx` database | `manual_verification` | `docs/operations/MONGODB_ATLAS_RUNBOOK.md` section "Verify Data Persistence" | Atlas console or mongosh |
| AC-004 | Forum posts persist to Atlas `cs_comments_service`database | `manual_verification` | `docs/operations/MONGODB_ATLAS_RUNBOOK.md` section "Verify Data Persistence" | Atlas console or mongosh |
| AC-005 | No local MongoDB container exists (local): `dockerps \| grep mongodb` returns nothing | `shell_verification` |`scripts/qa/verify-mongodb-atlas-integration.sh --mode local` | None (checks Docker) |
| AC-006 | No MongoDB StatefulSet/Deployment exists in K8s |`kubectl_check` | `scripts/qa/verify-mongodb-atlas-integration.sh --mode runtime` | Live GKE cluster |
| AC-006 | Production overlay includes `remove-legacy-mongodb-service.yaml` patch | `shell_verification` | `scripts/qa/verify-atlas-modulestore-path.sh --mode local` | Repo files only|
| AC-007 | Atlas cluster shows active connections in monitoring dashboard | `manual_verification` | Atlas console > Metrics > Connections | Atlas dashboard |
| AC-008 | `pymongo[srv]` installed in LMS pod: `pip list \|grep pymongo` shows extras | `kubectl_check` | `scripts/qa/verify-mongodb-atlas-integration.sh --mode runtime` | Live LMSpod |
| AC-008 | `dnspython>=2.0` installed in LMS pod | `kubectl_check` | `scripts/qa/verify-mongodb-atlas-integration.sh --mode runtime` | Live LMS pod |
| AC-009 | DNS resolution succeeds: `nslookup cluster-mereka-lms.2pjex4s.mongodb.net` returns results | `shell_verification` | `scripts/qa/verify-mongodb-atlas-integration.sh` | DNS resolver |

### Requirement Verification Tests

| Req | Test Case | Type | File / Command |
|-----|-----------|------|----------------|
| SRV connection string format | LMS/CMS settings contain `mongodb+srv://` detection logic and `ssl: bool(_mongodb_is_atlas)` | `shell_verification` | `scripts/qa/verify-atlas-modulestore-path.sh --mode local` |
| `retryWrites=true` | LMS/CMS settings include `retryWrites`in connection parameters | `shell_verification` | `scripts/qa/verify-mongodb-atlas-integration.sh --mode local` |
| `maxPoolSize=50` | LMS/CMS settings include `maxPoolSize` in connection parameters | `shell_verification` | `scripts/qa/verify-mongodb-atlas-integration.sh --mode local` |
| ExternalSecrets mapping | `external-secrets.yaml` maps `MONGODB_PASSWORD`, `MONGODB_USERNAME`, `FORUM_MONGODB_SRV` | `shell_verification` | `scripts/qa/verify-atlas-modulestore-path.sh --mode local` |
| No hardcoded passwords | Settings use `os.environ.get()` for all MongoDB credentials | `shell_verification` | `scripts/qa/verify-mongodb-atlas-integration.sh --mode local` |
| `pymongo[srv]` in Dockerfile | `apply-patches.sh` includes`pip install "pymongo[srv]"` | `shell_verification` | `scripts/qa/verify-mongodb-atlas-integration.sh --mode local` |
| IP allowlist | GKE NAT IPs are in Atlas IP allowlist (not 0.0.0.0/0) | `shell_verification` | `scripts/qa/audit-atlas-allowlist-monitor.sh` |

### Edge Case / Negative Tests

| Edge Case | Test Case | Type | File / Command |
|-----------|-----------|------|----------------|
| EC-1: DNS resolution failure | Verify `dnspython` is installed; simulate missing package check | `kubectl_check` | `scripts/qa/verify-mongodb-atlas-integration.sh --mode runtime` |
| EC-2: IP allowlist block | Verify GKE NAT IPs are in allowlist; monitor for drift | `shell_verification` | `scripts/qa/audit-atlas-allowlist-monitor.sh` |
| EC-3: Connection pool exhaustion | Verify `maxPoolSize` isconfigured; document recovery in runbook | `shell_verification` + `manual_verification` | `scripts/qa/verify-mongodb-atlas-integration.sh` + `docs/operations/MONGODB_ATLAS_RUNBOOK.md`|
| EC-4: Atlas maintenance window | Verify `retryWrites=true`is configured (transparent failover) | `shell_verification` |`scripts/qa/verify-mongodb-atlas-integration.sh --mode local` |
| EC-5: Cross-region latency | Verify Atlas cluster region matches GKE region (manual check) | `manual_verification` | Atlas console > Cluster > Region |
| EC-6: Legacy MongoDB regression | Verify no local MongoDB deployment or service exists after changes | `kubectl_check` |`scripts/qa/verify-atlas-modulestore-path.sh --mode runtime`(with `FAIL_ON_LEGACY_MONGODB=1`) |

### NFR Verification

| NFR | Test Case | Type | File / Command |
|-----|-----------|------|----------------|
| p95 read latency <= 100ms | Monitor via Atlas Performance Advisor | `manual_verification` | Atlas console > Performance|
| p95 write latency <= 500ms | Monitor via Atlas PerformanceAdvisor | `manual_verification` | Atlas console > Performance|
| Connection time <= 2s | Verify SRV resolution + connectionvia `pymongo` test script | `manual_verification` | `docs/operations/MONGODB_ATLAS_RUNBOOK.md` section "Latency Verification" |
| 99.95% uptime | Atlas M10+ SLA (managed by Atlas) | `manual_verification` | Atlas SLA documentation |
| TLS 1.2+ enforced | Verify `ssl=True` in settings when Atlas detected | `shell_verification` | `scripts/qa/verify-atlas-modulestore-path.sh --mode local` |
| Data at rest encryption | Atlas default (managed by Atlas)| `manual_verification` | Atlas security settings |

---

## Existing Verification Scripts

These scripts already exist and cover significant portions ofthe test matrix:

| Script | Purpose | ACs Covered |
|--------|---------|-------------|
| `scripts/qa/verify-atlas-modulestore-path.sh` | Verifies deployment contracts, settings tokens, ExternalSecrets mapping,legacy MongoDB removal | AC-001, AC-002, AC-005, AC-006 |
| `scripts/qa/audit-atlas-allowlist-monitor.sh` | Audits Atlas IP allowlist monitoring (cron, freshness, drift) | EC-2 (IPallowlist) |
| `scripts/qa/check-atlas-allowlist.sh` (via infra scripts) |Direct allowlist verification | EC-2 |

---

## New Verification Script: `scripts/qa/verify-mongodb-atlas-integration.sh`

This consolidated script covers the full AC matrix. It delegates to `verify-atlas-modulestore-path.sh` for overlapping checks and adds:

1. **Local mode** (`--mode local`): Repo-only checks (no cluster access needed)
   - `retryWrites=true` in settings
   - `maxPoolSize=50` in settings
   - `pymongo[srv]` in apply-patches.sh
   - DNS resolution of Atlas cluster hostname
   - No hardcoded MongoDB passwords

2. **Runtime mode** (`--mode runtime`): Requires kubectl access to GKE
   - `pymongo[srv]` installed in LMS pod
   - `dnspython` installed in LMS pod
   - LMS logs contain Atlas connection references
   - No legacy MongoDB deployment or service
   - LMS/CMS MONGODB_HOST resolves to Atlas

3. **All mode** (`--mode all`): Both local and runtime checks(default)

---

## Manual Verification Procedures

### AC-003: Course creation persists to Atlas

**Justification**: Requires end-to-end interaction with Studio UI and verification against Atlas data. Cannot be reliablyautomated without a full E2E browser test framework.

**Steps**:
1. Log into Studio (`https://studio.academyv2.mereka.io`)
2. Create a test course (or edit an existing course)
3. Open Atlas console > Browse Collections > `openedx` database
4. Verify the course document exists with the expected courseID

### AC-004: Forum posts persist to Atlas

**Justification**: Requires end-to-end interaction with the discussions MFE and verification against Atlas data.

**Steps**:
1. Log into LMS (`https://academyv2.mereka.io`)
2. Navigate to a course with discussions enabled
3. Create a test forum post
4. Open Atlas console > Browse Collections > `cs_comments_service` database
5. Verify the post document exists

### AC-007: Atlas shows active connections

**Justification**: Requires Atlas console access which cannotbe scripted without Atlas API credentials.

**Steps**:
1. Open Atlas console > Project > Cluster > Metrics
2. Verify "Connections" panel shows active connections > 0
3. Verify no authentication errors in the log

---

## Execution

```bash
# Run all local (repo) checks
./scripts/qa/verify-mongodb-atlas-integration.sh --mode local

# Run all runtime (kubectl) checks
./scripts/qa/verify-mongodb-atlas-integration.sh --mode runtime

# Run everything
./scripts/qa/verify-mongodb-atlas-integration.sh --mode all

# Run existing modulestore path verification
./scripts/qa/verify-atlas-modulestore-path.sh --mode all

# Run Atlas allowlist audit
./scripts/qa/audit-atlas-allowlist-monitor.sh
```

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-009) hasat least one test case
- [x] Edge cases from spec (DNS failure, IP allowlist, connection pool, maintenance, latency) have test cases
- [x] Test type (shell_verification / kubectl_check / manual_verification) is appropriate for each test
- [x] Manual tests have justification for why they cannot beautomated
- [x] Existing verification scripts referenced (not duplicated)
- [x] Source spec linked in header
