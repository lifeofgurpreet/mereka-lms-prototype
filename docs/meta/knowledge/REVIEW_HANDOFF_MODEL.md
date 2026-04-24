# Wave 5 Review Handoff Model

## Start here

- `docs/meta/knowledge/CHANGE_RUNTIME_CLOSEOUT.md`
- `docs/meta/knowledge/WAVE5_EXECUTION_TRACKER.md`
- `docs/meta/knowledge/OWNERSHIP_MAP.yaml`
- `docs/meta/knowledge/CHANGE_CLASSES.yaml`
- `docs/meta/knowledge/EVIDENCE_OBLIGATIONS.yaml`
- `docs/meta/knowledge/REVIEW_RULES.yaml`

## Machine-readable runtime surfaces

- `generated/knowledge/change-manifest.json`
- `generated/knowledge/review-bundle.md`
- `generated/knowledge/truth-impact-report.json`
- `generated/knowledge/wrapper-retirement-report.json`

## Gate entrypoints

- `scripts/qa/run-knowledge-runtime-gates.sh`
- `tools/knowledge/verify_knowledge_runtime.py`
- `.github/workflows/docs-policy.yml`

## Reviewer operating model

1. Read `generated/knowledge/review-bundle.md` first.
2. Confirm the required reviewer set matches the touched truth lanes.
3. Confirm the truth impact report matches expected ADR, runbook, plan, wrapper, and generated-surface fallout.
4. Confirm the wrapper retirement report does not hide stale wrappers as normative truth.
5. Use the runtime gate, not ad hoc spot checks, as the merge-time proof surface.

## Escalation rules

- A `normative_contract_change` without the expected reviewers is a merge blocker.
- A drifted generated runtime artifact is a merge blocker.
- A wrapper marked `suspicious` is not an automatic blocker, but it must not be silently ignored in review.
- Wave 4 topology remains locked: `docs/` and `specs/` stay physically separate.
