# ADR Review

## Scope

This runbook defines review gates for ADR-bearing pull requests.

## Review checklist

1. Confirm ADR IDs, titles, and paths are consistent between file and manifest.
2. Validate governance boundaries:
   - `governs` is explicit and non-ambiguous.
   - `does_not_govern` prevents accidental policy overreach.
3. Validate relationship integrity:
   - `depends_on`, `read_next`, `supersedes`, `amends` targets exist.
4. Validate verification quality:
   - `fitness_functions` are executable commands or checks.
   - failure modes are concrete and testable.
5. Validate exception discipline:
   - exception ADRs include enforced expiry/removal fields.
6. Validate Open edX/Tutor references:
   - official-source allowlist only.
7. Validate artifact classification:
   - `docs/concepts/architecture/**` for living policy
   - ADR for accepted decision history
   - `docs/adr/rfc/**` for undecided design
   - `docs/ops/runbooks/**` or `docs/guides/**` for procedures
   - `docs/evidence/**` for active proof
8. Validate vocabulary discipline:
   - `governs` and `does_not_govern` use controlled tokens from `docs/architecture/glossary.yaml`.

## Required commands

```bash
make adr-governance
make adr-impact RANGE=<BASE_SHA>...<HEAD_SHA>
```

## PR output requirements

- Include impacted ADR list from resolver output.
- Include reading order for reviewers/agents (foundation first, then domain bundle).
- Include the architecture artifact type touched when governed paths changed.
- Block merge if ADR suite fails or impact output is missing for governed-path changes.
