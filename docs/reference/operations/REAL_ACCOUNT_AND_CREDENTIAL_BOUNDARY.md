# Real Account And Credential Boundary

Parent policy:
- `docs/policies/operations/AGENT_EXECUTION_INVARIANTS.md`

## Hard Boundary

Agents MUST NOT:

- change real user passwords
- change operator passwords
- rotate or test credentials through ad hoc manual use
- log in through browser proof with real operator identities
- request or reveal real credentials in comments, logs, or evidence
- bypass seeded proof accounts by using production identities

## Allowed Identity Model

Proof lanes MAY use:

- seeded synthetic accounts
- synthetic tenants
- synthetic environments
- read-only public surfaces that do not require identity

## Default Rule

Any exception is prohibited unless it is:

1. explicitly approved
2. logged before execution
3. tied to a live mutation exception ledger
4. paired with a durable repo or GitOps fix path

If those conditions are not met, the action is not allowed.

