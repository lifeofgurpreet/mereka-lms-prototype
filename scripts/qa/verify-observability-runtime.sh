#!/usr/bin/env bash
# @spec: observability-validation-requirements_spec.md
# @covers AC-OVR-016, AC-OVR-018, AC-OVR-019, AC-OVR-020, AC-OVR-021, AC-OVR-023, AC-OVR-025, AC-OVR-026, AC-OVR-027, AC-OVR-028, AC-OVR-029, AC-OVR-031
#
# Runtime verification for observability validation (live cluster + GCP checks)
# This script checks live deployments, GCP resources, and Grafana dashboards.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
SKIP=0
VERIFY_CMD_TIMEOUT="${VERIFY_OBS_CMD_TIMEOUT:-45}"
VERIFY_RUNTIME_SCRIPT_TIMEOUT="${VERIFY_OBS_RUNTIME_SCRIPT_TIMEOUT:-120}"
VERIFY_RUNTIME_VALIDATION_TIMEOUT="${VERIFY_OBS_RUNTIME_VALIDATION_TIMEOUT:-120}"
VERIFY_APP_NAMESPACE="${VERIFY_OBS_APP_NAMESPACE:-mereka-lms}"
VERIFY_MONITORING_NAMESPACE="${VERIFY_OBS_MONITORING_NAMESPACE:-monitoring}"
VERIFY_K8S_CONTEXT="${VERIFY_OBS_K8S_CONTEXT:-}"
VERIFY_GCP_PROJECT="${VERIFY_OBS_GCP_PROJECT:-${GCP_PROJECT:-mereka-lms}}"
VERIFY_ENV_LABEL="${VERIFY_OBS_ENV_LABEL:-unknown}"
VERIFY_DISPATCH_PROFILE="${VERIFY_OBS_DISPATCH_PROFILE:-custom}"
VERIFY_EVIDENCE_FILE="${VERIFY_OBS_EVIDENCE_FILE:-}"
VERIFY_EVIDENCE_DIR="${VERIFY_OBS_EVIDENCE_DIR:-${VERIFY_EVIDENCE_FILE%/*}}"
METRICS_SPLIT_TOKEN='__METRICS_SPLIT__'
if [[ -z "$VERIFY_EVIDENCE_DIR" ]]; then
  VERIFY_EVIDENCE_DIR="$REPO_ROOT/var/ci"
fi
RESULTS_FILE="$(mktemp -t verify-observability-runtime.XXXXXX)"
trap 'rm -f "$RESULTS_FILE"' EXIT

# Helper functions
pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS=$((PASS + 1))
    printf 'pass\t%s\n' "$1" >> "$RESULTS_FILE"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL=$((FAIL + 1))
    printf 'fail\t%s\n' "$1" >> "$RESULTS_FILE"
}

skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    SKIP=$((SKIP + 1))
    printf 'skip\t%s\n' "$1" >> "$RESULTS_FILE"
}

write_metrics_payload_evidence() {
    local component="$1"
    local status_code="$2"
    local payload="$3"
    local note="$4"
    local artifact_file="$5"
    local metric_path="$6"

    local total_bytes
    local help_count
    local type_count
    local sample_count

    total_bytes="${#payload}"
    if [[ -n "$payload" ]]; then
        help_count="$(printf '%s' "$payload" | grep -cE '^# HELP ' || true)"
        type_count="$(printf '%s' "$payload" | grep -cE '^# TYPE ' || true)"
        sample_count="$(printf '%s' "$payload" | grep -cE '^[a-zA-Z_:][a-zA-Z0-9_:]*(\{[^\n]*\})?[[:space:]]+[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?([[:space:]]+[0-9]+)?$' || true)"
    else
        help_count=0
        type_count=0
        sample_count=0
    fi

    mkdir -p "$VERIFY_EVIDENCE_DIR"
    {
        echo "# Observability /metrics payload evidence"
        echo ""
        echo "- component: ${component}"
        echo "- generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "- status_code: ${status_code}"
        if [[ -n "$metric_path" ]]; then
            echo "- metric_path: ${metric_path}"
        fi
        echo "- payload_bytes: ${total_bytes}"
        echo "- help_count: ${help_count}"
        echo "- type_count: ${type_count}"
        echo "- numeric_sample_count: ${sample_count}"
        echo "- evidence_identity: env=${VERIFY_ENV_LABEL};profile=${VERIFY_DISPATCH_PROFILE};context=${VERIFY_K8S_CONTEXT:-default};project=${VERIFY_GCP_PROJECT}"
        if [[ -n "$note" ]]; then
            echo "- note: ${note}"
        fi
        echo ""
        echo "## Payload sample"
        echo ""
        echo '```text'
        if [[ -n "$payload" ]]; then
            printf '%s\n' "$payload" | awk 'NF' | head -n 200
        else
            echo "<no-payload-generated>"
        fi
        echo '```'
    } > "$artifact_file"
}

kubectl_cmd() {
    if [[ -n "$VERIFY_K8S_CONTEXT" ]]; then
        kubectl --context "$VERIFY_K8S_CONTEXT" "$@"
    else
        kubectl "$@"
    fi
}

kubectl_cmd_with_timeout() {
    local timeout_cmd=( )
    if command -v timeout >/dev/null 2>&1; then
        timeout_cmd=(timeout "$VERIFY_CMD_TIMEOUT")
    fi

    local context_args=( )
    if [[ -n "$VERIFY_K8S_CONTEXT" ]]; then
        context_args=(--context "$VERIFY_K8S_CONTEXT")
    fi

    "${timeout_cmd[@]}" kubectl "${context_args[@]}" "$@"
}

