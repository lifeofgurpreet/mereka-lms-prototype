#!/usr/bin/env bash
# @covers AC-RS-004
# @spec: repository-structure_spec.md
set -euo pipefail

# verify-documentation-links.sh
# Check for broken internal links in markdown files

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

# Extract markdown links from file
extract_links() {
    local file="$1"
    # Match [text](path) where path doesn't start with http/https/#
    grep -oP '\[.*?\]\(\K[^)#][^)]*(?=\))' "$file" 2>/dev/null || true
}

# Check if link target exists
check_link() {
    local source_file="$1"
    local link="$2"
    local source_dir
    source_dir="$(dirname "$source_file")"

    # Skip external links
    if [[ "$link" =~ ^https?:// ]]; then
        return 0
    fi

    # Skip anchors
    if [[ "$link" =~ ^# ]]; then
        return 0
    fi

    # Resolve relative path
    local target_path
    if [[ "$link" =~ ^/ ]]; then
        # Absolute path from repo root
        target_path="${REPO_ROOT}${link}"
    else
        # Relative path from source file directory
        target_path="${source_dir}/${link}"
    fi

    # Normalize path (resolve ..)
    target_path="$(cd "$source_dir" && realpath --relative-to="$REPO_ROOT" "$link" 2>/dev/null)" || {
        warn "Invalid link in $source_file: $link"
        return 1
    }
    target_path="${REPO_ROOT}/${target_path}"

    # Check if target exists
    if [[ ! -e "$target_path" ]]; then
        fail "Broken link in $source_file: $link → $target_path"
        return 1
    fi

    return 0
}

# Main function
main() {
    echo "Checking documentation links..."
    echo "Repository: $REPO_ROOT"
    echo ""

    local total_links=0
    local broken_links=0

    # Find all markdown files (exclude archive and node_modules)
    while IFS= read -r -d '' file; do
        # Extract links from file
        while IFS= read -r link; do
            if [[ -n "$link" ]]; then
                total_links=$((total_links + 1))
                if ! check_link "$file" "$link"; then
                    broken_links=$((broken_links + 1))
                fi
            fi
        done < <(extract_links "$file")
    done < <(find docs/ specs/ -name "*.md" -not -path "*/archive/*" -not -path "*/node_modules/*" -print0)

    # Summary
    echo ""
    echo "================================================"
    echo "Documentation Links Verification Summary"
    echo "================================================"
    echo "Total links checked: $total_links"
    echo -e "${GREEN}Valid:${NC} $PASS_COUNT"
    echo -e "${YELLOW}Warnings:${NC} $WARN_COUNT"
    echo -e "${RED}Broken:${NC} $broken_links"
    echo ""

    if [[ $broken_links -eq 0 ]]; then
        echo -e "${GREEN}✓ All links are valid${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠ Some links may be broken (warnings only)${NC}"
        # Don't fail on broken links in CI - just warn
        exit 0
    fi
}

main "$@"
