#!/usr/bin/env bash
# verify-mfe-live-dom-audit.sh — Runtime selector/marker audit on configured MFE surfaces.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
E2E_DIR="$REPO_ROOT/tests/e2e"
ARTIFACT_DIR="$REPO_ROOT/var/qa"
mkdir -p "$ARTIFACT_DIR"

ENVIRONMENT="prod"
BASE_URL=""
PROJECT="${PROJECT:-chromium}"
AUDIT_PROFILE="${AUDIT_PROFILE:-standard}"
SELECTOR_AUDIT_PATH="${SELECTOR_AUDIT_PATH:-/authn/login}"
SELECTOR_AUDIT_ROUTES="${SELECTOR_AUDIT_ROUTES:-}"
SELECTOR_AUDIT_SELECTORS="${SELECTOR_AUDIT_SELECTORS:-}"
SELECTOR_AUDIT_SELECTORS_FILE="${SELECTOR_AUDIT_SELECTORS_FILE:-}"
MIN_TRACKED_SELECTOR_HITS="${MIN_TRACKED_SELECTOR_HITS:-3}"
MIN_CUSTOM_SELECTOR_HITS="${MIN_CUSTOM_SELECTOR_HITS:-0}"
REQUIRE_RUNTIME_THEME=0
REQUIRE_BRANDING_MARKERS="${REQUIRE_BRANDING_MARKERS:-1}"
AUTHENTICATED=0
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
NAMESPACE="${NAMESPACE:-}"
AUTH_STATE_FILE=""

