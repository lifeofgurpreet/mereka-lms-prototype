#!/usr/bin/env bash
# @covers AC-006, AC-009
# @spec: branding-system_spec.md
# Verify Studio authoring branding signals for create-course/create-library flows.
#
# This script is deterministic:
# - Source mode checks selector coverage in theme override CSS.
# - Live mode checks the deployed themed Studio CSS bundle for the same selectors.
# - Optional screenshot mode captures Studio pages for human review.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "$SCRIPT_DIR/../shared/config.sh"

COMMON_OVERRIDE_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"

usage() {
  cat <<'EOF'
Usage: scripts/qa/verify-studio-authoring-branding.sh [prod|dev] [--source-only] [--capture]

Flags:
  --source-only   Only validate source selector coverage (no network calls).
  --capture       Capture Studio screenshots under var/screenshots/studio-authoring/.

Environment:
  STRICT_NO_GOOGLE_FONTS=1|0   Default: 0. Fail live check if Studio CSS imports fonts.googleapis.com.
EOF
}

ENVIRONMENT="${1:-prod}"
if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  usage
  exit 1
fi
shift || true

SOURCE_ONLY=0
CAPTURE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-only) SOURCE_ONLY=1; shift ;;
    --capture) CAPTURE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

STRICT_NO_GOOGLE_FONTS="${STRICT_NO_GOOGLE_FONTS:-0}"
STUDIO_CURL_INSECURE="${STUDIO_CURL_INSECURE:-auto}"
failures=0
FETCH_CURL_FLAGS=()
AGENT_BROWSER_FLAGS=()

ok() { printf "✓ %s\n" "$1"; }
fail() { printf "✗ %s\n" "$1" >&2; failures=$((failures + 1)); }

assert_contains() {
  local file=$1
  local pattern=$2
  local label=$3
  if rg -q -- "$pattern" "$file"; then
    ok "$label"
  else
    fail "$label (missing pattern: $pattern)"
  fi
}

check_source_selectors() {
  if [[ ! -f "$COMMON_OVERRIDE_CSS" ]]; then
    fail "Source CSS missing: $COMMON_OVERRIDE_CSS"
    return
  fi

  assert_contains "$COMMON_OVERRIDE_CSS" "action-create-course" "Source has create-course CTA selectors"
  assert_contains "$COMMON_OVERRIDE_CSS" "action-create-library" "Source has create-library CTA selectors"
  assert_contains "$COMMON_OVERRIDE_CSS" "outline-complex" "Source has outline panel selectors"
  assert_contains "$COMMON_OVERRIDE_CSS" "add-xblock-component" "Source has add-component CTA selectors"
  assert_contains "$COMMON_OVERRIDE_CSS" "--mereka-color-teal" "Source exports Mereka tokens for Studio"
}

fetch() {
  local url=$1
  curl "${FETCH_CURL_FLAGS[@]}" -sS -L --connect-timeout 10 --max-time 30 "$url" 2>/dev/null || true
}

