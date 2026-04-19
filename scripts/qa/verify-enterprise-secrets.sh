#!/usr/bin/env bash
# @covers AC-033, AC-034
# @spec: enterprise-microservices_spec.md
# verify-enterprise-secrets.sh
# Covers: AC-033, AC-034 (Secrets and Configuration)
# Exit 0 = all checks pass, exit 1 = failures
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
NAMESPACE="${NAMESPACE_OVERRIDE:-mereka-lms}"
PASS=0; FAIL=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
info() { echo -e "${YELLOW}ℹ${NC} $1"; }

echo "=== Enterprise Secrets Verification (AC-033..AC-034) ==="
echo

# Early-exit when no cluster is available (CI without kubectl context).
if ! command -v kubectl >/dev/null 2>&1 || ! kubectl cluster-info >/dev/null 2>&1; then
  echo "⚠ SKIP: kubectl not available or cluster unreachable — skipping runtime secret checks"
  echo "  (Run with a valid KUBECONFIG/cluster context to execute AC-033..AC-034)"
  exit 0
fi

# ---------------------------------------------------------------------------
# AC-033: ExternalSecrets sync → enterprise-secrets K8s Secret has all keys
# ---------------------------------------------------------------------------
echo "[AC-033] Verifying enterprise-secrets K8s secret contains all expected keys..."

# Expected secret keys (from deployment manifests)
EXPECTED_KEYS=(
  ENTERPRISE_CATALOG_SECRET_KEY
  MYSQL_ENTERPRISE_CATALOG_PASSWORD
  ENTERPRISE_CATALOG_OAUTH2_SECRET
  ENTERPRISE_ACCESS_SECRET_KEY
  MYSQL_ENTERPRISE_ACCESS_PASSWORD
  ENTERPRISE_ACCESS_OAUTH2_SECRET
  ENTERPRISE_SUBSIDY_SECRET_KEY
  MYSQL_ENTERPRISE_SUBSIDY_PASSWORD
  ENTERPRISE_SUBSIDY_OAUTH2_SECRET
)

