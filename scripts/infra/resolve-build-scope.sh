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

# Paths that DO NOT affect image content (docs, verifier scripts, governance
# catalogs, manifest-only kustomize files, bead tracker, etc.). If ALL changed
# paths match skip patterns, neither image needs a rebuild. Added in PR for
# bead mereka-lms-2xwo follow-up + evidence doc
# docs/ops/evidence/build-tutor-images-over-triggering-regression-2026-04-20.md
# The previous `* -> mark_shared` fallback triggered MFE+OpenEdX rebuilds on
# pure-config PRs (e.g. #1901 pin-required restore). Real example: #1901
# caused run 24639215635 to spend 1h 20min on MFE webpack for zero MFE source
# change. Cancelled manually.
declare -a skip_hits=()
mark_skip() {
  skip_hits+=("$1")
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
    infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/*|\
    scripts/infra/build-mfe-image.sh|\
    scripts/qa/verify-mfe-image-branding.sh|\
    scripts/qa/verify-mfe-runtime-contract.sh|\
    scripts/qa/verify-mfe-runtime-helper-contract.sh|\
    scripts/qa/verify-mfe-footer-plugin-slot.sh|\
    scripts/qa/verify-mfe-footer-slot.sh)
      mark_mfe "$path"
      ;;
    # Skip paths: documentation, verifier scripts that don't feed images,
    # governance catalogs, manifest-only kustomize, bead tracker, release
    # tooling, CI workflow/actions config. These do not affect image content.
    docs/**|docs/*|\
    '*.md'|\
    '*/README.md'|\
    README.md|\
    AGENTS.md|\
    CLAUDE.md|\
    reports/**|reports/*|\
    .beads/**|.beads/*|\
    .github/**|.github/*|\
    .githooks/**|.githooks/*|\
    .gitignore|\
    .editorconfig|\
    scripts/qa/fixtures/*|\
    scripts/qa/deprecated/*|\
    scripts/qa/verify-*.sh|\
    scripts/qa/audit-*.sh|\
    scripts/qa/test-*.sh|\
    scripts/qa/generate-*.sh|\
    scripts/qa/generate-*.py|\
    scripts/qa/run-*.sh|\
    scripts/qa/diagnose-*.sh|\
    scripts/governance/**|scripts/governance/*|\
    scripts/infra/verify-*.sh|\
    scripts/infra/release-*.sh|\
    scripts/infra/canonical-release.sh|\
    scripts/infra/assemble-release-evidence.sh|\
    scripts/infra/sync-gitops-prod-image-tags.sh|\
    scripts/infra/bump-image-tags.sh|\
    scripts/infra/tutor-config-save.sh|\
    scripts/infra/fix-service-selectors.sh|\
    deploy/k8s/base/kustomization.yaml|\
    deploy/k8s/base/VERSION|\
    deploy/k8s/base/contract.json|\
    deploy/k8s/base/RUNTIME_AUTHORITY_MAP.md|\
    deploy/k8s/VERSION|\
    deploy/k8s/contract.json|\
    deploy/k8s/overlays/local/**|deploy/k8s/overlays/local/*|\
    generated/**|generated/*|\
    verification/**|verification/*|\
    tests/**|tests/*|\
    evals/**|evals/*|\
    specs/**|specs/*|\
    specdocs/**|specdocs/*|\
    tutor_env/**|tutor_env/*|\
    var/**|var/*)
      mark_skip "$path"
      ;;
    *)
      mark_shared "$path"
      ;;
  esac
}

for changed_file in "${CHANGED_FILES[@]}"; do
  classify_path "$changed_file"
done

# Decision logic:
# - NO files at all (empty input) → build both (safety fallback; we don't know)
# - Some files ALL classified as skip → build neither (real skip case — saves
#   build-hours on docs/verifier/config-only PRs)
# - Any openedx-triggering or mfe-triggering path → build the matching image(s)
if [[ "$build_openedx" == false && "$build_mfe" == false ]]; then
  if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
    # No changed files supplied at all (e.g. manual dispatch with no payload)
    # — safety fallback to build both.
    build_openedx=true
    build_mfe=true
    shared_hits+=("<no changed files supplied>")
  elif [[ ${#skip_hits[@]} -gt 0 ]]; then
    # All changed files matched skip patterns. Leave both=false so the
    # workflow's `if: build_openedx==true || build_mfe==true` gate skips the
    # build jobs entirely. This is the real fix: docs/config/verifier PRs
    # should not rebuild images.
    :
  else
    # Shouldn't reach here if classify_path covers all inputs, but safety net.
    build_openedx=true
    build_mfe=true
    shared_hits+=("<unclassified fallback>")
  fi
fi

scope_label="both"
if [[ "$build_openedx" == false && "$build_mfe" == false ]]; then
  scope_label="skip"
elif [[ "$build_openedx" == true && "$build_mfe" == false ]]; then
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
    printf '\n'
    emit_list "Skip paths (non-image, does not trigger build)" "${skip_hits[@]}"
    if [[ "$scope_label" == "skip" ]]; then
      printf '\n- All changed paths classified as skip. Neither image needs a rebuild.\n'
    elif [[ "$scope_label" != "both" ]]; then
      printf '\n- Release bundle supports partial builds by inheriting the unchanged component digest.\n'
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
