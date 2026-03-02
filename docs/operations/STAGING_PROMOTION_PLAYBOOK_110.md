# Staging Promotion Playbook (`#110`)

Date: 2026-03-02  
Scope: Promotion execution checklist once operator signal is given.

## Preconditions

- Repo-side frontend/runtime gates are green (see `FRONTEND_RUNTIME_STABILITY_STATUS_2026-03-02.md`).
- Promotion approval explicitly received.
- If promotion involves GitOps overlays, ensure authorized operator context for infra repo operations.
- Preflight repo check is green:

```bash
./scripts/qa/verify-staging-activation.sh --offline
```

## Blocked-State Rule (Current Lane)

- If explicit infra/GitOps promotion signal has **not** been given, stop before step 3.
- In blocked mode, only do repo-local preparation:
  - refresh dev baseline evidence
  - keep rollback command path documented
  - post blocker status to `#110` with current evidence links
- Do not touch `bbi-infrastructure` overlays or Argo resources in blocked mode.

## Latest Repo-Local Baseline (2026-03-02T035438Z)

- All repo-local pre-promotion checks are green:
  - `capture-branding-screenshots.sh --env dev --mfe-only` (`exit=0`)
  - `verify-paragon-runtime.sh ... --require-slot-markers` (`PASS=17 WARN=0 FAIL=0`)
  - `verify-studio-authoring-branding.sh dev` (`failures=0`)
  - `run-phase7-dom-audit-full.sh --env dev --project chromium` (`1 passed`)
  - `verify-mfe-selector-hardening.sh` (`PASS=31 FAIL=0 WARN=0`)
  - `verify-a11y-contrast-focus.sh` (`PASS=29 WARN=2 FAIL=0`)
  - `verify-wcag-contrast-v2.sh` (`28 PASS / 0 FAIL`)
- Evidence artifacts:
  - `var/qa/staging-prepromotion-dev-baseline-20260302T035438Z.summary.log`
  - `var/screenshots/dev/20260302T035438Z/`

## Promotion Run Sequence

1. Validate source branch state in `mereka-lms`:

```bash
git fetch --all --prune
git switch start/next-implementor-2026-03-01
git pull --ff-only
git status --short --branch
```

2. Re-run frontend closure gates before promotion:

```bash
./scripts/qa/capture-branding-screenshots.sh --env dev --mfe-only
./scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.dev --require-slot-markers
./scripts/qa/verify-studio-authoring-branding.sh dev
./scripts/qa/verify-mfe-live-dom-audit.sh --env dev --audit-profile phase7_full --project chromium
./scripts/qa/verify-mfe-selector-hardening.sh
./scripts/qa/verify-a11y-contrast-focus.sh
./scripts/qa/verify-wcag-contrast-v2.sh
./scripts/qa/verify-certificate-branding.sh
```

3. Promotion execution (when infra signal is granted):
- Follow canonical release/promotion command set already documented in repo ops docs.
- Capture image tags/digests, target refs, and rollout status outputs.

4. Post-promotion runtime verification:

```bash
./scripts/qa/verify-paragon-runtime.sh --runtime-url <target_apps_url> --require-slot-markers
./scripts/qa/verify-studio-authoring-branding.sh <target_env>
./scripts/qa/verify-mfe-live-dom-audit.sh --env <target_env> --audit-profile phase7_full --project chromium
```

## Evidence Checklist (required for `#110`)

- Promotion command transcript with timestamp.
- Runtime verification outputs (all PASS) for target environment.
- Screenshot bundle path for target environment.
- Rollback command transcript and rollback verification (if exercised).

## Rollback Sequence

1. Revert promotion commit(s) in the relevant repo(s):

```bash
git log --oneline -n 10
git revert <sha>
git push
```

2. Verify rollback runtime:

```bash
./scripts/qa/verify-paragon-runtime.sh --runtime-url <target_apps_url> --require-slot-markers
./scripts/qa/verify-studio-authoring-branding.sh <target_env>
./scripts/qa/verify-mfe-live-dom-audit.sh --env <target_env> --audit-profile phase7_full --project chromium
```

## Notes

- This playbook is preparation-only in the current lane; no infra repo actions were executed.
