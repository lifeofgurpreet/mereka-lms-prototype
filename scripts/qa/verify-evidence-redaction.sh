#!/usr/bin/env bash
# @covers AC-215-A1, AC-215-A2
# @spec: repository-structure_spec.md
# Verify committed evidence files do not include raw sensitive auth/cookie material.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

STRICT="${STRICT:-1}"
STAGED_ONLY=0

usage() {
  cat <<'USAGE'
Usage: scripts/qa/verify-evidence-redaction.sh [--staged-only]

Options:
  --staged-only   Scan only staged files under evidence paths.

Environment:
  STRICT=1        Fail on findings (default).
  STRICT=0        Warn only.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged-only)
      STAGED_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$STRICT" in
  0|1) ;;
  *)
    echo "Invalid STRICT='$STRICT' (expected 0 or 1)" >&2
    exit 2
    ;;
esac

red=$'\033[0;31m'
yellow=$'\033[1;33m'
green=$'\033[0;32m'
reset=$'\033[0m'

collect_files() {
  if [[ "$STAGED_ONLY" -eq 1 ]]; then
    git diff --cached --name-only --diff-filter=ACM \
      | grep -E '^(docs/operations/evidence/|docs/evidence/observability/)' || true
    return
  fi

  if [[ -d docs/operations/evidence ]]; then
    find docs/operations/evidence -type f -print
  fi
  if [[ -d docs/evidence/observability ]]; then
    find docs/evidence/observability -type f -print
  fi
}

is_scannable_file() {
  local file="$1"
  case "$file" in
    *.md|*.txt|*.log|*.json|*.html|*.yaml|*.yml|*.tsv|*.csv)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

match_violation() {
  local line_lc="$1"

  # Require full redaction for cookie headers.
  if [[ "$line_lc" == *"set-cookie:"* ]] && [[ "$line_lc" != *"<redacted>"* ]]; then
    return 0
  fi

  if [[ "$line_lc" == *"sessionid="* ]] && [[ "$line_lc" != *"<redacted>"* ]]; then
    return 0
  fi

  if [[ "$line_lc" == *"csrftoken="* ]] && [[ "$line_lc" != *"<redacted>"* ]]; then
    return 0
  fi

  if [[ "$line_lc" =~ authorization:[[:space:]]*bearer[[:space:]]+[a-z0-9._-]{16,} ]] && [[ "$line_lc" != *"<redacted>"* ]]; then
    return 0
  fi

  if [[ "$line_lc" =~ x-api-key:[[:space:]]*[a-z0-9._-]{12,} ]] && [[ "$line_lc" != *"<redacted>"* ]]; then
    return 0
  fi

  if [[ "$line_lc" =~ eyj[a-z0-9_-]{8,}\.[a-z0-9_-]{8,}\.[a-z0-9_-]{8,} ]]; then
    return 0
  fi

  if [[ "$line_lc" =~ (api_key|master_key|secret_key|password)[^a-z0-9]*[:=][[:space:]]*[a-z0-9._-]{16,} ]] && \
     [[ "$line_lc" != *"<redacted>"* ]] && \
     [[ "$line_lc" != *"\${"* ]] && \
     [[ "$line_lc" != *"new_api_key"* ]] && \
     [[ "$line_lc" != *"change_me"* ]]; then
    return 0
  fi

  return 1
}

mapfile -t files < <(collect_files | sort -u)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No evidence files to scan."
  exit 0
fi

findings=0

for file in "${files[@]}"; do
  [[ -f "$file" ]] || continue
  is_scannable_file "$file" || continue

  line_num=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))
    line_lc="${line,,}"

    if match_violation "$line_lc"; then
      findings=$((findings + 1))
      if [[ "$STRICT" -eq 1 ]]; then
        printf '%sFAIL%s %s:%s potential sensitive evidence content\n' "$red" "$reset" "$file" "$line_num"
      else
        printf '%sWARN%s %s:%s potential sensitive evidence content\n' "$yellow" "$reset" "$file" "$line_num"
      fi
    fi
  done < "$file"
done

if [[ "$findings" -eq 0 ]]; then
  printf '%sPASS%s evidence redaction check: no sensitive patterns found\n' "$green" "$reset"
  exit 0
fi

if [[ "$STRICT" -eq 1 ]]; then
  echo ""
  echo "Evidence redaction check failed: $findings finding(s)."
  echo "Redact sensitive values (for example: set-cookie: <REDACTED>) before commit."
  exit 1
fi

echo ""
echo "Evidence redaction warnings: $findings finding(s)."
exit 0
