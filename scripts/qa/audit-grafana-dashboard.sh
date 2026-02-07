#!/usr/bin/env bash
# Validate Grafana dashboard coverage against a contract so critical signals
# stay visible across handoffs.
#
# Usage:
#   ./scripts/qa/audit-grafana-dashboard.sh
#   ./scripts/qa/audit-grafana-dashboard.sh --json
#   ./scripts/qa/audit-grafana-dashboard.sh --strict-required
#   ./scripts/qa/audit-grafana-dashboard.sh --strict-required --strict-recommended
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DASHBOARD_FILE="${DASHBOARD_FILE:-/home/gurpreet/projects/observability/dashboards/03-applications/bbi-mereka-lms.json}"
CONTRACT_FILE="${CONTRACT_FILE:-${REPO_ROOT}/infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json}"
JSON_OUT=0
STRICT_REQUIRED=0
STRICT_RECOMMENDED=0

usage() {
  cat <<EOF
Usage: ./scripts/qa/audit-grafana-dashboard.sh [options]

Options:
  --dashboard-file PATH      Grafana dashboard JSON path
  --contract-file PATH       Coverage contract JSON path
  --json                     Emit JSON output
  --strict-required          Exit non-zero on required misses
  --strict-recommended       Exit non-zero on recommended misses
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dashboard-file) DASHBOARD_FILE="${2:-}"; shift 2 ;;
    --contract-file) CONTRACT_FILE="${2:-}"; shift 2 ;;
    --json) JSON_OUT=1; shift ;;
    --strict-required) STRICT_REQUIRED=1; shift ;;
    --strict-recommended) STRICT_RECOMMENDED=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf "%s" "$s"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 2
  }
}

require_cmd jq

required_errors=()
recommended_warnings=()

add_required_error() {
  required_errors+=("$1")
}

add_recommended_warning() {
  recommended_warnings+=("$1")
}

check_dashboard_files() {
  [[ -f "$CONTRACT_FILE" ]] || add_required_error "Contract file missing: $CONTRACT_FILE"
  [[ -f "$DASHBOARD_FILE" ]] || add_required_error "Dashboard file missing: $DASHBOARD_FILE"
  if [[ "${#required_errors[@]}" -gt 0 ]]; then
    return 1
  fi
  jq -e . "$CONTRACT_FILE" >/dev/null || add_required_error "Invalid JSON in contract file: $CONTRACT_FILE"
  jq -e . "$DASHBOARD_FILE" >/dev/null || add_required_error "Invalid JSON in dashboard file: $DASHBOARD_FILE"
}

contains_exact_line() {
  local needle="$1"
  local haystack_file="$2"
  rg -Fqx -- "$needle" "$haystack_file" >/dev/null 2>&1
}

contains_substring() {
  local needle="$1"
  local haystack_file="$2"
  rg -Fq -- "$needle" "$haystack_file" >/dev/null 2>&1
}

check_uid() {
  local expected actual
  expected="$(jq -r '.dashboard_uid // empty' "$CONTRACT_FILE")"
  actual="$(jq -r '.uid // empty' "$DASHBOARD_FILE")"
  if [[ -n "$expected" && "$actual" != "$expected" ]]; then
    add_required_error "Dashboard UID mismatch: expected '$expected', found '$actual'"
  fi
}

