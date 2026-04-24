<!-- GENERATED FILE: DO NOT EDIT DIRECTLY. Rebuild with tools/knowledge/build_agent_task_bundles.py -->
# Task Bundle: incident debug

- Purpose: Debug runtime incidents using canonical runbooks and runtime impact surfaces.
- Why this bundle exists: Starts incident work from runtime and runbook truth instead of stale status notes.
- What this bundle intentionally excludes: Does not claim live-cluster truth beyond the repo and generated runtime evidence.

## Read First
- `specs/slo-sla-service-level-management_spec.md` [normative] Canonical entrypoint for domain `observability`.
- `generated/contracts/deployment-impact-report.json` [generated] Canonical entrypoint for domain `observability`.
- `generated/knowledge/truth-impact-report.json` [generated] Canonical entrypoint for domain `observability`.
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml` [canonical] Canonical entrypoint for domain `runtime/release`.
- `generated/contracts/release-obligations.md` [generated] Canonical entrypoint for domain `runtime/release`.

## Surface Meaning
- Normative: specs/slo-sla-service-level-management_spec.md
- Proposal: none
- Plan: none
- Generated: generated/contracts/cross-repo-manifest.json, generated/contracts/deployment-impact-report.json, generated/contracts/release-obligations.md, generated/knowledge/agent-entrypoints.json, generated/knowledge/change-manifest.json, generated/knowledge/review-bundle.md, generated/knowledge/truth-impact-report.json
- Historical context only: docs/archive/**, stale status notes

## Reviewers And Evidence
- Reviewers: architecture, docs, platform
- Evidence: cross_repo_manifest, deployment_impact, incident_notes, release_obligations, review_bundle, runtime_evidence

## Validation Commands
- `bash scripts/qa/run-cross-repo-contract-gates.sh`
- `bash scripts/qa/run-knowledge-runtime-gates.sh`

## Cross-Repo Fallout
- Overall verdict: `infra_counterpart_required`
- Repositories: bbi-infrastructure
- Reviewers: architecture, platform, release, security, tenancy_auth
