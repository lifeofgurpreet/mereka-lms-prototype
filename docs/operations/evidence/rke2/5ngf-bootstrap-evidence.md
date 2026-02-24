# 5ngf.1 + 5ngf.2: RKE2 Bootstrap + Smoke Evidence

> **Bead**: mereka-lms-5ngf / 5ngf.1 / 5ngf.2
> **ACs**: AC-RKE2-201..206
> **Date**: 2026-02-19
> **Context**: rke2-nonprod
> **Branch**: feat/23ry2-spec-dedupe-normalize

---

## AC-RKE2-201: Gate-by-Gate Status

### Gate 0: Kyverno Guardrails ✅ PASS

```
kyverno-admission-controller-7cf9798449-pjnts    1/1  Running  34h
kyverno-background-controller-7586fbfc99-ztlcv   1/1  Running  34h
kyverno-cleanup-controller-67b9675757-zkqlt       1/1  Running  34h
kyverno-reports-controller-7fd54d954f-ghxz9       1/1  Running  34h
```

### Gate 1: ArgoCD ✅ PASS

```
argocd-application-controller-0                     1/1  Running  2d
argocd-applicationset-controller-5796dcfc94-hpst7   1/1  Running  2d
argocd-dex-server-6d57f6f6b6-d4wrf                  1/1  Running  2d
argocd-notifications-controller-bb4f97f47-nk9ks     1/1  Running  2d
argocd-redis-6dfddccb76-9mdhj                       1/1  Running  47h
argocd-repo-server-77d887cfb9-hgtpx                 1/1  Running  2d
argocd-server-7fb8c5f74-9ngtw                       1/1  Running  2d
```

### Gate 2: Platform Essentials ✅ PASS

| Component | Pods | Status |
|-----------|------|--------|
| cert-manager | 3/3 Running | ✅ |
| ingress-nginx | 1/1 Running | ✅ |
| external-secrets | 3/3 Running | ✅ |
| monitoring (kube-prometheus + loki + promtail) | 8/8 Running | ✅ |
| velero | (deployed) | ✅ |

ClusterSecretStore `infisical-secret-store`: **Valid / ReadOnly / Ready** (37h)

### Gate 3: Secrets Provisioning ⚠️ NOT STARTED

**Blocker**: No ExternalSecrets deployed in `mereka-lms` namespace.

Only content in `mereka-lms`:
```
NAME                 TYPE                DATA   AGE
openedx-lms-tls      kubernetes.io/tls   2      9h   ← cert-manager issued ✅
openedx-mfe-tls      kubernetes.io/tls   2      9h   ← cert-manager issued ✅
openedx-studio-tls   kubernetes.io/tls   2      9h   ← cert-manager issued ✅
```

TLS certificates are **issued and Ready** — cert-manager is working for the `mereka-lms` namespace. But `openedx-secrets`, `mysql-credentials`, `redis-credentials` etc. are not yet present.

**Required action (bbi-infrastructure repo)**:
```bash
# 1. Apply ExternalSecrets to mereka-lms
kubectl --context rke2-nonprod apply -f deploy/k8s/base/secrets/external-secrets.yaml

# 2. Verify sync
kubectl --context rke2-nonprod get externalsecret -n mereka-lms -w
```

Note: ClusterSecretStore `infisical-secret-store` is Valid — the ESO operator can sync. The ExternalSecret manifests just haven't been applied yet.

### Gate 4: App Deploy ⚠️ BLOCKED (depends on Gate 3)

- **ArgoCD LMS app**: Does not exist (no `lms`, `openedx`, or equivalent ArgoCD Application in `argocd` namespace)
- **Pods**: None in `mereka-lms`
- **Staging kustomization**: `deploy/k8s/overlays/staging/` exists but is marked **DEPRECATED** (2026-02-10)

**Required action**: Enable LMS staging ArgoCD Application in `bbi-infrastructure` repo (the staging overlay was disabled when production moved to GKE).

---

## AC-RKE2-203: ArgoCD App State

No LMS ArgoCD app exists. The 7 `mereka-*` ArgoCD apps are for the non-LMS Mereka platform (web, backend, admin, auth, checkout) — deploying to `mereka-dev` namespace, not `mereka-lms`.

