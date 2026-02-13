# Agent Spec Workflow

5-step workflow for spec creation and maintenance.

## Step 1: Route (SPEC or DOCS?)

Determine if the work requires a spec, doc, or both:

| Signal | Route |
|--------|-------|
| Has acceptance criteria | SPEC |
| Defines testable contracts | SPEC |
| Explains how to use something | DOCS |
| Architecture decision | ADR (docs/adr/) |
| Operational procedure | RUNBOOK (docs/operations/) |
| Both contract + explanation | SPEC + DOCS |

## Step 2: Write

1. Copy `specs/_TEMPLATE.md` to `specs/{feature-name}_spec.md`
2. Fill in frontmatter (use `specdocs.config.yml` for valid values)
3. Write Human Summary first (for humans)
4. Write Agent Contract (for machines)
5. Define Acceptance Criteria with AC IDs

## Step 3: Lint

```bash
make lint-specs
```

Fix all errors. Address warnings before merge.

Common fixes:
- Missing frontmatter field → Add to YAML header
- Missing cross-cutting reference → Add to related_specs
- Missing NFR section → Add `### Non-Functional Requirements`
- Duplicate AC ID → Renumber or add domain prefix

## Step 4: Verify

Create verification scripts:

```bash
# scripts/qa/verify-{feature}/{test-name}.sh
#!/usr/bin/env bash
# @covers AC-001, AC-002
# @spec: {feature-name}_spec.md
set -euo pipefail

# Verification logic
```

Generate testmaps:

```bash
make generate-testmaps
make validate-testmaps
```

## Step 5: Ship

```bash
make check-fast   # Lint + testmap validation (<30s)
make check         # Full suite (lint + testmaps + coverage + verify)
git add specs/ scripts/ specdocs.config.yml
git commit -m "feat(specs): add {feature-name} spec with verification"
```

## Maintenance

When modifying existing specs:
1. Update the spec markdown
2. Update verification scripts (@covers annotations)
3. `make generate-testmaps` to refresh
4. `make check-fast` before commit
