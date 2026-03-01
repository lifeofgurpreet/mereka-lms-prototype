#!/usr/bin/env bash
# verify-frontend-qa-make-targets.sh — guard canonical frontend QA Makefile wiring.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MAKEFILE="$REPO_ROOT/Makefile"

echo "Checking frontend QA Makefile target wiring..."

violations=0

assert_exec() {
  local rel="$1"
  if [[ ! -x "$REPO_ROOT/$rel" ]]; then
    echo "❌ Missing executable script: $rel"
    violations=1
  fi
}

assert_make_target() {
  local target="$1"
  if ! rg -n "^${target}:" "$MAKEFILE" >/dev/null; then
    echo "❌ Makefile missing target: ${target}"
    violations=1
  fi
}

assert_make_command() {
  local command="$1"
  local label="$2"
  if ! rg -n --fixed-strings "$command" "$MAKEFILE" >/dev/null; then
    echo "❌ Makefile target wiring mismatch: ${label}"
    echo "   Expected command: $command"
    violations=1
  fi
}

assert_help_entry() {
  local needle="$1"
  if ! grep -Fq -- "$needle" <<<"$HELP_OUTPUT"; then
    echo "❌ make help output missing target entry: $needle"
    violations=1
  fi
}

if [[ ! -f "$MAKEFILE" ]]; then
  echo "❌ Missing Makefile"
  exit 1
fi

HELP_OUTPUT="$(make help 2>/dev/null || true)"
if [[ -z "$HELP_OUTPUT" ]]; then
  echo "❌ make help produced no output"
  violations=1
fi

assert_exec "scripts/qa/verify-cross-browser-branding-smoke.sh"
assert_exec "scripts/qa/verify-npm-start-mfe-smoke.sh"
assert_exec "scripts/qa/run-phase7-dom-audit.sh"
assert_exec "scripts/qa/run-phase7-dom-audit-full.sh"
assert_exec "scripts/qa/capture-branding-screenshots.sh"
assert_exec "scripts/qa/verify-frontend-performance-spotcheck.sh"
assert_exec "scripts/qa/run-branding-evidence-pipeline.sh"
assert_exec "scripts/qa/verify-certificate-branding.sh"
assert_exec "scripts/qa/verify-email-template-multilang.sh"

for target in \
  qa-cross-browser-prod \
  qa-cross-browser-dev \
  qa-phase7-dom-audit \
  qa-phase7-dom-audit-dev \
  qa-phase7-dom-audit-full \
  qa-phase7-dom-audit-full-dev \
  qa-phase7-dom-audit-full-strict \
  qa-npm-start-smoke-local \
  qa-npm-start-smoke-prod \
  qa-npm-start-smoke-dev \
  qa-branding-screenshots-prod \
  qa-branding-screenshots-dev \
  qa-branding-screenshots-mfe-prod \
  qa-branding-screenshots-mfe-dev \
  qa-frontend-closure-prod \
  qa-frontend-closure-dev \
  qa-frontend-closure-prod-screenshots \
  qa-frontend-closure-prod-screenshots-mfe \
  qa-frontend-closure-dev-screenshots \
  qa-frontend-closure-dev-screenshots-mfe \
  qa-certificate-branding \
  qa-email-template-branding \
  qa-frontend-contracts \
  qa-performance-prod \
  qa-performance-dev; do
  assert_make_target "$target"
done

assert_make_command \
  './scripts/qa/verify-cross-browser-branding-smoke.sh --env prod --cross-browser --require-runtime-theme' \
  "qa-cross-browser-prod"
assert_make_command \
  './scripts/qa/verify-cross-browser-branding-smoke.sh --env dev --cross-browser' \
  "qa-cross-browser-dev"
assert_make_command \
  './scripts/qa/run-phase7-dom-audit.sh --env prod --project chromium' \
  "qa-phase7-dom-audit"
assert_make_command \
  './scripts/qa/run-phase7-dom-audit.sh --env dev --project chromium' \
  "qa-phase7-dom-audit-dev"
assert_make_command \
  './scripts/qa/run-phase7-dom-audit-full.sh --env prod --project chromium' \
  "qa-phase7-dom-audit-full"
assert_make_command \
  './scripts/qa/run-phase7-dom-audit-full.sh --env dev --project chromium' \
  "qa-phase7-dom-audit-full-dev"
assert_make_command \
  './scripts/qa/run-phase7-dom-audit-full.sh --env prod --project chromium --require-runtime-theme' \
  "qa-phase7-dom-audit-full-strict"
assert_make_command \
  './scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://localhost --require-branding-markers' \
  "qa-npm-start-smoke-local"
