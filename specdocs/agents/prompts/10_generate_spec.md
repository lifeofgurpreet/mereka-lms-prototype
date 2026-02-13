# Generate Spec

> Given a routed classification (SPEC), generate a complete specification from the template.

## Input

- Feature description from the user
- Router decision: SPEC (from `00_router.md`)
- Template: `specs/_TEMPLATE.md`

## Process

1. **Determine spec type**: `feature_spec` | `migration_spec` | `infrastructure_spec` | `service_spec`
2. **Choose AC prefix**: Use domain-specific prefix from cross-cutting-requirements_spec.md Section 7
3. **Copy template**: Start from `specs/_TEMPLATE.md`
4. **Fill frontmatter**: title, type, status=draft, owner, vehicle, last_updated, depends_on, links
5. **Write Human Summary**: What/Why/Success in plain language for stakeholders
6. **Write Agent Contract**: Scope, Non-goals, ACs in Given-When-Then
7. **Add NFR section**: Reference cross-cutting, only add domain-specific NFRs
8. **Add Cross-Spec Integration**: AC-INT-NNN for upstream/downstream dependencies
9. **Add Verification section**: Point to scripts/qa/ paths
10. **Fill optional sections**: Data Model, API Contract, Configuration, Observability as needed

## AC Writing Rules

- Format: `- [ ] AC-{PREFIX}-{NNN}: Given {context}, when {action}, then {outcome}.`
- Every AC MUST be testable — no vague statements
- P0 ACs MUST be automatable
- Max 50 ACs per spec (warn if approaching limit)
- Edge cases get their own ACs, not buried in happy-path ACs

## Quality Checks Before Delivery

- [ ] Frontmatter has all required fields
- [ ] Human Summary is written for humans (no jargon-only sections)
- [ ] Every AC has a unique ID
- [ ] AC prefix is registered in cross-cutting Section 7
- [ ] NFR section references cross-cutting spec
- [ ] Dependencies section lists upstream/downstream
- [ ] Verification section has concrete script paths
- [ ] Open Questions captures unresolved decisions

## Output

`specs/{name}_spec.md` — ready for review status.
