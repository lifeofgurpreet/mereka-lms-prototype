# Implementation Plans

This directory contains implementation plans and test plans generated from the specifications in `specs/`.

## Structure

Each spec produces three artifacts:

| File | Purpose |
|------|---------|
| `<name>_plan.md` | Implementation task breakdown with dependencies, complexity estimates, and file paths |
| `<name>_testplan.md` | Test matrix covering unit, integration, E2E, and verification tests |
| `../_generated/testmaps/<name>_spec.testmap.yml` | Active machine-readable YAML mapping of spec ACs to test types and file paths |

## Conventions

### Implementation Tiers

Plans reference the implementation ordering from `specs/IMPLEMENTATION_ORDER.md`:

| Tier | Description |
|------|-------------|
| 0 | Foundations (repository structure, secrets, tutor config) |
| 1 | Core Infrastructure (K8s, MongoDB, domains, branding) |
| 2 | Operational Visibility (observability, CI/CD, analytics,SLO/SLA) |
| 3 | Data & Migrations (Kajabi/MCT, video, DR, forum) |
| 4 | Enterprise Foundation (multi-tenancy → auth-sso → enterprise-microservices) |
| 5 | Enterprise Features (ecommerce, email, badges, content,assessment, privacy) |
| 6 | Deferred (mobile apps, proctoring) |

### Test Types

Plans use test types matching the actual test infrastructure in this repo:

| Test Type | Tool | Location |
|-----------|------|----------|
| `shell_verification` | Bash scripts | `scripts/qa/verify-*.sh`, `scripts/qa/audit-*.sh` |
| `ci_workflow` | GitHub Actions | `.github/workflows/*.yml` |
| `kubectl_check` | kubectl commands | Documented inline in testmap |
| `smoke_test` | Bash scripts | `scripts/qa/smoke-*.sh` |
| `pytest` | pytest | `services/<name>/tests/` (new services only) |
| `manual_verification` | Human checklist | Documented inlinein testplan |

### Special Cases

- **forum-service-migration**: COMPLETED — plan is retrospective (documents what was done)
- **proctoring-integration**: DEFERRED until 2027 — plan is aplaceholder
- **cross-cutting-requirements**: No plan (meta-spec definingshared requirements)

## Regeneration

Plans were generated using the `spec-planner` agent from each spec. To regenerate:

```bash
# Single plan
use spec-planner to generate implementation tasks from specs/<name>_spec.md

# Verify all plans exist
ls specs/plans/*_plan.md | wc -l       # expect: 25
ls specs/plans/*_testplan.md | wc -l   # expect: 25
ls specs/_generated/testmaps/*_spec.testmap.yml | wc -l  # expect generated coverage set
python3 scripts/qa/spec-tools/build_spec_catalog.py
```

## Current truth surfaces

- `specs/INDEX.md` is the human-facing generated index for the top-level spec corpus.
- `specs/_generated/spec-catalog.json` is the machine-readable generated catalog for the same corpus.
- `specs/_generated/testmaps/**` is the active generated verification mapping surface.
- `specs/testmaps/**` is frozen legacy compatibility and must not receive new edits.
