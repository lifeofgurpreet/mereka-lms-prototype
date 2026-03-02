#!/usr/bin/env bash
# Capture screenshots of the public branding surfaces for prod/dev.
#
# This is an operator tool: it writes screenshots under var/ (gitignored).
# It uses `agent-browser`, so it is intended to be run by humans/agents with
# access to a browser-capable environment.
#
# Usage:
#   ./scripts/qa/capture-branding-screenshots.sh prod
#   ./scripts/qa/capture-branding-screenshots.sh --env dev
#   ./scripts/qa/capture-branding-screenshots.sh --env prod --mfe-only
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENVIRONMENT=""
MFE_ONLY=0
CORE_ROUTES_ONLY=0

usage() {
  cat <<'EOF'
Usage: capture-branding-screenshots.sh [options]

Options:
  --env <prod|dev>  Target environment.
  --mfe-only        Capture only MFE routes (authn, dashboard, learning, account).
  --core-routes     Capture only runtime-closure routes:
                    authn/login, account, learning, learner-dashboard, studio-home.
  -h, --help        Show this help.

Back-compat:
  capture-branding-screenshots.sh prod
  capture-branding-screenshots.sh dev
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -lt 2 ]] && { echo "ERROR: --env requires a value" >&2; exit 2; }
      ENVIRONMENT="$2"
      shift 2
      ;;
    --mfe-only)
      MFE_ONLY=1
      shift
      ;;
    --core-routes)
      CORE_ROUTES_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    prod|dev)
      if [[ -n "$ENVIRONMENT" ]]; then
        echo "ERROR: duplicate environment argument ($1)" >&2
        exit 2
      fi
      ENVIRONMENT="$1"
      shift
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  echo "ERROR: --env must be prod or dev" >&2
  usage >&2
  exit 2
fi

if [[ "$MFE_ONLY" == "1" && "$CORE_ROUTES_ONLY" == "1" ]]; then
  echo "ERROR: --mfe-only and --core-routes are mutually exclusive" >&2
  exit 2
fi

if ! command -v agent-browser >/dev/null 2>&1; then
  echo "agent-browser is required (Codex skill: agent-browser)." >&2
  exit 2
fi

ts="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$REPO_ROOT/var/screenshots/${ENVIRONMENT}/${ts}"
mkdir -p "$OUT_DIR"
AB_TIMEOUT_SECONDS="${AGENT_BROWSER_TIMEOUT_SECONDS:-45}"
AB_SESSION="${AGENT_BROWSER_SESSION:-branding-capture-${ts}}"
CAPTURE_RETRIES="${CAPTURE_RETRIES:-3}"
export AGENT_BROWSER_SESSION="$AB_SESSION"

ab_run() {
  timeout --foreground "${AB_TIMEOUT_SECONDS}s" agent-browser "$@" 2>&1
}

ab() {
  local out status uid session cmd
  cmd="$*"
  if out="$(ab_run "$@")"; then
    [[ -n "$out" ]] && echo "$out"
    return 0
  fi
  status=$?
  if [[ "$status" -eq 124 ]]; then
    echo "agent-browser timed out after ${AB_TIMEOUT_SECONDS}s: ${cmd}" >&2
    return 124
  fi
  if grep -q "Daemon failed to start" <<<"$out"; then
    uid="$(id -u)"
    session="${AGENT_BROWSER_SESSION:-default}"
    rm -f \
      "/run/user/${uid}/agent-browser/${session}.sock" \
      "/tmp/agent-browser-runtime-${uid}/agent-browser/${session}.sock" \
      2>/dev/null || true
    sleep 1
    if out="$(ab_run "$@")"; then
      [[ -n "$out" ]] && echo "$out"
      return 0
    fi
    status=$?
    if [[ "$status" -eq 124 ]]; then
      echo "agent-browser timed out after ${AB_TIMEOUT_SECONDS}s (retry): ${cmd}" >&2
      return 124
    fi
  fi
  echo "$out" >&2
  return "$status"
}

