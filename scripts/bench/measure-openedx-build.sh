#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
LABEL="${2:-baseline}"
OUTDIR="${3:-$ROOT/.benchmarks/openedx}"
BENCHMARK_CLASS="${BENCHMARK_CLASS:-proof-class}"
default_build_profile() {
  case "${BENCHMARK_CLASS:-proof-class}" in
    "proof-class"|"cache-hot validation") printf '%s\n' "proof" ;;
    *)
      echo "Unsupported benchmark_class '$BENCHMARK_CLASS' for measure-openedx-build.sh." >&2
      exit 2
      ;;
  esac
}
default_measurement_mode() {
  case "${BENCHMARK_CLASS:-proof-class}" in
    "cache-hot validation") printf '%s\n' "cache-hot-replay" ;;
    *) printf '%s\n' "warm-replay" ;;
  esac
}
BUILD_PROFILE="${BUILD_PROFILE:-$(default_build_profile)}"
MEASUREMENT_MODE="${MEASUREMENT_MODE:-$(default_measurement_mode)}"
CUSTOM_APP_INSTALL_MODE="${CUSTOM_APP_INSTALL_MODE:-noneditable}"
validate_measurement_mode() {
  case "${BENCHMARK_CLASS:-proof-class}" in
    "cache-hot validation")
      if [[ "$MEASUREMENT_MODE" != "cache-hot-replay" ]]; then
        echo "Unsupported measurement_mode '$MEASUREMENT_MODE' for benchmark_class '$BENCHMARK_CLASS'." >&2
        echo "Supported mode: cache-hot-replay" >&2
        exit 2
      fi
      ;;
    "proof-class")
      if [[ "$MEASUREMENT_MODE" != "warm-replay" ]]; then
        echo "Unsupported measurement_mode '$MEASUREMENT_MODE' for benchmark_class '$BENCHMARK_CLASS'." >&2
        echo "Supported mode: warm-replay" >&2
        echo "The legacy openedx harness does not establish coldish-registry-import semantics." >&2
        exit 2
      fi
      ;;
    *)
      echo "Unsupported benchmark_class '$BENCHMARK_CLASS' for measure-openedx-build.sh." >&2
      exit 2
      ;;
  esac
}
validate_build_contract() {
  if [[ "$BUILD_PROFILE" != "proof" ]]; then
    echo "Unsupported build_profile '$BUILD_PROFILE' for measure-openedx-build.sh." >&2
    echo "Supported build profile: proof" >&2
    exit 2
  fi
  if [[ "$CUSTOM_APP_INSTALL_MODE" != "noneditable" ]]; then
    echo "Unsupported custom_app_install_mode '$CUSTOM_APP_INSTALL_MODE' for measure-openedx-build.sh." >&2
    echo "Supported custom app install mode: noneditable" >&2
    exit 2
  fi
}
TUTOR_ROOT_PATH="${TUTOR_ROOT:-$ROOT/tutor_env}"
OPENEDX_DOCKERFILE="$TUTOR_ROOT_PATH/env/build/openedx/Dockerfile"
PLUGIN_DIR="${TUTOR_PLUGINS_ROOT:-${TUTOR_PLUGINS_DIR:-$TUTOR_ROOT_PATH/plugins}}"
export TUTOR_ROOT="$TUTOR_ROOT_PATH"
export TUTOR_PLUGINS_ROOT="$PLUGIN_DIR"
export TUTOR_PLUGINS_DIR="$PLUGIN_DIR"
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
validate_measurement_mode
validate_build_contract
START_EPOCH="$(date -u +%s)"
START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "label=$LABEL"
  echo "target=openedx-proof"
  echo "benchmark_class=$BENCHMARK_CLASS"
  echo "build_profile=$BUILD_PROFILE"
  echo "measurement_mode=$MEASUREMENT_MODE"
  echo "custom_app_install_mode=$CUSTOM_APP_INSTALL_MODE"
  echo "build_surface=tutor-images-build"
  echo "root=$ROOT"
  echo "tutor_root=$TUTOR_ROOT_PATH"
  echo "output_mode=runtime-image"
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
TUTOR_ROOT="$TUTOR_ROOT_PATH" .venv/bin/tutor images build openedx \
  -a "MEREKA_BUILD_PROFILE=$BUILD_PROFILE" \
  -a "MEREKA_CUSTOM_APP_INSTALL_MODE=$CUSTOM_APP_INSTALL_MODE" 2>&1 | tee "$LOG"
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
