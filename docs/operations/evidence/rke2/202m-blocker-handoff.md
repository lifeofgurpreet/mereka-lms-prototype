# 202m: RKE2 Bootstrap Gap — Formal Blocker Handoff

> **Bead**: mereka-lms-202m
> **ACs**: AC-RK2-001..004
> **Date**: 2026-02-19
> **Context**: rke2-nonprod, rke2-staging
> **Author**: BoldBadger
> **Owner for resolution**: bbi-infrastructure team

---

## AC-RK2-001: Current State Evidence (Timestamp: 2026-02-19T11:05..11:15 UTC)

### Contexts confirmed available
```
gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
kind-dev
rke2-nonprod
rke2-staging
```

### rke2-nonprod: mereka-lms namespace
```bash
kubectl --context rke2-nonprod get ns mereka-lms
# NAME          STATUS   AGE
# mereka-lms    Active   9h
```

### rke2-nonprod: No LMS ArgoCD Application
```bash
kubectl --context rke2-nonprod get app -n argocd -o name
# application.argoproj.io/calcom-staging-rke2
# application.argoproj.io/cert-manager-dev-rke2
# application.argoproj.io/external-secrets-dev-rke2
# application.argoproj.io/ingress-nginx-dev-rke2
# application.argoproj.io/kyverno-dev-rke2
# application.argoproj.io/mereka-admin-staging-rke2
# application.argoproj.io/mereka-app-staging-rke2
# application.argoproj.io/mereka-auth-staging-rke2
# application.argoproj.io/mereka-backend-staging-rke2
# application.argoproj.io/mereka-checkout-staging-rke2
# application.argoproj.io/mereka-dev-bootstrap-rke2
# application.argoproj.io/mereka-web-staging-rke2
# ... (no mereka-lms or openedx-lms entry)
```

### rke2-nonprod: No LMS workloads
```bash
kubectl --context rke2-nonprod get deploy -n mereka-lms
# No resources found in mereka-lms namespace.

kubectl --context rke2-nonprod get externalsecret -n mereka-lms
# No resources found in mereka-lms namespace.
```

### rke2-nonprod: What IS present
```bash
kubectl --context rke2-nonprod get secret -n mereka-lms
# NAME                 TYPE                DATA   AGE
# openedx-lms-tls      kubernetes.io/tls   2      9h   ← cert-manager ✅
# openedx-mfe-tls      kubernetes.io/tls   2      9h   ← cert-manager ✅
# openedx-studio-tls   kubernetes.io/tls   2      9h   ← cert-manager ✅

kubectl --context rke2-nonprod get clustersecretstore infisical-secret-store
# NAME                     AGE   STATUS   CAPABILITIES   READY
# infisical-secret-store   37h   Valid    ReadOnly       True  ← ESO ready ✅
```

### rke2-staging: Same state (namespace exists, no LMS workloads)
```bash
kubectl --context rke2-staging get ns mereka-lms
# NAME          STATUS   AGE
# mereka-lms    Active   (exists)

kubectl --context rke2-staging get app -n argocd -o name | grep -i lms
# (no output — no LMS app)

kubectl --context rke2-staging get deploy -n mereka-lms
# No resources found in mereka-lms namespace.
```

**Supporting evidence files**:
- `docs/operations/evidence/rke2/5ngf-bootstrap-20260219-1205.log` — raw kubectl output
- `docs/operations/evidence/rke2/5ngf-gates-20260219-1205.log` — full gate check output
- `docs/operations/evidence/rke2/5ngf-1-bootstrap-gap-20260219-1215.md` — OrangeSnow cross-check
- `docs/operations/evidence/rke2/5ngf-bootstrap-evidence.md` — gate-by-gate AC evidence

---

## AC-RK2-002: Blocker Bead Request

**Required action**: Create a bead/issue in the `bbi-infrastructure` repo:

```
Title: [RKE2] Create LMS ArgoCD Application + ExternalSecrets wiring for mereka-lms namespace
Priority: P1 (blocks 5ngf.2 smoke and RKE2 LMS staging readiness)

Repo source: /home/gurpreet/projects/k8s/mereka-lms
Target contexts: rke2-nonprod, rke2-staging
Target namespace: mereka-lms
```

