#!/usr/bin/env bash
# @covers AC-007, AC-008
# @spec: secrets-management_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

INFISICAL_DOMAIN="${INFISICAL_DOMAIN:-https://secrets.mereka.io/api}"
INFISICAL_ENV="${INFISICAL_ENV:-prod}"
INFISICAL_PATH="${INFISICAL_PATH:-/k8s/mereka-lms}"
INFISICAL_DIR="${INFISICAL_DIR:-}"
INFISICAL_PROJECT_ID="${INFISICAL_PROJECT_ID:-}"
INFISICAL_CONFIG_FILE="${INFISICAL_CONFIG_FILE:-}"
INFISICAL_TOKEN="${INFISICAL_TOKEN:-}"
EXTERNAL_SECRETS_FILE="${EXTERNAL_SECRETS_FILE:-${REPO_ROOT}/deploy/k8s/base/secrets/external-secrets.yaml}"
STRICT="${STRICT:-0}"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

if ! command -v infisical >/dev/null 2>&1; then
  echo "infisical CLI not found. Install and authenticate first." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found. Install jq to continue." >&2
  exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "rg (ripgrep) not found. Install rg to continue." >&2
  exit 1
fi

if [[ ! -f "$EXTERNAL_SECRETS_FILE" ]]; then
  echo "Missing external secrets file: $EXTERNAL_SECRETS_FILE" >&2
  exit 1
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
      break
    fi
  done
}

resolve_infisical_dir

if [[ -z "${INFISICAL_DIR:-}" || ! -d "$INFISICAL_DIR" ]]; then
  # Infisical CLI can run without a repo-local .infisical.json when the user has
  # already authenticated globally (common on a VPS).
  INFISICAL_DIR="$REPO_ROOT"
fi

INFISICAL_CONFIG_FILE="${INFISICAL_CONFIG_FILE:-${INFISICAL_DIR}/.infisical.json}"

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

if [[ -z "$INFISICAL_PROJECT_ID" ]]; then
  if [[ -f "$INFISICAL_CONFIG_FILE" ]]; then
    INFISICAL_PROJECT_ID=$(jq -r '.workspaceId // empty' "$INFISICAL_CONFIG_FILE")
  fi
fi
if [[ -z "$INFISICAL_PROJECT_ID" ]]; then
  INFISICAL_PROJECT_ID=$(infer_project_id_from_backup || true)
fi

if [[ -z "$INFISICAL_PROJECT_ID" ]]; then
  echo "Unable to determine Infisical projectId. Set INFISICAL_PROJECT_ID and retry." >&2
  exit 1
fi

log "Collecting expected secret keys from all ExternalSecret files..."
# Discover all ExternalSecret YAML files (main + service-specific), excluding local dev overlays
all_es_files=("$EXTERNAL_SECRETS_FILE")
while IFS= read -r f; do
  [[ "$f" != "$EXTERNAL_SECRETS_FILE" ]] && [[ "$f" != *"/overlays/local/"* ]] && all_es_files+=("$f")
done < <(rg -l "kind: ExternalSecret" "${REPO_ROOT}/deploy" "${REPO_ROOT}/services" --glob '*.yaml' --glob '*.yml' 2>/dev/null || true)
expected_keys=""
for es_file in "${all_es_files[@]}"; do
  if [[ -f "$es_file" ]]; then
    keys_in_file=$(rg -o "MEREKA_LMS_[A-Z0-9_]+" "$es_file" || true)
    if [[ -n "$keys_in_file" ]]; then
      expected_keys="${expected_keys}${expected_keys:+$'\n'}${keys_in_file}"
    fi
  fi
done
expected_keys=$(printf "%s\n" "$expected_keys" | sort -u)

log "Collecting actual secret keys from Infisical (${INFISICAL_PATH})..."
tmpfile=$(mktemp)
tmpvalues=$(mktemp)
trap 'rm -f "$tmpfile" "$tmpvalues"' EXIT

infisical_token_args=()
if [[ -n "${INFISICAL_TOKEN:-}" ]]; then
  # Useful for CI: pass a service token instead of relying on local CLI auth state.
  infisical_token_args=(--token "${INFISICAL_TOKEN}")
fi

