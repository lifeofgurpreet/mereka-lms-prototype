#!/usr/bin/env bash
# @covers AC-MFE-001, AC-MFE-002, AC-MFE-003, AC-MFE-004, AC-MFE-005
# @spec: mfe-branding-customization_spec.md
# run-branding-evidence-pipeline.sh — Release evidence pipeline for branding + MFE QA
#
# Runs all branding verification scripts, collects artifacts into a timestamped
# directory, and produces a markdown summary report suitable for release notes.
#
# Usage:
#   ./scripts/qa/run-branding-evidence-pipeline.sh --env prod
#   ./scripts/qa/run-branding-evidence-pipeline.sh --env prod --cross-browser --capture-screenshots
#   RETENTION_DAYS=30 RUN_SCREENSHOTS=1 ./scripts/qa/run-branding-evidence-pipeline.sh --env dev
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ENV="prod"
RUN_CROSS_BROWSER="${RUN_CROSS_BROWSER:-1}"
RUN_A11Y="${RUN_A11Y:-1}"
RUN_PERFORMANCE="${RUN_PERFORMANCE:-1}"
RUN_CERTIFICATE_BRANDING="${RUN_CERTIFICATE_BRANDING:-1}"
RUN_EMAIL_TEMPLATE_BRANDING="${RUN_EMAIL_TEMPLATE_BRANDING:-1}"
RUN_PARAGON_THEME_BUDGET="${RUN_PARAGON_THEME_BUDGET:-1}"
RUN_SLOT_COVERAGE="${RUN_SLOT_COVERAGE:-1}"
RUN_SELECTOR_HARDENING="${RUN_SELECTOR_HARDENING:-1}"
RUN_RUNTIME_THEME_CONTRACT="${RUN_RUNTIME_THEME_CONTRACT:-1}"
RUN_NPM_START_SMOKE="${RUN_NPM_START_SMOKE:-0}"
RUN_SCREENSHOTS="${RUN_SCREENSHOTS:-0}"
RUN_BASELINE_GATES="${RUN_BASELINE_GATES:-1}"
CROSS_BROWSER="${CROSS_BROWSER:-0}"
LEARNING_PATH="${LEARNING_PATH:-/learning}"
REQUIRE_RUNTIME_THEME="${REQUIRE_RUNTIME_THEME:-0}"
STRICT_WEBKIT="${STRICT_WEBKIT:-0}"
RUNTIME_THEME_URL="${RUNTIME_THEME_URL:-}"
RUNTIME_THEME_TIMEOUT_SECONDS="${RUNTIME_THEME_TIMEOUT_SECONDS:-300}"
NPM_START_BASE_URL="${NPM_START_BASE_URL:-}"
NPM_START_PROJECT="${NPM_START_PROJECT:-chromium}"
NPM_START_HEADED="${NPM_START_HEADED:-0}"
NPM_START_TIMEOUT_SECONDS="${NPM_START_TIMEOUT_SECONDS:-900}"
A11Y_SCRIPT="${A11Y_SCRIPT:-./scripts/qa/verify-accessibility.sh}"
A11Y_ARGS="${A11Y_ARGS:---offline}"

