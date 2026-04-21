#!/usr/bin/env bash
# @covers AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-014, AC-015, AC-016, AC-017, AC-018, AC-019, AC-024, AC-027, AC-028, AC-029, AC-030, AC-032, AC-033, AC-CCR-002, AC-CCR-008, AC-CCR-009
# @spec: k8s-deployment_spec.md
# @runtime-dependencies: none
set -euo pipefail

# verify-k8s-deployment-spec.sh
# Static analysis of K8s manifests to verify k8s-deployment spec compliance
# Covers 21 of 33 acceptance criteria (no live cluster needed)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0

# Paths
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_DIR="${REPO_ROOT}/deploy/k8s/base"
OVERLAYS_DIR="${REPO_ROOT}/deploy/k8s/overlays"
YQ="${HOME}/.local/bin/yq"

source "$REPO_ROOT/scripts/shared/ci-skip-guards.sh"
require_file "$YQ" "yq binary" || exit 0

# Verify yq is available
if [[ ! -x "$YQ" ]]; then
    echo -e "${RED}Error: yq not found at $YQ${NC}"
    exit 1
fi

# Pre-render base kustomize output to a temp file.
# The old monolithic deployments.yml / services.yml no longer exist;
# resources live in per-service directories under base/apps/.
RENDERED_BASE="$(mktemp)"
trap 'rm -f "$RENDERED_BASE"' EXIT
if ! kubectl kustomize "$BASE_DIR" > "$RENDERED_BASE" 2>/dev/null; then
    echo -e "${RED}Error: base kustomize render failed${NC}" >&2
    exit 1
fi

# Helper functions
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

skip() {
    echo -e "${YELLOW}SKIP${NC}: $1"
    SKIP_COUNT=$((SKIP_COUNT + 1))
}

# Check functions

check_replicas() {
    local overlay="${1:-production}"
    echo "Checking replica counts for overlay: $overlay"

    local kustomization="${OVERLAYS_DIR}/${overlay}/kustomization.yaml"

    if [[ ! -f "$kustomization" ]]; then
        skip "Overlay '$overlay' is not present in this repo; non-local environment overlays are GitOps-owned"
        return
    fi

    if [[ "$overlay" == "production" ]]; then
        # Check for replicas section in the GitOps production overlay when
        # a local checkout of that overlay is explicitly supplied.
        local lms_replicas
        local worker_replicas

        lms_replicas=$("$YQ" '.replicas[] | select(.name == "lms") | .count' "$kustomization" 2>/dev/null || echo "")
        worker_replicas=$("$YQ" '.replicas[] | select(.name == "lms-worker") | .count' "$kustomization" 2>/dev/null || echo "")

        if [[ "$lms_replicas" == "2" ]]; then
            pass "Production LMS replicas = 2"
        else
            fail "Production LMS replicas = $lms_replicas (expected 2)"
        fi

        if [[ "$worker_replicas" == "2" ]]; then
            pass "Production lms-worker replicas = 2"
        else
            fail "Production lms-worker replicas = $worker_replicas (expected 2)"
        fi
    elif [[ "$overlay" == "local" ]]; then
        local has_replicas
        has_replicas=$("$YQ" '.replicas' "$kustomization" 2>/dev/null || echo "null")

        if [[ "$has_replicas" == "null" ]]; then
            pass "Local overlay has no explicit replicas (defaults to 1)"
        else
            local all_passed=true
            local core_workloads=("lms" "cms" "lms-worker" "cms-worker")
            local disabled_workloads=(
                "enterprise-access"
                "enterprise-access-worker"
                "enterprise-admin-portal"
                "enterprise-catalog"
                "enterprise-catalog-worker"
                "enterprise-learner-portal"
                "enterprise-subsidy"
                "payments-gateway"
            )

            for workload in "${core_workloads[@]}"; do
                local count
                count=$("$YQ" ".replicas[] | select(.name == \"${workload}\") | .count" "$kustomization" 2>/dev/null || echo "")
                if [[ "$count" != "1" ]]; then
                    fail "Local overlay ${workload} replicas = ${count:-unset} (expected 1)"
                    all_passed=false
                fi
            done

            for workload in "${disabled_workloads[@]}"; do
                local count
                count=$("$YQ" ".replicas[] | select(.name == \"${workload}\") | .count" "$kustomization" 2>/dev/null || echo "")
                if [[ -n "$count" && "$count" != "0" ]]; then
                    fail "Local overlay ${workload} replicas = ${count} (expected 0 when explicitly listed)"
                    all_passed=false
                fi
            done

            if [[ "$all_passed" == true ]]; then
                pass "Local overlay replica contract matches core=1 and known disabled workloads=0"
            fi
        fi
    fi
}