wait_for_rendered_content() {
  local label=$1
  local target_url=${2:-}
  local max_attempts=20
  local attempt title text_len current_url min_text

  min_text=40
  case "$label" in
    studio-home|studio-*)
      min_text=80
      ;;
    mfe-authn-login|mfe-account|mfe-account-settings|mfe-learning|mfe-learner-dashboard|biji-mfe-authn-login|biji-mfe-account)
      min_text=20
      ;;
  esac

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    title="$(ab get title 2>/dev/null || true)"
    text_len="$(ab eval '(() => (document.body?.innerText || "").trim().length)()' 2>/dev/null || true)"
    current_url="$(ab get url 2>/dev/null || true)"

    if [[ "$text_len" =~ ^[0-9]+$ ]] && [[ "$text_len" -ge "$min_text" ]] && [[ -n "${title:-}" ]]; then
      return 0
    fi

    # Account/dashboard routes commonly redirect client-side to authn/login.
    # Wait for the redirect target to render meaningful content before capture.
    if [[ "$current_url" == *"/authn/login"* ]] && [[ "$text_len" =~ ^[0-9]+$ ]] && [[ "$text_len" -ge 20 ]]; then
      return 0
    fi

    # Studio/LMS pages can take longer to hydrate after first paint on dev.
    if [[ "$label" == studio-* || "$label" == lms-* ]]; then
      if [[ "$text_len" =~ ^[0-9]+$ ]] && [[ "$text_len" -ge 60 ]] && [[ "$current_url" == https://* ]]; then
        return 0
      fi
    fi

    # Target URL resolved and has enough content; accept even if title is delayed.
    if [[ -n "$target_url" ]] && [[ "$text_len" =~ ^[0-9]+$ ]] && [[ "$text_len" -ge "$min_text" ]]; then
      if [[ "$current_url" == "${target_url}"* || "$current_url" == *"/authn/login"* ]]; then
        return 0
      fi
    fi

    sleep 1
  done

  echo "WARN: timed out waiting for rendered content ($label)" >&2
  return 0
}

probe_me_status() {
  local probe
  probe="$(
    ab eval '(() => {
      try {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", "/api/user/v1/me", false);
        xhr.withCredentials = true;
        xhr.setRequestHeader("Accept", "application/json");
        xhr.send(null);
        const body = String(xhr.responseText || "");
        const hasUsername = /"username"\s*:/.test(body) ? "username" : "no_username";
        return `${xhr.status}|${hasUsername}`;
      } catch (_err) {
        return "na|na";
      }
    })()' 2>/dev/null || true
  )"
  probe="${probe//$'\t'/ }"
  probe="${probe//$'\n'/ }"
  if [[ -z "${probe:-}" ]]; then
    echo "na|na"
    return 0
  fi
  echo "$probe"
}

probe_login_refresh_status() {
  local probe
  probe="$(
    ab eval '(() => {
      try {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", "/login_refresh", false);
        xhr.withCredentials = true;
        xhr.send(null);
        return String(xhr.status || "na");
      } catch (_err) {
        return "na";
      }
    })()' 2>/dev/null || true
  )"
  probe="${probe//$'\t'/ }"
  probe="${probe//$'\n'/ }"
  if [[ -z "${probe:-}" ]]; then
    echo "na"
    return 0
  fi
  echo "$probe"
}

