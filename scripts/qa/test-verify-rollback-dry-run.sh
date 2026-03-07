#!/usr/bin/env bash
# Seeded-defect self-test for verify-rollback-dry-run.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-rollback-dry-run.sh"

tmpdir="$(mktemp -d -t verify-rollback-dry-run.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/scripts/migrations"

write_pass_fixture() {
  cat >"$tmpdir/scripts/migrations/rollback-openedx-imports.py" <<'EOF'
#!/usr/bin/env python3
import argparse

def main():
    parser = argparse.ArgumentParser(description="rollback helper")
    parser.add_argument("--dry-run", action="store_true", help="preview mode")
    parser.add_argument("--action", choices=["unenroll"], default="unenroll")
    args = parser.parse_args()
    count = 10
    if args.dry_run:
        print(f"would unenroll {count}")

if __name__ == "__main__":
    main()
EOF
  chmod +x "$tmpdir/scripts/migrations/rollback-openedx-imports.py"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-rollback-dry-run.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-rollback-dry-run.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-rollback-dry-run.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixture
run_expect_pass "rollback script with dry-run and action support passes"

cat >"$tmpdir/scripts/migrations/rollback-openedx-imports.py" <<'EOF'
#!/usr/bin/env python3
print("no dry run support")
EOF
chmod +x "$tmpdir/scripts/migrations/rollback-openedx-imports.py"
run_expect_fail "missing dry-run and action wiring is rejected"

echo "OK"
