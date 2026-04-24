#!/usr/bin/env bash
# Fixture tests for the local bootstrap readiness verifier.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$REPO_ROOT/scripts/infra/verify-local-bootstrap-readiness.sh"

# shellcheck source=scripts/infra/verify-local-bootstrap-readiness.sh
source "$VERIFY"

expect_filtered() {
  local label="$1"
  local input="$2"
  local expected="$3"
  local actual

  actual="$(printf '%s\n' "$input" | filter_tutor_exec_noise)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL %s\nexpected:\n%s\nactual:\n%s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi

  printf 'PASS %s\n' "$label"
}

expect_filtered \
  "mysql scalar keeps numeric result after Tutor wrapper noise" \
  "Mereka LMS plugin v1.0.0 loaded
docker compose -f /tmp/tutor_env/env/local/docker-compose.yml --project-name tutor_local exec mysql sh -lc 'mysql ...'
1" \
  "1"

expect_filtered \
  "mysql scalar keeps NULL result after Tutor wrapper noise" \
  "Mereka LMS plugin v1.0.0 loaded
docker compose -f /tmp/tutor_env/env/local/docker-compose.yml --project-name tutor_local exec mysql sh -lc 'mysql ...'
NULL" \
  "NULL"

expect_filtered \
  "theme convergence details preserve real multiline SQL output" \
  "Mereka LMS plugin v1.0.0 loaded
docker compose -f /tmp/tutor_env/env/local/docker-compose.yml --project-name tutor_local exec mysql sh -lc 'mysql ...'
localhost:indigo
apps.localhost:openedx" \
  "localhost:indigo
apps.localhost:openedx"

echo "PASS test-verify-local-bootstrap-readiness"
