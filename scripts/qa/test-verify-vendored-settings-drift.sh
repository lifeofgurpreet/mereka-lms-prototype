#!/usr/bin/env bash
# Seeded-defect self-test for verify-vendored-settings-drift.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-vendored-settings-drift.sh"

tmpdir="$(mktemp -d -t verify-vendored-settings-drift.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

APP_REPO="$tmpdir/app"
INFRA_REPO="$tmpdir/bbi-infrastructure"

mkdir -p "$APP_REPO/.git" "$INFRA_REPO/apps/mereka-lms/base/deploy/k8s/base/apps/openedx/settings/lms"

APP_FILE="deploy/k8s/base/apps/openedx/settings/lms/production.py"
INFRA_FILE="apps/mereka-lms/base/deploy/k8s/base/apps/openedx/settings/lms/production.py"

mkdir -p "$(dirname "$APP_REPO/$APP_FILE")"
cat >"$APP_REPO/$APP_FILE" <<'EOF'
SETTING = "canonical"
EOF

cat >"$INFRA_REPO/$INFRA_FILE" <<'EOF'
SETTING = "stale"
EOF

run_expect_pass() {
  local label="$1"
  shift
  "$@" >/tmp/verify-vendored-settings-drift.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  shift
  set +e
  "$@" >/tmp/verify-vendored-settings-drift.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-vendored-settings-drift.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

(
  cd "$APP_REPO"
  git init -q
  git config user.name test
  git config user.email test@example.com
  git add "$APP_FILE"
  git commit -qm "base"
  git checkout -qb feature
  mkdir -p scripts/qa
  cp "$VERIFY" scripts/qa/verify-vendored-settings-drift.sh

  run_expect_fail \
    "full scan fails when vendored settings drift exists" \
    env INFRA_REPO="$INFRA_REPO" bash scripts/qa/verify-vendored-settings-drift.sh

  cat > README.md <<'EOF'
unrelated change
EOF
  git add README.md
  git commit -qm "docs"

  run_expect_pass \
    "ci mode skips when no vendored settings surfaces changed" \
    env INFRA_REPO="$INFRA_REPO" GITHUB_EVENT_NAME=pull_request bash scripts/qa/verify-vendored-settings-drift.sh

  printf 'SETTING = "updated"\n' > "$APP_FILE"
  git add "$APP_FILE"
  git commit -qm "settings"

  run_expect_fail \
    "ci mode still fails when vendored settings surface changed" \
    env INFRA_REPO="$INFRA_REPO" GITHUB_EVENT_NAME=pull_request bash scripts/qa/verify-vendored-settings-drift.sh
)

echo "OK"
