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
assert_exec "scripts/qa/verify-make-help-contract.sh"
assert_exec "scripts/qa/verify-npm-start-mfe-smoke.sh"
assert_exec "scripts/qa/run-phase7-dom-audit.sh"
assert_exec "scripts/qa/run-phase7-dom-audit-full.sh"
assert_exec "scripts/qa/verify-phase7-selector-list-coverage.sh"
assert_exec "scripts/qa/capture-branding-screenshots.sh"
assert_exec "scripts/qa/verify-frontend-performance-spotcheck.sh"
assert_exec "scripts/qa/run-branding-evidence-pipeline.sh"
assert_exec "scripts/qa/verify-certificate-branding.sh"
assert_exec "scripts/qa/verify-email-template-multilang.sh"
assert_exec "scripts/qa/verify-phase2-smoke-evidence-contract.sh"
assert_exec "scripts/qa/verify-runtime-theme-drift-lane.sh"
assert_exec "scripts/qa/verify-release-automation.sh"
assert_exec "scripts/qa/verify-branding-evidence-a11y-contract.sh"
assert_exec "scripts/qa/verify-branding-evidence-screenshot-contract.sh"
assert_exec "scripts/qa/build-branding-before-after-report.sh"

for target in \
  qa-cross-browser-prod \
  qa-cross-browser-dev \
  qa-phase7-dom-audit \
  qa-phase7-dom-audit-dev \
  qa-phase7-dom-audit-full \
  qa-phase7-dom-audit-full-dev \
  qa-phase7-dom-audit-full-strict \
  qa-phase7-selector-coverage \
  qa-phase2-smoke-evidence-prod \
  qa-phase2-smoke-evidence-dev \
  qa-phase2-smoke-evidence-contract \
  qa-runtime-theme-mode-prod \
  qa-runtime-theme-mode-dev \
  qa-paragon-theme-budget \
  qa-frontend-extended-surfaces \
  qa-npm-start-smoke \
  qa-npm-start-smoke-local \
  qa-branding-screenshots \
  qa-branding-before-after \
  qa-frontend-closure \
  qa-frontend-closure-prod \
  qa-frontend-closure-dev \
  qa-frontend-closure-prod-screenshots \
  qa-frontend-closure-prod-screenshots-mfe \
  qa-frontend-closure-dev-screenshots \
  qa-frontend-closure-dev-screenshots-mfe \
  qa-certificate-branding \
  qa-email-template-branding \
  qa-make-help-contract \
  qa-frontend-contracts \
  qa-performance-prod \
  qa-performance-dev \
  qa-frontend-runtime-qa-prod \
  qa-frontend-runtime-qa-dev; do
  assert_make_target "$target"
done

assert_make_command \
  './scripts/qa/verify-cross-browser-branding-smoke.sh --env prod --cross-browser --require-runtime-theme' \
  "qa-cross-browser-prod"
assert_make_command \
  './scripts/qa/verify-cross-browser-branding-smoke.sh --env dev --cross-browser' \
  "qa-cross-browser-dev"
assert_make_command \
  '$(MAKE) qa-cross-browser-prod' \
  "qa-frontend-runtime-qa-prod includes qa-cross-browser-prod"
assert_make_command \
  '$(MAKE) qa-a11y-prod-hybrid' \
  "qa-frontend-runtime-qa-prod includes qa-a11y-prod-hybrid"
assert_make_command \
  '$(MAKE) qa-performance-prod' \
  "qa-frontend-runtime-qa-prod includes qa-performance-prod"
assert_make_command \
  '$(MAKE) qa-cross-browser-dev' \
  "qa-frontend-runtime-qa-dev includes qa-cross-browser-dev"
assert_make_command \
  '$(MAKE) qa-a11y-dev-hybrid' \
  "qa-frontend-runtime-qa-dev includes qa-a11y-dev-hybrid"
