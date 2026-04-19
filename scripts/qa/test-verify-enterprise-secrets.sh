#!/usr/bin/env bash
# Seeded-defect self-test for verify-enterprise-secrets.sh.
# Pattern: COMBO (fake-kubectl-in-PATH + tempdir fixture-tree + env-override)
# Fixtures:
#   1. all keys present + non-empty + unique passwords → expect pass
#   2. missing required key in secret data → expect fail
#   3. empty value for a secret key → expect fail
#   4. catalog deployment YAML missing enterprise-secrets reference → expect fail
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-enterprise-secrets.sh"

tmpdir="$(mktemp -d -t verify-enterprise-secrets.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

FAKEBIN="$tmpdir/bin"
mkdir -p "$FAKEBIN"
mkdir -p "$tmpdir/deploy/k8s/base/apps/enterprise"

OUTFILE="$tmpdir/verify.out"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
fail() {
  echo "[FAIL] $1" >&2
  cat "$OUTFILE" >&2 || true
  exit 1
}

pass() { echo "[PASS] $1"; }

run_expect_pass() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" NAMESPACE_OVERRIDE="test-ns" \
    PATH="$FAKEBIN:$PATH" \
    bash "$VERIFY" >"$OUTFILE" 2>&1
  local rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || fail "$label: expected exit 0, got $rc"
  pass "$label"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" NAMESPACE_OVERRIDE="test-ns" \
    PATH="$FAKEBIN:$PATH" \
    bash "$VERIFY" >"$OUTFILE" 2>&1
  local rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || fail "$label: expected non-zero exit but got 0"
  pass "$label"
}

write_good_catalog_deploy() {
  cat >"$tmpdir/deploy/k8s/base/apps/enterprise/enterprise-catalog-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: enterprise-catalog
spec:
  template:
    spec:
      initContainers:
        - name: config-gen
          env:
            - name: DJANGO_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: enterprise-secrets
                  key: ENTERPRISE_CATALOG_SECRET_KEY
YAML
}

write_bad_catalog_deploy() {
  cat >"$tmpdir/deploy/k8s/base/apps/enterprise/enterprise-catalog-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: enterprise-catalog
spec:
  template:
    spec:
      containers:
        - name: enterprise-catalog
          env:
            - name: DJANGO_SECRET_KEY
              value: hardcoded-bad-value
YAML
}

# The full 9-key JSON data blob (all keys present)
ALL_KEYS_JSON='{"ENTERPRISE_CATALOG_SECRET_KEY":"dGVzdA==","MYSQL_ENTERPRISE_CATALOG_PASSWORD":"Y2F0cGFzcw==","ENTERPRISE_CATALOG_OAUTH2_SECRET":"dGVzdA==","ENTERPRISE_ACCESS_SECRET_KEY":"dGVzdA==","MYSQL_ENTERPRISE_ACCESS_PASSWORD":"YWNjcGFzcw==","ENTERPRISE_ACCESS_OAUTH2_SECRET":"dGVzdA==","ENTERPRISE_SUBSIDY_SECRET_KEY":"dGVzdA==","MYSQL_ENTERPRISE_SUBSIDY_PASSWORD":"c3VicGFzcw==","ENTERPRISE_SUBSIDY_OAUTH2_SECRET":"dGVzdA=="}'

# Note: jsonpath args arrive in $* WITHOUT shell quotes, e.g.:
#   get secret enterprise-secrets -n test-ns -o jsonpath={.data}
#   get secret enterprise-secrets -n test-ns -o jsonpath={.data.KEY}

# ---------------------------------------------------------------------------
# Fixture 1: all keys present, non-empty, unique passwords, valid deploy YAML
# AC-034 pod path skipped (empty pod name) so only YAML file check runs there.
# ---------------------------------------------------------------------------
write_good_catalog_deploy

cat >"$FAKEBIN/kubectl" <<KEOF
#!/usr/bin/env bash
set -euo pipefail
ARGS="\$*"
if [[ "\${1:-}" == "cluster-info" ]]; then
  echo "Kubernetes control plane is running"; exit 0
fi
# existence check (no jsonpath arg)
if [[ "\${1:-}" == "get" && "\${2:-}" == "secret" && "\${3:-}" == "enterprise-secrets" ]] && \
   [[ "\$ARGS" != *"jsonpath"* ]]; then
  exit 0
fi
# .data blob
if [[ "\${1:-}" == "get" && "\${2:-}" == "secret" && "\$ARGS" == *"jsonpath={.data}"* ]] && \
   [[ "\$ARGS" != *"jsonpath={.data."* ]]; then
  printf '%s' '$ALL_KEYS_JSON'; exit 0
