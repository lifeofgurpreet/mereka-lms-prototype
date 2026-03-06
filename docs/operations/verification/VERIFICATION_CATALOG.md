# Verification Catalog

Machine-readable source: `docs/operations/verification/verification_catalog.json`.

## Core Entrypoints
- `scripts/qa/run-release-verification-gates.sh` — **Static release-blocking gates**: PR + push static verification suite from .github/ci-scripts-static.txt
- `scripts/qa/run-operations-gates.sh` — **Operations runtime gates**: Consolidated runtime governance gate (auth, multisite, observability, backups)
- `scripts/qa/run-multisite-governance-gates.sh` — **Multisite runtime gates**: Tenant/multisite runtime governance checks

## Summary
- Total `verify-*.sh` scripts: **498**
- Archived deprecated scripts: **21**
- CI static-bound scripts: **336**
- Workflow-direct bound scripts: **49**
- Status overrides applied: **8**

### Tier Distribution
- `exploratory_manual`: 130
- `periodic_runtime`: 12
- `release_blocking`: 356

### Status Distribution
- `active`: 371
- `manual_only`: 127

## Deprecated Candidates

- None

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
- `scripts/qa/deprecated/verify-patch-modularity.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check with stale assumptions about direct patch-function invocation in apply-patches.sh after plugin-driven patch orchestration changes.)
- `scripts/qa/deprecated/verify-tutor-patches-inventory.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check with stale inventory/parser assumptions (including non-Python plugin companion files) that no longer match current Tutor plugin contract layout.)
- `scripts/qa/deprecated/verify-email-ace-channels.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check that reports warning-only posture when email plugin/config surfaces are absent, providing low signal for current architecture.)
- `scripts/qa/deprecated/verify-email-bulk-campaigns.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check against optional bulk-email plugin paths that are absent in the active stack and currently emit warning-only results.)
- `scripts/qa/deprecated/verify-email-digests-code.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check against optional email-digests plugin paths that are absent in the active stack and currently emit warning-only results.)
- `scripts/qa/deprecated/verify-email-inapp-code.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check against optional in-app notifications plugin paths that are absent in the active stack and currently emit warning-only results.)
- `scripts/qa/deprecated/verify-email-push-code.sh` → `scripts/qa/run-release-verification-gates.sh` (Unbound exploratory check against optional push-notifications plugin paths that are absent in the active stack and currently emit warning-only results.)

## Lifecycle Policy
- `release_blocking`: MUST stay bound to CI static or direct workflow execution.
- `periodic_runtime`: SHOULD run via scheduled/runtime gates (`run-operations-gates.sh`, multisite gates).
- `exploratory_manual`: MAY run on-demand; candidates can be deprecated or archived once replacement exists.