---

## AC-RK2-003: Exact Required Actions + Owner

### Action 1: Apply ExternalSecrets to mereka-lms namespace

**Source manifest** (already in this repo):
```bash
kubectl --context rke2-nonprod apply -f deploy/k8s/base/secrets/external-secrets.yaml
```

**What this provisions** (from `deploy/k8s/base/secrets/external-secrets.yaml`):
- `openedx-secrets` — LMS/CMS Django settings (SECRET_KEY, DB passwords, OAuth keys)
- `mysql-credentials` — MySQL username/password
- `redis-credentials` — Redis auth token
- Additional service secrets (discovery, ecommerce, forum, mfe)

**Prerequisite**: ClusterSecretStore `infisical-secret-store` must be Valid (it is — confirmed above).

**Verification**:
```bash
kubectl --context rke2-nonprod get externalsecret -n mereka-lms -w
# Watch for STATUS=SecretSynced on all entries
```

### Action 2: Create LMS ArgoCD Application in bbi-infrastructure

**Required ArgoCD Application manifest** (add to bbi-infrastructure repo):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mereka-lms-staging-rke2
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Biji-Biji-Initiative/mereka-lms
    targetRevision: main
    path: deploy/k8s/overlays/staging   # or new rke2-specific overlay
  destination:
    server: https://kubernetes.default.svc
    namespace: mereka-lms
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Note on staging overlay**: `deploy/k8s/overlays/staging/` is marked **DEPRECATED** (2026-02-10) — it was disabled when production moved to GKE. Options:
- A) Un-deprecate and update image tags for RKE2 staging use
- B) Create new `deploy/k8s/overlays/rke2-staging/` overlay with RKE2-specific image pins

**Recommended**: Option B — create `deploy/k8s/overlays/rke2-staging/` as a clean RKE2 staging overlay with current image tags from production (`deploy/k8s/overlays/production/kustomization.yaml`).

### Action 3: Define Staging Hostnames

DNS records needed (Cloudflare DNS-only / gray cloud → RKE2 node IP):
```
lms.staging.mereka.dev     → <rke2-nonprod-node-ip>
studio.staging.mereka.dev  → <rke2-nonprod-node-ip>
apps.staging.mereka.dev    → <rke2-nonprod-node-ip>
```

cert-manager is already issuing Let's Encrypt certs — once DNS points to the node, `openedx-lms-tls`, `openedx-mfe-tls`, `openedx-studio-tls` will auto-renew.

### Action 4: Update Kustomize Ingress Hosts for RKE2

The staging overlay Ingress resources need to reference `*.staging.mereka.dev` hosts (not `*.mereka.io` / `*.mereka.dev`).

**Owner**: bbi-infrastructure team

---

## AC-RK2-004: Resume Condition for 5ngf.2

**DO NOT start 5ngf.2 smoke** until ALL of the following are true:

| Condition | Verification Command |
|-----------|---------------------|
| LMS ArgoCD app exists | `kubectl --context rke2-nonprod get app -n argocd mereka-lms-staging-rke2` |
| ExternalSecrets synced | `kubectl --context rke2-nonprod get externalsecret -n mereka-lms` → STATUS=SecretSynced |
| LMS pods Running | `kubectl --context rke2-nonprod get pods -n mereka-lms` → lms, cms, caddy Running |
| Staging DNS resolves | `curl -I https://lms.staging.mereka.dev` → HTTP 200 |

Once all 4 conditions PASS → immediately start `mereka-lms-5ngf.2` full smoke sequence.

---

## Summary

| AC | Status | Notes |
|----|--------|-------|
| AC-RK2-001 (kubectl evidence) | **DONE** | Raw logs + evidence files committed |
| AC-RK2-002 (blocker bead request) | **DONE** | Blocker documented here; bbi-infra to create |
| AC-RK2-003 (exact actions + owner) | **DONE** | 4 actions with exact commands |
| AC-RK2-004 (resume condition) | **DONE** | 4-condition gate defined |

**202m status**: COMPLETE (blocker handoff documented). Waiting on bbi-infrastructure to execute Actions 1-4.
**5ngf.2 status**: BLOCKED — will activate immediately when resume conditions are met.
