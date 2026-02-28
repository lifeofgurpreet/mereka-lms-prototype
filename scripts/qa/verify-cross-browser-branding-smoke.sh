#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
E2E_DIR="$REPO_ROOT/tests/e2e"
ARTIFACT_DIR="$REPO_ROOT/var/qa"
mkdir -p "$ARTIFACT_DIR"

ENVIRONMENT="prod"
CROSS_BROWSER=0
WEBKIT_ENABLED=1
STRICT_WEBKIT="${STRICT_WEBKIT:-0}"
LEARNING_PATH=""
REQUIRE_RUNTIME_THEME=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENVIRONMENT="${2:-}"
      shift 2
      ;;
    --cross-browser)
      CROSS_BROWSER=1
      shift
      ;;
    --learning-path)
      if [[ $# -lt 2 ]]; then
        echo "--learning-path requires a value" >&2
        exit 2
      fi
      LEARNING_PATH="${2:-}"
      shift 2
      ;;
    --require-runtime-theme)
      REQUIRE_RUNTIME_THEME=1
      shift
      ;;
    --strict-webkit)
      STRICT_WEBKIT=1
      shift
      ;;
    *)
      echo "Unknown arg: $1" >&2
      echo "Usage: $0 [--env prod|dev] [--cross-browser] [--learning-path /learning/... ] [--require-runtime-theme] [--strict-webkit]" >&2
      exit 2
      ;;
  esac
done

case "$ENVIRONMENT" in
  prod) BASE_URL="https://academyv2.mereka.io" ;;
  dev) BASE_URL="https://academyv2.mereka.dev" ;;
  *)
    echo "Invalid --env value: $ENVIRONMENT (expected prod|dev)" >&2
    exit 2
    ;;
esac

if [[ "$STRICT_WEBKIT" -eq 1 && "$CROSS_BROWSER" -ne 1 ]]; then
  echo "ERROR: --strict-webkit requires --cross-browser" >&2
  exit 2
fi

if [[ ! -f "$E2E_DIR/package.json" ]]; then
  echo "tests/e2e/package.json not found" >&2
  exit 1
fi

pushd "$E2E_DIR" >/dev/null

if [[ ! -d node_modules ]]; then
  echo "Installing e2e dependencies (npm ci)..."
  npm ci
fi

if [[ "$CROSS_BROWSER" -eq 1 ]]; then
  echo "Installing Playwright browsers: chromium firefox webkit"
  if ! npx playwright install chromium firefox webkit; then
    if [[ "$STRICT_WEBKIT" -eq 1 ]]; then
      echo "ERROR: WebKit install failed and strict mode is enabled"
      exit 1
    else
      echo "WARN: WebKit install failed (likely missing host deps); falling back to chromium+firefox projects"
      WEBKIT_ENABLED=0
      npx playwright install chromium firefox
    fi
  fi

  if [[ "$WEBKIT_ENABLED" -eq 1 ]]; then
    echo "Probing WebKit runtime launch capability..."
    if ! node <<'NODE'
const { webkit } = require('@playwright/test');
(async () => {
  const browser = await webkit.launch();
  await browser.close();
})().catch((error) => {
  console.error(error?.message || String(error));
  process.exit(1);
});
NODE
    then
      if [[ "$STRICT_WEBKIT" -eq 1 ]]; then
        echo "ERROR: WebKit launch probe failed and strict mode is enabled"
        exit 1
      else
        echo "WARN: WebKit launch probe failed; disabling webkit/mobile-safari projects for this run"
        WEBKIT_ENABLED=0
      fi
    fi
  fi
else
  echo "Installing Playwright browser: chromium"
  npx playwright install chromium
  WEBKIT_ENABLED=0
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
artifact="$ARTIFACT_DIR/cross-browser-branding-smoke-${ENVIRONMENT}-${timestamp}.log"

echo "Running branding smoke tests (env=$ENVIRONMENT, cross_browser=$CROSS_BROWSER, webkit_enabled=$WEBKIT_ENABLED, strict_webkit=$STRICT_WEBKIT)"
set -o pipefail
PW_CROSS_BROWSER="$CROSS_BROWSER" \
PW_ENABLE_WEBKIT="$WEBKIT_ENABLED" \
BRANDING_LEARNING_PATH="$LEARNING_PATH" \
REQUIRE_RUNTIME_THEME_URLS="$REQUIRE_RUNTIME_THEME" \
BASE_URL="$BASE_URL" \
npx playwright test tests/branding-smoke.spec.ts --reporter=list | tee "$artifact"

echo "Log: $artifact"

popd >/dev/null