capture_route() {
  local label=$1
  local url=$2
  local file=$3
  local summary_file=$4
  local attempt current_url title text_len node_count nav_ms min_nodes auth_state me_status login_refresh_status

  min_nodes=20
  case "$label" in
    mfe-learning)
      min_nodes=5
      ;;
  esac

  for ((attempt = 1; attempt <= CAPTURE_RETRIES; attempt++)); do
    ab open "$url" >/dev/null
    ab wait --load networkidle >/dev/null || true
    wait_for_rendered_content "$label" "$url"

    current_url="$(ab get url 2>/dev/null || true)"
    title="$(ab get title 2>/dev/null || true)"
    text_len="$(ab eval '(() => (document.body?.innerText || "").trim().length)()' 2>/dev/null || true)"
    node_count="$(ab eval '(() => document.querySelectorAll("body *").length)()' 2>/dev/null || true)"
    nav_ms="$(ab eval '(() => { const n = performance.getEntriesByType("navigation")[0]; if (!n) return "na"; const dcl = Number(n.domContentLoadedEventEnd || 0); const dur = Number(n.duration || 0); if (dcl > 0) return Math.round(dcl); if (dur > 0) return Math.round(dur); return "na"; })()' 2>/dev/null || true)"
    me_status="$(probe_me_status)"
    login_refresh_status="$(probe_login_refresh_status)"

    auth_state="$(classify_auth_state "$label" "$current_url")"

    if [[ "$text_len" =~ ^[0-9]+$ ]] && [[ "$node_count" =~ ^[0-9]+$ ]]; then
      if [[ "$text_len" -ge 20 ]] && [[ "$node_count" -ge "$min_nodes" ]]; then
        ab screenshot --full "$file" >/dev/null
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$label" "$attempt" "$auth_state" "${nav_ms:-na}" "${me_status:-na|na}" "${login_refresh_status:-na}" "$current_url" "$text_len" "$node_count" "$title" | tr '\n' ' ' >>"$summary_file"
        printf "\n" >>"$summary_file"
        return 0
      fi
    fi

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$label" "$attempt" "$auth_state" "${nav_ms:-na}" "${me_status:-na|na}" "${login_refresh_status:-na}" "$current_url" "${text_len:-na}" "${node_count:-na}" "${title:-}" | tr '\n' ' ' >>"$summary_file"
    printf "\n" >>"$summary_file"
    if [[ "$attempt" -lt "$CAPTURE_RETRIES" ]]; then
      echo "WARN: low-content capture probe for $label (attempt $attempt/$CAPTURE_RETRIES), retrying" >&2
      sleep 2
    fi
  done

  echo "WARN: capturing fallback screenshot for $label after $CAPTURE_RETRIES attempts" >&2
  ab screenshot --full "$file" >/dev/null
  return 0
}

classify_auth_state() {
  local label=$1
  local final_url=${2:-}

  if [[ "$label" == "mfe-authn-login" || "$label" == "biji-mfe-authn-login" ]]; then
    if [[ "$final_url" == *"/authn/login"* ]]; then
      echo "login_page"
    else
      echo "unexpected_non_login"
    fi
    return 0
  fi

  if [[ "$label" == "mfe-account" || "$label" == "mfe-account-settings" || "$label" == "mfe-learner-dashboard" || "$label" == "biji-mfe-account" ]]; then
    if [[ "$final_url" == *"/authn/login"* ]]; then
      echo "redirected_to_login"
    else
      echo "session_or_public"
    fi
    return 0
  fi

  if [[ "$final_url" == *"/authn/login"* ]]; then
    echo "authn_redirect"
  else
    echo "resolved"
  fi
}

base_lms="$LMS_DOMAIN"
base_studio="$STUDIO_DOMAIN"
base_mfe="$MFE_DOMAIN"
base_ecommerce="$ECOMMERCE_DOMAIN"
base_credentials="$CREDENTIALS_DOMAIN"
biji="$BIJI_DOMAIN"
sof="$SKILLOURFUTURE_DOMAIN"
biji_studio="$BIJI_STUDIO_DOMAIN"
biji_mfe="$BIJI_MFE_DOMAIN"

if [[ "$ENVIRONMENT" == "dev" ]]; then
  base_lms="$DEV_LMS_DOMAIN"
  base_studio="$DEV_STUDIO_DOMAIN"
  base_mfe="$DEV_MFE_DOMAIN"
  base_ecommerce="$DEV_ECOMMERCE_DOMAIN"
  base_credentials="$DEV_CREDENTIALS_DOMAIN"
  biji="" # dev does not serve biji/sof microsites
  sof=""
  biji_studio=""
  biji_mfe=""
