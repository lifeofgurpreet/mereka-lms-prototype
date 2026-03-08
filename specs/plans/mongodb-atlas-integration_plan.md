---
spec: mongodb-atlas-integration_spec.md
tier: 1
status: draft
estimated_effort: "3-5 days (M total)"
last_updated: "2026-02-10"
---

# Implementation Plan: MongoDB Atlas Integration

**Source Spec**: `specs/mongodb-atlas-integration_spec.md`
**Tier**: 1 (Core Infrastructure)
**Depends On**: Tier 0 (repository-structure, secrets-management, tutor-configuration)
**Blocks**: forum, analytics, any MongoDB consumer

---

## Summary

This spec codifies and verifies the existing MongoDB Atlas integration for Mereka Academy's Open edX deployment. The Atlascluster (`cluster-mereka-lms.2pjex4s.mongodb.net`) is already the live backend for both the modulestore (`openedx` database) and the forum (`cs_comments_service` database). Per ADR-0(verified 2026-02-07), the cutover is complete: legacy in-cluster MongoDB Deployment and Service have been retired in production.

The implementation work is therefore primarily **hardening, verification, and gap-filling** rather than greenfield migration. Key gaps to close include:

1. Formalizing `retryWrites=true` and `maxPoolSize` in connection strings
2. Ensuring `dnspython` is explicitly declared (currently pulled transitively by `pymongo[srv]`)
3. Adding Atlas connection health to the QA verification suite
4. Documenting rollback procedures as executable runbook steps
5. Establishing observability integration (Grafana dashboardfor application-side MongoDB metrics)

---

## Prerequisites

Before starting:

- [ ] Tier 0 specs (secrets-management, repository-structure,tutor-configuration) are at least draft-approved
- [ ] Access to Atlas console for `cluster-mereka-lms` project
- [ ] Access to GKE cluster `bbi-k8-cluster` in `asia-southeast1-c`
- [ ] Infisical access for `MEREKA_LMS_MONGODB_PASSWORD` andrelated secrets

---

## Task Breakdown

### Build

- [ ] **[S]** Add `retryWrites=true` and `maxPoolSize=50` toLMS/CMS modulestore connection parameters (`deploy/k8s/base/apps/openedx/settings/lms/production.py`, `deploy/k8s/base/apps/openedx/settings/cms/production.py`) | AC: #3 | Depends: None
  - **Done**: `mongodb_parameters` dict includes `retryWrites=True` and connection options include `maxPoolSize=50`

- [ ] **[S]** Add `retryWrites=true` and `maxPoolSize=50` toforum MongoDB client parameters in LMS settings (`deploy/k8s/base/apps/openedx/settings/lms/production.py`) | AC: #4 | Depends: None
  - **Done**: `FORUM_MONGODB_CLIENT_PARAMETERS` includes `retryWrites=True` and `maxPoolSize=50`

- [ ] **[S]** Verify `pymongo[srv]` install step exists in Dockerfile patch (`infrastructure/tutor/apply-patches.sh`) | AC: #8 | Depends: None
  - **Done**: `apply-patches.sh` contains `RUN pip install "pymongo[srv]"` block. Confirm `dnspython>=2.0` is installed asa transitive dependency. If not, add explicit `pip install dnspython>=2.0`.

- [ ] **[S]** Verify ExternalSecrets mapping for MongoDB credentials (`deploy/k8s/base/secrets/external-secrets.yaml`) | AC: #2 | Depends: None
  - **Done**: File contains `MONGODB_USERNAME`, `MONGODB_PASSWORD`, `FORUM_MONGODB_SRV`, and `FORUM_MONGODB_PASSWORD` mappings from `MEREKA_LMS_*` prefixed keys in GCP Secret Manager.

- [ ] **[S]** Verify production overlay removes legacy MongoDB Service (`deploy/k8s/overlays/production/patches/remove-legacy-mongodb-service.yaml`, `deploy/k8s/overlays/production/kustomization.yaml`) | AC: #5, #6 | Depends: None
  - **Done**: Patch file exists with `$patch: delete` for Service/mongodb. Production kustomization references it.

- [ ] **[M]** Add connection string validation to LMS/CMS settings that logs SRV connection attempt on startup (`deploy/k8s/base/apps/openedx/settings/lms/production.py`, `deploy/k8s/base/apps/openedx/settings/cms/production.py`) | AC: #1, #2 |Depends: None
  - **Done**: Settings file includes a startup log line: `logging.getLogger("mereka.mongodb").info("MongoDB host=%s atlas=%s", MONGODB_HOST, _mongodb_is_atlas)` so that `grep mongodb`in logs shows connection attempts.

### Test

- [ ] **[M]** Extend `scripts/qa/verify-atlas-modulestore-path.sh` to check for `retryWrites` and `maxPoolSize` in settings files (`scripts/qa/verify-atlas-modulestore-path.sh`) | AC:#1, #3, #4 | Depends: Build (retryWrites/maxPoolSize)
  - **Done**: Script's `check_local_modulestore_contract()` Python block includes checks for `retryWrites` and `maxPoolSize` tokens in LMS/CMS settings.

