#!/usr/bin/env bash
# Verify per-entry timeout metadata in .github/run-scripts-parallel.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d -t run-scripts-timeout.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

slow_script="$TMP_DIR/slow.sh"
cat >"$slow_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sleep 2
echo "slow script completed"
EOF
chmod +x "$slow_script"

with_override="$TMP_DIR/with-override.txt"
without_override="$TMP_DIR/without-override.txt"
printf '%s # timeout=4\n' "$slow_script" >"$with_override"
printf '%s\n' "$slow_script" >"$without_override"

if (cd "$TMP_DIR" && "$REPO_ROOT/.github/run-scripts-parallel.sh" "$with_override" 1 1) \
  >"$TMP_DIR/with-override.out" 2>"$TMP_DIR/with-override.err"; then
  echo "PASS: per-entry timeout override is honored"
else
  cat "$TMP_DIR/with-override.out" >&2 || true
  cat "$TMP_DIR/with-override.err" >&2 || true
  echo "FAIL: per-entry timeout override is honored" >&2
  exit 1
fi

if ! rg -q 'START slow \[1/1\] \(timeout 4s\)' "$TMP_DIR/with-override.out"; then
  cat "$TMP_DIR/with-override.out" >&2
  echo "FAIL: runner output exposes effective timeout" >&2
  exit 1
fi
echo "PASS: runner output exposes effective timeout"

set +e
(cd "$TMP_DIR" && "$REPO_ROOT/.github/run-scripts-parallel.sh" "$without_override" 1 1) \
  >"$TMP_DIR/without-override.out" 2>"$TMP_DIR/without-override.err"
rc=$?
set -e

if [[ "$rc" -ne 0 ]] && rg -q 'TIMEOUT slow \[1/1\]' "$TMP_DIR/without-override.out"; then
  echo "PASS: default timeout still fails closed"
else
  cat "$TMP_DIR/without-override.out" >&2 || true
  cat "$TMP_DIR/without-override.err" >&2 || true
  echo "FAIL: default timeout still fails closed" >&2
  exit 1
fi
