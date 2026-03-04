# Module Surface Validation Runbook

**Bead**: 253a — module surface validation pack (non-UI modules)
**Last updated**: 2026-03-04
**Audience**: Platform Eng, On-call

---

## Overview

This runbook covers HTTP smoke testing, authn proxy route verification, and evidence
collection for the non-UI Open edX module surfaces:

| Service | Host | Port | Notes |
|---------|------|------|-------|
| Credentials | `credentials.academyv2.mereka.io` | 443 (HTTPS) | Certificate/badge issuance service |
| Purchase Gateway | `payments.academyv2.mereka.io` | 443 (HTTPS) | Stripe-based payment service (replaces legacy Oscar) |
| Forum | `academyv2.mereka.io` | 443 (HTTPS) | Forum v2 integrated into LMS; no standalone host |
| Notes | `notes.academyv2.mereka.io` | 443 (HTTPS) | Learner annotations API |
| Preview | `preview.academyv2.mereka.io` | 443 (HTTPS) | LMS alias for staff course preview |
| MFE (authn) | `apps.academyv2.mereka.io` | 443 (HTTPS) | Authn, learning, account MFEs |
| App/Teacher | `apps.academyv2.mereka.io/course-authoring/` | 443 (HTTPS) | Course Authoring MFE (teacher surface) |

---

## Expected Status Codes Per Route

| Route | Expected HTTP | Notes |
|-------|--------------|-------|
| `GET credentials.academyv2.mereka.io/` | 200 | Caddy returns branded inline HTML page |
| `GET credentials.academyv2.mereka.io/health/` | 200 | JSON payload: `{"overall_status": "OK"}` |
| `GET credentials.academyv2.mereka.io/admin/login/` | 200 | Django admin login page |
| `GET credentials.academyv2.mereka.io/authn/login` | 200 | Proxied to MFE via Caddy |
| `GET notes.academyv2.mereka.io/heartbeat` | 200 | Service heartbeat |
| `GET academyv2.mereka.io/api/discussion/v1/` | 200 or 401 | Forum API (integrated into LMS) |
| `GET preview.academyv2.mereka.io/` | 200 or 302 | LMS preview alias |
| `GET apps.academyv2.mereka.io/authn/login` | 200 | MFE SPA shell |
| `GET apps.academyv2.mereka.io/course-authoring/` | 200 | Course authoring (teacher) surface |

---

## HTTP Smoke Commands

### Credentials

```bash
# Root landing (expect 200 — branded Caddy response)
curl -sL https://credentials.academyv2.mereka.io/ | grep -o "Mereka Credentials Service"
# Expected: Mereka Credentials Service

# Health endpoint (expect 200 + JSON status)
curl -s https://credentials.academyv2.mereka.io/health/ | python3 -m json.tool
# Expected: { "overall_status": "OK", "database_status": "OK", ... }

# Admin login (expect 200)
curl -sL -o /dev/null -w "%{http_code}\n" \
  https://credentials.academyv2.mereka.io/admin/login/
# Expected: 200

# Authn proxy route (expect 200 — served by MFE via Caddy)
curl -sL -o /dev/null -w "%{http_code}\n" \
  https://credentials.academyv2.mereka.io/authn/login
# Expected: 200
```

### Forum (integrated into LMS)

```bash
# Discussion API v1 (expect 200 or 401 when unauthenticated)
curl -sL -o /dev/null -w "%{http_code}\n" \
  https://academyv2.mereka.io/api/discussion/v1/
# Expected: 200 or 401

# Forum search (Meilisearch-backed)
curl -sL -o /dev/null -w "%{http_code}\n" \
  "https://academyv2.mereka.io/api/discussion/v1/search?text=test"
# Expected: 200 or 401
```

### Notes

```bash
# Service heartbeat (expect 200)
curl -sL -o /dev/null -w "%{http_code}\n" \
  https://notes.academyv2.mereka.io/heartbeat
# Expected: 200

# API health (expect 200 or 401)
curl -sL -o /dev/null -w "%{http_code}\n" \
  https://notes.academyv2.mereka.io/api/v1/
# Expected: 200 or 401
```