usage() {
  cat <<'EOF'
Usage: run-branding-evidence-pipeline.sh [options]

Options:
  --env <prod|dev>          Target environment (default: prod)
  --cross-browser           Run cross-browser Playwright matrix (chromium/firefox/mobile + webkit probe)
  --capture-screenshots     Capture public branding screenshots with agent-browser
  --frontend-only           Skip baseline multisite/route gates; run frontend closure gates only
  --require-runtime-theme   Enforce runtime PARAGON_THEME_URLS mode in smoke/perf checks
  -h, --help                Show this help

Environment toggles:
  RUN_CROSS_BROWSER=0|1     Enable/disable cross-browser smoke gate (default: 1)
  RUN_A11Y=0|1              Enable/disable a11y gate (default: 1)
  RUN_PERFORMANCE=0|1       Enable/disable performance gate (default: 1)
  RUN_CERTIFICATE_BRANDING=0|1
                            Enable/disable certificate/email branding gate (default: 1)
  RUN_EMAIL_TEMPLATE_BRANDING=0|1
                            Enable/disable email template branding gate (default: 1)
  RUN_PARAGON_THEME_BUDGET=0|1
                            Enable/disable Paragon theme CSS size/token budget gate (default: 1)
  RUN_SLOT_COVERAGE=0|1     Enable/disable FPF slot coverage truth gate (default: 1)
  RUN_SELECTOR_HARDENING=0|1
                            Enable/disable MFE selector hardening gate (default: 1)
  RUN_RUNTIME_THEME_CONTRACT=0|1
                            Enable/disable runtime theme contract gate (default: 1)
  RUNTIME_THEME_URL=<url>   Runtime apps origin for theme contract checks (default: env-derived)
  RUNTIME_THEME_TIMEOUT_SECONDS=<seconds>
                            Timeout for runtime theme contract gate (default: 300)
  RUN_NPM_START_SMOKE=0|1   Enable/disable npm-start MFE smoke gate (default: 0)
  NPM_START_BASE_URL=<url>  Base URL for npm-start smoke (default: env-derived prod/dev host)
  NPM_START_PROJECT=<name>  Playwright project for npm-start smoke (default: chromium)
  NPM_START_HEADED=0|1      Run npm-start smoke headed browser (default: 0)
  NPM_START_TIMEOUT_SECONDS=<seconds>
                            Timeout for npm-start smoke gate (default: 900)
  RUN_SCREENSHOTS=0|1       Enable/disable screenshot gate (default: 0)
  RUN_BASELINE_GATES=0|1    Enable/disable baseline multisite/route gates (default: 1)
  STRICT_WEBKIT=0|1         Require WebKit success in cross-browser gate (default: 0)
  A11Y_SCRIPT=<path>        A11y script path (default: ./scripts/qa/verify-accessibility.sh)
  A11Y_ARGS="<args>"        A11y script args (default: --offline)
  LEARNING_PATH=/learning   Optional learning route path for smoke checks
  RETENTION_DAYS=30         Evidence retention window in days (default: 30)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -lt 2 ]] && { echo "ERROR: --env requires a value" >&2; exit 2; }
      ENV="$2"
      shift 2
      ;;
    --cross-browser)
      CROSS_BROWSER=1
      shift
      ;;
    --capture-screenshots)
      RUN_SCREENSHOTS=1
      shift
      ;;
    --frontend-only)
      RUN_BASELINE_GATES=0
      shift
      ;;
    --require-runtime-theme)
      REQUIRE_RUNTIME_THEME=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$ENV" in
  prod|dev) ;;
  *)
    echo "ERROR: --env must be prod or dev (got: $ENV)" >&2
    exit 2
    ;;
esac

STAMP="$(date -u +%Y%m%d-%H%M%S)"
EVIDENCE_DIR="var/evidence/branding/${STAMP}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
SUMMARY_FILE="${EVIDENCE_DIR}/SUMMARY.md"

mkdir -p "$EVIDENCE_DIR"

echo "=== Branding Evidence Pipeline ==="
echo "Environment: $ENV"
echo "Evidence dir: $EVIDENCE_DIR"
echo "Retention: ${RETENTION_DAYS} days"
echo "Cross-browser: $CROSS_BROWSER (gate enabled: $RUN_CROSS_BROWSER)"
echo "A11y gate enabled: $RUN_A11Y"
echo "Performance gate enabled: $RUN_PERFORMANCE"
echo "Certificate branding gate enabled: $RUN_CERTIFICATE_BRANDING"
echo "Email template branding gate enabled: $RUN_EMAIL_TEMPLATE_BRANDING"
echo "Paragon theme budget gate enabled: $RUN_PARAGON_THEME_BUDGET"
echo "Slot coverage gate enabled: $RUN_SLOT_COVERAGE"
echo "Selector hardening gate enabled: $RUN_SELECTOR_HARDENING"
echo "Runtime theme contract gate enabled: $RUN_RUNTIME_THEME_CONTRACT"
echo "npm-start smoke gate enabled: $RUN_NPM_START_SMOKE"
echo "Screenshot gate enabled: $RUN_SCREENSHOTS"
echo "Baseline gates enabled: $RUN_BASELINE_GATES"
echo "Require runtime theme mode: $REQUIRE_RUNTIME_THEME"
echo "Require WebKit in cross-browser gate: $STRICT_WEBKIT"
echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

total_pass=0
total_fail=0
total_warn=0
gate_results=()

skip_gate() {
  local name="$1"
  local reason="$2"
  echo "Skipping: ${name} (${reason})"
  gate_results+=("| ${name} | SKIP | ${reason} |")
  total_warn=$((total_warn + 1))
}

