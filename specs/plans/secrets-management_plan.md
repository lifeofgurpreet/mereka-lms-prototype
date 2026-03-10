---
spec: secrets-management_spec.md
tier: 0
status: draft
estimated_effort: M
last_updated: "2026-02-10"
---

# Implementation Plan: Secrets Management

**Source Spec**: `specs/secrets-management_spec.md`
**Tier**: 0 -- Foundations (blocks all other specs)
**Estimated Total Effort**: M (medium, 2-4 days -- most infrastructure already exists)

## Summary

This plan formalizes and hardens the existing secrets management pipeline for Mereka Academy. The majority of the infrastructure is already in place: ExternalSecrets, ClusterSecretStore, Infisical integration, pre-commit hooks, and CI workflowsall exist. The implementation work focuses on closing gaps identified by the spec -- adding missing validation scripts, ensuring inventory completeness, hardening CI guardrails, adding observability for secret sync, and writing the verification shell scripts that map each acceptance criterion to a runnable check.

## Prerequisites

Before starting implementation:

1. **Infisical CLI access** -- authenticated on the VPS (`infisical login` completed)
2. **GKE cluster access** -- `kubectl` configured for `mereka-lms` namespace
3. **GCP Secret Manager access** -- `gcloud` authenticated with `roles/secretmanager.secretAccessor` and `roles/secretmanager.viewer`
4. **Repository hooks installed** -- `git config --local include.path ../.gitconfig`
5. **Tool dependencies** -- `infisical`, `jq`, `rg`, `kubectl`, `gcloud` installed

## Task Breakdown

### Build

#### B1. Verify and complete ExternalSecret inventory againstspec
- [ ] **[M]** Cross-reference every key in the spec inventorytables (33+ openedx-secrets, 7 database-secrets) against `deploy/k8s/base/secrets/external-secrets.yaml`. Add any missingkey mappings. Verify `FORUM_API_KEY` is present (spec listsit, current YAML may be missing).
- **Files**: `deploy/k8s/base/secrets/external-secrets.yaml`
- **AC**: AC-004, AC-005, AC-009, AC-010
- **Depends**: None
- **Done**: `rg -c 'secretKey:' deploy/k8s/base/secrets/external-secrets.yaml` shows >= 33 for openedx-secrets and exactlyfor database-secrets. Every `remoteRef.key` starts with `MEREKA_LMS_`.

#### B2. Verify ClusterSecretStore configuration matches spec
- [ ] **[S]** Confirm `deploy/k8s/base/secrets/cluster-secret-store.yaml` has `projectID: bbi-k8` and `secretVersionSelectionPolicy: LatestOrFail`. Already confirmed in codebase -- document and mark as verified.
- **Files**: `deploy/k8s/base/secrets/cluster-secret-store.yaml`
- **AC**: AC-016
- **Depends**: None
- **Done**: `grep -c 'bbi-k8' deploy/k8s/base/secrets/cluster-secret-store.yaml` returns 1. `grep -c 'LatestOrFail'` returns 1.

#### B3. Verify local overlay dev patches for Stripe and MySQL _DEV keys
- [ ] **[S]** Confirm `deploy/k8s/overlays/local/patches/openedx-secrets-dev.yaml` uses `*_DEV` suffix for Stripe keys. Confirm `deploy/k8s/overlays/local/patches/database-secrets-dev.yaml` uses `*_DEV` suffix for all MySQL passwords. Both already exist and are correct.
- **Files**: `deploy/k8s/overlays/local/patches/openedx-secrets-dev.yaml`, `deploy/k8s/overlays/local/patches/database-secrets-dev.yaml`
- **AC**: AC-017
- **Depends**: None
- **Done**: All Stripe keys in dev overlay end with `_DEV`. All MySQL keys in dev overlay end with `_DEV`.

#### B4. Verify Infisical path compliance -- audit script
- [ ] **[S]** Confirm `scripts/infra/infisical-audit-mereka-lms.sh` exists and checks for `MEREKA_LMS_*` keys outside `/k8s/mereka-lms`. Review script logic for correctness against spec requirements.
- **Files**: `scripts/infra/infisical-audit-mereka-lms.sh`
- **AC**: AC-006
- **Depends**: None
- **Done**: Script runs without error and reports any out-of-path keys.

