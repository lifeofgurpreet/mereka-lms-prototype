#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
LABEL="${2:-baseline}"
OUTDIR="${3:-$ROOT/.benchmarks/openedx}"
BENCHMARK_CLASS="${BENCHMARK_CLASS:-proof-class}"
TUTOR_ROOT_PATH="$ROOT/tutor_env"
OPENEDX_DOCKERFILE="$TUTOR_ROOT_PATH/env/build/openedx/Dockerfile"
PLUGIN_DIR="${TUTOR_PLUGINS_DIR:-$HOME/.local/share/tutor-plugins}"
mkdir -p "$OUTDIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$OUTDIR/${STAMP}-${LABEL}.log"
META="$OUTDIR/${STAMP}-${LABEL}.meta"

dockerfile_sha256() {
  if [[ -f "$OPENEDX_DOCKERFILE" ]]; then
    sha256sum "$OPENEDX_DOCKERFILE" | awk '{print $1}'
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

cd "$ROOT"
START_EPOCH="$(date -u +%s)"
START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "label=$LABEL"
  echo "benchmark_class=$BENCHMARK_CLASS"
  echo "root=$ROOT"
  echo "tutor_root=$TUTOR_ROOT_PATH"
  echo "start_iso=$START_ISO"
  echo "start_epoch=$START_EPOCH"
  echo "git_head=$(git rev-parse HEAD 2>/dev/null || true)"
  echo "git_status=$(git status --short | wc -l | tr -d ' ')"
  echo "rendered_dockerfile=$OPENEDX_DOCKERFILE"
  echo "rendered_dockerfile_sha256=$(dockerfile_sha256)"
  echo "plugin_mirror_dir=$PLUGIN_DIR"
  echo "plugin_mirror_sha256=$(plugin_mirror_sha256)"
} > "$META"

set +e
TUTOR_ROOT="$TUTOR_ROOT_PATH" .venv/bin/tutor images build openedx 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}
set -e

END_EPOCH="$(date -u +%s)"
END_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DURATION="$((END_EPOCH - START_EPOCH))"
{
  echo "end_iso=$END_ISO"
  echo "end_epoch=$END_EPOCH"
  echo "duration_seconds=$DURATION"
  echo "exit_code=$RC"
  echo "log=$LOG"
} >> "$META"

printf 'result=%s duration=%ss log=%s\n' "$RC" "$DURATION" "$LOG"
exit "$RC"
