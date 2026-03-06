#!/usr/bin/env bash
# Ensure a credentialed Studio-capable SSO canary exists end-to-end:
# - Authentik user exists and password matches Infisical source-of-truth
# - Open edX LMS/CMS user exists and has minimal Studio access (staff + CourseCreator)
# - GitHub repo secrets/variable are synced so CI can run the canary gate
#
# This script never prints secret values.
#
# Usage:
#   ./scripts/infra/ensure-studio-sso-canary.sh --verify
#   CONFIRM_ENSURE_STUDIO_SSO_CANARY=ENSURE_STUDIO_SSO_CANARY ALLOW_PROD_APPLY=1 \
#     ./scripts/infra/ensure-studio-sso-canary.sh --apply
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

MODE="verify" # verify | apply

# K8s targets
K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
OPENEDX_NAMESPACE="${OPENEDX_NAMESPACE:-mereka-lms}"
AUTHENTIK_NAMESPACE="${AUTHENTIK_NAMESPACE:-authentik}"
AUTHENTIK_DEPLOY="${AUTHENTIK_DEPLOY:-authentik-server}"
AUTHENTIK_AK_BIN="${AUTHENTIK_AK_BIN:-/lifecycle/ak}"
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-0}"
CREATE_PREOP_BACKUP="${CREATE_PREOP_BACKUP:-1}"
CONFIRM_ENSURE_STUDIO_SSO_CANARY="${CONFIRM_ENSURE_STUDIO_SSO_CANARY:-}"
CONFIRM_TOKEN="ENSURE_STUDIO_SSO_CANARY"

# Infisical source of truth
INFISICAL_DOMAIN="${INFISICAL_DOMAIN:-https://secrets.mereka.io/api}"
INFISICAL_ENV="${INFISICAL_ENV:-prod}"
INFISICAL_PATH="${INFISICAL_PATH:-/shared/oauth}"
INFISICAL_DIR="${INFISICAL_DIR:-}"
INFISICAL_PROJECT_ID="${INFISICAL_PROJECT_ID:-}"
INFISICAL_TOKEN="${INFISICAL_TOKEN:-}"

# Canary identity (intentionally separate from human admins)
CANARY_EMAIL="${CANARY_EMAIL:-sso-canary-studio@mereka.io}"
CANARY_DISPLAY_NAME="${CANARY_DISPLAY_NAME:-SSO Studio Canary}"

# Store canary creds in Infisical under /shared/oauth
INFISICAL_KEY_EMAIL="SSO_CANARY_STUDIO_EMAIL_PROD"
INFISICAL_KEY_PASSWORD="SSO_CANARY_STUDIO_PASSWORD_PROD"

REPO_SLUG="${REPO_SLUG:-Biji-Biji-Initiative/mereka-lms}"
SYNC_GITHUB="${SYNC_GITHUB:-1}"
ENABLE_RUNTIME_GATE="${ENABLE_RUNTIME_GATE:-1}"

usage() {
  cat <<EOF >&2
Usage: $0 [--verify|--apply]

Ensures:
  - Authentik user exists: $CANARY_EMAIL
  - Infisical secrets exist: $INFISICAL_PATH/$INFISICAL_KEY_EMAIL and $INFISICAL_KEY_PASSWORD
  - Open edX user exists and can access Studio (/home) (staff + CourseCreator)
  - GitHub repo secrets/variable synced for CI canary gate

Env:
  K8S_CONTEXT=$K8S_CONTEXT
  OPENEDX_NAMESPACE=$OPENEDX_NAMESPACE
  AUTHENTIK_NAMESPACE=$AUTHENTIK_NAMESPACE
  AUTHENTIK_DEPLOY=$AUTHENTIK_DEPLOY

  CANARY_EMAIL=$CANARY_EMAIL
  SYNC_GITHUB=1|0 (default: $SYNC_GITHUB)
  ENABLE_RUNTIME_GATE=1|0 (default: $ENABLE_RUNTIME_GATE)
  ALLOW_PROD_APPLY=1 for --apply on prod-like contexts
  CREATE_PREOP_BACKUP=1 (default for prod-like contexts)
  CONFIRM_ENSURE_STUDIO_SSO_CANARY=ENSURE_STUDIO_SSO_CANARY

Infisical:
  INFISICAL_DOMAIN=$INFISICAL_DOMAIN
  INFISICAL_ENV=$INFISICAL_ENV
  INFISICAL_PATH=$INFISICAL_PATH
  INFISICAL_PROJECT_ID=... (auto inferred when possible)
  INFISICAL_TOKEN=... (optional)

GitHub:
  REPO_SLUG=$REPO_SLUG
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify) MODE="verify"; shift ;;
    --apply) MODE="apply"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