collect_dashboard_data() {
  local titles_file="$1"
  local datasources_file="$2"
  local queries_file="$3"

  jq -r '.panels[]? | (.title // empty)' "$DASHBOARD_FILE" | sed '/^$/d' | sort -u >"$titles_file"
  jq -r '
    [.. | objects | .datasource? // empty]
    | .[]
    | if type=="string" then .
      elif type=="object" then (.uid // .type // "")
      else "" end
  ' "$DASHBOARD_FILE" | sed '/^$/d' | sort -u >"$datasources_file"
  jq -r '
    .. | objects
    | (.expr? // .query? // .rawSql? // empty)
  ' "$DASHBOARD_FILE" >"$queries_file"
}

check_required_items() {
  local titles_file="$1"
  local datasources_file="$2"
  local queries_file="$3"
  local item

  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    contains_exact_line "$item" "$titles_file" || add_required_error "Missing required panel title: $item"
  done < <(jq -r '.required.panel_titles[]? // empty' "$CONTRACT_FILE")

  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    contains_exact_line "$item" "$datasources_file" || add_required_error "Missing required datasource: $item"
  done < <(jq -r '.required.datasources[]? // empty' "$CONTRACT_FILE")

  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    contains_substring "$item" "$queries_file" || add_required_error "Missing required query fragment: $item"
  done < <(jq -r '.required.query_fragments[]? // empty' "$CONTRACT_FILE")
}

check_recommended_items() {
  local titles_file="$1"
  local datasources_file="$2"
  local queries_file="$3"
  local item

  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    contains_exact_line "$item" "$titles_file" || add_recommended_warning "Missing recommended panel title: $item"
  done < <(jq -r '.recommended.panel_titles[]? // empty' "$CONTRACT_FILE")

  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    contains_exact_line "$item" "$datasources_file" || add_recommended_warning "Missing recommended datasource: $item"
  done < <(jq -r '.recommended.datasources[]? // empty' "$CONTRACT_FILE")

  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    contains_substring "$item" "$queries_file" || add_recommended_warning "Missing recommended query fragment: $item"
  done < <(jq -r '.recommended.query_fragments[]? // empty' "$CONTRACT_FILE")
}

tmpdir="$(mktemp -d -t audit-grafana-dashboard.XXXXXX)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

check_dashboard_files || true
if [[ "${#required_errors[@]}" -eq 0 ]]; then
  check_uid
fi

if [[ "${#required_errors[@]}" -eq 0 ]]; then
  titles_file="${tmpdir}/titles.txt"
  datasources_file="${tmpdir}/datasources.txt"
  queries_file="${tmpdir}/queries.txt"
  collect_dashboard_data "$titles_file" "$datasources_file" "$queries_file"
  check_required_items "$titles_file" "$datasources_file" "$queries_file"
  check_recommended_items "$titles_file" "$datasources_file" "$queries_file"
fi

if [[ "$JSON_OUT" -eq 1 ]]; then
  printf "{"
  printf "\"dashboard_file\":\"%s\"," "$(json_escape "$DASHBOARD_FILE")"
  printf "\"contract_file\":\"%s\"," "$(json_escape "$CONTRACT_FILE")"
  printf "\"required_errors\":["
  for i in "${!required_errors[@]}"; do
    [[ "$i" -gt 0 ]] && printf ","
    printf "\"%s\"" "$(json_escape "${required_errors[$i]}")"
  done
  printf "],"
  printf "\"recommended_warnings\":["
  for i in "${!recommended_warnings[@]}"; do
    [[ "$i" -gt 0 ]] && printf ","
    printf "\"%s\"" "$(json_escape "${recommended_warnings[$i]}")"
  done
  printf "],"
  printf "\"required_ok\":%s," "$([[ "${#required_errors[@]}" -eq 0 ]] && echo true || echo false)"
  printf "\"recommended_ok\":%s" "$([[ "${#recommended_warnings[@]}" -eq 0 ]] && echo true || echo false)"
  printf "}\n"
else
  echo "=========================================="
  echo "Grafana Dashboard Coverage Audit"
  echo "=========================================="
  echo "dashboard: ${DASHBOARD_FILE}"
  echo "contract : ${CONTRACT_FILE}"
  echo ""

  if [[ "${#required_errors[@]}" -eq 0 ]]; then
    echo "Required checks: PASS"
  else
    echo "Required checks: FAIL"
    for err in "${required_errors[@]}"; do
      echo "  - ${err}"
    done
  fi

  if [[ "${#recommended_warnings[@]}" -eq 0 ]]; then
    echo "Recommended checks: PASS"
  else
    echo "Recommended checks: WARN"
    for warn in "${recommended_warnings[@]}"; do
      echo "  - ${warn}"
    done
  fi
fi

if [[ "$STRICT_REQUIRED" -eq 1 && "${#required_errors[@]}" -gt 0 ]]; then
  exit 1
fi
if [[ "$STRICT_RECOMMENDED" -eq 1 && "${#recommended_warnings[@]}" -gt 0 ]]; then
  exit 1
fi

exit 0
