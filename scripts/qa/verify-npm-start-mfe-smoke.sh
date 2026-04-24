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
REQUIRE_BRANDING_MARKERS="${REQUIRE_BRANDING_MARKERS:-1}"

usage() {
  cat <<'EOF'
Usage: verify-npm-start-mfe-smoke.sh [options]

Options:
  --base-url <url>            LMS base URL used to derive apps host (default: https://localhost)
  --learning-path <path>      Learning route path to include (default: /learning)
  --require-runtime-theme     Require PARAGON_THEME_URLS runtime mode (/theme/*.min.css)
  --require-branding-markers Require branded slot markers in rendered DOM (default)
  --allow-unbranded-shell     Allow smoke pass without branded marker assertion
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
    --require-branding-markers)
      REQUIRE_BRANDING_MARKERS=1
      shift
      ;;
    --allow-unbranded-shell)
      REQUIRE_BRANDING_MARKERS=0
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

if [[ "$REQUIRE_BRANDING_MARKERS" != "0" && "$REQUIRE_BRANDING_MARKERS" != "1" ]]; then
  echo "ERROR: REQUIRE_BRANDING_MARKERS must be 0 or 1 (got: $REQUIRE_BRANDING_MARKERS)" >&2
  exit 2
fi

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
host = parsed.hostname
if host.startswith("apps."):
    mfe_host = host
else:
    mfe_host = f"apps.{host}"
port = f":{parsed.port}" if parsed.port else ""
print(f"{scheme}://{mfe_host}{port}")
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
authn_shell_status="$(curl -ksSL -o "$authn_shell_file" -w '%{http_code}' "$authn_shell_url" || true)"
if [[ "$authn_shell_status" != "200" ]]; then
  echo "ERROR: authn shell preflight failed (${authn_shell_url} returned HTTP ${authn_shell_status:-unknown})." | tee -a "$artifact" >&2
  echo "Hint: ensure local MFE shell is reachable (for example: tutor dev start mfe --detach)." | tee -a "$artifact" >&2
  rm -f "$authn_shell_file"
  exit 1
fi

if ! grep -q 'PARAGON_THEME' "$authn_shell_file"; then
  echo "ERROR: authn shell preflight returned non-MFE HTML (missing PARAGON_THEME): $authn_shell_url" | tee -a "$artifact" >&2
  echo "Hint: check reverse-proxy host routing for apps.* before running npm-start smoke." | tee -a "$artifact" >&2
  rm -f "$authn_shell_file"
  exit 1
fi

if grep -q '/theme/core.min.css' "$authn_shell_file" && grep -q '/theme/mereka-brand.min.css' "$authn_shell_file"; then
  theme_mode="runtime-theme-urls"
elif grep -Eq 'paragon-theme-core\.[A-Za-z0-9]+\.css' "$authn_shell_file" \
  && grep -Eq 'brand-theme-core\.[A-Za-z0-9]+\.css' "$authn_shell_file"; then
  theme_mode="embedded-theme-files"
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

case "$PROJECT" in
  firefox)
    browser_install_target="firefox"
    ;;
  webkit|mobile-safari)
    browser_install_target="webkit"
    ;;
  chromium|mobile-chrome)
    browser_install_target="chromium"
    ;;
  *)
    browser_install_target="chromium"
    echo "WARN: Unknown Playwright project '$PROJECT'; defaulting browser install to chromium." | tee -a "$artifact"
    ;;
esac

echo "Installing Playwright browser: ${browser_install_target}" | tee -a "$artifact"
npx playwright install "$browser_install_target"

echo "Running npm-start MFE smoke (lms_base_url=$BASE_URL, mfe_origin=$MFE_ORIGIN, project=$PROJECT, learning_path=$LEARNING_PATH)" | tee -a "$artifact"
set -o pipefail
PW_CROSS_BROWSER=0 \
PW_ENABLE_WEBKIT=0 \
HEADED="$HEADED" \
BRANDING_LEARNING_PATH="$LEARNING_PATH" \
REQUIRE_RUNTIME_THEME_URLS="$REQUIRE_RUNTIME_THEME" \
REQUIRE_BRANDING_MARKERS="$REQUIRE_BRANDING_MARKERS" \
BASE_URL="$MFE_ORIGIN" \
npx playwright test tests/branding-smoke.spec.ts --project="$PROJECT" --reporter=list | tee -a "$artifact"

echo "Log: $artifact"
echo "Screenshots/artifacts: var/e2e-artifacts and var/e2e-report"

popd >/dev/null
