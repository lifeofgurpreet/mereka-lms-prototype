#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "${REPO_ROOT}/.." && pwd)}"

INFRA_REPO="${INFRA_REPO:-}"
STRICT=0

usage() {
  cat <<'EOF'
Usage:
  scripts/qa/audit-infra-mereka-lms-staging-references.sh [--infra-repo PATH] [--strict]

Purpose:
  Read-only audit for issue mereka-lms-7fyu:
  detect staging overlay references for mereka-lms in the external GitOps repo.

Options:
  --infra-repo PATH  Path to bbi-infrastructure checkout.
  --strict           Exit non-zero when staging references are found.
  -h, --help         Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --infra-repo)
      INFRA_REPO="${2:-}"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$INFRA_REPO" ]]; then
  for candidate in \
    "${WORKSPACE_ROOT}/infrastructure" \
    "${WORKSPACE_ROOT}/bbi-infrastructure" \
    "${HOME}/projects/k8s/infrastructure" \
    "${HOME}/projects/k8s/bbi-infrastructure"; do
    if [[ -d "$candidate/.git" ]]; then
      INFRA_REPO="$candidate"
      break
    fi
  done
fi

if [[ -z "$INFRA_REPO" ]]; then
  echo "Unable to detect infra repo. Pass --infra-repo PATH." >&2
  exit 1
fi

if [[ ! -d "$INFRA_REPO/.git" ]]; then
  echo "Not a git repo: $INFRA_REPO" >&2
  exit 1
fi

echo "Auditing staging references in: $INFRA_REPO"

overlay_file="$INFRA_REPO/apps/mereka-lms/overlays/staging/kustomization.yaml"
overlay_exists=0
if [[ -f "$overlay_file" ]]; then
  overlay_exists=1
fi

tmp_hits="$(mktemp)"
cleanup() {
  rm -f "$tmp_hits"
}
trap cleanup EXIT

# Find staging refs that are specifically tied to mereka-lms.
rg -n --no-heading \
  -e 'apps/mereka-lms/overlays/staging' \
  -e 'mereka-lms.*staging' \
  -e 'staging.*mereka-lms' \
  "$INFRA_REPO/apps" "$INFRA_REPO/applicationsets" "$INFRA_REPO/argocd" 2>/dev/null >"$tmp_hits" || true

echo "- staging overlay file present: $([[ "$overlay_exists" -eq 1 ]] && echo yes || echo no)"
hit_count="$(wc -l <"$tmp_hits" | tr -d '[:space:]')"
echo "- staging reference hits: $hit_count"

if [[ "$hit_count" -gt 0 ]]; then
  echo "Staging reference details:"
  sed 's/^/  /' "$tmp_hits"
fi

if [[ "$STRICT" -eq 1 && ( "$overlay_exists" -eq 1 || "$hit_count" -gt 0 ) ]]; then
  echo "❌ Strict mode failed: staging references still exist for mereka-lms."
  exit 1
fi

echo "✅ Audit complete."
