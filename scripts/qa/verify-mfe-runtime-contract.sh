#!/usr/bin/env bash
# @covers AC-SLOT-007, AC-SLOT-011, AC-SLOT-015, AC-SLOT-022, AC-UI-006, AC-UI-008
# @spec: mfe-plugin-slots_spec.md, branding-system_spec.md
#
# verify-mfe-runtime-contract.sh — MFE runtime contract gate
#
# Catches the class of failure where MFE plugins exist in source but the built
# runtime contract drifts. Public env.config.jsx can be absent in the final MFE
# image because Tutor compiles the runtime definitions into the app bundles, so
# the authoritative post-build evidence is the shipped MFE bundle plus tenant
# theme assets.
#
# Two operating modes:
#
#   Post-build gate (requires locally-present Docker image):
#     ./scripts/qa/verify-mfe-runtime-contract.sh --image <image_ref>
#
#   Live deployment gate (requires network access to MFE):
#     ./scripts/qa/verify-mfe-runtime-contract.sh --url <mfe_base_url>
#
# Both modes can be combined:
#     ./scripts/qa/verify-mfe-runtime-contract.sh --image <ref> --url <url>
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

IMAGE_REF=""
MFE_BASE_URL=""
GENERATED_ENV_CONFIG=""

usage() {
  cat <<'EOF'
Usage:
  scripts/qa/verify-mfe-runtime-contract.sh --image <image_ref>
  scripts/qa/verify-mfe-runtime-contract.sh --url <mfe_base_url>
  scripts/qa/verify-mfe-runtime-contract.sh --generated-env-config <path>
  scripts/qa/verify-mfe-runtime-contract.sh --image <image_ref> --url <mfe_base_url>

Examples:
  scripts/qa/verify-mfe-runtime-contract.sh --image tutor_local/openedx-mfe:latest
  scripts/qa/verify-mfe-runtime-contract.sh --url https://apps.academyv2.mereka.io
  scripts/qa/verify-mfe-runtime-contract.sh \
    --generated-env-config tutor_env/env/plugins/mfe/build/mfe/env.config.jsx
  scripts/qa/verify-mfe-runtime-contract.sh \
    --image ghcr.io/biji-biji-initiative/mereka-lms/mfe:TAG \
    --url https://apps.academyv2.mereka.io
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      IMAGE_REF="${2:-}"
      if [[ -z "$IMAGE_REF" ]]; then
        echo "ERROR: --image requires a value" >&2
        usage
        exit 1
      fi
      shift 2
      ;;
    --url)
      MFE_BASE_URL="${2:-}"
      if [[ -z "$MFE_BASE_URL" ]]; then
        echo "ERROR: --url requires a value" >&2
        usage
        exit 1
      fi
      # Strip trailing slash for consistent path construction
      MFE_BASE_URL="${MFE_BASE_URL%/}"
      shift 2
      ;;
    --generated-env-config)
      GENERATED_ENV_CONFIG="${2:-}"
      if [[ -z "$GENERATED_ENV_CONFIG" ]]; then
        echo "ERROR: --generated-env-config requires a value" >&2
        usage
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$IMAGE_REF" && -z "$MFE_BASE_URL" && -z "$GENERATED_ENV_CONFIG" ]]; then
  echo "ERROR: At least one of --image, --url, or --generated-env-config is required" >&2
  usage
  exit 1
fi

# ---------------------------------------------------------------------------
# Counters and helpers
# ---------------------------------------------------------------------------

PASSED=0
FAILED=0
SKIPPED=0

pass() {
  echo "PASS: $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo "FAIL: $1"
  FAILED=$((FAILED + 1))
}

skip() {
  echo "SKIP: $1"
  SKIPPED=$((SKIPPED + 1))
}

generated_env_config_candidates=()

