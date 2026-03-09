# Program Update — Read Before Execution
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

Use the current ADR corpus in `docs/adr/` as the authoritative starting state.

Execution rules for v2:
1. Wave 1 is an in-place governance overlay, not a physical ADR move.
2. ADR-027 remains Deployment Contract; constitutional ADR sequence starts at ADR-028.
3. First deliverable is contradiction/status/classification coverage for all ADRs.
4. Preserve repo taxonomy (`docs/adr`, `docs/ops`, `docs/concepts`, `docs/archive`).
5. Generate indexes/maps from metadata; do not hand-maintain them as source of truth.
6. For Open edX/Tutor process guidance, use official sources first:
   - `https://docs.openedx.org`
   - `https://docs.tutor.edly.io`
7. Exception/workaround ADRs are invalid without expiry and removal conditions.
8. Do not delete overloaded content without extracting to `evidence/` or `docs/runbooks/`.

Immediate priorities:
- Install ADR manifest/frontmatter/graph tooling.
- Author ADR-028 through ADR-033.
- Resolve contradictions across ADR-003, ADR-017, ADR-019, ADR-021, ADR-024, and ADR README behavior.
- Convert ADR-013 and ADR-022 into time-bounded exception lifecycle.
- Deepen ADR-018 into a decision-grade commerce ADR.
