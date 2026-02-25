# Deployment Parity Tracker-to-AC Matrix

**Date:** 2026-02-25
**Scope:** Non-production parity (local/rke2-nonprod), production rollout readiness, and spec/AC closure for implementer handoff

## 0) Data used

- Tracker source: `.beads/beads.db`
- AC source files:
  - `specs/testmaps/ci-cd-pipeline_spec.testmap.yml`
  - `specs/testmaps/k8s-deployment_spec.testmap.yml`
  - `specs/testmaps/analytics-pipeline_spec.testmap.yml`
  - `specs/testmaps/email-notifications-pipeline_spec.testmap.yml`
  - `specs/testmaps/enterprise-microservices_spec.testmap.yml`
- Legacy evidence files checked:
  - `docs/qa/SPEC_AC_GAP_REPORT.md`
  - `docs/qa/DEPLOYMENT_CRITICAL_GAP_REPORT.md`

> Note: `DEPLOYMENT_CRITICAL_GAP_REPORT.md` is dated `2026-02-18` and shows higher unmapped counts; current testmap-based coverage is newer/stronger but still shows many `manual` acceptance criteria that are explicitly blocked on unimplemented behavior.

## 1) Current open/in-progress tracker surface

### In-progress
- `mereka-lms-5ngf` — RKE2 LMS migration completion plan
- `mereka-lms-3bm2` — rke2: resolve Argo app health stale Degraded with fully synced resources
- `mereka-lms-1jsy` — RKE2 nonprod: fix ecommerce-worker CrashLoop + payments-gateway parity
- `mereka-lms-2s47` — fix-mfe-dockerfile-ulmo-migration
- `mereka-lms-1kwf` — brand/plugin parity lane (footer, studio, service surfaces)
- `mereka-lms-3st7` — RKE2 end-to-end rollout lane final hardening/hand-off
- `mereka-lms-5ngf.2` — RKE2: validate LMS on rke2-nonprod smoke, routing, and cutover readiness
- `mereka-lms-288f` — RKE2 nonprod smoke and tenant route matrix
- `mereka-lms-bims` — preview.academyv2.mereka.io /dashboard redirect (branding routing)
- `mereka-lms-1bdm` — Video pipeline epic (spec-only completion flow)
- `mereka-lms-i8lo` — Proctoring epic
- `mereka-lms-mci9` — Mobile epic

### Open
- `mereka-lms-1kwf.1` — Footer parity into LMS/MFEs
- `mereka-lms-aza7` — RKE2 operational hardening and deployment pipeline

### Relevant dependency edges (from local tracker graph)
- `20eb` is a common parent for `5ngf.2`, `288f`, and `aza7`
- `5ngf` blocks/parents `5ngf.2` and `288f`
- `288f` is a hardening dependency for `3st7` and `aza7`

## 2) AC completeness matrix (strictly to tracker IDs)

## Track A — CI/CD pipeline ACs and existing tracker ownership

| AC ID | AC status in testmap | Why this is currently risky | Existing tracker coverage | Recommended handling |
|---|---|---|---|---|
| AC-INT-001 | Manual (CI/CD integration + manifests+push validation) | Requires live pipeline + artifact/Argo validation path | Partial: `mereka-lms-3bm2` | Add explicit subtask: `mereka-lms-3bm2` -> CI manifest/Artifact/Argo success evidence |
| AC-INT-002 | Manual (`ExternalSecrets` sync gate), not implemented in CI step | No CI gate yet for SecretSynced; manual operator check currently | Partial: `mereka-lms-3bm2` | Add dedicated child issue for CI sync gate + test evidence |
| AC-INT-003 | Manual (`infisical-validate-mereka-lms.sh`) manual gating | Requires CI integration of existing validation script | Partial: `mereka-lms-3bm2` | Add explicit evidence issue under `mereka-lms-3bm2` |
| AC-INT-004 | Manual (`branding-preflight.sh`) | Requires image build path + pipeline coverage | Partial: `mereka-lms-3bm2` | Add dedicated child issue for branding preflight in CI |
| AC-003 | Manual (ruff validation requires CI runtime) | In CI environment control and runner availability | None | Link to `mereka-lms-5ngf` as pre-release hardening task |
| AC-004 | Manual (kubeconform validation requires CI runner/runner context) | Live validation environment requirement | None | Link to `mereka-lms-3bm2` |

## Track B — K8s deployment ACs and non-prod parity hardening