require_bool_01() {
  local var_name="$1"
  local value="$2"
  case "$value" in
    0|1) ;;
    *)
      echo "Invalid ${var_name}='${value}' (expected 0 or 1)" >&2
      exit 1
      ;;
  esac
}

is_prod_like_context() {
  local ctx="$1"
  [[ "$ctx" == *"gke_bbi-k8"* ]] || [[ "$ctx" == "prod" ]] || [[ "$ctx" == "production" ]] || [[ "$ctx" == "gke-prod" ]]
}

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
}

require_bool_01 "SYNC_GITHUB" "$SYNC_GITHUB"
require_bool_01 "ENABLE_RUNTIME_GATE" "$ENABLE_RUNTIME_GATE"
require_bool_01 "ALLOW_PROD_APPLY" "$ALLOW_PROD_APPLY"
require_bool_01 "CREATE_PREOP_BACKUP" "$CREATE_PREOP_BACKUP"

need_cmd kubectl
need_cmd infisical
need_cmd jq
if [[ "$SYNC_GITHUB" == "1" ]]; then
  need_cmd gh
fi

if [[ "$MODE" == "apply" ]]; then
  if [[ "$CONFIRM_ENSURE_STUDIO_SSO_CANARY" != "$CONFIRM_TOKEN" ]]; then
    echo "Refusing --apply without explicit confirmation token. Set CONFIRM_ENSURE_STUDIO_SSO_CANARY=${CONFIRM_TOKEN}" >&2
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT" && [[ "$ALLOW_PROD_APPLY" != "1" ]]; then
    echo "Refusing --apply on prod-like context '$K8S_CONTEXT' without ALLOW_PROD_APPLY=1" >&2
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT"; then
    if [[ "$CREATE_PREOP_BACKUP" == "1" ]]; then
      need_cmd velero
      backup_name="pre-op-${OPENEDX_NAMESPACE}-studio-sso-canary-$(date -u +%Y%m%d-%H%M)"
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Creating Velero pre-op backup: $backup_name"
      velero backup create "$backup_name" --include-namespaces "${OPENEDX_NAMESPACE},${AUTHENTIK_NAMESPACE}" --wait
    else
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] WARNING: CREATE_PREOP_BACKUP=0 on prod-like context '$K8S_CONTEXT' (operator override)"
    fi
  fi
fi

resolve_infisical_dir() {
  if [[ -n "${INFISICAL_DIR:-}" ]]; then
    return
  fi
  local candidates=(
    "/home/gurpreet/projects/secrets-management"
    "$REPO_ROOT"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}/.infisical.json" ]]; then
      INFISICAL_DIR="$candidate"
      return
    fi
  done
  INFISICAL_DIR="$REPO_ROOT"
}

infer_project_id_from_backup() {
  local backup_dir="${INFISICAL_BACKUP_DIR:-$HOME/.infisical/secrets-backup}"
  local candidate=""
  if [[ -d "$backup_dir" ]]; then
    candidate=$(ls "$backup_dir"/project_secrets_* 2>/dev/null | head -n 1 || true)
  fi
  if [[ -n "$candidate" ]]; then
    basename "$candidate" | sed -E 's/^project_secrets_([^_]+)_.*/\1/'
  fi
}

resolve_infisical_dir
if [[ -z "${INFISICAL_PROJECT_ID:-}" ]]; then
  if [[ -r "${INFISICAL_DIR}/.infisical.json" ]]; then
    INFISICAL_PROJECT_ID="$(jq -r '.workspaceId // empty' "${INFISICAL_DIR}/.infisical.json" || true)"
  fi
fi
if [[ -z "${INFISICAL_PROJECT_ID:-}" ]]; then
  INFISICAL_PROJECT_ID="$(infer_project_id_from_backup || true)"
fi
if [[ -z "${INFISICAL_PROJECT_ID:-}" ]]; then
  echo "Unable to determine Infisical projectId. Set INFISICAL_PROJECT_ID and retry." >&2
  exit 1
