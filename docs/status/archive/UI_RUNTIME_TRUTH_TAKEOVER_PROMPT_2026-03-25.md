# UI Runtime Truth Takeover Prompt

You are taking over the `mereka-lms` UI/browser-proof reproducibility lane.

Start by reading:

1. `docs/status/active/UI_RUNTIME_TRUTH_TRACKER_2026-03-25.md`
2. `docs/status/active/README.md`
3. `scripts/qa/verify-e2e-framework.sh`
4. `tests/e2e/package.json`

Then work from the tracker in order. Do not rediscover the queue.

## Mission

Make the clean-checkout browser-audit path truthful and reproducible, and keep the handoff honest about what is and is not yet live-proven.

The objective is not "the docs look complete." The objective is "another operator can start from a clean checkout and reproduce the browser harness without guessing."

## Immediate first task

Start with `UI-01` from the tracker: reproduce the browser-audit path from a clean checkout.

Current verified path:

1. `bash scripts/qa/verify-e2e-framework.sh`
2. `cd tests/e2e && npm ci`
3. `cd tests/e2e && npx playwright install chromium --force`
4. `cd tests/e2e && node -e "const { chromium } = require('./node_modules/playwright'); chromium.launch({ headless: true }).then(async b => { console.log('PLAYWRIGHT_LAUNCH_OK'); await b.close(); }).catch(err => { console.error(err && (err.stack || err.message || String(err))); process.exit(1); });"`

Verified facts:

- the clean browser worktree is `/tmp/mereka-lms-ui-proof-pr`
- the base commit is `865dc06a`
- `npm ci` populates `tests/e2e/node_modules`
- `npx playwright install chromium --force` repairs an incomplete Chromium cache when the headless-shell executable is missing
- the launch command succeeds when the cache is repaired

## Non-negotiable rules

- Do not claim live LMS/Studio/mobile closure unless you actually recapture it.
- Do not trust old tracker text over fresh clean-checkout verification.
- Do not expand into staging-proof workflow changes from this lane.
- Do not edit unrelated dirty files just because they show up in `git status`.
- Do not leave the tracker pointing at missing files.

## Current candidate fix set already in the worktree

Treat these as the only UI handoff files you should touch unless a verifier forces something else:

- `docs/status/active/UI_RUNTIME_TRUTH_TRACKER_2026-03-25.md`
- `docs/status/active/UI_RUNTIME_TRUTH_TAKEOVER_PROMPT_2026-03-25.md`
- `docs/status/active/README.md`
- `scripts/qa/verify-e2e-framework.sh`

## Required rerun commands

- `git diff --check`
- `bash scripts/qa/verify-e2e-framework.sh`
- `cd tests/e2e && npm ci`
- `cd tests/e2e && npx playwright install chromium --force`
- `cd tests/e2e && node -e "const { chromium } = require('./node_modules/playwright'); chromium.launch({ headless: true }).then(async b => { console.log('PLAYWRIGHT_LAUNCH_OK'); await b.close(); }).catch(err => { console.error(err && (err.stack || err.message || String(err))); process.exit(1); });"`

## Deliverables

Before stopping, leave behind all of the following:

1. updated UI tracker text that matches the actual clean-checkout operator path
2. prompt and README links that point to existing files
3. exact validation commands and outcomes
4. explicit statement of which UI truth dimensions are still open
5. a brief note on any cache or environment repair needed for Chromium

## Minimum acceptable success for this lane

- a clean checkout can bootstrap `tests/e2e`
- the browser cache repair step is explicit and reproducible
- the Playwright launch command succeeds
- the tracker no longer points at missing files or stale closure claims
