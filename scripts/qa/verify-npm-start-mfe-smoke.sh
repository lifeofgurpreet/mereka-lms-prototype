#!/usr/bin/env bash
# Smoke-check local npm-start MFEs (authn, learning, account, profile) and capture screenshots.
#
# Intended usage:
# 1) Run `tutor dev start mfe --detach` (or individual npm start MFEs).
# 2) Execute this script from repo root.
#
# Screenshots are produced by Playwright test outputs under `var/e2e-artifacts/`.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
E2E_DIR="$REPO_ROOT/tests/e2e"
ARTIFACT_DIR="$REPO_ROOT/var/qa"
mkdir -p "$ARTIFACT_DIR"

BASE_URL="${BASE_URL:-https://localhost}"
LEARNING_PATH="${LEARNING_PATH:-/learning}"
REQUIRE_RUNTIME_THEME=0
PROJECT="${PROJECT:-chromium}"
HEADED="${HEADED:-0}"

usage() {
  cat <<'EOF'
Usage: verify-npm-start-mfe-smoke.sh [options]

Options:
  --base-url <url>            LMS base URL used to derive apps host (default: https://localhost)
  --learning-path <path>      Learning route path to include (default: /learning)
  --require-runtime-theme     Require PARAGON_THEME_URLS runtime mode (/theme/*.min.css)
  --project <name>            Playwright project (default: chromium)
  --headed                    Run headed browser (default: headless)
  -h, --help                  Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      [[ $# -lt 2 ]] && { echo "ERROR: --base-url requires a value" >&2; exit 2; }
      BASE_URL="$2"
      shift 2
      ;;
    --learning-path)
      [[ $# -lt 2 ]] && { echo "ERROR: --learning-path requires a value" >&2; exit 2; }
      LEARNING_PATH="$2"
      shift 2
      ;;
    --require-runtime-theme)
      REQUIRE_RUNTIME_THEME=1
      shift
      ;;
    --project)
      [[ $# -lt 2 ]] && { echo "ERROR: --project requires a value" >&2; exit 2; }
      PROJECT="$2"
      shift 2
      ;;
    --headed)
      HEADED=1
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

if [[ ! -f "$E2E_DIR/package.json" ]]; then
  echo "ERROR: tests/e2e/package.json not found" >&2
  exit 1
fi

pushd "$E2E_DIR" >/dev/null

if [[ ! -d node_modules ]]; then
  echo "Installing e2e dependencies (npm ci)..."
  npm ci
fi

echo "Installing Playwright browser: chromium"
npx playwright install chromium

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
artifact="$ARTIFACT_DIR/npm-start-mfe-smoke-${timestamp}.log"

echo "Running npm-start MFE smoke (base_url=$BASE_URL, project=$PROJECT, learning_path=$LEARNING_PATH)"
set -o pipefail
PW_CROSS_BROWSER=0 \
PW_ENABLE_WEBKIT=0 \
HEADED="$HEADED" \
BRANDING_LEARNING_PATH="$LEARNING_PATH" \
REQUIRE_RUNTIME_THEME_URLS="$REQUIRE_RUNTIME_THEME" \
BASE_URL="$BASE_URL" \
npx playwright test tests/branding-smoke.spec.ts --project="$PROJECT" --reporter=list | tee "$artifact"

echo "Log: $artifact"
echo "Screenshots/artifacts: var/e2e-artifacts and var/e2e-report"

popd >/dev/null
