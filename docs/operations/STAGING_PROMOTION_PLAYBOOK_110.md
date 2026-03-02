# Staging Promotion Playbook (`#110`)

Date: 2026-03-02  
Scope: Promotion execution checklist once operator signal is given.

## Preconditions

- Repo-side frontend/runtime gates are green (see `FRONTEND_RUNTIME_STABILITY_STATUS_2026-03-02.md`).
- Promotion approval explicitly received.
- If promotion involves GitOps overlays, ensure authorized operator context for infra repo operations.

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