assert_make_command \
  '$(MAKE) qa-performance-dev' \
  "qa-frontend-runtime-qa-dev includes qa-performance-dev"
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
  './scripts/qa/verify-phase7-selector-list-coverage.sh' \
  "qa-phase7-selector-coverage"
assert_make_command \
  './scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.io --require-runtime --require-slot-markers' \
  "qa-phase2-smoke-evidence-prod includes runtime preflight gate"
assert_make_command \
  './scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.io --require-runtime --require-slot-markers' \
  "qa-runtime-theme-mode-prod preflight gate"
assert_make_command \
  './scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.io --require-runtime-theme --require-branding-markers' \
  "qa-phase2-smoke-evidence-prod includes prod smoke gate"
assert_make_command \
  './scripts/qa/capture-branding-screenshots.sh --env prod --mfe-only' \
  "qa-phase2-smoke-evidence-prod includes prod screenshot capture"
assert_make_command \
  './scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.dev --require-slot-markers' \
  "qa-phase2-smoke-evidence-dev includes runtime preflight gate"
assert_make_command \
  './scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.dev --require-slot-markers' \
  "qa-runtime-theme-mode-dev preflight gate"
assert_make_command \
  './scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.dev --require-branding-markers' \
  "qa-phase2-smoke-evidence-dev includes dev smoke gate"
assert_make_command \
  './scripts/qa/capture-branding-screenshots.sh --env dev --mfe-only' \
  "qa-phase2-smoke-evidence-dev includes dev screenshot capture"
assert_make_command \
  './scripts/qa/verify-phase2-smoke-evidence-contract.sh' \
  "qa-phase2-smoke-evidence-contract includes script contract"
assert_make_command \
  './scripts/qa/verify-paragon-token-coverage.sh' \
  "qa-paragon-theme-budget"
assert_make_command \
  './scripts/qa/verify-paragon-token-coverage.sh' \
  "qa-frontend-extended-surfaces includes verify-paragon-token-coverage"
assert_make_command \
  './scripts/qa/verify-certificate-branding.sh' \
  "qa-frontend-extended-surfaces includes verify-certificate-branding"
assert_make_command \
  './scripts/qa/verify-email-template-multilang.sh' \
  "qa-frontend-extended-surfaces includes verify-email-template-multilang"
assert_make_command \
  './scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://localhost --require-branding-markers' \
  "qa-npm-start-smoke-local"
assert_make_command \
  'args="--base-url https://academyv2.mereka.io --require-branding-markers"' \
  "qa-npm-start-smoke includes prod base-url args"
assert_make_command \
  './scripts/qa/verify-npm-start-mfe-smoke.sh $$args' \
  "qa-npm-start-smoke delegates to verify-npm-start-mfe-smoke.sh"
assert_make_command \
  './scripts/qa/capture-branding-screenshots.sh $$args' \
  "qa-branding-screenshots delegates to capture-branding-screenshots.sh"
assert_make_command \
  './scripts/qa/build-branding-before-after-report.sh $$args' \
  "qa-branding-before-after delegates to build-branding-before-after-report.sh"
assert_make_command \
  'args="--env $(QA_ENV) --frontend-only"' \
  "qa-frontend-closure base args"
assert_make_command \
  './scripts/qa/run-branding-evidence-pipeline.sh $$args' \
  "qa-frontend-closure delegates to run-branding-evidence-pipeline.sh"
assert_make_command \
  '$(MAKE) qa-frontend-closure QA_ENV=prod QA_CROSS_BROWSER=1 QA_REQUIRE_RUNTIME_THEME=1' \
  "qa-frontend-closure-prod"
assert_make_command \
  '$(MAKE) qa-frontend-closure QA_ENV=dev QA_CROSS_BROWSER=1' \
  "qa-frontend-closure-dev"
assert_make_command \
  '$(MAKE) qa-frontend-closure QA_ENV=prod QA_CROSS_BROWSER=1 QA_CAPTURE_SCREENSHOTS=1 QA_REQUIRE_RUNTIME_THEME=1' \
  "qa-frontend-closure-prod-screenshots"
