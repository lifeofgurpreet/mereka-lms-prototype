#!/usr/bin/env bash
# verify-mfe-live-dom-audit.sh — Runtime selector/marker audit on authn MFE surface.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
E2E_DIR="$REPO_ROOT/tests/e2e"
ARTIFACT_DIR="$REPO_ROOT/var/qa"
mkdir -p "$ARTIFACT_DIR"

ENVIRONMENT="prod"
BASE_URL=""
PROJECT="${PROJECT:-chromium}"
SELECTOR_AUDIT_PATH="${SELECTOR_AUDIT_PATH:-/authn/login}"
MIN_TRACKED_SELECTOR_HITS="${MIN_TRACKED_SELECTOR_HITS:-3}"
REQUIRE_RUNTIME_THEME=0
REQUIRE_BRANDING_MARKERS="${REQUIRE_BRANDING_MARKERS:-1}"

usage() {
  cat <<'EOF'
Usage: verify-mfe-live-dom-audit.sh [options]

Options:
  --env <prod|dev>                  Target environment (default: prod)
  --base-url <url>                  LMS base URL (optional; overrides --env mapping)
  --project <name>                  Playwright project (default: chromium)
  --selector-audit-path <path>      MFE route path for runtime selector audit (default: /authn/login)
  --min-selector-hits <int>         Minimum tracked selector hits required (default: 3)
  --require-runtime-theme           Require runtime /theme/*.css mode in authn shell
  --require-branding-markers        Require branded markers in runtime DOM (default)
  --allow-unbranded-shell           Allow selector audit without marker assertions
  -h, --help                        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -lt 2 ]] && { echo "ERROR: --env requires a value" >&2; exit 2; }
      ENVIRONMENT="$2"
      shift 2
      ;;
    --base-url)
      [[ $# -lt 2 ]] && { echo "ERROR: --base-url requires a value" >&2; exit 2; }
      BASE_URL="$2"
      shift 2
      ;;
    --project)
      [[ $# -lt 2 ]] && { echo "ERROR: --project requires a value" >&2; exit 2; }
      PROJECT="$2"
      shift 2
      ;;
    --selector-audit-path)
      [[ $# -lt 2 ]] && { echo "ERROR: --selector-audit-path requires a value" >&2; exit 2; }
      SELECTOR_AUDIT_PATH="$2"
      shift 2
      ;;
    --min-selector-hits)
      [[ $# -lt 2 ]] && { echo "ERROR: --min-selector-hits requires a value" >&2; exit 2; }
      MIN_TRACKED_SELECTOR_HITS="$2"
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

if [[ -z "$BASE_URL" ]]; then
  case "$ENVIRONMENT" in
    prod) BASE_URL="https://academyv2.mereka.io" ;;
    dev) BASE_URL="https://academyv2.mereka.dev" ;;
    *)
      echo "ERROR: invalid --env value: $ENVIRONMENT (expected prod|dev)" >&2
      exit 2
      ;;
  esac
fi

if ! [[ "$MIN_TRACKED_SELECTOR_HITS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --min-selector-hits must be a non-negative integer (got: $MIN_TRACKED_SELECTOR_HITS)" >&2
  exit 2
fi

if [[ "$REQUIRE_BRANDING_MARKERS" != "0" && "$REQUIRE_BRANDING_MARKERS" != "1" ]]; then
  echo "ERROR: REQUIRE_BRANDING_MARKERS must be 0 or 1 (got: $REQUIRE_BRANDING_MARKERS)" >&2
  exit 2
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
if not host.startswith("apps."):
    host = f"apps.{host}"
port = f":{parsed.port}" if parsed.port else ""
print(f"{scheme}://{host}{port}")
PY
)"
if [[ -z "$MFE_ORIGIN" ]]; then
  echo "ERROR: could not derive MFE origin from BASE_URL=$BASE_URL" >&2
  exit 2
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
artifact="$ARTIFACT_DIR/mfe-live-dom-audit-${ENVIRONMENT}-${timestamp}.log"
: > "$artifact"

authn_shell_url="${MFE_ORIGIN}/authn/login"
authn_shell_file="$(mktemp -t mereka-live-dom-authn-shell.XXXXXX)"
authn_shell_status="$(curl -ksSL -o "$authn_shell_file" -w '%{http_code}' "$authn_shell_url" || true)"
if [[ "$authn_shell_status" != "200" ]]; then
  echo "ERROR: authn shell preflight failed (${authn_shell_url} returned HTTP ${authn_shell_status:-unknown})." | tee -a "$artifact" >&2
  rm -f "$authn_shell_file"
  exit 1
fi

if ! grep -q 'PARAGON_THEME' "$authn_shell_file"; then
  echo "ERROR: authn shell preflight returned non-MFE HTML (missing PARAGON_THEME): $authn_shell_url" | tee -a "$artifact" >&2
  rm -f "$authn_shell_file"
  exit 1
fi

theme_mode="unknown"
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
  exit 1
fi

if [[ ! -f "$E2E_DIR/package.json" ]]; then
  echo "ERROR: tests/e2e/package.json not found" >&2
  exit 1
fi

pushd "$E2E_DIR" >/dev/null

if [[ ! -d node_modules ]]; then
  echo "Installing e2e dependencies (npm ci)..." | tee -a "$artifact"
  npm ci
fi

echo "Installing Playwright browser for project: $PROJECT" | tee -a "$artifact"
case "$PROJECT" in
  firefox)
    npx playwright install firefox
    ;;
  webkit|mobile-safari)
    npx playwright install webkit
    ;;
  *)
    npx playwright install chromium
    ;;
esac

echo "Running runtime selector DOM audit (base_url=$BASE_URL, mfe_origin=$MFE_ORIGIN, project=$PROJECT, selector_audit_path=$SELECTOR_AUDIT_PATH, min_selector_hits=$MIN_TRACKED_SELECTOR_HITS)" | tee -a "$artifact"
set -o pipefail
PW_CROSS_BROWSER=0 \
PW_ENABLE_WEBKIT=0 \
BASE_URL="$BASE_URL" \
REQUIRE_BRANDING_MARKERS="$REQUIRE_BRANDING_MARKERS" \
MIN_TRACKED_SELECTOR_HITS="$MIN_TRACKED_SELECTOR_HITS" \
SELECTOR_AUDIT_PATH="$SELECTOR_AUDIT_PATH" \
npx playwright test tests/selector-dom-audit.spec.ts --project="$PROJECT" --reporter=list | tee -a "$artifact"

echo "Log: $artifact"
echo "Screenshots/artifacts: var/e2e-artifacts and var/e2e-report"

popd >/dev/null
