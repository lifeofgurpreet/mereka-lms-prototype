#!/usr/bin/env bash
# Seeded-defect self-test for verify-csp-report-pipeline.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-csp-report-pipeline.sh"

tmpdir="$(mktemp -d -t verify-csp-report-pipeline.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/scripts/shared" \
  "$tmpdir/infrastructure/tutor/plugins" \
  "$tmpdir/deploy/k8s/base/apps/openedx/settings/lms"

cat >"$tmpdir/scripts/shared/mereka_plugin_contract.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mereka_plugin_contract_files() {
  local repo_root="${1:?repo_root required}"
  local plugins_dir="$repo_root/infrastructure/tutor/plugins"
  if [[ -f "$plugins_dir/mereka_lms.py" ]]; then
    printf "%s\n" "$plugins_dir/mereka_lms.py"
  fi
}

mereka_plugin_has_fixed() {
  local repo_root="${1:?repo_root required}"
  local needle="${2:?needle required}"
  local file
  while IFS= read -r file; do
    if grep -qF -- "$needle" "$file" 2>/dev/null; then
      return 0
    fi
  done < <(mereka_plugin_contract_files "$repo_root")
  return 1
}
EOF
chmod +x "$tmpdir/scripts/shared/mereka_plugin_contract.sh"

PLUGIN_FILE="$tmpdir/infrastructure/tutor/plugins/mereka_lms.py"
PROD_PY="$tmpdir/deploy/k8s/base/apps/openedx/settings/lms/production.py"

write_valid_sources() {
  cat >"$PLUGIN_FILE" <<'EOF'
from urllib.parse import urlparse as _urlparse

def _derive_sentry_csp_report_uri(_dsn):
    return _dsn

CSP_REPORT_URI = _csp_report_uri
EOF

  cat >"$PROD_PY" <<'EOF'
from urllib.parse import urlparse as _urlparse

def _derive_sentry_csp_report_uri(_dsn):
    return _dsn

CSP_REPORT_URI = _csp_report_uri
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-csp-report-pipeline.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-csp-report-pipeline.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-csp-report-pipeline.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_valid_sources
run_expect_pass "static CSP pipeline wiring passes when plugin and production match contract"

write_valid_sources
cat >>"$PLUGIN_FILE" <<'EOF'
HARD_CODED = "https://sentry.io/api/"
EOF
run_expect_fail "hardcoded sentry endpoint is rejected"

echo "OK"
