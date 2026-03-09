<!-- GENERATED FILE: DO NOT EDIT DIRECTLY. Rebuild with tools/knowledge/build_agent_task_bundles.py -->
# Task Bundle: migration change

- Purpose: Execute or review migration-affecting changes against migration truth and companion plans.
- Why this bundle exists: Pairs normative migration law with execution companions and contract fallout.
- What this bundle intentionally excludes: Does not collapse intentionally normative migration specs into plans.

## Read First
- `docs/meta/contracts/CONTRACT_RUNTIME_MODEL.md` [canonical] Canonical entrypoint for domain `cross-repo contracts`.
- `docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml` [canonical] Canonical entrypoint for domain `cross-repo contracts`.
- `docs/meta/contracts/INFRA_CROSSWALK.md` [canonical] Canonical entrypoint for domain `cross-repo contracts`.
- `generated/contracts/cross-repo-manifest.json` [generated] Canonical entrypoint for domain `cross-repo contracts`.
- `specs/plans/mobile-apps-enterprise_plan.md` [plan] Canonical entrypoint for domain `mobile`.
- `docs/reference/architecture/MOBILE_TOKEN_PARITY.md` [canonical] Canonical entrypoint for domain `mobile`.
- `generated/contracts/release-obligations.md` [generated] Canonical entrypoint for domain `mobile`.

## Surface Meaning
- Normative: none
- Proposal: none
- Plan: specs/plans/mobile-apps-enterprise_plan.md
- Generated: generated/contracts/cross-repo-manifest.json, generated/contracts/deployment-impact-report.json, generated/contracts/release-obligations.md, generated/knowledge/agent-entrypoints.json, generated/knowledge/change-manifest.json, generated/knowledge/review-bundle.md, generated/knowledge/truth-impact-report.json
- Historical context only: deprecated migration prompts, docs/archive/**

## Reviewers And Evidence
- Reviewers: architecture, docs, platform
- Evidence: cross_repo_manifest, deployment_impact, incident_notes, migration_proof, release_obligations, review_bundle, runtime_evidence

## Validation Commands
- `bash scripts/qa/run-cross-repo-contract-gates.sh`
- `bash scripts/qa/run-knowledge-runtime-gates.sh`

## Cross-Repo Fallout
- Overall verdict: `infra_counterpart_required`
- Repositories: bbi-infrastructure
- Reviewers: architecture, platform, release, security, tenancy_auth
