#!/usr/bin/env bash
# Seeded-defect self-test for verify-benchmark-artifact-contract.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-benchmark-artifact-contract.sh"

tmpdir="$(mktemp -d -t verify-benchmark-artifact-contract.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/scripts/bench" "$tmpdir/docs/status/active"

cat >"$tmpdir/scripts/bench/measure-bake-target.sh" <<'EOF'
#!/usr/bin/env bash
# benchmark_class=$BENCHMARK_CLASS
# build_profile=$BUILD_PROFILE
# measurement_mode=$MEASUREMENT_MODE
# custom_app_install_mode=$CUSTOM_APP_INSTALL_MODE
# Unsupported build_profile '$BUILD_PROFILE' for bake target '$TARGET'.
# Unsupported measurement_mode '$MEASUREMENT_MODE' for bake target '$TARGET'.
# Supported modes: warm-builder, warm-builder-noload
# MEASUREMENT_OVERRIDE_ARGS=(--set "$TARGET.output=type=cacheonly")
# Unsupported custom_app_install_mode '$CUSTOM_APP_INSTALL_MODE' for bake target '$TARGET'.
# Bake target '$TARGET' requires custom_app_install_mode=editable.
# Bake target '$TARGET' requires custom_app_install_mode=noneditable.
# build_surface=bake
# tutor_root=$TUTOR_ROOT_PATH
# bake_file=$BAKE_FILE
# bake_file_sha256=$(bake_file_sha256)
# output_mode=$OUTPUT_MODE
# rendered_dockerfile_sha256=$(dockerfile_sha256)
# plugin_mirror_sha256=$(plugin_mirror_sha256)
# webpack_seconds
# collectstatic_seconds
# docker_export_seconds
# docker_import_seconds
# cache_export_seconds
# rdfind_skip_observed=
# ) 2>&1 | tee "$LOG"
echo "target=$TARGET"
EOF

cat >"$tmpdir/scripts/bench/measure-openedx-build.sh" <<'EOF'
#!/usr/bin/env bash
echo "target=openedx-proof"
# benchmark_class=$BENCHMARK_CLASS
# build_profile=$BUILD_PROFILE
# measurement_mode=$MEASUREMENT_MODE
# custom_app_install_mode=$CUSTOM_APP_INSTALL_MODE
# Unsupported measurement_mode '$MEASUREMENT_MODE' for benchmark_class '$BENCHMARK_CLASS'.
# Unsupported build_profile '$BUILD_PROFILE' for measure-openedx-build.sh.
# Unsupported custom_app_install_mode '$CUSTOM_APP_INSTALL_MODE' for measure-openedx-build.sh.
# build_surface=tutor-images-build
# tutor_root=$TUTOR_ROOT_PATH
# output_mode=runtime-image
# rendered_dockerfile_sha256=$(dockerfile_sha256)
# plugin_mirror_sha256=$(plugin_mirror_sha256)
# MEREKA_BUILD_PROFILE=$BUILD_PROFILE
# MEREKA_CUSTOM_APP_INSTALL_MODE=$CUSTOM_APP_INSTALL_MODE
EOF

cat >"$tmpdir/docs/status/active/UV_EXPERIMENT_CONTROL_BOARD_2026-04-10.md" <<'EOF'
## Artifact verdict registry

Every named benchmark artifact in this lane must be explicitly classified as
`accepted`, `rejected`, or `invalid artifact`. There is no fourth state.

Registry rule:
1. do not compare cache-hot validation artifacts against proof-class throughput headlines
2. newly recorded benchmark artifacts missing the governed metadata contract are invalid evidence for new governed comparisons
3. legacy accepted or rejected artifacts recorded before the 2026-04-11 metadata contract remain historical board records until they are remeasured or superseded
EOF

chmod +x "$tmpdir/scripts/bench/measure-bake-target.sh" "$tmpdir/scripts/bench/measure-openedx-build.sh"

run_expect_pass() {
  local label="$1"
  MEASURE_BAKE_OVERRIDE="$tmpdir/scripts/bench/measure-bake-target.sh" \
  MEASURE_OPENEDX_OVERRIDE="$tmpdir/scripts/bench/measure-openedx-build.sh" \
  CONTROL_BOARD_OVERRIDE="$tmpdir/docs/status/active/UV_EXPERIMENT_CONTROL_BOARD_2026-04-10.md" \
    bash "$VERIFY" >/tmp/verify-benchmark-artifact-contract.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  MEASURE_BAKE_OVERRIDE="$tmpdir/scripts/bench/measure-bake-target.sh" \
  MEASURE_OPENEDX_OVERRIDE="$tmpdir/scripts/bench/measure-openedx-build.sh" \
  CONTROL_BOARD_OVERRIDE="$tmpdir/docs/status/active/UV_EXPERIMENT_CONTROL_BOARD_2026-04-10.md" \
    bash "$VERIFY" >/tmp/verify-benchmark-artifact-contract.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-benchmark-artifact-contract.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass "benchmark artifact contract passes"

rm -f "$tmpdir/docs/status/active/UV_EXPERIMENT_CONTROL_BOARD_2026-04-10.md"
run_expect_pass "missing lane-local control board is tolerated"

cat >"$tmpdir/docs/status/active/UV_EXPERIMENT_CONTROL_BOARD_2026-04-10.md" <<'EOF'
## Artifact verdict registry

Every named benchmark artifact in this lane must be explicitly classified as
`accepted`, `rejected`, or `invalid artifact`. There is no fourth state.

Registry rule:
1. do not compare cache-hot validation artifacts against proof-class throughput headlines
2. newly recorded benchmark artifacts missing the governed metadata contract are invalid evidence for new governed comparisons
3. legacy accepted or rejected artifacts recorded before the 2026-04-11 metadata contract remain historical board records until they are remeasured or superseded
EOF

python3 - <<PY
from pathlib import Path
fixture = Path("$tmpdir/scripts/bench/measure-openedx-build.sh")
text = fixture.read_text(encoding="utf-8")
text = text.replace('# output_mode=runtime-image\n', '', 1)
fixture.write_text(text, encoding="utf-8")
PY
run_expect_fail "missing output-mode metadata is rejected"

echo "OK"
