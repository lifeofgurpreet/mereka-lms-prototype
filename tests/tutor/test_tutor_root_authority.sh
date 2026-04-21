#!/usr/bin/env bash
# Regression tests for shared Tutor root authority across the canonical
# tutor-config-save -> prepare-tutor-build-context -> verify-tutor-config flow.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREP_SOURCE="$REPO_ROOT/scripts/infra/prepare-tutor-build-context.sh"
SAVE_SOURCE="$REPO_ROOT/scripts/infra/tutor-config-save.sh"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

test_start() {
  TESTS_RUN=$((TESTS_RUN + 1))
  echo -e "${YELLOW}TEST $TESTS_RUN: $1${NC}"
}

test_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "${GREEN}  ✓ PASS${NC}"
}

test_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "${RED}  ✗ FAIL: $1${NC}"
}

make_executable() {
  chmod +x "$1"
}

echo "=== Test Suite: Tutor Root Authority ==="
echo ""

TMP_DIR="$(mktemp -d -t tutor-root-authority.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

test_start "prepare-tutor-build-context.sh respects nondefault TUTOR_ROOT"
{
  fixture="$TMP_DIR/prepare-fixture"
  custom_root="$fixture/custom-root"
  default_root="$fixture/tutor_env"
  fake_venv="$fixture/fake-venv"
  mkdir -p "$fixture/scripts/infra" \
    "$fixture/infrastructure/tutor" \
    "$fixture/infrastructure/tutor/plugins/_mereka_lms" \
    "$fixture/infrastructure/tutor/mfe-build" \
    "$fixture/bin" \
    "$fake_venv/bin"

  cp "$PREP_SOURCE" "$fixture/scripts/infra/prepare-tutor-build-context.sh"

  cat >"$fixture/bin/python3" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cat >/dev/null
printf '%s\n' "\$0" >> "$fixture/python3-invocations.txt"
exit 0
EOF
  make_executable "$fixture/bin/python3"

  cat >"$fake_venv/bin/activate" <<EOF
#!/usr/bin/env bash
export VIRTUAL_ENV="$fake_venv"
export PATH="$fixture/bin:\$PATH"
EOF

  cat >"$fixture/scripts/infra/sync-tutor-plugin-mirror.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
  make_executable "$fixture/scripts/infra/sync-tutor-plugin-mirror.sh"

  cat >"$fixture/infrastructure/tutor/apply-patches.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${TUTOR_ROOT:?}"
printf '%s\n' "$TUTOR_ROOT" > "$REPO_ROOT/observed-prepare-root.txt"
printf 'PATCHED_BY_TEST\n' >> "$TUTOR_ROOT/env/build/openedx/Dockerfile"
EOF
  make_executable "$fixture/infrastructure/tutor/apply-patches.sh"

  printf 'plugin source\n' >"$fixture/infrastructure/tutor/plugins/_mereka_lms/source.py"
  sleep 1
  mkdir -p "$custom_root/env/build/openedx" "$default_root/env/build/openedx"
  printf 'FROM raw-openedx\n' >"$custom_root/env/build/openedx/Dockerfile"
  printf 'FROM default-openedx\n' >"$default_root/env/build/openedx/Dockerfile"

  (
    cd "$fixture"
    TUTOR_ROOT="$custom_root" \
    TUTOR_VENV="$fake_venv" \
    bash "$fixture/scripts/infra/prepare-tutor-build-context.sh" --target openedx >/tmp/test-tutor-root-authority.prepare.out 2>&1
  )

  observed_prepare_root="$(cat "$fixture/observed-prepare-root.txt")"
  if [[ "$observed_prepare_root" != "$custom_root" ]]; then
    test_fail "prepare-tutor-build-context.sh used '$observed_prepare_root' instead of custom TUTOR_ROOT '$custom_root'"
  elif [[ ! -s "$fixture/python3-invocations.txt" ]]; then
    test_fail "prepare-tutor-build-context.sh did not bootstrap its patch runtime from TUTOR_VENV"
  elif ! grep -q 'PATCHED_BY_TEST' "$custom_root/env/build/openedx/Dockerfile"; then
    test_fail "prepare-tutor-build-context.sh did not mutate the custom TUTOR_ROOT Dockerfile"
  elif grep -q 'PATCHED_BY_TEST' "$default_root/env/build/openedx/Dockerfile"; then
    test_fail "prepare-tutor-build-context.sh mutated repo-default tutor_env instead of the custom TUTOR_ROOT"
  else
    test_pass
  fi
}

test_start "tutor-config-save.sh forwards custom TUTOR_ROOT to prepare and verify steps"
{
  fixture="$TMP_DIR/save-fixture"
  custom_root="$fixture/custom-root"
  default_root="$fixture/tutor_env"
  mkdir -p "$fixture/scripts/infra" \
    "$fixture/scripts/shared" \
    "$fixture/infrastructure/tutor" \
    "$fixture/bin" \
    "$custom_root" \
    "$default_root"

  cp "$SAVE_SOURCE" "$fixture/scripts/infra/tutor-config-save.sh"

  cat >"$fixture/scripts/shared/config.sh" <<'EOF'
#!/usr/bin/env bash
EOF

  cat >"$fixture/bin/tutor" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "plugins" ]]; then
  exit 0
fi
if [[ "${1:-}" == "config" && "${2:-}" == "save" ]]; then
  : "${TUTOR_ROOT:?}"
  mkdir -p "$TUTOR_ROOT"
  printf 'saved=true\n' > "$TUTOR_ROOT/config.yml"
  exit 0
