# Verification Catalog

Machine-readable source: `docs/operations/verification/verification_catalog.json`.

## Core Entrypoints
- `scripts/qa/run-release-verification-gates.sh` — **Static release-blocking gates**: PR + push static verification suite from .github/ci-scripts-static.txt
- `scripts/qa/run-operations-gates.sh` — **Operations runtime gates**: Consolidated runtime governance gate (auth, multisite, observability, backups)
- `scripts/qa/run-multisite-governance-gates.sh` — **Multisite runtime gates**: Tenant/multisite runtime governance checks

## Summary
- Total `verify-*.sh` scripts: **499**
- Archived deprecated scripts: **5**
- CI static-bound scripts: **313**
- Workflow-direct bound scripts: **51**

### Tier Distribution
- `exploratory_manual`: 159
- `periodic_runtime`: 7
- `release_blocking`: 335

### Status Distribution
- `active`: 342
- `deprecated_candidate`: 32
- `manual_only`: 127

## Deprecated Candidates

Scripts currently not CI-bound and with near-zero references:
- `scripts/qa/verify-audit-logging.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-branding-evidence-a11y-contract.sh` (owner: `frontend-platform`, refs: 1)
- `scripts/qa/verify-branding-evidence-screenshot-contract.sh` (owner: `frontend-platform`, refs: 1)
- `scripts/qa/verify-cicd-image-build.sh` (owner: `frontend-platform`, refs: 1)
- `scripts/qa/verify-cicd-ios-build.sh` (owner: `frontend-platform`, refs: 1)
- `scripts/qa/verify-cicd-scheduled-ops.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-cicd-tutor-plugin-test.sh` (owner: `platform-infra`, refs: 1)
- `scripts/qa/verify-credentials-issuer.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-deprecation-discipline.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-email-ace-channels.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-email-bulk-campaigns.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-email-digests-code.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-email-digests.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-email-gdpr-code.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-email-inapp-code.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-email-preferences.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-email-push-code.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-gh-actions-budget-config.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-gh-actions-cost-dashboard.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-gh-actions-cost-tracking.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-k8s-validation-job.sh` (owner: `platform-infra`, refs: 1)
- `scripts/qa/verify-libraries-core.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-lint-job.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-mobile-backend-api.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-notifications-inapp.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-patch-modularity.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-repo-hygiene-artifacts.sh` (owner: `platform-core`, refs: 0)
- `scripts/qa/verify-restore-drill.sh` (owner: `sre-security`, refs: 1)
- `scripts/qa/verify-spec-dedupe-normalize.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-tutor-patches-inventory.sh` (owner: `platform-infra`, refs: 1)
- `scripts/qa/verify-ux-audit-coverage.sh` (owner: `frontend-platform`, refs: 0)
- `scripts/qa/verify-video-protection.sh` (owner: `migration-platform`, refs: 1)

## Archived Deprecated Scripts

- `scripts/qa/deprecated/verify-api-contracts.sh` → `scripts/qa/run-release-verification-gates.sh` (Unreferenced legacy point-check; consolidated under canonical release gate entrypoint.)
- `scripts/qa/deprecated/verify-build-optimizations.sh` → `scripts/qa/run-release-verification-gates.sh` (Unreferenced legacy point-check; consolidated under canonical release gate entrypoint.)
- `scripts/qa/deprecated/verify-capacity-planning.sh` → `scripts/qa/run-release-verification-gates.sh` (Unreferenced legacy point-check; consolidated under canonical release gate entrypoint.)
- `scripts/qa/deprecated/verify-data-retention.sh` → `scripts/qa/run-release-verification-gates.sh` (Unreferenced legacy point-check; consolidated under canonical release gate entrypoint.)
- `scripts/qa/deprecated/verify-devcontainer.sh` → `scripts/qa/run-release-verification-gates.sh` (Unreferenced legacy point-check; consolidated under canonical release gate entrypoint.)

## Lifecycle Policy
- `release_blocking`: MUST stay bound to CI static or direct workflow execution.
- `periodic_runtime`: SHOULD run via scheduled/runtime gates (`run-operations-gates.sh`, multisite gates).
- `exploratory_manual`: MAY run on-demand; candidates can be deprecated or archived once replacement exists.