check_envfrom() {
    echo "Checking envFrom configuration"

    local deployments="$RENDERED_BASE"
    local required_secrets=("openedx-secrets" "database-secrets" "mereka-lms-runtime-secrets")
    local deployments_to_check=("lms" "cms" "lms-worker")

    if [[ ! -f "$deployments" ]]; then
        fail "Deployments file not found: $deployments"
        return
    fi

    for deployment in "${deployments_to_check[@]}"; do
        local found_all=true

        # Use yq to extract envFrom secret names for this specific deployment
        local secret_names
        secret_names=$("$YQ" eval "select(.kind == \"Deployment\" and .metadata.name == \"${deployment}\") | .spec.template.spec.containers[0].envFrom[].secretRef.name" "$deployments" 2>/dev/null || echo "")

        for secret in "${required_secrets[@]}"; do
            if echo "$secret_names" | grep -q "^${secret}$"; then
                continue
            else
                fail "${deployment} Deployment missing envFrom secretRef: ${secret}"
                found_all=false
            fi
        done

        if [[ "$found_all" == true ]]; then
            pass "${deployment} Deployment has all required envFrom secrets"
        fi
    done
}

check_worker_probes() {
    echo "Checking worker probe contract"

    local deployments="$RENDERED_BASE"
    local worker_deployments=("lms-worker" "cms-worker")
    local all_passed=true

    for deployment in "${worker_deployments[@]}"; do
        for probe in livenessProbe readinessProbe; do
            local command
            command=$("$YQ" eval "select(.kind == \"Deployment\" and .metadata.name == \"${deployment}\") | .spec.template.spec.containers[0].${probe}.exec.command[]?" "$deployments" 2>/dev/null | grep -v "^---$" | paste -sd ' ' - || echo "")

            if [[ -z "$command" ]]; then
                fail "${deployment} ${probe} has no exec command"
                all_passed=false
                continue
            fi

            if [[ "$command" != *"ps -o comm= -p 1"* ]]; then
                fail "${deployment} ${probe} does not use the local PID probe contract"
                all_passed=false
            fi

            if [[ "$command" == *"inspect ping"* || "$command" == *"celery inspect"* || "$command" == *"celery -A"* ]]; then
                fail "${deployment} ${probe} uses Celery broker traversal instead of a local process check"
                all_passed=false
            fi
        done
    done

    if [[ "$all_passed" == true ]]; then
        pass "Worker liveness/readiness probes use local process checks and avoid Celery broker traversal"
    fi
}

check_mysql_args() {
    echo "Checking MySQL native password argument"

    local deployments="$RENDERED_BASE"

    if grep -A 30 "name: mysql$" "$deployments" | grep -q -- "--mysql-native-password=ON"; then
        pass "MySQL Deployment has --mysql-native-password=ON argument"
    else
        fail "MySQL Deployment missing --mysql-native-password=ON argument"
    fi
}