fi

infisical_token_args=()
if [[ -n "${INFISICAL_TOKEN:-}" ]]; then
  infisical_token_args=(--token "${INFISICAL_TOKEN}")
fi

fetch_plain_optional() {
  local key="$1"
  (cd "$INFISICAL_DIR" && infisical secrets get "$key" \
    --domain "$INFISICAL_DOMAIN" \
    --env "$INFISICAL_ENV" \
    --path "$INFISICAL_PATH" \
    --projectId "$INFISICAL_PROJECT_ID" \
    "${infisical_token_args[@]}" \
    --plain --silent) 2>/dev/null || true
}

set_infisical_from_file() {
  local file="$1"
  (cd "$INFISICAL_DIR" && infisical secrets set \
    --domain "$INFISICAL_DOMAIN" \
    --env "$INFISICAL_ENV" \
    --path "$INFISICAL_PATH" \
    --projectId "$INFISICAL_PROJECT_ID" \
    "${infisical_token_args[@]}" \
    --file "$file" \
    --type shared \
    --silent >/dev/null)
}

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

log "Mode: $MODE"
log "K8S_CONTEXT=$K8S_CONTEXT"
log "OPENEDX_NAMESPACE=$OPENEDX_NAMESPACE"
log "AUTHENTIK_NAMESPACE=$AUTHENTIK_NAMESPACE"
log "CANARY_EMAIL=$CANARY_EMAIL"

existing_email="$(fetch_plain_optional "$INFISICAL_KEY_EMAIL")"
existing_password="$(fetch_plain_optional "$INFISICAL_KEY_PASSWORD")"

if [[ "$MODE" == "verify" ]]; then
  if [[ -z "$existing_email" || -z "$existing_password" ]]; then
    echo "FAIL: missing Infisical Studio canary keys ($INFISICAL_PATH/$INFISICAL_KEY_EMAIL and/or $INFISICAL_KEY_PASSWORD)" >&2
    exit 1
  fi
else
  if [[ -z "$existing_email" || -z "$existing_password" ]]; then
    log "Infisical Studio canary keys missing; creating them (no values printed)"
    tmp_env="$(mktemp)"
    chmod 600 "$tmp_env"
    tmp_pass="$(mktemp)"
    chmod 600 "$tmp_pass"

    # Generate a strong password without printing it.
    python3 - <<'PY' >"$tmp_pass"
import secrets, string
alphabet = string.ascii_letters + string.digits + "!@#$%^&*()-_=+"
print("".join(secrets.choice(alphabet) for _ in range(42)))
PY

    {
      echo "$INFISICAL_KEY_EMAIL=$CANARY_EMAIL"
      echo "$INFISICAL_KEY_PASSWORD=$(cat "$tmp_pass")"
    } >"$tmp_env"

    set_infisical_from_file "$tmp_env"

    existing_email="$CANARY_EMAIL"
    existing_password="$(cat "$tmp_pass")"

    rm -f "$tmp_env" "$tmp_pass"
    log "Infisical Studio canary keys created"
  else
    # Ensure email matches our chosen canary identity (safe to update).
    if [[ "$existing_email" != "$CANARY_EMAIL" ]]; then
      log "Infisical $INFISICAL_KEY_EMAIL differs; updating to $CANARY_EMAIL"
      tmp_env="$(mktemp)"
      chmod 600 "$tmp_env"
      {
        echo "$INFISICAL_KEY_EMAIL=$CANARY_EMAIL"
      } >"$tmp_env"
      set_infisical_from_file "$tmp_env"
      rm -f "$tmp_env"
      existing_email="$CANARY_EMAIL"
    fi
  fi
fi

CANARY_PASSWORD="$existing_password"

if [[ "$MODE" == "apply" ]]; then
  log "Ensuring Authentik user exists and password matches Infisical (no secrets printed)"
  # Pass password via stdin to avoid putting it on the command line, and avoid
  # intermediate shells that can break the Authentik python environment.
  printf '%s\n' "$CANARY_PASSWORD" | kubectl --context "$K8S_CONTEXT" exec -i -n "$AUTHENTIK_NAMESPACE" "deploy/$AUTHENTIK_DEPLOY" -- \
    env CANARY_EMAIL="$CANARY_EMAIL" CANARY_DISPLAY_NAME="$CANARY_DISPLAY_NAME" \
    "$AUTHENTIK_AK_BIN" shell -c "
