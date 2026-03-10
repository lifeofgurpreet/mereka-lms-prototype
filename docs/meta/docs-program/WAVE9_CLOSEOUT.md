# Wave 9 Closeout
_Audience: Reviewers, contributors, and agents • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

## What Wave 9 added

Wave 9 took the repo from structurally improved to decision-grade truthful on the active hot path.

It added:

- a current-head findings ledger for both audits
- temporal integrity enforcement for proof-like artifacts
- semantic navigation validation for generated ADR surfaces
- deterministic spec parity surfaces:
  - `specs/catalog.json`
  - `specs/_generated/graph.json`
  - `specs/_generated/indexes/spec-read-first.md`
- cross-repo/front-door cleanup so active docs now point to canonical release, standing-order, and security surfaces
- a review/runtime semantic gate that checks:
  - open high-risk findings
  - blocking partial findings
  - docs catalog mirror drift
  - event-aware diff range handling for docs-policy CI

## What Wave 9 intentionally did not change

- no docs/specs topology redesign
- no ADR reclassification sweep
- no new truth plane
- no large branch-local knowledge/runtime merger
- no live runtime reconciliation

## Canonical read-first path

For humans and agents, use this order:

1. `docs/README.md`
2. `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`
3. `docs/reference/operations/RELEASE_PROCESS.md`
4. `docs/meta/standing-orders/README.md`
5. `specs/_generated/indexes/spec-read-first.md`
6. `docs/meta/docs-program/WAVE9_FINDINGS_LEDGER.md`

If the task has deployment or promotion fallout, add:

7. `docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md`
8. `docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md`

## Cross-repo review handoff path

Use this order for release/runtime/cross-repo review:

1. `docs/reference/operations/RELEASE_PROCESS.md`
2. `docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md`
3. `docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md`
4. `scripts/governance/canonical-entrypoints.yaml`
5. `deploy/k8s/contract.json`
6. `config/lane-identity.yaml`

## Agent-facing “what changed and what to read first”

Agents should start from:

- `docs/meta/docs-program/WAVE9_FINDINGS_LEDGER.md`
- `docs/README.md`
- `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`
- `specs/_generated/indexes/spec-read-first.md`

Then branch by task type:

- spec truth: `specs/**` plus `specs/catalog.json`
- operator/release truth: `docs/reference/operations/RELEASE_PROCESS.md`
- proof/evidence truth: `docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md`
- current docs debt or exceptions: `docs/meta/docs-program/WAVE9_FINDINGS_LEDGER.md`

## Intentionally retained holdouts

These remain by design after Wave 9:

- `docs/catalog.json` remains as a mirror of `generated/catalogs/docs-catalog.json`
  - This is still tracked as `RTA-05` and remains the only `PARTIAL` finding.
- overlay-level rather than exact-file cross-repo mappings remain where repo truth does not prove more.
- release sufficiency is still contract/evidence driven, not live-runtime verified.

## Current end-state

- open findings: `0`
- partial findings: `1`
- fixed findings: `6`
- invalidated-by-current-repo-truth findings: `3`

Wave 9 is complete when the repo can no longer sound authoritative while being wrong on the active review and agent hot path.
