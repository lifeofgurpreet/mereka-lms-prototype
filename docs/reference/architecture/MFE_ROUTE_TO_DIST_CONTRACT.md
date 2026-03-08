# MFE Route-to-Dist Contract

**Status**: ACTIVE
**Last updated**: 2026-02-17
**Owner**: Frontend Team
**Bead**: mereka-lms-115d.7

## Purpose

This contract ensures the three layers of MFE routing configuration remain in sync:

1. **Caddy routes** (Caddyfile): Maps URL prefixes to filesystem directories
2. **LMS URL settings** (production.py): Exposes MFE URLs to backend and MFE config API
3. **Branding verifier** (verify-mfe-branding.sh): Hardcoded route map for automated testing

**Why this matters**: Drift between these layers causes broken navigation, 404 errors, and inconsistent branding. The contract provides a single source of truth and automated verification.

## Architecture

### 3-Layer Routing Model

```
┌─────────────────────────────────────────────────────────────────┐
│                     Browser Request                             │
│                  GET /authn/login HTTP/1.1                      │
│                  Host: apps.academyv2.mereka.io                 │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LAYER 1: Caddy Routing                       │
│    File: deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile        │
│                                                                 │
│    @mfe_authn {                                                 │
│        path /authn /authn/*                                     │
│    }                                                            │
│    handle @mfe_authn {                                          │
│        uri strip_prefix /authn                                  │
│        root * /openedx/dist/authn      ← Directory mapping     │
│        try_files /{path} /index.html                            │
│        file_server                                              │
│    }                                                            │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                 LAYER 2: LMS Settings                           │
│   File: deploy/k8s/base/apps/openedx/settings/lms/production.py│
│                                                                 │
│   AUTHN_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/authn"     │
│   MFE_CONFIG["AUTHN_MICROFRONTEND_URL"] = AUTHN_MICROFRONTEND_URL│
│   MFE_CONFIG_API_URLS = {                                       │
│       'authn': f"{MEREKA_MFE_BASE_URL}/authn",                  │
│       ...                                                       │
│   }                                                             │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│               LAYER 3: Branding Verifier                        │
│         File: scripts/qa/verify-mfe-branding.sh                 │
│                                                                 │
│   declare -A MFE_ROUTES=(                                       │
│     ["/authn"]="authn"                                          │
│     ["/account"]="account"                                      │
│     ...                                                         │
│   )                                                             │
│                                                                 │
│   # Automated tests verify all 3 layers match                  │
└─────────────────────────────────────────────────────────────────┘
```

## Route Mapping Table

| URL Path | Directory | LMS Setting | Caddy Line | Verifier Line | Notes |
|----------|-----------|-------------|------------|---------------|-------|
| `/authn` | `authn` | `AUTHN_MICROFRONTEND_URL` | 37-45 | 93 | Login/registration |
| `/account` | `account` | `ACCOUNT_MICROFRONTEND_URL` | 47-55 | 94 | Settings, redirects /account/settings → /account/ |
| `/communications` | `communications` | `COMMUNICATIONS_MICROFRONTEND_URL` | 57-65 | 103 | Email preferences |
| `/course-authoring` | `course-authoring` | `MFE_CONFIG["COURSE_AUTHORING_MICROFRONTEND_URL"]` | 69-77 | 96 | Studio authoring (canonical path) |
| `/authoring` | `course-authoring` | (same as above) | 79-87 | 95 | Studio authoring (alias path, same dir) |
| `/discussions` | `discussions` | `DISCUSSIONS_MICROFRONTEND_URL` | 89-97 | 97 | Forum threads |
| `/gradebook` | `gradebook` | `WRITABLE_GRADEBOOK_URL` | 99-107 | 104 | Instructor gradebook |
| `/learner-dashboard` | `learner-dashboard` | `LEARNER_HOME_MICROFRONTEND_URL` | 109-117 | 98 | Learner home |
| `/learner-record` | `learner-record` | `LEARNER_RECORD_MICROFRONTEND_URL` | 190-198 | 99 | Learner record transcript UI |
| `/learning` | `learning` | `LEARNING_MICROFRONTEND_URL` | 119-127 | 99 | Courseware player |
| `/ora-grading` | `ora-grading` | `ORA_GRADING_MICROFRONTEND_URL` | 129-137 | 100 | Open response assessment grading |
| `/profile` | `profile` | `PROFILE_MICROFRONTEND_URL` | 139-147 | 102 | User profile editor |
| `/u` | `profile` | (same as /profile) | 151-158 | 101 | Username URL route (e.g., /u/alice) |

