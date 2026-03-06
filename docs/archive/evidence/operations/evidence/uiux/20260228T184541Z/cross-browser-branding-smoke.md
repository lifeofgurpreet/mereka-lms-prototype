Cross-Browser Branding Smoke Evidence
Generated: 2026-02-28T18:45:41Z
Branch: build/tenantfix-20260228-r6

## Scope

Validated updated Playwright branding smoke contract after hardening:
- Dual-mode theme contract detection (`runtime-theme-urls` vs `embedded-theme-files`)
- Optional learning-route coverage
- Strict runtime-theme gate toggle (`REQUIRE_RUNTIME_THEME_URLS=1`)

## Commands

```bash
./scripts/qa/verify-cross-browser-branding-smoke.sh --env prod --learning-path /learning
./scripts/qa/verify-cross-browser-branding-smoke.sh --env prod --cross-browser --learning-path /learning
./scripts/qa/verify-cross-browser-branding-smoke.sh --env prod --learning-path /learning --require-runtime-theme
```

## Results

### Baseline smoke (Chromium only)
- PASS: 4/4
- Routes:
  - `/authn/login`
  - `/learner-dashboard/`
  - `/account/settings`
  - `/learning` (via `--learning-path`)
- Log: `var/qa/cross-browser-branding-smoke-prod-20260228T184139Z.log`

### Cross-browser smoke
- PASS: 12/12
- Browser projects:
  - `chromium` (4/4)
  - `firefox` (4/4)
  - `mobile-chrome` (4/4)
- WebKit status:
  - Auto-disabled by probe fallback due host dependency gap.
  - This is expected behavior for the current runner and non-blocking for this check.
- Log: `var/qa/cross-browser-branding-smoke-prod-20260228T184541Z.log`

### Strict runtime-theme mode
- FAIL (expected on current prod image): `embedded-theme-files` detected instead of `runtime-theme-urls`.
- Gate behavior is correct: fails hard when `--require-runtime-theme` is set and `/api/mfe_config/v1` does not expose `PARAGON_THEME_URLS` + `/theme/*.min.css`.
- This mode is intended for post-image-rollout enforcement.

## Conclusion

The updated smoke harness is stable in normal mode, expands route coverage to include learning, and now provides a deterministic rollout gate for runtime `/theme/*.min.css` activation.