### Preview (LMS alias)

```bash
# Root (expect 200 or 302)
curl -sL -o /dev/null -w "%{http_code} %{url_effective}\n" \
  https://preview.academyv2.mereka.io/
# Expected: 200 (LMS homepage) or 302 → login

# Course preview path (staff-only)
curl -sL -o /dev/null -w "%{http_code}\n" \
  https://preview.academyv2.mereka.io/courses/
# Expected: 200 or 302 → login
```

### MFE — App / Teacher surfaces

```bash
# Authn login (expect 200)
curl -sL -o /dev/null -w "%{http_code}\n" \
  https://apps.academyv2.mereka.io/authn/login
# Expected: 200

# Course authoring (teacher MFE, expect 200)
curl -sL -o /dev/null -w "%{http_code}\n" \
  https://apps.academyv2.mereka.io/course-authoring/
# Expected: 200

# Learning surface (learner MFE)
curl -sL -o /dev/null -w "%{http_code}\n" \
  https://apps.academyv2.mereka.io/learning/
# Expected: 200

# Account MFE
curl -sL -o /dev/null -w "%{http_code}\n" \
  https://apps.academyv2.mereka.io/account/
# Expected: 200
```

---

## Authn Proxy Route Verification

Caddy routes `/authn/*` on the credentials domain to the MFE container (`mfe:8002`).
This ensures the branded authn shell is served on the credentials domain.

**Verify Caddyfile config:**
```bash
grep -A5 "handle /authn/" deploy/k8s/base/apps/caddy/Caddyfile
# Expected: credentials block with:
#   reverse_proxy mfe:8002 { ... }
```

**Verify live proxy (requires cluster):**
```bash
# credentials authn proxy
curl -s https://credentials.academyv2.mereka.io/authn/login | grep -o '<div id="root">'
# Expected: <div id="root">
```

---

## 5xx Monitoring References

5xx errors are tracked via PrometheusRule alerts in `deploy/k8s/base/monitoring/`:

| Alert file | Covers |
|-----------|--------|
| `prometheusrule-lms.yaml` | LMS pod health, memory, restarts |
| `prometheusrule-credentials.yaml` | Credentials service health |

**Verify alerts deployed:**
```bash
kubectl get prometheusrule -n mereka-lms
# Expected: lms-alerts, credentials-alerts listed

kubectl get prometheusrule lms-alerts -n mereka-lms -o yaml | grep -A3 "alert:"
# Expected: LMSPodDown, LMSPodRestarting, etc.
```

**Check for 5xx spikes (live cluster):**
```bash
# Via Prometheus query
kubectl exec -n monitoring deploy/prometheus -- \
  promtool query instant \
  'sum(rate(nginx_ingress_controller_requests{status=~"5.."}[5m])) by (ingress)'
```

---

## Evidence Collection Commands

Run these to capture a timestamped evidence bundle:

