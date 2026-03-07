#!/usr/bin/env bash
# Seeded-defect self-test for verify-migration-rollback.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-migration-rollback.sh"

tmpdir="$(mktemp -d -t verify-migration-rollback.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/docs/migrations/kajabi" \
  "$tmpdir/scripts/migrations" \
  "$tmpdir/specs" \
  "$tmpdir/scripts/qa"

write_pass_fixtures() {
  cat >"$tmpdir/docs/migrations/kajabi/ROLLBACK_AND_SAFETY.md" <<'EOF'
# Rollback and Safety
Use tutor local do restore-db after taking mysql database backup.
EOF

  cat >"$tmpdir/scripts/migrations/rollback-openedx-imports.py" <<'EOF'
#!/usr/bin/env python3
import argparse
parser = argparse.ArgumentParser()
parser.add_argument("--dry-run", action="store_true")
parser.add_argument("--action", choices=["unenroll"], default="unenroll")
EOF
  chmod +x "$tmpdir/scripts/migrations/rollback-openedx-imports.py"

  cat >"$tmpdir/specs/data-migrations-kajabi-mct_spec.md" <<'EOF'
# Data Migrations
## Rollback Procedure
Run tutor local do restore-db and verify mysqldump backups exist.
EOF

  cat >"$tmpdir/scripts/qa/list-critical-backup-pvcs.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
  chmod +x "$tmpdir/scripts/qa/list-critical-backup-pvcs.sh"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-migration-rollback.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-migration-rollback.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-migration-rollback.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixtures
run_expect_pass "rollback docs/spec/script/tooling contract passes"

cat >"$tmpdir/scripts/migrations/rollback-openedx-imports.py" <<'EOF'
#!/usr/bin/env python3
print("rollback helper without dry run")
EOF
chmod +x "$tmpdir/scripts/migrations/rollback-openedx-imports.py"
run_expect_fail "missing dry-run and unenroll support is rejected"

echo "OK"