### Special Routes (Non-MFE)

| URL Path | Handler | Target | Purpose |
|----------|---------|--------|---------|
| `/api/mfe_config/v1*` | `reverse_proxy` | `lms:8000` | MFE runtime config API |
| `/login_refresh*` | `reverse_proxy` | `lms:8000` | JWT cookie refresh for MFEs |
| `/orders*` | `reverse_proxy` | `payments-gateway:8080` | Deprecated MFE replaced by custom service |
| `/payment*` | `reverse_proxy` | `payments-gateway:8080` | Deprecated MFE replaced by custom service |
| `/account/settings` | `redir 302` | `/account/` | Compatibility redirect (account MFE doesn't implement /settings) |

### Directory Structure in MFE Container

```
/openedx/dist/
├── authn/
│   ├── index.html
│   ├── static/
│   └── favicon.ico
├── account/
│   ├── index.html
│   └── static/
├── communications/
├── course-authoring/      # BOTH /authoring and /course-authoring serve this dir
├── discussions/
├── gradebook/
├── learner-dashboard/
├── learner-record/
├── learning/
├── ora-grading/
└── profile/               # BOTH /profile and /u serve this dir
```

## Drift Risks

### Risk 1: Adding MFE in Caddy Without LMS Setting

**Symptom**: MFE loads in browser but backend doesn't know URL, causing broken links in emails/LMS pages.

**Example**:
```diff
# Caddyfile (added)
+ @mfe_newmfe {
+     path /newmfe /newmfe/*
+ }
+ handle @mfe_newmfe {
+     root * /openedx/dist/newmfe
+     ...
+ }

# production.py (forgotten!)
- (no corresponding *_MICROFRONTEND_URL)
```

**Detection**: `verify-mfe-route-contract.sh` will FAIL with "Caddy MFE dir 'newmfe' has no LMS URL setting"

### Risk 2: Adding LMS Setting Without Caddy Route

**Symptom**: Backend generates URLs that return 404 (Caddy doesn't know how to route them).

**Example**:
```diff
# production.py (added)
+ NEWMFE_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/newmfe"

# Caddyfile (forgotten!)
- (no corresponding route)
```

**Detection**: `verify-mfe-route-contract.sh` will FAIL with "LMS setting NEWMFE_MICROFRONTEND_URL has no Caddy route"

### Risk 3: Branding Verifier Map Goes Stale

**Symptom**: Automated tests don't cover new MFE, allowing branding regressions.

**Example**:
```diff
# Caddyfile + production.py (both updated)
+ /newmfe → newmfe
+ NEWMFE_MICROFRONTEND_URL

# verify-mfe-branding.sh (forgotten!)
- (MFE_ROUTES map not updated)
```

**Detection**: `verify-mfe-route-drift.sh` will FAIL with "Caddy dir 'newmfe' NOT in branding verifier"

### Risk 4: Course-Authoring Dual-Path Breaks

**Symptom**: One of `/authoring` or `/course-authoring` returns 404, breaking Studio navigation.

**Why it exists**: Legacy URL transition — some links use `/authoring`, newer ones use `/course-authoring`. Both must resolve to same directory.

**Detection**: `verify-mfe-route-contract.sh` checks both paths point to `course-authoring` directory.

### Risk 5: Profile /u Route Breaks

**Symptom**: Username URLs like `/u/alice` return 404 or serve wrong content.

**Why special**: Profile MFE doesn't use `/profile` as app basename — it expects `/u/:username` URLs. We serve the same SPA at both `/profile` (for static assets) and `/u` (for username routes).

**Detection**: `verify-mfe-route-contract.sh` checks `/u` route serves `profile` directory without prefix stripping.

## Adding a New MFE

**Follow this checklist to maintain contract compliance:**

### Step 1: Update Caddyfile

File: `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile`

```caddy
# Add BEFORE the closing brace
@mfe_newmfe {
    path /newmfe /newmfe/*
}
handle @mfe_newmfe {
    uri strip_prefix /newmfe
    root * /openedx/dist/newmfe
    try_files /{path} /index.html
    file_server
}
```

### Step 2: Update LMS Settings

File: `deploy/k8s/base/apps/openedx/settings/lms/production.py`

Add three entries:

```python
# 1. Django setting for backend use
NEWMFE_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/newmfe"

# 2. MFE_CONFIG for MFE config API (if MFE needs it)
MFE_CONFIG["NEWMFE_MICROFRONTEND_URL"] = NEWMFE_MICROFRONTEND_URL

# 3. MFE_CONFIG_API_URLS for MFE name mapping
MFE_CONFIG_API_URLS = {
    'newmfe': f"{MEREKA_MFE_BASE_URL}/newmfe",
    # ... existing entries
}
```

### Step 3: Update Branding Verifier

File: `scripts/qa/verify-mfe-branding.sh`

Update the `MFE_ROUTES` associative array (around line 92):

```bash
declare -A MFE_ROUTES=(
  ["/authn"]="authn"
  ["/account"]="account"
  # ... existing routes
  ["/newmfe"]="newmfe"  # ADD THIS
)
```

### Step 4: Rebuild and Deploy

```bash
# Rebuild MFE image with new MFE included
tutor images build mfe

# Push to registry
tutor images push mfe

# Update Kustomize overlay image tag
# deploy/k8s/overlays/production/kustomization.yaml

# Apply to cluster
kubectl apply -k deploy/k8s/overlays/production
```

### Step 5: Verify Contract

```bash
# Run contract verifier (should pass with 0 FAIL)
./scripts/qa/verify-mfe-route-contract.sh

# Run branding checks
./scripts/qa/verify-mfe-branding.sh

# Run drift guard
./scripts/qa/verify-mfe-route-drift.sh
```

## Drift Detection

### Manual Detection

```bash
# Check Caddyfile routes
grep -oP '(?<=root \* /openedx/dist/)[a-z0-9_-]+' \
  deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile | sort -u

# Check LMS MFE URLs
grep -E 'MICROFRONTEND_URL|MFE_CONFIG_API_URLS' \
  deploy/k8s/base/apps/openedx/settings/lms/production.py

# Check branding verifier routes
grep -oP '\["/[a-z0-9_-]+"\]="[a-z0-9_-]+"' \
  scripts/qa/verify-mfe-branding.sh
```

### Automated Detection

**Script**: `scripts/qa/verify-mfe-route-contract.sh`

**Runtime enforcement command**:
```bash
./scripts/qa/verify-mfe-route-contract.sh \
  --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster \
  --namespace mereka-lms \
  --strict-runtime
```

**Runs**:
- Pre-commit (recommended)
- CI on every PR (enforced)
- Nightly cron (defense-in-depth)
- `scripts/infra/release-openedx-gitops.sh` production postflight (default enabled)

**Coverage (AC-MFERT-002)**:
- Every Caddy directory has a corresponding LMS URL setting
- Every LMS MFE URL has a corresponding Caddy route
- Branding verifier `MFE_ROUTES` map includes all Caddy directories
- Deployed runtime `/etc/caddy/Caddyfile` in MFE pod contains all repo-declared route paths
- Authoring dual-path (`/authoring` + `/course-authoring`) both resolve to `course-authoring`
- Profile `/u` route serves `profile` directory
- Payments-gateway proxy routes exist for deprecated MFEs

**Expected result**: 20+ PASS / 0 FAIL

## Migration

### Removing an MFE

**Use case**: Deprecating an MFE in favor of LMS/custom service

**Steps**:

1. **Mark deprecated in docs** (this file)
2. **Add redirect in Caddyfile** (keep old URL working)
   ```caddy
   redir /oldmfe/* /newpath/{uri} 302
   ```
3. **Wait 1 release cycle** (allow cached links to age out)
4. **Remove from all 3 layers**:
   - Caddyfile route
   - LMS `*_MICROFRONTEND_URL` settings
   - Branding verifier `MFE_ROUTES` map
5. **Verify contract** (`verify-mfe-route-contract.sh` should still pass)

### Renaming an MFE URL Path

**Example**: Change `/discussions` → `/forum`

**Steps**:

1. **Add new route** in Caddyfile (serve same directory)
2. **Add new setting** in production.py
3. **Add both to branding verifier** (temporarily)
4. **Deploy and test**
5. **Update all hardcoded links** in codebase
6. **Wait 2 release cycles**
7. **Remove old route** from all 3 layers
8. **Verify contract**

## Rollback

### If MFE Fails to Load

**Symptoms**: 404 errors, blank pages, broken navigation

**Quick fix**:

```bash
# 1. Check Caddy logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=caddy --tail=100

# 2. Check MFE pod directory exists
MFE_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=mfe -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n mereka-lms "$MFE_POD" -- ls -la /openedx/dist/

# 3. Verify Caddyfile route
kubectl exec -n mereka-lms -l app.kubernetes.io/name=caddy -- cat /etc/caddy/Caddyfile | grep -A5 "@mfe_<name>"

# 4. Roll back to previous image tag
kubectl set image deployment/mfe -n mereka-lms mfe=<previous-image-tag>
kubectl rollout status deployment/mfe -n mereka-lms
```

### If LMS Can't Generate MFE URLs

**Symptoms**: Links in emails/LMS pages broken, redirects fail

**Quick fix**:

```bash
# 1. Check production.py has setting
kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
  python -c "from lms.envs.production import *; print(NEWMFE_MICROFRONTEND_URL)"

# 2. If missing, add to ConfigMap and restart
kubectl edit configmap openedx-settings-lms-patched -n mereka-lms
# Add: NEWMFE_MICROFRONTEND_URL = ...

kubectl rollout restart deployment/lms -n mereka-lms
```

## Success Criteria

**Contract is working when**:

- ✅ All MFE routes return HTTP 200 with correct content
- ✅ No 404 errors on production domains
- ✅ Backend generates correct MFE URLs in emails/links
- ✅ Branding verifier passes all checks
- ✅ Contract verifier passes with 0 FAIL
- ✅ Drift guard passes with 0 FAIL
- ✅ CI blocks PRs with route mapping drift
- ✅ Authoring dual-path works (both `/authoring` and `/course-authoring`)
- ✅ Profile username URLs work (`/u/alice`)
- ✅ Deprecated MFE routes proxy correctly (`/orders`, `/payment`)

**Contract violations trigger**:

- 🚫 CI failure on PR (blocks merge)
- 🚫 Nightly cron alert (email to team)
- 🚫 Manual gate check failure (blocks release)

## Related Files

| File | Purpose | Owner |
|------|---------|-------|
| `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` | Layer 1: Caddy routing | Platform |
| `deploy/k8s/base/apps/openedx/settings/lms/production.py` | Layer 2: LMS settings | Backend |
| `scripts/qa/verify-mfe-branding.sh` | Layer 3: Branding tests | Frontend |
| `scripts/qa/verify-mfe-route-contract.sh` | Contract verifier (NEW) | Frontend |
| `scripts/qa/verify-mfe-route-drift.sh` | Drift guard (existing) | Frontend |
| `.github/workflows/ci.yml` | CI gate | DevOps |
| `../../reports/2026/audits/FRONTEND_AUDIT_CHECKLIST.md` | Release checklist | Frontend |

## Acceptance Criteria

- **AC-MFERT-001**: Contract documents the complete MFE route-to-dist mapping across all 3 layers ✅
- **AC-MFERT-002**: Verifier confirms no drift between Caddyfile, LMS settings, and branding verifier ✅
- **AC-MFERT-003**: CI gate prevents regression of route mapping consistency ✅

## Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-02-17 | Claude | Initial contract (mereka-lms-115d.7) |
