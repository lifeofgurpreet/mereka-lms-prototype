<!-- GENERATED FILE: DO NOT EDIT DIRECTLY. Rebuild with tools/knowledge/build_agent_task_bundles.py -->
# Task Bundle: reviewer pass

- Purpose: Review an existing branch diff using the generated runtime surfaces first.
- Why this bundle exists: Gives reviewers and review agents one deterministic path through the change runtime.
- What this bundle intentionally excludes: Does not replace human judgment on mixed high-risk diffs.

## Read First
- `docs/meta/docs-program/WAVE4_CLOSEOUT.md` [canonical] Canonical entrypoint for domain `architecture`.
- `docs/adr` [canonical] Canonical entrypoint for domain `architecture`.
- `generated/knowledge/review-bundle.md` [generated] Canonical entrypoint for domain `architecture`.
- `generated/knowledge/truth-impact-report.json` [generated] Canonical entrypoint for domain `architecture`.
- `docs/meta/contracts/CONTRACT_RUNTIME_MODEL.md` [canonical] Canonical entrypoint for domain `cross-repo contracts`.
- `docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml` [canonical] Canonical entrypoint for domain `cross-repo contracts`.
- `docs/meta/contracts/INFRA_CROSSWALK.md` [canonical] Canonical entrypoint for domain `cross-repo contracts`.
- `generated/contracts/cross-repo-manifest.json` [generated] Canonical entrypoint for domain `cross-repo contracts`.

## Surface Meaning
- Normative: none
- Proposal: none
- Plan: none
- Generated: generated/contracts/cross-repo-manifest.json, generated/contracts/deployment-impact-report.json, generated/contracts/release-obligations.md, generated/knowledge/agent-entrypoints.json, generated/knowledge/change-manifest.json, generated/knowledge/review-bundle.md, generated/knowledge/truth-impact-report.json
- Historical context only: archive as default review source, raw repo grep as first pass

## Reviewers And Evidence
- Reviewers: architecture, docs, platform
- Evidence: cross_repo_manifest, deployment_impact, release_obligations, review_bundle, truth_impact_report

## Validation Commands
- `bash scripts/qa/run-knowledge-runtime-gates.sh`
- `bash scripts/qa/run-cross-repo-contract-gates.sh`

## Cross-Repo Fallout
- Overall verdict: `infra_counterpart_not_required`
- Repositories: none
- Reviewers: none
