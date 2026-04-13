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

default_build_profile() {
  case "$TARGET" in
    *-proof) printf '%s\n' "proof" ;;
    *-fast) printf '%s\n' "fast" ;;
    *-producer) printf '%s\n' "producer" ;;
    *-compat) printf '%s\n' "compat" ;;
    *) printf '%s\n' "unknown" ;;
  esac
}

default_custom_app_install_mode() {
  case "$TARGET" in
    openedx-fast) printf '%s\n' "editable" ;;
    openedx-proof|openedx-producer|openedx-compat) printf '%s\n' "noneditable" ;;
    *) printf '\n' ;;
  esac
}

BENCHMARK_CLASS="${BENCHMARK_CLASS:-$(default_benchmark_class)}"
BUILD_PROFILE="${BUILD_PROFILE:-$(default_build_profile)}"
MEASUREMENT_MODE="${MEASUREMENT_MODE:-warm-builder}"
CUSTOM_APP_INSTALL_MODE="${CUSTOM_APP_INSTALL_MODE:-$(default_custom_app_install_mode)}"
MEASUREMENT_OVERRIDE_ARGS=()

validate_build_profile() {
  case "$BUILD_PROFILE" in
    proof|fast|producer|compat) ;;
    *)
      echo "Unsupported build_profile '$BUILD_PROFILE' for bake target '$TARGET'." >&2
      echo "Supported profiles: proof, fast, producer, compat" >&2
      exit 2
      ;;
  esac
}

validate_measurement_mode() {
  case "$MEASUREMENT_MODE" in
    warm-builder) ;;
    warm-builder-noload) ;;
    *)
      echo "Unsupported measurement_mode '$MEASUREMENT_MODE' for bake target '$TARGET'." >&2
      echo "Supported modes: warm-builder, warm-builder-noload" >&2
      echo "Use warm-builder-noload to measure build compute without docker image materialization." >&2
      exit 2
      ;;
  esac
}

validate_custom_app_install_mode() {
  if [[ "$TARGET" != openedx-* ]]; then
    return 0
  fi

  case "$CUSTOM_APP_INSTALL_MODE" in
    editable|noneditable) ;;
    *)
      echo "Unsupported custom_app_install_mode '$CUSTOM_APP_INSTALL_MODE' for bake target '$TARGET'." >&2
      echo "Supported custom app install modes for openedx bake targets: editable, noneditable" >&2
      exit 2
      ;;
  esac

  case "$TARGET" in
    openedx-fast)
      if [[ "$CUSTOM_APP_INSTALL_MODE" != "editable" ]]; then
        echo "Bake target '$TARGET' requires custom_app_install_mode=editable." >&2
        exit 2
      fi
      ;;
    openedx-proof|openedx-producer|openedx-compat)
      if [[ "$CUSTOM_APP_INSTALL_MODE" != "noneditable" ]]; then
        echo "Bake target '$TARGET' requires custom_app_install_mode=noneditable." >&2
        exit 2
      fi
      ;;
  esac
}

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

bake_file_sha256() {
  sha256sum "$BAKE_FILE" | awk '{print $1}'
}

target_output_mode() {
  docker buildx bake -f "$BAKE_FILE" --print "${MEASUREMENT_OVERRIDE_ARGS[@]}" "$TARGET" 2>/dev/null | python3 -c '
import json
import sys

payload = sys.stdin.read()
start = payload.find("{")
if start == -1:
    raise SystemExit("unable to locate bake --print JSON payload")
document = json.loads(payload[start:])
outputs = document["target"][sys.argv[1]].get("output", [])
print(",".join(entry["type"] for entry in outputs))
' "$TARGET"
}

extract_step_metrics() {
  python3 - "$LOG" <<'PY'
import pathlib
import re
import sys

log_path = pathlib.Path(sys.argv[1])
lines = log_path.read_text(encoding="utf-8", errors="ignore").splitlines()

markers = {
    "webpack_seconds": "RUN npm run webpack",
    "collectstatic_seconds": "RUN ./manage.py lms collectstatic",
    "docker_export_seconds": "exporting to docker image format",
    "docker_import_seconds": "importing to docker",
    "cache_export_seconds": "exporting cache to client directory",
}

step_ids = {}
step_durations = {}

for line in lines:
    start_match = re.match(r"#(\d+)\s+(.*)$", line)
    if start_match:
        step_id, payload = start_match.groups()
        for key, marker in markers.items():
            if key not in step_ids and marker in payload:
                step_ids[key] = step_id

    done_match = re.match(r"#(\d+)\s+DONE\s+([0-9.]+)s$", line)
    if done_match:
        step_durations[done_match.group(1)] = done_match.group(2)

for key, step_id in step_ids.items():
    duration = step_durations.get(step_id)
    if duration is not None:
        print(f"{key}={duration}")

print(
    "rdfind_skip_observed="
    + ("1" if any("Skipping rdfind static dedupe (fast build profile)" in line for line in lines) else "0")
)
PY
}

START_EPOCH="$(date +%s)"
START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
GIT_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
GIT_STATUS="$(git -C "$ROOT" status --short | wc -l | tr -d ' ')"
validate_build_profile
validate_measurement_mode
validate_custom_app_install_mode
if [[ "$MEASUREMENT_MODE" == "warm-builder-noload" ]]; then
  MEASUREMENT_OVERRIDE_ARGS=(--set "$TARGET.output=type=cacheonly")
fi
OUTPUT_MODE="$(target_output_mode)"

if [[ -z "$OUTPUT_MODE" ]]; then
  echo "Failed to resolve output mode for bake target: $TARGET" >&2
  exit 1
fi

cat >"$META" <<EOF
label=$LABEL
target=$TARGET
benchmark_class=$BENCHMARK_CLASS
build_profile=$BUILD_PROFILE
measurement_mode=$MEASUREMENT_MODE
custom_app_install_mode=$CUSTOM_APP_INSTALL_MODE
build_surface=bake
root=$ROOT
tutor_root=$TUTOR_ROOT_PATH
bake_file=$BAKE_FILE
bake_file_sha256=$(bake_file_sha256)
output_mode=$OUTPUT_MODE
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
  printf 'docker buildx bake -f %q --progress=plain' "$BAKE_FILE"
  if [[ ${#MEASUREMENT_OVERRIDE_ARGS[@]} -gt 0 ]]; then
    printf ' %q' "${MEASUREMENT_OVERRIDE_ARGS[@]}"
  fi
  printf ' %q\n' "$TARGET"
  docker buildx bake -f "$BAKE_FILE" --progress=plain "${MEASUREMENT_OVERRIDE_ARGS[@]}" "$TARGET"
) 2>&1 | tee "$LOG"
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

STEP_METRICS="$(extract_step_metrics)"
if [[ -n "$STEP_METRICS" ]]; then
  printf '%s\n' "$STEP_METRICS" >>"$META"
fi

echo "result=$RESULT duration=${DURATION}s log=$LOG"
exit "$RESULT"
