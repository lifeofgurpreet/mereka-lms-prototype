# Spec → Implementation Tasks

> Convert an approved spec into ordered implementation tasks.

## Input

An approved spec file from `specs/<name>_spec.md` with:
- Acceptance criteria (AC-PREFIX-NNN)
- Requirements (MUST/SHOULD/MAY)
- Edge cases
- Dependencies (`depends_on` frontmatter)

## Output

A structured task list with:
1. **Task ID**: Sequential (T-001, T-002, ...)
2. **Title**: Imperative verb phrase
3. **ACs covered**: List of AC-PREFIX-NNN IDs
4. **Dependencies**: Other task IDs that must complete first
5. **Complexity estimate**: S (1-2h), M (2-4h), L (4-8h), XL (1-2d)
6. **Files to touch**: Expected file paths

## Task Ordering Rules

1. **Infrastructure first**: Database schemas, K8s manifests, secrets
2. **Core models next**: Django models, API schemas
3. **Business logic**: Services, pipelines, workflows
4. **Integration**: Cross-service wiring, event handlers
5. **Observability**: Metrics, alerts, dashboards
6. **Tests**: Unit → integration → e2e
7. **Documentation**: Runbooks, ADRs

## Template

```markdown
# Implementation Tasks: <Spec Name>

**Spec**: `specs/<name>_spec.md`
**Generated**: YYYY-MM-DD
**Total ACs**: N
**Estimated effort**: X days

## Task List

### T-001: <Title>
- **ACs**: AC-PREFIX-001, AC-PREFIX-002
- **Depends on**: —
- **Complexity**: M
- **Files**: `path/to/file.py`, `path/to/test.py`
- **Notes**: Implementation guidance

### T-002: <Title>
- **ACs**: AC-PREFIX-003
- **Depends on**: T-001
- **Complexity**: S
- **Files**: `path/to/file.py`

## Dependency Graph

```
T-001 → T-002 → T-004
      → T-003 → T-005
                → T-006
```

## Parallel Tracks

| Track | Tasks | Can run with |
|-------|-------|-------------|
| A: Core | T-001, T-002 | — |
| B: Integration | T-003, T-004 | After A completes |
| C: Observability | T-005, T-006 | After A completes |
```

## Conventions

- Each task MUST map to at least one AC
- Every AC MUST appear in at least one task
- Tasks SHOULD be completable in a single session (<8h)
- Test tasks annotate with `@covers AC-PREFIX-NNN` and `@spec: <name>_spec.md`
- Mark MUST requirements as blocking; SHOULD as enhancement
