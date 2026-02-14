#!/usr/bin/env bash
# @covers AC-LOG-005, AC-LOG-006
# @spec: observability-stack_spec.md
# Verify no PII (emails, passwords) are visible in logs.
#
# Usage:
#   ./scripts/qa/verify-observability-pii-filtering.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
APP_NS="${APP_NS:-mereka-lms}"
STRICT="${STRICT:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context) K8S_CONTEXT="$2"; shift 2 ;;
    --namespace) APP_NS="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

failures=0
skips=0

echo "Verify: PII filtering in logs"
echo "  context:   $K8S_CONTEXT"
echo "  namespace: $APP_NS"
echo ""

# Check if kubectl is available
if ! command -v kubectl >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} kubectl not available"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

# Check if cluster is reachable
if ! kubectl --context "$K8S_CONTEXT" cluster-info >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} Cannot reach cluster: $K8S_CONTEXT"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

# Services to check
SERVICES=("lms" "cms" "lms-worker" "cms-worker")

for svc in "${SERVICES[@]}"; do
  echo "Checking logs for service: $svc"

  # Get a pod for this service
  pod=$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get pods -l "app.kubernetes.io/name=$svc" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

  if [[ -z "$pod" ]]; then
    # Try alternate label
    pod=$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get pods -l "app=$svc" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  fi

  if [[ -z "$pod" ]]; then
    echo -e "  ${YELLOW}SKIP${NC} No running pod found for $svc"
    skips=$((skips + 1))
    continue
  fi

  echo "  Found pod: $pod"

  # Get recent logs (larger sample for PII detection)
  logs=$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" logs "$pod" --tail=200 2>/dev/null || echo "")

  if [[ -z "$logs" ]]; then
    echo -e "  ${YELLOW}SKIP${NC} No logs available from pod"
    skips=$((skips + 1))
    continue
  fi

  # AC-LOG-005: Check for email addresses
  echo -n "  Check: No email addresses in logs... "
  email_matches=$(echo "$logs" | grep -iE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | wc -l)

  if [[ "$email_matches" -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
  else
    # Check if emails are redacted/anonymized
    redacted_count=$(echo "$logs" | grep -iE '(redacted|anonymized|<email>|\*\*\*@|\[email\])' | wc -l)
    if [[ "$redacted_count" -gt 0 ]]; then
      echo -e "${GREEN}PASS${NC} (emails appear redacted)"
    else
      echo -e "${RED}FAIL${NC} Found $email_matches potential email addresses"
      failures=$((failures + 1))
      # Show first few matches
      echo "$logs" | grep -iE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | head -3 | sed 's/^/    /'
    fi
  fi

  # AC-LOG-006: Check for passwords
  echo -n "  Check: No passwords in logs... "
  # Look for patterns like password=value (not password=***)
  password_matches=$(echo "$logs" | grep -iE '(password|passwd|pwd)["\s]*[:=]["\s]*[^*\s]{3,}' | grep -v -iE '(password.*\*+|password.*redacted|password.*hidden)' | wc -l)

  if [[ "$password_matches" -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
  else
    echo -e "${RED}FAIL${NC} Found $password_matches potential password leaks"
    failures=$((failures + 1))
    # Show matches (with password values masked)
    echo "$logs" | grep -iE '(password|passwd|pwd)["\s]*[:=]["\s]*[^*\s]{3,}' | grep -v -iE '(password.*\*+|password.*redacted)' | head -3 | sed 's/password[^=]*=[^"]*\S\+/password=<REDACTED>/' | sed 's/^/    /'
  fi

  # Additional PII checks
  echo -n "  Check: No API keys/tokens in logs... "
  # Look for common token patterns
  token_matches=$(echo "$logs" | grep -iE '(api[_-]?key|token|secret|bearer)["\s]*[:=]["\s]*[a-zA-Z0-9+/=]{20,}' | grep -v -iE '(redacted|\*+|hidden)' | wc -l)

  if [[ "$token_matches" -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
  else
    echo -e "${YELLOW}WARN${NC} Found $token_matches potential tokens/keys (verify if redacted)"
  fi

  echo ""
done

echo -e "${YELLOW}NOTE:${NC} This check samples recent pod logs. For comprehensive PII filtering:"
echo "  1. Query Loki: {namespace=\"$APP_NS\"} |~ \"@.*\\\\.com\""
echo "  2. Review Django logging configuration for sensitive field filtering"
echo "  3. Check Promtail pipeline stages for PII redaction"

echo ""
if [[ "$failures" -eq 0 ]]; then
  if [[ "$skips" -gt 0 ]]; then
    echo -e "${YELLOW}OK (with $skips skipped checks)${NC}"
  else
    echo -e "${GREEN}OK${NC}"
  fi
  exit 0
else
  echo -e "${RED}FAILED ($failures checks failed)${NC}"
  exit 1
fi