check_live_css() {
  local studio_host html css_path css ts
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    studio_host="$STUDIO_DOMAIN"
  else
    studio_host="$DEV_STUDIO_DOMAIN"
  fi

  ts="$(date +%s)"
  html="$(fetch "https://${studio_host}/?nocache=${ts}")"
  if [[ -z "${html:-}" ]]; then
    fail "Studio host unreachable (${studio_host})"
    return
  fi

  # Accept both legacy and current Studio CSS paths:
  # - /static/studio/mereka/css/studio-main-v1.<hash>.css
  # - /static/studio/css/studio-main-v1.<hash>.css
  css_path="$(printf '%s' "$html" | rg -o '/static/studio/(mereka/)?css/studio-main-v1(\.[a-z0-9]+)?\.css' | head -n 1 || true)"
  if [[ -z "${css_path:-}" ]]; then
    fail "Studio themed CSS link missing (${studio_host})"
    return
  fi

  css="$(fetch "https://${studio_host}${css_path}?nocache=${ts}")"
  if [[ -z "${css:-}" ]]; then
    fail "Studio themed CSS unreachable (${studio_host}${css_path})"
    return
  fi

  if rg -q "action-create-course" <<<"$css"; then
    ok "Live Studio CSS has create-course selector"
  else
    fail "Live Studio CSS missing create-course selector"
  fi
  if rg -q "action-create-library" <<<"$css"; then
    ok "Live Studio CSS has create-library selector"
  else
    fail "Live Studio CSS missing create-library selector"
  fi
  if rg -q "outline-complex" <<<"$css"; then
    ok "Live Studio CSS has outline selectors"
  else
    fail "Live Studio CSS missing outline selectors"
  fi
  if rg -q "add-xblock-component" <<<"$css"; then
    ok "Live Studio CSS has add-component selectors"
  else
    fail "Live Studio CSS missing add-component selectors"
  fi

  if rg -q "fonts\\.googleapis\\.com" <<<"$css"; then
    if [[ "$STRICT_NO_GOOGLE_FONTS" == "1" ]]; then
      fail "Live Studio CSS still imports Google fonts (strict mode)"
    else
      ok "Live Studio CSS still imports Google fonts (non-strict)"
    fi
  else
    ok "Live Studio CSS has no Google font imports"
  fi
}

capture_screenshots() {
  if ! command -v agent-browser >/dev/null 2>&1; then
    fail "agent-browser not found (cannot capture screenshots)"
    return
  fi

  local studio_host ts out_dir
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    studio_host="$STUDIO_DOMAIN"
  else
    studio_host="$DEV_STUDIO_DOMAIN"
  fi

  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  out_dir="$REPO_ROOT/var/screenshots/studio-authoring/${ENVIRONMENT}/${ts}"
  mkdir -p "$out_dir"

  printf "Capturing Studio screenshots: %s\n" "$out_dir"
  agent-browser "${AGENT_BROWSER_FLAGS[@]}" set viewport 1440 900 >/dev/null
  for route in "/" "/course/" "/library/"; do
    local url file
    url="https://${studio_host}${route}"
    file="${out_dir}/studio$(echo "$route" | tr '/:' '__').png"
    agent-browser "${AGENT_BROWSER_FLAGS[@]}" open "$url" >/dev/null || true
    agent-browser "${AGENT_BROWSER_FLAGS[@]}" wait --load networkidle >/dev/null || true
    agent-browser "${AGENT_BROWSER_FLAGS[@]}" screenshot --full "$file" >/dev/null || true
  done
  agent-browser "${AGENT_BROWSER_FLAGS[@]}" close >/dev/null || true
  ok "Studio screenshots captured (${out_dir})"
}

echo "Verifying Studio authoring branding (${ENVIRONMENT})..."

if [[ "$STUDIO_CURL_INSECURE" == "auto" ]]; then
  if [[ "$ENVIRONMENT" == "dev" ]]; then
    STUDIO_CURL_INSECURE=1
  else
    STUDIO_CURL_INSECURE=0
  fi
fi
if [[ "$STUDIO_CURL_INSECURE" == "1" || "$STUDIO_CURL_INSECURE" == "true" ]]; then
  FETCH_CURL_FLAGS=(-k)
  AGENT_BROWSER_FLAGS=(--ignore-https-errors)
fi

# In CI environments without live cluster access, default to source-only mode.
if [[ "$SOURCE_ONLY" != "1" && "${CI:-}" == "true" ]]; then
  _studio_url="https://${STUDIO_DOMAIN:-studio.academyv2.mereka.io}"
  if ! curl -s --connect-timeout 3 --max-time 5 -o /dev/null "$_studio_url" 2>/dev/null; then
    echo "⚠ SKIP: Studio URL not reachable in CI environment — running source-only checks"
    SOURCE_ONLY=1
  fi
  unset _studio_url
fi


check_source_selectors

if [[ "$SOURCE_ONLY" != "1" ]]; then
  check_live_css
  if [[ "$CAPTURE" == "1" ]]; then
    capture_screenshots
  fi
else
  echo "Skipping live checks (--source-only)."
fi

echo "Studio authoring branding verification complete: failures=${failures}"
[[ "$failures" -eq 0 ]]
