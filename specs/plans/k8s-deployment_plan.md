---
spec: k8s-deployment_spec.md
tier: 1
status: draft
estimated_effort: "3-4 weeks (includes verification scripting and gap remediation)"
owner: engineering
last_updated: "2026-02-10"
prerequisites:
  - repository-structure_spec.md (Tier 0, APPROVED)
  - secrets-management_spec.md (Tier 0, IN_REVIEW)
  - tutor-configuration_spec.md (Tier 0, DRAFT)
  - cross-cutting-requirements_spec.md (Tier 0, IN_REVIEW)
---

# Implementation Plan: Kubernetes Deployment Specification

**Source Spec**: specs/k8s-deployment_spec.md
**Tier**: 1 -- Core Infrastructure
**Blocks**: Tiers 2-5 (all K8s-deployed services)

## Summary

The K8s deployment spec codifies the existing Open edX Kubernetes deployment on GKE. Much of the infrastructure already exists in deploy/k8s/. This plan focuses on:

1. **Gap remediation** -- closing the delta between what the spec requires and what the manifests currently declare (missing labels, missing security contexts, missing Aspects health probes, etc.).
2. **Verification automation** -- building shell scripts that machine-check every acceptance criterion against the rendered Kustomize output or live cluster.
3. **Documentation alignment** -- ensuring operational runbooks reference the spec and verification commands.

## Current State Analysis

The codebase already provides substantial coverage:

- **17+ Deployments**: present in deploy/k8s/base/deployments.yml (caddy, lms, cms, lms-worker, cms-worker, elasticsearch, mysql, smtp, redis, discovery, ecommerce, ecommerce-worker, credentials, meilisearch, mfe, notes, xqueue). Note: the spec lists a standalone forum Deployment, but Forum v2 is integrated into LMS (no separate Deployment). Meilisearch is an addition not in the original spec table.
- **Services**: all present in deploy/k8s/base/services.yml. Notes Service has a label bug (app.kubernetes.io/name: caddy instead of notes).
- **PVCs**: caddy (1Gi), elasticsearch (2Gi), mysql (5Gi), redis (1Gi), meilisearch (2Gi) all present.
- **ExternalSecrets**: openedx-secrets and database-secrets defined with correct ClusterSecretStore, refreshInterval, and deletionPolicy.
- **Monitoring**: ServiceMonitors for lms, cms, mysql, redis. PrometheusRule with all required alerts.
- **Logging**: Promtail DaemonSet with tolerations, resource limits, probes, host mounts.
- **Ingress**: Production Ingress resources for LMS, Studio, MFE.
- **Kustomize overlays**: local and production overlays with correct replica counts and image overrides.

### Gaps Identified

| Gap | AC(s) Affected | Severity |
|-----|---------------|----------|
| Notes Service label app.kubernetes.io/name: caddy should be notes | AC-014 | High |
| Forum Deployment absent (spec says 17 Deployments including forum) -- spec may need updating since Forum v2 is in-process | AC-003 | Medium (spec alignment) |
| xqueue Deployment missing securityContext (runAsUser/runAsGroup) | AC-010 | Medium |
| mfe Deployment missing securityContext (runAsUser/runAsGroup) | AC-010 | Medium |
| ecommerce-worker missing envFrom for openedx-secrets, database-secrets, mereka-lms-runtime-secrets | AC-006 | Medium |
| Aspects plugin Deployments (ClickHouse, Superset) exist in deploy/k8s/base/plugins/aspects/ but health probes and resource limits need verification | AC-032 | Medium |
| No automated verification scripts mapping to all 32 ACs | All | High |
| CronJobs (auth-verify-prod, cert-verify-prod) -- need to verify they exist in manifests or are deployed out-of-band | AC-031 | Medium |

---

## Task Breakdown

### Build -- Manifest Gap Remediation

- [ ] **[S]** B-01: Fix Notes Service label from app.kubernetes.io/name: caddy to app.kubernetes.io/name: notes (deploy/k8s/base/services.yml line 209) | AC: #014 | Depends: None

- [ ] **[S]** B-02: Add securityContext to xqueue Deployment (runAsUser: 1000, runAsGroup: 1000, allowPrivilegeEscalation: false) (deploy/k8s/base/deployments.yml, xqueue section) | AC: #010, #011 | Depends: None

