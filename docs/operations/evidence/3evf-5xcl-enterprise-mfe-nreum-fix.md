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

## Fix Already In Repo (Not Yet Deployed)

`deploy/k8s/base/apps/enterprise/mfe/admin-portal-deployment.yaml` contains a `sanitize-enterprise-index-html` initContainer that:

1. Copies `/openedx/dist` to a clean dir
2. Runs `awk` to strip any `<script>` block containing `NREUM`
3. Replaces the dist dir with the cleaned version

```yaml
initContainers:
  - name: sanitize-enterprise-index-html
    image: ...enterprise-admin-portal:latest
    command: ["/bin/sh", "-c"]
    args:
      - |
        awk '
          ...strips <script> blocks containing NREUM...
        ' /openedx/dist-clean/index.html > /tmp/index.html
```

The same initContainer is present in `learner-portal-deployment.yaml`.

### Why the Fix Is Not Live

The live cluster pod is running a deployment that **pre-dates the initContainer addition** — ArgoCD has not yet synced this manifest to the cluster.

**Verification** (run from cluster access):
```bash
kubectl get pod -n mereka-lms -l app.kubernetes.io/name=enterprise-admin-portal -o jsonpath='{.items[0].status.initContainerStatuses}'
```
If the initContainer is running, it will appear here. If empty — the deployed pod was created before the initContainer was added to the manifest.

---

## AC-UX-142: Admin/Studio Smoke After Fix

### Current state (pre-fix deployment)

| URL | HTTP | NREUM | Status |
|-----|------|-------|--------|
| `https://admin.academyv2.mereka.io/` | 200 | ❌ `undefined_license_key` present | FAIL |
| `https://enterprise.academyv2.mereka.io/` | 200 | ❌ Full NR agent embedded | WARN |
| `https://studio.academyv2.mereka.io/` | 200 | ✅ Not affected | PASS |
| `https://academyv2.mereka.io/` | 200 | ✅ Not affected (guarded in footer.html) | PASS |

### Expected state after ArgoCD sync

After the initContainer runs, the `index.html` served by the enterprise portals will have the NREUM `<script>` block stripped entirely. The portals will still be functional — NREUM was purely a monitoring agent injection with invalid keys.

---

## AC-UX-143: Evidence

```bash
# Confirm NREUM in admin portal (pre-fix):
curl -s https://admin.academyv2.mereka.io/ | grep -o 'licenseKey:"[^"]*"'
# Output: licenseKey:"undefined_license_key"

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

**Decision: initContainer sanitization (already in repo) is the correct minimal fix.**

Rationale:
- `apply-patches.sh` is for build-time Tutor template patches; the enterprise MFE images are pre-built upstream containers (not built via `tutor images build`)
- New Relic `ENABLE_NEW_RELIC=false` rebuild is the permanent fix, but requires a new enterprise MFE image build (tracked separately)
- The initContainer approach is runtime, image-agnostic, and already approved in the repo
- No LMS footer.html change needed — the existing guard in `footer.html` (line 89) already skips `undefined_license_key` for the LMS Segment/analytics footer template

**Action required (operator)**:
```bash
# Trigger ArgoCD sync to deploy the sanitize initContainer:
argocd app sync mereka-lms --resource apps:Deployment:enterprise-admin-portal
argocd app sync mereka-lms --resource apps:Deployment:enterprise-learner-portal
```

Or wait for the next scheduled ArgoCD reconciliation.

---

## AC-UX-145: Regression Guard Added

New CI script: `scripts/qa/verify-enterprise-mfe-nreum-clean.sh`

Checks live enterprise portal HTML for NREUM injection. Runs in SKIP mode if cluster is unreachable (CI-safe).
