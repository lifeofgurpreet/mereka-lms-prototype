#!/usr/bin/env bash
# test-verify-build-optimizations-render-delta-contract.sh - seeded fixtures.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$REPO_ROOT/scripts/qa/verify-build-optimizations-render-delta-contract.sh"
TMP_DIR="$(mktemp -d -t build-delta-contract-test.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0

pass() { echo "PASS $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL $1" >&2; FAIL=$((FAIL + 1)); }

contract="$TMP_DIR/contract.yaml"
patch_script="$TMP_DIR/build-optimizations.sh"
inventory_doc="$TMP_DIR/TUTOR_PATCHES_INVENTORY.md"

cat >"$contract" <<'EOF'
default_policy: fail_closed
review_date: "2026-04-27"
allowed_deltas:
  - id: fixture-delta
    authority_class: temporary_compatibility_layer
    source_markers:
      - FIXTURE_MARKER
    retirement_trigger: Move fixture behavior to source hook.
    added_patterns:
      - 'allowed added line'
    removed_patterns:
      - 'allowed removed line'
EOF

cat >"$patch_script" <<'EOF'
#!/usr/bin/env bash
FIXTURE_MARKER=1
EOF

cat >"$inventory_doc" <<'EOF'
# Inventory

fixture-delta
temporary compatibility layer
EOF

raw="$TMP_DIR/raw.Dockerfile"
patched="$TMP_DIR/patched.Dockerfile"
cat >"$raw" <<'EOF'
FROM base
allowed removed line
EOF
cat >"$patched" <<'EOF'
FROM base
allowed added line
EOF

if BUILD_OPTIMIZATIONS_DELTA_CONTRACT="$contract" \
  BUILD_OPTIMIZATIONS_SCRIPT="$patch_script" \
  PATCH_INVENTORY_DOC="$inventory_doc" \
  RAW_RENDER_FILE="$raw" \
  PATCHED_RENDER_FILE="$patched" \
  "$VERIFY" >/tmp/build-delta-good.out 2>/tmp/build-delta-good.err; then
  pass "allowed raw-vs-patched render delta passes"
else
  cat /tmp/build-delta-good.err >&2 || true
  fail "allowed raw-vs-patched render delta passes"
fi

cat >"$patched" <<'EOF'
FROM base
unexpected added line
EOF

set +e
BUILD_OPTIMIZATIONS_DELTA_CONTRACT="$contract" \
  BUILD_OPTIMIZATIONS_SCRIPT="$patch_script" \
  PATCH_INVENTORY_DOC="$inventory_doc" \
  RAW_RENDER_FILE="$raw" \
  PATCHED_RENDER_FILE="$patched" \
  "$VERIFY" >/tmp/build-delta-bad.out 2>/tmp/build-delta-bad.err
rc=$?
set -e

if [[ "$rc" -ne 0 ]] && grep -q "unexpected added render delta" /tmp/build-delta-bad.err; then
  pass "unexpected render delta fails closed"
else
  cat /tmp/build-delta-bad.out >&2 || true
  cat /tmp/build-delta-bad.err >&2 || true
  fail "unexpected render delta fails closed"
fi

set +e
BUILD_OPTIMIZATIONS_DELTA_CONTRACT="$contract" \
  BUILD_OPTIMIZATIONS_SCRIPT="$patch_script" \
  PATCH_INVENTORY_DOC="$TMP_DIR/missing.md" \
  "$VERIFY" >/tmp/build-delta-missing.out 2>/tmp/build-delta-missing.err
rc=$?
set -e

if [[ "$rc" -ne 0 ]] && grep -q "missing patch inventory doc" /tmp/build-delta-missing.err; then
  pass "missing inventory doc fails closed"
else
  cat /tmp/build-delta-missing.out >&2 || true
  cat /tmp/build-delta-missing.err >&2 || true
  fail "missing inventory doc fails closed"
fi

cat >"$inventory_doc" <<'EOF'
# Inventory

fixture-delta-extra
temporary compatibility layer
EOF

set +e
BUILD_OPTIMIZATIONS_DELTA_CONTRACT="$contract" \
  BUILD_OPTIMIZATIONS_SCRIPT="$patch_script" \
  PATCH_INVENTORY_DOC="$inventory_doc" \
  "$VERIFY" >/tmp/build-delta-substring.out 2>/tmp/build-delta-substring.err
rc=$?
set -e

if [[ "$rc" -ne 0 ]] && grep -q "fixture-delta missing as an exact token" /tmp/build-delta-substring.err; then
  pass "inventory delta id substring match fails closed"
else
  cat /tmp/build-delta-substring.out >&2 || true
  cat /tmp/build-delta-substring.err >&2 || true
  fail "inventory delta id substring match fails closed"
fi

cat >"$inventory_doc" <<'EOF'
# Inventory

fixture-delta
EOF

set +e
BUILD_OPTIMIZATIONS_DELTA_CONTRACT="$contract" \
  BUILD_OPTIMIZATIONS_SCRIPT="$patch_script" \
  PATCH_INVENTORY_DOC="$inventory_doc" \
  "$VERIFY" >/tmp/build-delta-class.out 2>/tmp/build-delta-class.err
rc=$?
set -e

if [[ "$rc" -ne 0 ]] && grep -q "authority_class 'temporary_compatibility_layer' missing" /tmp/build-delta-class.err; then
  pass "inventory authority class omission fails closed"
else
  cat /tmp/build-delta-class.out >&2 || true
  cat /tmp/build-delta-class.err >&2 || true
  fail "inventory authority class omission fails closed"
fi

cat >"$inventory_doc" <<'EOF'
# Inventory

fixture-delta
temporary compatibility layer
EOF

python3 - "$contract" <<'PY'
import sys
from pathlib import Path

contract = Path(sys.argv[1])
text = contract.read_text(encoding="utf-8")
text = text.replace("      - 'allowed added line'", "      - '.*'")
contract.write_text(text, encoding="utf-8")
PY

set +e
BUILD_OPTIMIZATIONS_DELTA_CONTRACT="$contract" \
  BUILD_OPTIMIZATIONS_SCRIPT="$patch_script" \
  PATCH_INVENTORY_DOC="$inventory_doc" \
  "$VERIFY" >/tmp/build-delta-broad.out 2>/tmp/build-delta-broad.err
rc=$?
set -e

if [[ "$rc" -ne 0 ]] && grep -q "overly broad added_patterns regex" /tmp/build-delta-broad.err; then
  pass "over-broad render delta regex fails closed"
else
  cat /tmp/build-delta-broad.out >&2 || true
  cat /tmp/build-delta-broad.err >&2 || true
  fail "over-broad render delta regex fails closed"
fi

echo "Summary: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
