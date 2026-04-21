# Verification Catalog

Machine-readable source: `verification/catalogs/verification_catalog.json`.

## Core Entrypoints
- `scripts/qa/run-release-verification-gates.sh` — **Static release-blocking gates**: PR + push static verification suite from .github/ci-scripts-static.txt
- `scripts/qa/run-operations-gates.sh` — **Operations runtime gates**: Consolidated runtime governance gate (auth, multisite, observability, backups)
- `scripts/qa/run-multisite-governance-gates.sh` — **Multisite runtime gates**: Tenant/multisite runtime governance checks

## Summary
- Total `verify-*.sh` scripts: **634**
- Archived deprecated scripts: **25**
- CI static-bound scripts: **386**
- Workflow-direct bound scripts: **72**
- Status overrides applied: **8**

### Tier Distribution
- `exploratory_manual`: 196
- `periodic_runtime`: 21
- `release_blocking`: 417

### Status Distribution
- `active`: 441
- `deprecated_candidate`: 1
- `manual_only`: 192

### Kind Distribution
- `verify`: 634

### Mutability Distribution
- `destructive`: 9
- `mutating`: 21
- `read-only`: 604

## Deprecated Candidates

Scripts currently not CI-bound and with near-zero references:
- `scripts/qa/verify-phase7-selector-list-coverage.sh` (owner: `platform-core`, refs: 1)

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
- `scripts/qa/deprecated/verify-footer-slot-only.sh` → `scripts/qa/run-release-verification-gates.sh` (Overlapping scope superseded by verify-footer-parity.sh (canonical gate). AC-FTR-301/302/304 checks are fully covered by the parity gate. Bead: mereka-lms-1kwf.1 PR-B.)
- `scripts/qa/deprecated/verify-footer-slot-migration.sh` → `scripts/qa/run-release-verification-gates.sh` (Transient migration-phase verifier; migration complete. Coverage subsumed by verify-footer-parity.sh canonical gate. Bead: mereka-lms-1kwf.1 PR-B.)
- `scripts/qa/deprecated/verify-mfe-footer-slot-migration.sh` → `scripts/qa/run-release-verification-gates.sh` (Transient MFE slot migration verifier; migration complete. MFE footer slot coverage subsumed by verify-footer-parity.sh canonical gate. Bead: mereka-lms-1kwf.1 PR-B.)
- `scripts/qa/deprecated/verify-footer-slot-evidence-rollback.sh` → `scripts/qa/run-release-verification-gates.sh` (Rollback-guard verifier for a one-time migration; migration complete and stable. Evidence-rollback risk now monitored by verify-footer-parity.sh. Bead: mereka-lms-1kwf.1 PR-B.)

## Lifecycle Policy
- `release_blocking`: MUST stay bound to CI static or direct workflow execution.
- `periodic_runtime`: SHOULD run via scheduled/runtime gates (`run-operations-gates.sh`, multisite gates).
- `exploratory_manual`: MAY run on-demand; candidates can be deprecated or archived once replacement exists.
