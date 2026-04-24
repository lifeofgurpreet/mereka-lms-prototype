#!/usr/bin/env bash
# test-verify-enterprise-sso-readiness.sh — self-contained test suite for
# scripts/qa/verify-enterprise-sso-readiness.sh
#
# Three fixtures covering the main semantic contracts:
#   1. Happy path  — --mode repo against the real repo → all 13 checks PASS, exit 0
#   2. Usage error — invalid --env value → exit 1 + error message on stderr
#   3. Degraded    — synthetic sparse repo missing key files → FAILs detected, exit 1
#
# NOTE: No live-cluster fixtures are included. Checks 9-20 (kubectl/HTTP) all
# skip gracefully when the kube context is unavailable; the --mode repo path
# is the only scope exercisable offline. This is noted in the PR body.
#
# Usage:
#   bash scripts/qa/test-verify-enterprise-sso-readiness.sh
#
# Bead: Batch 3 — test-verify-enterprise-sso-readiness.sh self-test axis
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/qa/verify-enterprise-sso-readiness.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

_pass() {
  PASS_COUNT=$(( PASS_COUNT + 1 ))
  echo "[test-verify-enterprise-sso-readiness] PASS $*"
}

_fail() {
  FAIL_COUNT=$(( FAIL_COUNT + 1 ))
  echo "[test-verify-enterprise-sso-readiness] FAIL $*" >&2
}

# ── Fixture 1: happy path — real repo, --mode repo → 13 PASS, exit 0 ─────────
# Tests: all repo-level checks exercise cleanly against the actual repo state.
# Validates: ExternalSecret keys, ENABLE_ENTERPRISE_INTEGRATION flag, DISABLE_ENTERPRISE_LOGIN,
#            keypair script, configure-tenant-idp, middleware guard, spec file, AC-042 dep.
echo ""
echo "--- Fixture 1: happy path (--mode repo against real repo → all checks PASS) ---"

FIX1_OUT="$TMP_DIR/fix1.txt"
FIX1_ERR="$TMP_DIR/fix1.err"

set +e
bash "$SCRIPT" --mode repo > "$FIX1_OUT" 2> "$FIX1_ERR"
FIX1_EXIT=$?
set -e

if [[ $FIX1_EXIT -eq 0 ]]; then
  _pass "fixture 1: exit 0 for --mode repo against real repo"
else
  _fail "fixture 1: expected exit 0, got $FIX1_EXIT — stderr: $(cat "$FIX1_ERR")"
fi

if grep -q "All checks passed" "$FIX1_OUT" 2>/dev/null; then
  _pass "fixture 1: 'All checks passed' summary line present"
else
  _fail "fixture 1: expected 'All checks passed' in stdout; got: $(tail -5 "$FIX1_OUT")"
fi

if grep -q "FAIL.*0" "$FIX1_OUT" 2>/dev/null; then
  _pass "fixture 1: FAIL counter is 0 in summary"
else
  _fail "fixture 1: expected 'FAIL  0' in summary; got: $(tail -10 "$FIX1_OUT")"
fi

# Spot-check that a representative check passed
if grep -q "ExternalSecret 'enterprise-sso-secrets' is defined" "$FIX1_OUT" 2>/dev/null; then
  _pass "fixture 1: ExternalSecret definition check executed"
else
  _fail "fixture 1: ExternalSecret check output missing from stdout"
fi

if grep -q "ENABLE_ENTERPRISE_INTEGRATION" "$FIX1_OUT" 2>/dev/null; then
  _pass "fixture 1: ENABLE_ENTERPRISE_INTEGRATION check executed"
else
  _fail "fixture 1: ENABLE_ENTERPRISE_INTEGRATION check output missing from stdout"
fi

# ── Fixture 2: usage error — invalid --env value → exit 1 + error on stderr ───
# Tests: argument validation guard rejects unknown env values with a clear message
#        and exits 1 immediately without running any checks.
echo ""
echo "--- Fixture 2: usage error (--env bogus → exit 1 + error on stderr) ---"

FIX2_OUT="$TMP_DIR/fix2.txt"
FIX2_ERR="$TMP_DIR/fix2.err"

set +e
bash "$SCRIPT" --env bogus-env > "$FIX2_OUT" 2> "$FIX2_ERR"
FIX2_EXIT=$?
set -e

if [[ $FIX2_EXIT -eq 1 ]]; then
  _pass "fixture 2: exit 1 for invalid --env value"
else
  _fail "fixture 2: expected exit 1, got $FIX2_EXIT"
fi

if grep -q "Invalid --env" "$FIX2_ERR" 2>/dev/null; then
  _pass "fixture 2: 'Invalid --env' error message on stderr"
else
  _fail "fixture 2: expected 'Invalid --env' on stderr; got: $(cat "$FIX2_ERR")"
fi

if ! grep -q "PASS\|FAIL\|SKIP" "$FIX2_OUT" 2>/dev/null; then
  _pass "fixture 2: no check output emitted before validation fails"
else
  _fail "fixture 2: unexpected check output before validation guard; got: $(cat "$FIX2_OUT")"
fi

# ── Fixture 3: degraded synthetic repo — missing files → FAILs detected, exit 1
# Tests: the verifier correctly reports FAILs when expected repo artefacts are absent.
# Technique: build a minimal fake repo under $TMP_DIR/fake-repo that has just enough
#            scaffolding for the shared/config.sh + mereka_plugin_contract.sh sourcing
#            to succeed, but is deliberately missing the ExternalSecret YAML,
#            configure-tenant-idp.sh, and the spec file.
echo ""
echo "--- Fixture 3: degraded repo (missing key files → FAIL lines, exit 1) ---"

FAKE_REPO="$TMP_DIR/fake-repo"

