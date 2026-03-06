# 5ngf.2 / 288f: RKE2 ArgoCD GitHub Connectivity — Root Cause + Fix

> **Date**: 2026-02-19T21:20 UTC
> **Context**: rke2-nonprod, argocd namespace
> **App**: mereka-lms-local (Unknown/ComparisonError)

---

## Network Diagnosis (from argocd-repo-server pod)

### HTTPS to github.com — BLOCKED
```bash
kubectl --context rke2-nonprod exec -n argocd deploy/argocd-repo-server -- \
  git ls-remote https://github.com/Biji-Biji-Initiative/mereka-lms.git HEAD
# Result: fatal: could not read Username for 'https://github.com': No such device or address
# = DNS resolution failure or port 443 blocked by NetworkPolicy
```

### SSH to github.com — WORKS (TCP connects)
```bash
kubectl --context rke2-nonprod exec -n argocd deploy/argocd-repo-server -- \
  git ls-remote ssh://git@github.com/Biji-Biji-Initiative/mereka-lms.git HEAD
# Result: Host key verification failed.
# = TCP port 22 reaches github.com. Blocked only by missing SSH host key trust.
# This is FIXABLE.
```

**Root cause**: Cilium NetworkPolicy (or CNI config) on rke2-nonprod blocks HTTPS (port 443)
egress from `argocd` namespace to `github.com`, but allows SSH (port 22).

---

## Repo Secret State

`argocd-repo-mereka-lms` secret exists with correct label:
```
NAME                     TYPE     LABELS
argocd-repo-mereka-lms   Opaque   argocd.argoproj.io/secret-type=repository
url:      https://github.com/Biji-Biji-Initiative/mereka-lms.git
username: x-access-token
password: <redacted>
```

Secret is correct but useless — HTTPS is blocked at the network layer, not auth layer.

---

## Fix (bbi-infrastructure team)

### Option A: Switch kustomization remote URL to SSH (Recommended — fastest)

In `bbi-infrastructure: apps/mereka-lms/overlays/profiles/dev/kustomization.yaml`,
change the remote resource reference from HTTPS to SSH:

```yaml
# BEFORE (broken — HTTPS blocked):
resources:
  - https://github.com/Biji-Biji-Initiative/mereka-lms.git//deploy/k8s/base?ref=<commit>

# AFTER (fix — SSH works):
resources:
  - git@github.com:Biji-Biji-Initiative/mereka-lms.git//deploy/k8s/base?ref=<commit>
```

Then update the ArgoCD repo secret to use SSH format and add a deploy key:

```bash
# 1. Generate deploy key (or reuse existing):
ssh-keygen -t ed25519 -C "argocd-rke2-mereka-lms" -f /tmp/mereka-lms-deploy-key -N ""

# 2. Add public key as Deploy Key in GitHub:
# GitHub → Biji-Biji-Initiative/mereka-lms → Settings → Deploy Keys → Add key
# Paste contents of /tmp/mereka-lms-deploy-key.pub

# 3. Create ArgoCD repo secret with SSH:
kubectl --context rke2-nonprod delete secret argocd-repo-mereka-lms -n argocd
kubectl --context rke2-nonprod create secret generic argocd-repo-mereka-lms \
  -n argocd \
  --from-literal=url=git@github.com:Biji-Biji-Initiative/mereka-lms.git \
  --from-literal=sshPrivateKey="$(cat /tmp/mereka-lms-deploy-key)" \
  --from-literal=insecureIgnoreHostKey=true
kubectl --context rke2-nonprod label secret argocd-repo-mereka-lms \
  -n argocd "argocd.argoproj.io/secret-type=repository"

# 4. Force hard refresh:
kubectl --context rke2-nonprod annotate app mereka-lms-local \
  -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

### Option B: Allow HTTPS egress in Cilium NetworkPolicy

Add a CiliumNetworkPolicy allowing `argocd` namespace pods to reach `github.com:443`:
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: argocd-github-egress
  namespace: argocd
spec:
  endpointSelector: {}
  egress:
    - toFQDNs:
        - matchName: "github.com"
        - matchName: "*.github.com"
        - matchName: "objects.githubusercontent.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
```

---

## Current State

| Check | Status |
|-------|--------|
| `mereka-lms-local` app exists | ✅ |
| ArgoCD repo secret created | ✅ |
| HTTPS to github.com | ❌ Blocked |
| SSH to github.com | ✅ TCP reachable |
| ExternalSecrets synced | ❌ (blocked upstream) |
| LMS pods running | ❌ (blocked upstream) |

**Single remaining blocker**: Switch kustomization to SSH + add SSH deploy key to ArgoCD.
Once done, `mereka-lms-local` should reach `Synced/Healthy` → unblocks 288f, 5ngf.2, aza7.