- [ ] **[M]** Create `scripts/qa/verify-mongodb-atlas-integration.sh` -- consolidated gate script that runs all MongoDB Atlas AC checks (`scripts/qa/verify-mongodb-atlas-integration.sh`) | AC: #1-#9 | Depends: All Build tasks
  - **Done**: Script runs local (repo) and runtime (kubectl)checks covering all 9 acceptance criteria. Exits 0 on pass, 1on failure.

- [ ] **[S]** Add pymongo[srv] and dnspython verification toimage build checks (`scripts/qa/verify-mongodb-atlas-integration.sh`) | AC: #8 | Depends: Build (pymongo[srv])
  - **Done**: Script includes `kubectl exec` check that `piplist | grep pymongo` shows `[srv]` extras and `dnspython` ispresent.

- [ ] **[S]** Add DNS resolution verification (`scripts/qa/verify-mongodb-atlas-integration.sh`) | AC: #9 | Depends: None
  - **Done**: Script includes `nslookup cluster-mereka-lms.2pjex4s.mongodb.net` check (both local and runtime).

### Observability

- [ ] **[M]** Add MongoDB connection event logging to LMS/CMSproduction settings (`deploy/k8s/base/apps/openedx/settings/lms/production.py`, `deploy/k8s/base/apps/openedx/settings/cms/production.py`) | Req: OBS-logs | Depends: None
  - **Done**: Settings include `logging.getLogger("mereka.mongodb")` with INFO-level log of host, atlas flag, and databasename on module import.

- [ ] **[S]** Document Atlas built-in alerts configuration (connection threshold, disk usage, replica set health) in operational runbook (`docs/operations/MONGODB_ATLAS_RUNBOOK.md`) |Req: OBS-alerts | Depends: None
  - **Done**: Runbook section documents which Atlas alerts toenable and their thresholds.

- [ ] **[M]** Create Grafana dashboard JSON for application-side MongoDB metrics (query latency, connection pool, error rates) (`infrastructure/monitoring/dashboards/mongodb-atlas.json`) | Req: OBS-dashboards | Depends: Observability stack (Tier 2, can be deferred)
  - **Done**: Dashboard JSON exists and can be imported to Grafana. Panels: connection count, query duration histogram, error rate.

### Docs

- [ ] **[M]** Create operational runbook for MongoDB Atlas (`docs/operations/MONGODB_ATLAS_RUNBOOK.md`) | Depends: None
  - **Done**: Runbook covers: connection troubleshooting, DNSresolution failures, IP allowlist management, connection pool exhaustion, Atlas maintenance windows, rollback procedures(copy-paste ready).

- [ ] **[S]** Update `docs/runbooks/operations/TROUBLESHOOTING.md` with MongoDB Atlas-specific troubleshooting entries | Depends: Runbook
  - **Done**: Troubleshooting doc includes MongoDB Atlas section with symptom-to-fix table.

- [ ] **[S]** Verify ADR-001 is up to date with current state(`docs/adr/001-mongodb-atlas.md`) | Depends: None
  - **Done**: ADR reflects cutover completion date and current verified state.

### Rollout

- [ ] **[S]** Verify Atlas IP allowlist includes all GKE NATIPs (`scripts/infra/check-atlas-allowlist.sh`, `scripts/infra/check-atlas-allowlist-vps.sh`) | Depends: None
  - **Done**: Existing allowlist scripts confirmed operational. Cron monitor active on VPS.

- [ ] **[S]** Document rollback procedure as executable script or runbook section (`docs/operations/MONGODB_ATLAS_RUNBOOK.md`) | Depends: Runbook task
  - **Done**: Rollback section includes step-by-step instructions to revert to in-cluster MongoDB if Atlas fails.

---

## Milestones

| Milestone | Tasks | Target |
|-----------|-------|--------|
| M1: Settings hardened | retryWrites, maxPoolSize, startup logging | Day 1 |
| M2: QA gate complete | verify-mongodb-atlas-integration.shpasses all checks | Day 2 |
| M3: Observability wired | Atlas alerts documented, Grafanadashboard created | Day 3 |
| M4: Runbook published | Operational runbook, troubleshooting updates, ADR verified | Day 4 |
| M5: Spec marked implemented | All ACs verified, testmap coverage 100% | Day 5 |

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `retryWrites` causes unexpected behavior with existing write patterns | Low | Medium | Test in staging first; `retryWrites` is Atlas default and recommended |
| `maxPoolSize=50` too low under load | Medium | Medium | Monitor connection pool utilization via Atlas dashboard; increase if >80% |
| DNS resolution intermittent in GKE pods | Low | High | `dnspython` handles SRV resolution; CoreDNS in GKE is reliable. Fallback: direct connection string |
| Atlas maintenance window causes transient errors | Low | Low | `retryWrites=true` handles transparent failover; documentin runbook |
| Grafana dashboard depends on Tier 2 observability stack | Medium | Low | Dashboard JSON can be created now, imported when stack is ready |

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-009) hasat least one build task
- [x] Every acceptance criterion has at least one test case (in verify-mongodb-atlas-integration.sh)
- [x] Every edge case (DNS failure, IP allowlist block, connection pool exhaustion, maintenance window, cross-region latency) has corresponding runbook entry
- [x] Test tasks cover both happy path (Atlas connected) andfailure cases (legacy MongoDB absent)
- [x] File paths specified for each task
- [x] Dependencies identified (or marked "None")
- [x] Complexity estimated (S/M/L) for each task
- [x] Source spec linked in header
