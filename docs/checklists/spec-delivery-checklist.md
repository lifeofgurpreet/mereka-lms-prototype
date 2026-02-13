# Spec Delivery Checklist

Use this before marking a spec as "approved" or "completed".

## Structure
- [ ] YAML frontmatter present with all required fields (title, type, status, owner, version, last_updated)
- [ ] Human Summary section present (What, Why, Success)
- [ ] Agent Contract section present (Scope, Non-goals)
- [ ] Requirements section with normative language (MUST/SHOULD/MAY)
- [ ] Acceptance Criteria with Given-When-Then format and AC-PREFIX-NNN IDs
- [ ] Edge Cases section present
- [ ] Observability section (Logs, Metrics, Alerts, Dashboards)
- [ ] Rollout & Rollback section
- [ ] Open Questions documented

## Quality
- [ ] cross-cutting-requirements_spec.md referenced in frontmatter
- [ ] AC IDs follow naming standard from cross-cutting Section 7
- [ ] Version field present (semantic versioning)
- [ ] No duplicate AC IDs
- [ ] Testmap file exists in specs/testmaps/

## Dependencies
- [ ] depends_on field lists prerequisite specs
- [ ] No circular dependencies
- [ ] Related specs cross-referenced in links section