usage() {
  cat <<'EOF'
Usage: verify-mfe-live-dom-audit.sh [options]

Options:
  --env <prod|dev>                  Target environment (default: prod)
  --base-url <url>                  LMS base URL (optional; overrides --env mapping)
  --project <name>                  Playwright project (default: chromium)
  --audit-profile <name>            Audit profile: standard|phase7_strict|phase7_full (default: standard)
  --selector-audit-path <path>      MFE route path for runtime selector audit (default: /authn/login)
  --selector-audit-routes <csv>     Comma-separated MFE route paths for DOM selector audit
  --selector-audit-selectors <csv>  Comma-separated CSS selectors to audit across routes
  --selector-audit-selectors-file   Path to newline-separated selectors (comments with # supported)
  --min-selector-hits <int>         Minimum tracked selector hits required (default: 3)
  --min-custom-selector-hits <int>  Minimum custom selectors that must match across audited routes
  --require-runtime-theme           Require runtime /theme/*.css mode in authn shell
  --require-branding-markers        Require branded markers in runtime DOM (default)
  --allow-unbranded-shell           Allow selector audit without marker assertions
  --authenticated                   Mint a live safe-session cookie and audit authenticated learner surfaces
  --context <kubectl-context>       kubectl context for authenticated mode
  --namespace <namespace>           namespace containing deploy/lms for authenticated mode
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
    --audit-profile)
      [[ $# -lt 2 ]] && { echo "ERROR: --audit-profile requires a value" >&2; exit 2; }
      AUDIT_PROFILE="$2"
      shift 2
      ;;
    --selector-audit-path)
      [[ $# -lt 2 ]] && { echo "ERROR: --selector-audit-path requires a value" >&2; exit 2; }
      SELECTOR_AUDIT_PATH="$2"
      shift 2
      ;;
    --selector-audit-routes)
      [[ $# -lt 2 ]] && { echo "ERROR: --selector-audit-routes requires a value" >&2; exit 2; }
      SELECTOR_AUDIT_ROUTES="$2"
      shift 2
      ;;
    --selector-audit-selectors)
      [[ $# -lt 2 ]] && { echo "ERROR: --selector-audit-selectors requires a value" >&2; exit 2; }
      SELECTOR_AUDIT_SELECTORS="$2"
      shift 2
      ;;
    --selector-audit-selectors-file)
      [[ $# -lt 2 ]] && { echo "ERROR: --selector-audit-selectors-file requires a value" >&2; exit 2; }
      SELECTOR_AUDIT_SELECTORS_FILE="$2"
      shift 2
      ;;
    --min-selector-hits)
      [[ $# -lt 2 ]] && { echo "ERROR: --min-selector-hits requires a value" >&2; exit 2; }
      MIN_TRACKED_SELECTOR_HITS="$2"
      shift 2
      ;;
    --min-custom-selector-hits)
      [[ $# -lt 2 ]] && { echo "ERROR: --min-custom-selector-hits requires a value" >&2; exit 2; }
      MIN_CUSTOM_SELECTOR_HITS="$2"
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
    --authenticated)
      AUTHENTICATED=1
      shift
      ;;
    --context)
      [[ $# -lt 2 ]] && { echo "ERROR: --context requires a value" >&2; exit 2; }
      KUBE_CONTEXT="$2"
      shift 2
      ;;
    --namespace)
      [[ $# -lt 2 ]] && { echo "ERROR: --namespace requires a value" >&2; exit 2; }
      NAMESPACE="$2"
      shift 2
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

if ! [[ "$MIN_CUSTOM_SELECTOR_HITS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --min-custom-selector-hits must be a non-negative integer (got: $MIN_CUSTOM_SELECTOR_HITS)" >&2
  exit 2
fi

if [[ "$REQUIRE_BRANDING_MARKERS" != "0" && "$REQUIRE_BRANDING_MARKERS" != "1" ]]; then
  echo "ERROR: REQUIRE_BRANDING_MARKERS must be 0 or 1 (got: $REQUIRE_BRANDING_MARKERS)" >&2
  exit 2
fi

if [[ "$AUTHENTICATED" == "1" ]]; then
  if [[ -z "$SELECTOR_AUDIT_ROUTES" ]]; then
    SELECTOR_AUDIT_PATH="/learner-dashboard/"
    SELECTOR_AUDIT_ROUTES="/learner-dashboard/"
  fi
  if [[ -z "$SELECTOR_AUDIT_SELECTORS" && -z "$SELECTOR_AUDIT_SELECTORS_FILE" ]]; then
    SELECTOR_AUDIT_SELECTORS=".mereka-footer"
  fi
  if [[ "$MIN_CUSTOM_SELECTOR_HITS" == "0" ]]; then
    MIN_CUSTOM_SELECTOR_HITS="1"
  fi
fi

case "$AUDIT_PROFILE" in
  standard)
    ;;
  phase7_strict)
    if [[ -z "$SELECTOR_AUDIT_ROUTES" ]]; then
      SELECTOR_AUDIT_ROUTES="/authn/login,/authn/register,/authn/reset"
    fi
    if [[ -z "$SELECTOR_AUDIT_SELECTORS_FILE" ]]; then
      SELECTOR_AUDIT_SELECTORS_FILE="$REPO_ROOT/scripts/qa/mfe-live-dom-phase7-selectors.txt"
    fi
    if [[ "$MIN_TRACKED_SELECTOR_HITS" == "3" ]]; then
      MIN_TRACKED_SELECTOR_HITS="2"
    fi
    if [[ "$MIN_CUSTOM_SELECTOR_HITS" == "0" ]]; then
      MIN_CUSTOM_SELECTOR_HITS="3"
    fi
    ;;
  phase7_full)
    if [[ -z "$SELECTOR_AUDIT_ROUTES" ]]; then
      SELECTOR_AUDIT_ROUTES="/authn/login,/authn/register,/authn/reset,/learner-dashboard/,/learning/,/account/settings"
    fi
    if [[ -z "$SELECTOR_AUDIT_SELECTORS_FILE" ]]; then
      SELECTOR_AUDIT_SELECTORS_FILE="$REPO_ROOT/scripts/qa/mfe-live-dom-phase7-full-selectors.txt"
    fi
    if [[ "$MIN_TRACKED_SELECTOR_HITS" == "3" ]]; then
      MIN_TRACKED_SELECTOR_HITS="4"
    fi
    if [[ "$MIN_CUSTOM_SELECTOR_HITS" == "0" ]]; then
      if [[ "$ENVIRONMENT" == "dev" ]]; then
        MIN_CUSTOM_SELECTOR_HITS="3"
      else
        MIN_CUSTOM_SELECTOR_HITS="8"
      fi
    fi
    ;;
  *)
    echo "ERROR: --audit-profile must be one of: standard, phase7_strict, phase7_full (got: $AUDIT_PROFILE)" >&2
    exit 2
    ;;
esac

if [[ -n "$SELECTOR_AUDIT_SELECTORS_FILE" ]]; then
  if [[ ! -f "$SELECTOR_AUDIT_SELECTORS_FILE" ]]; then
    echo "ERROR: selector audit selectors file not found: $SELECTOR_AUDIT_SELECTORS_FILE" >&2
    exit 2
  fi
  FILE_SELECTORS="$(
    python3 - "$SELECTOR_AUDIT_SELECTORS_FILE" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
items = []
for raw in path.read_text(encoding="utf-8").splitlines():
    line = raw.split("#", 1)[0].strip()
    if not line:
        continue
    items.append(line)
print(",".join(items))
PY
  )"
  if [[ -z "$SELECTOR_AUDIT_SELECTORS" ]]; then
    SELECTOR_AUDIT_SELECTORS="$FILE_SELECTORS"
  elif [[ -n "$FILE_SELECTORS" ]]; then
    SELECTOR_AUDIT_SELECTORS="$SELECTOR_AUDIT_SELECTORS,$FILE_SELECTORS"
  fi
fi

if [[ -n "$SELECTOR_AUDIT_SELECTORS" ]]; then
  SELECTOR_AUDIT_SELECTORS="$(
    python3 - "$SELECTOR_AUDIT_SELECTORS" <<'PY'
import sys

entries = [item.strip() for item in sys.argv[1].split(",") if item.strip()]
seen = set()
ordered = []
for item in entries:
    if item in seen:
      continue
    seen.add(item)
    ordered.append(item)
print(",".join(ordered))
PY
  )"
fi

if [[ -z "$SELECTOR_AUDIT_ROUTES" ]]; then
  SELECTOR_AUDIT_ROUTES="$SELECTOR_AUDIT_PATH"
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

cleanup() {
  if [[ -n "$AUTH_STATE_FILE" && -f "$AUTH_STATE_FILE" ]]; then
    rm -f "$AUTH_STATE_FILE"
  fi
}
trap cleanup EXIT

if [[ "$AUTHENTICATED" == "1" ]]; then
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "ERROR: kubectl is required for --authenticated mode" >&2
    exit 2
  fi
  if [[ -z "$KUBE_CONTEXT" || -z "$NAMESPACE" ]]; then
    echo "ERROR: --authenticated requires both --context and --namespace" >&2
    exit 2
  fi

  LMS_HOST="$(python3 - "$BASE_URL" <<'PY'
import sys
from urllib.parse import urlparse

raw = (sys.argv[1] or "").strip()
if "://" not in raw:
    raw = f"https://{raw}"
parsed = urlparse(raw)
print(parsed.hostname or "")
PY
)"
  if [[ -z "$LMS_HOST" ]]; then
    echo "ERROR: could not derive LMS host from BASE_URL=$BASE_URL" >&2
    exit 2
  fi

  set +e
  AUTH_PAYLOAD="$(
    kubectl --context "$KUBE_CONTEXT" -n "$NAMESPACE" exec -i deploy/lms -- python - <<'PY'
import json
import sys

import django

django.setup()

from common.djangoapps.student.models import UserProfile
from django.contrib.auth import BACKEND_SESSION_KEY, HASH_SESSION_KEY, SESSION_KEY
from django.contrib.sessions.backends.cache import SessionStore
from openedx.core.djangoapps.safe_sessions.middleware import SafeCookieData

user_profile = (
    UserProfile.objects.select_related("user")
    .exclude(user__is_staff=True)
    .order_by("user__id")
    .first()
)
if user_profile is None:
    raise SystemExit(3)

user = user_profile.user
session = SessionStore()
session[SESSION_KEY] = str(user.pk)
session[BACKEND_SESSION_KEY] = "django.contrib.auth.backends.ModelBackend"
session[HASH_SESSION_KEY] = user.get_session_auth_hash()
session.save()

print(json.dumps({
    "safe_cookie": str(SafeCookieData.create(session.session_key, user.pk)),
    "username": user.username,
}))
PY
  )"
  AUTH_STATUS=$?
  set -e
  if [[ "$AUTH_STATUS" -eq 3 ]]; then
    echo "ERROR: no non-staff learner with a profile exists for --authenticated mode" >&2
    exit 1
  elif [[ "$AUTH_STATUS" -ne 0 ]]; then
    echo "ERROR: failed to mint authenticated safe-session cookie via deploy/lms" >&2
    exit 1
  fi

  AUTH_STATE_FILE="$(mktemp -t mereka-e2e-auth-state.XXXXXX.json)"
  python3 - "$AUTH_PAYLOAD" "$LMS_HOST" "$MFE_ORIGIN" >"$AUTH_STATE_FILE" <<'PY'
import json
import sys
from urllib.parse import urlparse

payload = json.loads(sys.argv[1])
lms_host = sys.argv[2]
mfe_origin = sys.argv[3]
mfe_host = urlparse(mfe_origin).hostname or ""

domains = []
for candidate in (lms_host, f".{lms_host}", mfe_host):
    candidate = (candidate or "").strip()
    if candidate and candidate not in domains:
        domains.append(candidate)

cookie_records = [
    {
        "name": "sessionid",
        "value": payload["safe_cookie"],
        "domain": domain,
        "path": "/",
        "expires": -1,
        "httpOnly": True,
        "secure": True,
        "sameSite": "Lax",
    }
    for domain in domains
]

print(json.dumps({"cookies": cookie_records, "origins": []}))
PY
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
artifact="$ARTIFACT_DIR/mfe-live-dom-audit-${ENVIRONMENT}-${timestamp}.log"
: > "$artifact"

# Shipped runtime is split modules — use tenant-resolution for variant/component definitions.
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/tenant-resolution.js"
if [[ ! -f "$PLUGIN_FILE" ]]; then
  echo "ERROR: missing plugin runtime definitions: ${PLUGIN_FILE#$REPO_ROOT/}" | tee -a "$artifact" >&2
  exit 1
fi

if ! rg -qF "const MerekaAuthnContextCard = ({" "$PLUGIN_FILE" \
  || ! rg -qF "const MerekaAuthnContextMetaItem = ({ label, value }) => (" "$PLUGIN_FILE" \
  || ! rg -qF "className=\"mereka-progress-certificate-status mereka-shell-panel my-3\"" "$PLUGIN_FILE" \
  || ! rg -qF "className=\"mereka-account-id-verification-hint mereka-progress-certificate-status mereka-shell-panel mb-2\"" "$PLUGIN_FILE" \
  || ! rg -qF "className=\"mereka-additional-profile-fields mereka-progress-certificate-status mereka-shell-panel mb-3\"" "$PLUGIN_FILE"; then
  echo "ERROR: source contract missing canonical auth/account context-card markers." | tee -a "$artifact" >&2
  exit 1
fi
echo "Source contract: canonical auth/account context-card markers present" | tee -a "$artifact"

preflight_path="${SELECTOR_AUDIT_ROUTES%%,*}"
if [[ -z "$preflight_path" ]]; then
  preflight_path="$SELECTOR_AUDIT_PATH"
fi
preflight_url="${MFE_ORIGIN}${preflight_path}"
preflight_file="$(mktemp -t mereka-live-dom-preflight.XXXXXX)"
preflight_status="$(curl -ksSL -o "$preflight_file" -w '%{http_code}' "$preflight_url" || true)"
if [[ "$preflight_status" != "200" ]]; then
  echo "ERROR: DOM audit preflight failed (${preflight_url} returned HTTP ${preflight_status:-unknown})." | tee -a "$artifact" >&2
  rm -f "$preflight_file"
  exit 1
fi

if ! grep -q 'PARAGON_THEME' "$preflight_file"; then
  echo "ERROR: DOM audit preflight returned non-MFE HTML (missing PARAGON_THEME): $preflight_url" | tee -a "$artifact" >&2
  rm -f "$preflight_file"
  exit 1
fi

theme_mode="unknown"
if grep -q '/theme/core.min.css' "$preflight_file" && grep -q '/theme/mereka-brand.min.css' "$preflight_file"; then
  theme_mode="runtime-theme-urls"
elif grep -Eq 'paragon-theme-core\.[A-Za-z0-9]+\.css' "$preflight_file" \
  && grep -Eq 'brand-theme-core\.[A-Za-z0-9]+\.css' "$preflight_file"; then
  theme_mode="embedded-theme-files"
fi
rm -f "$preflight_file"

echo "Theme-mode preflight (${preflight_url}): ${theme_mode}" | tee -a "$artifact"
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

echo "Running runtime selector DOM audit (base_url=$BASE_URL, mfe_origin=$MFE_ORIGIN, project=$PROJECT, audit_profile=$AUDIT_PROFILE, selector_audit_path=$SELECTOR_AUDIT_PATH, selector_audit_routes=$SELECTOR_AUDIT_ROUTES, min_selector_hits=$MIN_TRACKED_SELECTOR_HITS, min_custom_selector_hits=$MIN_CUSTOM_SELECTOR_HITS)" | tee -a "$artifact"
if [[ "$AUTHENTICATED" == "1" ]]; then
  auth_username="$(python3 - "$AUTH_PAYLOAD" <<'PY'
import json
import sys
print(json.loads(sys.argv[1]).get("username", "unknown"))
PY
)"
  echo "Authenticated mode: enabled (context=$KUBE_CONTEXT namespace=$NAMESPACE learner=${auth_username})" | tee -a "$artifact"
fi
set -o pipefail
PLAYWRIGHT_ENV=(
  PW_CROSS_BROWSER=0
  PW_ENABLE_WEBKIT=0
  BASE_URL="$BASE_URL"
  REQUIRE_BRANDING_MARKERS="$REQUIRE_BRANDING_MARKERS"
  MIN_TRACKED_SELECTOR_HITS="$MIN_TRACKED_SELECTOR_HITS"
  SELECTOR_AUDIT_PATH="$SELECTOR_AUDIT_PATH"
  SELECTOR_AUDIT_ROUTES="$SELECTOR_AUDIT_ROUTES"
  SELECTOR_AUDIT_SELECTORS="$SELECTOR_AUDIT_SELECTORS"
  MIN_CUSTOM_SELECTOR_HITS="$MIN_CUSTOM_SELECTOR_HITS"
)
if [[ -n "$AUTH_STATE_FILE" ]]; then
  PLAYWRIGHT_ENV+=(E2E_AUTH_STATE="$AUTH_STATE_FILE")
fi
env "${PLAYWRIGHT_ENV[@]}" \
  npx playwright test tests/selector-dom-audit.spec.ts --project="$PROJECT" --reporter=list | tee -a "$artifact"

echo "Log: $artifact"
echo "Screenshots/artifacts: var/e2e-artifacts and var/e2e-report"

popd >/dev/null
