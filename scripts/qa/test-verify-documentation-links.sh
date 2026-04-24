#!/usr/bin/env bash
# Seeded-defect self-test for verify-documentation-links.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-documentation-links.sh"

tmpdir="$(mktemp -d -t verify-doc-links.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/docs" "$tmpdir/specs"

run_and_capture() {
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY"
}

strip_ansi() {
  sed -E 's/\x1b\[[0-9;]*m//g'
}

# Case 1: valid relative link should report zero broken links.
cat >"$tmpdir/docs/target.md" <<'EOF'
# Target
EOF
cat >"$tmpdir/docs/source.md" <<'EOF'
# Source

See [target](target.md).
EOF
valid_output="$(run_and_capture | strip_ansi)"
if ! grep -q "Broken: 0" <<<"$valid_output"; then
  echo "FAIL valid link case did not report Broken: 0" >&2
  echo "$valid_output" >&2
  exit 1
fi
echo "PASS valid links report zero broken"

# Case 2: broken link should be detected but remain non-blocking (exit 0).
cat >"$tmpdir/docs/source.md" <<'EOF'
# Source

See [missing](missing.md).
EOF
broken_output="$(run_and_capture | strip_ansi)"
if ! grep -q "Broken: 1" <<<"$broken_output"; then
  echo "FAIL broken link case did not report Broken: 1" >&2
  echo "$broken_output" >&2
  exit 1
fi
if ! grep -q "Some links may be broken" <<<"$broken_output"; then
  echo "FAIL broken link case missing warning summary" >&2
  echo "$broken_output" >&2
  exit 1
fi
echo "PASS broken links are detected as non-blocking warnings"

echo "OK"
