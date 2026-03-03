#!/usr/bin/env bash
# Bead v2 Format Linter
# Validates beads against the v2 format standard (docs/standards/bead-v2-format.md)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Configuration
JSON_OUTPUT=false
SUGGEST_FIXES=false
VERBOSE=false

# Counters
TOTAL_BEADS=0
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Detail tracking
declare -a TITLE_PASS=()
declare -a TITLE_WARN=()
declare -a TITLE_FAIL=()
declare -a DESC_FULL=()
declare -a DESC_PARTIAL=()
declare -a DESC_MINIMAL=()
declare -a DOD_PASS=()
declare -a DOD_WARN=()
declare -a CLASS_SECURITY_PASS=()
declare -a CLASS_SECURITY_FAIL=()
declare -a CLASS_DR_PASS=()
declare -a CLASS_DR_FAIL=()
declare -a CLASS_RELIABILITY_PASS=()
declare -a CLASS_RELIABILITY_FAIL=()

# Helper: count words in title
count_words() {
    echo "$1" | wc -w | tr -d ' '
}

# Helper: check if title has domain prefix (word followed by colon)
has_domain_prefix() {
    [[ "$1" =~ ^[A-Za-z0-9_-]+:[[:space:]] ]]
}

# Helper: count description sections
count_sections() {
    local desc="$1"
    local count=0

    # Check for required v2 sections (flexible format - headers or keywords)
    # Context: Where this lives, why now
    if grep -qiE '^(##? *)?(Context|Where|Scope):' <<< "$desc" || grep -qi 'why now|repo/path|service:' <<< "$desc"; then
        count=$((count + 1))
    fi

    # Problem: What's broken/risky
    if grep -qiE '^(##? *)?(Problem|Issue|Current state|CRITICAL):' <<< "$desc" || grep -qi 'broken|risky|impact if|footgun' <<< "$desc"; then
        count=$((count + 1))
    fi

    # Target state: Bullet list, measurable outcomes
    if grep -qiE '^(##? *)?(Target state|Goal|Success criteria|Acceptance criteria|DoD):' <<< "$desc" || grep -qi '^- \[' <<< "$desc"; then
        count=$((count + 1))
    fi

    # Verification: Commands/scripts
    if grep -qiE '^(##? *)?(Verification|Evidence|Validation):' <<< "$desc" || grep -qi 'scripts/|\.sh|kubectl|verify' <<< "$desc"; then
        count=$((count + 1))
    fi

    echo "$count"
}

# Helper: check class-specific sections
check_class_sections() {
    local desc="$1"
    local labels="$2"
    local required_count=0
    local found_count=0

    # SECURITY_T0 or DR_T0 require: Non-goals, Implementation plan, Rollback, Evidence
    if grep -qi 'SECURITY_T0|DR_T0' <<< "$labels"; then
        required_count=4
        grep -qiE '^(##? *)?(Non-goals|Out of scope):' <<< "$desc" && ((found_count++)) || true
        grep -qiE '^(##? *)?(Implementation plan|Plan|Steps):' <<< "$desc" && ((found_count++)) || true
        grep -qiE '^(##? *)?(Rollback|Backout):' <<< "$desc" && ((found_count++)) || true
        grep -qiE '^(##? *)?(Evidence|Artifacts):' <<< "$desc" && ((found_count++)) || true
    fi

    # RELIABILITY_T1 requires: Evidence
    if grep -qi 'RELIABILITY_T1' <<< "$labels"; then
        required_count=1
        grep -qiE '^(##? *)?(Evidence|Artifacts):' <<< "$desc" && ((found_count++)) || true
    fi

    echo "${found_count}/${required_count}"
}