# Scaffold minimal directory tree
mkdir -p \
  "$FAKE_REPO/scripts/qa" \
  "$FAKE_REPO/scripts/shared" \
  "$FAKE_REPO/scripts/tenants" \
  "$FAKE_REPO/deploy/k8s/base/secrets" \
  "$FAKE_REPO/deploy/k8s/base/apps/openedx/settings/lms" \
  "$FAKE_REPO/infrastructure/tutor/plugins" \
  "$FAKE_REPO/specs"

# Minimal shared/config.sh (sourced unconditionally by the verifier)
cat > "$FAKE_REPO/scripts/shared/config.sh" <<'SH'
#!/usr/bin/env bash
LMS_DOMAIN="academyv2.mereka.io"
DEV_LMS_DOMAIN="academyv2.mereka.dev"
STAGING_LMS_DOMAIN="staging.academyv2.mereka.io"
K8S_NAMESPACE_PROD="mereka-lms"
K8S_NAMESPACE_DEV="mereka-lms-dev"
K8S_NAMESPACE_STAGING="stg-mereka-lms"
K8S_CONTEXT_PROD="rke2-prod"
K8S_CONTEXT_DEV="rke2-nonprod"
K8S_CONTEXT_STAGING="rke2-nonprod"
SH

# Minimal mereka_plugin_contract.sh (sourced unconditionally)
cp "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh" \
   "$FAKE_REPO/scripts/shared/mereka_plugin_contract.sh"

# Plugin file that has ENABLE_ENTERPRISE_INTEGRATION (keeps that check green so
# we isolate the file-missing FAILs cleanly)
cat > "$FAKE_REPO/infrastructure/tutor/plugins/mereka_lms.py" <<'PY'
FEATURES = {}
FEATURES["ENABLE_ENTERPRISE_INTEGRATION"] = True
PY

# lms/production.py WITHOUT DISABLE_ENTERPRISE_LOGIN (deliberate FAIL)
cat > "$FAKE_REPO/deploy/k8s/base/apps/openedx/settings/lms/production.py" <<'PY'
# minimal stub — DISABLE_ENTERPRISE_LOGIN intentionally absent
DEBUG = False
PY

# external-secrets.yaml WITHOUT enterprise-sso-secrets (deliberate FAIL)
cat > "$FAKE_REPO/deploy/k8s/base/secrets/external-secrets.yaml" <<'YAML'
# minimal stub — enterprise-sso-secrets intentionally absent
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: openedx-secrets
spec: {}
YAML

# generate-saml-keypair.sh exists and is executable (should PASS)
cat > "$FAKE_REPO/scripts/tenants/generate-saml-keypair.sh" <<'SH'
#!/usr/bin/env bash
echo "stub keypair generator"
SH
chmod +x "$FAKE_REPO/scripts/tenants/generate-saml-keypair.sh"

# configure-tenant-idp.sh is absent (deliberate FAIL)
# specs/auth-sso-enterprise_spec.md is absent (deliberate FAIL)
# scripts/qa/verify-auth-surfaces.sh is absent (deliberate FAIL)

# Use a real copy of the verifier but override REPO_ROOT via the PATH trick:
# The verifier hard-codes REPO_ROOT from its own location, so we copy it into
# the fake repo and run it from there.
cp "$SCRIPT" "$FAKE_REPO/scripts/qa/verify-enterprise-sso-readiness.sh"

FIX3_OUT="$TMP_DIR/fix3.txt"
FIX3_ERR="$TMP_DIR/fix3.err"

set +e
bash "$FAKE_REPO/scripts/qa/verify-enterprise-sso-readiness.sh" \
  --mode repo > "$FIX3_OUT" 2> "$FIX3_ERR"
FIX3_EXIT=$?
set -e

if [[ $FIX3_EXIT -eq 1 ]]; then
  _pass "fixture 3: exit 1 when key repo files are missing"
else
  _fail "fixture 3: expected exit 1 for degraded repo, got $FIX3_EXIT"
fi

if grep -q "enterprise-sso-secrets.*NOT found\|ExternalSecret.*NOT found\|ExternalSecret is missing key" "$FIX3_OUT" 2>/dev/null; then
  _pass "fixture 3: FAIL reported for missing enterprise-sso-secrets ExternalSecret"
else
  _fail "fixture 3: expected FAIL for ExternalSecret absence; stdout: $(grep -a FAIL "$FIX3_OUT" || true)"
fi

if grep -q "DISABLE_ENTERPRISE_LOGIN" "$FIX3_OUT" 2>/dev/null; then
  _pass "fixture 3: FAIL reported for missing DISABLE_ENTERPRISE_LOGIN"
else
  _fail "fixture 3: expected FAIL for missing DISABLE_ENTERPRISE_LOGIN; stdout: $(grep -a FAIL "$FIX3_OUT" || true)"
fi

if grep -q "configure-tenant-idp.sh not found" "$FIX3_OUT" 2>/dev/null; then
  _pass "fixture 3: FAIL reported for missing configure-tenant-idp.sh"
else
  _fail "fixture 3: expected FAIL for missing configure-tenant-idp.sh; stdout: $(grep FAIL "$FIX3_OUT" || true)"
fi

if grep -q "auth-sso-enterprise_spec.md" "$FIX3_OUT" 2>/dev/null; then
  _pass "fixture 3: spec file check executed"
else
  _fail "fixture 3: spec file check output missing from stdout"
fi

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Summary: PASS=${PASS_COUNT} FAIL=${FAIL_COUNT}"
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo "[test-verify-enterprise-sso-readiness] FAILED" >&2
  exit 1
fi
echo "[test-verify-enterprise-sso-readiness] ALL FIXTURES PASSED"
