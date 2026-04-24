# Spec Delivery Checklist

> Verify before moving a spec from draft to review.

## Frontmatter
- [ ] `title` is descriptive and system-focused
- [ ] `type` is one of: feature_spec, migration_spec, infrastructure_spec, service_spec
- [ ] `status` is set to "review" (not still "draft")
- [ ] `owner` is assigned
- [ ] `vehicle` matches project (talent_platform or data_pipeline)
- [ ] `last_updated` is today's date
- [ ] `depends_on` lists hard blockers (if any)
- [ ] `links.related_specs` includes cross-cutting-requirements_spec.md

## Human Summary
- [ ] "What is changing" is concrete (file paths, services, URLs)
- [ ] "Why" explains business/technical rationale
- [ ] "Success looks like" has measurable outcomes
- [ ] Written for humans, not just agents

## Agent Contract
- [ ] Scope: In-scope and Out-of-scope clearly listed
- [ ] Non-goals stated explicitly
- [ ] Every AC has unique ID (AC-PREFIX-NNN format)
- [ ] AC prefix is registered in cross-cutting Section 7
- [ ] ACs use Given-When-Then format
- [ ] P0 ACs are automatable
- [ ] Total AC count <= 50

## Required Sections
- [ ] Non-Functional Requirements section present
- [ ] Cross-Spec Integration section (if dependencies exist)
- [ ] Dependencies: Upstream and Downstream listed
- [ ] Verification: Automated and Manual paths defined

## Optional Sections (include if relevant)
- [ ] Data Model (if new schemas)
- [ ] API Contract (if public APIs)
- [ ] Configuration (if env vars or feature flags)
- [ ] Observability (if beyond cross-cutting baseline)
- [ ] Migration Strategy (required for migration_spec)
- [ ] Risks and Mitigations

## Final
- [ ] `make check-specs` passes
- [ ] No open questions that block review
