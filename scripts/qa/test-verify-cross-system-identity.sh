#!/usr/bin/env bash
# Seeded-defect self-test for verify-cross-system-identity.sh.
# Pattern: tempdir fixture-tree with REPO_ROOT_OVERRIDE env injection.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-cross-system-identity.sh"

tmpdir="$(mktemp -d -t verify-cross-system-identity.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

LOG="$tmpdir/output.log"

mkdir -p \
  "$tmpdir/scripts/migrations/kajabi/output" \
  "$tmpdir/scripts/migrations/kajabi" \
  "$tmpdir/scripts/migrations/mct" \
  "$tmpdir/exports/mct"

# ── helpers ──────────────────────────────────────────────────────────────────

run_expect_pass() {
  local label="$1"
  if REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >"$LOG" 2>&1; then
    echo "PASS ${label}"
  else
    echo "FAIL ${label}: expected success but command failed" >&2
    cat "$LOG" >&2 || true
    exit 1
  fi
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >"$LOG" 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat "$LOG" >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

# ── fixture helpers ───────────────────────────────────────────────────────────

write_kajabi_users() {
  cat >"$tmpdir/scripts/migrations/kajabi/output/users.csv" <<'EOF'
email,name
alice@example.com,Alice Smith
bob@example.com,Bob Jones
shared@example.com,Shared User
EOF
}

write_mct_users() {
  cat >"$tmpdir/exports/mct/users.ndjson" <<'EOF'
{"email": "carol@example.com", "name": "Carol Brown"}
{"email": "shared@example.com", "name": "Shared MCT User"}
EOF
}

write_kajabi_import_with_collision_handling() {
  cat >"$tmpdir/scripts/migrations/kajabi/openedx_bulk_import.py" <<'EOF'
#!/usr/bin/env python3
# Kajabi bulk import with email collision handling
from django.contrib.auth.models import User
user, created = User.objects.get_or_create(email=email, defaults={"username": username})
EOF
  chmod +x "$tmpdir/scripts/migrations/kajabi/openedx_bulk_import.py"
}

write_mct_import_with_collision_handling() {
  cat >"$tmpdir/scripts/migrations/mct/openedx_bulk_import_mct.py" <<'EOF'
#!/usr/bin/env python3
# MCT bulk import with email collision handling
from django.contrib.auth.models import User
try:
    user, created = User.objects.get_or_create(email=row["email"])
except IntegrityError:
    user = User.objects.filter(email=row["email"]).first()
EOF
  chmod +x "$tmpdir/scripts/migrations/mct/openedx_bulk_import_mct.py"
}

# ── fixture 1: full happy path ────────────────────────────────────────────────
# Both data files present, both import scripts have collision handling.

write_kajabi_users
write_mct_users
write_kajabi_import_with_collision_handling
write_mct_import_with_collision_handling

run_expect_pass "full fixture: both data files + collision handling passes"

# ── fixture 2: missing kajabi users file ─────────────────────────────────────
# Verifier must fail when the Kajabi users CSV is absent.

rm -f "$tmpdir/scripts/migrations/kajabi/output/users.csv"

run_expect_fail "missing kajabi users.csv is rejected"

# restore for next test
write_kajabi_users

# ── fixture 3: import script without collision handling ───────────────────────
# Replace the kajabi import script with one that has no get_or_create / IntegrityError.

cat >"$tmpdir/scripts/migrations/kajabi/openedx_bulk_import.py" <<'EOF'
#!/usr/bin/env python3
# Kajabi bulk import WITHOUT collision handling
from django.contrib.auth.models import User
user = User.objects.create(email=email, username=username)
EOF
chmod +x "$tmpdir/scripts/migrations/kajabi/openedx_bulk_import.py"

run_expect_fail "kajabi import script missing collision handling is rejected"

echo "OK"
