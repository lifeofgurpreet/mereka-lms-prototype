#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <repo-root> <bake-target> [label]" >&2
  exit 1
fi

ROOT="$(cd "$1" && pwd)"
TARGET="$2"
LABEL="${3:-$TARGET}"
BENCHMARK_CLASS="${BENCHMARK_CLASS:-producer-class}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BENCH_DIR="$ROOT/.benchmarks/bake"
LOG="$BENCH_DIR/${TIMESTAMP}-${LABEL}.log"
META="$BENCH_DIR/${TIMESTAMP}-${LABEL}.meta"
BAKE_FILE="$ROOT/docker-bake.hcl"
TUTOR_ROOT_PATH="$ROOT/tutor_env"
PLUGIN_DIR="${TUTOR_PLUGINS_DIR:-$HOME/.local/share/tutor-plugins}"

mkdir -p "$BENCH_DIR"

if [[ ! -f "$BAKE_FILE" ]]; then
  echo "Missing bake file: $BAKE_FILE" >&2
  exit 1
fi

default_benchmark_class() {
  case "$TARGET" in
    *-proof|*-compat) printf '%s\n' "proof-class" ;;
    *-fast) printf '%s\n' "fast-class" ;;
    *-producer) printf '%s\n' "producer-class" ;;
    *) printf '%s\n' "producer-class" ;;
  esac
}

BENCHMARK_CLASS="${BENCHMARK_CLASS:-$(default_benchmark_class)}"
target_dockerfile() {
  case "$TARGET" in
    openedx-*) printf '%s\n' "$ROOT/tutor_env/env/build/openedx/Dockerfile" ;;
    mfe-*) printf '%s\n' "$ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile" ;;
    *) printf '\n' ;;
  esac
}

dockerfile_sha256() {
  local dockerfile
  dockerfile="$(target_dockerfile)"
  if [[ -n "$dockerfile" && -f "$dockerfile" ]]; then
    sha256sum "$dockerfile" | awk '{print $1}'
  fi
}

plugin_mirror_sha256() {
  if [[ -d "$PLUGIN_DIR" ]]; then
    tar -C "$PLUGIN_DIR" -cf - \
      mereka_lms.py \
      mereka_lms_mfe_slots.py \
      mfe_oauth_fix.py \
      _mereka_lms 2>/dev/null | sha256sum | awk '{print $1}'
  fi
}

START_EPOCH="$(date +%s)"
START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
GIT_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
GIT_STATUS="$(git -C "$ROOT" status --short | wc -l | tr -d ' ')"

cat >"$META" <<EOF
label=$LABEL
target=$TARGET
benchmark_class=$BENCHMARK_CLASS
root=$ROOT
tutor_root=$TUTOR_ROOT_PATH
start_iso=$START_ISO
start_epoch=$START_EPOCH
git_head=$GIT_HEAD
git_status=$GIT_STATUS
rendered_dockerfile=$(target_dockerfile)
rendered_dockerfile_sha256=$(dockerfile_sha256)
plugin_mirror_dir=$PLUGIN_DIR
plugin_mirror_sha256=$(plugin_mirror_sha256)
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