if [[ -n "$GENERATED_ENV_CONFIG" ]]; then
  generated_env_config_candidates+=("$GENERATED_ENV_CONFIG")
  generated_env_config_dir="$(dirname "$GENERATED_ENV_CONFIG")"
  sibling_indigo_env_config="${generated_env_config_dir}/indigo/env.config.jsx"
  if [[ -f "$sibling_indigo_env_config" ]]; then
    generated_env_config_candidates+=("$sibling_indigo_env_config")
  fi
elif [[ -n "$IMAGE_REF" ]]; then
  generated_env_config_candidates+=(
    "${TUTOR_ROOT:-$(pwd)/tutor_env}/env/plugins/mfe/build/mfe/env.config.jsx"
    "${TUTOR_ROOT:-$(pwd)/tutor_env}/env/plugins/mfe/build/mfe/indigo/env.config.jsx"
  )
fi

generated_env_configs=()
for candidate in "${generated_env_config_candidates[@]}"; do
  if [[ -n "$candidate" && -f "$candidate" ]]; then
    generated_env_configs+=("$candidate")
  fi
done

# ---------------------------------------------------------------------------
# Section 0: Generated env.config ownership checks
# ---------------------------------------------------------------------------

if [[ "${#generated_env_configs[@]}" -gt 0 ]]; then
  echo "=== Section 0: Generated env.config ownership checks ==="
  echo

  for env_config_path in "${generated_env_configs[@]}"; do
    env_size=$(wc -c < "$env_config_path")
    if [[ "$env_size" -gt 100 ]]; then
      pass "Generated env.config.jsx is non-trivial (${env_size} bytes > 100): ${env_config_path}"
    else
      fail "Generated env.config.jsx is too small (${env_size} bytes <= 100): ${env_config_path}"
    fi

    for marker in \
      "MerekaFooter" \
      "mereka_learner_sidebar_widget" \
      "mereka_dashboard_course_list_context"
    do
      if grep -qF "$marker" "$env_config_path"; then
        pass "Generated env.config.jsx contains Mereka ownership marker: ${marker}"
      else
        fail "Generated env.config.jsx missing Mereka ownership marker: ${marker}"
      fi
    done

    for forbidden in \
      "RenderWidget: IndigoFooter" \
      "RenderWidget: AddDarkTheme" \
      "id: 'custom_footer'"
    do
      if grep -qF "$forbidden" "$env_config_path"; then
        fail "Generated env.config.jsx still contains conflicting tutor-indigo ownership marker: ${forbidden}"
      else
        pass "Generated env.config.jsx is free of conflicting tutor-indigo ownership marker: ${forbidden}"
      fi
    done
  done

  echo
else
  skip "No generated env.config.jsx artifacts selected; build-time ownership checks require --image or --generated-env-config"
fi

# ---------------------------------------------------------------------------
# Section 1: Post-build Docker image checks
# ---------------------------------------------------------------------------

if [[ -n "$IMAGE_REF" ]]; then
  echo "=== Section 1: Post-build image checks (${IMAGE_REF}) ==="
  echo

  if ! docker image inspect "$IMAGE_REF" >/dev/null 2>&1; then
    echo "Pulling image for runtime verification: $IMAGE_REF"
    docker pull "$IMAGE_REF" >/dev/null
  fi

