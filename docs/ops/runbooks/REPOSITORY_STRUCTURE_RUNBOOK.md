# Repository Structure Runbook
_Audience: All Engineers • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers manual verification procedures for repository structure compliance.

> **Spec**: `specs/repository-structure_spec.md`
> **Testmap**: `specs/testmaps/repository-structure_spec.testmap.yml`

---

## Edge Case: Deprecated Path Usage

### Procedure
1. Search for imports or references to deprecated paths:
   ```bash
   # Check for references to deprecated tools/ directory
   grep -rn "tools/" --include="*.sh" --include="*.py" --include="*.yml" \
     --exclude-dir=.git --exclude-dir=node_modules | \
     grep -v "# deprecated" | grep -v "scripts/" | grep -v "spec-tools"

   # Check for references to deprecated ops/ directory
   grep -rn "ops/" --include="*.sh" --include="*.py" --include="*.yml" \
     --exclude-dir=.git --exclude-dir=node_modules | \
     grep -v "# deprecated" | grep -v "infrastructure/" | grep -v "operations"
   ```
2. Review any matches to confirm they are genuine deprecated path references
3. Verify deprecated directories contain only README.md redirects:
   ```bash
   ls tools/  # Should only contain README.md
   ls ops/    # Should only contain README.md (if dir exists)
   ```
4. Check CI/CD workflows for references to deprecated paths
5. Check CLAUDE.md and documentation for outdated path references

### Acceptance
- No scripts import from `tools/` or `ops/` directories
- Deprecated directories contain only README.md with redirect instructions
- CI/CD workflows use current paths (`scripts/`, `infrastructure/`)
- Documentation references current directory structure