```bash
TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)
BUNDLE_DIR="var/module-surface-evidence/${TIMESTAMP}"
mkdir -p "$BUNDLE_DIR"

# Credentials
curl -sL -o "$BUNDLE_DIR/credentials-health.json" -w "%{http_code}" \
  https://credentials.academyv2.mereka.io/health/ > "$BUNDLE_DIR/credentials-health.txt"

curl -sL -o "$BUNDLE_DIR/credentials-admin.html" -w "%{http_code}" \
  https://credentials.academyv2.mereka.io/admin/login/ > "$BUNDLE_DIR/credentials-admin.txt"

# Forum (LMS)
curl -sL -o "$BUNDLE_DIR/forum-api.json" -w "%{http_code}" \
  https://academyv2.mereka.io/api/discussion/v1/ > "$BUNDLE_DIR/forum-api.txt"

# Notes
curl -sL -o "$BUNDLE_DIR/notes-heartbeat.txt" -w "%{http_code}" \
  https://notes.academyv2.mereka.io/heartbeat > "$BUNDLE_DIR/notes-heartbeat-code.txt"

# Preview
curl -sL -o "$BUNDLE_DIR/preview-root.html" -w "%{http_code} %{url_effective}" \
  https://preview.academyv2.mereka.io/ > "$BUNDLE_DIR/preview-root.txt"

# MFE
curl -sL -o "$BUNDLE_DIR/mfe-authn-login.html" -w "%{http_code}" \
  https://apps.academyv2.mereka.io/authn/login > "$BUNDLE_DIR/mfe-authn-login.txt"

curl -sL -o "$BUNDLE_DIR/mfe-course-authoring.html" -w "%{http_code}" \
  https://apps.academyv2.mereka.io/course-authoring/ > "$BUNDLE_DIR/mfe-course-authoring.txt"

echo "Evidence captured in: $BUNDLE_DIR"
ls -lh "$BUNDLE_DIR/"
```

Or use the automated script in live mode:
```bash
MODULE_SURFACE_LIVE=1 ./scripts/qa/verify-module-surface-validation.sh
# Evidence will be written to var/module-surface-evidence/<timestamp>/
```

---

## Automated Verification

Run the full non-UI module surface pack:

```bash
# Source check only (offline, CI-safe)
./scripts/qa/verify-module-surface-validation.sh

# With live HTTP checks
MODULE_SURFACE_LIVE=1 ./scripts/qa/verify-module-surface-validation.sh
```

Expected output (all PASS, no FAIL):
```
=== Module Surface Validation Pack ===
Repo root : /path/to/mereka-lms
Live mode : 0

--- AC-MOD-001: Service Host Inventory & Smoke Coverage ---
[PASS] AC-MOD-001: Service hostname registry doc: file exists (...)
[PASS] AC-MOD-001: Hostname doc lists credentials host
...
--- AC-MOD-002: Status Code Mapping & Authn Proxy Routes ---
[PASS] AC-MOD-002: Caddyfile has authn proxy block for credentials
...

==============================
  Module Surface Validation
==============================
  PASS: NN
  WARN: N
  FAIL: 0
==============================
RESULT: PASS
```

---

## Troubleshooting

### Credentials /health/ returns 503

- Check pod: `kubectl get pods -n mereka-lms -l app.kubernetes.io/name=credentials`
- Check DB connectivity: `kubectl exec -n mereka-lms deploy/credentials -- python manage.py dbshell`

### Notes heartbeat fails

- Check pod: `kubectl get pods -n mereka-lms -l app.kubernetes.io/name=notes`
- Notes depends on LMS JWT auth; check `SOCIAL_AUTH_EDX_OAUTH2_*` settings

### Forum API returns unexpected errors

- Forum v2 is integrated into LMS (not a standalone service)
- Check LMS pod: `kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms`
- Check forum settings: `kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "from django.conf import settings; print(settings.FORUM_BACKEND)"`

### Authn proxy not serving MFE shell

- Check Caddyfile has `handle /authn/*` blocks for the service domain
- Check MFE pod: `kubectl get pods -n mereka-lms -l app.kubernetes.io/name=mfe`
- Check MFE endpoints: `kubectl get endpoints mfe -n mereka-lms`

### Preview returns 404 on course paths

- Preview host is an LMS alias — check `PREVIEW_LMS_BASE_URL` in Tutor config
- Verify Caddyfile routes `preview.academyv2.mereka.io` → `lms:8000`

---

## References

- Service hostname registry: `docs/operations/OPENEDX_HOSTNAMES.md`
- Caddy routing config: `deploy/k8s/base/apps/caddy/Caddyfile`
- PrometheusRules: `deploy/k8s/base/monitoring/prometheusrule-lms.yaml`, `prometheusrule-credentials.yaml`
- Troubleshooting guide: `docs/operations/TROUBLESHOOTING.md`
- Bead 253a ACs: AC-MOD-001 through AC-MOD-005
