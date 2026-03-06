# Verification Catalog

Machine-readable source: `docs/operations/verification/verification_catalog.json`.

## Core Entrypoints
- `scripts/qa/run-release-verification-gates.sh` — **Static release-blocking gates**: PR + push static verification suite from .github/ci-scripts-static.txt
- `scripts/qa/run-operations-gates.sh` — **Operations runtime gates**: Consolidated runtime governance gate (auth, multisite, observability, backups)
- `scripts/qa/run-multisite-governance-gates.sh` — **Multisite runtime gates**: Tenant/multisite runtime governance checks

## Summary
- Total `verify-*.sh` scripts: **503**
- Archived deprecated scripts: **14**
- CI static-bound scripts: **326**
- Workflow-direct bound scripts: **49**

### Tier Distribution
- `exploratory_manual`: 150
- `periodic_runtime`: 7
- `release_blocking`: 346

### Status Distribution
- `active`: 353
- `deprecated_candidate`: 23
- `manual_only`: 127

## Deprecated Candidates

Scripts currently not CI-bound and with near-zero references:
- `scripts/qa/verify-audit-logging.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-branding-evidence-a11y-contract.sh` (owner: `frontend-platform`, refs: 1)
- `scripts/qa/verify-branding-evidence-screenshot-contract.sh` (owner: `frontend-platform`, refs: 1)
- `scripts/qa/verify-cicd-ios-build.sh` (owner: `frontend-platform`, refs: 1)
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
- `scripts/qa/verify-libraries-core.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-mobile-backend-api.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-notifications-inapp.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-patch-modularity.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-restore-drill.sh` (owner: `sre-security`, refs: 1)
- `scripts/qa/verify-spec-dedupe-normalize.sh` (owner: `platform-core`, refs: 1)
- `scripts/qa/verify-tutor-patches-inventory.sh` (owner: `platform-infra`, refs: 1)
- `scripts/qa/verify-video-protection.sh` (owner: `migration-platform`, refs: 1)

## Archived Deprecated Scripts

- `scripts/qa/deprecated/verify-api-contracts.sh` → `scripts/qa/run-release-verification-gates.sh` (Unreferenced legacy point-check; consolidated under canonical release gate entrypoint.)
- `scripts/qa/deprecated/verify-build-optimizations.sh` → `scripts/qa/run-release-verification-gates.sh` (Unreferenced legacy point-check; consolidated under canonical release gate entrypoint.)
- `scripts/qa/deprecated/verify-capacity-planning.sh` → `scripts/qa/run-release-verification-gates.sh` (Unreferenced legacy point-check; consolidated under canonical release gate entrypoint.)
- `scripts/qa/deprecated/verify-data-retention.sh` → `scripts/qa/run-release-verification-gates.sh` (Unreferenced legacy point-check; consolidated under canonical release gate entrypoint.)
- `scripts/qa/deprecated/verify-devcontainer.sh` → `scripts/qa/run-release-verification-gates.sh` (Unreferenced legacy point-check; consolidated under canonical release gate entrypoint.)
- `scripts/qa/deprecated/verify-bash-strict-mode.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check with zero references; strict-mode posture is already enforced by release-gate scripts and repo lint contracts.)
- `scripts/qa/deprecated/verify-ux-audit-coverage.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check with zero references and stale section contracts that no longer match the active UI/UX audit report.)
- `scripts/qa/deprecated/verify-k8s-validation-job.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check with stale kubeconform bootstrap assumptions and broken pass/fail counters under strict-mode shell semantics.)
- `scripts/qa/deprecated/verify-lint-job.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check with broken pass/fail counters under strict-mode shell semantics and no CI/workflow binding.)
- `scripts/qa/deprecated/verify-gh-actions-budget-config.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check for non-existent GitHub Actions budget config with strict-mode counter semantics that terminate on first warning.)
- `scripts/qa/deprecated/verify-gh-actions-cost-dashboard.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check for non-existent GitHub Actions cost dashboard with strict-mode counter semantics that terminate on first warning.)
- `scripts/qa/deprecated/verify-gh-actions-cost-tracking.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check for non-existent GitHub Actions cost tracking script with strict-mode counter semantics that terminate on first warning.)
- `scripts/qa/deprecated/verify-cicd-image-build.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check with stale CI contract assumptions (deprecated build inputs) no longer matching the active build workflow.)
- `scripts/qa/deprecated/verify-cicd-scheduled-ops.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check with stale scheduled-ops workflow assumptions no longer matching active runtime gate workflows.)

## Lifecycle Policy
- `release_blocking`: MUST stay bound to CI static or direct workflow execution.
- `periodic_runtime`: SHOULD run via scheduled/runtime gates (`run-operations-gates.sh`, multisite gates).
- `exploratory_manual`: MAY run on-demand; candidates can be deprecated or archived once replacement exists.
