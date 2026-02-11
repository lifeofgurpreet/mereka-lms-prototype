# Sprint 1: Foundation Complete

**Duration**: 2 weeks (2026-02-11 to 2026-02-25)
**Goal**: Close all Tier 2-3 gaps, achieve 68% coverage
**Current**: 59.6% → **Target**: 68%

---

## Objectives

1. Complete k8s-deployment (97% → 100%)
2. Complete tutor-configuration-resilience (67% → 100%)
3. Complete analytics-pipeline (88% → 100%)
4. Complete data-migrations-kajabi-mct (98% → 100%)
5. Close disaster-recovery gaps (55% → 90%)
6. Close video-pipeline gaps (24% → 70%)
7. Close ci-cd-pipeline gaps (56% → 85%)

---

## Tasks Breakdown

### Week 1: Close Small Gaps (7 ACs)

**k8s-deployment** (1 AC unmapped)
- [ ] AC-001: Verify base Kustomize directory structure
  - **File**: `scripts/qa/verify-k8s-kustomize-structure.sh`
  - **Estimated**: 1 hour

**tutor-configuration-resilience** (4 ACs unmapped)
- [ ] AC-TCR-001: Verify config.yml never committed to git
  - **File**: `.githooks/pre-commit` + verification script
  - **Estimated**: 2 hours
- [ ] AC-TCR-002: Backup created before `tutor config save`
  - **File**: `scripts/infra/tutor-config-save.sh` (enhance)
  - **Estimated**: 2 hours
- [ ] AC-TCR-003: Rollback script restores from backup
  - **File**: `scripts/infra/tutor-config-rollback.sh` (new)
  - **Estimated**: 3 hours
- [ ] AC-TCR-006: Config changes trigger apply-patches.sh
  - **File**: Test wrapper behavior
  - **Estimated**: 2 hours

**analytics-pipeline** (1 AC unmapped)
- [ ] AC-003: ClickHouse retention policy active
  - **Type**: Manual verification (add to manual_verifications.yaml)
  - **Estimated**: 30 minutes

**data-migrations-kajabi-mct** (1 AC unmapped)
- [ ] AC-044: Migration rollback procedures documented
  - **Type**: Documentation (add to runbook)
  - **Estimated**: 1 hour

### Week 2: Medium Features (30 ACs)

**disaster-recovery-business-continuity** (10 ACs unmapped)
- [ ] AC-007-012: Velero restore procedures for 6 scenarios
  - **File**: `scripts/infra/velero-restore-*.sh` (6 scripts)
  - **Estimated**: 2 days

**video-pipeline-delivery** (19 ACs unmapped)
- [ ] AC-006-015: Mux upload validation, status tracking, error handling
  - **File**: `services/video-pipeline/tests/test_mux_*.py`
  - **Estimated**: 3 days
- [ ] AC-016-025: Video playback, adaptive streaming, analytics
  - **Type**: Mix of automated + manual
  - **Estimated**: 2 days

**ci-cd-pipeline** (17 ACs unmapped)
- [ ] AC-013-020: Release automation, dry-run, rollback
  - **File**: `.github/workflows/release.yml` enhancement
  - **Estimated**: 2 days
- [ ] AC-030-039: Image scanning, SBOM, vulnerability gates
  - **File**: `.github/workflows/security-scan.yml`
  - **Estimated**: 1 day

---

## Success Criteria

- [ ] All Tier 2 specs at 100% (k8s-deployment, tutor-resilience)
- [ ] Tier 3 specs at 90%+ average
- [ ] Coverage report shows 68%+
- [ ] All integrity gates pass
- [ ] New tests have `@covers` + `@spec` annotations

---

## Dependencies

- **Blocked**: None (foundation work is unblocked)
- **Blocks**: Sprint 2 (multi-tenancy work)

---

## Resources

- **Tools**: `scripts/qa/spec-tools/spec_verify.py`, `spec_coverage_report.py`
- **Specs**: `specs/k8s-deployment_spec.md`, `specs/tutor-configuration-resilience_spec.md`, etc.
- **Previous work**: Foundation (Tier 0-1) already at 100%

---

## Daily Standup Questions

1. Which AC did you complete yesterday?
2. Which AC are you working on today?
3. Any blockers preventing AC completion?
4. Does your test have `@covers` annotation?

---

## Sprint Review

**Metrics to report**:
- Coverage change: 59.6% → X%
- ACs completed: 0 → X
- Specs at 100%: 20 → X
- Unmapped ACs: 311 → X
