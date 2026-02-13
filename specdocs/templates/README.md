# Spec Templates

The canonical template lives at `specs/_TEMPLATE.md`. Type-specific guidance below.

## Template Types

| Type | Use When | Key Sections |
|------|----------|--------------|
| `feature_spec` | New capability or system | Full template (all sections) |
| `migration_spec` | Moving from old to new | Migration Strategy REQUIRED |
| `infrastructure_spec` | Platform/deployment infra | Configuration + K8s manifests |
| `service_spec` | New microservice | API Contract + Data Model REQUIRED |

## Usage

```bash
cp specs/_TEMPLATE.md specs/{name}_spec.md
# Edit frontmatter: set type, title, etc.
# Follow 10_generate_spec.md prompt for section guidance
```

## Type-Specific Notes

### migration_spec
- "What is changing" should compare old vs new
- Migration Strategy section is REQUIRED (Phases, Rollback, Data Preservation)
- Include data verification ACs (zero data loss)

### infrastructure_spec
- Configuration section is REQUIRED (env vars, K8s resources)
- Include K8s manifest paths in Verification section
- Reference k8s-deployment_spec.md

### service_spec
- API Contract section is REQUIRED
- Data Model section is REQUIRED
- Include health check AC (GET /health returns 200)
- Include metrics AC (Prometheus scrape endpoint)
