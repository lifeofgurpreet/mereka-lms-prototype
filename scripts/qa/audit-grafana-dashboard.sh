#!/usr/bin/env bash
# @covers AC-002
# @spec: observability-stack_spec.md
# Validate Grafana dashboard coverage against a contract so critical signals
# stay visible across handoffs.
#
# Usage:
#   ./scripts/qa/audit-grafana-dashboard.sh
#   ./scripts/qa/audit-grafana-dashboard.sh --all
#   ./scripts/qa/audit-grafana-dashboard.sh --json
#   ./scripts/qa/audit-grafana-dashboard.sh --strict-required
#   ./scripts/qa/audit-grafana-dashboard.sh --strict-required --strict-recommended
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_DASHBOARD_FILE="${REPO_ROOT}/infrastructure/monitoring/grafana/dashboards/slo-overview.json"
DEFAULT_CONTRACT_FILE="${REPO_ROOT}/infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json"
DEFAULT_CATALOG_FILE="${REPO_ROOT}/infrastructure/monitoring/grafana/dashboard-catalog.bbi-mereka-lms.json"
LEGACY_DASHBOARD_FILE="${HOME}/projects/observability/dashboards/03-applications/bbi-mereka-lms.json"
USER_DASHBOARD_FILE="${DASHBOARD_FILE:-}"
USER_CONTRACT_FILE="${CONTRACT_FILE:-}"
DASHBOARD_FILE="${USER_DASHBOARD_FILE:-$DEFAULT_DASHBOARD_FILE}"
if [[ ! -f "$DASHBOARD_FILE" ]] && [[ -f "$LEGACY_DASHBOARD_FILE" ]]; then
  DASHBOARD_FILE="$LEGACY_DASHBOARD_FILE"
fi
CONTRACT_FILE="${USER_CONTRACT_FILE:-$DEFAULT_CONTRACT_FILE}"
CATALOG_FILE="${CATALOG_FILE:-$DEFAULT_CATALOG_FILE}"
JSON_OUT=0
STRICT_REQUIRED=0
STRICT_RECOMMENDED=0
AUDIT_ALL=0
EXPLICIT_SINGLE=0

usage() {
  cat <<EOF
Usage: ./scripts/qa/audit-grafana-dashboard.sh [options]

Options:
  --all                      Audit all dashboards from the catalog
  --dashboard-file PATH      Grafana dashboard JSON path
  --contract-file PATH       Coverage contract JSON path
  --catalog-file PATH        Dashboard catalog JSON path
  --json                     Emit JSON output
  --strict-required          Exit non-zero on required misses
  --strict-recommended       Exit non-zero on recommended misses
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) AUDIT_ALL=1; shift ;;
    --dashboard-file) DASHBOARD_FILE="${2:-}"; EXPLICIT_SINGLE=1; shift 2 ;;
    --contract-file) CONTRACT_FILE="${2:-}"; EXPLICIT_SINGLE=1; shift 2 ;;
    --catalog-file) CATALOG_FILE="${2:-}"; shift 2 ;;
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

