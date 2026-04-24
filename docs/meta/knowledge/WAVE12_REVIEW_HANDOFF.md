# Wave 12 Review Handoff

## Review Order
1. [DECISION_RUNTIME_MODEL.md](/home/gurpreet/projects/k8s/mereka-lms-wt-wave12-review-release-decision-runtime/docs/meta/knowledge/DECISION_RUNTIME_MODEL.md)
2. [review-decision.json](/home/gurpreet/projects/k8s/mereka-lms-wt-wave12-review-release-decision-runtime/generated/knowledge/review-decision.json)
3. [reviewer-obligations.json](/home/gurpreet/projects/k8s/mereka-lms-wt-wave12-review-release-decision-runtime/generated/knowledge/reviewer-obligations.json)
4. [evidence-obligations.json](/home/gurpreet/projects/k8s/mereka-lms-wt-wave12-review-release-decision-runtime/generated/knowledge/evidence-obligations.json)
5. [read-first-packs.json](/home/gurpreet/projects/k8s/mereka-lms-wt-wave12-review-release-decision-runtime/generated/knowledge/read-first-packs.json)
6. [release-readiness.json](/home/gurpreet/projects/k8s/mereka-lms-wt-wave12-review-release-decision-runtime/generated/knowledge/release-readiness.json)
7. [runtime-evaluation.json](/home/gurpreet/projects/k8s/mereka-lms-wt-wave12-review-release-decision-runtime/generated/knowledge/runtime-evaluation.json)
8. [WAVE12_CLOSEOUT.md](/home/gurpreet/projects/k8s/mereka-lms-wt-wave12-review-release-decision-runtime/docs/meta/knowledge/WAVE12_CLOSEOUT.md)

## Exact Validation Order
1. `bash scripts/qa/run-agent-pack-runtime-gates.sh`
2. `python3 tools/knowledge/build_review_decision.py --check --repo-root . --range origin/main...HEAD`
3. `python3 tools/knowledge/build_reviewer_obligations.py --check --repo-root .`
4. `python3 tools/knowledge/build_evidence_obligations.py --check --repo-root .`
5. `python3 tools/knowledge/build_read_first_packs.py --check --repo-root .`
6. `python3 tools/knowledge/build_release_readiness.py --check --repo-root .`
7. `python3 tools/knowledge/build_runtime_evaluation.py --check --repo-root .`
8. `python3 tools/knowledge/verify_decision_runtime.py --repo-root . --range origin/main...HEAD`
9. `bash scripts/qa/run-decision-runtime-gates.sh`
10. `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`

## Reviewer Guidance
- Treat JSON outputs as canonical.
- Treat Markdown projections as convenience surfaces only.
- If `review-decision.json` and `release-readiness.json` disagree semantically, block the change and inspect the canonical inputs named inside each output.
- If `runtime-evaluation.json` shows fixture failures, do not accept the runtime as trustworthy.
- If release readiness is `advisory` or `break-glass-only`, treat missing live approval state as unresolved input, not as implicit approval.

## Remaining Manual Judgment
- live reviewer approvals
- live cluster/runtime convergence
- runtime convergence warnings that are intentionally surfaced but not auto-cleared
- any cross-repo fact not proven from the current local repos