run_gate() {
  local name="$1"; shift
  local timeout_seconds="${GATE_TIMEOUT_SECONDS:-300}"
  local log_file="${EVIDENCE_DIR}/${name}.log"
  local rc=0

  echo -n "Running: ${name}... "

  set +e
  timeout "$timeout_seconds" "$@" > "$log_file" 2>&1
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    echo "OK"
    gate_results+=("| ${name} | PASS | [log](${name}.log) |")
    total_pass=$((total_pass + 1))
  elif [[ "$rc" -eq 124 ]]; then
    echo "TIMEOUT"
    gate_results+=("| ${name} | TIMEOUT | [log](${name}.log) |")
    total_fail=$((total_fail + 1))
  else
    echo "FAIL (exit $rc)"
    gate_results+=("| ${name} | FAIL | [log](${name}.log) |")
    total_fail=$((total_fail + 1))
  fi
}

if [[ "$RUN_BASELINE_GATES" == "1" ]]; then
  # --- Gate 1: MFE Route Smoke ---
  run_gate "mfe-route-smoke" \
    ./scripts/qa/verify-mfe-route-smoke.sh --env "$ENV" --json

  # --- Gate 2: Tenant Branding Runtime ---
  run_gate "tenant-branding-runtime" \
    ./scripts/qa/verify-tenant-branding-runtime.sh --env "$ENV"

  # --- Gate 3: MFE Route Contract ---
  run_gate "mfe-route-contract" \
    ./scripts/qa/verify-mfe-route-contract.sh

  # --- Gate 4: MFE Route Drift ---
  run_gate "mfe-route-drift" \
    ./scripts/qa/verify-mfe-route-drift.sh

  # --- Gate 5: Multisite Governance ---
  run_gate "multisite-governance" \
    ./scripts/qa/run-multisite-governance-gates.sh --env "$ENV"
else
  skip_gate "mfe-route-smoke" "RUN_BASELINE_GATES=0"
  skip_gate "tenant-branding-runtime" "RUN_BASELINE_GATES=0"
  skip_gate "mfe-route-contract" "RUN_BASELINE_GATES=0"
  skip_gate "mfe-route-drift" "RUN_BASELINE_GATES=0"
  skip_gate "multisite-governance" "RUN_BASELINE_GATES=0"
fi

# --- Gate 6: FPF Slot Coverage Truth ---
if [[ "$RUN_SLOT_COVERAGE" == "1" ]]; then
  run_gate "fpf-slot-coverage" \
    ./scripts/qa/verify-fpf-slot-coverage.sh
else
  skip_gate "fpf-slot-coverage" "RUN_SLOT_COVERAGE=0"
fi

# --- Gate 7: MFE Selector Hardening ---
if [[ "$RUN_SELECTOR_HARDENING" == "1" ]]; then
  run_gate "mfe-selector-hardening" \
    ./scripts/qa/verify-mfe-selector-hardening.sh
else
  skip_gate "mfe-selector-hardening" "RUN_SELECTOR_HARDENING=0"
fi

# --- Gate 8: Frontend Branding Smoke (Playwright) ---
if [[ "$RUN_CROSS_BROWSER" == "1" ]]; then
  cross_browser_args=(--env "$ENV" --learning-path "$LEARNING_PATH")
  if [[ "$CROSS_BROWSER" == "1" ]]; then
    cross_browser_args+=(--cross-browser)
  fi
  if [[ "$REQUIRE_RUNTIME_THEME" == "1" ]]; then
    cross_browser_args+=(--require-runtime-theme)
  fi
  if [[ "$STRICT_WEBKIT" == "1" ]]; then
    cross_browser_args+=(--strict-webkit)
  fi
  run_gate "cross-browser-branding-smoke" \
    ./scripts/qa/verify-cross-browser-branding-smoke.sh "${cross_browser_args[@]}"
else
  skip_gate "cross-browser-branding-smoke" "RUN_CROSS_BROWSER=0"
fi

