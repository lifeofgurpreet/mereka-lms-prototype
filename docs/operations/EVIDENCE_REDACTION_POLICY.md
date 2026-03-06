# Evidence Redaction Policy
_Audience: Contributors + Reviewers • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## Scope

Applies to committed evidence under:

Canonical:
- `docs/archive/evidence/operations/**`
- `docs/archive/evidence/observability/**`

Transitional compatibility:
- `docs/operations/evidence/**`
- `docs/evidence/observability/**`

Raw operational outputs belong in `var/**` (gitignored) and workflow artifacts.

## Required Redaction Rules

Before committing evidence markdown/text/log files:

1. `set-cookie` headers MUST be fully redacted:
   - `set-cookie: <REDACTED>`
2. Raw token/cookie values MUST NOT appear:
   - `sessionid=`
   - `csrftoken=`
   - `authorization: bearer ...`
   - `x-api-key: ...`
3. JWT-like payloads MUST be redacted.

## Allowed Example

```text
set-cookie: <REDACTED>
authorization: <REDACTED>
```

## Disallowed Example

```text
set-cookie: sessionid=abc123...; Path=/
authorization: bearer eyJ...
```

## Enforcement

- Local: `.githooks/pre-commit` calls `scripts/qa/verify-evidence-redaction.sh --staged-only`
- CI: `.github/workflows/ci.yml` runs `STRICT=1 ./scripts/qa/verify-evidence-redaction.sh`
- CI growth budget: `./scripts/qa/verify-evidence-sprawl-budget.sh` enforces tracked evidence file/size budgets from `docs/operations/verification/evidence_sprawl_budget.json`
- Tracking policy: `./scripts/qa/verify-evidence-tracking-policy.sh` enforces markdown-only evidence + redaction markers across canonical and transitional evidence paths.

## Related

- `docs/operations/EVIDENCE_SCHEMA.md`
- `docs/operations/DEPLOY_EVIDENCE_GATES.md`
