# MFE Routing Parity Runbook

Maintained by: Platform team
Last reviewed: 2026-02-18
Spec: bead-115d17 (AC-ROUTE-001 through AC-ROUTE-004)

---

## Overview

Mereka Academy MFEs are served from a single image (`mfe:8002`) that bundles multiple React SPAs in separate dist directories. Caddy handles all URL-to-dist-directory routing inside the MFE container.

Two Caddyfile layers are involved:

| Layer | File | Purpose |
|-------|------|---------|
| Outer | `deploy/k8s/base/apps/caddy/Caddyfile` | Routes `apps.*` domain to `mfe:8002` |
| Inner | `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` | Routes URL paths to dist directories inside MFE image |

---

## Route Mapping Table

| URL Path | Dist Directory | Backend | Notes |
|----------|---------------|---------|-------|
| `/authn/*` | `dist/authn` | file_server | Login / registration SPA |
| `/account/*` | `dist/account` | file_server | Account settings SPA |
| `/communications/*` | `dist/communications` | file_server | Bulk email UI |
| `/course-authoring/*` | `dist/course-authoring` | file_server | Studio MFE (canonical path) |
| `/authoring/*` | `dist/course-authoring` | file_server | Alias for /course-authoring (see below) |
| `/discussions/*` | `dist/discussions` | file_server | Discussion forum SPA |
| `/gradebook/*` | `dist/gradebook` | file_server | Instructor gradebook SPA |
| `/learner-dashboard/*` | `dist/learner-dashboard` | file_server | Learner home SPA |
| `/learner-record/*` | `dist/learner-record` | file_server | Learner record / transcript SPA |
| `/learning/*` | `dist/learning` | file_server | Course player SPA |
| `/ora-grading/*` | `dist/ora-grading` | file_server | ORA grading interface |
| `/profile/*` | `dist/profile` | file_server | Public profile SPA |
| `/u/*` | `dist/profile` | file_server | Profile alias (no prefix strip) |
| `/api/mfe_config/v1*` | — | `lms:8000` | MFE config API passthrough |
| `/login_refresh*` | — | `lms:8000` | JWT refresh passthrough |
| `/orders*` | — | `payments-gateway:8080` | Legacy ecommerce redirect |
| `/payment*` | — | `payments-gateway:8080` | Legacy ecommerce redirect |

---

## Caddyfile Structure for MFE Routing

Each MFE route follows this pattern in the inner Caddyfile (`:8002`):

```caddy
@mfe_<name> {
    path /<name> /<name>/*
}
handle @mfe_<name> {
    uri strip_prefix /<name>
    root * /openedx/dist/<name>
    try_files /{path} /index.html
    file_server
}
```

Key points:
- `uri strip_prefix` removes the URL prefix before Caddy looks up the file
- `try_files /{path} /index.html` enables SPA client-side routing
- `file_server` serves static files — no reverse_proxy to a backend process

---

## Known Routing Quirks

### /authoring vs /course-authoring

The course authoring MFE build output is named `course-authoring` in the dist directory.
Open edX historically supported both `/authoring` and `/course-authoring` as URL prefixes
(see LMS setting `COURSE_AUTHORING_MICROFRONTEND_URL`).

Both paths are wired in the MFE Caddyfile:

```caddy
@mfe_course-authoring {
    path /course-authoring /course-authoring/*
}
handle @mfe_course-authoring {
    uri strip_prefix /course-authoring
    root * /openedx/dist/course-authoring
    try_files /{path} /index.html
    file_server
}

@mfe_authoring {
    path /authoring /authoring/*
}
handle @mfe_authoring {
    uri strip_prefix /authoring
    root * /openedx/dist/course-authoring   # same dist dir
    try_files /{path} /index.html
    file_server
}
```

**Both must always point to the same dist directory.** The verify script enforces this.

### /u Profile Alias (No Prefix Strip)

The profile MFE mounts username routes at `/u/:username`. Unlike other routes, the `/u`
alias must NOT strip the `/u` prefix, because the SPA needs the full path to extract
the username from the URL.

```caddy
@mfe_profile_u {
    path /u /u/*
}
handle @mfe_profile_u {
    root * /openedx/dist/profile
    try_files /index.html           # no uri strip_prefix here
    file_server
}
```

### Account Settings Redirect