# Key listing via example env generation is stable and avoids printing values.
(
  cd "$INFISICAL_DIR"
  infisical secrets generate-example-env \
    --domain "$INFISICAL_DOMAIN" \
    --env "$INFISICAL_ENV" \
    --path "$INFISICAL_PATH" \
    --projectId "$INFISICAL_PROJECT_ID" \
    "${infisical_token_args[@]}" \
    > "$tmpfile"
)
actual_keys=$(cut -d= -f1 "$tmpfile" | sed '/^$/d' | sort -u)

missing=$(comm -23 <(printf "%s\n" "$expected_keys") <(printf "%s\n" "$actual_keys") || true)
extra=$(comm -13 <(printf "%s\n" "$expected_keys") <(printf "%s\n" "$actual_keys") || true)

if [[ -n "$missing" ]]; then
  echo "Missing Infisical secrets:" >&2
  echo "$missing" >&2
  exit 1
fi

log "All expected secrets exist in Infisical."
if [[ -n "$extra" ]]; then
  log "Additional secrets present in Infisical (review if needed):"
  echo "$extra"
fi

log "Checking for empty or placeholder values in Infisical..."
if [[ ! -f "$tmpvalues" || ! -s "$tmpvalues" ]]; then
  (
    cd "$INFISICAL_DIR"
    infisical secrets \
      --domain "$INFISICAL_DOMAIN" \
      --env "$INFISICAL_ENV" \
      --path "$INFISICAL_PATH" \
      --projectId "$INFISICAL_PROJECT_ID" \
      "${infisical_token_args[@]}" \
      --output json --silent > "$tmpvalues"
  )
fi

# Some keys are intentionally optional until a feature is fully enabled.
# Keep them present (so ExternalSecrets stays stable), but allow them to be empty
# or placeholders without failing validation.
OPTIONAL_KEYS_REGEX='^(MEREKA_LMS_STRIPE_WEBHOOK_SECRET|MEREKA_LMS_STRIPE_WEBHOOK_SECRET_DEV)$'

empty_values=$(
  jq -r --arg opt_re "$OPTIONAL_KEYS_REGEX" '
    .[]
    | select((.secretKey | test($opt_re)) | not)
    | select((.secretValue == null) or (.secretValue == "") or (.secretValue|tostring|test("\\*not found\\*"; "i")))
    | .secretKey
  ' "$tmpvalues"
)
if [[ -n "$empty_values" ]]; then
  echo "Infisical secrets with empty values:" >&2
  echo "$empty_values" >&2
  exit 1
fi

# Fail fast on placeholder values for non-optional keys.
placeholder_values=$(
  jq -r --arg opt_re "$OPTIONAL_KEYS_REGEX" '
    .[]
    | select((.secretKey | test($opt_re)) | not)
    | select((.secretValue|tostring|test("^(REPLACE_ME|REPLACE_.+|CHANGE_ME|TODO|TBD)$"; "i")))
    | .secretKey
  ' "$tmpvalues"
)
if [[ -n "$placeholder_values" ]]; then
  echo "Infisical secrets with placeholder values (fix at source):" >&2
  echo "$placeholder_values" >&2
  exit 1
fi

# Prevent the "MySQL 1045 due to trailing newline" failure mode at the source.
newline_values=$(
  jq -r '
    .[]
    | select((.secretKey | test("(_PASSWORD$|_OAUTH2_SECRET$|_CLIENT_SECRET$)")))
    | select((.secretValue|tostring|test("[\\r\\n]$")))
    | .secretKey
  ' "$tmpvalues"
)
if [[ -n "$newline_values" ]]; then
  if [[ "$STRICT" == "1" ]]; then
    echo "Infisical secrets with trailing CR/LF (will break auth/password parsing):" >&2
    echo "$newline_values" >&2
    exit 1
  fi
  log "WARN: Infisical secrets with trailing CR/LF detected (run with STRICT=1 to fail):"
  echo "$newline_values"
fi

optional_warnings=$(
  jq -r --arg opt_re "$OPTIONAL_KEYS_REGEX" '
    .[]
    | select(.secretKey | test($opt_re))
    | select((.secretValue == null) or (.secretValue == "") or (.secretValue|tostring|test("^(REPLACE_ME|REPLACE_.+|CHANGE_ME|TODO|TBD)$"; "i")))
    | .secretKey
  ' "$tmpvalues"
)
if [[ -n "$optional_warnings" ]]; then
  log "WARN: Optional secrets are unset/placeholders (ok until feature is enabled):"
  echo "$optional_warnings"
fi