assert_make_command \
  '$(MAKE) qa-frontend-closure QA_ENV=prod QA_CROSS_BROWSER=1 QA_CAPTURE_SCREENSHOTS=1 QA_MFE_ONLY=1 QA_REQUIRE_RUNTIME_THEME=1' \
  "qa-frontend-closure-prod-screenshots-mfe"
assert_make_command \
  '$(MAKE) qa-frontend-closure QA_ENV=dev QA_CROSS_BROWSER=1 QA_CAPTURE_SCREENSHOTS=1' \
  "qa-frontend-closure-dev-screenshots"
assert_make_command \
  '$(MAKE) qa-frontend-closure QA_ENV=dev QA_CROSS_BROWSER=1 QA_CAPTURE_SCREENSHOTS=1 QA_MFE_ONLY=1' \
  "qa-frontend-closure-dev-screenshots-mfe"
assert_make_command \
  './scripts/qa/verify-certificate-branding.sh' \
  "qa-certificate-branding"
assert_make_command \
  './scripts/qa/verify-email-template-multilang.sh' \
  "qa-email-template-branding"
assert_make_command \
  './scripts/qa/verify-make-help-contract.sh' \
  "qa-make-help-contract"
assert_make_command \
  './scripts/qa/verify-make-help-contract.sh' \
  "qa-frontend-contracts includes verify-make-help-contract"
assert_make_command \
  './scripts/qa/verify-frontend-qa-make-targets.sh' \
  "qa-frontend-contracts includes verify-frontend-qa-make-targets"
assert_make_command \
  '$(MAKE) qa-frontend-extended-surfaces' \
  "qa-frontend-contracts includes qa-frontend-extended-surfaces aggregator"
assert_make_command \
  './scripts/qa/verify-release-automation.sh' \
  "qa-frontend-contracts includes verify-release-automation"
assert_make_command \
  './scripts/qa/verify-phase2-smoke-evidence-contract.sh' \
  "qa-frontend-contracts includes verify-phase2-smoke-evidence-contract"
assert_make_command \
  './scripts/qa/verify-phase7-dom-audit-contract.sh' \
  "qa-frontend-contracts includes verify-phase7-dom-audit-contract"
assert_make_command \
  './scripts/qa/verify-phase7-selector-list-coverage.sh' \
  "qa-frontend-contracts includes verify-phase7-selector-list-coverage"
assert_make_command \
  './scripts/qa/verify-runtime-theme-drift-lane.sh' \
  "qa-frontend-contracts includes verify-runtime-theme-drift-lane"
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
assert_help_entry "qa-phase7-selector-coverage"
assert_help_entry "qa-phase2-smoke-evidence-prod"
assert_help_entry "qa-phase2-smoke-evidence-dev"
assert_help_entry "qa-phase2-smoke-evidence-contract"
assert_help_entry "qa-runtime-theme-mode-prod"
assert_help_entry "qa-runtime-theme-mode-dev"
assert_help_entry "qa-paragon-theme-budget"
assert_help_entry "qa-frontend-extended-surfaces"
assert_help_entry "qa-frontend-runtime-qa-prod"
assert_help_entry "qa-frontend-runtime-qa-dev"
assert_help_entry "qa-make-help-contract"
assert_help_entry "qa-frontend-contracts"
assert_help_entry "qa-npm-start-smoke"
assert_help_entry "qa-branding-screenshots"
assert_help_entry "qa-branding-before-after"
assert_help_entry "qa-frontend-closure"
assert_help_entry "qa-frontend-closure-dev-screenshots-mfe"
assert_help_entry "qa-frontend-closure-prod-screenshots-mfe"
assert_help_entry "qa-frontend-closure-dev-screenshots"

if [[ "$violations" -ne 0 ]]; then
  echo "Frontend QA Makefile target contract failed."
  exit 1
fi

echo "✅ Frontend QA Makefile target contract passed."