#### B5. Verify Infisical validation script covers all spec requirements
- [ ] **[M]** Confirm `scripts/infra/infisical-validate-mereka-lms.sh` checks: (a) all expected keys exist, (b) no empty values, (c) no placeholder values (`REPLACE_ME`, `CHANGE_ME`,`TODO`, `TBD`), (d) no trailing CR/LF on password-type keys when `STRICT=1`. Already confirmed in codebase -- script meetsall requirements.
- **Files**: `scripts/infra/infisical-validate-mereka-lms.sh`
- **AC**: AC-007, AC-008
- **Depends**: None
- **Done**: `STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh` exits 0.

#### B6. Create verify-secrets-pipeline.sh verification script
- [ ] **[M]** Create a comprehensive shell verification script at `scripts/qa/verify-secrets-pipeline.sh` that runs all acceptance criteria checks that can be run locally against therepository (static checks). This script aggregates: naming convention checks, inventory completeness checks, ExternalSecret config checks, hardcoded secret scans, and dev/prod separation checks. It does NOT require Infisical or cluster access.
- **Files**: `scripts/qa/verify-secrets-pipeline.sh` (new)
- **AC**: AC-004, AC-005, AC-009, AC-010, AC-012, AC-014, AC-015, AC-016, AC-017
- **Depends**: B1, B2, B3
- **Done**: `./scripts/qa/verify-secrets-pipeline.sh` exits 0on clean repo.

#### B7. Add FORUM_API_KEY to ExternalSecrets if missing
- [ ] **[S]** The spec inventory lists `FORUM_API_KEY` mappedto `MEREKA_LMS_FORUM_API_KEY`. Verify it exists in `external-secrets.yaml`. If missing, add the mapping.
- **Files**: `deploy/k8s/base/secrets/external-secrets.yaml`
- **AC**: AC-009
- **Depends**: None
- **Done**: `rg 'FORUM_API_KEY' deploy/k8s/base/secrets/external-secrets.yaml` returns a match.

#### B8. Populate Atlas and migration secrets in Infisical (operator task)
- [ ] **[S]** Verify (or populate) Atlas secrets at `/k8s/mereka-lms/atlas` with keys: `ATLAS_PUBLIC_KEY`, `ATLAS_PRIVATE_KEY`, `ATLAS_ORG_ID`, `ATLAS_PROJECT_ID`. Verify MCT and Kajabi migration keys exist at their respective paths. This is anoperator task, not a code change.
- **Files**: None (Infisical operator task)
- **AC**: AC-011
- **Depends**: None
- **Done**: `infisical secrets generate-example-env --path /k8s/mereka-lms/atlas --env prod` returns all 4 keys.

### Test

#### T1. Create verify-secrets-naming-convention.sh
- [ ] **[S]** Shell script that extracts all `remoteRef.key`values from `external-secrets.yaml` and asserts every one starts with `MEREKA_LMS_`. Fails on any violation.
- **Files**: `scripts/qa/verify-secrets-naming-convention.sh`(new)
- **AC**: AC-004, AC-005
- **Depends**: B1
- **Done**: Script exits 0 when all keys comply, exits 1 if any key lacks prefix.

#### T2. Create verify-secrets-inventory.sh
- [ ] **[S]** Shell script that counts keys in each ExternalSecret resource and validates: openedx-secrets >= 33, database-secrets == 7. Also validates all spec-listed keys are present.
- **Files**: `scripts/qa/verify-secrets-inventory.sh` (new)
- **AC**: AC-009, AC-010
- **Depends**: B1
- **Done**: Script exits 0 when inventory matches spec requirements.

#### T3. Create verify-jwt-uniqueness.sh
- [ ] **[S]** Shell script that extracts all JWT `remoteRef.key` values and asserts each maps to a distinct GCP SM key (notwo services share the same JWT remote key).
- **Files**: `scripts/qa/verify-jwt-uniqueness.sh` (new)
- **AC**: AC-014
- **Depends**: B1
- **Done**: Script exits 0 when all JWT secrets reference distinct remote keys.

