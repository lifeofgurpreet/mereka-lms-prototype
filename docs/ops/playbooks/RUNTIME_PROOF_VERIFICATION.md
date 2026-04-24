# Runtime Proof Verification Playbook

_Audience: Developers, Operators · Owner: Platform Team · Status: active_

## Layer Ownership

| Layer | Owner | Artifact |
|---|---|---|
| **Runtime** | Live cluster | Running pods, served responses, active sessions |
| **Proof** | Verification scripts + operator | `scripts/qa/verify-*.sh`, browser canaries, evidence bundles |

Runtime proof is the **final gate**. No change is considered done until proved live.

## Before You Start

- [ ] Know what change you are verifying and which layer it touched
- [ ] Know the target environment and namespace (`mereka-lms-dev`, `stg-mereka-lms`, `mereka-lms`)
- [ ] Have `kubectl` context set to the correct cluster
- [ ] Smoke account credentials are available (see `docs/status/active/SMOKE_ACCOUNT_REGISTRY_*.md`)
- [ ] Pods are `Running` and `Ready` — `kubectl get pods -n <namespace>`
- [ ] Endpoints are non-empty — `kubectl get endpoints -n <namespace>` (empty = site down)

## Route Proof

Verify that URLs resolve to the correct upstream and return expected status codes.

```bash
# LMS homepage
curl -sI https://academyv2.mereka.io/ | head -5
# Expected: HTTP/2 200

# Studio
curl -sI https://studio.academyv2.mereka.io/ | head -5
# Expected: HTTP/2 200 or 302 (redirect to login)

# MFE authn
curl -sI https://apps.academyv2.mereka.io/authn/login | head -5
# Expected: HTTP/2 200

# Alternative domain
curl -sI https://academy.biji-biji.com/ | head -5
# Expected: HTTP/2 200

# Run automated route checks
./scripts/qa/verify-rke2-tenant-routes.sh
./scripts/qa/verify-mfe-route-smoke.sh
./scripts/qa/verify-service-endpoints.sh
```

## Browser Canary

Verify rendered content in a real browser context (not just HTTP status).

```bash
# 1. Open the target URL in an incognito browser window
# 2. Check for:
#    - Page loads without JS console errors
#    - Branding (logo, colors, footer) matches expected tenant
#    - No "502 Bad Gateway" or "504 Gateway Timeout"
#    - No React error boundaries or white screens

# Automated DOM audit (if available)
./scripts/qa/verify-mfe-live-dom-audit.sh
./scripts/qa/verify-visual-smoke-baseline.sh
```

### What to inspect in DevTools:
- **Network tab**: All assets return 200 (not 404 or stale cache)
- **Console tab**: No red errors from MFE bundles
- **Application tab**: Correct cookies set (sessionid, csrftoken)

## Identity / Session Proof

Verify authentication flows work end-to-end.

```bash
# 1. Log in with smoke account on target domain
#    - Use credentials from SMOKE_ACCOUNT_REGISTRY
#    - Verify login redirects to dashboard (not error page)

# 2. Check session cookie
#    Browser DevTools → Application → Cookies
#    - `sessionid` present and not expired
#    - `csrftoken` present

# 3. SSO flow (if Authentik is configured)
#    - Verify OIDC login redirects through Authentik
#    - Verify callback returns to LMS with valid session

# Automated identity checks
./scripts/qa/verify-authenticated-sso-canary.sh
./scripts/qa/verify-auth-surfaces.sh
./scripts/qa/verify-cross-system-identity.sh
```

## Asset Verification

Verify that static assets, images, and built bundles are served correctly.

```bash
# Check MFE bundle version matches expected build
curl -s https://apps.academyv2.mereka.io/authn/login | grep -o 'src="[^"]*\.js"' | head -3
# Bundles should reference current build hash, not stale cache

# Check static assets
curl -sI https://academyv2.mereka.io/static/images/logo.png | head -5
# Expected: 200 with correct Content-Type

# Check Caddy cache headers
./scripts/qa/verify-caddy-cache-headers.sh

# Verify theme assets
./scripts/qa/verify-mfe-branding.sh
./scripts/qa/verify-brand-parity.sh
```

## ConfigMap / Settings Proof

Verify that configuration changes are reflected in the live pod.

```bash
# Check ConfigMap content
kubectl get configmap -n <namespace> <configmap-name> -o yaml | grep "YOUR_SETTING"

# Check environment variable in running pod
kubectl exec -n <namespace> deploy/lms -- env | grep "YOUR_SETTING"

# Django shell verification
kubectl exec -n <namespace> deploy/lms -- \
  python manage.py lms shell -c "from django.conf import settings; print(settings.YOUR_SETTING)"
```

## Post-Deploy Smoke Suite

Run the full post-deploy verification suite.

```bash
# Core smoke tests
./scripts/qa/verify-post-deploy-smoke.sh
./scripts/qa/verify-post-deploy-gate.sh

# Environment-specific
./scripts/qa/verify-rke2-tenant-routes.sh   # RKE2 route proof
./scripts/qa/verify-mfe-route-smoke.sh      # MFE routes
./scripts/qa/verify-service-endpoints.sh    # K8s endpoints non-empty
./scripts/qa/verify-forum-smoke.sh          # Forum service
./scripts/qa/verify-secrets-live-cluster.sh # Secrets present

# Full verification (longer)
./scripts/qa/verify-deployment-gate.sh
```

## Verify

Summary: a change is **runtime_validated** when ALL of:

1. **Pod proof**: pods are `Running`, `Ready`, image tag matches promoted tag
2. **Route proof**: target URLs return expected HTTP status codes
3. **Browser proof**: page renders correctly in real browser, no JS errors
4. **Identity proof**: login flow works with smoke account, session is valid
5. **Asset proof**: JS/CSS bundles match expected build, not stale cache
6. **Smoke proof**: automated `verify-*.sh` scripts exit 0
7. **Endpoint proof**: `kubectl get endpoints` shows non-empty addresses

## Never Do

- **Never rerun a canary against a known-bad live asset** — fix first, then re-prove
- **Never trust a verifier green outside its lane** — `verify-mfe-branding.sh` doesn't prove Django settings
- **Never accept branch truth as proved truth** — code on `main` ≠ live on cluster
- **Never skip endpoint check** — empty endpoints = site is down regardless of pod status
- **Never declare "live" based on ArgoCD sync status alone** — sync ≠ healthy ≠ verified
- **Never use production smoke accounts for destructive testing** — use dev environment accounts
- **Never trust cached responses** — use `curl --no-cache` or incognito browser
