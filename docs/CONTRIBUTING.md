# Documentation Contributing Guide
_Audience: Contributors • Owner: Platform Team • Last verified: 2026-03-06 • Status: canonical_

## Scope
This guide covers contribution rules for files under `docs/**`.

## Required Rules
1. Place new docs in domain folders (`docs/concepts`, `docs/guides`, `docs/ops`, `docs/archive`, `docs/qa`), not `docs/` root.
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
4. If superseding a doc, add the replacement pointer in the first 10 lines.
5. If moving files, update internal links in the same change set.
6. Do not hard delete historical/evidence docs during remediation phases.

## File Placement
- Architecture and references: `docs/concepts/**`
- Human workflows and onboarding: `docs/guides/**`
- Operational procedures and runbooks: `docs/ops/**`
- Historical artifacts and superseded docs: `docs/archive/**`
- QA reports and validation outputs: `docs/qa/**`

### Transitional Path Policy
- `docs/operations/**`, `docs/onboarding/**`, and `docs/runbooks/**` are transitional compatibility paths.
- Do not create new canonical docs under transitional paths.
- If you must touch a transitional file, preserve pointer semantics and prefer updating the canonical target in `docs/ops/**` or `docs/guides/**`.

## Naming
- Prefer kebab-case for new canonical docs.
- Keep names stable and semantic.
- Avoid `SCREAMING_SNAKE_CASE` for new docs unless external contracts require it.

## Validation Before Commit
1. Verify changed markdown links resolve.
2. Confirm metadata exists for touched canonical/supporting docs.
3. Confirm superseded stubs include replacement link.
4. Update `docs/README.md` when discoverability changes.

## Governance
- Canonical policy and tracker: `docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md`
- Governance approval packet (`GOV-01`): `docs/archive/reports/governance-approval-note-20260306.md`
- Escalation routing appendix (`GOV-02`): `docs/archive/reports/escalation-appendix-20260306.md`
- Canonical sign-off matrix: `docs/archive/reports/canonical-authority-approval-matrix-20260306.md`
- Closure readiness checklist (`CLS-02`): `docs/archive/reports/program-closure-readiness-20260306.md`
- Transitional tree deprecation timeline: `docs/archive/reports/transitional-path-deprecation-timeline-20260306.md`
- Global contribution workflow: `../CONTRIBUTING.md`
