#!/usr/bin/env bash
# @covers AC-003, AC-028, AC-032
# @spec: k8s-deployment_spec.md
#
# Verify ArgoCD health configuration for the mereka-lms deployment manifests.
# Diagnoses stale Degraded status caused by missing probes, stuck rollouts,
# aggressive probe timeouts, and missing progressDeadlineSeconds.
#
# Supports two modes:
#   --offline  Validate git manifests only (no cluster access needed)
#   --online   Live cluster checks via kubectl (requires cluster access)
#
# Usage:
#   ./scripts/qa/verify-argocd-health-config.sh --offline
#   ./scripts/qa/verify-argocd-health-config.sh --online
#   ./scripts/qa/verify-argocd-health-config.sh --offline --online
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../shared/config.sh
source "${REPO_ROOT}/scripts/shared/config.sh"

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
APP_NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"

# Probe timeout ceiling (seconds) — probes more aggressive than this may cause
# false-positive Degraded under GKE node pressure
PROBE_TIMEOUT_MAX=10
PROBE_INITIAL_DELAY_MIN=5

# progressDeadlineSeconds ceiling — above this ArgoCD considers rollout Degraded
# even for slow-starting apps. 600s = 10 min, matches CLAUDE.md "10 minutes" SLO.
PROGRESS_DEADLINE_MAX=600

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
WARN_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}  $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
skip() { echo -e "  ${YELLOW}SKIP${NC}  $1"; SKIP_COUNT=$((SKIP_COUNT + 1)); }
warn() { echo -e "  ${YELLOW}WARN${NC}  $1"; WARN_COUNT=$((WARN_COUNT + 1)); }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
RUN_OFFLINE=false
RUN_ONLINE=false

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [--offline] [--online]

OPTIONS:
    --offline   Validate git manifests only (no cluster access needed)
    --online    Live cluster checks via kubectl
    --help      Show this help

EXAMPLES:
    $(basename "$0") --offline
    $(basename "$0") --online
    $(basename "$0") --offline --online
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --offline) RUN_OFFLINE=true; shift ;;
    --online)  RUN_ONLINE=true; shift ;;
    --help)    print_usage; exit 0 ;;
    *)         echo "Unknown option: $1"; print_usage; exit 1 ;;
  esac
done

if [[ "$RUN_OFFLINE" == false && "$RUN_ONLINE" == false ]]; then
  echo "ERROR: at least one of --offline or --online is required" >&2
  print_usage
  exit 1
fi

echo "ArgoCD Health Configuration Verifier"
echo "======================================="
echo ""

