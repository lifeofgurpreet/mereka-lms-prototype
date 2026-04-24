# Documentation Contributing Guide
_Audience: Contributors • Owner: Platform Team • Last verified: 2026-03-08 • Status: canonical_

## Scope
This guide covers contribution rules for files under `docs/**`.

## Start here
If you are not sure where a document belongs, stop and route it before writing.

The most common docs mistake in this repo is not bad prose. It is putting correct content in the wrong root, which creates split-brain again.

Use this guide in this order:
1. Pick the correct root.
2. Add or preserve required metadata.
3. Update navigation if discoverability changed.
4. Run the local checks that match your diff.

## Before you write
1. Place new docs in winning roots, not just any folder that already exists.
2. Keep the `docs/` root to the allowlist only:
- `README.md`
- `CONTRIBUTING.md`
- `DOCS_REMEDIATION_PLAN_AND_TRACKER.md`
- `catalog.json` (generated derived mirror)
3. Treat in-document metadata as the source of truth.
4. Do not hand-edit generated artifacts.
5. Do not hard-delete historical, archived, or evidence docs during remediation work.

## Canonical File Placement
- Living architecture and standards: `docs/concepts/architecture/**`
- Human workflows and onboarding: `docs/guides/**`
- Operational procedures and quick references: `docs/ops/**`
- Supporting reference and policy: `docs/reference/**`, `docs/policies/**`
- Active evidence: `docs/evidence/**`
- Active status and reporting: `docs/status/**`
- Decision history and exceptions: `docs/adr/**`
- Historical artifacts and superseded docs: `docs/archive/**`

## Required metadata
Canonical and supporting docs must carry:
- `Audience`
- `Owner`
- `Last verified`
- `Status`

### Transitional Path Policy
- `docs/operations/README.md`, `docs/runbooks/README.md`, `docs/onboarding/README.md`, and `docs/architecture/README.md` are retired compatibility tombstones.
- Do not create new canonical docs under transitional paths.
- If you must touch a transitional file, preserve pointer semantics and prefer updating the canonical target instead.
- Transitional files should collapse to stub-only replacements with `Status: superseded` and `superseded_by`.

## Specs / docs contract

- `specs/**` is the normative intended-behavior system.
- `docs/**` is explanation, operation, decision history, evidence, and status.
- Generated testmaps are not a second manual truth plane.
- `docs/catalog.json` must be generated from `generated/catalogs/docs-catalog.json` or mechanically checked against document metadata.
- Regenerate it with `python3 tools/docs/verify/build-doc-catalog.py`.
- If a winning-root doc changes under `docs/ops/**`, `docs/guides/**`, `docs/reference/**`, `docs/policies/**`, `docs/evidence/**`, `docs/status/**`, `docs/concepts/architecture/**`, or `docs/adr/**`, the same diff MUST also update `generated/catalogs/docs-catalog.json`.
- See [DOCS_SPECS_CONTRACT.md](guides/standards/DOCS_SPECS_CONTRACT.md).

## Naming
- Prefer kebab-case for new canonical docs.
- Keep names stable and semantic.
- Avoid `SCREAMING_SNAKE_CASE` for new docs unless external contracts require it.

## Definition of complete
Your docs change is not complete just because the file reads well.

A docs change is complete when:
1. the content lives under the correct root,
2. metadata is present and current,
3. moved or superseded docs point to the replacement,
4. changed Markdown links resolve,
5. discoverability is updated when readers would otherwise miss the document,
6. the catalog and policy checks still pass.

If a reader would need tribal knowledge to find the document after your change, the change is incomplete.

## What gets rejected
- New canonical docs under transitional roots.
- Canonical docs that route readers into transitional roots without an explicit legacy reason.
- Generated artifact edits without regenerating the source output.
- Moves that leave broken links, orphaned navigation, or missing supersession pointers.
- Docs that try to define normative product behavior that belongs in `specs/**`.

## Minimal local checks
Run these for docs control-plane changes:

```bash
bash tools/docs/verify/verify-docs-policy.sh --range HEAD~1...HEAD
python3 tools/docs/verify/verify-doc-catalog-governance.py --range HEAD~1...HEAD
python3 tools/docs/verify/verify-doc-catalog-health.py --max-stale-days 45
python3 tools/docs/verify/scan-doc-catalog-residue.py --fail-on-residue
python3 tools/docs/verify/build-doc-catalog.py
```

## Governance
- Canonical policy and tracker: `docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md`
- Authority resolver: `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`
- Architecture charter: `docs/concepts/architecture/ARCHITECTURE_CHARTER.md`
- Governance approval packet (`GOV-01`): `docs/archive/reports/governance-approval-note-20260306.md`
- Escalation routing appendix (`GOV-02`): `docs/archive/reports/escalation-appendix-20260306.md`
- Canonical sign-off matrix: `docs/archive/reports/canonical-authority-approval-matrix-20260306.md`
- Closure readiness checklist (`CLS-02`): `docs/archive/reports/program-closure-readiness-20260306.md`
- Transitional tree deprecation timeline: `docs/archive/reports/transitional-path-deprecation-timeline-20260306.md`
- Global contribution workflow: `../CONTRIBUTING.md`