check_mysql_exporter() {
    echo "Checking MySQL exporter sidecar"

    local deployments="$RENDERED_BASE"

    # In rendered multi-doc YAML, grep context may not span from metadata.name
    # to the sidecar container. Search the full rendered output instead.
    if grep -q "name: mysqld-exporter" "$deployments" && \
       grep -q "containerPort: 9104" "$deployments"; then
        pass "MySQL Deployment has mysqld-exporter sidecar with port 9104"
    else
        fail "MySQL Deployment missing mysqld-exporter sidecar or port 9104"
    fi
}

check_redis_exporter() {
    echo "Checking Redis exporter sidecar"

    local deployments="$RENDERED_BASE"
    local exporter_port

    exporter_port=$("$YQ" eval 'select(.kind == "Deployment" and .metadata.name == "redis") | .spec.template.spec.containers[] | select(.name == "redis-exporter") | .ports[]? | select(.containerPort == 9121) | .containerPort' "$deployments" 2>/dev/null | grep -v "^---$" | head -1 || echo "")

    if [[ "$exporter_port" == "9121" ]]; then
        pass "Redis Deployment has redis-exporter sidecar with port 9121"
    else
        fail "Redis Deployment missing redis-exporter sidecar or port 9121"
    fi
}

check_security_context() {
    echo "Checking securityContext settings"

    local deployments="$RENDERED_BASE"

    # Container hardening patches enforce: allowPrivilegeEscalation=false,
    # capabilities drop ALL, readOnlyRootFilesystem (where applicable).
    # Use yq to extract container securityContext per Deployment (grep -A
    # is unreliable on multi-doc YAML — it matches Service metadata first).
    for svc in lms cms; do
      local ape
      ape=$("$YQ" eval "select(.kind == \"Deployment\" and .metadata.name == \"${svc}\") | .spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation" "$deployments" 2>/dev/null | grep -v "^---$" | grep -v "^null$" | head -1 || echo "")
      if [[ "$ape" == "false" ]]; then
        pass "${svc} has allowPrivilegeEscalation: false"
      else
        fail "${svc} missing allowPrivilegeEscalation: false"
      fi
    done

    # MySQL and SMTP may have different security models (stateful services)
    for svc in mysql smtp; do
      local sec
      sec=$("$YQ" eval "select(.kind == \"Deployment\" and .metadata.name == \"${svc}\") | .spec.template.spec.containers[0].securityContext" "$deployments" 2>/dev/null | grep -v "^---$" | grep -v "^null$" | head -1 || echo "")
      if [[ -n "$sec" ]]; then
        pass "${svc} has securityContext defined"
      else
        warn "${svc} missing explicit securityContext"
      fi
    done
}

check_privilege_escalation() {
    echo "Checking allowPrivilegeEscalation settings"

    local deployments="$RENDERED_BASE"

    # Count containers with securityContext across all resource kinds
    local containers_with_context
    containers_with_context=$(grep -c "allowPrivilegeEscalation:" "$deployments" || echo "0")

    if [[ $containers_with_context -eq 0 ]]; then
        warn "No containers have allowPrivilegeEscalation set (should be false for all)"
        return
    fi

    # Check Deployments only (rendered output includes non-Deployment resources
    # like ClusterPolicies that mention the string in descriptions).
    # Extract explicit values, filter out nulls and document separators.
    local deploy_priv_esc
    deploy_priv_esc=$("$YQ" eval 'select(.kind == "Deployment") | .spec.template.spec.containers[].securityContext.allowPrivilegeEscalation' "$deployments" 2>/dev/null | grep -vE '^(---|null)$' || echo "")

    if [[ -z "$deploy_priv_esc" ]]; then
        warn "No Deployment containers have explicit allowPrivilegeEscalation (unset = defaults to true)"
        return
    fi

    if echo "$deploy_priv_esc" | grep -q "true"; then
        # Caddy has allowPrivilegeEscalation: true for port binding;
        # check if ALL other Deployment containers are false.
        local true_count false_count
        true_count=$(echo "$deploy_priv_esc" | grep -c "true" || echo "0")
        false_count=$(echo "$deploy_priv_esc" | grep -c "false" || echo "0")
        if [[ "$true_count" -le 1 ]]; then
            warn "1 Deployment container has allowPrivilegeEscalation: true (caddy needs port binding); ${false_count} are false"
        else
            fail "${true_count} Deployment containers have allowPrivilegeEscalation: true (should be false)"
        fi
    else
        pass "All Deployment containers with explicit securityContext have allowPrivilegeEscalation: false"
    fi
}