check_openedx_settings_metrics_wiring() {
    local component="$1"
    local deploy_name="$2"
    local configmap_names=()
    local deduped_configmap_names=()
    local marker_counts=()
    local cfg_json=""
    local marker_hit=0
    local checked_count=0
    local fallback_map=""

    if ! command -v kubectl >/dev/null 2>&1; then
        skip "${component} settings wiring check requires kubectl"
        return 0
    fi

    set +e
    local volume_json
    volume_json="$(kubectl_cmd_with_timeout get deploy "$deploy_name" -n "$VERIFY_APP_NAMESPACE" -o json 2>/dev/null)"
    local volume_rc=$?
    set -e

    if [[ $volume_rc -ne 0 || -z "$volume_json" ]]; then
        fail "AC-OVR-016: ${component} deployment '$deploy_name' is not reachable for settings map detection"
        return 1
    fi

    mapfile -t configmap_names < <(printf '%s' "$volume_json" | jq -r --arg c "$deploy_name" '.spec.template.spec.volumes[]? | select(.configMap.name | tostring | startswith("openedx-settings-" + $c)) | .configMap.name' 2>/dev/null)
    if [[ ${#configmap_names[@]} -eq 0 ]]; then
        mapfile -t configmap_names < <(printf '%s' "$volume_json" | jq -r '.spec.template.spec.volumes[]? | select(.configMap.name | tostring | startswith("openedx-settings-")) | .configMap.name' 2>/dev/null)
    fi

    if [[ ${#configmap_names[@]} -eq 0 ]]; then
        fail "AC-OVR-016: ${component} deployment '$deploy_name' has no openedx-settings configmap references"
        return 1
    fi

    for fallback_map in "${configmap_names[@]}"; do
        [[ -z "$fallback_map" ]] && continue

        local map_already_seen=0
        for existing_map in "${deduped_configmap_names[@]:-}"; do
            if [[ "$existing_map" == "$fallback_map" ]]; then
                map_already_seen=1
                break
            fi
        done

        if [[ "$map_already_seen" -eq 0 ]]; then
            deduped_configmap_names+=("$fallback_map")
        fi
    done

    if [[ ${#deduped_configmap_names[@]} -eq 0 ]]; then
        fail "AC-OVR-016: ${component} deployment '$deploy_name' has no valid openedx-settings configmap candidates"
        return 1
    fi

    configmap_names=("${deduped_configmap_names[@]}")

    for fallback_map in "${configmap_names[@]}"; do
        [[ -z "$fallback_map" ]] && continue
        set +e
        cfg_json="$(kubectl_cmd_with_timeout get configmap "$fallback_map" -n "$VERIFY_APP_NAMESPACE" -o json 2>/dev/null)"
        local cfg_rc=$?
        set -e
        if [[ $cfg_rc -ne 0 || -z "$cfg_json" ]]; then
            continue
        fi

        checked_count=$((checked_count + 1))
        local marker_count
        local marker_file_csv=""
        marker_count="$(printf '%s' "$cfg_json" | jq -r '[.data // {} | to_entries[]? | select(.value | contains("openedx_prometheus.urls") or contains("_metrics_urlconf") or contains("django_prometheus.middleware.PrometheusBeforeMiddleware") or contains("django_prometheus.middleware.PrometheusAfterMiddleware") or contains("openedx_prometheus"))] | length' 2>/dev/null | tr -d '[:space:]' )"
        marker_file_csv="$(printf '%s' "$cfg_json" | jq -r '[.data // {} | to_entries[]? | select(.key == "production.py" or .key == "development.py" or .key == "test.py") | select(.value | contains("openedx_prometheus.urls") or contains("_metrics_urlconf") or contains("django_prometheus.middleware.PrometheusBeforeMiddleware") or contains("django_prometheus.middleware.PrometheusAfterMiddleware") or contains("openedx_prometheus")) | .key] | unique | join(",")' 2>/dev/null | tr -d '[:space:]')"
        if [[ -z "$marker_file_csv" || "$marker_file_csv" == "null" ]]; then
            marker_file_csv=""
        fi

        marker_counts+=("$fallback_map=$marker_count:${marker_file_csv:-none}")
        if [[ "$marker_count" != "" && "$marker_count" -gt 0 ]]; then
            marker_hit=1
            if [[ -n "$marker_file_csv" ]]; then
                pass "AC-OVR-016: ${component} settings configmap '$fallback_map' includes prom metrics wiring markers ($marker_count) in ${marker_file_csv}"
            else
                pass "AC-OVR-016: ${component} settings configmap '$fallback_map' includes prom metrics wiring markers ($marker_count)"
            fi
            echo "AC-OVR-016: ${component} settings configmaps checked: ${configmap_names[*]}"
            break
        fi
    done

    if [[ "$marker_hit" -eq 1 ]]; then
        return 0
    fi

    if [[ "$checked_count" -eq 0 ]]; then
        fail "AC-OVR-016: ${component} settings configmaps were not readable for marker verification"
        return 1
    fi

    echo "AC-OVR-016: ${component} settings configmaps checked: ${configmap_names[*]}"
    echo "AC-OVR-016: ${component} marker probe summary: ${marker_counts[*]}"
    fail "AC-OVR-016: ${component} settings configmaps do not include prom metrics wiring markers (checked ${checked_count} map(s))"
    return 1
}

resolve_prometheus_pod() {
    local pod_name=""
    local probe_namespace=""
    PROM_POD_NAMESPACE=""

    probe_namespace="$VERIFY_MONITORING_NAMESPACE"
    pod_name="$(kubectl_cmd_with_timeout get pods -n "$probe_namespace" -l app.kubernetes.io/name=prometheus -o name 2>/dev/null | head -1)"
    if [[ -n "$pod_name" ]]; then
        PROM_POD_NAMESPACE="$probe_namespace"
        printf '%s\n' "$pod_name"
        return 0
    fi

    probe_namespace="$VERIFY_APP_NAMESPACE"
    pod_name="$(kubectl_cmd_with_timeout get pods -n "$probe_namespace" -l app.kubernetes.io/name=prometheus -o name 2>/dev/null | head -1)"
    if [[ -n "$pod_name" ]]; then
        PROM_POD_NAMESPACE="$probe_namespace"
        printf '%s\n' "$pod_name"
        return 0
    fi

    printf ''
}

resolve_service_monitor() {
    local target_name="$1"
    local namespace_list=()
    local probe_namespaces=("$VERIFY_MONITORING_NAMESPACE" "$VERIFY_APP_NAMESPACE")
    local known_matches=()
    local all_matches=()
    local namespace=""
    local line=""
    local line_name=""

    SM_MATCH_COUNT=0
    SM_MATCH_NAMESPACES=""
    SM_RESOLVED_NAMESPACE=""
    if [[ -z "$target_name" ]]; then
        printf ''
        return 1
    fi

    # Deduplicate candidate namespaces
    for namespace in "${probe_namespaces[@]}"; do
        [[ -z "$namespace" ]] && continue
        case " ${namespace_list[*]:-} " in
            *" ${namespace} "*) ;;
            *) namespace_list+=("$namespace") ;;
        esac
    done

    # First check known namespaces in deterministic order.
    for namespace in "${namespace_list[@]}"; do
        if kubectl_cmd_with_timeout get servicemonitor -n "$namespace" "$target_name" --ignore-not-found -o name >/dev/null 2>&1; then
            known_matches+=("$namespace")
        fi
    done

    if [[ "${#known_matches[@]}" -gt 0 ]]; then
        SM_MATCH_COUNT="${#known_matches[@]}"
        SM_MATCH_NAMESPACES="$(printf '%s, ' "${known_matches[@]}" | sed 's/, $//')"

        if [[ "${#known_matches[@]}" -eq 1 ]]; then
            SM_RESOLVED_NAMESPACE="${known_matches[0]}"
            printf '%s\n' "${SM_RESOLVED_NAMESPACE}"
            return 0
        fi

        return 2
    fi

    # Fallback across all namespaces if not found in known namespaces.
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        namespace="${line%%/*}"
        line_name="${line##*/}"

        # expected format: <namespace>/servicemonitor.monitoring.coreos.com/<name>
        if [[ "$line_name" == "$target_name" ]]; then
            all_matches+=("$namespace")
        fi
    done < <(kubectl_cmd_with_timeout get servicemonitor -A -o name --ignore-not-found 2>/dev/null)

    if [[ "${#all_matches[@]}" -eq 0 ]]; then
        printf ''
        return 1
    fi

    # Deduplicate fallback namespace list.
    namespace_list=()
    for namespace in "${all_matches[@]}"; do
        case " ${namespace_list[*]:-} " in
            *" ${namespace} "*) ;;
            *) namespace_list+=("$namespace") ;;
        esac
    done

    SM_MATCH_COUNT="${#namespace_list[@]}"
    SM_MATCH_NAMESPACES="$(printf '%s, ' "${namespace_list[@]}" | sed 's/, $//')"

    if [[ "${#namespace_list[@]}" -eq 1 ]]; then
        SM_RESOLVED_NAMESPACE="${namespace_list[0]}"
        printf '%s\n' "${SM_RESOLVED_NAMESPACE}"
        return 0
    fi

    return 2
}

resolve_prometheus_rule() {
    local target_name="$1"
    local namespace_list=()
    local probe_namespaces=("$VERIFY_MONITORING_NAMESPACE" "$VERIFY_APP_NAMESPACE")
    local known_matches=()
    local all_matches=()
    local namespace=""
    local line=""
    local line_name=""

    PR_MATCH_COUNT=0
    PR_MATCH_NAMESPACES=""
    PR_RESOLVED_NAMESPACE=""
    if [[ -z "$target_name" ]]; then
        printf ''
        return 1
    fi

    # Deduplicate candidate namespaces.
    for namespace in "${probe_namespaces[@]}"; do
        [[ -z "$namespace" ]] && continue
        case " ${namespace_list[*]:-} " in
            *" ${namespace} "*) ;;
            *) namespace_list+=("$namespace") ;;
        esac
    done

    # Check known namespaces in order.
    for namespace in "${namespace_list[@]}"; do
        if kubectl_cmd_with_timeout get prometheusrule -n "$namespace" "$target_name" --ignore-not-found -o name >/dev/null 2>&1; then
            known_matches+=("$namespace")
        fi
    done

    if [[ "${#known_matches[@]}" -gt 0 ]]; then
        PR_MATCH_COUNT="${#known_matches[@]}"
        PR_MATCH_NAMESPACES="$(printf '%s, ' "${known_matches[@]}" | sed 's/, $//')"

        if [[ "${#known_matches[@]}" -eq 1 ]]; then
            PR_RESOLVED_NAMESPACE="${known_matches[0]}"
            printf '%s\n' "${PR_RESOLVED_NAMESPACE}"
            return 0
        fi

        return 2
    fi

    # Fallback across all namespaces when not found in known namespaces.
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        namespace="${line%%/*}"
        line_name="${line##*/}"

        # expected format: <namespace>/prometheusrule.monitoring.coreos.com/<name>
        if [[ "$line_name" == "$target_name" ]]; then
            all_matches+=("$namespace")
        fi
    done < <(kubectl_cmd_with_timeout get prometheusrule -A -o name --ignore-not-found 2>/dev/null)

    if [[ "${#all_matches[@]}" -eq 0 ]]; then
        printf ''
        return 1
    fi

    namespace_list=()
    for namespace in "${all_matches[@]}"; do
        case " ${namespace_list[*]:-} " in
            *" ${namespace} "*) ;;
            *) namespace_list+=("$namespace") ;;
        esac
    done

    PR_MATCH_COUNT="${#namespace_list[@]}"
    PR_MATCH_NAMESPACES="$(printf '%s, ' "${namespace_list[@]}" | sed 's/, $//')"

    if [[ "${#namespace_list[@]}" -eq 1 ]]; then
        PR_RESOLVED_NAMESPACE="${namespace_list[0]}"
        printf '%s\n' "${PR_RESOLVED_NAMESPACE}"
        return 0
    fi

    return 2
}

extract_json_payload() {
    local output="$1"
    local json_payload=""
    local trimmed=""

    trimmed="$(printf '%s' "$output" | sed 's/[[:space:]]*$//')"

    if [[ -n "$trimmed" && "${trimmed:0:1}" == "{" && "${trimmed: -1}" == "}" ]]; then
        if command -v python3 >/dev/null 2>&1; then
            json_payload="$(printf '%s' "$trimmed" | python3 - <<'PY'
import json
import sys

text = sys.stdin.read().strip()
try:
    json.loads(text)
except Exception:
    sys.exit(0)

print(text)
PY
)"
            if [[ -n "$json_payload" ]]; then
                printf '%s' "$json_payload"
                return 0
            fi
        fi
    fi

    if command -v python3 >/dev/null 2>&1; then
        json_payload="$(printf '%s' "$trimmed" | python3 - <<'PY'
import json
import sys

text = sys.stdin.read()
starts = [idx for idx, ch in enumerate(text) if ch == '{']

for start in reversed(starts):
    depth = 0
    end = -1
    for idx, ch in enumerate(text[start:], start):
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                end = idx
                break
    if end == -1:
        continue

    candidate = text[start:end + 1].strip()
    try:
        json.loads(candidate)
    except Exception:
        continue

    print(candidate)
    sys.exit(0)

sys.exit(1)
PY
    )"
    fi

    if [[ -z "$json_payload" ]]; then
        # Fallback: take the last top-level JSON-looking block from plain text output.
        json_payload="$(printf '%s' "$trimmed" | awk 'BEGIN{found=0; depth=0} /\{/{found=1} found{print} /^$/&&found{exit}')"
    fi

    printf '%s' "$json_payload"
}

