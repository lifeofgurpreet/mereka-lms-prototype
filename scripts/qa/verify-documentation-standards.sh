#!/usr/bin/env bash
# @covers AC-RS-001, AC-RS-002, AC-RS-003
# @spec: repository-structure_spec.md
set -euo pipefail

# verify-documentation-standards.sh
# Validates documentation files against DOCUMENTATION_STANDARDS.md

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Repo root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

# Check runbook metadata format
check_runbook_metadata() {
    echo ""
    echo "=== Checking Runbook Metadata ==="

    local runbooks_dir="docs/operations/runbooks"
    if [[ ! -d "$runbooks_dir" ]]; then
        warn "Runbooks directory not found: $runbooks_dir"
        return
    fi

    local missing_metadata=()
    while IFS= read -r -d '' file; do
        # Check for metadata line (starts with underscore)
        if ! head -5 "$file" | grep -qE "^_.*Audience.*•.*Owner.*•.*Last (verified|updated):"; then
            missing_metadata+=("$(basename "$file")")
        fi
    done < <(find "$runbooks_dir" -name "*.md" -print0)

    if [[ ${#missing_metadata[@]} -eq 0 ]]; then
        pass "All runbooks have metadata"
    else
        fail "Runbooks missing metadata: ${missing_metadata[*]}"
    fi
}

# Check spec frontmatter
check_spec_frontmatter() {
    echo ""
    echo "=== Checking Spec Frontmatter ==="

    local specs_dir="specs"
    if [[ ! -d "$specs_dir" ]]; then
        warn "Specs directory not found: $specs_dir"
        return
    fi

    local missing_frontmatter=()
    while IFS= read -r -d '' file; do
        # Skip IMPLEMENTATION_ORDER.md and manual_verifications.yaml
        if [[ "$(basename "$file")" == "IMPLEMENTATION_ORDER.md" ]] || \
           [[ "$(basename "$file")" == "manual_verifications.yaml" ]]; then
            continue
        fi

        # Check for YAML frontmatter
        if ! head -5 "$file" | grep -q "^---$"; then
            missing_frontmatter+=("$(basename "$file")")
        fi
    done < <(find "$specs_dir" -maxdepth 1 -name "*_spec.md" -print0)

    if [[ ${#missing_frontmatter[@]} -eq 0 ]]; then
        pass "All specs have YAML frontmatter"
    else
        fail "Specs missing frontmatter: ${missing_frontmatter[*]}"
    fi
}

# Check ADR format
check_adr_format() {
    echo ""
    echo "=== Checking ADR Format ==="

    local adr_dir="docs/adr"
    if [[ ! -d "$adr_dir" ]]; then
        warn "ADR directory not found: $adr_dir"
        return
    fi

    local invalid_adr=()
    while IFS= read -r -d '' file; do
        # Check for required sections
        if ! grep -q "^## Context" "$file" || \
           ! grep -q "^## Decision" "$file" || \
           ! grep -q "^## Consequences" "$file"; then
            invalid_adr+=("$(basename "$file")")
        fi
    done < <(find "$adr_dir" -name "*.md" -print0 2>/dev/null || true)

    if [[ ${#invalid_adr[@]} -eq 0 ]]; then
        pass "All ADRs have required sections"
    else
        fail "ADRs missing required sections: ${invalid_adr[*]}"
    fi
}

# Check verification scripts
check_verification_scripts() {
    echo ""
    echo "=== Checking Verification Scripts ==="

    local scripts_dir="scripts/qa"
    if [[ ! -d "$scripts_dir" ]]; then
        warn "QA scripts directory not found: $scripts_dir"
        return
    fi

    local missing_annotations=()
    while IFS= read -r -d '' file; do
        # Check for @covers annotation
        if ! head -10 "$file" | grep -qE "^# @covers"; then
            missing_annotations+=("$(basename "$file")")
        fi
    done < <(find "$scripts_dir" -name "verify-*.sh" -print0)

    if [[ ${#missing_annotations[@]} -eq 0 ]]; then
        pass "All verification scripts have @covers annotations"
    else
        warn "Scripts missing @covers: ${#missing_annotations[@]} files"
    fi
}

# Check for deprecated paths
check_deprecated_paths() {
    echo ""
    echo "=== Checking for Deprecated Paths ==="

    local deprecated_refs=()

    # Check for tools/ references (should be scripts/)
    if grep -r "tools/" docs/ specs/ --include="*.md" >/dev/null 2>&1; then
        deprecated_refs+=("Found 'tools/' references (should use 'scripts/')")
    fi

    # Check for ops/ references (should be infrastructure/ or scripts/)
    if grep -r "ops/" docs/ specs/ --include="*.md" >/dev/null 2>&1; then
        deprecated_refs+=("Found 'ops/' references (should use 'infrastructure/' or 'scripts/')")
    fi

    if [[ ${#deprecated_refs[@]} -eq 0 ]]; then
        pass "No deprecated path references found"
    else
        warn "${deprecated_refs[*]}"
    fi
}

# Check for hardcoded secrets in docs
check_hardcoded_secrets() {
    echo ""
    echo "=== Checking for Hardcoded Secrets ==="

    local secret_patterns=(
        'PASSWORD.*=.*"[^"]+'
        'API_KEY.*=.*"[^"]+'
        'SECRET.*=.*"[^"]+'
        'PRIVATE_KEY.*=.*"[^"]+'
    )

    local files_with_secrets=()
    for pattern in "${secret_patterns[@]}"; do
        while IFS= read -r file; do
            # Ignore:
            # - Example values (example, placeholder, changeme, CHANGE_ME)
            # - Environment variable references (os.environ, process.env, ${})
            # - Empty strings ("")
            # - Documentation examples (migration guides, setup guides)
            # - Archive directory (historical docs)
            if grep -E "$pattern" "$file" | \
               grep -qvE '(os\.environ|process\.env|\$\{|\"\"|changeme|CHANGE_ME|example|placeholder|Example|EXAMPLE|your-|<your|DOCUMENTATION_STANDARDS)' && \
               [[ ! "$file" =~ (archive|migrations|integrations|TASK3) ]]; then
                files_with_secrets+=("$file")
            fi
        done < <(find docs/ specs/ -name "*.md" -exec grep -l -E "$pattern" {} \; 2>/dev/null || true)
    done

    if [[ ${#files_with_secrets[@]} -eq 0 ]]; then
        pass "No hardcoded secrets in documentation"
    else
        warn "Files with potential hardcoded secrets (may be false positives): ${#files_with_secrets[@]} files"
    fi
}

# Check DOCUMENTATION_STANDARDS.md exists
check_standards_exist() {
    echo ""
    echo "=== Checking Standards Document ==="

    if [[ -f "docs/DOCUMENTATION_STANDARDS.md" ]]; then
        pass "docs/DOCUMENTATION_STANDARDS.md exists"
    else
        fail "docs/DOCUMENTATION_STANDARDS.md not found"
    fi
}

# Run all checks
main() {
    echo "Verifying documentation standards compliance..."
    echo "Repository: $REPO_ROOT"

    check_standards_exist
    check_runbook_metadata
    check_spec_frontmatter
    check_adr_format
    check_verification_scripts
    check_deprecated_paths
    check_hardcoded_secrets

    # Summary
    echo ""
    echo "================================================"
    echo "Documentation Standards Verification Summary"
    echo "================================================"
    echo -e "${GREEN}Passed:${NC} $PASS_COUNT"
    echo -e "${YELLOW}Warnings:${NC} $WARN_COUNT"
    echo -e "${RED}Failed:${NC} $FAIL_COUNT"
    echo ""

    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "${GREEN}✓ All checks passed${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some checks failed${NC}"
        exit 1
    fi
}

main "$@"
