#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  resolve-build-scope.sh [--github-output <path>] [--summary-file <path>] [file ...]

Reads changed file paths from argv or stdin and emits a conservative build scope:
  - obvious Open edX-only paths => build_openedx=true, build_mfe=false
  - obvious MFE-only paths      => build_openedx=false, build_mfe=true
  - shared / ambiguous paths    => build_openedx=true, build_mfe=true

If no file paths are provided, paths are read one-per-line from stdin.
EOF
  exit 2
}

GITHUB_OUTPUT_PATH=""
SUMMARY_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --github-output)
      [[ $# -ge 2 ]] || usage
      GITHUB_OUTPUT_PATH="$2"
      shift 2
      ;;
    --summary-file)
      [[ $# -ge 2 ]] || usage
      SUMMARY_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

declare -a CHANGED_FILES=()
if [[ $# -gt 0 ]]; then
  CHANGED_FILES=("$@")
else
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    CHANGED_FILES+=("$line")
  done
fi

build_openedx=false
build_mfe=false
declare -a openedx_hits=()
declare -a mfe_hits=()
declare -a shared_hits=()

mark_openedx() {
  build_openedx=true
  openedx_hits+=("$1")
}

mark_mfe() {
  build_mfe=true
  mfe_hits+=("$1")
}

mark_shared() {
  build_openedx=true
  build_mfe=true
  shared_hits+=("$1")
}

classify_path() {
  local path="$1"
  case "$path" in
    deploy/k8s/base/apps/openedx/*|\
    infrastructure/tutor/custom-apps/*|\
    infrastructure/tutor/themes/mereka/lms/*|\
    infrastructure/tutor/themes/mereka/cms/*|\
    infrastructure/tutor/plugins/email-preferences/*|\
    infrastructure/tutor/plugins/email-suppression/*|\
    infrastructure/tutor/plugins/multi-tenancy/*|\
    infrastructure/tutor/plugins/mfe_oauth_fix.py|\
    infrastructure/tutor/plugins/_mereka_lms/openedx_dockerfile.py|\
    infrastructure/tutor/plugins/_mereka_lms/lms_settings.py|\
    infrastructure/tutor/plugins/_mereka_lms/cms_settings.py|\
    scripts/infra/build-openedx-image.sh|\
    scripts/qa/verify-openedx-image-branding.sh)
      mark_openedx "$path"
      ;;
    infrastructure/tutor/themes/mereka/mfe/*|\
    infrastructure/tutor/plugins/mereka_lms_mfe_slots.py|\
    infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py|\
    infrastructure/tutor/plugins/_mereka_lms/mfe_runtime.py|\
    infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js|\
    scripts/infra/build-mfe-image.sh|\
    scripts/qa/verify-mfe-image-branding.sh|\
    scripts/qa/verify-mfe-runtime-contract.sh)
      mark_mfe "$path"
      ;;
    *)
      mark_shared "$path"
      ;;
  esac
}

for changed_file in "${CHANGED_FILES[@]}"; do
  classify_path "$changed_file"
done

if [[ "$build_openedx" == false && "$build_mfe" == false ]]; then
  build_openedx=true
  build_mfe=true
  shared_hits+=("<no changed files supplied>")
fi

scope_label="both"
if [[ "$build_openedx" == true && "$build_mfe" == false ]]; then
  scope_label="openedx-only"
elif [[ "$build_openedx" == false && "$build_mfe" == true ]]; then
  scope_label="mfe-only"
fi

emit_list() {
  local label="$1"
  shift
  local -a values=("$@")
  printf '#### %s (%d)\n' "$label" "${#values[@]}"
  if [[ ${#values[@]} -eq 0 ]]; then
    printf -- '- none\n'
    return
  fi
  local value
  for value in "${values[@]}"; do
    printf -- '- `%s`\n' "$value"
  done
}

summary_md=$(
  {
    printf -- '- Scope label: `%s`\n' "$scope_label"
    printf -- '- Build OpenEdX: `%s`\n' "$build_openedx"
    printf -- '- Build MFE: `%s`\n\n' "$build_mfe"
    emit_list "Open edX-owned paths" "${openedx_hits[@]}"
    printf '\n'
    emit_list "MFE-owned paths" "${mfe_hits[@]}"
    printf '\n'
    emit_list "Shared or ambiguous paths" "${shared_hits[@]}"
    if [[ "$scope_label" != "both" ]]; then
      printf '\n- Release bundle remains dual-image only; partial push builds intentionally skip that lane.\n'
    fi
  }
)

printf '%s\n' "$summary_md"

if [[ -n "$SUMMARY_FILE" ]]; then
  printf '%s\n' "$summary_md" > "$SUMMARY_FILE"
fi

if [[ -n "$GITHUB_OUTPUT_PATH" ]]; then
  {
    printf 'build_openedx=%s\n' "$build_openedx"
    printf 'build_mfe=%s\n' "$build_mfe"
    printf 'scope_label=%s\n' "$scope_label"
  } >> "$GITHUB_OUTPUT_PATH"
fi