assert_make_command \
  './scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.io --require-runtime-theme --require-branding-markers' \
  "qa-npm-start-smoke-prod"
assert_make_command \
  './scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.dev --require-branding-markers' \
  "qa-npm-start-smoke-dev"
assert_make_command \
  './scripts/qa/capture-branding-screenshots.sh prod' \
  "qa-branding-screenshots-prod"
assert_make_command \
  './scripts/qa/capture-branding-screenshots.sh dev' \
  "qa-branding-screenshots-dev"
assert_make_command \
  './scripts/qa/capture-branding-screenshots.sh --env prod --mfe-only' \
  "qa-branding-screenshots-mfe-prod"
assert_make_command \
  './scripts/qa/capture-branding-screenshots.sh --env dev --mfe-only' \
  "qa-branding-screenshots-mfe-dev"
assert_make_command \
  './scripts/qa/run-branding-evidence-pipeline.sh --env prod --frontend-only --cross-browser --require-runtime-theme' \
  "qa-frontend-closure-prod"
assert_make_command \
  './scripts/qa/run-branding-evidence-pipeline.sh --env dev --frontend-only --cross-browser' \
  "qa-frontend-closure-dev"
assert_make_command \
  'RUN_SCREENSHOTS=1 ./scripts/qa/run-branding-evidence-pipeline.sh --env prod --frontend-only --cross-browser --capture-screenshots --require-runtime-theme' \
  "qa-frontend-closure-prod-screenshots"
assert_make_command \
  'SCREENSHOT_SCOPE=mfe-only RUN_SCREENSHOTS=1 ./scripts/qa/run-branding-evidence-pipeline.sh --env prod --frontend-only --cross-browser --capture-screenshots --require-runtime-theme' \
  "qa-frontend-closure-prod-screenshots-mfe"
assert_make_command \
  'RUN_SCREENSHOTS=1 ./scripts/qa/run-branding-evidence-pipeline.sh --env dev --frontend-only --cross-browser --capture-screenshots' \
  "qa-frontend-closure-dev-screenshots"
assert_make_command \
  'SCREENSHOT_SCOPE=mfe-only RUN_SCREENSHOTS=1 ./scripts/qa/run-branding-evidence-pipeline.sh --env dev --frontend-only --cross-browser --capture-screenshots' \
  "qa-frontend-closure-dev-screenshots-mfe"
assert_make_command \
  './scripts/qa/verify-certificate-branding.sh' \
  "qa-certificate-branding"
assert_make_command \
  './scripts/qa/verify-email-template-multilang.sh' \
  "qa-email-template-branding"
assert_make_command \
  './scripts/qa/verify-frontend-qa-make-targets.sh' \
  "qa-frontend-contracts includes verify-frontend-qa-make-targets"
assert_make_command \
  './scripts/qa/verify-mfe-live-dom-audit-workflow.sh' \
  "qa-frontend-contracts includes verify-mfe-live-dom-audit-workflow"
assert_make_command \
  './scripts/qa/verify-frontend-branding-closure-workflow.sh' \
  "qa-frontend-contracts includes verify-frontend-branding-closure-workflow"
assert_make_command \
  './scripts/qa/verify-release-evidence-workflow.sh' \
  "qa-frontend-contracts includes verify-release-evidence-workflow"
assert_make_command \
  './scripts/qa/verify-phase7-dom-audit-contract.sh' \
  "qa-frontend-contracts includes verify-phase7-dom-audit-contract"
assert_make_command \
  './scripts/qa/verify-branding-evidence-a11y-contract.sh' \
  "qa-frontend-contracts includes verify-branding-evidence-a11y-contract"
assert_make_command \
  './scripts/qa/verify-branding-evidence-screenshot-contract.sh' \
  "qa-frontend-contracts includes verify-branding-evidence-screenshot-contract"
assert_make_command \
  './scripts/qa/verify-ci-cd-pipeline.sh --section gitops' \
  "qa-frontend-contracts includes verify-ci-cd-pipeline --section gitops"
assert_make_command \
  './scripts/qa/verify-frontend-performance-spotcheck.sh --env prod --require-runtime' \
  "qa-performance-prod"
assert_make_command \
  './scripts/qa/verify-frontend-performance-spotcheck.sh --env dev' \
  "qa-performance-dev"

assert_help_entry "qa-phase7-dom-audit-full-strict"
assert_help_entry "qa-frontend-contracts"
assert_help_entry "qa-npm-start-smoke-prod"
assert_help_entry "qa-frontend-closure-dev-screenshots-mfe"

if [[ "$violations" -ne 0 ]]; then
  echo "Frontend QA Makefile target contract failed."
  exit 1
fi

echo "✅ Frontend QA Makefile target contract passed."