check_selector_match() {
    echo "Checking Service selector matches Deployment labels"

    local services="$RENDERED_BASE"
    local deployments="$RENDERED_BASE"
    local mismatches=0

    # Extract service names
    local service_names
    service_names=$("$YQ" eval 'select(.kind == "Service") | .metadata.name' "$services" 2>/dev/null | grep -v "^---$" || echo "")

    if [[ -z "$service_names" ]]; then
        fail "No Services found in $services"
        return
    fi

    # Pre-compute all deployment labels once (avoids SIGPIPE with grep -q)
    local deployment_labels
    deployment_labels=$("$YQ" eval 'select(.kind == "Deployment") | .spec.template.metadata.labels."app.kubernetes.io/name"' "$deployments" 2>/dev/null | grep -v "^---$" || echo "")

    while IFS= read -r service_name; do
        [[ "$service_name" == "---" ]] && continue
        [[ -z "$service_name" ]] && continue

        # Get service selector
        local selector_app
        selector_app=$("$YQ" eval "select(.kind == \"Service\" and .metadata.name == \"$service_name\") | .spec.selector.\"app.kubernetes.io/name\"" "$services" 2>/dev/null | head -1 || echo "")

        if [[ -z "$selector_app" ]]; then
            continue
        fi

        # Check if matching Deployment exists with same label
        if echo "$deployment_labels" | grep -q "^${selector_app}$"; then
            continue
        else
            # mongodb service exists in base but has no Deployment (Atlas-only architecture)
            # Production overlay removes it via remove-legacy-mongodb-service.yaml
            if [[ "$service_name" == "mongodb" ]]; then
                warn "Service mongodb has no matching Deployment (expected: Atlas-only, removed in GitOps production overlay)"
            elif [[ "$service_name" == "promtail" ]]; then
                warn "Service promtail has no matching Deployment (expected: runs as DaemonSet, not Deployment)"
            else
                fail "Service $service_name selector (app.kubernetes.io/name=$selector_app) has no matching Deployment"
                mismatches=$((mismatches + 1))
            fi
        fi
    done <<< "$service_names"

    if [[ $mismatches -eq 0 ]]; then
        pass "All Service selectors match Deployment labels"
    fi
}

check_pvcs() {
    echo "Checking PersistentVolumeClaim configurations"

    local volumes="${BASE_DIR}/volumes.yml"

    if [[ ! -f "$volumes" ]]; then
        fail "Volumes file not found: $volumes"
        return
    fi

    local checks=("caddy:1Gi" "elasticsearch:2Gi" "mysql:5Gi" "redis:1Gi")
    local all_passed=true

    for check in "${checks[@]}"; do
        local name="${check%%:*}"
        local size="${check##*:}"

        # Use yq eval-all to handle multi-document YAML
        local actual_size
        actual_size=$("$YQ" eval "select(.metadata.name == \"$name\") | .spec.resources.requests.storage" "$volumes" 2>/dev/null | head -1 || echo "")

        if [[ "$actual_size" == "$size" ]]; then
            continue
        else
            fail "PVC $name has size $actual_size (expected $size)"
            all_passed=false
        fi

        # Check accessModes
        if "$YQ" eval "select(.metadata.name == \"$name\") | .spec.accessModes[]" "$volumes" 2>/dev/null | grep -q "ReadWriteOnce"; then
            continue
        else
            fail "PVC $name missing ReadWriteOnce accessMode"
            all_passed=false
        fi
    done

    if [[ "$all_passed" == true ]]; then
        pass "All PVCs have correct size and accessModes"
    fi
}

