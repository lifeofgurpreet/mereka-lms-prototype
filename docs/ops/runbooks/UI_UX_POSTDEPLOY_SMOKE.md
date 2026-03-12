# UI/UX Post-Deploy Smoke Runbook
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

**Bead**: mereka-lms-115d.20
**Covers**: AC-UVIS-301, AC-UVIS-302, AC-UVIS-303, AC-UVIS-304, AC-UVIS-305
**Last updated**: 2026-02-18
**Audience**: Platform Engineering, QA

---

## Purpose

This runbook defines the authenticated UI smoke + visual checkpoint contract for
3 tenant domains across 5 critical MFE routes (15 checkpoints total).  It is
the top layer of the Mereka Academy verification stack, sitting above unauthenticated
visual regression (`VISUAL_SMOKE_BASELINE.md`) and route-level a11y conformance
(ACCESSIBILITY_CONFORMANCE_RUNBOOK.md).

The verification script is `scripts/qa/verify-tenant-ui-smoke.sh`.

---

## Tenant Domain Registry (AC-UVIS-301)

Three production tenant domains are in scope for this smoke gate:

| # | Domain | Brand Name | Notes |
|---|--------|-----------|-------|
| 1 | `academyv2.mereka.io` | Mereka Academy | Primary production domain |
| 2 | `academy.biji-biji.com` | Biji-Biji Academy | Partner co-brand |
| 3 | `skillourfuture.mereka.io` | Skill Our Future Academy | Government programme |

For per-domain token configuration and SITE_VARIANTS details see
[TENANT_BRANDING_MATRIX.md](TENANT_BRANDING_MATRIX.md).

---

## Route × Domain Matrix — 15 Checkpoints (AC-UVIS-301)

Each cell in this matrix is one smoke checkpoint (authenticated page load +
visual capture + a11y landmark check).

| Route | `academyv2.mereka.io` | `academy.biji-biji.com` | `skillourfuture.mereka.io` |
|-------|-----------------------|------------------------|---------------------------|
| `/learner-dashboard/` | CP-01 | CP-06 | CP-11 |
| `/learning/` | CP-02 | CP-07 | CP-12 |
| `/account/` | CP-03 | CP-08 | CP-13 |
| `/profile/` | CP-04 | CP-09 | CP-14 |
| `/course-authoring/` | CP-05 | CP-10 | CP-15 |

**Total**: 15 checkpoints (5 routes × 3 domains).  Each checkpoint is executed
at desktop viewport (1280×800).  Mobile viewport (375×812) is optional but
encouraged for release gates.

### Route Descriptions

| Route | MFE App | Auth Required |
|-------|---------|---------------|
| `/learner-dashboard/` | `frontend-app-learner-dashboard` | Learner session |
| `/learning/` | `frontend-app-learning` | Learner session + course enrolment |
| `/account/` | `frontend-app-account` | Learner session |
| `/profile/` | `frontend-app-profile` | Learner session |
| `/course-authoring/` | `frontend-app-course-authoring` | Staff/author session |

---

## Screenshot Capture and Visual Comparison (AC-UVIS-302)

### Screenshot Naming Convention

Screenshots are stored under `var/smoke/` using the following template:

```
var/smoke/{domain}/{route}-{timestamp}.png
```

Examples:

```
var/smoke/academyv2.mereka.io/learner-dashboard-2026-02-18T14-30-00Z.png
var/smoke/academy.biji-biji.com/account-2026-02-18T14-30-05Z.png
var/smoke/skillourfuture.mereka.io/course-authoring-2026-02-18T14-30-10Z.png
```

The `{timestamp}` follows ISO 8601 with colons replaced by hyphens for
filesystem compatibility (`%Y-%m-%dT%H-%M-%SZ`).

### Capture Command

