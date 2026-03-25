#!/usr/bin/env bash
# Release Gate — Mereka LMS
# Canonical release verification entrypoint for Phase 2 deployment contract.
#
# Usage:
#   scripts/release/release-gate.sh [--overlay <path>] [--skip-cluster]
#
# Flags:
#   --overlay <path>   Path to Kustomize overlay to check (default: deploy/k8s/base)
#   --skip-cluster     Skip checks that require a live Kubernetes cluster
#
# Exit codes:
#   0  All gates PASS
#   1  One or more gates FAIL
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# ── Colours ───────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Arg parsing ───────────────────────────────────────────────────────────
OVERLAY="deploy/k8s/base"
SKIP_CLUSTER=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --overlay)
      OVERLAY="${2:?--overlay requires a path}"
      shift 2
      ;;
    --skip-cluster)
      SKIP_CLUSTER=true
      shift
      ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: $0 [--overlay <path>] [--skip-cluster]" >&2
      exit 1
      ;;
  esac
done

# ── Counters ──────────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0
WARN=0

pass()  { echo -e "${GREEN}[PASS]${NC} $*"; PASS=$((PASS + 1)); }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; FAIL=$((FAIL + 1)); }
skip()  { echo -e "${YELLOW}[SKIP]${NC} $*"; SKIP=$((SKIP + 1)); }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; WARN=$((WARN + 1)); }
info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
header(){ echo -e "\n${BOLD}=== $* ===${NC}"; }

CONTRACT="deploy/k8s/contract.json"
REGISTRY="deploy/k8s/migrations/registry.yaml"
EXTERNAL_SECRETS_DIR="deploy/k8s/base"

# ── Gate 1: Manifests render ──────────────────────────────────────────────
header "Gate 1: Kustomize Render"

if ! command -v kubectl &>/dev/null; then
  skip "kubectl not found — cannot render manifests"
else
  if kubectl kustomize "$OVERLAY" >/dev/null 2>&1; then
    pass "kubectl kustomize $OVERLAY renders without error"
  else
    fail "kubectl kustomize $OVERLAY failed to render"
    info "Run: kubectl kustomize $OVERLAY to see errors"
  fi
fi

# ── Gate 2: Contract validation ───────────────────────────────────────────
header "Gate 2: Deployment Contract Validation"

CONTRACT_SCRIPT="scripts/qa/verify-deployment-contract.sh"
if [[ -x "$CONTRACT_SCRIPT" ]]; then
  if bash "$CONTRACT_SCRIPT" >/dev/null 2>&1; then
    pass "$CONTRACT_SCRIPT passed"
  else
    fail "$CONTRACT_SCRIPT failed"
    info "Run: bash $CONTRACT_SCRIPT for details"
  fi
else
  skip "$CONTRACT_SCRIPT not found or not executable"
fi

# ── Gate 3: Migration registry validation ────────────────────────────────
header "Gate 3: Migration Registry Validation"

if [[ ! -f "$REGISTRY" ]]; then
  fail "Migration registry not found: $REGISTRY"
