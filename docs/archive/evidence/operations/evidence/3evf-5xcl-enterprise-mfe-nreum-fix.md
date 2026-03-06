# Enterprise MFE: undefined_license_key / NREUM Root Cause + Fix

> **Beads**: mereka-lms-3evf (AC-UX-140..144), mereka-lms-5xcl (AC-UX-141..145)
> **Date**: 2026-02-19
> **Branch**: feat/23ry2-spec-dedupe-normalize

---

## AC-UX-140 / AC-UX-141: Root Cause + Trace

### Symptom

`https://admin.academyv2.mereka.io/` HTML source contains:

```javascript
;NREUM.loader_config={
  accountID:"undefined_account_id",
  trustKey:"undefined_trust_key",
  agentID:"undefined_agent_id",
  licenseKey:"undefined_license_key",
  applicationID:"undefined_application_id"
}
;NREUM.info={
  beacon:"bam-cell.nr-data.net",
  licenseKey:"undefined_license_key",
  applicationID:"undefined_application_id",
  sa:1
}
```

### Root Cause

The `frontend-app-admin-portal` (enterprise admin MFE) was built with New Relic browser agent enabled (`ENABLE_NEW_RELIC=true` or default-on in the upstream Open edX MFE build), but **no real New Relic license key was provided at build time**. The webpack build inlines the New Relic browser agent snippet with literal `"undefined_license_key"` placeholders.

The same issue exists in `frontend-app-learner-portal-enterprise`: that portal contains a **full embedded New Relic browser agent** (~34KB inline script) — likely from the upstream open-source build defaults.

**No LMS/Studio pages are affected** — the LMS and Studio are Django applications and do not use the New Relic browser agent build system. Confirmed: `https://studio.academyv2.mereka.io/` HTTP 200, no NREUM injection.

### Why MFE Config API Did Not Prevent This

`/api/mfe_config/v1` returns `{}` for New Relic keys — meaning the LMS has no New Relic config set. The browser agent was injected at **build time** (webpack), not at runtime. The runtime config cannot override a script already embedded in `index.html`.

---

## Fix Status (As of 2026-02-19)

Runtime stripping initContainers for enterprise portals were removed from manifests to avoid non-canonical patching.
The canonical mitigation now relies on build-time configuration and deploy-time verification.

This means:

- `deploy/k8s/base/apps/enterprise/mfe/admin-portal-deployment.yaml` should **not** contain `strip-nreum`.
- `deploy/k8s/base/apps/enterprise/mfe/learner-portal-deployment.yaml` should **not** contain `strip-nreum`.
- Live smoke and QA are expected to prove zero `undefined_license_key` by rebuilding/rolling images with fixed configuration.

### Why the Fix Can Be Delayed in Runtime

After removing runtime sanitization from manifests, correctness depends on image rollout:

- Rebuild enterprise MFE images with correct New Relic build-time configuration.
- Push updated images and update GitOps image tags.
- Roll out via GitOps and run the smoke script.

If the cluster still shows inline NREUM snippets, the active image is still pre-fix or using an old build.

---

## AC-UX-142: Admin/Studio Smoke After Fix

### Current state (pre-fix deployment)

| URL | HTTP | NREUM | Status |
|-----|------|-------|--------|
| `https://admin.academyv2.mereka.io/` | 200 | ❌ `undefined_license_key` present | FAIL |
| `https://enterprise.academyv2.mereka.io/` | 200 | ❌ `undefined_license_key` present | FAIL |
| `https://studio.academyv2.mereka.io/` | 200 | ✅ Not affected | PASS |
| `https://academyv2.mereka.io/` | 200 | ✅ Not affected (guarded in footer.html) | PASS |

### Expected state after ArgoCD sync

After rebuild and rollout, the `index.html` served by the enterprise portals should no longer include inline `NREUM` snippets with undefined placeholders. The portals remain functional; only invalid monitoring bootstrap configuration is removed.

### Current verification (2026-02-19)

```bash
./scripts/qa/verify-enterprise-mfe-nreum-clean.sh
```

Result from live check:

- FAIL (7 pass / 2 fail / 0 skip)
- `admin.academyv2.mereka.io` still returns inline `undefined_license_key`
- `enterprise.academyv2.mereka.io` now still returns inline undefined New Relic placeholders
- Manifest checks confirm no `strip-nreum` initContainer in enterprise deployments
- Caddy route checks for `/api/mfe_config/v1` and `/login_refresh` are present

---

## AC-UX-143: Evidence

```bash
# Confirm NREUM in admin portal (pre-fix):
curl -s https://admin.academyv2.mereka.io/ | grep -o 'licenseKey:"[^"]*"'
# Output: licenseKey:"undefined_license_key"

# Confirm visual evidence bundle (fresh):
ls -l docs/archive/evidence/operations/evidence/screenshots/2026-02-19/{admin,apps,enterprise}.png
file docs/archive/evidence/operations/evidence/screenshots/2026-02-19/{admin,apps,enterprise}.png

# Confirm NREUM placeholders in enterprise portal:
curl -s https://enterprise.academyv2.mereka.io/ | rg -n "undefined_(license_key|account_id|application_id|agent_id)"
# Output expected: undefined_account_id / undefined_application_id / undefined_license_key

# LMS MFE config (no NR keys):
curl -s "https://academyv2.mereka.io/api/mfe_config/v1?mfe=admin"
# Output: {}

# Caddyfile routing fix (already in repo):
# grep deploy/k8s/base/apps/caddy/Caddyfile | relevant lines:
#   reverse_proxy /api/mfe_config/v1* lms:8000
#   reverse_proxy /login_refresh* lms:8000
# (applied for both admin.academyv2.mereka.io and enterprise.academyv2.mereka.io)
```

---

## AC-UX-144: Decision — apply-patches vs Plugin Parity

**Decision: canonical fix is build-time configuration + deploy verification (no initContainer runtime workaround).**

Rationale:
- `apply-patches.sh` remains the canonical path for Tutor-generated manifests and non-MFE services.
- Enterprise MFEs are containerized separately; runtime HTML mutation is intentionally removed from the deployment manifest.
- The build-time config path (`ENABLE_NEW_RELIC=false` or equivalent in enterprise MFE build config) should be enforced in the MFE image pipeline and evidenced by image rollout.

**Action required (operator)**:
```bash
# Ensure enterprise MFE images are rebuilt with correct New Relic configuration and deployed by GitOps:
./scripts/infra/release-openedx-gitops.sh \
  --openedx-tag <tag> --mfe-tag <tag> --verify-runtime --apply
```

---

## AC-UX-145: Regression Guard Added

New CI script: `scripts/qa/verify-enterprise-mfe-nreum-clean.sh`

Checks live enterprise portal HTML for NREUM injection. Runs in SKIP mode if cluster is unreachable (CI-safe).