# ---------------------------------------------------------------------------
# OFFLINE CHECKS — validate git manifests
# ---------------------------------------------------------------------------
if [[ "$RUN_OFFLINE" == true ]]; then
  echo "== Offline checks (git manifests) =="
  echo ""

  # ------------------------------------------------------------------
  # 1. Deployment YAML discovery
  # ------------------------------------------------------------------
  echo "--- Discovering Deployment manifests ---"

  # Exclude patch files under deploy/k8s/base/patches/ and overlays/*/patches/ —
  # those are strategic-merge patches with partial specs (no resources/probes).
  mapfile -t DEPLOYMENT_FILES < <(
    find "${REPO_ROOT}/deploy/k8s/base" -name "*.yaml" \
      -not -path "*/patches/*" \
      -exec grep -l "^kind: Deployment" {} \;
  )

  if [[ ${#DEPLOYMENT_FILES[@]} -eq 0 ]]; then
    fail "no Deployment YAML files found under deploy/k8s/base"
  else
    pass "found ${#DEPLOYMENT_FILES[@]} Deployment manifest(s)"
  fi

  echo ""

  # ------------------------------------------------------------------
  # 2. Per-Deployment: readiness probe present
  # ------------------------------------------------------------------
  echo "--- Readiness probes ---"

  MISSING_READINESS=()
  for f in "${DEPLOYMENT_FILES[@]}"; do
    rel="${f#"${REPO_ROOT}/"}"
    result=$(python3 - "$f" <<'PY'
import sys, yaml

path = sys.argv[1]
try:
    docs = list(yaml.safe_load_all(open(path)))
except Exception:
    print("SKIP:yaml_parse_error")
    sys.exit(0)

for doc in docs:
    if not doc or doc.get('kind') != 'Deployment':
        continue
    containers = doc.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
    for c in containers:
        cname = c.get('name', '?')
        cmd = c.get('command', [])
        # Celery workers run as long-running queue consumers — no HTTP endpoint
        # to probe. Warn instead of fail.
        is_worker = any('celery' in str(arg) for arg in cmd + c.get('args', []))
        if is_worker:
            if not c.get('readinessProbe'):
                print(f"WARN:{cname}:worker container without readinessProbe (expected)")
            else:
                print(f"PASS:{cname}:readinessProbe present")
        else:
            if not c.get('readinessProbe'):
                print(f"FAIL:{cname}:readinessProbe missing on non-worker container")
            else:
                print(f"PASS:{cname}:readinessProbe present")
PY
)
    found_fail=false
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      level="${line%%:*}"
      rest="${line#*:}"
      cname="${rest%%:*}"
      msg="${rest#*:}"
      case "$level" in
        PASS) pass "readinessProbe: ${msg} (${rel})" ;;
        FAIL) fail "readinessProbe: ${msg} (${rel})"; found_fail=true; MISSING_READINESS+=("$rel") ;;
        WARN) warn "readinessProbe: ${msg} (${rel})" ;;
        SKIP) skip "readinessProbe: ${msg} (${rel})" ;;
      esac
    done <<< "$result"
  done

  echo ""

  # ------------------------------------------------------------------
  # 3. Per-Deployment: liveness probe present
  # ------------------------------------------------------------------
  echo "--- Liveness probes ---"

  MISSING_LIVENESS=()
  for f in "${DEPLOYMENT_FILES[@]}"; do
    rel="${f#"${REPO_ROOT}/"}"
    result=$(python3 - "$f" <<'PY'
import sys, yaml

path = sys.argv[1]
try:
    docs = list(yaml.safe_load_all(open(path)))
except Exception:
    print("SKIP:yaml_parse_error")
    sys.exit(0)

for doc in docs:
    if not doc or doc.get('kind') != 'Deployment':
        continue
    containers = doc.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
    for c in containers:
        cname = c.get('name', '?')
        cmd = c.get('command', [])
        is_worker = any('celery' in str(arg) for arg in cmd + c.get('args', []))
        if is_worker:
            if not c.get('livenessProbe'):
                print(f"WARN:{cname}:worker container without livenessProbe (may need exec-based probe)")
            else:
                print(f"PASS:{cname}:livenessProbe present")
        else:
            if not c.get('livenessProbe'):
                print(f"FAIL:{cname}:livenessProbe missing on non-worker container")
            else:
                print(f"PASS:{cname}:livenessProbe present")
PY
)
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      level="${line%%:*}"
      rest="${line#*:}"
      cname="${rest%%:*}"
      msg="${rest#*:}"
      case "$level" in
        PASS) pass "livenessProbe: ${msg} (${rel})" ;;
        FAIL) fail "livenessProbe: ${msg} (${rel})"; MISSING_LIVENESS+=("$rel") ;;
        WARN) warn "livenessProbe: ${msg} (${rel})" ;;
        SKIP) skip "livenessProbe: ${msg} (${rel})" ;;
      esac
    done <<< "$result"
  done

  echo ""

  # ------------------------------------------------------------------
  # 4. Probe endpoint sanity — no obviously non-existent paths
  # ------------------------------------------------------------------
  echo "--- Probe endpoint sanity ---"

  # Known-bad patterns: /healthz on Django services (they use /health/),
  # /ping on non-ClickHouse services, port 80 on services running on 8000+
  SUSPICIOUS_PROBES=()

  for f in "${DEPLOYMENT_FILES[@]}"; do
    rel="${f#"${REPO_ROOT}/"}"
    # Extract httpGet paths used in probes
    probe_paths=$(python3 - "$f" <<'PY'
import sys, re
text = open(sys.argv[1]).read()
# Find all path: values that appear inside readinessProbe or livenessProbe blocks
# Simple heuristic: lines with "path:" that follow a probe keyword
in_probe = False
paths = []
for line in text.splitlines():
    stripped = line.strip()
    if 'readinessProbe:' in stripped or 'livenessProbe:' in stripped:
        in_probe = True
    if in_probe and stripped.startswith('path:'):
        paths.append(stripped.split('path:', 1)[1].strip())
    # Exit probe block on new top-level key (indent level 0 relative)
    if in_probe and stripped and not stripped.startswith('#') and \
       not stripped.startswith('path:') and not stripped.startswith('port:') and \
       not stripped.startswith('http') and not stripped.startswith('initial') and \
       not stripped.startswith('period') and not stripped.startswith('timeout') and \
       not stripped.startswith('failure') and not stripped.startswith('success') and \
       'readinessProbe' not in stripped and 'livenessProbe' not in stripped and \
       'httpGet' not in stripped:
        in_probe = False
print('\n'.join(paths))
PY
)
    while IFS= read -r probe_path; do
      [[ -z "$probe_path" ]] && continue
      # Flag /healthz — Django apps use /health/ (with trailing slash)
      if [[ "$probe_path" == "/healthz" ]]; then
        warn "suspicious probe path '/healthz' (Django uses '/health/'): ${rel}"
        SUSPICIOUS_PROBES+=("$rel:/healthz")
      fi
      # Flag bare / which means the app serves health on root — unusual
      if [[ "$probe_path" == "/" ]]; then
        warn "probe path is '/' (may return 200 even when app is broken): ${rel}"
      fi
    done <<< "$probe_paths"

    if [[ ${#SUSPICIOUS_PROBES[@]} -eq 0 ]]; then
      pass "probe paths look reasonable: ${rel}"
    fi
  done

  echo ""

  # ------------------------------------------------------------------
  # 5. Probe timeout reasonableness
  # ------------------------------------------------------------------
  echo "--- Probe timeout values (timeoutSeconds <= ${PROBE_TIMEOUT_MAX}s, initialDelaySeconds >= ${PROBE_INITIAL_DELAY_MIN}s) ---"

  for f in "${DEPLOYMENT_FILES[@]}"; do
    rel="${f#"${REPO_ROOT}/"}"
    timeout_issues=$(python3 - "$f" "$PROBE_TIMEOUT_MAX" "$PROBE_INITIAL_DELAY_MIN" <<'PY'
import sys, yaml

path = sys.argv[1]
max_timeout = int(sys.argv[2])
min_initial = int(sys.argv[3])
issues = []

try:
    docs = list(yaml.safe_load_all(open(path)))
except Exception:
    sys.exit(0)

for doc in docs:
    if not doc or doc.get('kind') != 'Deployment':
        continue
    containers = doc.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
    for c in containers:
        cname = c.get('name', '?')
        for probe_key in ('readinessProbe', 'livenessProbe'):
            probe = c.get(probe_key, {})
            if not probe:
                continue
            ts = probe.get('timeoutSeconds', 1)
            idt = probe.get('initialDelaySeconds', 0)
            if ts > max_timeout:
                issues.append(f"{cname}.{probe_key}.timeoutSeconds={ts} > ceiling {max_timeout}s")
            if idt < min_initial:
                issues.append(f"{cname}.{probe_key}.initialDelaySeconds={idt} < minimum {min_initial}s")

print('\n'.join(issues))
PY
)
    if [[ -z "$timeout_issues" ]]; then
      pass "probe timeouts reasonable: ${rel}"
    else
      while IFS= read -r issue; do
        [[ -z "$issue" ]] && continue
        fail "probe timeout issue in ${rel}: ${issue}"
      done <<< "$timeout_issues"
    fi
  done

  echo ""

  # ------------------------------------------------------------------
  # 6. progressDeadlineSeconds — prevents stuck rollouts causing Degraded
  # ------------------------------------------------------------------
  echo "--- progressDeadlineSeconds (<= ${PROGRESS_DEADLINE_MAX}s) ---"

  for f in "${DEPLOYMENT_FILES[@]}"; do
    rel="${f#"${REPO_ROOT}/"}"
    pds_check=$(python3 - "$f" "$PROGRESS_DEADLINE_MAX" <<'PY'
import sys, yaml

path = sys.argv[1]
max_pds = int(sys.argv[2])
issues = []

try:
    docs = list(yaml.safe_load_all(open(path)))
except Exception:
    sys.exit(0)

for doc in docs:
    if not doc or doc.get('kind') != 'Deployment':
        continue
    pds = doc.get('spec', {}).get('progressDeadlineSeconds')
    if pds is None:
        # K8s default is 600s — acceptable, but note it
        issues.append(f"UNSET:default=600s")
    elif pds > max_pds:
        issues.append(f"SET_TOO_HIGH:{pds}s > ceiling {max_pds}s")

print('\n'.join(issues))
PY
)
    if [[ -z "$pds_check" ]]; then
      pass "progressDeadlineSeconds set and within ceiling: ${rel}"
    else
      while IFS= read -r issue; do
        [[ -z "$issue" ]] && continue
        case "$issue" in
          UNSET:*)
            # Not a failure — K8s default of 600s is within our ceiling
            skip "progressDeadlineSeconds not set (K8s default 600s applies): ${rel}"
            ;;
          SET_TOO_HIGH:*)
            fail "progressDeadlineSeconds too high in ${rel}: ${issue#SET_TOO_HIGH:}"
            ;;
        esac
      done <<< "$pds_check"
    fi
  done

  echo ""

  # ------------------------------------------------------------------
  # 7. ArgoCD hook annotations — stale status if hook resources linger
  # ------------------------------------------------------------------
  echo "--- ArgoCD hook annotations (argocd.argoproj.io/hook) ---"

  hook_files=$(grep -rl "argocd.argoproj.io/hook" "${REPO_ROOT}/deploy/k8s" 2>/dev/null || true)
  if [[ -z "$hook_files" ]]; then
    pass "no argocd.argoproj.io/hook annotations found (no hook resources to cause stale status)"
  else
    while IFS= read -r hf; do
      rel="${hf#"${REPO_ROOT}/"}"
      hook_type=$(grep "argocd.argoproj.io/hook:" "$hf" | head -1 | awk '{print $2}' || echo "unknown")
      delete_policy=$(grep "argocd.argoproj.io/hook-delete-policy:" "$hf" 2>/dev/null | head -1 | awk '{print $2}' || echo "MISSING")

      if [[ "$delete_policy" == "MISSING" ]]; then
        fail "hook resource missing delete-policy (will cause stale Degraded): ${rel} (hook=${hook_type})"
      else
        pass "hook resource has delete-policy=${delete_policy}: ${rel}"
      fi
    done <<< "$hook_files"
  fi

  echo ""

  # ------------------------------------------------------------------
  # 8. Resource requests/limits — OOMKill → Degraded cycle
  # ------------------------------------------------------------------
  echo "--- Resource requests and limits (OOMKill protection) ---"

  MISSING_RESOURCES=()
  for f in "${DEPLOYMENT_FILES[@]}"; do
    rel="${f#"${REPO_ROOT}/"}"
    resource_issues=$(python3 - "$f" <<'PY'
import sys, yaml

path = sys.argv[1]
issues = []

try:
    docs = list(yaml.safe_load_all(open(path)))
except Exception:
    sys.exit(0)

for doc in docs:
    if not doc or doc.get('kind') != 'Deployment':
        continue
    pod_spec = doc.get('spec', {}).get('template', {}).get('spec', {})
    for c in pod_spec.get('containers', []):
        cname = c.get('name', '?')
        res = c.get('resources', {})
        if not res.get('requests'):
            issues.append(f"{cname}: missing resources.requests")
        if not res.get('limits'):
            issues.append(f"{cname}: missing resources.limits (OOMKill risk)")
        else:
            # Check memory limit is present specifically (CPU throttling != OOMKill)
            mem_limit = res.get('limits', {}).get('memory')
            if not mem_limit:
                issues.append(f"{cname}: missing resources.limits.memory (OOMKill risk)")

print('\n'.join(issues))
PY
)
    if [[ -z "$resource_issues" ]]; then
      pass "resource requests/limits configured: ${rel}"
    else
      while IFS= read -r issue; do
        [[ -z "$issue" ]] && continue
        fail "resource config issue in ${rel}: ${issue}"
        MISSING_RESOURCES+=("$rel")
      done <<< "$resource_issues"
    fi
  done

  echo ""

  # ------------------------------------------------------------------
  # 9. ArgoCD ignore-differences config — prevents false Degraded from
  #    server-side fields ArgoCD can't manage
  # ------------------------------------------------------------------
  echo "--- ArgoCD ignoreDifferences / resource exclusions ---"

  argocd_ignore_patch="${REPO_ROOT}/deploy/k8s/patches/argocd-configmap-ignore.yaml"
  if [[ -f "$argocd_ignore_patch" ]]; then
    pass "argocd-configmap-ignore.yaml exists (resource exclusions configured)"

    # Check it covers known volatile fields
    if grep -q "managedFields\|status\|resourceVersion" "$argocd_ignore_patch" 2>/dev/null; then
      pass "ignoreDifferences covers volatile fields (managedFields/status/resourceVersion)"
    else
      warn "argocd-configmap-ignore.yaml exists but may not cover volatile fields"
    fi
  else
    warn "argocd-configmap-ignore.yaml not found — ArgoCD may report Degraded for server-added fields"
  fi

  echo ""
fi

# ---------------------------------------------------------------------------
# ONLINE CHECKS — live cluster via kubectl
# ---------------------------------------------------------------------------
if [[ "$RUN_ONLINE" == true ]]; then
  echo "== Online checks (live cluster) =="
  echo ""

  if ! command -v kubectl &>/dev/null; then
    fail "kubectl not found in PATH — cannot run online checks"
  else
    pass "kubectl available"
    echo ""

    # ----------------------------------------------------------------
    # 1. ArgoCD app health overview
    # ----------------------------------------------------------------
    echo "--- ArgoCD Application health status ---"

    app_list=$(kubectl get applications -n "$ARGOCD_NAMESPACE" \
      -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

    if [[ -z "$app_list" ]]; then
      skip "no ArgoCD Applications found in namespace '${ARGOCD_NAMESPACE}'"
    else
      for app in $app_list; do
        app_json=$(kubectl get application "$app" -n "$ARGOCD_NAMESPACE" \
          -o json 2>/dev/null || echo "")
        if [[ -z "$app_json" ]]; then
          skip "could not fetch Application ${app}"
          continue
        fi

        health_status=$(echo "$app_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('status', {}).get('health', {}).get('status', 'Unknown'))
" 2>/dev/null || echo "Unknown")

        sync_status=$(echo "$app_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('status', {}).get('sync', {}).get('status', 'Unknown'))
" 2>/dev/null || echo "Unknown")

        if [[ "$health_status" == "Healthy" ]]; then
          pass "app=${app} health=Healthy sync=${sync_status}"
        elif [[ "$health_status" == "Progressing" ]]; then
          warn "app=${app} health=Progressing (rollout in progress) sync=${sync_status}"
        else
          fail "app=${app} health=${health_status} sync=${sync_status}"
        fi
      done
    fi

    echo ""

    # ----------------------------------------------------------------
    # 2. Which resources are Degraded
    # ----------------------------------------------------------------
    echo "--- Degraded resources in ${APP_NAMESPACE} ---"

    for app in $app_list; do
      app_json=$(kubectl get application "$app" -n "$ARGOCD_NAMESPACE" \
        -o json 2>/dev/null || echo "")
      [[ -z "$app_json" ]] && continue

      degraded=$(echo "$app_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
resources = d.get('status', {}).get('resources', [])
for r in resources:
    h = r.get('health', {}).get('status', '')
    if h in ('Degraded', 'Missing', 'Unknown'):
        ns = r.get('namespace', '')
        kind = r.get('kind', '?')
        name = r.get('name', '?')
        msg = r.get('health', {}).get('message', '')
        print(f'{kind}/{name} ({ns}) status={h} msg={msg!r}')
" 2>/dev/null || echo "")

      if [[ -z "$degraded" ]]; then
        pass "app=${app}: no Degraded/Missing/Unknown resources"
      else
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          fail "app=${app}: ${item}"
        done <<< "$degraded"
      fi
    done

    echo ""

    # ----------------------------------------------------------------
    # 3. Pod readiness vs ArgoCD view
    # ----------------------------------------------------------------
    echo "--- Pod readiness in ${APP_NAMESPACE} ---"

    if kubectl get namespace "$APP_NAMESPACE" &>/dev/null 2>&1; then
      not_ready=$(kubectl get pods -n "$APP_NAMESPACE" \
        --field-selector="status.phase!=Succeeded" \
        -o json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
issues = []
for pod in d.get('items', []):
    name = pod['metadata']['name']
    phase = pod.get('status', {}).get('phase', 'Unknown')
    if phase in ('Failed', 'Unknown', 'Pending'):
        issues.append(f'{name}: phase={phase}')
        continue
    conditions = pod.get('status', {}).get('conditions', [])
    for cond in conditions:
        if cond.get('type') == 'Ready' and cond.get('status') != 'True':
            reason = cond.get('reason', '')
            msg = cond.get('message', '')
            issues.append(f'{name}: NotReady reason={reason!r} msg={msg!r}')
for i in issues:
    print(i)
" 2>/dev/null || echo "")

      if [[ -z "$not_ready" ]]; then
        pass "all pods in ${APP_NAMESPACE} are Ready"
      else
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          fail "pod not ready: ${item}"
        done <<< "$not_ready"
      fi
    else
      skip "namespace '${APP_NAMESPACE}' not found"
    fi

    echo ""

    # ----------------------------------------------------------------
    # 4. Pending rollouts / stuck ReplicaSets
    # ----------------------------------------------------------------
    echo "--- Stuck rollouts (pending ReplicaSets) ---"

    if kubectl get namespace "$APP_NAMESPACE" &>/dev/null 2>&1; then
      stuck=$(kubectl get deployments -n "$APP_NAMESPACE" -o json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
issues = []
for dep in d.get('items', []):
    name = dep['metadata']['name']
    spec_replicas = dep.get('spec', {}).get('replicas', 1)
    status = dep.get('status', {})
    ready = status.get('readyReplicas', 0)
    available = status.get('availableReplicas', 0)
    updated = status.get('updatedReplicas', 0)
    # Detect incomplete rollout: updatedReplicas != spec replicas
    if updated is not None and updated < spec_replicas:
        issues.append(f'{name}: rollout incomplete updated={updated}/{spec_replicas}')
    # Detect readiness deficit
    if ready is not None and ready < spec_replicas:
        issues.append(f'{name}: insufficient ready replicas ready={ready}/{spec_replicas}')
for i in issues:
    print(i)
" 2>/dev/null || echo "")

      if [[ -z "$stuck" ]]; then
        pass "all Deployments in ${APP_NAMESPACE} have expected replicas ready"
      else
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          fail "stuck rollout: ${item}"
        done <<< "$stuck"
      fi
    else
      skip "namespace '${APP_NAMESPACE}' not found"
    fi

    echo ""

    # ----------------------------------------------------------------
    # 5. OOMKill events in the last hour
    # ----------------------------------------------------------------
    echo "--- OOMKill events (last hour) ---"

    if kubectl get namespace "$APP_NAMESPACE" &>/dev/null 2>&1; then
      oomkill_events=$(kubectl get events -n "$APP_NAMESPACE" \
        --field-selector="reason=OOMKilling" \
        -o json 2>/dev/null | python3 -c "
import sys, json
from datetime import datetime, timezone, timedelta
d = json.load(sys.stdin)
cutoff = datetime.now(timezone.utc) - timedelta(hours=1)
recent = []
for ev in d.get('items', []):
    ts_str = ev.get('lastTimestamp') or ev.get('eventTime') or ''
    name = ev.get('involvedObject', {}).get('name', '?')
    msg = ev.get('message', '')
    try:
        ts = datetime.fromisoformat(ts_str.rstrip('Z')).replace(tzinfo=timezone.utc)
        if ts >= cutoff:
            recent.append(f'{name}: {msg}')
    except Exception:
        pass
for r in recent:
    print(r)
" 2>/dev/null || echo "")

      if [[ -z "$oomkill_events" ]]; then
        pass "no OOMKill events in ${APP_NAMESPACE} in the last hour"
      else
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          fail "OOMKill event: ${item}"
        done <<< "$oomkill_events"
      fi
    else
      skip "namespace '${APP_NAMESPACE}' not found"
    fi

    echo ""
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "======================================="
echo "Summary"
echo "======================================="
echo -e "  ${GREEN}Passed${NC}:   ${PASS_COUNT}"
echo -e "  ${RED}Failed${NC}:   ${FAIL_COUNT}"
echo -e "  ${YELLOW}Skipped${NC}:  ${SKIP_COUNT}"
echo -e "  ${YELLOW}Warnings${NC}: ${WARN_COUNT}"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "See docs/ops/runbooks/ARGOCD_HEALTH_TROUBLESHOOTING.md for remediation steps."
  exit 1
fi
exit 0
