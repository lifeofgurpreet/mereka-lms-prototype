# Wave 6 Cross-Repo Contract Runtime Closeout

## What Wave 6 added

- A source-controlled contract model for cross-repo ownership, release obligations, and deployment surfaces.
- An explicit service contract inventory for the major deployable units: openedx, mfe, purchase-gateway, enterprise-services, runner-ci, and observability-runtime.
- A crosswalk from app-repo deployment truth to the known external GitOps overlay roots in `bbi-infrastructure`.
- A machine-readable cross-repo manifest that classifies the current branch diff into service-level counterpart obligations.
- A machine-readable deployment impact report that tells reviewers whether infra work is required, manual review is required, or the change is app-only.
- A human-facing release obligations packet that explains required infra follow-up, evidence, runbooks, release-note treatment, and reviewer expectations.
- A Wave 6 verifier and contract gate, wired into `docs-policy.yml`.

## What stayed intentionally unchanged

- Wave 4 topology remains intact.
- Wave 5 repo-native change intelligence remains the base layer.
- `docs/` and `specs/` remain separate filesystem roots.
- Wave 6 is repo-contract-only and does not claim live-cluster reconciliation.
- Unknown infra mappings are allowed only when explicit and reviewable.

## Current runtime posture

- The branch diff can now be classified into cross-repo service obligations.
- The current branch diff resolves overall to `infra_counterpart_required`.
- The required counterpart repo is visible as `bbi-infrastructure`.
- The remaining uncertainty is concentrated in exact GitOps file paths, not in whether cross-repo coupling exists.

## Remaining explicit unknowns

- openedx exact ArgoCD application and secret-store file paths
- mfe exact ingress, appset, and edge file paths
- purchase-gateway exact Stripe secret and ingress file paths
- enterprise-services per-service overlay decomposition
- runner-ci exact self-hosted runner host and secret provisioning file paths
- observability exact monitoring and alerting app file paths

## Recommended reviewer path

1. Run `bash scripts/qa/run-cross-repo-contract-gates.sh`.
2. Run `bash scripts/qa/run-knowledge-runtime-gates.sh`.
3. Read `generated/contracts/release-obligations.md`.
4. Check `generated/contracts/deployment-impact-report.json` for `infra_counterpart_required` and `manual_review_required` services.
5. Confirm whether a counterpart `bbi-infrastructure` PR exists for every service that is not app-only.

## Recommended next wave

- Use the Wave 6 runtime against real coupled app-plus-infra PRs and reduce the remaining exact-path unknowns with repo-backed crosswalk evidence rather than manual reviewer memory.