```bash
# Capture a single checkpoint (requires Playwright + SSO credentials)
export SSO_USERNAME="smoke-test@mereka.io"
export SSO_PASSWORD="<from Infisical>"
export TARGET_DOMAIN="academyv2.mereka.io"
export TARGET_ROUTE="learner-dashboard"

./scripts/qa/visual-regression-test.sh \
  --authenticated \
  --domain "$TARGET_DOMAIN" \
  --route "$TARGET_ROUTE" \
  --output "var/smoke/${TARGET_DOMAIN}/${TARGET_ROUTE}-$(date -u +%Y-%m-%dT%H-%M-%SZ).png"
```

### Visual Comparison Approach — RMSE Threshold

Screenshots are diffed against the baseline using ImageMagick
`compare -metric RMSE`.  The thresholds mirror those defined in
[VISUAL_SMOKE_BASELINE.md](VISUAL_SMOKE_BASELINE.md):

| Threshold | RMSE | Use |
|-----------|------|-----|
| Tolerant | ≤ 5.0 | Feature development, daily smoke |
| Strict | ≤ 2.0 | Release gate, tenant onboarding |

Set via:

```bash
VISUAL_RMSE_THRESHOLD=5.0   # tolerant (default)
VISUAL_RMSE_THRESHOLD=2.0   # strict
```

For full threshold policy and false-positive triage see
[VISUAL_SMOKE_BASELINE.md](VISUAL_SMOKE_BASELINE.md).

---

## Accessibility Cross-Reference (AC-UVIS-303)

Every checkpoint in the Route × Domain matrix **must** also pass the
authenticated a11y landmark + focus-indicator checks defined in:

- **Script**: `scripts/qa/verify-a11y-authenticated-routes.sh`
- **Runbook**: `ACCESSIBILITY_CONFORMANCE_RUNBOOK.md`

### Required Landmarks (per authenticated route)

All 5 routes must expose the following ARIA landmarks:

| Landmark | HTML Element / Role | WCAG Reference |
|----------|---------------------|---------------|
| `banner` | `<header>` / `role="banner"` | WCAG 1.3.1 |
| `main` | `<main>` / `role="main"` | WCAG 1.3.1 |
| `nav` | `<nav>` / `role="navigation"` | WCAG 1.3.1 |
| `contentinfo` | `<footer>` / `role="contentinfo"` | WCAG 1.3.1 |

No duplicate landmarks of the same type are permitted (per WCAG 1.3.6).

### Focus Indicators

Focus indicators must meet 3:1 minimum contrast ratio against adjacent colours
(WCAG 2.2 SC 1.4.11) and must be a visible outline, not a colour-only change.
This applies to buttons, links, and form inputs on all 5 routes.

To run the full a11y gate:

```bash
./scripts/qa/verify-a11y-authenticated-routes.sh
```

---

## Artifact Naming and Retention (AC-UVIS-304)

### Storage Layout

```
var/smoke/
├── academyv2.mereka.io/
│   ├── learner-dashboard-2026-02-18T14-30-00Z.png
│   ├── learning-2026-02-18T14-30-05Z.png
│   ├── account-2026-02-18T14-30-10Z.png
│   ├── profile-2026-02-18T14-30-15Z.png
│   └── course-authoring-2026-02-18T14-30-20Z.png
├── academy.biji-biji.com/
│   └── (same structure)
└── skillourfuture.mereka.io/
    └── (same structure)
```

### Retention Policy

| Rule | Value |
|------|-------|
| Retention period | **30 days** |
| Cleanup command | `find var/smoke/ -name "*.png" -mtime +30 -delete` |
| Latest symlink | `var/smoke/{domain}/latest/` → most recent run directory |
| Gitignore | `var/smoke/` is gitignored (runtime artifact) |

The `latest` symlink is updated by the capture script after each successful
run and allows other tooling to reference the most recent screenshots without
knowing the exact timestamp.

### CI Artifact Upload

For GitHub Actions runs, upload the `var/smoke/` directory as a workflow
artifact with `retention-days: 30`:

```yaml
- name: Upload smoke artifacts
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: tenant-ui-smoke-${{ github.run_id }}
    path: var/smoke/
    retention-days: 30
```

---

## Why This Is a World-Class Baseline (AC-UVIS-305)

The Mereka Academy verification stack is layered to catch different failure
modes at the appropriate depth:

| Layer | Gate | Coverage |
|-------|------|---------|
| 1. Design tokens | `verify-design-tokens.sh` | CSS variable consistency |
| 2. Branding integrity | `verify-branding-token-integrity.sh` | Token → theme coherence |
| 3. Unauthenticated visual | `verify-visual-smoke-baseline.sh` | RMSE diff against baseline |
| 4. A11y conformance | `verify-a11y-authenticated-routes.sh` | Landmarks + focus indicators |
| 5. **Tenant UI smoke** | `verify-tenant-ui-smoke.sh` ← this gate | Auth × domain × route matrix |

Adding the tenant-domain dimension in Layer 5 is what makes this world-class:
most LMS deployments check only one domain.  By asserting across all 3 tenant
domains for every authenticated route, we detect:

- Tenant-specific branding regressions (wrong footer brand name, wrong logo)
- Domain-resolution failures (TenantResolutionMiddleware misconfiguration)
- MFE route gaps introduced when adding a new tenant
- A11y regressions that are tenant-specific (e.g., a plugin-slot override
  that removes a landmark only on one domain)

### Failure → Bead Mapping

When a checkpoint fails, triage using the following mapping:

| Failure Type | Likely Category | Follow-up Bead |
|-------------|-----------------|----------------|
| Wrong brand name / copyright holder in footer | Branding regression | `115d.*` (branding beads) |
| Footer landmark (`contentinfo`) missing | A11y regression | `3vg9.*` (a11y beads) |
| RMSE diff above threshold for tenant domain | Visual regression | `115d.15` (visual smoke) |
| Route returns 4xx or redirect loop | Routing / tenancy config | `115d.*` or `8jao.*` |
| Focus indicator invisible on a route | A11y regression | `3vg9.*` (a11y beads) |
| Screenshot not matching baseline across all 3 domains | Theme / token drift | `115d.4` (token beads) |

To file a triage ticket, use the title format:

```
smoke(tenant-ui): {domain} / {route} — {failure-type} [{AC-UVIS-NNN}]
```

Example:

```
smoke(tenant-ui): academy.biji-biji.com / learner-dashboard — wrong brand name [AC-UVIS-301]
```

---

## Running the Full Gate

### Offline (CI-safe, no cluster required)

```bash
./scripts/qa/verify-tenant-ui-smoke.sh
```

Expected result: **0 FAIL**.  WARNs are advisory.

### Live Cluster (all 15 checkpoints)

```bash
export SSO_USERNAME="smoke-test@mereka.io"
export SSO_PASSWORD="<from Infisical>"

TENANT_SMOKE_LIVE=1 ./scripts/qa/verify-tenant-ui-smoke.sh
```

### Run A11y Gate in Parallel

```bash
./scripts/qa/verify-tenant-ui-smoke.sh &
./scripts/qa/verify-a11y-authenticated-routes.sh &
wait
```

---

## Related Documentation

- [`VISUAL_SMOKE_BASELINE.md`](VISUAL_SMOKE_BASELINE.md) — RMSE threshold policy + baseline generation
- [`ACCESSIBILITY_CONFORMANCE_RUNBOOK.md`](ACCESSIBILITY_CONFORMANCE_RUNBOOK.md) — Landmark + focus requirements
- [`TENANT_BRANDING_MATRIX.md`](TENANT_BRANDING_MATRIX.md) — Per-domain brand configuration
- [`../ops/runbooks/VISUAL_REGRESSION_RUNBOOK.md`](../ops/runbooks/VISUAL_REGRESSION_RUNBOOK.md) — Unauthenticated visual regression infrastructure
- [`scripts/qa/verify-tenant-ui-smoke.sh`](../../scripts/qa/verify-tenant-ui-smoke.sh) — This gate's verification script
- [`scripts/qa/verify-a11y-authenticated-routes.sh`](../../scripts/qa/verify-a11y-authenticated-routes.sh) — A11y authenticated route gate
- [`scripts/qa/verify-visual-smoke-baseline.sh`](../../scripts/qa/verify-visual-smoke-baseline.sh) — Visual smoke baseline verification