resolve_repo_path() {
  local candidate="${1:-}"
  if [[ -z "$candidate" ]]; then
    printf '%s' ""
    return 0
  fi
  if [[ "$candidate" = /* ]]; then
    printf '%s' "$candidate"
    return 0
  fi
  printf '%s' "${REPO_ROOT}/${candidate}"
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

to_minutes_from_range() {
  local token="$1"
  local value unit minutes

  token="${token#[}"
  token="${token%]}"
  value="${token%[smhdwy]}"
  unit="${token: -1}"

  case "$unit" in
    s) minutes="$(awk "BEGIN{print int($value/60)}")" ;;
    m) minutes="$value" ;;
    h) minutes="$(awk "BEGIN{print $value * 60}")" ;;
    d) minutes="$(awk "BEGIN{print $value * 1440}")" ;;
    w) minutes="$(awk "BEGIN{print $value * 10080}")" ;;
    *) minutes="" ;;
  esac

  printf '%s' "$minutes"
}

query_freshness_window_met() {
  local query="$1"
  local max_minutes="$2"
  local minutes

  [[ "$max_minutes" -le 0 ]] && return 0
  # SLO recording rules are pre-computed time-windowed gauges. The dashboard
  # intentionally reads them as instant vectors without adding extra range
  # selectors, and freshness is enforced by Prometheus rule evaluation cadence.
  if [[ "$query" =~ ^[[:space:]]*mereka:slo:(error_budget_remaining_ratio|error_budget_remaining_minutes|journey_error_budget_remaining_ratio)(\{[^}]*\})?[[:space:]]*$ ]]; then
    return 0
  fi
  [[ "$query" == *"\$__rate_interval"* ]] && return 0
  [[ "$query" == *"\$__interval"* ]] && return 0
  [[ "$query" == *"\$__range"* ]] && return 0

  local range
  while IFS= read -r range; do
    [[ -z "$range" ]] && continue
    minutes="$(to_minutes_from_range "$range")"
    [[ -z "$minutes" ]] && continue
    if (( minutes <= max_minutes )); then
      return 0
    fi
  done < <(grep -oE '\[[0-9]+[smhdwy]\]' <<<"$query")

  # Recording-rule conventions often encode windows in metric names
  # (for example *_5m, *_1h, *_30d). Treat these as freshness hints.
  local hint token
  while IFS= read -r hint; do
    [[ -z "$hint" ]] && continue
    token="${hint#:}"
    token="${token#_}"
    minutes="$(to_minutes_from_range "[${token}]")"
    [[ -z "$minutes" ]] && continue
    if (( minutes <= max_minutes )); then
      return 0
    fi
  done < <(grep -oE '[_:][0-9]+[smhdwy]\b' <<<"$query")

  return 1
}

panel_is_non_data() {
  local title="$1"
  jq -e --arg t "$title" '
    [.. | objects | select(.title == $t and has("type")) | .type] as $types
    | ($types | length) > 0
      and ($types | all(. == "row" or . == "text" or . == "dashlist" or . == "news"))
  ' "$DASHBOARD_FILE" >/dev/null
}

check_panel_ownership_and_freshness() {
  local titles_file="$1"
  local panel_spec
  local title owner max_staleness query_file

  while IFS= read -r panel_spec; do
    [[ -z "$panel_spec" ]] && continue

    title="$(jq -r '.title // empty' <<<"$panel_spec")"
    owner="$(jq -r '.owner // empty' <<<"$panel_spec")"
    max_staleness="$(jq -r '.max_staleness_minutes // 0' <<<"$panel_spec")"

    if [[ -z "$title" ]]; then
      add_required_error "Contract panel spec missing title"
      continue
    fi

    if [[ -z "$owner" ]]; then
      add_required_error "Missing required panel owner in contract for: $title"
      continue
    fi

    if ! contains_exact_line "$title" "$titles_file"; then
      add_required_error "Missing required panel title: $title (contract metadata)"
      continue
    fi

    if panel_is_non_data "$title"; then
      continue
    fi

    query_file="$(mktemp -t panel-queries.XXXXXX)"
    jq -r --arg t "$title" '.. | objects | select(.title == $t and has("targets")) | .targets[]? | (.expr? // .query? // .rawSql? // empty)' "$DASHBOARD_FILE" >"$query_file"

    if [[ ! -s "$query_file" ]]; then
      add_required_error "Panel has no query payload in dashboard: $title"
      rm -f "$query_file"
      continue
    fi

    if [[ "$max_staleness" != "0" ]] && ! {
      while IFS= read -r tmp_q; do
        [[ -z "$tmp_q" ]] && continue
        query_freshness_window_met "$tmp_q" "$max_staleness" && break
      done <"$query_file"
    }; then
      add_required_error "Panel freshness check failed for '$title' (max_staleness_minutes=$max_staleness)"
    fi

    rm -f "$query_file"
  done < <(jq -c '.required.panels[]?' "$CONTRACT_FILE" 2>/dev/null || true)
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

run_catalog_audit() {
  local aggregate_required=0
  local aggregate_recommended=0
  local first=1

  [[ -f "$CATALOG_FILE" ]] || {
    echo "Dashboard catalog missing: $CATALOG_FILE" >&2
    exit 1
  }
  jq -e . "$CATALOG_FILE" >/dev/null || {
    echo "Invalid JSON in dashboard catalog: $CATALOG_FILE" >&2
    exit 1
  }

  local tmpdir
  tmpdir="$(mktemp -d -t audit-grafana-catalog.XXXXXX)"
  trap 'rm -rf "$tmpdir"' EXIT
  local results_file="${tmpdir}/results.jsonl"
  : >"$results_file"

  while IFS= read -r dashboard_spec; do
    [[ -n "$dashboard_spec" ]] || continue
    local key title uid dashboard_path contract_path abs_dashboard abs_contract child_json
    key="$(jq -r '.key // empty' <<<"$dashboard_spec")"
    title="$(jq -r '.title // empty' <<<"$dashboard_spec")"
    uid="$(jq -r '.uid // empty' <<<"$dashboard_spec")"
    dashboard_path="$(jq -r '.dashboard_file // empty' <<<"$dashboard_spec")"
    contract_path="$(jq -r '.contract_file // empty' <<<"$dashboard_spec")"
    abs_dashboard="$(resolve_repo_path "$dashboard_path")"
    abs_contract="$(resolve_repo_path "$contract_path")"

    if [[ -z "$key" || -z "$dashboard_path" || -z "$contract_path" ]]; then
      echo "Invalid dashboard catalog entry: ${dashboard_spec}" >&2
      exit 1
    fi

    child_json="$("$0" --dashboard-file "$abs_dashboard" --contract-file "$abs_contract" --json)"
    jq -c \
      --arg key "$key" \
      --arg title "$title" \
      --arg uid "$uid" \
      '. + {key: $key, title: $title, uid: $uid}' <<<"$child_json" >>"$results_file"
  done < <(jq -c '.dashboards[]?' "$CATALOG_FILE")

  if [[ ! -s "$results_file" ]]; then
    echo "Dashboard catalog has no dashboard entries: $CATALOG_FILE" >&2
    exit 1
  fi

  if jq -e 'select(.required_ok == false)' "$results_file" >/dev/null 2>&1; then
    aggregate_required=1
  fi
  if jq -e 'select(.recommended_ok == false)' "$results_file" >/dev/null 2>&1; then
    aggregate_recommended=1
  fi

  if [[ "$JSON_OUT" -eq 1 ]]; then
    jq -s \
      --arg catalog_file "$CATALOG_FILE" \
      '{
        mode: "catalog",
        catalog_file: $catalog_file,
        results: .,
        required_ok: (all(.[]; .required_ok == true)),
        recommended_ok: (all(.[]; .recommended_ok == true))
      }' "$results_file"
  else
    echo "=========================================="
    echo "Grafana Dashboard Coverage Audit"
    echo "=========================================="
    echo "catalog: ${CATALOG_FILE}"
    echo ""

    while IFS= read -r dashboard_result; do
      local status required_ok recommended_ok
      key="$(jq -r '.key' <<<"$dashboard_result")"
      title="$(jq -r '.title' <<<"$dashboard_result")"
      required_ok="$(jq -r '.required_ok' <<<"$dashboard_result")"
      recommended_ok="$(jq -r '.recommended_ok' <<<"$dashboard_result")"
      status="PASS"
      if [[ "$required_ok" != "true" ]]; then
        status="FAIL"
      elif [[ "$recommended_ok" != "true" ]]; then
        status="WARN"
      fi
      echo "[${status}] ${title} (${key})"
      jq -r '.required_errors[]? | "  - " + .' <<<"$dashboard_result"
      jq -r '.recommended_warnings[]? | "  - " + .' <<<"$dashboard_result"
      echo ""
    done <"$results_file"

    if [[ "$aggregate_required" -eq 0 ]]; then
      echo "Required checks: PASS"
    else
      echo "Required checks: FAIL"
    fi

    if [[ "$aggregate_recommended" -eq 0 ]]; then
      echo "Recommended checks: PASS"
    else
      echo "Recommended checks: WARN"
    fi
  fi

  if [[ "$STRICT_REQUIRED" -eq 1 && "$aggregate_required" -ne 0 ]]; then
    exit 1
  fi
  if [[ "$STRICT_RECOMMENDED" -eq 1 && "$aggregate_recommended" -ne 0 ]]; then
    exit 1
  fi

  exit 0
}

if [[ "$AUDIT_ALL" -eq 1 || ( "$EXPLICIT_SINGLE" -eq 0 && -f "$CATALOG_FILE" ) ]]; then
  run_catalog_audit
fi

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

  jq -r '.. | objects | (.title // empty)' "$DASHBOARD_FILE" | sed '/^$/d' | sort -u >"$titles_file"
  jq -r '
    [.. | objects | .datasource? // empty]
    | .[]
    | if type=="string" then
        if (. | test("^\\$\\{?DS_PROMETHEUS\\}?$")) then "prometheus" else . end
      elif type=="object" then
        if has("uid") and (.uid | test("^\\$\\{?DS_PROMETHEUS\\}?$")) then "prometheus" else (.uid // .type // "") end
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
  check_panel_ownership_and_freshness "$titles_file"
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
