# GKE Parity + ArgoCD Hardening Evidence Bundle
**Timestamp**: 2026-02-20T18:12:51Z
**Agent**: WhiteCliff
**Branch**: feat/23ry2-spec-dedupe-normalize (mereka-lms)
**Related PR**: bbi-infrastructure feat/argocd-timeout-hardening → ca0cc5a

---

## 1. GKE Prod Runtime Surface Checks

| Surface | URL | HTTP | Status |
|---------|-----|------|--------|
| Academy LMS | https://academyv2.mereka.io/ | 200 | PASS |
| Studio CMS | https://studio.academyv2.mereka.io/ | 200 | PASS |
| Admin Portal | https://admin.academyv2.mereka.io/ | 200 | PASS |
| Enterprise Access Health | https://admin.academyv2.mereka.io/api/enterprise-access/health/ | 200 | PASS |

Admin HTML: no `undefined_license_key` / no `MISSING_ENV_VAR` / no `405` blocking errors confirmed.

---

## 2. ArgoCD Application Status (All Environments)

| App | Context | Sync | Health | Revision |
|-----|---------|------|--------|----------|
| mereka-lms-prod | GKE (gke_bbi-k8) | Synced | Healthy | 0a67963 |
| mereka-lms-local | rke2-nonprod | Synced | Healthy | 0a67963 |
| mereka-lms-local | rke2-staging | Synced | Healthy | 0a67963 |

**Before (prior session)**: mereka-lms-local on rke2-nonprod showed Unknown/ComparisonError due to ArgoCD repo-server GitHub fetch timeouts.
**After**: Synced/Healthy — live hotfixes resolved the timeouts.

---

## 3. ArgoCD Timeout Hardening — Codified

**Live hotfixes applied 2026-02-20 on rke2-nonprod (via kubectl):**

### argocd-cmd-params-cm (ConfigMap)
```yaml
controller.repo.server.timeout.seconds: "300"
reposerver.git.request.timeout: "5m"
reposerver.git.lsremote.parallelism.limit: "5"
reposerver.parallelism.limit: "5"
reposerver.enable.git.submodule: "false"
```

### argocd-repo-server (Deployment env vars)
```yaml
ARGOCD_EXEC_TIMEOUT: 5m
ARGOCD_EXEC_FATAL_TIMEOUT: 6m
```

**Codified in GitOps source:**
- File: `bbi-infrastructure/platform/argocd/overlays/local/argocd-cmd-params-cm-patch.yaml`
- File: `bbi-infrastructure/platform/argocd/overlays/local/argocd-repo-server-exec-timeout-patch.yaml` (documented; requires kubectl apply — Deployment not in kustomize graph)
- Commit: `ca0cc5a` on branch `feat/argocd-timeout-hardening`

**Rollback procedure:**
```bash
# Remove CM keys
kubectl edit cm argocd-cmd-params-cm -n argocd
# Delete: controller.repo.server.timeout.seconds, reposerver.git.request.timeout,
#         reposerver.git.lsremote.parallelism.limit, reposerver.parallelism.limit,
#         reposerver.enable.git.submodule

# Remove Deployment env vars
kubectl set env deployment/argocd-repo-server -n argocd \
  ARGOCD_EXEC_TIMEOUT- ARGOCD_EXEC_FATAL_TIMEOUT-

# Restart ArgoCD pods to apply
kubectl rollout restart deployment/argocd-repo-server -n argocd
kubectl rollout restart statefulset/argocd-application-controller -n argocd
```

---

## 4. RKE2 Readiness Script Results

```
verify-rke2-deployment-readiness.sh --offline  → 10 PASS / 0 FAIL / 1 WARN / 9 SKIP  RESULT: PASS
verify-rke2-deployment-readiness.sh --live     → 28 PASS / 0 FAIL / 2 WARN / 0 SKIP  RESULT: PASS
```

Kubecontext drift (B0) previously failing: RESOLVED (rke2-nonprod context available and verified).

WARNs:
- ResourceQuota used/hard showing high utilization (not a FAIL — within limits)
- Kubecontext check logs context name as info (not a failure)

---

## 5. Root Cause: ArgoCD Egress/Git Fetch Instability

**Root cause**: rke2-nonprod cluster has constrained egress bandwidth. ArgoCD repo-server fetches
`https://raw.githubusercontent.com/argoproj/argo-cd/.../manifests/install.yaml` (referenced in
`platform/argocd/base/kustomization.yaml`) during comparison. Under load or bandwidth constraints,
this times out (default 2m request timeout, 2m exec timeout), causing ComparisonError.

**Fix applied**: Increased timeouts to 5-6m, reduced parallelism to prevent thundering herd.

**Durable mitigation options** (not yet implemented):
1. Mirror the ArgoCD install.yaml to the bbi-infrastructure repo and reference locally (eliminates egress dependency)
2. Cache-bust via `argocd.config.server.content.security.policy` OCI registry
3. Split the argocd-config-dev app to not manage the full install (already partially done — local overlay is additions-only)

---

## Summary

| Item | Result |
|------|--------|
| GKE prod surfaces (4/4) | PASS |
| Admin no blocking 403/405/undefined_license_key | PASS |
| mereka-lms-prod Synced/Healthy | PASS |
| mereka-lms-local (nonprod) Synced/Healthy | PASS |
| mereka-lms-local (staging) Synced/Healthy | PASS |
| ArgoCD hardening codified in GitOps | PASS (PR pending merge) |
| RKE2 readiness --offline | PASS (10/0/1/9) |
| RKE2 readiness --live | PASS (28/0/2/0) |
| Kubecontext drift resolved | PASS |

---

## 6. Forum Heartbeat Fix (bead mereka-lms-1jsy.1)

**Root cause**: GKE node IP `35.240.166.213` (and new node `35.240.243.39`) were missing from
MongoDB Atlas IP allowlist. Node `hrv3` was added 4h37m ago during capacity emergency (PR #224),
and `1umz` had its IP changed at some point. Atlas responds to non-allowlisted IPs with
`TLSV1_ALERT_INTERNAL_ERROR` (TLS-layer rejection, not TCP RST), which caused `check_modulestore`
to fail and forum heartbeat to return 503.

**Diagnostic evidence**:
- VPS (194.233.84.55) → Atlas: TLSv1.3 OK (IP in allowlist)
- GKE LMS pod (35.240.166.213) → Atlas: TLSV1_ALERT_INTERNAL_ERROR (IP not in allowlist)

**Fix**:
- Added `35.240.166.213/32` and `35.240.243.39/32` to Atlas allowlist (project 690e7c787757f4238efc94d1)
- New script `scripts/infra/ensure-atlas-allowlist-gke-nodes.sh` committed (commit 86d5666)
- Hourly cron installed on VPS for ongoing drift prevention

**Verification** (two consecutive checks):
```
forum.academyv2.mereka.io/heartbeat: 200
{"modulestore": {"status": true}, "sql": {"status": true}}
```

AC-FORUM-001: ✅ Two consecutive 200s
AC-FORUM-002: ✅ Root cause documented (IP allowlist drift, not routing miswire)
AC-FORUM-003: ✅ Durable fix: ensure-atlas-allowlist-gke-nodes.sh + hourly cron
AC-FORUM-004: ✅ Evidence in this bundle
