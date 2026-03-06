# Bead v2 Format Standard

## Title Rule (10 words max)

```
<Domain>: <Action> <Asset> (<Constraint/Goal>)
```

**Bad**: "Fix thing"
**Good**: "Auth: Enforce Authentik Admin MFA (single-admin)"

## Description Structure

### Required Sections (all classes)

- **Context**: Where this lives (repo/path/service), why now
- **Problem**: What's broken/risky, impact if unaddressed
- **Target state**: Bullet list, measurable outcomes
- **Verification**: Commands/scripts that prove it worked

### Required for SECURITY_T0 / DR_T0

- **Non-goals**: Prevent scope creep
- **Implementation plan**: Step-by-step (idempotent, reversible), prod safety
- **Rollback**: How to undo safely
- **Evidence**: Artifact paths + timestamps

### Optional (all classes)

- **Non-goals**: Useful for epics and multi-phase work
- **Rollback**: Useful for any infrastructure change

## Bead Classes

| Class | DoD Requirements |
|-------|-----------------|
| SECURITY_T0 | Verifier + negative assertion + rollback + evidence bundle |
| DR_T0 | Verifier + negative assertion + rollback + evidence bundle |
| RELIABILITY_T1 | Verifier + negative assertion + evidence |
| UX_T2 | Verifier + evidence |
| DOCS_T3 | Verifier |

## Definition of Done (DoD)

A bead is not "done" unless it has:

- [ ] Automated verification (script/CI gate)
- [ ] Negative assertion (prove the failure mode is blocked)
- [ ] Evidence artifact (file/log/CI artifact)
- [ ] Runbook/doc update (so it doesn't become tribal)

**Contrarian but true**: "Done" without a verifier is just "worked once on your laptop."

## Negative Assertion Patterns

- "script asserts user X is NOT admin"
- "audit fails if restore-test drifts away from PV flags"
- "verify fails if authn assets 404 on service domains"
- "cross-tenant API call returns 403, not 200"

## Closing a Bead

Final comment must include:

1. What changed
2. How to verify
3. Where the evidence lives
4. Any follow-up risks / TODO
