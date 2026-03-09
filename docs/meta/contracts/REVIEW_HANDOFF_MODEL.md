# Wave 6 Review Handoff Model

## Start here

- `docs/meta/contracts/CHANGE_RUNTIME_CLOSEOUT.md`
- `docs/meta/contracts/WAVE6_EXECUTION_TRACKER.md`
- `docs/meta/contracts/CONTRACT_RUNTIME_MODEL.md`
- `docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml`
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml`
- `docs/meta/contracts/ENVIRONMENT_SURFACES.yaml`

## Machine-readable runtime surfaces

- `generated/contracts/cross-repo-manifest.json`
- `generated/contracts/deployment-impact-report.json`
- `generated/contracts/release-obligations.md`

## Gate entrypoints

- `scripts/qa/run-cross-repo-contract-gates.sh`
- `tools/contracts/verify_cross_repo_contracts.py`
- `.github/workflows/docs-policy.yml`

## Reviewer operating model

1. Read `generated/contracts/release-obligations.md` first.
2. Check `generated/contracts/cross-repo-manifest.json` to see which services were touched and how they were classified.
3. Check `generated/contracts/deployment-impact-report.json` to see whether an infra counterpart is required, manual review is required, or the change is app-only.
4. Confirm there is a `bbi-infrastructure` counterpart PR or explicit rationale for every `infra_counterpart_required` service.
5. Treat every `manual_review_required` service as unresolved until the missing GitOps path knowledge is explicitly addressed in review.

## Escalation rules

- A high-risk service with `unknown_mapping` is a merge blocker.
- Drifted generated contract outputs are a merge blocker.
- A deployment-affecting contract change without the expected reviewer groups is a merge blocker.
- Wave 6 remains repo-contract-only. Review must not invent live-cluster proof requirements that the wave did not promise.

## Locked model assumptions

- `docs/` and `specs/` stay physically separate.
- Wave 5 remains the repo-native review intelligence layer underneath Wave 6.
- Wave 6 answers what must change together across repos; it does not reconcile what is currently live.
