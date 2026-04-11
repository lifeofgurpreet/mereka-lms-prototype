#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <repo-root> <bake-target> [label]" >&2
  exit 1
fi

ROOT="$(cd "$1" && pwd)"
TARGET="$2"
LABEL="${3:-$TARGET}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BENCH_DIR="$ROOT/.benchmarks/bake"
LOG="$BENCH_DIR/${TIMESTAMP}-${LABEL}.log"
META="$BENCH_DIR/${TIMESTAMP}-${LABEL}.meta"
BAKE_FILE="$ROOT/docker-bake.hcl"

mkdir -p "$BENCH_DIR"

if [[ ! -f "$BAKE_FILE" ]]; then
  echo "Missing bake file: $BAKE_FILE" >&2
  exit 1
fi

START_EPOCH="$(date +%s)"
START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
GIT_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
GIT_STATUS="$(git -C "$ROOT" status --short | wc -l | tr -d ' ')"

cat >"$META" <<EOF
label=$LABEL
target=$TARGET
root=$ROOT
start_iso=$START_ISO
start_epoch=$START_EPOCH
git_head=$GIT_HEAD
git_status=$GIT_STATUS
log=$LOG
EOF

set +e
(
  cd "$ROOT"
  echo "Building bake target $TARGET"
  echo "docker buildx bake -f $BAKE_FILE --progress=plain $TARGET"
  docker buildx bake -f "$BAKE_FILE" --progress=plain "$TARGET"
) | tee "$LOG"
RESULT=${PIPESTATUS[0]}
set -e

END_EPOCH="$(date +%s)"
END_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DURATION="$((END_EPOCH - START_EPOCH))"

cat >>"$META" <<EOF
end_iso=$END_ISO
end_epoch=$END_EPOCH
duration_seconds=$DURATION
exit_code=$RESULT
EOF

echo "result=$RESULT duration=${DURATION}s log=$LOG"
exit "$RESULT"
