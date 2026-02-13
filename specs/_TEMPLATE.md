---
title: "{SPEC_TITLE}"
type: "feature_spec"  # feature_spec | migration_spec | infrastructure_spec | service_spec
status: "draft"  # draft | review | approved | in_progress | completed
owner: "engineering"
vehicle: "talent_platform"  # talent_platform | data_pipeline
last_updated: "{YYYY-MM-DD}"
# completed_date: "{YYYY-MM-DD}"  # Uncomment when status=completed
# implementation_notes: |
#   Multi-line notes about implementation decisions, deployment outcomes, etc.
#   Only fill this when status=completed.
depends_on:
  # - "specs/cross-cutting-requirements_spec.md"  # REQUIRED if this spec references TCR requirements
  # - "specs/k8s-deployment_spec.md"  # Example dependency
links:
  related_docs:
    # - "docs/operations/{RUNBOOK}.md"
    # - "docs/architecture/{DESIGN_DOC}.md"
    # - "docs/adr/{NNN-decision-name}.md"
  related_specs:
    - "specs/cross-cutting-requirements_spec.md"  # REQUIRED (MEREKA-REF-001)
    # - "specs/{other-spec}_spec.md"
---

<!--
TEMPLATE INSTRUCTIONS (delete this entire comment block when writing your spec):

1. **Title**: Use descriptive, system-focused titles. Examples:
   - "Forum Service Migration: Ruby cs_comments_service to Python openedx-forum"
   - "Ecommerce Purchase Gateway (Stripe -> Open edX Integration)"
   - "Platform Middleware and Custom Apps"

2. **Type**: Choose one:
   - feature_spec: New capability or system
   - migration_spec: Moving from old to new system
   - infrastructure_spec: Platform/deployment infrastructure
   - service_spec: New microservice or major service change

3. **Status Flow**: draft → review → approved → in_progress → completed

4. **Depends On**: List specs that MUST be completed before this one.
   - Always include "specs/cross-cutting-requirements_spec.md" in related_specs
   - Only put hard blockers in depends_on

5. **Acceptance Criteria (AC) Naming**:
   - Use domain prefixes for clarity: AC-AUTH-001, AC-K8S-001, AC-DB-001
   - OR use simple AC-001, AC-002 for single-domain specs
   - NEVER reuse AC IDs across different sections/domains without prefixes
   - Use @spec: annotation in verification scripts to avoid collisions

6. **Cross-Cutting Requirements Reference**:
   - MEREKA-REF-001: All specs MUST reference cross-cutting-requirements_spec.md
   - Only specify overrides/additions to cross-cutting requirements in your spec
   - Don't duplicate tenant isolation, observability, secrets patterns

7. **Verification**:
   - Add verification scripts to scripts/qa/ or scripts/qa/verify-{feature}/
   - Use @covers annotations: @covers AC-001, AC-002
   - Use @spec: annotation when AC IDs might collide: @spec: ecommerce-purchase-gateway_spec
   - Run scripts/qa/spec-tools/ac-coverage-report.py to verify coverage

8. **Non-Functional Requirements**:
   - Use heading "### Non-Functional Requirements" (standardized)
   - Reference cross-cutting NFRs, only specify domain-specific ones
-->

# Human Summary

<!--
Write for HUMANS first. Explain WHAT is changing and WHY it matters.
Use concrete examples, real-world impact, and plain language.
Target audience: product managers, stakeholders, future engineers.
-->

## What is changing

<!--
Describe the change in concrete terms:
- What components/services are being modified?
- What new capabilities are being added?
- What existing behavior is being replaced?
- What data flows are involved?
- What files/directories are touched?

Be specific about file paths, service names, URLs, databases.
-->

{Description of what is being built, modified, or migrated}

## Why

<!--
Explain the business/technical rationale:
- What problem does this solve?
- Why now? (What forcing function drives this?)
- What are the consequences of NOT doing this?
- What is the impact on users, operations, or revenue?

Include upstream decisions, deprecations, security issues, or strategic goals.
-->

{Business and technical rationale for the change}

## Success looks like

<!--
Paint a picture of the desired end state:
- User-visible outcomes (latency, reliability, UX)
- Operational improvements (simplicity, observability, cost)
- Technical achievements (decommissioned services, reduced complexity)

Use concrete metrics where possible (e.g., "checkout completes in <60s").
-->

- {Measurable outcome 1}
- {Measurable outcome 2}
- {Measurable outcome 3}

---

# Agent Contract

<!--
Write for AI AGENTS. Be precise, unambiguous, and checkable.
This section defines the implementation contract.
-->

## Scope

### In Scope

<!--
Explicitly list what IS included in this spec.
Be comprehensive - this is the checklist for implementation.
-->

- {Component/feature 1}
- {Component/feature 2}
- {Integration point 1}
- {Data migration/transformation}
- {Configuration changes}
- {K8s manifests}
- {Monitoring/alerting}
- {Documentation updates}

### Out of Scope

<!--
Explicitly list what is NOT included.
Prevents scope creep and clarifies boundaries.
-->

- {Related feature that will be separate spec}
- {Upstream dependency not owned by this spec}
- {Future enhancement not needed for MVP}

## Non-goals

<!--
State what you are explicitly NOT trying to achieve.
Clarifies intent and prevents misinterpretation.
-->

- {Anti-goal 1 - what we're NOT building}
- {Anti-goal 2 - approach we're NOT taking}

## Acceptance Criteria

<!--
Use checkbox format with AC IDs.
AC IDs MUST be unique within this spec.
Use domain prefixes (AC-AUTH-001, AC-K8S-001) if multiple domains.
Use simple AC-001 format if single domain.

Format:
- [ ] AC-{DOMAIN}-001: Given {context}, when {action}, then {expected outcome}.

Make criteria testable and specific.
-->

### {Domain/Component 1}

- [ ] AC-{PREFIX}-001: Given {context}, when {action}, then {outcome}.
- [ ] AC-{PREFIX}-002: Given {context}, when {action}, then {outcome}.

### {Domain/Component 2}

- [ ] AC-{PREFIX}-003: Given {context}, when {action}, then {outcome}.
- [ ] AC-{PREFIX}-004: Given {context}, when {action}, then {outcome}.

### Non-Functional Requirements

<!--
REQUIRED heading (MEREKA-SEC-001).
Reference cross-cutting-requirements_spec.md, only specify overrides/additions.
-->

- [ ] AC-NFR-001: Performance requirement (if not covered by cross-cutting)
- [ ] AC-NFR-002: Security requirement (if not covered by cross-cutting)
- [ ] AC-NFR-003: Observability requirement (if not covered by cross-cutting)

**Cross-Cutting Inheritance**: This spec inherits requirements from `specs/cross-cutting-requirements_spec.md` including:
- Tenant isolation (if multi-tenant service)
- Observability baseline (metrics, logs, traces, dashboards, alerts)
- Secrets management (Infisical → GCP SM → ExternalSecrets → K8s)
- Common NFR thresholds (latency, availability, security)

Only domain-specific NFRs are listed above.

### Cross-Spec Integration

<!--
If this spec depends on other specs, define integration criteria.
Use AC-INT-NNN prefix for cross-spec acceptance criteria.
-->

#### {Upstream Spec Name} (Tier X → Tier Y)

- [ ] AC-INT-001: Given {upstream spec} is deployed, when {this feature}, then {integration works}.
- [ ] AC-INT-002: Given {shared resource}, when {concurrent access}, then {behavior}.

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
Add to specs/manual_verifications.yaml for tracking.
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