# Run all image checks in a single container invocation to avoid repeated
# docker run overhead. Each check emits PASS/FAIL/SKIP lines that are captured
# and replayed in the outer shell so the counters stay accurate.
  image_output=$(docker run --rm --entrypoint sh "$IMAGE_REF" -lc '
set -euo pipefail

result() {
  local status="$1"
  local msg="$2"
  echo "${status}: ${msg}"
}

# ----- Optional env.config.jsx diagnostic -----
ENV_CONFIG="/openedx/dist/env.config.jsx"

if [ -f "$ENV_CONFIG" ]; then
  result PASS "env.config.jsx exists at $ENV_CONFIG (diagnostic artifact)"
else
  result SKIP "env.config.jsx not shipped as a standalone artifact in the final image"
fi

if [ -f "$ENV_CONFIG" ]; then
  size=$(wc -c < "$ENV_CONFIG")
  if [ "$size" -gt 100 ]; then
    result PASS "env.config.jsx is non-trivial (${size} bytes > 100)"
  else
    result SKIP "env.config.jsx is present but small (${size} bytes <= 100); compiled bundle markers remain authoritative"
  fi
fi

# ----- Compiled learner-dashboard bundle -----
LEARNER_DASH_BUNDLE=$(ls /openedx/dist/learner-dashboard/app.*.js 2>/dev/null | head -n 1 || true)
if [ -n "$LEARNER_DASH_BUNDLE" ]; then
  result PASS "Learner dashboard app bundle exists at $LEARNER_DASH_BUNDLE"
else
  result FAIL "Learner dashboard app bundle missing under /openedx/dist/learner-dashboard/"
fi

if [ -n "$LEARNER_DASH_BUNDLE" ]; then
  bundle_size=$(wc -c < "$LEARNER_DASH_BUNDLE")
  if [ "$bundle_size" -gt 100000 ]; then
    result PASS "Learner dashboard bundle is non-trivial (${bundle_size} bytes > 100000)"
  else
    result FAIL "Learner dashboard bundle is too small (${bundle_size} bytes <= 100000)"
  fi

  for marker in \
    "mereka_footer" \
    "org.openedx.frontend.layout.footer.v1" \
    "mereka-dashboard-header-slot"
  do
    if grep -qF "$marker" "$LEARNER_DASH_BUNDLE"; then
      result PASS "Learner dashboard bundle contains runtime marker: $marker"
    else
      result FAIL "Learner dashboard bundle missing runtime marker: $marker"
    fi
  done
fi

# ----- Compiled authn bundle -----
AUTHN_BUNDLE=$(ls /openedx/dist/authn/app.*.js 2>/dev/null | head -n 1 || true)
if [ -n "$AUTHN_BUNDLE" ]; then
  result PASS "Authn app bundle exists at $AUTHN_BUNDLE"
  if grep -qF "mereka_authn_login_component" "$AUTHN_BUNDLE"; then
    result PASS "Authn bundle contains runtime marker: mereka_authn_login_component"
  else
    result FAIL "Authn bundle missing runtime marker: mereka_authn_login_component"
  fi
else
  result FAIL "Authn app bundle missing under /openedx/dist/authn/"
fi

# ----- Theme logos -----
for logo_path in \
  "/openedx/dist/theme/logo-horizontal.svg" \
  "/openedx/dist/theme/biji-biji/logo-horizontal.svg" \
  "/openedx/dist/theme/skillourfuture/logo-horizontal.svg"
do
  if [ -f "$logo_path" ]; then
    result PASS "Logo exists: $logo_path"
  else
    result FAIL "Logo MISSING: $logo_path"
  fi
done

# ----- Theme CSS bundles -----
CORE_CSS="/openedx/dist/theme/core.min.css"
if [ -f "$CORE_CSS" ]; then
  css_size=$(wc -c < "$CORE_CSS")
  if [ "$css_size" -gt 1000 ]; then
    result PASS "core.min.css exists and is non-trivial (${css_size} bytes > 1000)"
  else
    result FAIL "core.min.css is too small (${css_size} bytes <= 1000) — likely placeholder"
  fi
else
  result FAIL "core.min.css MISSING at $CORE_CSS"
fi

for css_path in \
  "/openedx/dist/theme/mereka-brand.min.css" \
  "/openedx/dist/theme/biji-biji-brand.min.css" \
  "/openedx/dist/theme/sof-brand.min.css"
do
  if [ -f "$css_path" ]; then
    css_size=$(wc -c < "$css_path")
    if [ "$css_size" -gt 100 ]; then
      result PASS "Brand CSS exists and is non-trivial (${css_size} bytes > 100): $css_path"
    else
      result FAIL "Brand CSS is too small (${css_size} bytes <= 100) — likely placeholder: $css_path"
    fi
  else
    result FAIL "Brand CSS MISSING: $css_path"
  fi
done
' 2>&1)

  # Replay the container output and tally results
  while IFS= read -r line; do
    echo "$line"
    if [[ "$line" == PASS:* ]]; then
      PASSED=$((PASSED + 1))
    elif [[ "$line" == FAIL:* ]]; then
      FAILED=$((FAILED + 1))
    elif [[ "$line" == SKIP:* ]]; then
      SKIPPED=$((SKIPPED + 1))
    fi
  done <<< "$image_output"

  echo
fi

# ---------------------------------------------------------------------------
# Section 2: Live deployment checks
# ---------------------------------------------------------------------------

if [[ -n "$MFE_BASE_URL" ]]; then
  echo "=== Section 2: Live deployment checks (${MFE_BASE_URL}) ==="
  echo

  # Helper: perform a HEAD/GET curl and return the HTTP status code
  http_status() {
    local url="$1"
    curl -sS -o /dev/null -w "%{http_code}" --max-time 15 "$url" 2>/dev/null || echo "000"
  }

  # Helper: fetch response body
  http_body() {
    local url="$1"
    curl -sSL --max-time 15 "$url" 2>/dev/null || true
  }

  # Helper: get Content-Type header
  content_type() {
    local url="$1"
    curl -sSI --max-time 15 "$url" 2>/dev/null | grep -i "^content-type:" | head -1 | tr -d '\r' || true
  }

  # 2.1 Public env.config.jsx is diagnostic only
  env_config_url="${MFE_BASE_URL}/env.config.jsx"
  env_status=$(http_status "$env_config_url")
  if [[ "$env_status" == "200" ]]; then
    pass "env.config.jsx returns HTTP 200 at ${env_config_url} (diagnostic artifact)"
  else
    skip "env.config.jsx returns HTTP ${env_status} at ${env_config_url}; bundle marker checks are authoritative"
  fi

  if [[ "$env_status" == "200" ]]; then
    env_body=$(http_body "$env_config_url")
    env_size=${#env_body}
    if [[ "$env_size" -gt 100 ]]; then
      pass "env.config.jsx body is non-trivial (${env_size} bytes > 100)"
    else
      skip "env.config.jsx body is small (${env_size} bytes <= 100); compiled bundle markers remain authoritative"
    fi
  fi

  # 2.2 Mereka logo (default tenant)
  logo_url="${MFE_BASE_URL}/theme/logo-horizontal.svg"
  logo_status=$(http_status "$logo_url")
  logo_ct=$(content_type "$logo_url")
  if [[ "$logo_status" == "200" ]]; then
    pass "Default logo returns HTTP 200: ${logo_url}"
  else
    fail "Default logo returns HTTP ${logo_status}: ${logo_url}"
  fi
  if echo "$logo_ct" | grep -qi "image/svg"; then
    pass "Default logo Content-Type is image/svg+xml"
  else
    fail "Default logo Content-Type is not image/svg+xml (got: ${logo_ct:-<none>})"
  fi

  # 2.3 core.min.css
  core_css_url="${MFE_BASE_URL}/theme/core.min.css"
  core_status=$(http_status "$core_css_url")
  core_ct=$(content_type "$core_css_url")
  if [[ "$core_status" == "200" ]]; then
    pass "core.min.css returns HTTP 200: ${core_css_url}"
  else
    fail "core.min.css returns HTTP ${core_status}: ${core_css_url}"
  fi
  if echo "$core_ct" | grep -qi "text/css"; then
    pass "core.min.css Content-Type is text/css"
  else
    fail "core.min.css Content-Type is not text/css (got: ${core_ct:-<none>})"
  fi

  # 2.4 Tenant brand CSS bundles
  for brand_css in \
    "biji-biji-brand.min.css" \
    "sof-brand.min.css"
  do
    brand_url="${MFE_BASE_URL}/theme/${brand_css}"
    brand_status=$(http_status "$brand_url")
    if [[ "$brand_status" == "200" ]]; then
      pass "Brand CSS returns HTTP 200: ${brand_url}"
    else
      fail "Brand CSS returns HTTP ${brand_status}: ${brand_url}"
    fi
  done

  # 2.5 Tenant logos
  for tenant_logo in \
    "biji-biji/logo-horizontal.svg" \
    "skillourfuture/logo-horizontal.svg"
  do
    tenant_url="${MFE_BASE_URL}/theme/${tenant_logo}"
    tenant_status=$(http_status "$tenant_url")
    if [[ "$tenant_status" == "200" ]]; then
      pass "Tenant logo returns HTTP 200: ${tenant_url}"
    else
      fail "Tenant logo returns HTTP ${tenant_status}: ${tenant_url}"
    fi
  done

  # 2.6 Learner dashboard MFE serves
  dashboard_url="${MFE_BASE_URL}/learner-dashboard/"
  dashboard_status=$(http_status "$dashboard_url")
  if [[ "$dashboard_status" == "200" ]]; then
    pass "learner-dashboard returns HTTP 200: ${dashboard_url}"
  else
    fail "learner-dashboard returns HTTP ${dashboard_status}: ${dashboard_url} (MFE may not be running)"
  fi

  # 2.7 PARAGON_THEME present in learner-dashboard HTML (theme switching wired)
  if [[ "$dashboard_status" == "200" ]]; then
    dashboard_body=$(http_body "$dashboard_url")
    if grep -q "PARAGON_THEME" <<< "$dashboard_body"; then
      pass "learner-dashboard HTML contains PARAGON_THEME (theme switching wired)"
    else
      fail "learner-dashboard HTML missing PARAGON_THEME — theme switching not configured"
    fi

    dashboard_bundle_path="$(printf '%s' "$dashboard_body" | grep -oE '/learner-dashboard/app\.[^"]+\.js' | head -n 1 || true)"
    if [[ -n "$dashboard_bundle_path" ]]; then
      pass "learner-dashboard HTML references compiled app bundle: ${dashboard_bundle_path}"
      dashboard_bundle_body="$(http_body "${MFE_BASE_URL}${dashboard_bundle_path}")"
      dashboard_bundle_size=${#dashboard_bundle_body}
      if [[ "$dashboard_bundle_size" -gt 100000 ]]; then
        pass "learner-dashboard bundle body is non-trivial (${dashboard_bundle_size} bytes > 100000)"
      else
        fail "learner-dashboard bundle body is too small (${dashboard_bundle_size} bytes <= 100000)"
      fi

      for marker in \
        "mereka_footer" \
        "org.openedx.frontend.layout.footer.v1" \
        "mereka-dashboard-header-slot"
      do
        if grep -qF "$marker" <<< "$dashboard_bundle_body"; then
          pass "learner-dashboard bundle contains runtime marker: ${marker}"
        else
          fail "learner-dashboard bundle missing runtime marker: ${marker}"
        fi
      done
    else
      fail "learner-dashboard HTML missing compiled app bundle reference"
    fi
  else
    skip "learner-dashboard HTML check skipped (page did not return 200)"
  fi

  echo
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo "=== Summary ==="
echo "PASS: ${PASSED} | FAIL: ${FAILED} | SKIP: ${SKIPPED}"
echo

if [[ "$FAILED" -gt 0 ]]; then
  echo "One or more MFE runtime contract checks failed." >&2
  echo "  - If compiled bundle markers are missing: the mereka_lms runtime definitions did not reach the built MFE bundle." >&2
  echo "    Ensure the plugin is enabled before running: tutor images build mfe" >&2
  echo "  - If theme assets are missing: re-run: make branding-sync && tutor images build mfe" >&2
  echo "  - If live checks fail: the deployed image may pre-date this contract." >&2
  echo "    Rebuild and redeploy: tutor images build mfe && tutor k8s restart mfe" >&2
  exit 1
fi

echo "All MFE runtime contract checks passed."
exit 0
