#!/usr/bin/env bash
# build-runtime-blocker-handoff-bundle.sh — Package canonical runtime blocker artifacts into one tarball.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_OUTPUT="$REPO_ROOT/var/qa/frontend-runtime-blocker-handoff-bundle.tar.gz"
OUTPUT_FILE="$DEFAULT_OUTPUT"

usage() {
  cat <<'USAGE'
Usage: build-runtime-blocker-handoff-bundle.sh [--output <path>]

Options:
  --output <path>  Output tar.gz path (default: var/qa/frontend-runtime-blocker-handoff-bundle.tar.gz)
  -h, --help       Show help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -lt 2 ]] && { echo "ERROR: --output requires a value" >&2; exit 2; }
      OUTPUT_FILE="$2"
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

mkdir -p "$(dirname "$OUTPUT_FILE")"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
STAGE_DIR="$TMP_DIR/runtime-blocker-handoff"
mkdir -p "$STAGE_DIR"

copy_if_exists() {
  local rel="$1"
  local src="$REPO_ROOT/$rel"
  if [[ -f "$src" ]]; then
    cp "$src" "$STAGE_DIR/"
    return 0
  fi
  return 1
}

copied=0
missing=0

for rel in \
  "var/qa/frontend-runtime-blocker-handoff.md" \
  "var/qa/frontend-runtime-blocker-infra-prompt.txt" \
  "var/qa/frontend-runtime-blocker-infra-prompt.md" \
  "var/qa/frontend-runtime-blocker-status.txt" \
  "var/qa/frontend-runtime-blocker-status.md" \
  "var/qa/frontend-runtime-blocker-sweep-latest-both.summary.log" \
  "var/qa/frontend-runtime-blocker-sweep-latest-both.summary.json" \
  "var/qa/frontend-runtime-blocker-sweep-latest-both.records.tsv" \
  "var/qa/frontend-runtime-blocker-sweep-latest-both.diagnostics.tsv" \
  "var/qa/frontend-runtime-blocker-auth-surfaces-prod-latest.log" \
  "var/qa/frontend-runtime-blocker-auth-surfaces-dev-latest.log" \
  "var/qa/frontend-runtime-blocker-credentials-dev-latest.log"; do
  if copy_if_exists "$rel"; then
    copied=$((copied + 1))
  else
    missing=$((missing + 1))
  fi
done

{
  echo "generated_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "repo_root=$REPO_ROOT"
  echo "copied_files=$copied"
  echo "missing_files=$missing"
} > "$STAGE_DIR/manifest.txt"

tar -czf "$OUTPUT_FILE" -C "$TMP_DIR" runtime-blocker-handoff
echo "wrote $OUTPUT_FILE (copied=$copied missing=$missing)"