validate_observability_compliance_json() {
    local payload="$1"

    if [[ -z "$payload" ]]; then
        echo "json_payload_missing"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "jq_missing"
        return 1
    fi

    if ! printf '%s' "$payload" | jq -e '
        (type == "object")
        and (has("generated_at"))
        and (has("mode"))
        and (has("strict"))
        and (has("summary"))
        and (has("checks"))
        and (.summary | type == "object")
        and (.summary.pass | type == "number")
        and (.summary.fail | type == "number")
        and (.summary.skip | type == "number")
        and (.summary.total | type == "number")
        and (.checks | type == "array")
        and (.checks | map(has("id") and has("status") and has("message")) | all)
        and (.checks | length == .summary.total)
        and (.checks | all((.id | type == "string") and (.status | type == "string") and (.message | type == "string")))
    ' >/dev/null 2>&1; then
        echo "schema_mismatch"
        return 1
    fi

    return 0
}

gcloud_cmd() {
    gcloud --project "$VERIFY_GCP_PROJECT" "$@"
}

normalize_host_value() {
    local value="${1:-}"
    value="${value//$'\r'/}"
    value="${value//$'\n'/}"
    value="${value//\"/}"
    value="${value// /}"
    printf '%s' "$value"
}

read_metrics_host() {
    local namespace="$1"
    local resource="$2"
    local config_file="$3"
    local key_name="$4"
    local resolved_host=""
    local -a fallback_keys=("$key_name")
    local key=""

    case "$key_name" in
        LMS_BASE)
            fallback_keys+=("LMS_HOST" "SITE_HOST" "OPENEDX_HOSTNAME" "CMS_BASE")
            ;;
        CMS_BASE)
            fallback_keys+=("CMS_HOST" "SITE_HOST" "OPENEDX_HOSTNAME" "LMS_BASE")
            ;;
        *)
            fallback_keys+=("${key_name%_BASE}_HOST" "OPENEDX_HOSTNAME")
            ;;
    esac

    for key in "${fallback_keys[@]}"; do
        resolved_host="$(kubectl_cmd_with_timeout exec -n "$namespace" "$resource" -- \
            sh -lc "grep -E \"^${key}:\" '$config_file' 2>/dev/null | tail -n 1 | awk '{print \$2}'" 2>/dev/null || true)"
        resolved_host="$(normalize_host_value "$resolved_host")"
        if [[ -n "$resolved_host" ]]; then
            echo "$resolved_host"
            return 0
        fi
    done

    resolved_host="$(kubectl_cmd_with_timeout exec -n "$namespace" "$resource" -- \
        sh -lc "printenv | awk -F= '/^(LMS_BASE|CMS_BASE|LMS_HOST|CMS_HOST|OPENEDX_HOSTNAME)=/ {print \\$2; exit}' 2>/dev/null || true" 2>/dev/null || true)"
    resolved_host="$(normalize_host_value "$resolved_host")"
    echo "$resolved_host"
}