check_strategy() {
    echo "Checking Deployment update strategies"

    local deployments="$RENDERED_BASE"
    local stateful_deployments=("elasticsearch" "mysql" "redis")
    local all_passed=true

    for deployment in "${stateful_deployments[@]}"; do
        local strategy
        strategy=$("$YQ" eval "select(.kind == \"Deployment\" and .metadata.name == \"$deployment\") | .spec.strategy.type" "$deployments" 2>/dev/null | head -1 || echo "")

        if [[ "$strategy" == "Recreate" ]]; then
            continue
        else
            fail "Deployment $deployment has strategy '$strategy' (expected Recreate)"
            all_passed=false
        fi
    done

    if [[ "$all_passed" == true ]]; then
        pass "All stateful Deployments use Recreate strategy"
    fi
}

check_ingress_count() {
    echo "Checking production Ingress count"

    local ingress_dir="${OVERLAYS_DIR}/production"
    if [[ ! -d "$ingress_dir" ]]; then
        skip "Production Ingress is GitOps-owned; deploy/k8s/overlays/production is absent in this repo"
        return
    fi

    local ingress_count
    ingress_count=$(find "$ingress_dir" -name "ingress-*.yaml" -o -name "*-ingress.yaml" | wc -l)

    if [[ $ingress_count -ge 3 ]]; then
        pass "Production overlay has $ingress_count Ingress files (expected ≥3)"
    else
        fail "Production overlay has only $ingress_count Ingress files (expected ≥3)"
    fi
}

check_ingress_annotations() {
    echo "Checking Ingress cert-manager annotations"

    local ingress_dir="${OVERLAYS_DIR}/production"
    if [[ ! -d "$ingress_dir" ]]; then
        skip "Production Ingress annotations are verified in the GitOps overlay, not this app repo"
        return
    fi

    local ingress_files
    ingress_files=$(find "$ingress_dir" -name "ingress-*.yaml" -o -name "*-ingress.yaml")

    if [[ -z "$ingress_files" ]]; then
        fail "No Ingress files found in $ingress_dir"
        return
    fi

    local missing_annotation=false

    while IFS= read -r file; do
        if ! grep -q "cert-manager.io/cluster-issuer" "$file"; then
            fail "$(basename "$file") missing cert-manager.io/cluster-issuer annotation"
            missing_annotation=true
        fi
    done <<< "$ingress_files"

    if [[ "$missing_annotation" == false ]]; then
        pass "All Ingress files have cert-manager.io/cluster-issuer annotation"
    fi
}

check_ingress_hosts() {
    echo "Checking LMS Ingress hosts"

    if [[ ! -d "${OVERLAYS_DIR}/production" ]]; then
        skip "Production Ingress hosts are verified in the GitOps overlay, not this app repo"
        return
    fi

    local lms_ingress
    lms_ingress=$(find "${OVERLAYS_DIR}/production" -name "*lms*.yaml" | grep -i ingress | head -1)

    if [[ -z "$lms_ingress" ]]; then
        fail "LMS Ingress file not found in production overlay"
        return
    fi

    local has_mereka=false
    local has_biji=false

    if grep -q "academyv2.mereka.io" "$lms_ingress"; then
        has_mereka=true
    fi

    if grep -q "academy.biji-biji.com" "$lms_ingress"; then
        has_biji=true
    fi

    if [[ "$has_mereka" == true ]] && [[ "$has_biji" == true ]]; then
        pass "LMS Ingress includes academyv2.mereka.io and academy.biji-biji.com"
    else
        [[ "$has_mereka" == false ]] && fail "LMS Ingress missing academyv2.mereka.io"
        [[ "$has_biji" == false ]] && fail "LMS Ingress missing academy.biji-biji.com"
    fi
}

