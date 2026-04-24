# Spec Lint Rule Taxonomy

Rules are organized by category prefix. Each rule has a severity (error, warn, info)
and an optional autofix capability.

## Rule Categories

| Prefix | Category | Description |
|--------|----------|-------------|
| `SPEC-FM` | Frontmatter | YAML frontmatter structure, required fields, valid values |
| `SPEC-SEC` | Sections | Required/recommended markdown sections |
| `SPEC-NORM` | Normative Language | RFC 2119 keyword usage (MUST/SHOULD/MAY) |
| `SPEC-AC` | Acceptance Criteria | AC ID format, uniqueness, completeness |
| `SPEC-SHAPE` | Shape/Size | Spec size limits, section balance |
| `MEREKA-REF` | Mereka References | Cross-cutting spec references, related_specs |
| `MEREKA-SEC` | Mereka Sections | Project-specific section requirements (NFR) |
| `MEREKA-AC` | Mereka ACs | Project-specific AC rules |
| `TESTMAP` | Testmap Schema | Testmap YAML structure, AC mapping, verify types |
| `DOCS` | Documentation | Doc-specific rules (not specs) |

## Severity Levels

- **error**: Blocks CI merge. Must fix.
- **warn**: Displayed in CI. Should fix before merge.
- **info**: Advisory. Fix when convenient.

## Rule Files

Each `.yml` file in this directory defines one or more rules:

```yaml
rules:
  - id: "SPEC-FM-001"
    severity: "error"
    description: "Frontmatter must be present"
    rationale: "Frontmatter enables automated parsing and indexing"
    autofix: false
```