fi
echo "unsupported tutor stub invocation: $*" >&2
exit 1
EOF
  make_executable "$fixture/bin/tutor"

  cat >"$fixture/scripts/infra/sync-tutor-plugin-mirror.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
  make_executable "$fixture/scripts/infra/sync-tutor-plugin-mirror.sh"

  cat >"$fixture/scripts/infra/prepare-tutor-build-context.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
printf '%s\n' "${TUTOR_ROOT:?}" > "$REPO_ROOT/observed-save-prepare-root.txt"
exit 0
EOF
  make_executable "$fixture/scripts/infra/prepare-tutor-build-context.sh"

  cat >"$fixture/scripts/infra/verify-tutor-config.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
printf '%s\n' "${TUTOR_ROOT:?}" > "$REPO_ROOT/observed-save-verify-root.txt"
exit 0
EOF
  make_executable "$fixture/scripts/infra/verify-tutor-config.sh"

  (
    cd "$fixture"
    PATH="$fixture/bin:$PATH" \
    TUTOR_ROOT="$custom_root" \
    bash "$fixture/scripts/infra/tutor-config-save.sh" --set LMS_HOST=authority.example >/tmp/test-tutor-root-authority.save.out 2>&1
  )

  observed_save_prepare_root="$(cat "$fixture/observed-save-prepare-root.txt")"
  observed_save_verify_root="$(cat "$fixture/observed-save-verify-root.txt")"
  if [[ "$observed_save_prepare_root" != "$custom_root" ]]; then
    test_fail "tutor-config-save.sh forwarded '$observed_save_prepare_root' to prepare instead of '$custom_root'"
  elif [[ "$observed_save_verify_root" != "$custom_root" ]]; then
    test_fail "tutor-config-save.sh forwarded '$observed_save_verify_root' to verify instead of '$custom_root'"
  elif [[ ! -f "$custom_root/config.yml" ]]; then
    test_fail "tutor-config-save.sh did not write config.yml inside the custom TUTOR_ROOT"
  elif [[ -f "$default_root/config.yml" ]]; then
    test_fail "tutor-config-save.sh wrote config.yml to repo-default tutor_env instead of the custom TUTOR_ROOT"
  else
    test_pass
  fi
}

test_start "tutor-config-save.sh tolerates already-enabled canonical plugins"
{
  fixture="$TMP_DIR/already-enabled-fixture"
  custom_root="$fixture/custom-root"
  mkdir -p "$fixture/scripts/infra" \
    "$fixture/scripts/shared" \
    "$fixture/infrastructure/tutor" \
    "$fixture/bin" \
    "$custom_root"

  cp "$SAVE_SOURCE" "$fixture/scripts/infra/tutor-config-save.sh"

  cat >"$fixture/scripts/shared/config.sh" <<'EOF'
#!/usr/bin/env bash
EOF

  cat >"$custom_root/config.yml" <<'EOF'
PLUGINS:
  - mereka_lms
  - mereka_lms_mfe_slots
EOF

  cat >"$fixture/bin/tutor" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "plugins" && "${2:-}" == "enable" ]]; then
  echo "plugin ${3:-} is already enabled"
  exit 42
fi
if [[ "${1:-}" == "plugins" ]]; then
  exit 0
fi
if [[ "${1:-}" == "config" && "${2:-}" == "save" ]]; then
  : "${TUTOR_ROOT:?}"
  printf 'saved=true\n' >> "$TUTOR_ROOT/config.yml"
  exit 0
fi
echo "unsupported tutor stub invocation: $*" >&2
exit 1
EOF
  make_executable "$fixture/bin/tutor"

  cat >"$fixture/scripts/infra/sync-tutor-plugin-mirror.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
  make_executable "$fixture/scripts/infra/sync-tutor-plugin-mirror.sh"

  cat >"$fixture/scripts/infra/prepare-tutor-build-context.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
printf 'prepare\n' > "$REPO_ROOT/already-enabled-prepare.txt"
exit 0
EOF
  make_executable "$fixture/scripts/infra/prepare-tutor-build-context.sh"

  cat >"$fixture/scripts/infra/verify-tutor-config.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
printf 'verify\n' > "$REPO_ROOT/already-enabled-verify.txt"
exit 0
EOF
  make_executable "$fixture/scripts/infra/verify-tutor-config.sh"

  (
    cd "$fixture"
    PATH="$fixture/bin:$PATH" \
    TUTOR_ROOT="$custom_root" \
    bash "$fixture/scripts/infra/tutor-config-save.sh" --set LMS_HOST=authority.example >/tmp/test-tutor-root-authority.already-enabled.out 2>&1
  )

  if [[ ! -f "$fixture/already-enabled-prepare.txt" ]]; then
    test_fail "tutor-config-save.sh did not continue to prepare after already-enabled plugin state"
  elif [[ ! -f "$fixture/already-enabled-verify.txt" ]]; then
    test_fail "tutor-config-save.sh did not continue to verify after already-enabled plugin state"
  elif ! grep -q "Canonical Tutor plugin already enabled in config: mereka_lms" /tmp/test-tutor-root-authority.already-enabled.out; then
    test_fail "tutor-config-save.sh did not report already-enabled mereka_lms"
  elif ! grep -q "Canonical Tutor plugin already enabled in config: mereka_lms_mfe_slots" /tmp/test-tutor-root-authority.already-enabled.out; then
    test_fail "tutor-config-save.sh did not report already-enabled mereka_lms_mfe_slots"
  else
    test_pass
  fi
}

echo ""
echo "=== Test Summary ==="
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All Tutor root authority tests passed!${NC}"
  exit 0
fi

echo -e "${RED}✗ Tutor root authority regression detected${NC}"
exit 1
