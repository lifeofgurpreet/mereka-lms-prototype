# Specdocs Tools

Verification and analysis tools for the spec ecosystem.

## Tools

All tools live in `scripts/qa/spec-tools/` and are referenced here for discoverability.

| Tool | Purpose | Usage |
|------|---------|-------|
| `render_index.py` | Generate `specs/INDEX.md` from frontmatter | `python3 scripts/qa/spec-tools/render_index.py` |
| `spec_coverage_dashboard.py` | AC coverage analysis across specs | `python3 scripts/qa/spec-tools/spec_coverage_dashboard.py` |
| `validate_testmap_format.py` | Validate testmap YAML schema | `python3 scripts/qa/spec-tools/validate_testmap_format.py` |

## Makefile Integration

```bash
make check-specs    # Run spec linter
make spec-verify    # Alias for check-specs
make spec-fix       # Auto-fix common issues (future)
```

## CI Integration

See `.github/workflows/verify-specs.yml` for CI pipeline that runs:
1. Spec frontmatter validation
2. AC format checking
3. Cross-reference verification
4. Testmap schema validation