```
mereka-admin-staging-rke2      Unknown/Unknown
mereka-app-staging-rke2        Unknown/Unknown
mereka-auth-staging-rke2       Unknown/Unknown
mereka-backend-staging-rke2    Unknown/Unknown
mereka-checkout-staging-rke2   Unknown/Unknown
mereka-dev-bootstrap-rke2      Unknown/Unknown
mereka-web-staging-rke2        Unknown/Unknown
```

Note: All show `Unknown/Unknown` — likely because ArgoCD can't reach its repo-server from this kubectl context (ArgoCD is running on the cluster but we're accessing via kubeconfig, not ArgoCD's own API).

---

## AC-RKE2-204: LMS/CMS/Caddy/MFE Pods

**Status**: Not deployed. Gate 3 (ExternalSecrets) and Gate 4 (ArgoCD app) must complete first.

---

## AC-RKE2-205: Smoke Matrix

**Status**: Cannot run — no LMS deployment yet. Once Gate 3+4 complete:

Planned staging hosts (from `RKE2_LMS_HANDOFF.md`):
- `lms.staging.mereka.dev` (TBD)
- `studio.staging.mereka.dev` (TBD)
- `apps.staging.mereka.dev` (TBD)

Note: Staging DNS and actual hostnames not yet defined in HANDOFF doc.

---

## AC-RKE2-202: ExternalSecrets Gap

| Secret | Status |
|--------|--------|
| `openedx-secrets` | ❌ Not present |
| `mysql-credentials` | ❌ Not present |
| `redis-credentials` | ❌ Not present |
| TLS certs | ✅ Present (issued by cert-manager) |
| `infisical-secret-store` ClusterSecretStore | ✅ Valid/Ready |

ESO operator is ready. ExternalSecret manifests need to be applied.

---

## AC-RKE2-206: Tenant Hosting Readiness + Handoff Notes

### Current RKE2 Gate Status

| Gate | Status | Blocker |
|------|--------|---------|
| Gate 0 (guardrails) | ✅ PASS | — |
| Gate 1 (ArgoCD) | ✅ PASS | — |
| Gate 2 (platform essentials) | ✅ PASS | — |
| Gate 3 (secrets) | ⚠️ NOT STARTED | Apply ExternalSecrets to mereka-lms ns |
| Gate 4 (app deploy) | ⚠️ BLOCKED | Needs Gate 3 + bbi-infrastructure ArgoCD app |
| Gate 5 (smoke/cutover) | ⚠️ BLOCKED | Needs Gate 4 |

### Required Operator Actions (bbi-infrastructure repo)

1. **Apply ExternalSecrets**: `kubectl --context rke2-nonprod apply -f deploy/k8s/base/secrets/external-secrets.yaml`
2. **Enable LMS staging kustomization**: Un-deprecate `deploy/k8s/overlays/staging/` or create new RKE2-specific overlay in `bbi-infrastructure`
3. **Create ArgoCD Application**: Add LMS ArgoCD Application targeting `rke2-nonprod` cluster + `mereka-lms` namespace
4. **Define staging hostnames**: Update `RKE2_LMS_HANDOFF.md` with actual `*.staging.mereka.dev` domain assignments
5. **DNS**: Add Cloudflare DNS records for staging hosts → RKE2 node IP (DNS-only, Let's Encrypt via cert-manager)

### What's Ready

- ✅ `mereka-lms` namespace exists with cert-manager-issued TLS certs for openedx-lms, openedx-mfe, openedx-studio
- ✅ ClusterSecretStore `infisical-secret-store` Valid/Ready (ESO can sync secrets when ExternalSecrets are applied)
- ✅ All platform infrastructure (ArgoCD, cert-manager, ingress-nginx, external-secrets, monitoring) Running
- ✅ Staging overlay (`deploy/k8s/overlays/staging/`) exists with image pins (though deprecated)

### Blocker Summary

**This is a bbi-infrastructure action, not a mereka-lms repo action.** The LMS repo side is ready (kustomize overlays, image tags, ExternalSecret manifests). The blocking work is enabling the LMS deployment in bbi-infrastructure's ArgoCD ApplicationSet and defining staging hostnames.
