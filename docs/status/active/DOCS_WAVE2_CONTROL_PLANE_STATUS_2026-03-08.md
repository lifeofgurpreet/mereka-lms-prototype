# Docs Wave 2 Control Plane Status
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-08 • Status: supporting_

## Summary

Wave 2 control-plane hardening is materially complete.

The repo now has:

- one declared winner per artifact kind
- blocking guards on transitional-root regression
- blocking guards on archive writes
- blocking guards on winning-root catalog residue
- blocking guards on winning-root doc changes that skip source-catalog updates

## Current enforced winners

- living architecture: `docs/concepts/architecture/**`
- operator docs: `docs/ops/**`
- evidence: `docs/evidence/**`
- active reporting: `docs/status/**`
- decision ledger: `docs/adr/**`
- specs: `specs/**`

## Current blocking gates

- `tools/docs/verify/verify-docs-policy.sh`
- `tools/docs/verify/verify-stub-only-transitional-dirs.py`
- `tools/docs/verify/verify-archive-write-protection.py`
- `tools/docs/verify/verify-evidence-status-root-policy.py`
- `tools/docs/verify/verify-doc-catalog-governance.py`
- `tools/docs/verify/scan-doc-catalog-residue.py --fail-on-residue`
- `tools/docs/verify/verify-doc-catalog-health.py`

## Remaining non-closed work

1. `generated/catalogs/docs-catalog.json` is enforced and fresh, but it is still maintained more manually than ideally desired.
2. Transitional compatibility roots still exist by design and can be removed only in a later cleanup wave after link retirement risk is low.
3. Archive ownership is protected by override today; stricter ownership routing may still be added later if review friction justifies it.

## Review guidance

Treat this wave as complete when evaluating control-plane integrity.

Treat future work as follow-up hardening or cleanup, not foundational resolver work.
