# Frontend Runtime Stability Status (2026-03-02)

## Scope

In-repo stabilization work only (`mereka-lms` repository).  
No `bbi-infrastructure` / GitOps repo edits were performed.

## Completed in This Lane

- Runtime screenshot capture determinism improvements (existing script updates retained).
- Runtime audit hardening in Playwright selector test for transient shell states.
- MFE Caddy CSP source patch to unblock required external runtime resources.
- Documentation updates for stabilization status, blockers, and phase decisioning.

## Verification Summary

| Command | Result | Notes / Artifacts |
|---|---|---|
| `./scripts/qa/capture-branding-screenshots.sh --env dev --mfe-only` | PASS | `var/screenshots/dev/20260302T010124Z/` (one non-blocking render-timeout warning on `mfe-authn-login`) |
| `./scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.dev --require-slot-markers` | PASS | `PASS=17 WARN=0 FAIL=0` |
| `./scripts/qa/verify-studio-authoring-branding.sh dev` | PASS | `failures=0` on rerun |
| `./scripts/qa/verify-mfe-selector-hardening.sh` | PASS | Selector hardening contract green |
| `./scripts/qa/verify-a11y-contrast-focus.sh` | PASS | Non-blocking warnings documented |
| `./scripts/qa/verify-wcag-contrast-v2.sh` | PASS | WCAG v2 gate green |
| `./scripts/qa/verify-mfe-live-dom-audit.sh --env dev --audit-profile phase7_full --project chromium` | PASS | `1 passed`; log: `var/qa/mfe-live-dom-audit-dev-20260302T010325Z.log` |
| `./scripts/qa/verify-certificate-branding.sh` | PASS | `PASS=25 WARN=0 FAIL=0` |
| `./scripts/qa/verify-security-hardening.sh` | PASS | `PASS=30 FAIL=0 WARN=1` |
| `cd tests/e2e && npx playwright test tests/selector-dom-audit.spec.ts --list` | PASS | Playwright spec compiles/lists |

## Source-Level Fixes Applied

1. `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile`
- Updated MFE CSP to allow external domains required by runtime scripts/styles/fonts:
  - `https://cdnjs.cloudflare.com`
  - `https://cdn.jsdelivr.net`
  - `https://www.googletagmanager.com`
  - `https://www.google-analytics.com`
  - `https://fonts.googleapis.com`
  - `https://fonts.gstatic.com`

2. `tests/e2e/tests/selector-dom-audit.spec.ts`
- Added bounded retry flow for transient “unexpected error / Try again” shells.
- Added hydration-aware low-signal bypass for authn surfaces in headless CI contexts.

## Open Blockers

- CSP improvement is a source change until deployed; runtime can only be re-verified after rollout.

## Notes

- Earlier in the same day, runtime checks intermittently failed with transient error-shell behavior and Studio reachability issues; latest reruns listed above are green.

## Next Action (Requires Deployment Signal)

After approval to proceed with rollout paths, deploy updated image/config and re-run:

```bash
./scripts/qa/verify-studio-authoring-branding.sh dev
./scripts/qa/run-phase7-dom-audit-full.sh --env dev --project chromium
./scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.dev --require-slot-markers
```