else
  pass "Migration registry exists: $REGISTRY"

  # Validate YAML is parseable
  if python3 -c "import yaml; yaml.safe_load(open('$REGISTRY'))" 2>/dev/null; then
    pass "Migration registry is valid YAML"
  else
    fail "Migration registry has invalid YAML"
  fi

  # Validate required fields on each service entry
  REQUIRED_FIELDS="name schema_owner database migration_command health_endpoint health_port release_critical"
  REGISTRY_ERRORS=0
  SVC_COUNT=0

  while IFS= read -r svc_name; do
    SVC_COUNT=$((SVC_COUNT + 1))
    for field in $REQUIRED_FIELDS; do
      val=$(python3 - <<PYEOF 2>/dev/null
import yaml
reg = yaml.safe_load(open('$REGISTRY'))
svcs = [s for s in reg.get('services', []) if s.get('name') == '$svc_name']
if svcs:
    v = svcs[0].get('$field')
    print('' if v is None else str(v))
PYEOF
)
      if [[ -z "$val" || "$val" == "None" ]]; then
        fail "Service '$svc_name' missing required field: $field"
        REGISTRY_ERRORS=$((REGISTRY_ERRORS + 1))
      fi
    done
  done < <(python3 -c "
import yaml
reg = yaml.safe_load(open('$REGISTRY'))
for s in reg.get('services', []):
    print(s['name'])
" 2>/dev/null)

  if [[ $SVC_COUNT -eq 0 ]]; then
    fail "Migration registry has no services defined"
  elif [[ $REGISTRY_ERRORS -eq 0 ]]; then
    pass "All $SVC_COUNT services in registry have required fields"
  fi
fi

# ── Gate 4: Image pin check ───────────────────────────────────────────────
header "Gate 4: Image Pin Check (overlay: $OVERLAY)"

if ! command -v kubectl &>/dev/null; then
  skip "kubectl not found — cannot render overlay for pin check"
elif [[ "$OVERLAY" == *"/base" || "$OVERLAY" == *"/base/" ]]; then
  # Base is expected to have pin-required — it's the sentinel.
  # Only check real environment overlays.
  skip "Base overlay uses pin-required by design — pass --overlay <env-overlay> to check pins"
else
  PIN_SENTINEL="pin-required"
  if kubectl kustomize "$OVERLAY" 2>/dev/null | grep -q "$PIN_SENTINEL"; then
    PINNED_LINES=$(kubectl kustomize "$OVERLAY" 2>/dev/null | grep "$PIN_SENTINEL" || true)
    fail "Sentinel tag '$PIN_SENTINEL' found in overlay '$OVERLAY'"
    echo "$PINNED_LINES" | while IFS= read -r line; do
      info "  $line"
    done
  else
    pass "No '$PIN_SENTINEL' sentinel tags found in overlay '$OVERLAY'"
  fi
fi

# ── Gate 5: Secret key completeness ──────────────────────────────────────
header "Gate 5: Secret Key Completeness"

if [[ ! -f "$CONTRACT" ]]; then
  skip "contract.json not found — cannot check secret keys"
elif [[ ! -d "$EXTERNAL_SECRETS_DIR" ]]; then
  skip "ExternalSecrets base dir not found at $EXTERNAL_SECRETS_DIR — skipping"
else
  # Collect all keys declared in contract.json required_secrets
  CONTRACT_KEYS=$(python3 -c "
import json
c = json.load(open('$CONTRACT'))
for s in c.get('required_secrets', []):
    for k in s.get('keys', []):
        print(k)
" 2>/dev/null | sort -u)

  # Collect all secretKey values from all ExternalSecret manifests under base/
  # (the K8s secret key name, which is what contract.json required_secrets[].keys[] lists)
  ES_KEYS=$(python3 - <<PYEOF 2>/dev/null | sort -u
import os, yaml

base_dir = "$EXTERNAL_SECRETS_DIR"
for dirpath, _, filenames in os.walk(base_dir):
    for fname in filenames:
        if not fname.endswith((".yaml", ".yml")):
            continue
        fpath = os.path.join(dirpath, fname)
        try:
            with open(fpath) as f:
                for doc in yaml.safe_load_all(f):
                    if not doc or doc.get("kind") != "ExternalSecret":
                        continue
                    spec = doc.get("spec", {})
                    for d in spec.get("data", []):
                        key = d.get("secretKey", "")
                        if key:
                            print(key)
        except Exception:
            pass
PYEOF
)

  MISSING_COUNT=0
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    if ! echo "$ES_KEYS" | grep -qxF "$key"; then
      fail "Secret key '$key' in contract.json has no ExternalSecret entry"
      MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
  done <<< "$CONTRACT_KEYS"

  TOTAL_KEYS=$(echo "$CONTRACT_KEYS" | grep -c . || true)
  if [[ $MISSING_COUNT -eq 0 ]]; then
    pass "All $TOTAL_KEYS contract secret keys have ExternalSecret entries"
  else
    info "$MISSING_COUNT/$TOTAL_KEYS keys missing from ExternalSecret"
  fi
fi

# ── Cluster-gated checks ──────────────────────────────────────────────────
if [[ "$SKIP_CLUSTER" == "true" ]]; then
  info "Skipping cluster-dependent checks (--skip-cluster)"
else
  header "Gate 6: Cluster Connectivity (live)"
  if ! command -v kubectl &>/dev/null; then
    skip "kubectl not found"
  elif ! kubectl cluster-info &>/dev/null 2>&1; then
    skip "No live cluster reachable — use --skip-cluster if running offline"
  else
    NAMESPACE=$(python3 -c "import json; print(json.load(open('$CONTRACT')).get('namespace','mereka-lms'))" 2>/dev/null || echo "mereka-lms")
    if kubectl get namespace "$NAMESPACE" &>/dev/null 2>&1; then
      pass "Namespace '$NAMESPACE' exists in live cluster"
    else
      fail "Namespace '$NAMESPACE' not found in live cluster"
    fi
  fi
fi

# ── Gate 7: Contract bundle version consistency ───────────────────────────
header "Gate 7: Contract Bundle Version"

VERSION_FILE="deploy/k8s/VERSION"
if [[ -f "$CONTRACT" ]] && [[ -f "$VERSION_FILE" ]]; then
  CONTRACT_VER=$(python3 -c "import json; print(json.load(open('$CONTRACT'))['version'])" 2>/dev/null || true)
  FILE_VER=$(tr -d '[:space:]' < "$VERSION_FILE")
  if [[ -z "$CONTRACT_VER" ]]; then
    fail "contract.json is missing 'version' field"
  elif [[ "$CONTRACT_VER" == "$FILE_VER" ]]; then
    pass "Contract v$CONTRACT_VER matches VERSION file"
  else
    fail "Contract version mismatch: contract.json=$CONTRACT_VER, VERSION=$FILE_VER"
  fi
else
  if [[ ! -f "$CONTRACT" ]] && [[ ! -f "$VERSION_FILE" ]]; then
    skip "Contract bundle incomplete (missing contract.json and VERSION)"
  elif [[ ! -f "$CONTRACT" ]]; then
    skip "contract.json not found — skipping version consistency check"
  else
    skip "VERSION file not found at $VERSION_FILE — skipping version consistency check"
  fi
fi

# ── Gate 8: Boundary audit (advisory) ─────────────────────────────────────
header "Gate 8: Deployment Boundary Audit (ADR-025)"

BOUNDARY_WARNS=0
for platform_dir in arc logging policies; do
  if [[ -d "$REPO_ROOT/deploy/k8s/base/$platform_dir" ]]; then
    warn "Platform resource still in app repo: deploy/k8s/base/$platform_dir (ADR-025 Phase 3 — migrate to bbi-infrastructure)"
    BOUNDARY_WARNS=$((BOUNDARY_WARNS + 1))
  fi
done
if [[ $BOUNDARY_WARNS -eq 0 ]]; then
  pass "No platform-shared resources found in app repo (ADR-025 compliant)"
fi

# ── Proof artifact ────────────────────────────────────────────────────────
PROOF_DIR="$REPO_ROOT/var/proof"
mkdir -p "$PROOF_DIR"
VERDICT="pass"
[[ $FAIL -gt 0 ]] && VERDICT="fail"
# Closure level: "runtime" when cluster checks ran, "static" when skipped.
# Convergence gates MUST require closure_level=runtime for canonical closure.
# A "pass" with closure_level=static is NOT canonical runtime proof.
CLOSURE_LEVEL="runtime"
[[ "$SKIP_CLUSTER" == "true" ]] && CLOSURE_LEVEL="static"
cat > "$PROOF_DIR/release-gate.json" <<PROOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "sha": "$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")",
  "overlay": "$OVERLAY",
  "skip_cluster": $SKIP_CLUSTER,
  "closure_level": "$CLOSURE_LEVEL",
  "gates_pass": $PASS,
  "gates_fail": $FAIL,
  "gates_warn": $WARN,
  "gates_skip": $SKIP,
  "verdict": "$VERDICT"
}
PROOF
info "Proof artifact written: $PROOF_DIR/release-gate.json"

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━ Release Gate Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}PASS${NC}  $PASS"
echo -e "  ${YELLOW}SKIP${NC}  $SKIP"
echo -e "  ${YELLOW}WARN${NC}  $WARN"
echo -e "  ${RED}FAIL${NC}  $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}${BOLD}RESULT: FAIL — $FAIL gate(s) failed. Do not release.${NC}"
  exit 1
else
  echo -e "${GREEN}${BOLD}RESULT: PASS — All gates passed. Release may proceed.${NC}"
  exit 0
fi