- [ ] **[S]** B-03: Add securityContext to mfe Deployment (runAsUser: 1000, runAsGroup: 1000, allowPrivilegeEscalation: false) (deploy/k8s/base/deployments.yml, mfe section) | AC: #010, #011 | Depends: None

- [ ] **[S]** B-04: Add envFrom references (openedx-secrets, database-secrets, mereka-lms-runtime-secrets) to ecommerce-worker Deployment (deploy/k8s/base/deployments.yml, ecommerce-worker section) | AC: #006 | Depends: None

- [ ] **[M]** B-05: Audit and fix Aspects plugin Deployments -- add health probes (ClickHouse /ping on 8123, Superset /health on 8088), resource requests/limits (ClickHouse: 2Gi/4Gi mem, 500m/2 cpu; Superset: 1Gi/2Gi mem, 250m/1 cpu), and app.kubernetes.io/part-of: aspects labels (deploy/k8s/base/plugins/aspects/deployments.yml) | AC: #032 | Depends: None

- [ ] **[S]** B-06: Verify and document Forum Deployment status -- the spec lists forum as a base Deployment, but Forum v2 is integrated into LMS. Update spec or add a comment/stub Deployment. Recommend updating the spec to remove forum from the Deployment table and note the in-process integration. (specs/k8s-deployment_spec.md lines 122, 158) | AC: #003 | Depends: None

- [ ] **[M]** B-07: Verify CronJob manifests for observability jobs exist (auth-verify-prod, cert-verify-prod in mereka-lms namespace; backup-verification, restore-test in velero namespace). If deployed out-of-band, create manifest stubs or document the deployment mechanism. (deploy/k8s/overlays/production/) | AC: #031 | Depends: None

- [ ] **[S]** B-08: Verify skillourfuture.academy.mereka.io is listed as a host in the production LMS Ingress (deploy/k8s/overlays/production/ingress-openedx-lms.yaml) | AC: #019 | Depends: None

### Test -- Verification Scripts

- [ ] **[M]** T-01: Create scripts/qa/verify-kustomize-render.sh -- renders both local and production overlays via kubectl kustomize, checks exit code, verifies all resources have namespace: mereka-lms (scripts/qa/verify-kustomize-render.sh) | AC: #001, #002 | Depends: None

- [ ] **[L]** T-02: Create scripts/qa/verify-k8s-deployment-spec.sh -- comprehensive verification script that checks all 32 ACs against rendered Kustomize output (no cluster required). Checks: Deployment count, replica counts per overlay, envFrom references, security contexts, service selectors vs pod labels, PVC sizes/access modes, Ingress hosts/annotations, ConfigMap count, image tags, monitoring resources, Promtail resources. (scripts/qa/verify-k8s-deployment-spec.sh) | AC: #001-#032 | Depends: B-01 through B-08

- [ ] **[M]** T-03: Create scripts/qa/verify-k8s-secrets-hygiene.sh -- scans all manifests in deploy/k8s/ for hardcoded secrets (passwords, API keys, tokens) excluding local dev overlay placeholders, ExternalSecret references, and comments. Extends existing scripts/qa/scan-secrets-fast.sh. (scripts/qa/verify-k8s-secrets-hygiene.sh) | AC: #012, #023 | Depends: None

- [ ] **[M]** T-04: Create scripts/qa/verify-k8s-live-cluster.sh -- live cluster verification: checks Deployment readiness, endpoint population, ExternalSecret sync status, PVC binding, Promtail pod count vs node count. Requires cluster access. (scripts/qa/verify-k8s-live-cluster.sh) | AC: #003, #013, #020, #021, #029 | Depends: None

- [ ] **[S]** T-05: Create scripts/qa/verify-k8s-images.sh -- checks production overlay rendered output for latest tags and verifies Artifact Registry path format (scripts/qa/verify-k8s-images.sh) | AC: #025, #026 | Depends: None

- [ ] **[S]** T-06: Add Kustomize render check to existing scripts/qa/audit-observability.sh local mode -- verify ServiceMonitors, PrometheusRule, and Promtail DaemonSet are present in rendered output (scripts/qa/audit-observability.sh) | AC: #027, #028, #029, #030 | Depends: None

