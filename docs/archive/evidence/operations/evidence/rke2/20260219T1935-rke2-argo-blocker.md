# 5ngf.2: RKE2 ArgoCD Blocker Evidence

> **Date**: 2026-02-19T19:35 UTC
> **Context**: rke2-nonprod
> **App**: mereka-lms-local
> **Status**: ComparisonError → BLOCKED

---

## Current ArgoCD App State

```
mereka-lms-local   Unknown   Healthy
```

App source:
```
Repo URL:         https://github.com/Biji-Biji-Initiative/bbi-infrastructure.git
Path:             apps/mereka-lms/overlays/profiles/dev
Target Revision:  main
Destination:      namespace=mereka-lms, server=https://kubernetes.default.svc
```

---

## Exact Error (ComparisonError)

```
Failed to load target state: failed to generate manifest for source 1 of 1:
rpc error: code = Unknown desc = Manifest generation error (cached):
`kustomize build <path>/apps/mereka-lms/overlays/profiles/dev --load-restrictor LoadRestrictionsNone`
failed exit status 1:

# Warning: 'patchesJson6902' is deprecated. Please use 'patches' instead.
# Run 'kustomize edit fix' to update your Kustomization automatically.

Error: accumulating resources: ... accumulating resources from
'https://github.com/Biji-Biji-Initiative/mereka-lms.git//deploy/k8s/base?ref=fc3441823080f4ab4a2efa8105fdfbec5f1a3d6f':
URL is a git repository':
hit 27s timeout running '/usr/bin/git fetch --depth=1
  https://github.com/Biji-Biji-Initiative/mereka-lms.git
  fc3441823080f4ab4a2efa8105fdfbec5f1a3d6f'
```

---

## Root Cause Analysis

The kustomization at `apps/mereka-lms/overlays/profiles/dev` (in bbi-infrastructure repo)
references a **remote GitHub URL** for the mereka-lms base:

```yaml
# In bbi-infrastructure: apps/mereka-lms/overlays/profiles/dev/kustomization.yaml
# (approximate — actual in bbi-infrastructure repo)
resources:
  - https://github.com/Biji-Biji-Initiative/mereka-lms.git//deploy/k8s/base?ref=fc3441823080f4ab4a2efa8105fdfbec5f1a3d6f
```

ArgoCD's repo-server on rke2-nonprod **cannot reach GitHub** (times out after 27s).
This is an outbound network connectivity issue — the RKE2 cluster's ArgoCD cannot fetch from GitHub.

**Commit `fc3441823080f4ab4a2efa8105fdfbec5f1a3d6f`** exists in mereka-lms (verified locally).

**Secondary issue**: `patchesJson6902` deprecated (minor, cosmetic).

---

## ExternalSecrets + Pods State

```bash
kubectl --context rke2-nonprod get externalsecret -n mereka-lms
# No resources found in mereka-lms namespace.

kubectl --context rke2-nonprod get pods -n mereka-lms
# No resources found in mereka-lms namespace.
```

Nothing deployed — blocked upstream at kustomize build step.

---

## Required Actions (bbi-infrastructure team)

### Option A (Preferred): Fix ArgoCD GitHub Outbound Access

Ensure ArgoCD repo-server on rke2-nonprod can reach `https://github.com`:
```bash
# From rke2-nonprod cluster, test connectivity:
kubectl --context rke2-nonprod exec -n argocd deploy/argocd-repo-server -- \
  git ls-remote https://github.com/Biji-Biji-Initiative/mereka-lms.git HEAD
```

If this times out → check cluster CNI/egress rules for `github.com:443`.
Cilium NetworkPolicy may be blocking egress; check `argocd` namespace egress policy.

### Option B: Change Remote Reference to Relative Path

Modify `bbi-infrastructure: apps/mereka-lms/overlays/profiles/dev/kustomization.yaml`
to use a relative path instead of a remote URL — requires bbi-infrastructure to inline or
vendor the mereka-lms base manifests.

### Option C: Add ArgoCD Repository Credentials

If it's auth (not connectivity), add a GitHub Deploy Key or PAT to ArgoCD:
```bash
kubectl --context rke2-nonprod create secret generic mereka-lms-repo \
  -n argocd \
  --from-literal=url=https://github.com/Biji-Biji-Initiative/mereka-lms.git \
  --from-literal=username=<github-user> \
  --from-literal=password=<github-pat>
kubectl --context rke2-nonprod label secret mereka-lms-repo \
  -n argocd "argocd.argoproj.io/secret-type=repository"
```

### Deprecation Fix (minor)

```bash
# In bbi-infrastructure, in the kustomization directory:
kustomize edit fix
git commit -m "fix: replace deprecated patchesJson6902 with patches"
```

---

## 5ngf.2 Resume Gate (unchanged)

Will start 5ngf.2 immediately when ALL of these pass:

| # | Condition | Command |
|---|-----------|---------|
| 1 | ArgoCD app exists | `kubectl --context rke2-nonprod get app -n argocd mereka-lms-local` → **Synced/Healthy** (not Unknown) |
| 2 | ExternalSecrets synced | `kubectl --context rke2-nonprod get externalsecret -n mereka-lms` → SecretSynced |
| 3 | Pods Running | `kubectl --context rke2-nonprod get pods -n mereka-lms` → lms/cms/caddy Running |
| 4 | DNS resolves | `curl -I https://lms.staging.mereka.dev` → HTTP 200 |
