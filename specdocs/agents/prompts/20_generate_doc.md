# Generate Doc

> Given a routed classification (DOCS), generate appropriate documentation.

## Input

- Topic description from the user
- Router decision: DOCS (from `00_router.md`)
- Doc type determined by content

## Doc Type Selection

| Content | Doc Type | Location |
|---------|----------|----------|
| Architecture decision | ADR | `docs/adr/NNN-{slug}.md` |
| Operational procedure | Runbook | `docs/operations/{slug}.md` |
| Setup/getting started | Onboarding | `docs/onboarding/{slug}.md` |
| System design explanation | Architecture | `docs/concepts/architecture/{slug}.md` |
| Migration playbook | Migration | `docs/migrations/{slug}.md` |
| Quick reference | Quickref | `docs/operations/quickref/{slug}.md` |

## ADR Format

```markdown
# ADR-NNN: {Title}

**Status**: proposed | accepted | deprecated | superseded
**Date**: YYYY-MM-DD
**Deciders**: {who}

## Context
{What is the issue?}

## Decision
{What did we decide?}

## Consequences
{What are the positive/negative outcomes?}
```

## Runbook Format

```markdown
# {Procedure Name}

## When to Use
{Trigger conditions}

## Prerequisites
{Required access, tools, context}

## Steps
1. {Step with command}
2. {Step with verification}

## Rollback
{How to undo if things go wrong}

## Escalation
{Who to contact if stuck}
```

## Quality Checks Before Delivery

- [ ] Doc type matches content (not forcing spec format on explanations)
- [ ] Written for the target audience (operators, developers, stakeholders)
- [ ] Concrete examples included (not abstract hand-waving)
- [ ] Commands are copy-pasteable
- [ ] Links to related specs where applicable

## Output

Document at the appropriate `docs/` path.