- [ ] **[S]** T-07: Create scripts/qa/verify-k8s-externalsecrets.sh -- checks ExternalSecret specs for refreshInterval, secretStoreRef, deletionPolicy, and MEREKA_LMS_ prefix on all remoteRef keys (scripts/qa/verify-k8s-externalsecrets.sh) | AC: #021, #022, #023 | Depends: None

### Observability

- [ ] **[S]** O-01: Verify existing Grafana dashboard JSON in infrastructure/monitoring/ covers deployment replica status, pod restarts, memory/CPU per workload, MySQL connections, Redis memory (infrastructure/monitoring/) | AC: Observability/Dashboards | Depends: None

- [ ] **[S]** O-02: Verify Promtail ConfigMap labels logs with namespace, pod, container, and node (deploy/k8s/base/logging/promtail-configmap.yaml) | AC: Observability/Logs | Depends: None

### Docs

- [ ] **[M]** D-01: Update docs/operations/K8S_OPERATIONS_GUIDE.md to reference the spec and link to new verification scripts (docs/operations/K8S_OPERATIONS_GUIDE.md) | Depends: T-02

- [ ] **[S]** D-02: Update docs/operations/DEPLOYMENT_RUNBOOK.md rollout and rollback sections to match spec procedures (docs/operations/DEPLOYMENT_RUNBOOK.md) | Depends: None

- [ ] **[S]** D-03: Add edge case troubleshooting entries from spec to docs/ops/runbooks/TROUBLESHOOTING.md (CrashLoopBackOff, Celery worker starvation, volume data corruption, partial deployment) (docs/ops/runbooks/TROUBLESHOOTING.md) | Depends: None

### Rollout

- [ ] **[S]** R-01: Run verify-k8s-deployment-spec.sh against current manifests and generate a gap report. File issues (beads) for any remaining gaps. (scripts/qa/verify-k8s-deployment-spec.sh) | Depends: T-02

- [ ] **[M]** R-02: Apply manifest fixes (B-01 through B-05) to production cluster via standard rollout procedure (dry run, apply, verify deployments, verify endpoints, smoke test) | Depends: B-01 through B-08, T-02

- [ ] **[S]** R-03: Run live cluster verification (verify-k8s-live-cluster.sh) post-apply and capture results (scripts/qa/verify-k8s-live-cluster.sh) | Depends: R-02, T-04

---

## Milestones

| Milestone | Tasks | Target |
|-----------|-------|--------|
| M1: Manifest gaps remediated | B-01 through B-08 | Week 1 |
| M2: Offline verification scripts complete | T-01, T-02, T-03, T-05, T-06, T-07 | Week 2 |
| M3: Live verification and docs | T-04, O-01, O-02, D-01, D-02, D-03 | Week 3 |
| M4: Production rollout and validation | R-01, R-02, R-03 | Week 4 |

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Forum Deployment spec mismatch -- spec says 17 Deployments including forum but Forum v2 is in-process in LMS | Verification script counts will fail | Update spec to reflect current architecture (B-06) |
| Meilisearch Deployment/PVC not in spec but exists in manifests | Verification confusion | Document in spec addendum or update spec |
| Aspects plugin Deployments may not be rendered by base overlay (require plugin kustomization) | AC-032 verification may need plugin-aware rendering | Test with kubectl kustomize including plugin path |
| Live cluster verification requires GKE access and may expose transient state | False negatives from pod churn | Run live checks multiple times; allow for transient Pending states |
| Security context changes to xqueue and mfe may cause permission errors | Container startup failures | Test in local Kind cluster first |
| Notes Service label fix may cause brief endpoint gap during rollout | Momentary traffic routing failure for notes | Apply during low-traffic window; notes is not user-critical |

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-032) has at least one build or verification task
- [x] Every acceptance criterion has at least one test/verification script
- [x] Edge cases from spec mapped to troubleshooting docs (D-03)
- [x] File paths specified for every task
- [x] Dependencies identified for all tasks
- [x] Complexity estimated (S/M/L) for each task
- [x] Source spec linked in header