fi
# per-key lookup
if [[ "\${1:-}" == "get" && "\${2:-}" == "secret" && "\$ARGS" == *"jsonpath={.data."* ]]; then
  case "\$ARGS" in
    *MYSQL_ENTERPRISE_CATALOG_PASSWORD*) printf "Y2F0cGFzcw=="; exit 0 ;;
    *MYSQL_ENTERPRISE_ACCESS_PASSWORD*)  printf "YWNjcGFzcw=="; exit 0 ;;
    *MYSQL_ENTERPRISE_SUBSIDY_PASSWORD*) printf "c3VicGFzcw=="; exit 0 ;;
    *)  printf "dGVzdA=="; exit 0 ;;
  esac
fi
# pod lookup → return a pod name so AC-034 proceeds to YAML file check
if [[ "\${1:-}" == "get" && "\${2:-}" == "pods" ]]; then printf "catalog-pod-ok"; exit 0; fi
# python3 exec for SECRET_KEY length → return >10
if [[ "\${1:-}" == "exec" ]]; then printf "32"; exit 0; fi
# deployment get (config-gen secret ref check)
if [[ "\${1:-}" == "get" && "\${2:-}" == "deployment" ]]; then printf ""; exit 0; fi
echo "unexpected kubectl: \$ARGS" >&2; exit 1
KEOF
chmod +x "$FAKEBIN/kubectl"

run_expect_pass "all keys present with unique passwords and valid deployment YAML"

# ---------------------------------------------------------------------------
# Fixture 2: ENTERPRISE_SUBSIDY_OAUTH2_SECRET absent from .data
# ---------------------------------------------------------------------------
MISSING_KEY_JSON='{"ENTERPRISE_CATALOG_SECRET_KEY":"dGVzdA==","MYSQL_ENTERPRISE_CATALOG_PASSWORD":"Y2F0cGFzcw==","ENTERPRISE_CATALOG_OAUTH2_SECRET":"dGVzdA==","ENTERPRISE_ACCESS_SECRET_KEY":"dGVzdA==","MYSQL_ENTERPRISE_ACCESS_PASSWORD":"YWNjcGFzcw==","ENTERPRISE_ACCESS_OAUTH2_SECRET":"dGVzdA==","ENTERPRISE_SUBSIDY_SECRET_KEY":"dGVzdA==","MYSQL_ENTERPRISE_SUBSIDY_PASSWORD":"c3VicGFzcw=="}'

cat >"$FAKEBIN/kubectl" <<KEOF
#!/usr/bin/env bash
set -euo pipefail
ARGS="\$*"
if [[ "\${1:-}" == "cluster-info" ]]; then echo "running"; exit 0; fi
if [[ "\${1:-}" == "get" && "\${2:-}" == "secret" && "\${3:-}" == "enterprise-secrets" ]] && \
   [[ "\$ARGS" != *"jsonpath"* ]]; then exit 0; fi
if [[ "\${1:-}" == "get" && "\${2:-}" == "secret" && "\$ARGS" == *"jsonpath={.data}"* ]] && \
   [[ "\$ARGS" != *"jsonpath={.data."* ]]; then
  printf '%s' '$MISSING_KEY_JSON'; exit 0
fi
if [[ "\${1:-}" == "get" && "\${2:-}" == "secret" && "\$ARGS" == *"jsonpath={.data."* ]]; then
  case "\$ARGS" in
    *MYSQL_ENTERPRISE_CATALOG_PASSWORD*) printf "Y2F0cGFzcw=="; exit 0 ;;
    *MYSQL_ENTERPRISE_ACCESS_PASSWORD*)  printf "YWNjcGFzcw=="; exit 0 ;;
    *MYSQL_ENTERPRISE_SUBSIDY_PASSWORD*) printf "c3VicGFzcw=="; exit 0 ;;
    *) printf "dGVzdA=="; exit 0 ;;
  esac
fi
if [[ "\${1:-}" == "get" && "\${2:-}" == "pods" ]]; then printf ""; exit 0; fi
echo "unexpected kubectl: \$ARGS" >&2; exit 1
KEOF
chmod +x "$FAKEBIN/kubectl"

run_expect_fail "missing ENTERPRISE_SUBSIDY_OAUTH2_SECRET key is rejected"

