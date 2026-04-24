#!/usr/bin/env bash
# Seeded-defect self-test for verify-architecture-doc-path-drift.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-architecture-doc-path-drift.sh"

tmpdir="$(mktemp -d -t arch-doc-path-drift.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/scripts/qa"
cat >"$tmpdir/scripts/qa/verify-a.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "docs/architecture/OLD.md"
EOF
cat >"$tmpdir/scripts/qa/verify-b.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "docs/concepts/architecture/NEW.md"
EOF

ALLOWLIST="$tmpdir/allowlist.json"

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" ARCH_DOC_PATH_ALLOWLIST_OVERRIDE="$ALLOWLIST" \
    bash "$VERIFY" >/tmp/verify-architecture-doc-path-drift.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-architecture-doc-path-drift.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" ARCH_DOC_PATH_ALLOWLIST_OVERRIDE="$ALLOWLIST" \
    bash "$VERIFY" >/tmp/verify-architecture-doc-path-drift.out 2>&1
  echo "PASS ${label}"
}

# Case 1: missing allowlist entry fails.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "legacy_docs_architecture_reference_allowlist": []
}
EOF
run_expect_fail "missing allowlist entry is rejected"

# Case 2: matching allowlist passes.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "legacy_docs_architecture_reference_allowlist": [
    "scripts/qa/verify-a.sh"
  ]
}
EOF
run_expect_pass "matching allowlist passes"

# Case 3: stale entry fails in strict mode.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "legacy_docs_architecture_reference_allowlist": [
    "scripts/qa/verify-a.sh",
    "scripts/qa/verify-b.sh"
  ]
}
EOF
set +e
REPO_ROOT_OVERRIDE="$tmpdir" ARCH_DOC_PATH_ALLOWLIST_OVERRIDE="$ALLOWLIST" STRICT_STALE=1 \
  bash "$VERIFY" >/tmp/verify-architecture-doc-path-drift.out 2>&1
rc=$?
set -e
if [[ "$rc" -eq 0 ]]; then
  echo "FAIL stale strict mode: expected failure but command succeeded" >&2
  cat /tmp/verify-architecture-doc-path-drift.out >&2 || true
  exit 1
fi
echo "PASS stale strict mode is rejected"

echo "OK"
