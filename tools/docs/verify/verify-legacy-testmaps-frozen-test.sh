#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="tools/docs/verify/verify-legacy-testmaps-frozen.py"
SCRIPT_ABS="$(pwd)/$SCRIPT_PATH"

if [ ! -f "$SCRIPT_PATH" ]; then
  echo "missing script: $SCRIPT_PATH"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" /tmp/legacy-testmaps-ok.$$' EXIT

SUMMARY_OK="$TMP_DIR/ok.json"
python3 "$SCRIPT_PATH" --range HEAD~0...HEAD --summary-file "$SUMMARY_OK" >/tmp/legacy-testmaps-ok.$$ 2>&1 || {
  cat /tmp/legacy-testmaps-ok.$$
  exit 1
}
grep -q 'LEGACY_TESTMAP_FREEZE_OK' /tmp/legacy-testmaps-ok.$$
grep -q '"status": "pass"' "$SUMMARY_OK"
grep -q 'specs/testmaps/README.md' "$SUMMARY_OK"
grep -q 'specs/testmaps/RETIREMENT_PLAN.md' "$SUMMARY_OK"

TMP_REPO="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$TMP_REPO" /tmp/legacy-testmaps-ok.$$' EXIT

(
  cd "$TMP_REPO"
  git init -q
  git config user.name "Codex Test"
  git config user.email "codex@example.com"
  mkdir -p specs/testmaps
  cat > specs/testmaps/README.md <<'EOF'
# README
EOF
  cat > specs/testmaps/RETIREMENT_PLAN.md <<'EOF'
# RETIREMENT
EOF
  cat > specs/testmaps/example_spec.testmap.yml <<'EOF'
spec: example
EOF
  git add specs/testmaps
  git commit -qm "baseline"

  SUMMARY_ALLOWED="$TMP_DIR/allowed.json"
  echo "local note" >> specs/testmaps/README.md
  python3 "$SCRIPT_ABS" --working-tree --summary-file "$SUMMARY_ALLOWED" >"$TMP_DIR/allowed.out" 2>&1 || {
    cat "$TMP_DIR/allowed.out"
    exit 1
  }
  grep -q 'LEGACY_TESTMAP_FREEZE_OK mode=working-tree' "$TMP_DIR/allowed.out"
  grep -q '"status": "pass"' "$SUMMARY_ALLOWED"

  git checkout -- specs/testmaps/README.md
  echo "mutated" >> specs/testmaps/example_spec.testmap.yml
  if python3 "$SCRIPT_ABS" --working-tree >"$TMP_DIR/forbidden.out" 2>&1; then
    cat "$TMP_DIR/forbidden.out"
    exit 1
  fi
  grep -q 'LEGACY_TESTMAP_FREEZE_FAIL mode=working-tree' "$TMP_DIR/forbidden.out"
  grep -q 'specs/testmaps/example_spec.testmap.yml' "$TMP_DIR/forbidden.out"
)

echo "verify-legacy-testmaps-frozen self-test: OK"