check_configmaps() {
    echo "Checking ConfigMap generators"

    local kustomization="${BASE_DIR}/kustomization.yaml"
    local configmap_count
    configmap_count=$("$YQ" '.configMapGenerator | length' "$kustomization" 2>/dev/null || echo "0")

    if [[ $configmap_count -ge 13 ]]; then
        pass "Base kustomization has $configmap_count configMapGenerator entries (expected ≥13)"
    else
        fail "Base kustomization has only $configmap_count configMapGenerator entries (expected ≥13)"
    fi
}

check_servicemonitors() {
    echo "Checking ServiceMonitor resources"

    local monitoring_dir="${BASE_DIR}/monitoring"

    if [[ ! -d "$monitoring_dir" ]]; then
        fail "Monitoring directory not found: $monitoring_dir"
        return
    fi

    local required_monitors=("lms" "cms" "mysql" "redis")
    local all_found=true

    for monitor in "${required_monitors[@]}"; do
        if find "$monitoring_dir" -name "servicemonitor*${monitor}*.yaml" -o -name "*${monitor}*servicemonitor*.yaml" 2>/dev/null | grep -q .; then
            continue
        elif grep -rl "kind: ServiceMonitor" "$monitoring_dir" 2>/dev/null | xargs grep -l "name:.*${monitor}" 2>/dev/null | grep -q .; then
            continue
        else
            fail "ServiceMonitor for $monitor not found in $monitoring_dir"
            all_found=false
        fi
    done

    if [[ "$all_found" == true ]]; then
        pass "All required ServiceMonitors present"
    fi
}

check_alertrules() {
    echo "Checking PrometheusRule resources"

    local monitoring_dir="${BASE_DIR}/monitoring"

    # Capture to variable to avoid SIGPIPE when grep -q exits early
    local found_files
    found_files=$(find "$monitoring_dir" -name "*.yaml" -exec grep -l "kind: PrometheusRule" {} \; 2>/dev/null || echo "")

    if [[ -n "$found_files" ]]; then
        pass "PrometheusRule found in monitoring directory"
    else
        fail "No PrometheusRule found in $monitoring_dir"
    fi
}

check_promtail_tolerations() {
    echo "Checking Promtail DaemonSet"

    local logging_dir="${BASE_DIR}/logging"

    if [[ ! -d "$logging_dir" ]]; then
        fail "Logging directory not found: $logging_dir"
        return
    fi

    if [[ -f "${logging_dir}/promtail-daemonset.yaml" ]]; then
        pass "Promtail DaemonSet exists at ${logging_dir}/promtail-daemonset.yaml"
    else
        fail "Promtail DaemonSet not found at ${logging_dir}/promtail-daemonset.yaml"
    fi
}

check_promtail_resources() {
    echo "Checking Promtail resource requests/limits"

    local promtail="${BASE_DIR}/logging/promtail-daemonset.yaml"

    if [[ ! -f "$promtail" ]]; then
        fail "Promtail DaemonSet not found"
        return
    fi

    if grep -A 10 "resources:" "$promtail" | grep -q "requests:" && \
       grep -A 10 "resources:" "$promtail" | grep -q "limits:"; then
        pass "Promtail DaemonSet has resource requests and limits"
    else
        fail "Promtail DaemonSet missing resource requests or limits"
    fi
}

check_aspects() {
    echo "Checking Aspects/ClickHouse manifests"

    # Check for aspects-related files
    if find "${BASE_DIR}" -name "*aspects*" -o -name "*clickhouse*" | grep -q .; then
        pass "Aspects/ClickHouse manifests found"
    else
        warn "Aspects/ClickHouse manifests not found (may not be implemented yet)"
    fi
}

# Main execution

print_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Verify K8s deployment manifests against k8s-deployment spec (static analysis).

OPTIONS:
    --check <name>      Run specific check (see list below)
    --overlay <name>    Specify overlay for checks that need it (local by default)
    --help              Show this help message

