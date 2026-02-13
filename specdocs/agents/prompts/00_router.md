# Spec/Doc Router

> Decide whether the requested artifact is a **SPEC**, a **DOC**, or **BOTH**.

## Decision Criteria

| Signal | → SPEC | → DOC | → BOTH |
|--------|--------|-------|--------|
| Contains testable requirements (MUST/SHOULD/MAY) | Yes | No | — |
| Describes acceptance criteria or success metrics | Yes | No | — |
| Explains how to use an existing system | No | Yes | — |
| Records a decision (ADR) | No | Yes | — |
| Defines a new feature or service | Yes | No | If also needs runbook |
| Describes operational procedures | No | Yes | If also has SLO/SLA targets |
| Needs machine-checkable verification | Yes | No | — |
| Audience is primarily operators/developers learning the system | No | Yes | — |

## Routing Rules

1. **If the artifact defines WHAT MUST BE TRUE** → SPEC
   - Goes in `specs/<name>_spec.md`
   - Uses `_TEMPLATE.md` structure
   - Contains AC-PREFIX-NNN acceptance criteria
   - References `cross-cutting-requirements_spec.md`

2. **If the artifact explains WHAT IS or HOW TO** → DOC
   - Goes in `docs/<category>/` (onboarding, operations, architecture, migrations, adr)
   - Uses narrative prose, examples, screenshots
   - Links to relevant specs for normative requirements

3. **If the artifact needs BOTH** → Create both files
   - SPEC defines the contract (testable)
   - DOC explains context, tutorials, runbooks (readable)
   - They cross-reference each other via `links:` frontmatter

## Anti-patterns

- **Doc masquerading as spec**: Has MUST/SHOULD requirements but lives in `docs/` → Move requirements to a spec
- **Spec masquerading as doc**: Has tutorials and explanations but no testable criteria → Move to `docs/`
- **Mixed artifact**: Single file with both normative requirements AND tutorials → Split into spec + doc pair

## Example Routing

| Request | Route | Reason |
|---------|-------|--------|
| "Write requirements for SSO integration" | SPEC | Testable requirements |
| "Document how to deploy to GKE" | DOC | Operational procedure |
| "Define the branding system and explain how to use it" | BOTH | Spec for requirements + doc for usage guide |
| "Record why we chose MongoDB Atlas" | DOC (ADR) | Decision record |
| "Define SLO targets for the platform" | SPEC | Machine-checkable targets |
| "Write a troubleshooting guide for auth failures" | DOC | Explanatory content |
