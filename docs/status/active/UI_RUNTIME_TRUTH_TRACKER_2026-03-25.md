# UI Runtime Truth Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-26T03:25:37Z • Status: active_

This tracker records the truthful operator path for the UI/browser-proof lane. It only claims what was actually re-verified in the current clean worktree.

## Current verified signal

The clean browser-audit worktree was created from `origin/main` and is isolated from the dirty local checkout:

- path: `/tmp/mereka-lms-ui-proof-pr`
- branch: `detached HEAD`
- base commit: `865dc06a` (`fix(ci): increase sso-canary timeout to 20 min and add Playwright browser cache (#1050)`)

The clean-checkout bootstrap path was re-verified in that worktree:

1. `bash scripts/qa/verify-e2e-framework.sh`
2. `cd tests/e2e && npm ci`
3. `cd tests/e2e && npx playwright install chromium --force`
4. `cd tests/e2e && node -e "const { chromium } = require('./node_modules/playwright'); chromium.launch({ headless: true }).then(async b => { console.log('PLAYWRIGHT_LAUNCH_OK'); await b.close(); }).catch(err => { console.error(err && (err.stack || err.message || String(err))); process.exit(1); });"`

Verified outcomes:

- `bash scripts/qa/verify-e2e-framework.sh` passed offline
- `npm ci` populated `tests/e2e/node_modules` from the lockfile
- `npx playwright install chromium --force` repaired an incomplete browser cache and restored `chromium_headless_shell-1208/chrome-headless-shell`
- the exact Playwright launch command succeeded with `PLAYWRIGHT_LAUNCH_OK`
- `launchPersistentContext('/tmp/codex-pw-profile-2', { headless: true })` also succeeded

## What is now true

| Dimension | Current state | Why |
|---|---|---|
| Clean checkout bootstrap | closed | `npm ci` is the correct deterministic install step for `tests/e2e` |
| Browser cache repair | closed | `npx playwright install chromium --force` fixed the missing headless-shell executable in this environment |
| Browser harness launch | closed | Playwright launches successfully from the clean worktree |
| Live UI screenshots | open | this cleanup did not re-run the actual LMS/Studio/authn browser audits |
| Desktop/mobile parity | open | no fresh screenshot bundle was captured in this cleanup |
| Tracker truth | open | the repo now has a truthful handoff surface, but it still needs runtime evidence if the next agent runs the live audits |

## Immediate next steps

### UI-01 — Reproduce the browser audit path from a clean checkout

Done when:

- a clean worktree can run `npm ci`
- browser cache repair is explicitly documented as `npx playwright install chromium --force` when the cache is incomplete
- the Playwright launch command succeeds without relying on a dirty local checkout

### UI-02 — Capture live UI proof

Done when:

- LMS, Studio, authn, and at least one MFE route are screened in desktop and mobile viewports
- screenshot artifacts and routes are recorded here

### UI-03 — Keep the handoff truthful

Done when:

- no file here claims live UI closure without a fresh browser audit
- the prompt and README point to this tracker instead of stale or missing references

## Required checks after any change in this lane

- `git diff --check`
- `bash scripts/qa/verify-e2e-framework.sh`
- `cd tests/e2e && npm ci`
- `cd tests/e2e && npx playwright install chromium --force`
- `cd tests/e2e && node -e "const { chromium } = require('./node_modules/playwright'); chromium.launch({ headless: true }).then(async b => { console.log('PLAYWRIGHT_LAUNCH_OK'); await b.close(); }).catch(err => { console.error(err && (err.stack || err.message || String(err))); process.exit(1); });"`

## Residual risks

- The current checkout still contains unrelated dirty files from other workstreams; only scoped diffs should be used for UI handoff edits.
- A fresh machine may still need the Chromium cache repaired the first time; this tracker records the exact fix that worked here.
- No live site screenshot bundle was produced during this cleanup, so runtime UI parity remains a follow-up, not a closure claim.
