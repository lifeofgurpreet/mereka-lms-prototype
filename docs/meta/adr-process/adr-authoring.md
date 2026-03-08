# ADR Authoring

## Scope

This runbook defines the mandatory authoring flow for ADR updates under `docs/adr/`.

## Authoring flow

1. Select the correct template from `docs/adr/templates/`.
2. Add complete frontmatter required by `scripts/qa/verify_adr_frontmatter.py`.
3. Write normative content using `MUST`, `MUST NOT`, `SHOULD`, `SHOULD NOT`, `MAY`.
4. Include all required sections:
   - Decision
   - Scope
   - Non-goals
   - Context
   - Decision details
   - Invariants
   - Verification
   - Failure modes
   - Consequences
   - Alternatives considered
5. Link the ADR into `docs/adr/manifest.yaml` with accurate relationship keys:
   - `depends_on`
   - `read_next`
   - `supersedes`
   - `amends`
6. For exception ADRs, include non-null:
   - `expiry_date`
   - `removal_condition`
7. For Open edX/Tutor guidance, use official-source allowlist only in `related_tutor_docs`:
   - `https://docs.openedx.org`
   - `https://docs.tutor.edly.io`

## When not to write an ADR

- Use `docs/concepts/architecture/` when the content is living policy that will be reviewed over time.
- Use `docs/adr/rfc/` when the decision is still open.
- Use `docs/ops/runbooks/` for operator procedures and `docs/guides/` for contributor-facing workflows.
- Use `docs/evidence/` for active proof, logs, screenshots, or verification bundles.

## Controlled vocabulary

- `governs` and `does_not_govern` for governed ADRs must use controlled tokens from `docs/architecture/glossary.yaml`.
- Do not introduce ad hoc free-form scope labels.
- Do not leave governed ADRs with placeholder titles (`---`) or empty `governs`.

## Required commands

```bash
make adr-governance
make adr-impact RANGE=HEAD~1...HEAD
```

## Exit criteria

- ADR suite passes.
- Impacted ADR output is attached in PR context.
- No placeholder text remains in generated bundle outputs.
