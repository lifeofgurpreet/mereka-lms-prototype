<!-- GENERATED FILE: DO NOT EDIT DIRECTLY. Rebuild with tools/knowledge/build_agent_task_bundles.py -->
# Task Bundle: normative spec change

- Purpose: Update or review normative contract truth.
- Why this bundle exists: Prevents agents from treating proposals, plans, or generated summaries as normative law.
- What this bundle intentionally excludes: Does not authorize archive, wrappers, or proposal-only material as default sources.

## Read First
- `docs/meta/docs-program/WAVE4_CLOSEOUT.md` [canonical] Canonical entrypoint for domain `architecture`.
- `docs/adr` [canonical] Canonical entrypoint for domain `architecture`.
- `generated/knowledge/review-bundle.md` [generated] Canonical entrypoint for domain `architecture`.
- `generated/knowledge/truth-impact-report.json` [generated] Canonical entrypoint for domain `architecture`.
- `specs/standards/SPEC_SYSTEM_CHARTER.md` [canonical] Canonical entrypoint for domain `specs-control-plane`.
- `specs/standards/SPEC_METADATA_MODEL.md` [canonical] Canonical entrypoint for domain `specs-control-plane`.
- `specs/standards/SPEC_AUTHORING_STANDARD.md` [canonical] Canonical entrypoint for domain `specs-control-plane`.
- `tools/specs/verify_spec_frontmatter.py` [canonical] Canonical entrypoint for domain `specs-control-plane`.
- `tools/specs/verify_spec_taxonomy.py` [canonical] Canonical entrypoint for domain `specs-control-plane`.

## Surface Meaning
- Normative: none
- Proposal: none
- Plan: none
- Generated: generated/knowledge/agent-entrypoints.json, generated/knowledge/change-manifest.json, generated/knowledge/review-bundle.md, generated/knowledge/truth-impact-report.json
- Historical context only: compatibility wrappers as primary input, docs/archive/**, specs/archive/**

## Reviewers And Evidence
- Reviewers: architecture, docs
- Evidence: review_bundle, truth_impact_report

## Validation Commands
- `python3 tools/specs/verify_spec_frontmatter.py --repo-root .`
- `python3 tools/specs/verify_spec_taxonomy.py --repo-root .`
- `python3 tools/specs/verify_spec_paths.py --repo-root .`
- `python3 scripts/qa/spec-tools/build_spec_catalog.py --check --repo-root .`

## Cross-Repo Fallout
- Overall verdict: `infra_counterpart_required`
- Repositories: bbi-infrastructure
- Reviewers: architecture, platform, release, security, tenancy_auth