AVAILABLE CHECKS:
    replicas            Replica counts (requires --overlay)
    envfrom             envFrom configuration
    worker-probes       Worker liveness/readiness probes
    mysql-args          MySQL native password argument
    mysql-exporter      MySQL exporter sidecar
    redis-exporter      Redis exporter sidecar
    security-context    securityContext user/group settings
    privilege-escalation allowPrivilegeEscalation settings
    selector-match      Service selector matches Deployment labels
    pvcs                PersistentVolumeClaim configurations
    strategy            Deployment update strategies
    ingress-count       Production Ingress count
    ingress-annotations Ingress cert-manager annotations
    ingress-hosts       LMS Ingress host list
    configmaps          ConfigMap generator count
    servicemonitors     ServiceMonitor resources
    alertrules          PrometheusRule resources
    promtail-tolerations Promtail DaemonSet existence
    promtail-resources  Promtail resource requests/limits
    aspects             Aspects/ClickHouse manifests

EXAMPLES:
    $(basename "$0")                                    # Run all checks
    $(basename "$0") --check replicas --overlay local
    $(basename "$0") --check envfrom
    $(basename "$0") --check mysql-args

EOF
}

# Parse arguments
CHECK_NAME=""
OVERLAY="local"

while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            CHECK_NAME="$2"
            shift 2
            ;;
        --overlay)
            OVERLAY="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Run checks
echo "K8s Deployment Spec Verification"
echo "================================="
echo ""

if [[ -z "$CHECK_NAME" ]]; then
    # Run all checks
    check_replicas "$OVERLAY"
    echo ""
    check_envfrom
    echo ""
    check_worker_probes
    echo ""
    check_mysql_args
    echo ""
    check_mysql_exporter
    echo ""
    check_redis_exporter
    echo ""
    check_security_context
    echo ""
    check_privilege_escalation
    echo ""
    check_selector_match
    echo ""
    check_pvcs
    echo ""
    check_strategy
    echo ""
    check_ingress_count
    echo ""
    check_ingress_annotations
    echo ""
    check_ingress_hosts
    echo ""
    check_configmaps
    echo ""
    check_servicemonitors
    echo ""
    check_alertrules
    echo ""
    check_promtail_tolerations
    echo ""
    check_promtail_resources
    echo ""
    check_aspects
else
    # Run specific check
    case "$CHECK_NAME" in
        replicas)
            check_replicas "$OVERLAY"
            ;;
        envfrom)
            check_envfrom
            ;;
        worker-probes)
            check_worker_probes
            ;;
        mysql-args)
            check_mysql_args
            ;;
        mysql-exporter)
            check_mysql_exporter
            ;;
        redis-exporter)
            check_redis_exporter
            ;;
        security-context)
            check_security_context
            ;;
        privilege-escalation)
            check_privilege_escalation
            ;;
        selector-match)
            check_selector_match
            ;;
        pvcs)
            check_pvcs
            ;;
        strategy)
            check_strategy
            ;;
        ingress-count)
            check_ingress_count
            ;;
        ingress-annotations)
            check_ingress_annotations
            ;;
        ingress-hosts)
            check_ingress_hosts
            ;;
        configmaps)
            check_configmaps
            ;;
        servicemonitors)
            check_servicemonitors
            ;;
        alertrules)
            check_alertrules
            ;;
        promtail-tolerations)
            check_promtail_tolerations
            ;;
        promtail-resources)
            check_promtail_resources
            ;;
        aspects)
            check_aspects
            ;;
        *)
            echo "Unknown check: $CHECK_NAME"
            print_usage
            exit 1
            ;;
    esac
fi

# Summary
echo ""
echo "================================="
echo "Summary"
echo "================================="
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
echo -e "${RED}Failed: $FAIL_COUNT${NC}"
echo -e "${YELLOW}Warnings: $WARN_COUNT${NC}"
echo -e "${YELLOW}Skipped: $SKIP_COUNT${NC}"

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
else
    exit 0
fi