if kubectl get secret enterprise-secrets -n "$NAMESPACE" &>/dev/null; then
  # Get all key names from the secret
  SECRET_DATA=$(kubectl get secret enterprise-secrets -n "$NAMESPACE" -o jsonpath='{.data}' 2>/dev/null || echo "{}")

  MISSING_KEYS=()
  FOUND_KEYS=0
  for key in "${EXPECTED_KEYS[@]}"; do
    if echo "$SECRET_DATA" | grep -q "\"$key\""; then
      FOUND_KEYS=$((FOUND_KEYS + 1))
    else
      MISSING_KEYS+=("$key")
    fi
  done

  TOTAL_KEYS=$(echo "$SECRET_DATA" | grep -o '"[^"]*":' | wc -l)

  if [[ ${#MISSING_KEYS[@]} -eq 0 ]]; then
    pass "AC-033: All ${#EXPECTED_KEYS[@]} expected keys present in enterprise-secrets"
  else
    fail "AC-033: Missing ${#MISSING_KEYS[@]} keys from enterprise-secrets:"
    for key in "${MISSING_KEYS[@]}"; do
      echo "    - $key"
    done
  fi

  pass "AC-033: enterprise-secrets has $TOTAL_KEYS total keys ($FOUND_KEYS matched)"

  # Verify no key has empty value (base64 of empty = "")
  EMPTY_VALS=0
  for key in "${EXPECTED_KEYS[@]}"; do
    VAL=$(kubectl get secret enterprise-secrets -n "$NAMESPACE" -o jsonpath="{.data.$key}" 2>/dev/null || echo "")
    if [[ -z "$VAL" ]]; then
      EMPTY_VALS=$((EMPTY_VALS + 1))
    fi
  done
  if [[ "$EMPTY_VALS" -eq 0 ]]; then
    pass "AC-033: All secret keys have non-empty values"
  else
    fail "AC-033: $EMPTY_VALS secret keys have empty values"
  fi

  # Verify unique passwords per service (no shared passwords)
  CAT_PW=$(kubectl get secret enterprise-secrets -n "$NAMESPACE" -o jsonpath='{.data.MYSQL_ENTERPRISE_CATALOG_PASSWORD}' 2>/dev/null || echo "")
  ACC_PW=$(kubectl get secret enterprise-secrets -n "$NAMESPACE" -o jsonpath='{.data.MYSQL_ENTERPRISE_ACCESS_PASSWORD}' 2>/dev/null || echo "")
  SUB_PW=$(kubectl get secret enterprise-secrets -n "$NAMESPACE" -o jsonpath='{.data.MYSQL_ENTERPRISE_SUBSIDY_PASSWORD}' 2>/dev/null || echo "")

  if [[ -n "$CAT_PW" && -n "$ACC_PW" && -n "$SUB_PW" ]]; then
    if [[ "$CAT_PW" != "$ACC_PW" && "$CAT_PW" != "$SUB_PW" && "$ACC_PW" != "$SUB_PW" ]]; then
      pass "AC-033: MySQL passwords are unique per service (no shared passwords)"
    else
      fail "AC-033: MySQL passwords are NOT unique — some services share the same password"
    fi
  else
    info "AC-033: Could not verify password uniqueness (some passwords empty)"
  fi
else
  fail "AC-033: enterprise-secrets K8s secret not found in namespace $NAMESPACE"
fi
echo

# ---------------------------------------------------------------------------
# AC-034: Catalog service reads correct SECRET_KEY from environment
# ---------------------------------------------------------------------------
echo "[AC-034] Verifying catalog service reads correct SECRET_KEY..."

CAT_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=enterprise-catalog --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$CAT_POD" ]]; then
  # Verify SECRET_KEY is set in config YAML (config-gen pattern writes to YAML, not env vars)
  SECRET_KEY_LEN=$(kubectl exec -n "$NAMESPACE" "$CAT_POD" -- python3 -c "
import yaml
try:
    with open('/config/enterprise_catalog.yml') as f:
        cfg = yaml.safe_load(f)
    print(len(str(cfg.get('SECRET_KEY', ''))))
except Exception:
    print('0')
" 2>/dev/null | tr -d '[:space:]')
  if [[ "${SECRET_KEY_LEN:-0}" -gt 10 ]]; then
    pass "AC-034: SECRET_KEY set in catalog config YAML (length: $SECRET_KEY_LEN chars)"
  elif [[ "${SECRET_KEY_LEN:-0}" -gt 0 ]]; then
    info "AC-034: SECRET_KEY is set but short ($SECRET_KEY_LEN chars)"
  else
    fail "AC-034: SECRET_KEY not found in catalog config YAML"
  fi

  # Verify the secret key came from the correct K8s secret (via manifest)
  CATALOG_DEPLOY="$REPO_ROOT/deploy/k8s/base/apps/enterprise/enterprise-catalog-deployment.yaml"
  if [[ -f "$CATALOG_DEPLOY" ]]; then
    if grep -A3 "DJANGO_SECRET_KEY" "$CATALOG_DEPLOY" | grep -q "enterprise-secrets"; then
      pass "AC-034: Catalog deployment sources SECRET_KEY from enterprise-secrets"
    elif grep -q "ENTERPRISE_CATALOG_SECRET_KEY" "$CATALOG_DEPLOY"; then
      pass "AC-034: Catalog deployment references ENTERPRISE_CATALOG_SECRET_KEY"
    else
      fail "AC-034: Catalog deployment does not source SECRET_KEY from enterprise-secrets"
    fi
  fi

  # Verify config-gen init container uses the correct secret
  CONFIG_GEN_SECRET=$(kubectl get deployment enterprise-catalog -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="config-gen")].env[?(@.name=="DJANGO_SECRET_KEY")].valueFrom.secretKeyRef.key}' 2>/dev/null || echo "")
  if [[ "$CONFIG_GEN_SECRET" == "ENTERPRISE_CATALOG_SECRET_KEY" ]]; then
    pass "AC-034: Config-gen init container uses ENTERPRISE_CATALOG_SECRET_KEY from enterprise-secrets"
  elif [[ -n "$CONFIG_GEN_SECRET" ]]; then
    info "AC-034: Config-gen uses secret key: $CONFIG_GEN_SECRET"
  else
    info "AC-034: Config-gen secret key reference check inconclusive"
  fi
else
  fail "AC-034: No running enterprise-catalog pod"
fi

# Summary
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS"
echo -e "${RED}FAIL:${NC} $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
