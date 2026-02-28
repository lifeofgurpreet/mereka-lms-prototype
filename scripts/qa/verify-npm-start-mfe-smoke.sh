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

MFE_ORIGIN="$(python3 - "$BASE_URL" <<'PY'
import sys
from urllib.parse import urlparse

raw = (sys.argv[1] or "").strip()
if "://" not in raw:
    raw = f"https://{raw}"
parsed = urlparse(raw)
if not parsed.hostname:
    print("")
    raise SystemExit(0)
scheme = parsed.scheme or "https"
print(f"{scheme}://apps.{parsed.hostname}")
PY
)"
if [[ -z "$MFE_ORIGIN" ]]; then
  echo "ERROR: could not derive MFE origin from BASE_URL=$BASE_URL" >&2
  exit 2
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
artifact="$ARTIFACT_DIR/npm-start-mfe-smoke-${timestamp}.log"
: > "$artifact"

theme_mode="unknown"
authn_shell_url="${MFE_ORIGIN}/authn/login"
authn_shell_file="$(mktemp -t mereka-authn-shell.XXXXXX)"
if curl -ksSL "$authn_shell_url" -o "$authn_shell_file"; then
  if grep -q '/theme/core.min.css' "$authn_shell_file" && grep -q '/theme/mereka-brand.min.css' "$authn_shell_file"; then
    theme_mode="runtime-theme-urls"
  elif grep -Eq 'paragon-theme-core\.[A-Za-z0-9]+\.css' "$authn_shell_file" \
    && grep -Eq 'brand-theme-core\.[A-Za-z0-9]+\.css' "$authn_shell_file"; then
    theme_mode="embedded-theme-files"
  fi
else
  echo "WARN: unable to fetch authn shell for theme-mode preflight: $authn_shell_url" | tee -a "$artifact"
fi
rm -f "$authn_shell_file"

echo "Theme-mode preflight (${authn_shell_url}): ${theme_mode}" | tee -a "$artifact"
if [[ "$REQUIRE_RUNTIME_THEME" == "1" && "$theme_mode" != "runtime-theme-urls" ]]; then
  echo "ERROR: runtime theme mode required, but detected '${theme_mode}'." | tee -a "$artifact" >&2
  echo "Hint: deploy MFE with PARAGON_THEME_URLS active, then rerun this smoke gate." | tee -a "$artifact" >&2
  echo "Log: $artifact"
  exit 1
fi

pushd "$E2E_DIR" >/dev/null

if [[ ! -d node_modules ]]; then
  echo "Installing e2e dependencies (npm ci)..."
  npm ci
fi

echo "Installing Playwright browser: chromium" | tee -a "$artifact"
npx playwright install chromium

echo "Running npm-start MFE smoke (base_url=$BASE_URL, project=$PROJECT, learning_path=$LEARNING_PATH)" | tee -a "$artifact"
set -o pipefail
PW_CROSS_BROWSER=0 \
PW_ENABLE_WEBKIT=0 \
HEADED="$HEADED" \
BRANDING_LEARNING_PATH="$LEARNING_PATH" \
REQUIRE_RUNTIME_THEME_URLS="$REQUIRE_RUNTIME_THEME" \
BASE_URL="$BASE_URL" \
npx playwright test tests/branding-smoke.spec.ts --project="$PROJECT" --reporter=list | tee -a "$artifact"

echo "Log: $artifact"
echo "Screenshots/artifacts: var/e2e-artifacts and var/e2e-report"

popd >/dev/null
