#!/usr/bin/env bash
# @covers AC-BENCH-001
#
# Verify benchmark artifact governance contract:
#   - benchmark harnesses emit the minimum metadata required for class-safe comparison
#   - if a lane-local experiment control board is present, it keeps an explicit accepted/rejected/invalid verdict registry
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
MEASURE_BAKE="${MEASURE_BAKE_OVERRIDE:-$REPO_ROOT/scripts/bench/measure-bake-target.sh}"
MEASURE_OPENEDX="${MEASURE_OPENEDX_OVERRIDE:-$REPO_ROOT/scripts/bench/measure-openedx-build.sh}"
CONTROL_BOARD="${CONTROL_BOARD_OVERRIDE:-$REPO_ROOT/docs/status/active/UV_EXPERIMENT_CONTROL_BOARD_2026-04-10.md}"

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

check_file() {
  local path="$1"
  local label="$2"
  if [[ -f "$path" ]]; then
    pass "$label exists"
  else
    fail "$label missing: $path"
  fi
}

check_contains() {
  local path="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq "$needle" "$path"; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo "=== Benchmark Artifact Contract ==="

check_file "$MEASURE_BAKE" "measure-bake-target harness"
check_file "$MEASURE_OPENEDX" "measure-openedx-build harness"
if [[ -f "$CONTROL_BOARD" ]]; then
  pass "UV experiment control board exists"
else
  pass "UV experiment control board is optional outside lane-local docs"
fi

if [[ -f "$MEASURE_BAKE" ]]; then
  check_contains "$MEASURE_BAKE" 'target=$TARGET' "bake harness stamps target"
  check_contains "$MEASURE_BAKE" 'benchmark_class=$BENCHMARK_CLASS' "bake harness stamps benchmark class"
  check_contains "$MEASURE_BAKE" 'build_profile=$BUILD_PROFILE' "bake harness stamps build profile"
  check_contains "$MEASURE_BAKE" 'measurement_mode=$MEASUREMENT_MODE' "bake harness stamps measurement mode"
  check_contains "$MEASURE_BAKE" 'custom_app_install_mode=$CUSTOM_APP_INSTALL_MODE' "bake harness stamps custom app install mode"
  check_contains "$MEASURE_BAKE" "Unsupported build_profile '\$BUILD_PROFILE' for bake target '\$TARGET'." "bake harness rejects unsupported build profiles"
  check_contains "$MEASURE_BAKE" "Unsupported measurement_mode '\$MEASUREMENT_MODE' for bake target '\$TARGET'." "bake harness rejects unsupported measurement modes"
  check_contains "$MEASURE_BAKE" "Supported modes: warm-builder, warm-builder-noload" "bake harness documents supported measurement modes"
  check_contains "$MEASURE_BAKE" 'MEASUREMENT_OVERRIDE_ARGS=(--set "$TARGET.output=type=cacheonly")' "bake harness overrides target output for no-load measurement"
  check_contains "$MEASURE_BAKE" "Unsupported custom_app_install_mode '\$CUSTOM_APP_INSTALL_MODE' for bake target '\$TARGET'." "bake harness rejects unsupported custom app install modes"
  check_contains "$MEASURE_BAKE" "Bake target '\$TARGET' requires custom_app_install_mode=editable." "bake harness enforces editable mode for openedx-fast"
  check_contains "$MEASURE_BAKE" "Bake target '\$TARGET' requires custom_app_install_mode=noneditable." "bake harness enforces noneditable mode for strict openedx bake targets"
  check_contains "$MEASURE_BAKE" 'build_surface=bake' "bake harness stamps build surface"
  check_contains "$MEASURE_BAKE" 'tutor_root=$TUTOR_ROOT_PATH' "bake harness stamps repo-scoped tutor root"
  check_contains "$MEASURE_BAKE" 'bake_file=$BAKE_FILE' "bake harness stamps bake file path"
  check_contains "$MEASURE_BAKE" 'bake_file_sha256=$(bake_file_sha256)' "bake harness stamps bake file hash"
  check_contains "$MEASURE_BAKE" 'output_mode=$OUTPUT_MODE' "bake harness stamps output mode"
  check_contains "$MEASURE_BAKE" 'rendered_dockerfile_sha256=$(dockerfile_sha256)' "bake harness stamps rendered Dockerfile hash"
  check_contains "$MEASURE_BAKE" 'plugin_mirror_sha256=$(plugin_mirror_sha256)' "bake harness stamps plugin mirror hash"
  check_contains "$MEASURE_BAKE" 'webpack_seconds' "bake harness records webpack timing"
  check_contains "$MEASURE_BAKE" 'collectstatic_seconds' "bake harness records collectstatic timing"
  check_contains "$MEASURE_BAKE" 'docker_export_seconds' "bake harness records docker export timing"
  check_contains "$MEASURE_BAKE" 'docker_import_seconds' "bake harness records docker import timing"
  check_contains "$MEASURE_BAKE" 'cache_export_seconds' "bake harness records cache export timing"
  check_contains "$MEASURE_BAKE" 'rdfind_skip_observed=' "bake harness records rdfind skip observation"
  check_contains "$MEASURE_BAKE" ') 2>&1 | tee "$LOG"' "bake harness captures build stderr in the artifact log"
fi

if [[ -f "$MEASURE_OPENEDX" ]]; then
  check_contains "$MEASURE_OPENEDX" 'target=openedx-proof' "legacy proof harness stamps explicit proof target"
  check_contains "$MEASURE_OPENEDX" 'benchmark_class=$BENCHMARK_CLASS' "legacy proof harness stamps benchmark class"
  check_contains "$MEASURE_OPENEDX" 'build_profile=$BUILD_PROFILE' "legacy proof harness stamps build profile"
  check_contains "$MEASURE_OPENEDX" 'measurement_mode=$MEASUREMENT_MODE' "legacy proof harness stamps measurement mode"
  check_contains "$MEASURE_OPENEDX" 'custom_app_install_mode=$CUSTOM_APP_INSTALL_MODE' "legacy proof harness stamps custom app install mode"
  check_contains "$MEASURE_OPENEDX" "Unsupported measurement_mode '\$MEASUREMENT_MODE' for benchmark_class '\$BENCHMARK_CLASS'." "legacy proof harness rejects unsupported measurement modes"
  check_contains "$MEASURE_OPENEDX" "Unsupported build_profile '\$BUILD_PROFILE' for measure-openedx-build.sh." "legacy proof harness rejects unsupported build profiles"
  check_contains "$MEASURE_OPENEDX" "Unsupported custom_app_install_mode '\$CUSTOM_APP_INSTALL_MODE' for measure-openedx-build.sh." "legacy proof harness rejects unsupported custom app install modes"
  check_contains "$MEASURE_OPENEDX" 'build_surface=tutor-images-build' "legacy proof harness stamps build surface"
  check_contains "$MEASURE_OPENEDX" 'tutor_root=$TUTOR_ROOT_PATH' "legacy proof harness stamps repo-scoped tutor root"
  check_contains "$MEASURE_OPENEDX" 'output_mode=runtime-image' "legacy proof harness stamps output mode"
  check_contains "$MEASURE_OPENEDX" 'rendered_dockerfile_sha256=$(dockerfile_sha256)' "legacy proof harness stamps rendered Dockerfile hash"
  check_contains "$MEASURE_OPENEDX" 'plugin_mirror_sha256=$(plugin_mirror_sha256)' "legacy proof harness stamps plugin mirror hash"
  check_contains "$MEASURE_OPENEDX" 'MEREKA_BUILD_PROFILE=$BUILD_PROFILE' "legacy proof harness passes the proof build profile through Tutor"
  check_contains "$MEASURE_OPENEDX" 'MEREKA_CUSTOM_APP_INSTALL_MODE=$CUSTOM_APP_INSTALL_MODE' "legacy proof harness passes the proof custom app install mode through Tutor"
fi

if [[ -f "$CONTROL_BOARD" ]]; then
  check_contains "$CONTROL_BOARD" '## Artifact verdict registry' "control board declares an artifact verdict registry"
  check_contains "$CONTROL_BOARD" '`accepted`, `rejected`, or `invalid artifact`' "control board constrains verdicts to the governed set"
  check_contains "$CONTROL_BOARD" 'There is no fourth state.' "control board rejects an implicit fourth verdict state"
  check_contains "$CONTROL_BOARD" 'do not compare cache-hot validation artifacts against proof-class throughput headlines' "control board separates cache-hot validation from proof-class throughput"
  check_contains "$CONTROL_BOARD" 'newly recorded benchmark artifacts missing the governed metadata contract are invalid evidence for new governed comparisons' "control board rejects new metadata-incomplete evidence"
  check_contains "$CONTROL_BOARD" 'legacy accepted or rejected artifacts recorded before the 2026-04-11 metadata contract remain historical board records until they are remeasured or superseded' "control board explicitly grandfathers pre-contract historical artifacts"
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL ==="
[[ $FAIL -gt 0 ]] && exit 1
exit 0