# Helper: check DoD in closing comment
check_dod_comment() {
    local comments="$1"

    # Must have closing comment with >50 chars
    local last_comment
    last_comment=$(echo "$comments" | jq -r '.[-1].text // ""' 2>/dev/null || echo "")

    [[ ${#last_comment} -lt 50 ]] && return 1

    # Check for DoD keywords (at least 2 of: verify, evidence, changed, fixed, follow-up, risk, TODO)
    local keyword_count=0
    grep -qi "verify" <<< "$last_comment" && ((keyword_count++)) || true
    grep -qi "evidence" <<< "$last_comment" && ((keyword_count++)) || true
    grep -qi "changed\|fixed" <<< "$last_comment" && ((keyword_count++)) || true
    grep -qi "follow-up\|followup" <<< "$last_comment" && ((keyword_count++)) || true
    grep -qi "risk\|TODO" <<< "$last_comment" && ((keyword_count++)) || true

    [[ $keyword_count -ge 2 ]]
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --fix)
            SUGGEST_FIXES=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            cat <<EOF
Usage: $0 [OPTIONS]

Validate beads against v2 format standard (docs/standards/bead-v2-format.md)

OPTIONS:
  --json          Output machine-readable JSON
  --fix           Suggest fixes for common issues
  -v, --verbose   Show detailed per-bead analysis
  -h, --help      Show this help

EXIT CODES:
  0 - No FAIL-level issues
  1 - At least one FAIL-level issue found
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Check if br is available
if ! command -v br &>/dev/null; then
    echo "ERROR: br (beads_rust) not found in PATH" >&2
    exit 1
fi

# Fetch all beads (open + closed)
cd "$REPO_ROOT"
OPEN_BEADS=$(br list --status open --json 2>/dev/null || echo "[]")
CLOSED_BEADS=$(br list --status closed --json 2>/dev/null || echo "[]")

# Combine into single array
ALL_BEADS=$(jq -s '.[0] + .[1]' <(echo "$OPEN_BEADS") <(echo "$CLOSED_BEADS"))
TOTAL_BEADS=$(echo "$ALL_BEADS" | jq 'length')

if [[ $TOTAL_BEADS -eq 0 ]]; then
    echo "No beads found" >&2
    exit 0
fi

# Process each bead
for i in $(seq 0 $((TOTAL_BEADS - 1))); do
    bead=$(echo "$ALL_BEADS" | jq ".[$i]")

    id=$(echo "$bead" | jq -r '.id')
    title=$(echo "$bead" | jq -r '.title')
    desc=$(echo "$bead" | jq -r '.description // ""')
    status=$(echo "$bead" | jq -r '.status')
    labels=$(echo "$bead" | jq -r '.labels // [] | join(" ")')
    comments=$(echo "$bead" | jq -c '.comments // []')

    bead_score="PASS"
    issues=()

    # === TITLE CHECK ===
    word_count=$(count_words "$title")
    if ! has_domain_prefix "$title"; then
        TITLE_WARN+=("$id")
        bead_score="WARN"
        issues+=("title: missing domain prefix")
    elif [[ $word_count -gt 10 ]]; then
        TITLE_FAIL+=("$id")
        bead_score="FAIL"
        issues+=("title: $word_count words (>10)")
    else
        TITLE_PASS+=("$id")
    fi

    # === DESCRIPTION SECTIONS CHECK ===
    section_count=$(count_sections "$desc")
    if [[ $section_count -eq 4 ]]; then
        DESC_FULL+=("$id")
    elif [[ $section_count -ge 2 ]]; then
        DESC_PARTIAL+=("$id")
        [[ "$bead_score" == "PASS" ]] && bead_score="WARN"
        issues+=("description: $section_count/4 sections")
    else
        DESC_MINIMAL+=("$id")
        bead_score="FAIL"
        issues+=("description: $section_count/4 sections")
    fi

    # === CLASS-SPECIFIC SECTIONS CHECK ===
    class_check=$(check_class_sections "$desc" "$labels")
    if [[ "$class_check" != "0/0" ]]; then
        IFS='/' read -r found required <<< "$class_check"
        if [[ $found -eq $required ]]; then
            if grep -qi "SECURITY_T0" <<< "$labels"; then
                CLASS_SECURITY_PASS+=("$id")
            fi
            if grep -qi "DR_T0" <<< "$labels"; then
                CLASS_DR_PASS+=("$id")
            fi
            if grep -qi "RELIABILITY_T1" <<< "$labels"; then
                CLASS_RELIABILITY_PASS+=("$id")
            fi
        else
            bead_score="FAIL"
            issues+=("class-specific: $found/$required sections")
            if grep -qi "SECURITY_T0" <<< "$labels"; then
                CLASS_SECURITY_FAIL+=("$id")
            fi
            if grep -qi "DR_T0" <<< "$labels"; then
                CLASS_DR_FAIL+=("$id")
            fi
            if grep -qi "RELIABILITY_T1" <<< "$labels"; then
                CLASS_RELIABILITY_FAIL+=("$id")
            fi
        fi
    fi

    # === DOD CHECK (closed beads only) ===
    if [[ "$status" == "closed" ]]; then
        if check_dod_comment "$comments"; then
            DOD_PASS+=("$id")
        else
            DOD_WARN+=("$id")
            [[ "$bead_score" == "PASS" ]] && bead_score="WARN"
            issues+=("DoD: closing comment missing keywords")
        fi
    fi

    # Count overall score
    case "$bead_score" in
        PASS) ((PASS_COUNT++)) || true ;;
        WARN) ((WARN_COUNT++)) || true ;;
        FAIL) ((FAIL_COUNT++)) || true ;;
    esac

    # Verbose output
    if [[ "$VERBOSE" == true && ${#issues[@]} -gt 0 ]]; then
        echo "[$bead_score] $id - $title"
        for issue in "${issues[@]}"; do
            echo "  ⚠ $issue"
        done
        echo
    fi
done

# === OUTPUT RESULTS ===
if [[ "$JSON_OUTPUT" == true ]]; then
    # Machine-readable JSON output
    jq -n \
        --argjson total "$TOTAL_BEADS" \
        --argjson pass "$PASS_COUNT" \
        --argjson warn "$WARN_COUNT" \
        --argjson fail "$FAIL_COUNT" \
        --argjson title_pass "$(jq -nc '$ARGS.positional' --args "${TITLE_PASS[@]+"${TITLE_PASS[@]}"}")" \
        --argjson title_warn "$(jq -nc '$ARGS.positional' --args "${TITLE_WARN[@]+"${TITLE_WARN[@]}"}")" \
        --argjson title_fail "$(jq -nc '$ARGS.positional' --args "${TITLE_FAIL[@]+"${TITLE_FAIL[@]}"}")" \
        --argjson desc_full "$(jq -nc '$ARGS.positional' --args "${DESC_FULL[@]+"${DESC_FULL[@]}"}")" \
        --argjson desc_partial "$(jq -nc '$ARGS.positional' --args "${DESC_PARTIAL[@]+"${DESC_PARTIAL[@]}"}")" \
        --argjson desc_minimal "$(jq -nc '$ARGS.positional' --args "${DESC_MINIMAL[@]+"${DESC_MINIMAL[@]}"}")" \
        --argjson dod_pass "$(jq -nc '$ARGS.positional' --args "${DOD_PASS[@]+"${DOD_PASS[@]}"}")" \
        --argjson dod_warn "$(jq -nc '$ARGS.positional' --args "${DOD_WARN[@]+"${DOD_WARN[@]}"}")" \
        '{
            summary: {
                total: $total,
                pass: $pass,
                warn: $warn,
                fail: $fail,
                pass_pct: (($pass / $total * 100) | floor),
                warn_pct: (($warn / $total * 100) | floor),
                fail_pct: (($fail / $total * 100) | floor)
            },
            title_format: {
                pass: $title_pass,
                warn: $title_warn,
                fail: $title_fail
            },
            description_sections: {
                full: $desc_full,
                partial: $desc_partial,
                minimal: $desc_minimal
            },
            dod_compliance: {
                pass: $dod_pass,
                warn: $dod_warn
            }
        }'
else
    # Human-readable output
    cat <<EOF
=== Bead v2 Format Lint Report ===

SUMMARY:
  Total scanned: $TOTAL_BEADS
  PASS: $PASS_COUNT ($(( PASS_COUNT * 100 / TOTAL_BEADS ))%)
  WARN: $WARN_COUNT ($(( WARN_COUNT * 100 / TOTAL_BEADS ))%)
  FAIL: $FAIL_COUNT ($(( FAIL_COUNT * 100 / TOTAL_BEADS ))%)

TITLE FORMAT:
  ✓ PASS: ${#TITLE_PASS[@]} beads have proper Domain: Action Asset pattern
  ⚠ WARN: ${#TITLE_WARN[@]} beads missing Domain: prefix
  ✗ FAIL: ${#TITLE_FAIL[@]} beads have >10 word titles

DESCRIPTION SECTIONS:
  ✓ Full v2 (4/4 sections): ${#DESC_FULL[@]} beads
  ⚠ Partial (2-3 sections): ${#DESC_PARTIAL[@]} beads
  ✗ Minimal (0-1 sections): ${#DESC_MINIMAL[@]} beads

CLASS-SPECIFIC:
  SECURITY_T0: ${#CLASS_SECURITY_PASS[@]}/$((${#CLASS_SECURITY_PASS[@]} + ${#CLASS_SECURITY_FAIL[@]})) beads compliant
  DR_T0: ${#CLASS_DR_PASS[@]}/$((${#CLASS_DR_PASS[@]} + ${#CLASS_DR_FAIL[@]})) beads compliant
  RELIABILITY_T1: ${#CLASS_RELIABILITY_PASS[@]}/$((${#CLASS_RELIABILITY_PASS[@]} + ${#CLASS_RELIABILITY_FAIL[@]})) beads compliant

DOD (closed beads):
  ✓ PASS: ${#DOD_PASS[@]}/$((${#DOD_PASS[@]} + ${#DOD_WARN[@]})) closed beads have proper closing comments
  ⚠ WARN: ${#DOD_WARN[@]}/$((${#DOD_PASS[@]} + ${#DOD_WARN[@]})) closed beads have minimal closing comments

EOF

    # Show top offenders (worst compliance)
    if [[ ${#TITLE_FAIL[@]} -gt 0 || ${#DESC_MINIMAL[@]} -gt 0 ]]; then
        echo "TOP OFFENDERS (worst v2 compliance):"
        for id in "${TITLE_FAIL[@]:0:5}"; do
            title=$(echo "$ALL_BEADS" | jq -r ".[] | select(.id == \"$id\") | .title")
            echo "  $id: Title (FAIL) — \"$title\""
        done
        for id in "${DESC_MINIMAL[@]:0:5}"; do
            if [[ ! " ${TITLE_FAIL[*]} " =~ " ${id} " ]]; then
                title=$(echo "$ALL_BEADS" | jq -r ".[] | select(.id == \"$id\") | .title")
                echo "  $id: Description (FAIL) — \"$title\""
            fi
        done
        echo
    fi

    # Show best compliance examples
    if [[ ${#DESC_FULL[@]} -gt 0 ]]; then
        echo "MOST IMPROVED (best v2 compliance):"
        for id in "${DESC_FULL[@]:0:5}"; do
            if [[ " ${TITLE_PASS[*]} " =~ " ${id} " ]]; then
                title=$(echo "$ALL_BEADS" | jq -r ".[] | select(.id == \"$id\") | .title")
                echo "  $id: Title (PASS) + Description (PASS) — \"$title\""
            fi
        done
        echo
    fi

    # Suggest fixes if requested
    if [[ "$SUGGEST_FIXES" == true && ${#TITLE_WARN[@]} -gt 0 ]]; then
        echo "SUGGESTED FIXES:"
        echo
        echo "Missing Domain Prefix (${#TITLE_WARN[@]} beads):"
        for id in "${TITLE_WARN[@]:0:3}"; do
            title=$(echo "$ALL_BEADS" | jq -r ".[] | select(.id == \"$id\") | .title")
            # Suggest domain based on labels
            labels=$(echo "$ALL_BEADS" | jq -r ".[] | select(.id == \"$id\") | .labels // [] | join(\" \")")
            suggested_domain="Task"
            if grep -qi "auth\|authentik" <<< "$labels"; then suggested_domain="Auth"
            elif grep -qi "k8s\|kubernetes" <<< "$labels"; then suggested_domain="K8s"
            elif grep -qi "ci\|pipeline" <<< "$labels"; then suggested_domain="CI"
            elif grep -qi "tutor" <<< "$labels"; then suggested_domain="Tutor"
            elif grep -qi "forum" <<< "$labels"; then suggested_domain="Forum"
            elif grep -qi "video" <<< "$labels"; then suggested_domain="Video"
            elif grep -qi "email" <<< "$labels"; then suggested_domain="Email"
            elif grep -qi "dr\|backup\|velero" <<< "$labels"; then suggested_domain="DR"
            elif grep -qi "security\|secrets" <<< "$labels"; then suggested_domain="Security"
            elif grep -qi "enterprise" <<< "$labels"; then suggested_domain="Enterprise"
            fi
            echo "  $id: \"$suggested_domain: $title\""
        done
        echo
    fi
fi

# Exit code: 0 if no FAIL, 1 otherwise
[[ $FAIL_COUNT -eq 0 ]]