| AC ID | AC status in testmap | Why this is still a gap for parity claims | Existing tracker coverage | Recommended handling |
|---|---|---|---|---|
| AC-INT-001 | Manual (secrets + running pods check) | Requires live cluster/secret-sync evidence (non-prod and prod parity) | `mereka-lms-5ngf.2`, `mereka-lms-288f`, `mereka-lms-aza7` | Add explicit checklist issue and attach runtime logs per overlay |
| AC-INT-002 | Manual (env value from SecretSynced) | Requires kubectl env inspection in cluster | `mereka-lms-1jsy`, `mereka-lms-288f`, `mereka-lms-aza7` | Add as dedicated subtask under `mereka-lms-aza7` |
| AC-INT-003 | Manual (rotation propagation within 1h) | Requires time-bound secret rotation drill and post-verification | None | Add dedicated `k8s` drill issue under `mereka-lms-5ngf` |
| AC-INT-004 | Manual (MySQL native password flag + LMS connectivity) | Runtime DB config/behavior check | `mereka-lms-5ngf`, `mereka-lms-1jsy` | Map to hardening stream (`mereka-lms-5ngf`) |
| AC-INT-005 | Manual (`ALLOWED_HOSTS` includes tenant domains) | Requires live LMS `kubectl exec` runtime verify | `mereka-lms-5ngf`, `mereka-lms-288f` | Add specific issue for domain contract verification |

## Track C — Email notifications pipeline ACs (major implementation gap)

All of these ACs are listed in `email-notifications-pipeline_spec.testmap.yml` and are explicitly marked as **feature not yet implemented**.

### AC IDs currently blocked (41)
- `AC-003, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020, AC-021, AC-022, AC-023, AC-024, AC-025, AC-026, AC-027, AC-028, AC-029, AC-030, AC-031, AC-032, AC-033, AC-034, AC-035, AC-037, AC-038, AC-039, AC-040, AC-041, AC-042, AC-043, AC-044, AC-045`

### Current tracker coverage
- No active open tracker explicitly maps these ACs.
- Related historical tickets are closed (`2t3y`, `2t3y.*`, `2ecg`, etc.) and do not represent current executable backlog.

### Action
- Create one parent issue and split 41 ACs into manageable delivery slices (e.g., infra, ACE transport, preferences, push/failover, tenant isolation, alerts/compliance).
- Suggested parent: `mereka-lms-2t3y` equivalent pattern, new status open, with children per AC or per cluster of ACs.
- This is the largest user-visible non-production parity blocker for “feature parity” even if ACs exist in testmaps.

## Track D — Analytics / enterprise services

### Analytics pipeline
- ACs `AC-001` to `AC-008` are mapped in testmap and currently have verification entries.
- No active tracker is explicitly dedicated to analytics parity drift closure as of this pass.
- Legacy analytics decisions exist in closed items (`2ecg`, `2aze*`), but there is no active open issue ensuring current parity state.
- Recommendation: add one tracking issue for live Aspects parity and reference the existing Aspects deployment/monitoring scripts (if/when intended for active non-prod).

### Enterprise microservices
- ACs are generally mapped in testmap and automated-heavy.
- `AC-037` is manual-only (logging assertion requiring runtime enterprise-subsidy behavior).
- No active open tracker dedicated to unresolved enterprise runtime parity issues; only legacy `in_progress` and historical `closed` entries.

## 3) Tracker-to-AC gap list (highest priority first)

1. **`mereka-lms-aza7` + `mereka-lms-3st7` + `mereka-lms-5ngf` chain**
   - Should explicitly own AC-INT items from CI/K8s where manual integration evidence is missing.
2. **Email notification AC burst (`email-notifications-pipeline_spec`, AC-003..045)**
   - Requires end-to-end pipeline implementation and parity verification before release-readiness claims.
3. **`mereka-lms-3bm2`**
   - Closest fit for CI integration reliability ACs (especially `AC-INT-001` through `AC-INT-004`).
4. **`mereka-lms-5ngf.2`, `mereka-lms-288f`**
   - Closest fit for non-prod parity smoke/tenant matrix and routing checks aligned with AC-INT-001/002/005 risk set.

## 4) Suggested deliverable tickets for implementer handoff

Create these if not already present:

- `DEPLOY-OPR-001`: Track CI pipeline contract completion for `ci-cd-pipeline_spec` AC-INT-001..004 + AC-003..004
- `DEPLOY-NONPROD-001`: Track non-prod + prod parity evidence for `k8s-deployment_spec` AC-INT-001..005
- `NOTIF-PRODREADINESS-001`: Implement email notifications pipeline ACs `AC-003..045` from `email-notifications-pipeline_spec`
- `ANALYTICS-PARITY-001`: Reconfirm Aspects/superset + analytics runtime parity for current overlays and tenant surfaces

## 5) What this means for your “local/dev/staging parity” objective

- In practice, the canonical non-production lane is now `rke2-nonprod` (not the deprecated `overlays/staging` lane).
- You should treat parity as `production` vs `rke2-nonprod` (+ `local` for quick dev)
- AC-backed blockers above are real gaps for claiming parity. The biggest immediate blocker is email notifications implementation despite AC mapping artifacts implying testmap coverage.
- All items above are tracker-level handoff-ready and do not require runtime edits by the reviewer.