# ---------------------------------------------------------------------------
# Fixture 3: ENTERPRISE_CATALOG_SECRET_KEY present in .data but empty value
# ---------------------------------------------------------------------------
cat >"$FAKEBIN/kubectl" <<KEOF
#!/usr/bin/env bash
set -euo pipefail
ARGS="\$*"
if [[ "\${1:-}" == "cluster-info" ]]; then echo "running"; exit 0; fi
if [[ "\${1:-}" == "get" && "\${2:-}" == "secret" && "\${3:-}" == "enterprise-secrets" ]] && \
   [[ "\$ARGS" != *"jsonpath"* ]]; then exit 0; fi
if [[ "\${1:-}" == "get" && "\${2:-}" == "secret" && "\$ARGS" == *"jsonpath={.data}"* ]] && \
   [[ "\$ARGS" != *"jsonpath={.data."* ]]; then
  printf '%s' '$ALL_KEYS_JSON'; exit 0
fi
if [[ "\${1:-}" == "get" && "\${2:-}" == "secret" && "\$ARGS" == *"jsonpath={.data."* ]]; then
  case "\$ARGS" in
    # ENTERPRISE_CATALOG_SECRET_KEY → empty value triggers AC-033 empty-value fail
    *ENTERPRISE_CATALOG_SECRET_KEY*) printf ""; exit 0 ;;
    *MYSQL_ENTERPRISE_CATALOG_PASSWORD*) printf "Y2F0cGFzcw=="; exit 0 ;;
    *MYSQL_ENTERPRISE_ACCESS_PASSWORD*)  printf "YWNjcGFzcw=="; exit 0 ;;
    *MYSQL_ENTERPRISE_SUBSIDY_PASSWORD*) printf "c3VicGFzcw=="; exit 0 ;;
    *) printf "dGVzdA=="; exit 0 ;;
  esac
fi
if [[ "\${1:-}" == "get" && "\${2:-}" == "pods" ]]; then printf ""; exit 0; fi
echo "unexpected kubectl: \$ARGS" >&2; exit 1
KEOF
chmod +x "$FAKEBIN/kubectl"

run_expect_fail "empty ENTERPRISE_CATALOG_SECRET_KEY value is rejected"

# ---------------------------------------------------------------------------
# Fixture 4: all AC-033 checks pass; catalog deployment YAML has no reference
# to enterprise-secrets → AC-034 YAML file check must fail.
# A pod name is returned so the AC-034 file-check branch is actually reached.
# ---------------------------------------------------------------------------
write_bad_catalog_deploy

cat >"$FAKEBIN/kubectl" <<KEOF
#!/usr/bin/env bash
set -euo pipefail
ARGS="\$*"
if [[ "\${1:-}" == "cluster-info" ]]; then echo "running"; exit 0; fi
if [[ "\${1:-}" == "get" && "\${2:-}" == "secret" && "\${3:-}" == "enterprise-secrets" ]] && \
   [[ "\$ARGS" != *"jsonpath"* ]]; then exit 0; fi
if [[ "\${1:-}" == "get" && "\${2:-}" == "secret" && "\$ARGS" == *"jsonpath={.data}"* ]] && \
   [[ "\$ARGS" != *"jsonpath={.data."* ]]; then
  printf '%s' '$ALL_KEYS_JSON'; exit 0
fi
if [[ "\${1:-}" == "get" && "\${2:-}" == "secret" && "\$ARGS" == *"jsonpath={.data."* ]]; then
  case "\$ARGS" in
    *MYSQL_ENTERPRISE_CATALOG_PASSWORD*) printf "Y2F0cGFzcw=="; exit 0 ;;
    *MYSQL_ENTERPRISE_ACCESS_PASSWORD*)  printf "YWNjcGFzcw=="; exit 0 ;;
    *MYSQL_ENTERPRISE_SUBSIDY_PASSWORD*) printf "c3VicGFzcw=="; exit 0 ;;
    *) printf "dGVzdA=="; exit 0 ;;
  esac
fi
# Return a pod name so AC-034 proceeds to the YAML file check
if [[ "\${1:-}" == "get" && "\${2:-}" == "pods" ]]; then printf "catalog-pod-abc"; exit 0; fi
# python3 exec → return length > 10 so SECRET_KEY length check passes
if [[ "\${1:-}" == "exec" ]]; then printf "32"; exit 0; fi
if [[ "\${1:-}" == "get" && "\${2:-}" == "deployment" ]]; then printf ""; exit 0; fi
echo "unexpected kubectl: \$ARGS" >&2; exit 1
KEOF
chmod +x "$FAKEBIN/kubectl"

run_expect_fail "catalog deployment YAML without enterprise-secrets reference is rejected"

echo "OK"
