#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

usage() {
  cat <<'EOF'
Usage: scripts/branding/run-branding-gates.sh [prod|dev|all]

Environment flags:
  BRANDING_LEVEL=core|deep            Default: deep
  RUN_SOURCE_GATE=1|0                 Default: 1
  RUN_LIVE_GATE=1|0                   Default: 1
  RUN_AUDIT=1|0                       Default: 1
  AUDIT_STRICT=1|0                    Default: 0 (pass --strict to audit-branding-surfaces)
  RUN_STUDIO_AUTHORING_CHECK=1|0      Default: 1
  RUN_MFE_PREREQ_CHECK=1|0            Default: 1
  STRICT_NO_GOOGLE_FONTS=1|0          Default: 0 (passed to studio authoring check)
  STRICT_PROXY_AUTHN_BRANDING=1|0     Default: 0 (enforce branded /authn assets on service domains)
  RUN_SCREENSHOTS=1|0                 Default: 0
  RUN_VISUAL_REGRESSION=1|0           Default: 0
  VISUAL_THRESHOLD=<float>            Default: 0.06
  VISUAL_EXCLUDE_REGEX=<expr>         Optional regex for skipped screenshot labels
  VISUAL_STRICT=1|0                   Default: 0 (strict file-set match)
  VISUAL_ALLOW_BOOTSTRAP=1|0          Default: 1 (first screenshot run won't fail)
  VISUAL_JSON=1|0                     Default: 0
  VISUAL_BASELINE_DIR=<path>          Optional explicit baseline run directory
  VISUAL_CANDIDATE_DIR=<path>         Optional explicit candidate run directory
  STRICT_MFE_BRANDING_REV=1|0         Default: 0 (passed through)
  CHECK_CERTS=1|0                     Default: auto (1 for prod, 0 for dev)

Examples:
  scripts/branding/run-branding-gates.sh prod
  RUN_SCREENSHOTS=1 scripts/branding/run-branding-gates.sh prod
  RUN_AUDIT=0 RUN_SCREENSHOTS=0 scripts/branding/run-branding-gates.sh all
EOF
}

TARGET_ENV="${1:-prod}"
if [[ "$TARGET_ENV" != "prod" && "$TARGET_ENV" != "dev" && "$TARGET_ENV" != "all" ]]; then
  usage
  exit 1
fi

BRANDING_LEVEL="${BRANDING_LEVEL:-deep}"
RUN_SOURCE_GATE="${RUN_SOURCE_GATE:-1}"
RUN_LIVE_GATE="${RUN_LIVE_GATE:-1}"
RUN_AUDIT="${RUN_AUDIT:-1}"
AUDIT_STRICT="${AUDIT_STRICT:-0}"
RUN_STUDIO_AUTHORING_CHECK="${RUN_STUDIO_AUTHORING_CHECK:-1}"
RUN_MFE_PREREQ_CHECK="${RUN_MFE_PREREQ_CHECK:-1}"
RUN_SCREENSHOTS="${RUN_SCREENSHOTS:-0}"
RUN_VISUAL_REGRESSION="${RUN_VISUAL_REGRESSION:-0}"
VISUAL_THRESHOLD="${VISUAL_THRESHOLD:-0.06}"
VISUAL_EXCLUDE_REGEX="${VISUAL_EXCLUDE_REGEX:-}"
VISUAL_STRICT="${VISUAL_STRICT:-0}"
VISUAL_ALLOW_BOOTSTRAP="${VISUAL_ALLOW_BOOTSTRAP:-1}"
VISUAL_JSON="${VISUAL_JSON:-0}"
VISUAL_BASELINE_DIR="${VISUAL_BASELINE_DIR:-}"
VISUAL_CANDIDATE_DIR="${VISUAL_CANDIDATE_DIR:-}"

if [[ "$BRANDING_LEVEL" != "core" && "$BRANDING_LEVEL" != "deep" ]]; then
  echo "Invalid BRANDING_LEVEL=${BRANDING_LEVEL} (expected core|deep)" >&2
  exit 1
fi

run_source_gate() {
  echo "==> Source gate: verify-branding-health (${BRANDING_LEVEL})"
  BRANDING_LEVEL="$BRANDING_LEVEL" "$REPO_ROOT/scripts/branding/verify-branding-health.sh"
  if [[ "$RUN_MFE_PREREQ_CHECK" == "1" ]]; then
    echo "==> Source gate: verify-mfe-build-prereqs"
    "$REPO_ROOT/scripts/qa/verify-mfe-build-prereqs.sh"
  fi
  if [[ "$RUN_STUDIO_AUTHORING_CHECK" == "1" ]]; then
    echo "==> Source gate: verify-studio-authoring-branding (source-only)"
    "$REPO_ROOT/scripts/qa/verify-studio-authoring-branding.sh" prod --source-only
  fi
}

run_live_gate() {
  local env=$1
  local certs_flag="${CHECK_CERTS:-}"
  local visual_args=()

  echo "==> Live gate: public-health-check (${env})"
  if [[ -z "$certs_flag" ]]; then
    if [[ "$env" == "prod" ]]; then
      CHECK_CERTS=1 CHECK_BRANDING=1 "$REPO_ROOT/scripts/qa/public-health-check.sh" "$env"
    else
      CHECK_BRANDING=1 "$REPO_ROOT/scripts/qa/public-health-check.sh" "$env"
    fi
  else
    CHECK_CERTS="$certs_flag" CHECK_BRANDING=1 "$REPO_ROOT/scripts/qa/public-health-check.sh" "$env"
  fi

  echo "==> Live gate: verify-public-branding (${env}, ${BRANDING_LEVEL})"
  BRANDING_LEVEL="$BRANDING_LEVEL" \
    STRICT_MFE_BRANDING_REV="${STRICT_MFE_BRANDING_REV:-0}" \
    "$REPO_ROOT/scripts/qa/verify-public-branding.sh" "$env"

  if [[ "$RUN_STUDIO_AUTHORING_CHECK" == "1" ]]; then
    echo "==> Live gate: verify-studio-authoring-branding (${env})"
    STRICT_NO_GOOGLE_FONTS="${STRICT_NO_GOOGLE_FONTS:-0}" \
      "$REPO_ROOT/scripts/qa/verify-studio-authoring-branding.sh" "$env"
  fi

  if [[ "$RUN_AUDIT" == "1" ]]; then
    echo "==> Live gate: audit-branding-surfaces (${env})"
    if [[ "$AUDIT_STRICT" == "1" ]]; then
      "$REPO_ROOT/scripts/qa/audit-branding-surfaces.sh" "$env" --strict
    else
      "$REPO_ROOT/scripts/qa/audit-branding-surfaces.sh" "$env"
    fi
  fi

  if [[ "$RUN_SCREENSHOTS" == "1" ]]; then
    echo "==> Live gate: capture-branding-screenshots (${env})"
    "$REPO_ROOT/scripts/qa/capture-branding-screenshots.sh" "$env"
  fi

  if [[ "$RUN_VISUAL_REGRESSION" == "1" ]]; then
    echo "==> Live gate: visual-regression-branding (${env})"
    visual_args+=(--threshold "$VISUAL_THRESHOLD")
    if [[ -n "$VISUAL_EXCLUDE_REGEX" ]]; then
      visual_args+=(--exclude-regex "$VISUAL_EXCLUDE_REGEX")
    fi
    if [[ "$VISUAL_STRICT" == "1" ]]; then
      visual_args+=(--strict)
    fi
    if [[ "$VISUAL_ALLOW_BOOTSTRAP" == "1" ]]; then
      visual_args+=(--allow-bootstrap)
    fi
    if [[ "$VISUAL_JSON" == "1" ]]; then
      visual_args+=(--json)
    fi
    if [[ -n "$VISUAL_BASELINE_DIR" ]]; then
      visual_args+=(--baseline "$VISUAL_BASELINE_DIR")
    fi
    if [[ -n "$VISUAL_CANDIDATE_DIR" ]]; then
      visual_args+=(--candidate "$VISUAL_CANDIDATE_DIR")
    fi
    "$REPO_ROOT/scripts/qa/visual-regression-branding.sh" "$env" "${visual_args[@]}"
  fi
}

if [[ "$RUN_SOURCE_GATE" == "1" ]]; then
  run_source_gate
else
  echo "==> Skipping source gate (RUN_SOURCE_GATE=${RUN_SOURCE_GATE})"
fi

if [[ "$RUN_LIVE_GATE" != "1" ]]; then
  echo "==> Skipping live gates (RUN_LIVE_GATE=${RUN_LIVE_GATE})"
  exit 0
fi

if [[ "$TARGET_ENV" == "all" ]]; then
  run_live_gate "prod"
  run_live_gate "dev"
else
  run_live_gate "$TARGET_ENV"
fi

echo "==> Branding gates completed."
