# Live Mutation Exception Ledger Template

Parent policy:
- `docs/policies/operations/AGENT_EXECUTION_INVARIANTS.md`

Use this template only for explicitly approved live mutation exceptions.

```markdown
# Live Mutation Exception Record

- Timestamp:
- Lane:
- Actor:
- Target environment:
- Mutation class:
- Exact mutation:
- Reason:
- Evidence before mutation:
- Approval holder:
- Durable fix PR:
- Revert path:
- Closure state:
- Closure evidence:
```

## Minimum Requirements

The ledger entry is incomplete if any of the following are missing:

- timestamp
- lane
- actor
- target environment
- exact mutation
- reason
- evidence before mutation
- durable fix PR
- revert path
- closure state