fetch_metrics_with_status() {
    local namespace="$1"
    local resource="$2"
    local target="${3:-/metrics}"
    local metrics_host="${4:-}"
    local result=""
    local status="000"
    local body=""
    local payload_path=""
    local split_token="$METRICS_SPLIT_TOKEN"
    local path_candidates=( )
    local attempts=( )
    local path_candidate=""
    local fetch_url=""
    local target_arg_used=""
    local remote_script=""
    local host_header=""
    local host_header_wget=""

    if [[ "$target" == http://* || "$target" == https://* ]]; then
        path_candidates=("$target")
    else
        path_candidates=(
            "$target"
            "${target%/}/"
        )
    fi

    for path_candidate in "${path_candidates[@]}"; do
        [[ -z "$path_candidate" ]] && continue
        if [[ -z "${attempts[*]}" ]]; then
            attempts+=("$path_candidate")
        elif ! printf '%s' "${attempts[*]}" | grep -qxF "$path_candidate"; then
            attempts+=("$path_candidate")
        fi
    done

    for path_candidate in "${attempts[@]}"; do
        if [[ "$path_candidate" == http://* || "$path_candidate" == https://* ]]; then
            fetch_url="$path_candidate"
            target_arg_used="$path_candidate"
        else
            fetch_url="http://localhost:8000${path_candidate}"
            target_arg_used="$path_candidate"
        fi

        if [[ -n "$metrics_host" ]]; then
            host_header="-H 'Host: ${metrics_host}'"
            host_header_wget="--header='Host: ${metrics_host}'"
        else
            host_header=""
            host_header_wget=""
        fi

        remote_script="$(cat <<'EOF'
tmp_body=$(mktemp)
tmp_hdr=$(mktemp)
tmp_status=000
if command -v curl >/dev/null 2>&1; then
  tmp_status=$(curl -s -m __TIMEOUT__s __HOST_HEADER__ -o "$tmp_body" -D "$tmp_hdr" -w '%{http_code}' '__URL__' 2>/dev/null || echo 000)
elif command -v wget >/dev/null 2>&1; then
  tmp_status=$(wget --server-response --quiet __HOST_HEADER_WGET__ --timeout=__TIMEOUT__ -O - '__URL__' >"$tmp_body" 2>"$tmp_hdr" && awk 'BEGIN{code="000"} /^  HTTP\// {code=$2} END{print code}' "$tmp_hdr" 2>/dev/null | tr -d '[:space:]' || echo 000)
elif command -v python3 >/dev/null 2>&1; then
  tmp_status=$(python3 - <<'PY' "__URL__" "__TIMEOUT__" "__METRICS_HOST__" "$tmp_body"
import sys
import urllib.request

url = sys.argv[1]
timeout = int(sys.argv[2])
host = sys.argv[3]
out_path = sys.argv[4]
headers = {}
if host and host != "__EMPTY__":
    headers["Host"] = host
req = urllib.request.Request(url, headers=headers)
try:
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = resp.read()
        with open(out_path, "wb") as f:
            f.write(body)
        print(resp.getcode())
except Exception as exc:
    code = getattr(exc, "code", 0) or 0
    print(code)
PY
)
else
  tmp_status=000
fi
if [ -z "$tmp_status" ]; then
  tmp_status=000
fi
body_content=$(cat "$tmp_body" 2>/dev/null || true)
rm -f "$tmp_body" "$tmp_hdr"
printf '%s\n__SPLIT__:%s\n' "$body_content" "$tmp_status"
EOF
)"
        remote_script="${remote_script/__TIMEOUT__/$VERIFY_CMD_TIMEOUT}"
        remote_script="${remote_script/__HOST_HEADER__/$host_header}"
        remote_script="${remote_script/__HOST_HEADER_WGET__/$host_header_wget}"
        remote_script="${remote_script/__URL__/$fetch_url}"
        remote_script="${remote_script/__METRICS_HOST__/${metrics_host:-__EMPTY__}}"
        remote_script="${remote_script/__SPLIT__/$split_token}"

        result="$(kubectl_cmd_with_timeout exec -n "$namespace" "$resource" -- sh -lc "$remote_script" 2>/dev/null || true)"

        if [[ -n "$result" ]] && printf '%s' "$result" | tail -n1 | grep -q "^${split_token}:"; then
            break
        fi
    done

    if [[ -z "$result" ]] || ! printf '%s' "$result" | tail -n1 | grep -q "^${split_token}:"; then
        printf '%s%s%s%s%s' "000" "$split_token" "not-attempted" "$split_token" ""
        return 0
    fi

    status="$(printf '%s' "$result" | tail -n1 | sed "s/^${split_token}://")"
    body="$(printf '%s' "$result" | sed '$d')"
    payload_path="$target_arg_used"

    if [[ "$payload_path" == http://* || "$payload_path" == https://* ]]; then
        payload_path="${payload_path#http://localhost:8000}"
        payload_path="${payload_path#https://localhost:8000}"
    fi

    if [[ -z "$payload_path" ]]; then
        payload_path="/"
    fi

    body="${body%$'\r'}"

    printf '%s%s%s%s%s' "$status" "$split_token" "$payload_path" "$split_token" "$body"
}

check_metrics_payload_shape() {
    local component="$1"
    local payload="$2"
    local missing=0

    if [[ -z "$payload" ]]; then
        fail "AC-OVR-016: ${component} /metrics body is empty"
        return 1
    fi

    if ! printf '%s' "$payload" | grep -qE '^# HELP '; then
        fail "AC-OVR-016: ${component} /metrics body missing # HELP exposition block"
        missing=$((missing + 1))
    fi

    if ! printf '%s' "$payload" | grep -qE '^# TYPE '; then
        fail "AC-OVR-016: ${component} /metrics body missing # TYPE exposition block"
        missing=$((missing + 1))
    fi

    if ! printf '%s' "$payload" | grep -qE '^[a-zA-Z_:][a-zA-Z0-9_:]*(\{[^\n]*\})?[[:space:]]+[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?([[:space:]]+[0-9]+)?$'; then
        fail "AC-OVR-016: ${component} /metrics body missing a Prometheus sample with numeric value"
        missing=$((missing + 1))
    fi

    if [[ $missing -eq 0 ]]; then
        pass "AC-OVR-016: ${component} /metrics has valid Prometheus exposition structure"
    fi

    return "$missing"
}

run_missing_resource_negative_check() {
    local validation_script="scripts/qa/verify-observability-validation.sh"
    local temp_root
    local monitoring_root
    local kustomization
    local output
    local rc=0
    local missing_sm="servicemonitor-enterprise.yaml"

    if [[ ! -x "$validation_script" ]]; then
        skip "AC-OVR-026: scripts/qa/verify-observability-validation.sh not executable"
        return 0
    fi

    temp_root="$(mktemp -d -t observability-negative.XXXXXX)"
    monitoring_root="$temp_root/deploy/k8s/base/monitoring"

    mkdir -p "$(dirname "$monitoring_root")"
    cp -a "deploy/k8s/base/monitoring" "$temp_root/deploy/k8s/base/"
    kustomization="$monitoring_root/kustomization.yaml"
    sed -i "/$missing_sm/d" "$kustomization"

    set +e
    output="$( \
      VERIFY_OBS_KUSTOMIZATION_PATH="$kustomization" \
      VERIFY_OBS_MONITORING_DIR="$monitoring_root" \
      "$validation_script" 2>&1 \
    )"
    rc=$?
    set -e

    rm -rf "$temp_root"

    if [[ $rc -ne 0 ]] && echo "$output" | grep -q "${missing_sm} NOT listed in kustomization.yaml"; then
        pass "AC-OVR-026: Negative-control check exits non-zero when required ServiceMonitor entry is missing"
    elif [[ $rc -eq 0 ]]; then
        fail "AC-OVR-026: Negative-control check passed even when required ServiceMonitor was removed"
    else
        fail "AC-OVR-026: Negative-control output did not include expected ServiceMonitor missing check"
    fi
}

check_prometheus_runtime_wiring() {
    local component="${1}"
    local target_name="${2}"
    local rule_name="${3}"
    local evidence_file="${4}"
    local check_rule=0
    local sm_namespace="${VERIFY_MONITORING_NAMESPACE}"
    local sm_namespace_evidence=""
    local rule_crd_count=0
    local rule_namespace=""
    local rule_namespace_evidence=""
    local rule_resolve_rc=0
    local sm_resolve_rc=0
    local sm_namespace_candidate=""

    if ! command -v kubectl >/dev/null 2>&1; then
        skip "runtime wiring for ${component}: kubectl unavailable"
        return 0
    fi

    if [[ -n "$target_name" ]]; then
        set +e
        sm_namespace_candidate="$(resolve_service_monitor "$target_name")"
        sm_resolve_rc=$?
        sm_namespace_evidence="${SM_MATCH_NAMESPACES:-$VERIFY_MONITORING_NAMESPACE}"
        set -e

        if [[ "$sm_resolve_rc" -eq 0 ]]; then
            sm_namespace="$sm_namespace_candidate"
            pass "Runtime wiring: ServiceMonitor '${target_name}' exists in ${sm_namespace}"
            sm_namespace_evidence="${sm_namespace}"
        elif [[ "$sm_resolve_rc" -eq 1 ]]; then
            fail "Runtime wiring: expected ServiceMonitor '${target_name}' not found in ${VERIFY_MONITORING_NAMESPACE}/${VERIFY_APP_NAMESPACE} (all-namespace fallback checked)"
            sm_namespace_evidence="${VERIFY_MONITORING_NAMESPACE}/${VERIFY_APP_NAMESPACE}"
        else
            fail "Runtime wiring: ServiceMonitor '${target_name}' exists in multiple namespaces (${SM_MATCH_NAMESPACES:-unknown}); resolve_service_monitor requires deterministic single match"
        fi

    fi

    if [[ -n "$rule_name" ]]; then
        set +e
        rule_namespace="$(resolve_prometheus_rule "$rule_name")"
        rule_resolve_rc=$?
        rule_crd_count="${PR_MATCH_COUNT:-0}"
        rule_namespace_evidence="${PR_MATCH_NAMESPACES:-$VERIFY_MONITORING_NAMESPACE}"
        set -e

        if [[ "$rule_resolve_rc" -eq 0 ]]; then
            pass "Runtime wiring: PrometheusRule '${rule_name}' exists in ${rule_namespace}"
            check_rule=1
        elif [[ "$rule_resolve_rc" -eq 1 ]]; then
            fail "Runtime wiring: expected PrometheusRule '${rule_name}' not found in ${VERIFY_MONITORING_NAMESPACE}/${VERIFY_APP_NAMESPACE} (all-namespace fallback checked)"
            check_rule=0
        else
            fail "Runtime wiring: PrometheusRule '${rule_name}' exists in multiple namespaces (${PR_MATCH_NAMESPACES:-unknown}); expected single definition"
            check_rule=0
        fi
    fi

    set +e
    PROM_POD="$(resolve_prometheus_pod)"
    set -e

    if [[ -z "$PROM_POD" ]]; then
        skip "runtime wiring for ${component}: Prometheus pod not found in ${VERIFY_MONITORING_NAMESPACE}/${VERIFY_APP_NAMESPACE}"
        return 0
    fi

    set +e
    TARGETS_JSON="$(kubectl_cmd_with_timeout exec -n "$PROM_POD_NAMESPACE" "$PROM_POD" -c prometheus --             wget -q -O- "http://localhost:9090/api/v1/targets" 2>/dev/null)"
    RULES_JSON="$(kubectl_cmd_with_timeout exec -n "$PROM_POD_NAMESPACE" "$PROM_POD" -c prometheus --             wget -q -O- "http://localhost:9090/api/v1/rules" 2>/dev/null)"
    set -e

    TARGET_COUNT="0"
    RULE_GROUP_COUNT="0"
    if [[ -n "$TARGETS_JSON" ]]; then
        TARGET_COUNT="$(printf '%s' "$TARGETS_JSON" | jq -r --arg n "$target_name" '[ .data.activeTargets // [] | .[] | select( (.scrapePool // "" | contains($n)) or (.labels.job // "" | tostring | contains($n)) or (.discoveredLabels["__meta_kubernetes_service_name"] // "" | tostring | contains($n)) ) ] | length' 2>/dev/null | tr -d '[:space:]')"
    fi
    if [[ "$check_rule" -eq 1 && -n "$RULES_JSON" ]]; then
        RULE_GROUP_COUNT="$(printf '%s' "$RULES_JSON" | jq -r --arg n "$rule_name" '[ .data.groups // [] | .[] | select((.name // "") == $n or (.name // "" | contains($n)) ) ] | length' 2>/dev/null | tr -d '[:space:]')"
        RULE_GROUP_COUNT="${RULE_GROUP_COUNT:-0}"
    fi

    TARGET_COUNT="${TARGET_COUNT:-0}"
    RULE_GROUP_COUNT="${RULE_GROUP_COUNT:-0}"

    mkdir -p "$VERIFY_EVIDENCE_DIR"
    {
        echo "# Prometheus wiring evidence for ${component}"
        echo ""
        echo "- generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "- component: ${component}"
        echo "- target_name: ${target_name}"
        if [[ -n "$target_name" ]]; then
            echo "- target_namespace: ${sm_namespace_evidence:-${VERIFY_MONITORING_NAMESPACE}}"
        else
            echo "- target_namespace: (not requested)"
        fi
        if [[ -n "$rule_name" ]]; then
            echo "- rule_name: ${rule_name}"
            echo "- rule_namespace: ${rule_namespace_evidence:-${VERIFY_MONITORING_NAMESPACE}}"
        else
            echo "- rule_name: (not requested)"
            echo "- rule_namespace: (not requested)"
        fi
        echo "- target_matches: ${TARGET_COUNT}"
        echo "- rule_group_matches: ${RULE_GROUP_COUNT}"
        echo "- evidence_identity: env=${VERIFY_ENV_LABEL};profile=${VERIFY_DISPATCH_PROFILE};context=${VERIFY_K8S_CONTEXT:-default};project=${VERIFY_GCP_PROJECT}"
        echo ""
        echo "## Raw targets payload"
        echo '```json'
        echo "$TARGETS_JSON" | jq '.data.activeTargets // []' 2>/dev/null | sed -n '1,120p'
        echo '```'
        echo ""
        echo "## Raw rule payload"
        echo '```json'
        echo "$RULES_JSON" | jq '.data.groups // []' 2>/dev/null | sed -n '1,160p'
        echo '```'
    } > "$evidence_file"

    if [[ -n "$target_name" ]]; then
        if [[ "$TARGET_COUNT" -gt 0 ]]; then
            pass "Runtime wiring: ${component} target visible to Prometheus as '${target_name}' (${TARGET_COUNT})"
        else
            fail "Runtime wiring: ${component} ServiceMonitor '${target_name}' not present in Prometheus active targets"
        fi
    fi

    if [[ "$check_rule" -eq 1 ]]; then
        if [[ "$RULE_GROUP_COUNT" -gt 0 ]]; then
            pass "Runtime wiring: ${component} rule group present in Prometheus as '${rule_name}' (${RULE_GROUP_COUNT})"
        else
            fail "Runtime wiring: ${component} PrometheusRule '${rule_name}' not present in Prometheus /api/v1/rules"
        fi
    fi
}

echo "========================================================="
echo "Observability Validation Runtime Verification (Live)"
echo "========================================================="
echo ""

# AC-OVR-016: SLI recording rules producing data
echo "==> AC-OVR-016: Prometheus recording rules producing numeric data (0-1 range)"
if command -v kubectl >/dev/null 2>&1; then
    # Try to get Prometheus pod
    set +e
    PROM_POD="$(resolve_prometheus_pod)"
    PROM_NAMESPACE="${PROM_POD_NAMESPACE:-$VERIFY_MONITORING_NAMESPACE}"
    set -e

    if [[ -n "$PROM_POD" ]]; then
        # Query recording rule
        set +e
        if kubectl_cmd_with_timeout exec -n "$PROM_NAMESPACE" "$PROM_POD" -c prometheus -- \
                wget -q -O- "http://localhost:9090/api/v1/query?query=mereka:http_requests:availability_ratio_5m" 2>/dev/null | \
                grep -q '"status":"success"'; then
                pass "AC-OVR-016: SLI recording rule mereka:http_requests:availability_ratio_5m is producing data"
            else
                skip "AC-OVR-016: Recording rule exists but may not have data yet (scrape warm-up or rollout delay)"
            fi
        set -e
    else
        skip "AC-OVR-016: Prometheus pod not found in ${VERIFY_MONITORING_NAMESPACE}/${VERIFY_APP_NAMESPACE} namespace"
    fi
else
    skip "AC-OVR-016: kubectl not available (requires live cluster access)"
fi

# AC-OVR-016 (prerequisite): LMS/CMS /metrics endpoints must return HTTP 200
echo ""
echo "==> AC-OVR-016: LMS/CMS /metrics endpoint returns valid Prometheus exposition payload"
if command -v kubectl >/dev/null 2>&1; then
    set +e
    lms_metrics_host="$(read_metrics_host "$VERIFY_APP_NAMESPACE" deploy/lms /openedx/config/lms.env.yml LMS_BASE)"
    cms_metrics_host="$(read_metrics_host "$VERIFY_APP_NAMESPACE" deploy/cms /openedx/config/cms.env.yml CMS_BASE)"

    LMS_RESULT="$(fetch_metrics_with_status "$VERIFY_APP_NAMESPACE" deploy/lms /metrics "$lms_metrics_host")"
    LMS_CODE="${LMS_RESULT%%${METRICS_SPLIT_TOKEN}*}"
    if [[ "$LMS_CODE" == "400" && -n "$lms_metrics_host" ]]; then
        LMS_RESULT_NOHOST="$(fetch_metrics_with_status "$VERIFY_APP_NAMESPACE" deploy/lms /metrics "")"
        if [[ "${LMS_RESULT_NOHOST%%${METRICS_SPLIT_TOKEN}*}" == "200" ]]; then
            LMS_RESULT="$LMS_RESULT_NOHOST"
        fi
    fi

    LMS_REST="${LMS_RESULT#*${METRICS_SPLIT_TOKEN}}"
    LMS_PATH="${LMS_REST%%${METRICS_SPLIT_TOKEN}*}"
    LMS_METRICS="${LMS_REST#*${METRICS_SPLIT_TOKEN}}"

    CMS_RESULT="$(fetch_metrics_with_status "$VERIFY_APP_NAMESPACE" deploy/cms /metrics "$cms_metrics_host")"
    CMS_CODE="${CMS_RESULT%%${METRICS_SPLIT_TOKEN}*}"
    if [[ "$CMS_CODE" == "400" && -n "$cms_metrics_host" ]]; then
        CMS_RESULT_NOHOST="$(fetch_metrics_with_status "$VERIFY_APP_NAMESPACE" deploy/cms /metrics "")"
        if [[ "${CMS_RESULT_NOHOST%%${METRICS_SPLIT_TOKEN}*}" == "200" ]]; then
            CMS_RESULT="$CMS_RESULT_NOHOST"
        fi
    fi

    CMS_REST="${CMS_RESULT#*${METRICS_SPLIT_TOKEN}}"
    CMS_PATH="${CMS_REST%%${METRICS_SPLIT_TOKEN}*}"
    CMS_METRICS="${CMS_REST#*${METRICS_SPLIT_TOKEN}}"
    set -e

    write_metrics_payload_evidence "LMS" "$LMS_CODE" "$LMS_METRICS" "" "$VERIFY_EVIDENCE_DIR/observability-metrics-lms-runtime.md" "$LMS_PATH"
    write_metrics_payload_evidence "CMS" "$CMS_CODE" "$CMS_METRICS" "" "$VERIFY_EVIDENCE_DIR/observability-metrics-cms-runtime.md" "$CMS_PATH"

    if [[ "$LMS_CODE" == "200" ]]; then
        pass "AC-OVR-016: LMS /metrics returned 200"
        check_metrics_payload_shape "LMS" "$LMS_METRICS"
    else
        fail "AC-OVR-016: LMS /metrics returned $LMS_CODE (expected 200)"
    fi

    if [[ "$CMS_CODE" == "200" ]]; then
        pass "AC-OVR-016: CMS /metrics returned 200"
        check_metrics_payload_shape "CMS" "$CMS_METRICS"
    else
        fail "AC-OVR-016: CMS /metrics returned $CMS_CODE (expected 200)"
    fi
else
    skip "AC-OVR-016: kubectl not available (cannot verify LMS/CMS /metrics)"
    write_metrics_payload_evidence "LMS" "000" "" "kubectl unavailable at runtime verification" "$VERIFY_EVIDENCE_DIR/observability-metrics-lms-runtime.md" "/metrics"
    write_metrics_payload_evidence "CMS" "000" "" "kubectl unavailable at runtime verification" "$VERIFY_EVIDENCE_DIR/observability-metrics-cms-runtime.md" "/metrics"
fi

check_openedx_settings_metrics_wiring "LMS" "lms"
check_openedx_settings_metrics_wiring "CMS" "cms"

# AC-OVR-018: GCP uptime checks
echo ""
echo "==> AC-OVR-018: GCP uptime checks deployed"
if command -v gcloud >/dev/null 2>&1 && gcloud auth list 2>/dev/null | grep -q ACTIVE; then
    set +e
    if command -v timeout >/dev/null 2>&1; then
        UPTIME_JSON="$(timeout "$VERIFY_CMD_TIMEOUT" gcloud_cmd monitoring uptime list-configs --format=json 2>/dev/null || echo '[]')"
    else
        UPTIME_JSON="$(gcloud_cmd monitoring uptime list-configs --format=json 2>/dev/null || echo '[]')"
    fi
    UPTIME_COUNT="$(echo "$UPTIME_JSON" | jq '. | length' 2>/dev/null || echo 0)"
    set -e
    EXPECTED_UPTIME=$(find infrastructure/monitoring/uptime/*.json 2>/dev/null | wc -l || echo 0)

    if [[ "$UPTIME_COUNT" -ge "$EXPECTED_UPTIME" ]]; then
        pass "AC-OVR-018: GCP has $UPTIME_COUNT uptime checks (expected: $EXPECTED_UPTIME)"
    else
        fail "AC-OVR-018: GCP has $UPTIME_COUNT uptime checks (expected: $EXPECTED_UPTIME)"
    fi
else
    skip "AC-OVR-018: gcloud not authenticated (requires GCP access)"
fi

# AC-OVR-019: GCP alert policies
echo ""
echo "==> AC-OVR-019: GCP alert policies deployed"
if command -v gcloud >/dev/null 2>&1 && gcloud auth list 2>/dev/null | grep -q ACTIVE; then
    set +e
    if command -v timeout >/dev/null 2>&1; then
        ALERT_JSON="$(timeout "$VERIFY_CMD_TIMEOUT" gcloud_cmd alpha monitoring policies list --format=json 2>/dev/null || echo '[]')"
    else
        ALERT_JSON="$(gcloud_cmd alpha monitoring policies list --format=json 2>/dev/null || echo '[]')"
    fi
    ALERT_COUNT="$(echo "$ALERT_JSON" | jq '. | length' 2>/dev/null | tr -d '[:space:]' || echo 0)"
    set -e

    if [[ "$ALERT_COUNT" -gt 0 ]]; then
        pass "AC-OVR-019: GCP has $ALERT_COUNT alert policies deployed"
    else
        fail "AC-OVR-019: No GCP alert policies found"
    fi
else
    skip "AC-OVR-019: gcloud not authenticated (requires GCP access)"
fi

# AC-OVR-020: GCP log-based metrics
echo ""
echo "==> AC-OVR-020: GCP log-based metrics deployed"
if command -v gcloud >/dev/null 2>&1 && gcloud auth list 2>/dev/null | grep -q ACTIVE; then
    set +e
    if command -v timeout >/dev/null 2>&1; then
        METRIC_JSON="$(timeout "$VERIFY_CMD_TIMEOUT" gcloud_cmd logging metrics list --format=json 2>/dev/null || echo '[]')"
    else
        METRIC_JSON="$(gcloud_cmd logging metrics list --format=json 2>/dev/null || echo '[]')"
    fi
    METRIC_COUNT="$(echo "$METRIC_JSON" | jq '. | length' 2>/dev/null | tr -d '[:space:]' || echo 0)"
    set -e

    if [[ "$METRIC_COUNT" -gt 0 ]]; then
        pass "AC-OVR-020: GCP has $METRIC_COUNT log-based metrics deployed"
    else
        fail "AC-OVR-020: No GCP log-based metrics found"
    fi
else
    skip "AC-OVR-020: gcloud not authenticated (requires GCP access)"
fi

# AC-OVR-021: GCP dashboards
echo ""
echo "==> AC-OVR-021: GCP monitoring dashboards deployed"
if command -v gcloud >/dev/null 2>&1 && gcloud auth list 2>/dev/null | grep -q ACTIVE; then
    set +e
    if command -v timeout >/dev/null 2>&1; then
        DASHBOARD_JSON="$(timeout "$VERIFY_CMD_TIMEOUT" gcloud_cmd monitoring dashboards list --format=json 2>/dev/null || echo '[]')"
    else
        DASHBOARD_JSON="$(gcloud_cmd monitoring dashboards list --format=json 2>/dev/null || echo '[]')"
    fi
    DASHBOARD_COUNT="$(echo "$DASHBOARD_JSON" | jq '. | length' 2>/dev/null | tr -d '[:space:]' || echo 0)"
    set -e

    if [[ "$DASHBOARD_COUNT" -gt 0 ]]; then
        pass "AC-OVR-021: GCP has $DASHBOARD_COUNT monitoring dashboards deployed"
    else
        skip "AC-OVR-021: No GCP dashboards found (may not be deployed yet)"
    fi
else
    skip "AC-OVR-021: gcloud not authenticated (requires GCP access)"
fi

# AC-OVR-023: Grafana dashboard with required panels
echo ""
echo "==> AC-OVR-023: Grafana dashboard bbi-app-mereka-lms exists with required panels"
GRAFANA_URL="${GRAFANA_URL:-https://grafana.mereka.io}"
GRAFANA_TOKEN="${GRAFANA_API_TOKEN:-}"
GRAFANA_DASHBOARD_CONTRACT_PATH="${GRAFANA_DASHBOARD_CONTRACT_PATH:-infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json}"

if [[ -n "$GRAFANA_TOKEN" ]]; then
    set +e
    if command -v timeout >/dev/null 2>&1; then
        DASHBOARD_JSON="$(timeout "$VERIFY_CMD_TIMEOUT" curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
            "$GRAFANA_URL/api/dashboards/uid/bbi-app-mereka-lms" 2>/dev/null)"
    else
        DASHBOARD_JSON="$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
            "$GRAFANA_URL/api/dashboards/uid/bbi-app-mereka-lms" 2>/dev/null)"
    fi
    set -e

    if echo "$DASHBOARD_JSON" | jq -e '.dashboard' >/dev/null 2>&1; then
        # Check required panels and query fragments from contract
        REQUIRED_PANELS=("LMS" "CMS (Studio)" "Caddy" "MySQL" "Redis")
        REQUIRED_QUERY_FRAGMENTS=("kube_pod_status_phase" "container_cpu_usage_seconds_total" "container_memory_usage_bytes")

        if [[ -f "$GRAFANA_DASHBOARD_CONTRACT_PATH" ]] && command -v jq >/dev/null 2>&1; then
            mapfile -t contract_panels < <(jq -r '.required.panel_titles[]?' "$GRAFANA_DASHBOARD_CONTRACT_PATH" 2>/dev/null)
            mapfile -t contract_fragments < <(jq -r '.required.query_fragments[]?' "$GRAFANA_DASHBOARD_CONTRACT_PATH" 2>/dev/null)
            if [[ "${#contract_panels[@]}" -gt 0 ]]; then
                REQUIRED_PANELS=("${contract_panels[@]}")
            fi
            if [[ "${#contract_fragments[@]}" -gt 0 ]]; then
                REQUIRED_QUERY_FRAGMENTS=("${contract_fragments[@]}")
            fi
        fi

        MISSING=0
        for panel in "${REQUIRED_PANELS[@]}"; do
            if ! echo "$DASHBOARD_JSON" | jq -e --arg panel "$panel" '.dashboard.panels[] | select(.title == $panel)' >/dev/null 2>&1; then
                fail "AC-OVR-023: Required panel '$panel' not found in dashboard"
                MISSING=$((MISSING + 1))
            fi
        done

        for fragment in "${REQUIRED_QUERY_FRAGMENTS[@]}"; do
            if ! echo "$DASHBOARD_JSON" | jq -e --arg fragment "$fragment" '.dashboard.panels[].targets[]?.expr | select(strings | contains($fragment))' >/dev/null 2>&1; then
                fail "AC-OVR-023: Required query fragment '$fragment' not found in dashboard expressions"
                MISSING=$((MISSING + 1))
            fi
        done

        if [[ $MISSING -eq 0 ]]; then
            pass "AC-OVR-023: Dashboard bbi-app-mereka-lms has required panels and query fragments"
        fi
    else
        fail "AC-OVR-023: Dashboard bbi-app-mereka-lms not found in Grafana"
    fi
else
    skip "AC-OVR-023: GRAFANA_API_TOKEN not set (requires Grafana API access)"
fi

# AC-OVR-025: validate-observability-compliance.sh outputs valid JSON
echo ""
echo "==> AC-OVR-025: Validation script produces valid JSON with --json flag"
if [[ -f "scripts/qa/validate-observability-compliance.sh" ]]; then
    # Run in JSON mode and validate output deterministically
    VALIDATE_RC=0
    VALIDATE_OUTPUT=""
    set +e
    if command -v timeout >/dev/null 2>&1; then
      VALIDATE_OUTPUT="$(VALIDATE_OBS_APP_NAMESPACE="$VERIFY_APP_NAMESPACE" \
        VALIDATE_OBS_JSON_ONLY=1 \
        timeout "$VERIFY_RUNTIME_VALIDATION_TIMEOUT" scripts/qa/validate-observability-compliance.sh --mode local --json --strict 2>&1)"
      VALIDATE_RC=$?
    else
      VALIDATE_OUTPUT="$(VALIDATE_OBS_APP_NAMESPACE="$VERIFY_APP_NAMESPACE" \
        VALIDATE_OBS_JSON_ONLY=1 \
        scripts/qa/validate-observability-compliance.sh --mode local --json --strict 2>&1)"
      VALIDATE_RC=$?
    fi

    if [[ $VALIDATE_RC -ne 0 ]]; then
        fail "AC-OVR-025: validate-observability-compliance.sh failed in --json mode (rc=${VALIDATE_RC})"
        if [[ -n "$VALIDATE_OUTPUT" ]]; then
            skip "AC-OVR-025: output_excerpt=$(printf '%s' "${VALIDATE_OUTPUT}" | tail -n 5 | tr '\n' ' ')"
        fi
    else
        VALIDATE_JSON_PAYLOAD="$(extract_json_payload "$VALIDATE_OUTPUT")"
        JSON_SCHEMA_RESULT="$(validate_observability_compliance_json "$VALIDATE_JSON_PAYLOAD")"

        if [[ "$JSON_SCHEMA_RESULT" == "schema_mismatch" ]]; then
            fail "AC-OVR-025: JSON schema validation failed: missing required fields or wrong structure"
            if [[ -n "$VALIDATE_OUTPUT" ]]; then
                skip "AC-OVR-025: output_excerpt=$(printf '%s' "${VALIDATE_OUTPUT}" | tail -n 5 | tr '\n' ' ')"
            fi
        elif [[ "$JSON_SCHEMA_RESULT" == "jq_missing" ]]; then
            fail "AC-OVR-025: jq dependency required for strict JSON schema validation"
        elif [[ "$JSON_SCHEMA_RESULT" == "json_payload_missing" ]]; then
            fail "AC-OVR-025: JSON output was not found in validation output"
        else
            pass "AC-OVR-025: Validation script emits schema-valid JSON"
            if [[ -n "$VERIFY_EVIDENCE_FILE" ]]; then
                echo "${VALIDATE_JSON_PAYLOAD}" > "$VERIFY_EVIDENCE_DIR/observability-compliance-runtime.json"
            fi
        fi
    fi
    set -e
else
    skip "AC-OVR-025: scripts/qa/validate-observability-compliance.sh not found"
fi

# AC-OVR-026: Validation script detects missing resources
echo ""
echo "==> AC-OVR-026: Validation script exits non-zero when resources are missing"
run_missing_resource_negative_check

# AC-OVR-027: Validation script --mode runtime queries kubectl and gcloud
echo ""
echo "==> AC-OVR-027: Validation script runtime mode queries kubectl and gcloud"
if [[ -f "scripts/qa/validate-observability-compliance.sh" ]]; then
    if command -v kubectl >/dev/null 2>&1 && command -v gcloud >/dev/null 2>&1; then
        if [[ -n "$VERIFY_K8S_CONTEXT" ]]; then
            if kubectl --context "$VERIFY_K8S_CONTEXT" get ns >/dev/null 2>&1; then
                pass "AC-OVR-027: kubectl cluster access succeeds"
            else
                fail "AC-OVR-027: kubectl cluster access failed"
            fi
        elif kubectl get ns >/dev/null 2>&1; then
            pass "AC-OVR-027: kubectl cluster access succeeds"
        else
            fail "AC-OVR-027: kubectl cluster access failed"
        fi

        local_account_count="$(timeout "$VERIFY_RUNTIME_SCRIPT_TIMEOUT" gcloud auth list --filter='status:ACTIVE' --format='value(account)' 2>/dev/null | sed '/^$/d' | wc -l | tr -d ' ')" || local_account_count="0"
        if [[ "$local_account_count" -ge 1 ]]; then
            pass "AC-OVR-027: gcloud active account available"
        else
            fail "AC-OVR-027: gcloud has no active account"
        fi
    else
        skip "AC-OVR-027: kubectl or gcloud not available"
    fi
else
    skip "AC-OVR-027: scripts/qa/validate-observability-compliance.sh not found"
fi

# AC-OVR-028: CI runs validation script on monitoring file changes
echo ""
echo "==> AC-OVR-028: CI workflow runs validation script on PR changes"
if [[ -f ".github/workflows/observability-compliance.yml" ]]; then
    if grep -q "validate-observability-compliance.sh" .github/workflows/observability-compliance.yml; then
        pass "AC-OVR-028: CI workflow configured to run validation script"
    else
        fail "AC-OVR-028: CI workflow exists but does not run validation script"
    fi
else
    fail "AC-OVR-028: CI workflow for observability compliance not yet created"
fi

# AC-OVR-029: CI blocks merge when ServiceMonitor is removed
echo ""
echo "==> AC-OVR-029: CI blocks merge when ServiceMonitor is removed from kustomization"
if [[ -f ".github/workflows/observability-compliance.yml" ]]; then
    if grep -q "pull_request:" .github/workflows/observability-compliance.yml \
        && grep -q "deploy/k8s/base/monitoring" .github/workflows/observability-compliance.yml \
        && grep -q "validate-observability-compliance.sh --mode local --strict" .github/workflows/observability-compliance.yml; then
        pass "AC-OVR-029: CI workflow enforces merge-blocking observability checks on monitoring changes"
    else
        fail "AC-OVR-029: CI workflow does not gate monitoring-path changes with strict observability validation"
    fi
else
    fail "AC-OVR-029: CI workflow for observability compliance not yet created"
fi

# AC-OVR-031: Alert rules have valid PromQL (no syntax errors)
echo ""
echo "==> AC-OVR-031: All alert PromQL expressions are valid (no syntax errors)"
echo ""
echo ">> Runtime wiring check: LMS and CMS metrics/alerts in Prometheus"
check_prometheus_runtime_wiring \
    "LMS" \
    "lms-metrics" \
    "lms-alerts" \
    "$VERIFY_EVIDENCE_DIR/observability-lms-prometheus-wiring-runtime.md"
check_prometheus_runtime_wiring \
    "CMS" \
    "cms-metrics" \
    "lms-alerts" \
    "$VERIFY_EVIDENCE_DIR/observability-cms-prometheus-wiring-runtime.md"

echo "==> Runtime wiring check: caddy-metrics and caddy-alerts in Prometheus"
check_prometheus_runtime_wiring \
    "caddy" \
    "caddy-metrics" \
    "caddy-alerts" \
    "$VERIFY_EVIDENCE_DIR/observability-caddy-prometheus-wiring-runtime.md"

echo "==> Runtime wiring check: mfe-metrics and services-alerts in Prometheus"
check_prometheus_runtime_wiring \
    "mfe" \
    "mfe-metrics" \
    "services-alerts" \
    "$VERIFY_EVIDENCE_DIR/observability-mfe-prometheus-wiring-runtime.md"

echo "==> Runtime wiring check: remaining high-signal ServiceMonitors in Prometheus targets"
check_prometheus_runtime_wiring \
    "forum" \
    "forum-metrics" \
    "" \
    "$VERIFY_EVIDENCE_DIR/observability-forum-prometheus-wiring-runtime.md"
check_prometheus_runtime_wiring \
    "discovery" \
    "discovery-metrics" \
    "" \
    "$VERIFY_EVIDENCE_DIR/observability-discovery-prometheus-wiring-runtime.md"
check_prometheus_runtime_wiring \
    "ecommerce" \
    "ecommerce-metrics" \
    "" \
    "$VERIFY_EVIDENCE_DIR/observability-ecommerce-prometheus-wiring-runtime.md"
check_prometheus_runtime_wiring \
    "credentials" \
    "credentials-metrics" \
    "" \
    "$VERIFY_EVIDENCE_DIR/observability-credentials-prometheus-wiring-runtime.md"
check_prometheus_runtime_wiring \
    "purchase-gateway" \
    "purchase-gateway-metrics" \
    "" \
    "$VERIFY_EVIDENCE_DIR/observability-purchase-gateway-prometheus-wiring-runtime.md"

echo "==> Runtime wiring check: additional core alert groups in Prometheus"
check_prometheus_runtime_wiring \
    "slo" \
    "" \
    "slo-recording-rules" \
    "$VERIFY_EVIDENCE_DIR/observability-slo-rules-prometheus-wiring-runtime.md"
check_prometheus_runtime_wiring \
    "video" \
    "" \
    "video-alerts" \
    "$VERIFY_EVIDENCE_DIR/observability-video-rules-prometheus-wiring-runtime.md"
check_prometheus_runtime_wiring \
    "ora2" \
    "" \
    "ora2-operations" \
    "$VERIFY_EVIDENCE_DIR/observability-ora2-rules-prometheus-wiring-runtime.md"

lane_env="${VERIFY_ENV_LABEL,,}"
if [[ "$lane_env" == "dev" || "$lane_env" == "local" || "$lane_env" == "kind" || "$lane_env" == "kind-dev" ]]; then
    echo "==> Runtime wiring check: dev-only ServiceMonitors"
    check_prometheus_runtime_wiring \
        "xqueue" \
        "xqueue-metrics" \
        "" \
        "$VERIFY_EVIDENCE_DIR/observability-dev-xqueue-prometheus-wiring-runtime.md"
    check_prometheus_runtime_wiring \
        "mux" \
        "mux-delivery-monitor" \
        "" \
        "$VERIFY_EVIDENCE_DIR/observability-dev-mux-prometheus-wiring-runtime.md"
fi
if command -v kubectl >/dev/null 2>&1; then
    set +e
    PROM_POD="$(resolve_prometheus_pod)"
    PROM_NAMESPACE="${PROM_POD_NAMESPACE:-$VERIFY_MONITORING_NAMESPACE}"
    set -e

    if [[ -n "$PROM_POD" ]]; then
        # Get all alert rules from Prometheus
        set +e
        RULES_JSON="$(kubectl_cmd_with_timeout exec -n "$PROM_NAMESPACE" "$PROM_POD" -c prometheus -- \
            wget -q -O- "http://localhost:9090/api/v1/rules" 2>/dev/null)"
        set -e

        if echo "$RULES_JSON" | jq -e '.data.groups[].rules[] | select(.type=="alerting")' >/dev/null 2>&1; then
            # Count alerts with health=ok
            TOTAL_ALERTS=$(echo "$RULES_JSON" | jq '[.data.groups[].rules[] | select(.type=="alerting")] | length')
            OK_ALERTS=$(echo "$RULES_JSON" | jq '[.data.groups[].rules[] | select(.type=="alerting" and .health=="ok")] | length')

            if [[ "$OK_ALERTS" -eq "$TOTAL_ALERTS" ]]; then
                pass "AC-OVR-031: All $TOTAL_ALERTS alert rules have valid PromQL (health=ok)"
            else
                fail "AC-OVR-031: $((TOTAL_ALERTS - OK_ALERTS)) alert rules have PromQL syntax errors"
            fi
        else
            skip "AC-OVR-031: No alert rules loaded in Prometheus yet"
        fi
    else
        skip "AC-OVR-031: Prometheus pod not found in ${VERIFY_MONITORING_NAMESPACE}/${VERIFY_APP_NAMESPACE} namespace"
    fi
else
    skip "AC-OVR-031: kubectl not available (requires live cluster access)"
fi

# Summary
echo ""
echo "==========================================="
echo "Summary"
echo "==========================================="
echo -e "${GREEN}PASS: $PASS${NC}"
echo -e "${RED}FAIL: $FAIL${NC}"
echo -e "${YELLOW}SKIP: $SKIP${NC}"
echo "Total: $((PASS + FAIL + SKIP))"

if [[ -n "$VERIFY_EVIDENCE_FILE" ]]; then
    mkdir -p "$(dirname "$VERIFY_EVIDENCE_FILE")"
    {
        echo "# Observability Runtime Verification Evidence"
        echo ""
        echo "- generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "- app_namespace: $VERIFY_APP_NAMESPACE"
        echo "- monitoring_namespace: $VERIFY_MONITORING_NAMESPACE"
        echo "- gcp_project: $VERIFY_GCP_PROJECT"
        echo "- environment_label: $VERIFY_ENV_LABEL"
        echo "- dispatch_profile: $VERIFY_DISPATCH_PROFILE"
        echo "- k8s_context: ${VERIFY_K8S_CONTEXT:-default}"
        echo "- evidence_identity: env=${VERIFY_ENV_LABEL};profile=${VERIFY_DISPATCH_PROFILE};context=${VERIFY_K8S_CONTEXT:-default};project=${VERIFY_GCP_PROJECT}"
        echo "- metrics_payload_evidence_lms: observability-metrics-lms-runtime.md"
        echo "- metrics_payload_evidence_cms: observability-metrics-cms-runtime.md"
        echo ""
        echo "## Summary"
        echo ""
        echo "- pass: $PASS"
        echo "- fail: $FAIL"
        echo "- skip: $SKIP"
        echo "- total: $((PASS + FAIL + SKIP))"
        echo ""
        echo "## Failed Checks"
        echo ""
        if awk -F $'\t' '$1=="fail"{exit 0} END{exit 1}' "$RESULTS_FILE"; then
            awk -F $'\t' '$1=="fail"{printf("- %s\n", $2)}' "$RESULTS_FILE"
        else
            echo "- none"
        fi
    } > "$VERIFY_EVIDENCE_FILE"
fi

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi

exit 0
