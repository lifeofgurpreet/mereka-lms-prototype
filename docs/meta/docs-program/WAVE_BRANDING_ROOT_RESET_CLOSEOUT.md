# Wave Branding Root Reset Closeout

## End state

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

## Canonical ownership now

- Branding guidance: `docs/guides/branding/**`
- Branding-related specs: `specs/**`
- Docs-program governance: `docs/meta/docs-program/**`

## Guardrail

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
