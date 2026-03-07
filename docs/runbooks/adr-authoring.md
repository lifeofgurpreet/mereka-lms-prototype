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

## Required commands

```bash
make adr-governance
```

## Exit criteria

- ADR suite passes.
- Impacted ADR output is attached in PR context.
- No placeholder text remains in generated bundle outputs.
