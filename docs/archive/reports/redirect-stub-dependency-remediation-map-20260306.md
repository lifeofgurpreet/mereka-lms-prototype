# Redirect Stub Dependency Remediation Map 2026-03-06
_Audience: Docs Lead + Platform Eng • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## Scope
- Remaining superseded markdown stubs outside archive: 0
- Purpose: enumerate non-doc dependencies that must be updated before final stub reclassification/archive.

## Remediation Table
| Legacy Stub | Canonical Target | Dependency Class | Blocking References |
|---|---|---|---|
| `docs/branding/BRANDING_OPERATING_MODEL.md` | `docs/guides/branding/BRANDING_OPERATING_MODEL.md` | `script` | scripts/qa/check-forbidden-overrides.sh<br>scripts/qa/verify-visual-parity-checkpoints.sh<br>scripts/qa/lint-active-docs-env-model.sh<br>scripts/qa/verify-no-dom-overrides.sh<br>scripts/qa/verify-mfe-footer-slot-migration.sh |
| `docs/branding/MULTI_TENANT_BRANDING_OPS.md` | `docs/guides/branding/MULTI_TENANT_BRANDING_OPS.md` | `script` | scripts/qa/verify-multi-tenant-branding-ops.sh |
| `docs/branding/PLUGIN_MIGRATION_SURVEY.md` | `docs/guides/branding/PLUGIN_MIGRATION_SURVEY.md` | `script` | scripts/qa/check-forbidden-overrides.sh |
| `docs/branding/TENANT_BRANDING_CONTRACT.md` | `docs/guides/branding/TENANT_BRANDING_CONTRACT.md` | `script` | scripts/qa/verify-tenant-branding-contract.sh<br>scripts/qa/verify-brand-pack-schema.sh |
| `docs/branding/TENANT_CONFIG_HANDOFF.md` | `docs/guides/branding/TENANT_CONFIG_HANDOFF.md` | `script` | scripts/qa/verify-tenant-config-handoff.sh |
| `docs/branding/VISUAL_PARITY_CHECKPOINTS.md` | `docs/guides/branding/VISUAL_PARITY_CHECKPOINTS.md` | `script` | scripts/qa/verify-visual-parity-checkpoints.sh<br>scripts/qa/verify-ui-ux-hardening-bundle.sh |
| `docs/runbooks/operations/ACCESSIBILITY_CONFORMANCE_RUNBOOK.md` | `docs/runbooks/operations/ACCESSIBILITY_CONFORMANCE_RUNBOOK.md` | `script` | scripts/qa/verify-a11y-tenant-branding.sh<br>scripts/qa/verify-a11y-authenticated-routes.sh<br>scripts/qa/verify-tenant-ui-smoke.sh |
| `docs/operations/ACCESS_URLS.md` | `docs/ops/quickref/access-urls.md` | `script` | scripts/qa/verify-operator-dashboards.sh |
| `docs/policies/operations/ALLOWED_ACTIONS_POLICY.md` | `docs/policies/operations/ALLOWED_ACTIONS_POLICY.md` | `script` | scripts/qa/verify-actions-pinned.sh |
| `docs/operations/CI_CD_SETUP.md` | `docs/reference/operations/CI_CD_SETUP.md` | `script` | scripts/qa/lint-active-docs-env-model.sh |
| `docs/operations/CI_RUNNER_POLICY.md` | `docs/policies/operations/CI_RUNNER_POLICY.md` | `script` | scripts/qa/verify-ci-runner-policy.sh |
| `docs/runbooks/operations/DATA_ERASURE_RUNBOOK.md` | `docs/runbooks/operations/DATA_ERASURE_RUNBOOK.md` | `script` | scripts/qa/deprecated/verify-data-retention.sh<br>scripts/qa/verify-pii-inventory.sh |
| `docs/runbooks/operations/ENTERPRISE_SERVICES_RUNBOOK.md` | `docs/runbooks/operations/ENTERPRISE_SERVICES_RUNBOOK.md` | `script` | scripts/qa/verify-enterprise-all-acs.sh |
| `docs/operations/ENTERPRISE_SSO_GUIDE.md` | `docs/ops/security/ENTERPRISE_SSO_GUIDE.md` | `script` | scripts/qa/verify-enterprise-sso-readiness.sh |
| `docs/operations/GITHUB_ACTIONS_COST_MONITORING.md` | `docs/ops/ci-cd/GITHUB_ACTIONS_COST_MONITORING.md` | `script` | scripts/qa/verify-github-actions-cost.sh |
| `docs/operations/LOGGING_AND_SENTRY.md` | `docs/ops/monitoring/LOGGING_AND_SENTRY.md` | `script` | scripts/qa/verify-rke2-rollout-readiness.sh |
| `docs/operations/MONITORING.md` | `docs/reference/operations/MONITORING.md` | `script` | scripts/qa/verify-rke2-rollout-readiness.sh<br>scripts/qa/verify-operator-dashboards.sh |
| `docs/reference/operations/OBSERVABILITY_PARITY_MATRIX.md` | `docs/reference/operations/OBSERVABILITY_PARITY_MATRIX.md` | `workflow` | .github/workflows/observability-compliance.yml |
| `docs/operations/OBSERVABILITY_QUICKSTART.md` | `docs/ops/monitoring/OBSERVABILITY_QUICKSTART.md` | `script` | scripts/qa/verify-operator-dashboards.sh |
| `docs/operations/SECRET_ROTATION_CHECKLIST.md` | `docs/runbooks/operations/SECRET_ROTATION_CHECKLIST.md` | `script` | scripts/qa/verify-disaster-recovery.sh |
| `docs/operations/SECURITY_EXCEPTIONS.md` | `docs/policies/operations/SECURITY_EXCEPTIONS.md` | `script+workflow` | .github/workflows/security-exceptions.yml<br>scripts/qa/verify-security-exceptions.sh |
| `docs/operations/VISUAL_REGRESSION.md` | `docs/runbooks/operations/VISUAL_REGRESSION_RUNBOOK.md` | `script` | scripts/qa/verify-visual-baselines.sh |
| `docs/runbooks/operations/VISUAL_REGRESSION_RUNBOOK.md` | `docs/runbooks/operations/VISUAL_REGRESSION_RUNBOOK.md` | `script` | scripts/qa/verify-visual-parity-checkpoints.sh<br>scripts/qa/verify-visual-smoke-baseline.sh<br>scripts/qa/verify-ui-ux-hardening-bundle.sh |
| `docs/operations/credential-backfill-runbook.md` | `docs/ops/runbooks/credential-backfill-runbook.md` | `script` | scripts/qa/verify-credentials-ops.sh<br>scripts/qa/verify-vc-ops.sh |
| `docs/operations/credential-issuance-failure-runbook.md` | `docs/ops/runbooks/credential-issuance-failure-runbook.md` | `script` | scripts/qa/verify-credentials-ops.sh<br>scripts/qa/verify-vc-ops.sh |
| `docs/operations/credential-key-rotation-runbook.md` | `docs/ops/runbooks/credential-key-rotation-runbook.md` | `script` | scripts/qa/verify-credentials-ops.sh<br>scripts/qa/verify-credentials-issuer.sh<br>scripts/qa/verify-vc-issuer.sh<br>scripts/qa/verify-vc-ops.sh |
| `docs/operations/credential-verification-failure-runbook.md` | `docs/ops/runbooks/credential-verification-failure-runbook.md` | `script` | scripts/qa/verify-credentials-ops.sh<br>scripts/qa/verify-vc-ops.sh |

## Execution Outcome
1. Script/workflow references listed in this map were updated to canonical targets.
2. `tools/docs/verify/verify-docs-policy.sh` passed after dependency updates.
3. All mapped stubs were reclassified from `superseded` to `archive-candidate`.
