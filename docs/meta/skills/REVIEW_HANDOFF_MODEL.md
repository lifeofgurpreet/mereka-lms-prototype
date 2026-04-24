# Wave 7 Review Handoff Model

## Reviewer entry path

1. Run `bash scripts/qa/run-task-runtime-gates.sh`
2. Open `generated/knowledge/task-context-report.json`
3. Open `generated/knowledge/skill-index.json`
4. Open the bundle for the primary task type in `generated/knowledge/task-bundles/`
5. If the bundle shows cross-repo dependencies, also open:
   - `generated/contracts/cross-repo-manifest.json`
   - `generated/contracts/deployment-impact-report.json`
   - `generated/contracts/release-obligations.md`
6. Finish with:
   - `generated/knowledge/review-bundle.md`
   - `generated/knowledge/truth-impact-report.json`

## Agent handoff path

1. Resolve task context with `tools/knowledge/resolve_task_context.py`
2. Read the matching generated task bundle first
3. Follow the bundle's authority order
4. Refresh the listed generated surfaces
5. Run the listed commands before handoff
6. Escalate if any escalation condition is true

## Authority rule

Task bundles do not override canonical truth.

The bundle authority order is:

1. explicit Wave 4/5/6 resolver and contract docs
2. canonical specs / contracts / runbooks / architecture docs for the affected task type
3. generated runtime outputs derived from those surfaces
4. status/evidence surfaces
5. archive only when explicitly named as historical context

## Escalate instead of guessing when

- one diff spans multiple high-risk task types
- a bundle indicates `manual_review_required` or `unknown_mapping`
- required reviewers are cross-disciplinary and the change is deployment-affecting
- evidence obligations imply release or security review but the task scope looks repo-local
- the resolver reports `confidence: low`
