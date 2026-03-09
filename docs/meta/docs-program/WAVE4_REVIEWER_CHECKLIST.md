# Wave 4 Reviewer Checklist

Use this checklist for any PR that changes docs/specs knowledge surfaces.

## Control-plane checks

- `docs/` and `specs/` still remain separate filesystem roots.
- The change does not introduce split truth between a canonical file and a compatibility wrapper.
- Generated knowledge surfaces were refreshed through their generators, not hand-edited.

## Required gate

- Run `bash scripts/qa/run-knowledge-integrity-gates.sh`

## Review questions

- Is the changed file in the correct lane?
- If a wrapper exists, is its canonical target explicit and still justified?
- If a new generated surface exists, is there a `--check` path for drift detection?
- If metadata changed, do the shared catalog and graph still classify it correctly?
- If the change affects docs-program control surfaces, does the tracker still match the actual branch state?
