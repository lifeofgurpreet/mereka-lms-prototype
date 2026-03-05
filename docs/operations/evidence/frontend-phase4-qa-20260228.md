# Frontend Phase 4 QA Evidence (2026-02-28)

## Scope
Runtime verification for the remaining QA closure lanes in `docs/BRANDING_PLAN.md`:
- Cross-browser + mobile smoke
- Accessibility contrast/focus scan
- Frontend performance spot-check

## Commands Run

```bash
./scripts/qa/verify-cross-browser-branding-smoke.sh --env prod --cross-browser
./scripts/qa/verify-a11y-contrast-focus.sh --env prod
./scripts/qa/verify-frontend-performance-spotcheck.sh --env prod
./scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.io --require-runtime-theme --project chromium
```

## Results

### 1) Cross-browser smoke
- Status: PASS
- Summary: 12/12 tests passed (chromium, firefox, mobile-chrome)
- Note: WebKit dependency warning observed on host probe; webkit lane skipped for this run.
- Artifact: `var/qa/cross-browser-branding-smoke-prod-20260228T211009Z.log`

### 2) Accessibility contrast/focus
- Status: PASS
- Summary: PASS=29, WARN=2, FAIL=0
- Artifact: `var/a11y-contrast-focus-gate.txt`

### 3) Frontend performance spot-check
- Status: PASS
- Summary (script output): `Summary: PASSED=14 FAILED=0` and `PASS=10 WARN=2 FAIL=0`
- Artifact: script output only (no explicit artifact path emitted by the command)

### 4) Strict runtime-theme npm-start smoke

- Status: FAIL (expected deployment blocker signal)
- Failure: `runtime theme mode required, but detected 'embedded-theme-files'`
- Failing preflight target: `https://apps.academyv2.mereka.io/authn/login`
- Artifact: `var/qa/npm-start-mfe-smoke-20260228T211231Z.log`

## Outcome
Cross-browser, accessibility, and performance runtime checks are green, but strict runtime-theme mode is still blocked in production until MFE rollout serves `/theme/*.min.css` (instead of embedded authn hash CSS).
