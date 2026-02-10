---
spec: secrets-management_spec.md
plan: secrets-management_plan.md
last_updated: "2026-02-10"
---

# Test Plan: Secrets Management

**Source Spec**: `specs/secrets-management_spec.md`
**Source Plan**: `specs/plans/secrets-management_plan.md`

## Test Framework

This spec covers infrastructure-as-code and operational tooling. There is no application-level code to unit test. All verification uses:

| Test Type | Tool | Location Pattern |
|-----------|------|-----------------|
| `shell_verification` | Bash scripts (`set -euo pipefail`) |`scripts/qa/verify-*.sh` |
| `ci_workflow` | GitHub Actions | `.github/workflows/ci.yml`|
| `kubectl_check` | kubectl commands (requires cluster access) | Inline commands |
| `manual_verification` | Human-executed checklist | Documented below |

---

## Test Matrix

| AC | Description | Test Type | Test File / Location | Mocks/ Fixtures | Priority |
|----|-------------|-----------|---------------------|------------------|----------|
| AC-001 | ExternalSecrets show `SecretSynced` status | `kubectl_check` | `kubectl get externalsecrets -n mereka-lms` | Requires GKE cluster | P1 |
| AC-002 | Pods use `envFrom` with `secretRef` | `kubectl_check` | `kubectl get deploy lms -n mereka-lms -o yaml \| grep -A3 envFrom` | Requires GKE cluster | P1 |
| AC-003 | LMS pod has non-empty `OPENEDX_SECRET_KEY` env var| `kubectl_check` | `kubectl exec` into LMS pod | Requires GKE cluster + running pod | P1 |
| AC-004 | All `remoteRef.key` values start with `MEREKA_LMS_` | `shell_verification` | `scripts/qa/verify-secrets-naming-convention.sh` | None (parses YAML file) | P1 |
| AC-005 | ExternalSecret `data` maps `MEREKA_LMS_*` remote to local keys | `shell_verification` | `scripts/qa/verify-secrets-naming-convention.sh` | None (parses YAML file) | P1 |
| AC-006 | Zero `MEREKA_LMS_*` keys outside canonical Infisical path | `shell_verification` | `scripts/infra/infisical-audit-mereka-lms.sh` | Requires Infisical CLI auth | P1 |
| AC-007 | Validation script exits 0 in prod and dev | `shell_verification` + `ci_workflow` | `scripts/infra/infisical-validate-mereka-lms.sh`, `.github/workflows/ci.yml` (validate-infisical job) | Requires Infisical CLI auth or `INFISICAL_TOKEN` | P1 |
| AC-008 | `STRICT=1` validation exits 0 (no empty, no placeholder, no trailing CR/LF) | `shell_verification` + `ci_workflow` | `scripts/infra/infisical-validate-mereka-lms.sh`, `.github/workflows/ci.yml` (validate-infisical job) | Requires Infisical CLI auth or `INFISICAL_TOKEN` | P1 |
| AC-009 | `openedx-secrets` has >= 33 keys matching spec inventory | `shell_verification` + `kubectl_check` | `scripts/qa/verify-secrets-inventory.sh` (static), `kubectl get secret`(live) | Static: parses YAML; Live: requires cluster | P1 |
| AC-010 | `database-secrets` has exactly 7 specified keys |`shell_verification` + `kubectl_check` | `scripts/qa/verify-secrets-inventory.sh` (static), `kubectl get secret` (live) |Static: parses YAML; Live: requires cluster | P1 |
| AC-011 | Atlas secrets exist at `/k8s/mereka-lms/atlas` inInfisical | `manual_verification` | Operator runs `infisicalsecrets generate-example-env --path /k8s/mereka-lms/atlas` |Requires Infisical CLI auth | P2 |
| AC-012 | Zero hardcoded secrets in `deploy/k8s/` directory| `shell_verification` + `ci_workflow` | `scripts/qa/verify-no-hardcoded-secrets.sh`, `.github/workflows/ci.yml` | None (scans repo files) | P1 |
| AC-013 | Pre-commit hook blocks commits with hardcoded secrets | `manual_verification` | `.githooks/pre-commit` (test bystaging a file with `PASSWORD = "hunter2"`) | Requires localgit hooks installed | P1 |
| AC-014 | All JWT secrets map to distinct GCP SM remote keys| `shell_verification` | `scripts/qa/verify-jwt-uniqueness.sh` | None (parses YAML file) | P1 |
| AC-015 | ExternalSecrets have correct `refreshInterval`, `deletionPolicy`, `creationPolicy`, `secretStoreRef` | `shell_verification` | `scripts/qa/verify-externalsecret-config.sh` |None (parses YAML files) | P1 |
| AC-016 | ClusterSecretStore has `projectID: bbi-k8` and `LatestOrFail` | `shell_verification` | `scripts/qa/verify-externalsecret-config.sh` | None (parses YAML file) | P1 |
| AC-017 | Local overlay uses `*_DEV` suffixed keys for Stripe and MySQL | `shell_verification` | `scripts/qa/verify-dev-prod-secret-separation.sh` | None (parses YAML files) | P1 |
| AC-018 | Rotated secret propagates end-to-end after sync +force-sync + restart | `manual_verification` | Follow rotation procedure in spec Rollout section | Requires Infisical + GKE cluster + running pods | P2 |

---

## Edge Case Tests

