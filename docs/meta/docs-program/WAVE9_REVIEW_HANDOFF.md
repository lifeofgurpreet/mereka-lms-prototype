# Wave 9 Review Handoff
_Audience: Reviewers and coding agents • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

## Purpose

This is the review-safe entrypoint for Wave 9.

Use it when you need to answer:

- what changed
- what is authoritative
- what commands prove the branch is clean
- what remaining ambiguity is intentional rather than accidental

## Read this first

1. `docs/meta/docs-program/WAVE9_FINDINGS_LEDGER.md`
2. `docs/meta/docs-program/WAVE9_CLOSEOUT.md`
3. `docs/README.md`
4. `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`

## If the review touches release or cross-repo fallout

Read next:

1. `docs/reference/operations/RELEASE_PROCESS.md`
2. `docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md`
3. `docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md`
4. `scripts/governance/canonical-entrypoints.yaml`
5. `deploy/k8s/contract.json`
6. `config/lane-identity.yaml`

## If the review touches spec truth

Read next:

1. `specs/_generated/indexes/spec-read-first.md`
2. `specs/catalog.json`
3. `specs/_generated/graph.json`
4. the affected canonical spec under `specs/**`

## Validation commands

Run from repo root:

```bash
python3 tools/docs/verify/build-doc-catalog.py --check --root .
python3 tools/knowledge/build_wave9_findings_ledger.py --check --repo-root .
python3 tools/docs/verify/verify_temporal_integrity.py
python3 tools/docs/verify/verify_generated_navigation.py
bash scripts/qa/verify-release-automation.sh
bash scripts/qa/verify-release-workflow-invocation.sh
python3 tools/knowledge/verify_review_runtime.py --repo-root . --range origin/main...HEAD
bash scripts/qa/run-review-runtime-gates.sh
python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD
python3 scripts/qa/spec-tools/build_spec_catalog.py --check --repo-root .
python3 tools/specs/build_spec_graph.py --check
python3 tools/specs/build_spec_bundles.py --check
```

## What still requires human judgment

- whether the remaining mirror-catalog risk should be accepted long term or removed in a later wave
- whether a deployment-affecting change has sufficient release evidence beyond repo-local proof
- mixed diffs that touch both policy and runtime surfaces in one PR

## What is intentionally out of scope

- live runtime reconciliation
- cluster-state truth
- full branch-local knowledge/runtime plane merger
- removal of the docs catalog mirror

## Review standard

Do not approve based on freshness alone.

Approve only if:

- the findings ledger has no open findings
- generated navigation resolves correctly
- temporal integrity is clean
- release/runtime semantics pass the review-runtime gate
- spec parity surfaces are present and deterministic