#### T4. Create verify-externalsecret-config.sh
- [ ] **[S]** Shell script that parses `external-secrets.yaml` and validates: `refreshInterval: 1h`, `deletionPolicy: Retain`, `creationPolicy: Owner`, `secretStoreRef.name: gcp-secret-manager`. Also validates ClusterSecretStore has `projectID:bbi-k8` and `LatestOrFail`.
- **Files**: `scripts/qa/verify-externalsecret-config.sh` (new)
- **AC**: AC-015, AC-016
- **Depends**: B2
- **Done**: Script exits 0 when all config values match specrequirements.

#### T5. Create verify-no-hardcoded-secrets.sh
- [ ] **[S]** Shell script that scans `deploy/k8s/` for hardcoded secret patterns, excluding legitimate references (`secretKeyRef`, `secretRef`, `remoteRef`, `SecretStore`, `ExternalSecret`, `secretName`, `secretGenerator`, comments). Wraps thegrep pattern from the spec's Verification section.
- **Files**: `scripts/qa/verify-no-hardcoded-secrets.sh` (new)
- **AC**: AC-012
- **Depends**: None
- **Done**: Script exits 0 when no hardcoded secrets found.

#### T6. Create verify-dev-prod-secret-separation.sh
- [ ] **[S]** Shell script that inspects local overlay patches and confirms Stripe and MySQL keys use `*_DEV` suffixed GCPSM keys.
- **Files**: `scripts/qa/verify-dev-prod-secret-separation.sh` (new)
- **AC**: AC-017
- **Depends**: B3
- **Done**: Script exits 0 when all dev overlay keys use `_DEV` suffix.

#### T7. Verify pre-commit hook blocks hardcoded secrets
- [ ] **[S]** Manual test: create a temporary branch, stage afile with `PASSWORD = "hunter2"`, verify `git commit` is blocked by the pre-commit hook. Document the test procedure in the test plan.
- **Files**: `.githooks/pre-commit` (existing, read-only verification)
- **AC**: AC-013
- **Depends**: None
- **Done**: Commit is blocked; removing the secret allows thecommit.

### Observability

#### O1. Add PrometheusRule for ExternalSecret sync failures
- [ ] **[M]** Create or update Prometheus alerting rules to fire when any ExternalSecret in `mereka-lms` namespace has `status.condition.type=Ready` with `status=False` for more thanminutes. Severity: critical.
- **Files**: `infrastructure/monitoring/prometheus-rules/externalsecret-alerts.yaml` (new)
- **AC**: Observability/Alerts (spec requirement)
- **Depends**: None
- **Done**: `kubectl apply --dry-run=client -f` succeeds. Alert rule fires in test scenario.

#### O2. Add Grafana dashboard panel for ExternalSecret syncstatus
- [ ] **[S]** Create a Grafana dashboard JSON or document thepanel query for ExternalSecret sync status (synced vs. errorcount) and reconciliation duration.
- **Files**: `infrastructure/monitoring/dashboards/externalsecret-sync.json` (new)
- **AC**: Observability/Dashboards (spec requirement)
- **Depends**: O1
- **Done**: Dashboard JSON is valid and importable.

#### O3. Verify ESO logs are collected by Promtail
- [ ] **[S]** Confirm Promtail config includes the `external-secrets` namespace. This is a verification task, not necessarily a code change.
- **Files**: `infrastructure/observability/` (verification)
- **AC**: Observability/Logs (spec requirement)
- **Depends**: None
- **Done**: Loki query `{namespace="external-secrets"} |= "SecretSynced"` returns results.

### Docs

#### D1. Update SECRET_ROTATION_CHECKLIST.md to match spec procedures
- [ ] **[S]** Ensure `docs/ops/runbooks/SECRET_ROTATION_CHECKLIST.md` matches the rotation procedure in the spec's Rollout section (7-step sequence).
- **Files**: `docs/ops/runbooks/SECRET_ROTATION_CHECKLIST.md`
- **AC**: Rollout/Rotation (spec requirement)
- **Depends**: None
- **Done**: Checklist steps match spec.

