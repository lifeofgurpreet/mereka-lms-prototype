# Docs Root Authority Contract
_Audience: Contributors and reviewers • Owner: Platform Team • Last updated: 2026-03-11 • Status: canonical_

This contract makes docs-root ownership explicit so retired roots stop acting like shadow authority.

## Canonical Roots

Use these roots for living content:

| Content type | Canonical root |
| --- | --- |
| living architecture narrative and standards | `docs/concepts/architecture/**` |
| operator procedures and runbooks | `docs/ops/**` |
| stable lookup and architecture/operations reference | `docs/reference/**` |
| policies and control contracts | `docs/policies/**` |
| docs-program internals and migration ledgers | `docs/meta/**` |
| stabilization plans, debt ledgers, and bounded remediation trackers | `docs/stabilization/**` |
| review and handoff packets | `docs/reviews/**` |
| proof and evidence | `docs/evidence/**` |
| status and readiness reporting | `docs/status/**` |

## Retired Roots

These roots are retired and must not carry new living content:

| Retired root | Allowed content |
| --- | --- |
| `docs/architecture/**` | `docs/architecture/README.md` tombstone only |
| `docs/operations/**` | `docs/operations/README.md` tombstone only |

The retired roots may be named in governance artifacts when the point of the document is retirement itself, but they must not regain substantive living documents.

## Safe Migration Sequence

When moving a file out of a retired root:

1. classify the retired-root file in `docs/stabilization/RETIRED_ROOT_REMEDIATION_LEDGER.md`
2. choose the canonical destination by artifact type, not by historical path
3. move or collapse the content into the canonical root
4. update inbound references from active docs
5. leave only an allowed tombstone or remove the retired-root file entirely
6. run `scripts/qa/verify-retired-root-remediation.sh`

If the destination is ambiguous, stop at classification and defer it instead of guessing.

## How The Verifier Treats Retired Roots

`scripts/qa/verify-retired-root-remediation.sh` treats retired roots as follows:

- fails on substantive files still living under `docs/architecture/**` or `docs/operations/**`
- allows only the root README tombstones
- fails when active docs still point to retired-root substantive targets
- allows governance-only references that explain the retirement contract itself

The underlying legacy-root verifiers remain the enforcement mechanism for root emptiness and live-reference cleanup.

## Migration Rules

- do not create per-file tombstones under retired roots unless the verifier contract is intentionally updated
- prefer deletion of the retired-root file once the canonical destination exists and references are repaired
- collapse duplicates instead of preserving two active copies
- route runbooks to `docs/ops/runbooks/**`, not to the retired `docs/runbooks/**` compatibility root
- route stabilization debt and audit material to `docs/stabilization/**`

## Governing Artifacts

This contract is enforced alongside:

- `docs/stabilization/RETIRED_ROOT_REMEDIATION_LEDGER.md`
- `docs/stabilization/retired-root-remediation-ledger.v1.yaml`
- `scripts/qa/verify-retired-root-remediation.sh`
- `var/proofs/retired-root-remediation.md`
