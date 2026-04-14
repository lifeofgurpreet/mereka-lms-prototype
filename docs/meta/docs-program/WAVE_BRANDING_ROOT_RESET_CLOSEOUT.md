# Wave Branding Root Reset Closeout

_Audience: Reviewers and maintainers • Owner: Platform Team • Last verified: 2026-04-14 • Status: historical closeout snapshot_

> Historical closeout for a completed root-retirement wave.
>
> This file records the retirement of `docs/branding/**`. It does not define
> the current branding front door.

For current docs-program execution, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

## Historical Wave End State

`docs/branding/**` is retired as an active documentation root.

Final shape:

```text
docs/branding/
  README.md
```

The canonical living branding root is now `docs/guides/branding/**`.

## What changed

- Rewrote active repo references from `docs/branding/**` to `docs/guides/branding/**`.
- Corrected one dead branding-plan link to the actual canonical operating model.
- Deleted duplicate files under `docs/branding/**`, including the stale audit copy.
- Kept `docs/branding/README.md` only as a tombstone redirect.
- Refreshed generated catalog surfaces impacted by the collapse.

## Current Canonical Model

- Branding guidance: `docs/guides/branding/**`
- Branding-related specs: `specs/**`
- Docs-program governance: `docs/meta/docs-program/**`

## Historical Guardrail

`tools/docs/verify/verify_legacy_branding_root.py` prevents regrowth by failing when:

- any file other than `docs/branding/README.md` exists under `docs/branding/**`
- active documentation, infra, or workflow surfaces still rely on `docs/branding/**` as a living root

This guard is enforced through `tools/docs/verify/verify-docs-policy.sh`.

## Validation

```bash
python3 tools/docs/verify/verify_legacy_branding_root.py --repo-root .
python3 tools/docs/verify/build-doc-catalog.py --root .
bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD
```

## Remaining risk

Historical ledgers and evidence docs still mention `docs/branding/**` as part of prior topology history.
That is acceptable as historical context, but they must not be used as living guidance.
