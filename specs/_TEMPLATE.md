# Legacy Spec Template

_Status: superseded_  
_Superseded by: specs/templates/spec-template.md_

This path is transitional only. The live document is now maintained at:

- `specs/templates/spec-template.md`

Do not add new substantive content here.

## Dependencies

### Upstream

<!--
What must be completed BEFORE this can start?
Reference specs, infrastructure, or external systems.
-->

- **{Spec/System}**: {Why it's a blocker}
- **{Spec/System}**: {Why it's a blocker}

### Downstream

<!--
What depends on THIS spec?
What will break or be blocked if this is delayed?
-->

- **{Spec/Feature}**: {How it depends on this spec}
- **{Spec/Feature}**: {How it depends on this spec}

## Verification

<!--
Explain how to verify this spec is correctly implemented.
-->

### Automated Verification

Add verification scripts to `scripts/qa/verify-{feature}/` with `@covers` annotations:

```bash
#!/usr/bin/env bash
# @covers AC-001, AC-002
# @spec: {this-spec-name}_spec

set -euo pipefail
# Verification logic here
```

Run coverage report:
```bash
scripts/qa/spec-tools/ac-coverage-report.py
```

### Manual Verification

<!--
Steps that require human verification or monitoring.
Add to specs/plans/manual_verifications.yaml for tracking.
-->

1. {Manual test step 1}
2. {Manual test step 2}
3. {Monitoring verification over 24h period}

### Test Plan

<!--
If this spec has a separate test plan, reference it here.
Test plans live in specs/plans/{spec-name}_test_plan.md
-->

See `specs/plans/{spec-name}_test_plan.md` for comprehensive test scenarios.

## Data Model

<!--
OPTIONAL: Include if this spec introduces new data structures.
Use tables, schemas, or ER diagrams.
-->

### {Model Name}

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | {Description} |
| {field} | {type} | {constraints} | {description} |

### Relationships

- {Model A} has many {Model B}
- {Model C} belongs to {Model D}

## API Contract

<!--
OPTIONAL: Include if this spec defines public APIs.
Use OpenAPI snippets or clear request/response examples.
-->

### {Endpoint Name}

**Request**:
```http
POST /api/v1/{resource}
Content-Type: application/json

{
  "field": "value"
}
```

**Response**:
```http
HTTP/1.1 201 Created
Content-Type: application/json

{
  "id": "uuid",
  "field": "value"
}
```

## Configuration

<!--
OPTIONAL: List environment variables, config files, or feature flags.
-->

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| {VAR_NAME} | Yes | N/A | {Description} |
| {VAR_NAME} | No | {default} | {Description} |

### Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| {FEATURE_FLAG_NAME} | false | {When to enable} |

## Observability

<!--
OPTIONAL: Specify metrics, logs, traces, dashboards, alerts.
Only include if going beyond cross-cutting requirements.
-->

### Metrics

- `{metric_name}`: {Description}
- `{metric_name}`: {Description}

### Alerts

- **{Alert Name}**: Fires when {condition}, severity={level}

### Dashboards

- `{dashboard-name}`: {URL or path to Grafana JSON}

## Migration Strategy

<!--
OPTIONAL: Required for migration_spec type.
Define cutover plan, rollback, dual-running, data sync.
-->

### Phases

1. **Phase 1 - Preparation**: {What happens}
2. **Phase 2 - Dual-Running**: {What happens}
3. **Phase 3 - Cutover**: {What happens}
4. **Phase 4 - Decommission**: {What happens}

### Rollback Plan

{How to revert if things go wrong}

### Data Preservation

{How data is backed up, migrated, verified}

## Risks and Mitigations

<!--
Identify known risks and how you plan to handle them.
-->

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| {Risk description} | High/Medium/Low | High/Medium/Low | {How to mitigate} |

## Open Questions

<!--
List unresolved decisions or areas needing research.
Update as questions are answered.
-->

- [ ] {Question 1}?
- [ ] {Question 2}?

---

## Implementation Notes

<!--
OPTIONAL: Fill this section only when status=completed.
Capture lessons learned, deployment outcomes, deviations from plan.
Move to implementation_notes frontmatter field when done.
-->

{What actually happened during implementation, what changed from the spec, what we learned}