fi

declare -a URLS=()
if [[ "$CORE_ROUTES_ONLY" == "1" ]]; then
  URLS=(
    "mfe-authn-login|https://${base_mfe}/authn/login"
    "mfe-learning|https://${base_mfe}/learning/"
    "mfe-account|https://${base_mfe}/account/"
    "mfe-learner-dashboard|https://${base_mfe}/learner-dashboard/"
    "studio-home|https://${base_studio}/"
  )
elif [[ "$MFE_ONLY" == "1" ]]; then
  URLS=(
    "mfe-authn-login|https://${base_mfe}/authn/login"
    "mfe-learning|https://${base_mfe}/learning/"
    "mfe-account|https://${base_mfe}/account/"
    "mfe-account-settings|https://${base_mfe}/account/settings"
    "mfe-learner-dashboard|https://${base_mfe}/learner-dashboard/"
  )
  if [[ -n "$biji_mfe" ]]; then
    URLS+=("biji-mfe-authn-login|https://${biji_mfe}/authn/login")
    URLS+=("biji-mfe-account|https://${biji_mfe}/account/")
  fi
else
  URLS=(
    "lms-home|https://${base_lms}/"
    "lms-courses|https://${base_lms}/courses"
    "studio-home|https://${base_studio}/"
    "mfe-authn-login|https://${base_mfe}/authn/login"
    "mfe-learning|https://${base_mfe}/learning/"
    "mfe-account|https://${base_mfe}/account/"
    "mfe-account-settings|https://${base_mfe}/account/settings"
    "mfe-learner-dashboard|https://${base_mfe}/learner-dashboard/"
    "ecommerce-root|https://${base_ecommerce}/"
    "ecommerce-dashboard|https://${base_ecommerce}/dashboard/"
    "ecommerce-basket|https://${base_ecommerce}/basket/"
    "ecommerce-checkout|https://${base_ecommerce}/checkout/"
    "ecommerce-stripe-webhook|https://${base_ecommerce}/api/v2/webhooks/stripe/"
    "credentials-admin-login|https://${base_credentials}/admin/login/"
    "forum-home|https://forum.${base_lms}/"
    "forum-heartbeat|https://forum.${base_lms}/heartbeat"
    "notes-root|https://notes.${base_lms}/"
  )

  if [[ -n "$biji" ]]; then
    URLS+=("biji-home|https://${biji}/")
  fi
  if [[ -n "$biji_studio" ]]; then
    URLS+=("biji-studio-home|https://${biji_studio}/")
  fi
  if [[ -n "$biji_mfe" ]]; then
    URLS+=("biji-mfe-authn-login|https://${biji_mfe}/authn/login")
    URLS+=("biji-mfe-account|https://${biji_mfe}/account/")
  fi
  if [[ -n "$sof" ]]; then
    URLS+=("skillourfuture-home|https://${sof}/")
  fi
fi

sanitize() {
  echo "$1" | tr ' /:' '___' | tr -cd 'a-zA-Z0-9_.-'
}

echo "Capturing screenshots to: $OUT_DIR (mfe_only=$MFE_ONLY)"
ab set viewport 1440 900 >/dev/null
SUMMARY_FILE="$OUT_DIR/capture-summary.tsv"
echo -e "label\tattempt\tauth_state\tnav_ms\tme_status\tlogin_refresh_status\tfinal_url\ttext_len\tnode_count\ttitle" >"$SUMMARY_FILE"

for entry in "${URLS[@]}"; do
  label="${entry%%|*}"
  url="${entry#*|}"
  file="$OUT_DIR/$(sanitize "$label").png"

  echo "- $label: $url"
  capture_route "$label" "$url" "$file" "$SUMMARY_FILE"
done

ab close >/dev/null || true

echo "OK"
echo "Capture summary: $SUMMARY_FILE"