# --- Gate 9: Runtime Theme Contract ---
if [[ "$RUN_RUNTIME_THEME_CONTRACT" == "1" ]]; then
  runtime_theme_args=()
  if [[ -n "$RUNTIME_THEME_URL" ]]; then
    runtime_theme_args+=(--runtime-url "$RUNTIME_THEME_URL")
  elif [[ "$REQUIRE_RUNTIME_THEME" == "1" ]]; then
    case "$ENV" in
      prod) runtime_theme_args+=(--runtime-url "https://apps.academyv2.mereka.io") ;;
      dev) runtime_theme_args+=(--runtime-url "https://apps.academyv2.mereka.dev") ;;
    esac
  fi
  if [[ "$REQUIRE_RUNTIME_THEME" == "1" ]]; then
    runtime_theme_args+=(--require-runtime)
  fi
  GATE_TIMEOUT_SECONDS="$RUNTIME_THEME_TIMEOUT_SECONDS" run_gate "runtime-theme-contract" \
    ./scripts/qa/verify-paragon-runtime.sh "${runtime_theme_args[@]}"
else
  skip_gate "runtime-theme-contract" "RUN_RUNTIME_THEME_CONTRACT=0"
fi

# --- Gate 10: npm-start MFE smoke (optional) ---
if [[ "$RUN_NPM_START_SMOKE" == "1" ]]; then
  npm_start_args=(--project "$NPM_START_PROJECT" --learning-path "$LEARNING_PATH")
  if [[ -n "$NPM_START_BASE_URL" ]]; then
    npm_start_args+=(--base-url "$NPM_START_BASE_URL")
  else
    case "$ENV" in
      prod) npm_start_args+=(--base-url "https://academyv2.mereka.io") ;;
      dev) npm_start_args+=(--base-url "https://academyv2.mereka.dev") ;;
    esac
  fi
  if [[ "$REQUIRE_RUNTIME_THEME" == "1" ]]; then
    npm_start_args+=(--require-runtime-theme)
  fi
  if [[ "$NPM_START_HEADED" == "1" ]]; then
    npm_start_args+=(--headed)
  fi
  GATE_TIMEOUT_SECONDS="$NPM_START_TIMEOUT_SECONDS" run_gate "npm-start-mfe-smoke" \
    ./scripts/qa/verify-npm-start-mfe-smoke.sh "${npm_start_args[@]}"
else
  skip_gate "npm-start-mfe-smoke" "RUN_NPM_START_SMOKE=0"
fi

# --- Gate 11: Accessibility / Contrast / Focus Lane ---
if [[ "$RUN_A11Y" == "1" ]]; then
  if [[ ! -x "$A11Y_SCRIPT" ]]; then
    echo "ERROR: A11Y script is not executable or missing: $A11Y_SCRIPT" >&2
    exit 2
  fi
  a11y_args=()
  if [[ -n "$A11Y_ARGS" ]]; then
    # shellcheck disable=SC2206
    a11y_args=($A11Y_ARGS)
  fi
  run_gate "a11y-tenant-branding" \
    "$A11Y_SCRIPT" "${a11y_args[@]}"
else
  skip_gate "a11y-tenant-branding" "RUN_A11Y=0"
fi

# --- Gate 12: Frontend Performance Spot-Check ---
if [[ "$RUN_PERFORMANCE" == "1" ]]; then
  performance_args=(--env "$ENV")
  if [[ "$REQUIRE_RUNTIME_THEME" == "1" ]]; then
    performance_args+=(--require-runtime)
  fi
  run_gate "frontend-performance-spotcheck" \
    ./scripts/qa/verify-frontend-performance-spotcheck.sh "${performance_args[@]}"
else
  skip_gate "frontend-performance-spotcheck" "RUN_PERFORMANCE=0"
fi

# --- Gate 13: Paragon Theme Budget Contract ---
if [[ "$RUN_PARAGON_THEME_BUDGET" == "1" ]]; then
  run_gate "paragon-theme-budget" \
    ./scripts/qa/verify-paragon-token-coverage.sh
else
  skip_gate "paragon-theme-budget" "RUN_PARAGON_THEME_BUDGET=0"
fi

# --- Gate 14: Certificate + Email Branding Contract ---
if [[ "$RUN_CERTIFICATE_BRANDING" == "1" ]]; then
  run_gate "certificate-branding" \
    ./scripts/qa/verify-certificate-branding.sh
else
  skip_gate "certificate-branding" "RUN_CERTIFICATE_BRANDING=0"
fi

# --- Gate 15: Email Template Branding Contract ---
if [[ "$RUN_EMAIL_TEMPLATE_BRANDING" == "1" ]]; then
  run_gate "email-template-branding" \
    ./scripts/qa/verify-email-template-multilang.sh
