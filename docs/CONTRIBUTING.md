# Documentation Contributing Guide
_Audience: Contributors • Owner: Platform Team • Last verified: 2026-03-08 • Status: canonical_

## Scope
This guide covers contribution rules for files under `docs/**`.

## Required Rules
1. Place new docs in winning roots, not just any existing folder.
2. Keep `docs/` root to the allowlist only:
- `README.md`
- `CONTRIBUTING.md`
- `DOCS_REMEDIATION_PLAN_AND_TRACKER.md`
- `catalog.json` (optional)
3. Use metadata on canonical/supporting docs:
- `Audience`
- `Owner`
- `Last verified`
- `Status`
4. In-document metadata is the source of truth. Generated files must derive from it.
5. If superseding a doc, add the replacement pointer in the first 10 lines.
6. If moving files, update internal links in the same change set.
7. Do not hard delete historical or evidence docs during remediation phases.

## Canonical File Placement
- Living architecture and standards: `docs/concepts/architecture/**`
- Human workflows and onboarding: `docs/guides/**`
- Operational procedures and quick references: `docs/ops/**`
- Supporting reference and policy: `docs/reference/**`, `docs/policies/**`
- Active evidence: `docs/evidence/**`
- Active status and reporting: `docs/status/**`
- Decision history and exceptions: `docs/adr/**`
- Historical artifacts and superseded docs: `docs/archive/**`

### Transitional Path Policy
- `docs/operations/**`, `docs/onboarding/**`, `docs/runbooks/**`, `docs/branding/**`, and `docs/architecture/**` are transitional compatibility paths.
- Do not create new canonical docs under transitional paths.
- If you must touch a transitional file, preserve pointer semantics and prefer updating the canonical target instead.
- Transitional files should collapse to stub-only replacements with `Status: superseded` and `superseded_by`.

## Specs / Docs Contract

- `specs/**` is the normative intended-behavior system.
- `docs/**` is explanation, operation, decision history, evidence, and status.
- Generated testmaps are not a second manual truth plane.
- `docs/catalog.json` must be generated or mechanically checked against document metadata.
- See [DOCS_SPECS_CONTRACT.md](guides/standards/DOCS_SPECS_CONTRACT.md).

## Naming
- Prefer kebab-case for new canonical docs.
- Keep names stable and semantic.
- Avoid `SCREAMING_SNAKE_CASE` for new docs unless external contracts require it.

## Validation Before Commit
1. Verify changed markdown links resolve.
2. Confirm metadata exists for touched canonical/supporting docs.
3. Confirm superseded stubs include replacement link.
4. Confirm canonical docs do not route readers into transitional roots unless explicitly marked legacy.
5. Update `docs/README.md` when discoverability changes.

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