`/account/settings` is not a standalone SPA route in the account MFE. The Caddyfile
redirects it to `/account/` (302) so users don't hit a blank page:

```caddy
@account_settings_compat {
    path /account/settings /account/settings/
}
redir @account_settings_compat /account/ 302
```

---

## How to Add a New MFE Route

1. Build the MFE and confirm the dist output directory name in the image.

2. Add a handler block to the inner Caddyfile
   (`deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile`):

   ```caddy
   @mfe_<newname> {
       path /<newname> /<newname>/*
   }
   handle @mfe_<newname> {
       uri strip_prefix /<newname>
       root * /openedx/dist/<newname>
       try_files /{path} /index.html
       file_server
   }
   ```

3. Add the corresponding `*_MICROFRONTEND_URL` entry to
   `deploy/k8s/base/apps/openedx/settings/lms/production.py`.

4. Add the route mapping to `scripts/qa/verify-mfe-branding.sh`
   (`MFE_ROUTES` associative array).

5. Run the verification scripts to confirm parity:

   ```bash
   ./scripts/qa/verify-mfe-routing-parity.sh
   ./scripts/qa/verify-mfe-route-drift.sh
   ./scripts/qa/verify-mfe-route-contract.sh
   ```

---

## Verification Commands

### Full routing parity check (AC-ROUTE-001 through AC-ROUTE-004)

```bash
./scripts/qa/verify-mfe-routing-parity.sh
```

Expected output:
```
=== MFE Routing Parity Verification ===
...
=== Results: N PASS / 0 FAIL / M WARN ===
All MFE routing parity checks passed.
```

### Check authoring dual-path specifically (AC-ROUTE-002)

```bash
grep -A8 "@mfe_course-authoring" \
  deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile

grep -A8 "@mfe_authoring" \
  deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile
```

Both blocks must contain `root * /openedx/dist/course-authoring`.

### Verify outer Caddyfile proxy to mfe:8002

```bash
grep "mfe:8002" deploy/k8s/base/apps/caddy/Caddyfile
```

Expected: at least two matches (local + production vhosts).

### Live cluster: check routes from MFE pod

```bash
# List dist directories present in the running MFE pod
MFE_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=mfe \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n mereka-lms "$MFE_POD" -- ls /openedx/dist/
```

Cross-reference this list against the Route Mapping Table above.
Any directory in the Caddyfile but absent from the pod indicates a build gap.

### Log routing decisions in the MFE pod

```bash
# Stream Caddy access logs from MFE pod (JSON format)
kubectl logs -n mereka-lms -l app.kubernetes.io/name=mfe --follow \
  | jq -r 'select(.request != null) | "\(.ts | todate) \(.request.method) \(.request.uri) → \(.status)"'
```

### Smoke-test all routes (unauthenticated)

```bash
MFE_BASE="https://apps.academyv2.mereka.io"
for path in /authn/login /account/ /course-authoring/ /authoring/ \
            /discussions/ /gradebook/ /learner-dashboard/ /learner-record/ \
            /learning/ /ora-grading/ /profile/ /u/test-user; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${MFE_BASE}${path}")
  echo "$code  ${path}"
done
```

All paths should return `200` (SPAs serve index.html for all routes).

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `/course-authoring/` returns 404 | Missing handler block in MFE Caddyfile | Add `@mfe_course-authoring` block |
| `/authoring/` works, `/course-authoring/` doesn't (or vice versa) | Handler exists for one but not both | Add the missing block; both must serve `dist/course-authoring` |
| MFE route serves wrong dist dir | Wrong `root` directive | Correct the dist directory path in the handler |
| `/u/username` shows 404 or wrong page | strip_prefix accidentally added to /u handler | Remove `uri strip_prefix /u` from the `@mfe_profile_u` block |
| All MFE routes 502 | `mfe:8002` container unhealthy | Check MFE pod logs and readiness probe |
| Route returns `200` with empty body | Runtime Caddyfile in pod is stale/missing handler (false-green if only status checked) | Check `/etc/caddy/Caddyfile` in the MFE pod and re-apply Tutor patches + rebuild/redeploy MFE |
| `/api/mfe_config/v1` not found | API passthrough missing | Add `reverse_proxy /api/mfe_config/v1* lms:8000` to MFE Caddyfile |