| Edge Case | Test Description | Test Type | Location | Priority |
|-----------|-----------------|-----------|----------|----------|
| EC-1: Trailing whitespace in passwords | `infisical-validate-mereka-lms.sh` with `STRICT=1` detects trailing `\r` or `\n` in password/OAuth secret values | `shell_verification` | `scripts/infra/infisical-validate-mereka-lms.sh` | P1 |
| EC-2: ExternalSecret sync failure | If ClusterSecretStore is unreachable, existing K8s Secrets are retained (`deletionPolicy: Retain`) | `kubectl_check` + `manual_verification` | Verify `deletionPolicy: Retain` in YAML (static); simulate by revoking IAM role (manual) | P2 |
| EC-3: Key sprawl outside canonical path | `infisical-audit-mereka-lms.sh` detects `MEREKA_LMS_*` keys at root `/` or `/mereka-lms` | `shell_verification` | `scripts/infra/infisical-audit-mereka-lms.sh` | P1 |
| EC-4: Placeholder values in production | `infisical-validate-mereka-lms.sh` rejects `REPLACE_ME`, `CHANGE_ME`, `TODO`, `TBD` values | `shell_verification` | `scripts/infra/infisical-validate-mereka-lms.sh` | P1 |
| EC-5: GCP SM secret missing | `sync-mereka-lms-secrets-to-gcpsm.sh` creates missing secrets in create-if-missing mode |`manual_verification` | `scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh` | P2 |
| EC-6: Kind MySQL auth drift after rotation | Dev overlay uses `*_DEV` keys to isolate from production rotations | `shell_verification` | `scripts/qa/verify-dev-prod-secret-separation.sh` | P1 |
| EC-7: Concurrent secret updates | No automated test (coordination via rotation checklist) | `manual_verification` | `docs/operations/SECRET_ROTATION_CHECKLIST.md` | P3 |
| EC-8: ESO service account IAM drift | ClusterSecretStore requires both `secretAccessor` and `viewer` roles | `manual_verification` | `gcloud projects get-iam-policy-binding` check |P2 |

---

## Test Execution Strategy

### Phase 1: Static / Repo-Local (CI-safe, no credentials needed)

These tests run in CI on every push to `main` and every PR:

```bash
# Aggregated by verify-secrets-pipeline.sh:
./scripts/qa/verify-secrets-naming-convention.sh
./scripts/qa/verify-secrets-inventory.sh
./scripts/qa/verify-jwt-uniqueness.sh
./scripts/qa/verify-externalsecret-config.sh
./scripts/qa/verify-no-hardcoded-secrets.sh
./scripts/qa/verify-dev-prod-secret-separation.sh
```

### Phase 2: Infisical Validation (requires credentials)

These tests run in CI when `INFISICAL_TOKEN` and `INFISICAL_PROJECT_ID` are configured:

```bash
STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
STRICT=1 INFISICAL_ENV=dev  ./scripts/infra/infisical-validate-mereka-lms.sh
./scripts/infra/infisical-audit-mereka-lms.sh
```

### Phase 3: Live Cluster Verification (requires GKE access)

These tests are run by operators during rollout verification:

```bash
kubectl get externalsecrets -n mereka-lms   # AC-001
kubectl get deploy lms -n mereka-lms -o yaml | grep -A3 envFrom  # AC-002
kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data}' | jq 'keys | length'  # AC-009
kubectl get secret database-secrets -n mereka-lms -o jsonpath='{.data}' | jq 'keys | length'  # AC-010
```

### Phase 4: Manual Verification (human operator)

| Test | Procedure | Frequency |
|------|-----------|-----------|
| AC-003: LMS pod env var check | `kubectl exec` into LMS pod, echo env var | Per deployment |
| AC-011: Atlas secrets existence | Run Infisical CLI against`/k8s/mereka-lms/atlas` | Once during setup |
| AC-013: Pre-commit hook test | Stage file with hardcoded secret, attempt commit | Once per hook change |
| AC-018: End-to-end rotation test | Follow spec rotation procedure with a non-critical secret | Quarterly |

---

## Coverage Summary

| Category | Total ACs | Automated | Manual | Coverage |
|----------|-----------|-----------|--------|----------|
| Pipeline Integrity | 3 (AC-001 to AC-003) | 0 | 3 (kubectl_check) | 100% (requires cluster) |
| Naming Convention | 2 (AC-004 to AC-005) | 2 | 0 | 100% |
| Infisical Path | 3 (AC-006 to AC-008) | 3 | 0 | 100% (requires Infisical) |
| Secret Inventory | 3 (AC-009 to AC-011) | 2 static + 2 live| 1 manual | 100% |
| No Hardcoded Secrets | 2 (AC-012 to AC-013) | 1 | 1 manual| 100% |
| JWT Uniqueness | 1 (AC-014) | 1 | 0 | 100% |
| ExternalSecret Config | 2 (AC-015 to AC-016) | 2 | 0 | 100%|
| Dev/Prod Separation | 1 (AC-017) | 1 | 0 | 100% |
| Rotation Verification | 1 (AC-018) | 0 | 1 manual | 100% |
| **Total** | **18** | **12** | **6** | **100%** |
| Edge Cases | 8 | 5 | 3 | 100% |

All 18 acceptance criteria are covered. 12 have fully automated verification scripts. 6 require cluster access or human execution but have documented procedures.
