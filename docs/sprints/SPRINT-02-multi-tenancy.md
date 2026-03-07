# Sprint 2: Multi-Tenancy & SLOs

**Duration**: 2 weeks (2026-02-25 to 2026-03-11)
**Status**: ✅ COMPLETE (2026-02-12)
**Coverage**: ~65% → ~70%

---

## Objectives

1. Fix gaps found in Sprint 1 (VeleroBackupFailed, Mux secrets, Trivy, orphaned forum-dev.yaml)
2. Complete SLI/SLO foundation with PrometheusRules
3. Complete design-tokens-system CI validation (75% → 100%)
4. Verify platform-middleware-custom-apps (5% → 80%)
5. Verify observability-stack contracts
6. Verify multi-tenancy-architecture foundation (57% → 90%)

---

## Tasks Breakdown

### Gap Fixes from Sprint 1

- [x] Add VeleroBackupFailed/VeleroBackupMissing PrometheusRule alerts
  - **File**: `deploy/k8s/base/monitoring/prometheusrule-velero.yaml`
- [x] Add MUX_TOKEN_ID/MUX_TOKEN_SECRET to ExternalSecrets
  - **File**: `deploy/k8s/base/secrets/external-secrets.yaml`
- [x] Delete orphaned forum-dev.yaml (Forum v2 runs in-process)
  - **File**: `deploy/k8s/overlays/local/patches/meilisearch-security-context.yaml` (deleted)
- [x] Add Trivy container scanning to CI build pipeline
  - **File**: `.github/workflows/build-tutor-images.yml`

### SLI/SLO Foundation

- [x] PrometheusRule with SLI recording rules (availability + latency)
  - **File**: `deploy/k8s/base/monitoring/prometheusrule-slo.yaml`
- [x] Multi-window burn rate alerts (fast 14.4x, slow 6x)
  - Included in `prometheusrule-slo.yaml`
- [x] 30-day error budget tracking (remaining ratio + minutes)
  - Included in `prometheusrule-slo.yaml`
- [x] Monitoring kustomization updated
  - **File**: `deploy/k8s/base/monitoring/kustomization.yaml`

### Design Tokens CI

- [x] AC-010: Token validation in CI
  - **File**: `.github/workflows/ci.yml` (design-token-lint job added)
- [x] AC-011-012: Token drift detection + sync verification
  - **File**: `scripts/qa/verify-design-token-ci.sh` — 20/20 pass

### Platform Middleware

- [x] All 5 middleware components verified
  - **File**: `scripts/qa/verify-platform-middleware.sh` — 68/68 pass

### Observability Contracts

- [x] Full observability stack verification
  - **File**: `scripts/qa/verify-observability-contracts.sh` — 41/42 pass (tracing SKIP)

### Multi-Tenancy Foundation

- [x] Multi-tenancy architecture verification
  - **File**: `scripts/qa/verify-multi-tenancy-foundation.sh` — 52/52 pass (3 tenant domains)

---

## Deliverables

| File | Type | Result |
|------|------|--------|
| `deploy/k8s/base/monitoring/prometheusrule-slo.yaml` | K8s manifest | SLI/SLO rules |
| `deploy/k8s/base/monitoring/prometheusrule-velero.yaml` | K8s manifest | Velero alert rules |
| `deploy/k8s/base/monitoring/kustomization.yaml` | K8s manifest | Updated |
| `deploy/k8s/base/secrets/external-secrets.yaml` | K8s manifest | Mux secrets added |
| `.github/workflows/build-tutor-images.yml` | CI | Trivy scanning |
| `.github/workflows/ci.yml` | CI | Design token lint job |
| `scripts/qa/verify-slo-contracts.sh` | Verification | 27/27 pass |
| `scripts/qa/verify-design-token-ci.sh` | Verification | 20/20 pass |
| `scripts/qa/verify-platform-middleware.sh` | Verification | 68/68 pass |
| `scripts/qa/verify-observability-contracts.sh` | Verification | 41/42 pass |
| `scripts/qa/verify-multi-tenancy-foundation.sh` | Verification | 52/52 pass |

---

## Success Criteria

- [x] Sprint 1 gaps fixed (Velero alerts, Mux secrets, Trivy, forum-dev cleanup)
- [x] SLI/SLO PrometheusRules deployed with burn rate alerts
- [x] Design tokens validated in CI
- [x] All 5 platform middlewares verified (68/68 pass)
- [x] Multi-tenancy foundation verified (52/52 pass)
- [x] Coverage report shows ~70%

---

## Dependencies

- **Depends on**: Sprint 1 (foundation complete) — ✅ done
- **Blocks**: Sprint 3 (auth SSO needs multi-tenancy) — ✅ unblocked

---

## Resources

- **Specs**: `specs/multi-tenancy-architecture_spec.md`, `specs/design-tokens-system_spec.md`
- **Existing code**: `infrastructure/tutor/plugins/multi-tenancy/`
- **Runbooks**: `docs/operations/TENANT_PROVISIONING.md`