#### D2. Create or update SECRETS_SNAPSHOT.md with current inventory
- [ ] **[S]** Regenerate `docs/reference/operations/SECRETS_SNAPSHOT.md` with the current key inventory matching the spec's 33+7+4+8+6 keys.
- **Files**: `docs/reference/operations/SECRETS_SNAPSHOT.md`
- **AC**: AC-009, AC-010, AC-011
- **Depends**: B1, B8
- **Done**: Snapshot doc lists all keys from spec inventory.

### CI Workflow

#### C1. Add secrets-pipeline-verification job to CI
- [ ] **[M]** Add a new job `secrets-pipeline` to `.github/workflows/ci.yml` that runs `verify-secrets-pipeline.sh` (B6) on every push to `main` and every PR. This is the static (repo-local) verification. The existing `validate-infisical` job handles live Infisical checks.
- **Files**: `.github/workflows/ci.yml`
- **AC**: AC-004, AC-005, AC-009, AC-010, AC-012, AC-014, AC-015, AC-016, AC-017
- **Depends**: B6
- **Done**: CI job runs green on `main`.

#### C2. Verify existing Infisical CI job covers spec requirements
- [ ] **[S]** Confirm the existing `validate-infisical` job in `.github/workflows/ci.yml` runs `STRICT=1` for both `prod`and `dev`. Already confirmed in codebase.
- **Files**: `.github/workflows/ci.yml` (existing, verification only)
- **AC**: AC-007, AC-008
- **Depends**: None
- **Done**: CI job runs `STRICT=1` for both environments.

### Rollout

#### R1. Run full validation suite against production
- [ ] **[M]** After all build and test tasks are complete, run the full verification sequence from the spec's Verificationsection (10 commands) against production. Document results as evidence.
- **Files**: None (operator task)
- **AC**: AC-001, AC-002, AC-003, AC-018
- **Depends**: All build and test tasks
- **Done**: All 10 verification commands pass. Results captured in a bead.

#### R2. Run full validation suite against dev (Kind)
- [ ] **[S]** Same as R1 but against the Kind dev cluster toverify dev/prod separation.
- **Files**: None (operator task)
- **AC**: AC-017
- **Depends**: All build and test tasks
- **Done**: All applicable verification commands pass on Kind.

---

## Milestone Checkpoints

### Milestone 1: Static Verification (Day 1)
- B1, B2, B3, B7 complete (inventory and config verified/updated)
- T1-T6 written and passing
- B6 aggregates all static checks and passes

### Milestone 2: CI Integration (Day 2)
- C1 added to CI workflow
- C2 verified
- All static checks pass in CI

### Milestone 3: Live Verification (Day 2-3)
- B4, B5, B8 verified against Infisical
- O1, O2, O3 observability tasks complete
- D1, D2 docs updated

### Milestone 4: Production Signoff (Day 3-4)
- R1 full production verification passes
- R2 dev verification passes
- Evidence documented in bead

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Missing `FORUM_API_KEY` in ExternalSecret | Medium | Low |B7 checks and adds if missing |
| Infisical CLI auth expires during validation | Low | Medium| Re-authenticate; CI uses service token |
| Atlas/migration secrets not populated in Infisical | Medium| Low | B8 is an operator task; decouple from automated checks |
| CI secrets (`INFISICAL_TOKEN`) not configured in GitHub | Medium | Medium | `validate-infisical` job uses `if:` guard; static checks work without it |
| ESO metrics not scraped by Prometheus | Low | Medium | O1/Overify; can be deferred to observability spec |

---

## Dependencies on Other Specs

| Spec | Dependency Type |
|------|----------------|
| `repository-structure_spec.md` | Defines directory layout for scripts and manifests |
| `k8s-deployment_spec.md` | Defines pod specs, `envFrom`, deployment patterns |
| `observability-stack_spec.md` | Defines Prometheus, Loki, Grafana infrastructure |
| `cross-cutting-requirements_spec.md` | Inherits secrets management pattern (Section 3) |
