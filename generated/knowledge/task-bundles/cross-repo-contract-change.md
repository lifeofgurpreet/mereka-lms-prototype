<!-- GENERATED FILE: DO NOT EDIT DIRECTLY. Rebuild with tools/knowledge/build_agent_task_bundles.py -->
# Task Bundle: cross repo contract change

- Purpose: Change or review repo-to-infra contract surfaces and downstream deployment fallout.
- Why this bundle exists: Makes infra-coupled fallout visible before an agent edits app-repo contract surfaces.
- What this bundle intentionally excludes: Does not guess missing infra file mappings where Wave 6 still marks them unknown.

## Read First
- `docs/meta/contracts/CONTRACT_RUNTIME_MODEL.md` [canonical] Canonical entrypoint for domain `cross-repo contracts`.
- `docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml` [canonical] Canonical entrypoint for domain `cross-repo contracts`.
- `docs/meta/contracts/INFRA_CROSSWALK.md` [canonical] Canonical entrypoint for domain `cross-repo contracts`.
- `generated/contracts/cross-repo-manifest.json` [generated] Canonical entrypoint for domain `cross-repo contracts`.
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml` [canonical] Canonical entrypoint for domain `runtime/release`.
- `generated/contracts/release-obligations.md` [generated] Canonical entrypoint for domain `runtime/release`.
- `generated/contracts/deployment-impact-report.json` [generated] Canonical entrypoint for domain `runtime/release`.

## Surface Meaning
- Normative: none
- Proposal: none
- Plan: none
- Generated: generated/contracts/cross-repo-manifest.json, generated/contracts/deployment-impact-report.json, generated/contracts/release-obligations.md, generated/knowledge/agent-entrypoints.json, generated/knowledge/change-manifest.json, generated/knowledge/review-bundle.md, generated/knowledge/truth-impact-report.json
- Historical context only: docs/archive/**, guessed infra paths

## Reviewers And Evidence
- Reviewers: architecture, docs, platform
- Evidence: cross_repo_manifest, deployment_impact, incident_notes, release_obligations, review_bundle, runtime_evidence

## Validation Commands
- `bash scripts/qa/run-cross-repo-contract-gates.sh`
- `python3 tools/contracts/build_cross_repo_manifest.py --check --range origin/main...HEAD --repo-root .`
- `python3 tools/contracts/build_deployment_impact_report.py --check --range origin/main...HEAD --repo-root .`

## Cross-Repo Fallout
- Overall verdict: `infra_counterpart_required`
- Repositories: bbi-infrastructure
- Reviewers: architecture, platform, release, security, tenancy_auth