else
  skip_gate "email-template-branding" "RUN_EMAIL_TEMPLATE_BRANDING=0"
fi

# --- Gate 16: Public Screenshot Capture (optional operator evidence) ---
if [[ "$RUN_SCREENSHOTS" == "1" ]]; then
  run_gate "capture-branding-screenshots" \
    ./scripts/qa/capture-branding-screenshots.sh "$ENV"
else
  skip_gate "capture-branding-screenshots" "RUN_SCREENSHOTS=0"
fi

# --- Generate Summary Report ---
cat > "$SUMMARY_FILE" <<EOF
# Branding Evidence Report

**Generated**: $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Environment**: ${ENV}
**Pipeline**: run-branding-evidence-pipeline.sh
**Commit**: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
**Branch**: $(git branch --show-current 2>/dev/null || echo "unknown")

## Gate Results

| Gate | Status | Log |
|------|--------|-----|
$(printf '%s\n' "${gate_results[@]}")

## Pipeline Options

- Cross-browser matrix requested: ${CROSS_BROWSER}
- Learning route: ${LEARNING_PATH}
- Runtime theme strict mode: ${REQUIRE_RUNTIME_THEME}
- WebKit strict mode: ${STRICT_WEBKIT}
- Baseline multisite/route gates enabled: ${RUN_BASELINE_GATES}
- A11y gate enabled: ${RUN_A11Y}
- A11y script: ${A11Y_SCRIPT}
- A11y args: ${A11Y_ARGS}
- Performance gate enabled: ${RUN_PERFORMANCE}
- Paragon theme budget gate enabled: ${RUN_PARAGON_THEME_BUDGET}
- Certificate branding gate enabled: ${RUN_CERTIFICATE_BRANDING}
- Email template branding gate enabled: ${RUN_EMAIL_TEMPLATE_BRANDING}
- Slot coverage gate enabled: ${RUN_SLOT_COVERAGE}
- Selector hardening gate enabled: ${RUN_SELECTOR_HARDENING}
- Runtime theme contract gate enabled: ${RUN_RUNTIME_THEME_CONTRACT}
- Runtime theme contract URL: ${RUNTIME_THEME_URL:-"(auto by env)"}
- Runtime theme contract timeout: ${RUNTIME_THEME_TIMEOUT_SECONDS}s
- npm-start smoke gate enabled: ${RUN_NPM_START_SMOKE}
- npm-start smoke base URL: ${NPM_START_BASE_URL:-"(auto by env)"}
- npm-start smoke project: ${NPM_START_PROJECT}
- npm-start smoke headed: ${NPM_START_HEADED}
- npm-start smoke timeout: ${NPM_START_TIMEOUT_SECONDS}s
- Screenshot gate enabled: ${RUN_SCREENSHOTS}

## Failure Taxonomy

| Failure Type | Remediation Owner | Priority | ETA |
|-------------|-------------------|----------|-----|
| MFE dist directory missing | Build engineer | P2 | Next image build |
| SITE_NAME fallback to default | Tenant admin | P3 | branding_config population |
| Brand color tokens absent | Tenant admin | P3 | branding_config population |
| Selector override expired | Frontend lead | P2 | Plugin-slot migration |
| Route 404 on live endpoint | DevOps | P1 | Immediate investigation |

## Artifact Inventory

$(ls -1 "$EVIDENCE_DIR" | sed 's/^/- /')

## Retention Policy

Evidence directories are retained for ${RETENTION_DAYS} days.
Cleanup: \`find var/evidence/branding -maxdepth 1 -mtime +${RETENTION_DAYS} -exec rm -rf {} +\`
EOF

echo ""
echo "=== Summary ==="
echo "Gates run: ${#gate_results[@]}"
echo "Passed: $total_pass"
echo "Failures: $total_fail"
echo "Warnings/Skips: $total_warn"
echo "Evidence: $EVIDENCE_DIR"
echo "Report: $SUMMARY_FILE"

# --- Cleanup old evidence ---
if [[ -d "var/evidence/branding" ]]; then
  find var/evidence/branding -maxdepth 1 -mindepth 1 -mtime +${RETENTION_DAYS} -exec rm -rf {} + 2>/dev/null || true
fi

echo ""
if [[ "$total_fail" -eq 0 ]]; then
  echo "ALL GATES PASSED"
  exit 0
else
  echo "GATES FAILED: $total_fail"
  exit 1
fi
