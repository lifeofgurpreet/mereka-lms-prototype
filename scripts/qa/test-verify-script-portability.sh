#!/usr/bin/env bash
# Seeded-defect self-test for verify-script-portability.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_SCRIPT="$REPO_ROOT/scripts/qa/verify-script-portability.sh"

tmpdir="$(mktemp -d -t test-script-portability.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

good_dir="$tmpdir/good"
bad_dir="$tmpdir/bad"
mkdir -p "$good_dir" "$bad_dir"

cat >"$good_dir/good.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "$REPO_ROOT"
EOF

cat >"$bad_dir/bad.sh" <<'EOF'
#!/usr/bin/env bash
echo "/home/someone/projects/k8s/mereka-lms"
EOF

echo "[1/2] verifier passes on portable script sample..."
bash "$VERIFY_SCRIPT" --dir "$good_dir" >/tmp/test-verify-script-portability-good.out 2>&1

echo "[2/2] verifier fails on workstation absolute path sample..."
if bash "$VERIFY_SCRIPT" --dir "$bad_dir" >/tmp/test-verify-script-portability-bad.out 2>&1; then
  echo "FAIL: expected verifier to fail on seeded workstation path" >&2
  cat /tmp/test-verify-script-portability-bad.out >&2 || true
  exit 1
fi

if ! grep -qi "workstation path literal found" /tmp/test-verify-script-portability-bad.out; then
  echo "FAIL: expected workstation-path failure message" >&2
  cat /tmp/test-verify-script-portability-bad.out >&2 || true
  exit 1
fi

rm -f /tmp/test-verify-script-portability-good.out /tmp/test-verify-script-portability-bad.out
echo "PASS: seeded-defect test for verify-script-portability.sh"
