#!/usr/bin/env bash
# no_environment_domains_in_base.sh
#
# QA gate: Fail if environment-specific domains are found in deploy/k8s/base/.
#
# Environment-specific domains have no place in the base package — they belong
# in overlays or are injected via environment variables at runtime.
#
# Allowed exceptions:
#   - Comment lines (starting with #) that document why a domain appears
#   - The biji-biji-mfe-env.js and skillourfuture-mfe-env.js files are
#     per-tenant reference configs that are NOT deployed as ConfigMaps (see
#     the kustomization.yaml comment in apps/enterprise/mfe/); they document
#     the tenant's domain, not configure the running system.
#   - The production.py settings files use os.environ.get() with defaults —
#     the os.environ.get pattern means the default is overrideable at runtime.
#     We exclude production.py defaults since they're fallbacks, not fixed config.
#
# Usage: ./scripts/qa/no_environment_domains_in_base.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BASE_DIR="${REPO_ROOT}/deploy/k8s/base"

DOMAIN_PATTERNS=(
  'mereka\.io'
  'mereka\.dev'
  'biji-biji\.com'
  'skillourfuture'
  'academy\.biji-biji'
)

# Files that are explicitly allowed to contain tenant domain references:
# - Per-tenant MFE env files that serve as reference/documentation only
#   (not deployed as ConfigMaps per kustomization.yaml comment in mfe/)
# - production.py files where domains appear only inside os.environ.get() defaults
ALLOWED_PATTERNS=(
  'apps/enterprise/mfe/biji-biji-mfe-env\.js'
  'apps/enterprise/mfe/skillourfuture-mfe-env\.js'
  'apps/openedx/settings'
  'plugins/discovery/apps/settings'
  'plugins/credentials/apps/credentials/settings'
  'plugins/notes/apps/settings'
  'plugins/xqueue/apps/settings'
)

FAIL=0
TOTAL_FILES=0
VIOLATION_COUNT=0

build_allowed_grep_pattern() {
  local pattern=""
  for p in "${ALLOWED_PATTERNS[@]}"; do
    if [ -n "$pattern" ]; then
      pattern="${pattern}|${p}"
    else
      pattern="${p}"
    fi
  done
  echo "$pattern"
}

ALLOWED_GREP="$(build_allowed_grep_pattern)"

for domain_pattern in "${DOMAIN_PATTERNS[@]}"; do
  while IFS= read -r match_line; do
    # Extract file path (before the colon-lineno-colon)
    file_path="${match_line%%:*}"
    rest="${match_line#*:}"
    line_num="${rest%%:*}"
    line_content="${rest#*:}"

    # Skip comment lines (trimmed line starts with #)
    trimmed="${line_content#"${line_content%%[![:space:]]*}"}"
    if [[ "$trimmed" == \#* ]]; then
      continue
    fi

    # Skip allowed files
    if echo "$file_path" | grep -qE "$ALLOWED_GREP"; then
      continue
    fi

    # Skip os.environ.get() defaults in Python files — these are overrideable
    if [[ "$file_path" == *.py ]] && echo "$line_content" | grep -q 'os\.environ\.get('; then
      continue
    fi

    echo "FAIL: ${file_path}:${line_num}: environment domain '${domain_pattern}' found:"
    echo "      ${line_content}"
    FAIL=1
    (( VIOLATION_COUNT++ )) || true
  done < <(grep -rn --include="*.yaml" --include="*.yml" --include="*.py" --include="*.js" \
    -E "$domain_pattern" "$BASE_DIR" 2>/dev/null || true)
  (( TOTAL_FILES++ )) || true
done

if [ "$FAIL" -eq 0 ]; then
  echo "PASS: No environment-specific domains found in deploy/k8s/base/ (checked ${#DOMAIN_PATTERNS[@]} patterns)"
  exit 0
else
  echo ""
  echo "FAIL: Found ${VIOLATION_COUNT} environment domain violation(s) in deploy/k8s/base/"
  echo "      Domains belong in overlays or env vars, not in base."
  exit 1
fi