from authentik.core.models import User
import os, sys

email = os.environ.get(\"CANARY_EMAIL\", \"\").strip().lower()
display = os.environ.get(\"CANARY_DISPLAY_NAME\", \"SSO Studio Canary\")
pw = sys.stdin.readline().rstrip(\"\\n\")

if not email:
    raise SystemExit(\"CANARY_EMAIL missing\")
if not pw:
    raise SystemExit(\"CANARY_PASSWORD missing from stdin\")

u = User.objects.filter(email=email).first()
created = False
if not u:
    u = User.objects.create(username=email, email=email, name=display, is_active=True)
    created = True

u.is_active = True
u.name = display
u.set_password(pw)
u.save()
print(email, \"CREATED\" if created else \"UPDATED\", \"active=\" + str(u.is_active))
  "

  log "Ensuring Open edX user exists with minimal Studio access (staff + CourseCreator; no superuser)"
  kubectl --context "$K8S_CONTEXT" exec -i -n "$OPENEDX_NAMESPACE" deploy/lms -- \
    bash -lc 'set -euo pipefail; CANARY_EMAIL="'"$CANARY_EMAIL"'" python - <<PY
import os, sys
import django
django.setup()
from django.contrib.auth import get_user_model
from django.utils.crypto import get_random_string
User = get_user_model()
email = os.environ["CANARY_EMAIL"]
u = User.objects.filter(email=email).first() or User.objects.filter(username=email).first()
created = False
if not u:
    u = User.objects.create_user(username=email, email=email)
    created = True
u.is_active = True
u.is_staff = True
u.is_superuser = False
# Open edX OIDC pipeline returns "Your account is disabled" when the user has no
# usable LMS password, even if they authenticate via OIDC. Ensure a strong
# random password exists (not stored/printed).
if not u.has_usable_password():
    u.set_password(get_random_string(40))
u.save()
print(email, "CREATED" if created else "OK", f"active={u.is_active}", f"staff={u.is_staff}", f"superuser={u.is_superuser}")
PY'

  kubectl --context "$K8S_CONTEXT" exec -i -n "$OPENEDX_NAMESPACE" deploy/cms -- \
    bash -lc 'set -euo pipefail; CANARY_EMAIL="'"$CANARY_EMAIL"'" python - <<PY
import os
import django
django.setup()
from django.contrib.auth import get_user_model
from cms.djangoapps.course_creators.models import CourseCreator
from django.utils.crypto import get_random_string

User = get_user_model()
email = os.environ["CANARY_EMAIL"]
u = User.objects.filter(email=email).first() or User.objects.filter(username=email).first()
created = False
if not u:
    u = User.objects.create_user(username=email, email=email)
    created = True

u.is_active = True
u.is_staff = True
u.is_superuser = False
if not u.has_usable_password():
    u.set_password(get_random_string(40))
u.save()

cc = CourseCreator.objects.filter(user=u).first()
if cc:
    cc.state = CourseCreator.GRANTED
    cc.all_organizations = True
    cc.save()
    cc_state = "UPDATED"
else:
    CourseCreator.objects.create(user=u, state=CourseCreator.GRANTED, all_organizations=True)
    cc_state = "CREATED"

print(email, "CREATED" if created else "OK", f"active={u.is_active}", f"staff={u.is_staff}", f"superuser={u.is_superuser}", "CourseCreator=" + cc_state)
PY'
fi

if [[ "$SYNC_GITHUB" == "1" ]]; then
  log "Syncing Infisical -> GitHub secrets and enabling runtime gate (no secrets printed)"
  args=(--repo "$REPO_SLUG" --require-studio)
  if [[ "$ENABLE_RUNTIME_GATE" == "1" ]]; then
    args+=(--enable-runtime-gate)
  fi
  "$REPO_ROOT/scripts/infra/sync-github-authenticated-sso-canary-from-infisical.sh" "${args[@]}"
fi

if [[ "$MODE" == "apply" ]]; then
  log "Running credentialed canary (requires Studio access)"
  REQUIRE_STUDIO_CANARY=1 SSO_CANARY_TIMEOUT_SECONDS=240 \
    "$REPO_ROOT/scripts/infra/run-authenticated-sso-canary-from-infisical.sh" --env prod
fi

log "OK"
