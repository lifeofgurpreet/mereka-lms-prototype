# Deploy Evidence Gates for RKE2 Parity
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-04-21 • Status: active_

> **Bead**: mereka-lms-3qy2
> **Date**: 2026-02-18
> **Cluster**: rke2-prod

## Redaction Requirement

Evidence committed to `docs/**/evidence/**` MUST redact sensitive headers/tokens.
Use:

- `set-cookie: <REDACTED>`
- `authorization: <REDACTED>`

See `docs/policies/operations/EVIDENCE_REDACTION_POLICY.md`.

## 1. RKE2/Dev Parity Proof Commands (AC-OPS-301)

### Route Parity

```bash
# RKE2 production (`rke2-prod`) routes
curl -sI https://academyv2.mereka.io | head -1              # LMS: HTTP/2 200
curl -sI https://studio.academyv2.mereka.io | head -1       # CMS: HTTP/2 200 or 302
curl -sI https://apps.academyv2.mereka.io | head -1          # MFE: HTTP/2 200
curl -sI https://academy.biji-biji.com | head -1             # Alt domain: HTTP/2 200

# Kind dev routes (if running)
curl -sI http://localhost | head -1                           # LMS
curl -sI http://studio.localhost | head -1                    # CMS
curl -sI http://apps.localhost | head -1                      # MFE
```

### Rollout Status

```bash
CTX="rke2-prod"
NS="mereka-lms"

# All deployments should show READY = desired count
kubectl --context $CTX get deployments -n $NS \
  -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,DESIRED:.spec.replicas,UP-TO-DATE:.status.updatedReplicas'

# No pods in error state
kubectl --context $CTX get pods -n $NS | grep -vE "Running|Completed"
```

### Ingress Health

```bash
# Endpoints must be non-empty for all core services
for svc in caddy lms cms mfe; do
  echo -n "$svc: "
  kubectl --context $CTX get endpoints $svc -n $NS -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "MISSING"
  echo ""
done
```

### Authn Shell Verification

```bash
# LMS auth check — verify OIDC redirect works
curl -sI "https://academyv2.mereka.io/auth/login/oidc/" | grep -E "HTTP|Location"
# Expected: HTTP/2 302 → auth0.mereka.io

# Studio OAuth2 check
curl -sI "https://studio.academyv2.mereka.io/login/" | grep -E "HTTP|Location"
# Expected: HTTP/2 302 → academyv2.mereka.io/oauth2/authorize

# MFE config API
curl -s "https://apps.academyv2.mereka.io/api/mfe_config/v1" | python3 -m json.tool | head -5
```

## 2. Brand/Analytics Verification Gates (AC-OPS-302)

### Pre-Deploy Branding Gate

```bash
# Verify branding assets in image
kubectl --context $CTX exec -n $NS deployment/lms -- \
  ls /openedx/staticfiles/mereka-theme/ 2>/dev/null | head -5

# Verify theme is active
kubectl --context $CTX exec -n $NS deployment/lms -- \
  python manage.py lms shell -c "from django.conf import settings; print('THEME:', settings.DEFAULT_SITE_THEME)"

# Verify logo URL returns 200
curl -sI "https://academyv2.mereka.io/static/mereka-theme/images/logo.png" | head -1
```

### Pre-Deploy Analytics Gate

```bash
# Verify tracking log path exists and is writable
kubectl --context $CTX exec -n $NS deployment/lms -- \
  python manage.py lms shell -c "from django.conf import settings; print('TRACKING_BACKENDS:', list(settings.TRACKING_BACKENDS.keys()) if hasattr(settings, 'TRACKING_BACKENDS') else 'NOT_SET')"
```

## 3. Post-Deploy Incident and Rollback Matrix (AC-OPS-303)

| Symptom | Detection Command | Rollback Action | Severity |
|---------|-------------------|-----------------|----------|
| 502 on all routes | `curl -sI https://academyv2.mereka.io` → 502 | `git revert HEAD && git push` in both repos; ArgoCD auto-syncs | P1 |
| LMS pods CrashLoopBackOff | `kubectl get pods -n mereka-lms \| grep CrashLoop` | Check logs: `kubectl logs -n mereka-lms deploy/lms --tail=50`; revert if config issue | P1 |
| MFE blank page | `curl -s https://apps.academyv2.mereka.io \| grep -c "root"` → 0 | Check MFE pod logs; verify MFE image tag matches expected | P2 |
| Auth redirect loop | `curl -sI https://academyv2.mereka.io/auth/login/oidc/ -L --max-redirs 3` → exceeds | Check `SESSION_COOKIE_*` settings; verify Authentik is reachable | P2 |
| Empty endpoints | `kubectl get endpoints caddy -n mereka-lms` → `<none>` | Run `./scripts/infra/fix-service-selectors.sh` | P1 |
| ArgoCD OutOfSync | `kubectl get application -n argocd \| grep mereka-lms` → OutOfSync | Check base ref SHA matches HEAD; force sync: `argocd app sync mereka-lms-prod` | P2 |
| Stale image (old tag running) | `kubectl get deploy lms -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].image}'` | Verify kustomization tags match; restart: `kubectl rollout restart deploy/lms -n mereka-lms` | P3 |

## 4. Release PR Artifact List (AC-OPS-304)

Every release PR must include:

| Artifact | Location | Required? |
|----------|----------|-----------|
| Image tags | PR body: openedx tag + mfe tag | **Yes** |
| Dry-run output | PR body or comment: `canonical-release.sh --dry-run` output | **Yes** |
| Preflight check | PR body: `canonical-release.sh --check-only` output | **Yes** |
| Route health | PR comment: curl output for LMS/CMS/MFE URLs | **Yes** |
| Pod status | PR comment: `kubectl get pods -n mereka-lms` | **Yes** |
| Endpoint check | PR comment: `kubectl get endpoints -n mereka-lms` | **Yes** |
| ArgoCD sync status | PR comment: application sync/health | **Yes** |
| Branding verification | PR comment: logo + theme check output | Recommended |
| Cache check result | PR body: cache hit/miss from dry-run | Recommended |

## 5. Cache Reuse Policy (AC-OPS-305)

### Default: Cache Reuse

If `canonical-release.sh --dry-run` reports "cache hit" for both images, **skip the build step**. The existing images in GHCR are identical.

### Justified Full-Rebuild Exceptions

| Trigger | Why Full Rebuild |
|---------|-----------------|
| `apply-patches.sh` changed | Patches modify Dockerfile templates; must rebuild |
| `requirements/` changed | New Python dependencies; must rebuild openedx |
| `infrastructure/tutor/themes/` changed | Branding assets baked into image; must rebuild |
| MFE source changed (frontend-app-*) | New JS bundle; must rebuild mfe |
| Node/Python version bump | Base image change; must rebuild both |
| Security advisory (CVE) | Need fresh base layer; must rebuild both |
| Cache digest mismatch | Image was re-tagged or modified externally; rebuild |

### Cache Lock Mechanism

Cache digests stored in `var/build-cache/` (gitignored). Format: `<image>_<tag>.digest` containing the sha256 digest from GHCR.

To force a full rebuild regardless of cache:
```bash
rm -rf var/build-cache/
./scripts/infra/canonical-release.sh --dry-run --openedx-tag <TAG> --mfe-tag <MFE_TAG>
# Will show "cache miss" for both, triggering rebuild
```
