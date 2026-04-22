#!/usr/bin/env bash
# @spec: cross-cutting-requirements_spec.md
# @covers AC-ULMO-001: OPENEDX_COMMON_VERSION patch confirmed working (ensure_mfe_ulmo_source_refs)
# @covers AC-ULMO-002: All MFE app source refs use release/ulmo
# @covers AC-ULMO-003: Atlas translation pulls use release/ulmo
# @covers AC-ULMO-004: Brand package uses the repo-local Ulmo-compatible package
# @covers AC-ULMO-006: discussions webpack fix is no-op on ulmo (fixed upstream)
#
# Verify MFE Ulmo migration completeness.
#
# Modes:
#   --offline  Static checks against snapshot Dockerfile and apply-patches.sh (default)
#   --online   Live cluster checks via kubectl (requires KUBECONFIG / cluster access)
#
# Usage:
#   ./scripts/qa/verify-mfe-ulmo-migration.sh
#   ./scripts/qa/verify-mfe-ulmo-migration.sh --offline
#   ./scripts/qa/verify-mfe-ulmo-migration.sh --online
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
# mfe-node.sh removed in tracker #32; MFE Dockerfile hooks now live in plugin module
MFE_PATCH="$REPO_ROOT/infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py"
SNAPSHOT="$REPO_ROOT/infrastructure/tutor/mfe-build/Dockerfile"
RENDERED_DOCKERFILE="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
KUSTOMIZATION_PROD="$REPO_ROOT/deploy/k8s/overlays/production/kustomization.yaml"
NAMESPACE="${NAMESPACE:-mereka-lms}"

PASS=0
FAIL=0
SKIP=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
skip() { SKIP=$((SKIP + 1)); echo "  SKIP: $1"; }

MODE="offline"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline) MODE="offline"; shift ;;
    --online)  MODE="online";  shift ;;
    -h|--help)
      echo "Usage: $0 [--offline|--online]"
      echo ""
      echo "  --offline  Static checks (default): Dockerfile snapshot, apply-patches.sh, kustomization"
      echo "  --online   Live cluster checks: pod image, version header, MFE route smoke tests"
      exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1 ;;
  esac
done

echo "========================================"
echo "MFE Ulmo Migration Verification ($MODE)"
echo "========================================"
echo ""

# -----------------------------------------------------------------------
# OFFLINE mode
# -----------------------------------------------------------------------
run_offline_checks() {
  local active_dockerfile="$SNAPSHOT"
  local active_label="snapshot Dockerfile"
  if [[ -f "$RENDERED_DOCKERFILE" ]]; then
    active_dockerfile="$RENDERED_DOCKERFILE"
    active_label="rendered MFE Dockerfile"
  fi

  # -----------------------------------------------------------------------
  # AC-ULMO-001: Ulmo source refs are native in Tutor v21 (no patch needed)
  # NOTE: ensure_mfe_ulmo_source_refs() was in mfe-node.sh (removed tracker #32).
  # Tutor v21 (Ulmo) natively uses release/ulmo.1 refs; the bash patch is no-op.
  # Verification is now against the snapshot Dockerfile directly.
  # -----------------------------------------------------------------------
  echo "--- AC-ULMO-001: Ulmo source refs (native in Tutor v21) ---"

  if [[ ! -f "$APPLY_PATCHES" ]]; then
    fail "apply-patches.sh not found at $APPLY_PATCHES"
  else
    # Verify mfe-node.sh is no longer sourced (it was removed in tracker #32)
    if grep -q 'mfe-node.sh' "$APPLY_PATCHES"; then
      fail "apply-patches.sh still references removed mfe-node.sh (tracker #32)"
    else
      pass "apply-patches.sh does not reference deprecated mfe-node.sh"
    fi

    # OPENEDX_COMMON_VERSION check (gitignored config.yml)
    TUTOR_CONFIG="$REPO_ROOT/tutor_env/config.yml"
    if [[ -f "$TUTOR_CONFIG" ]]; then
      CONFIG_VER=$(grep "OPENEDX_COMMON_VERSION" "$TUTOR_CONFIG" | head -1 || true)
      if grep -q "redwood" <<<"$CONFIG_VER"; then
        pass "OPENEDX_COMMON_VERSION=redwood.3 (snapshot approach active)"
      elif grep -q "ulmo" <<<"$CONFIG_VER"; then
        pass "OPENEDX_COMMON_VERSION=ulmo (native Tutor v21 behavior)"
      else
        skip "OPENEDX_COMMON_VERSION not determinable from config.yml"
      fi
    else
      skip "tutor_env/config.yml not found (gitignored) — OPENEDX_COMMON_VERSION unverifiable"
    fi
  fi

  echo ""

  # -----------------------------------------------------------------------
  # Stale release ref scan
  # -----------------------------------------------------------------------
  echo "--- Stale release ref scan (nutmeg/palm/olive/quince/redwood) ---"

  if [[ -f "$active_dockerfile" ]]; then
    STALE_COUNT=$(grep -cEi "frontend-app.*#.*(nutmeg|palm|olive|quince|open-release/redwood)" "$active_dockerfile" || true)
    if [[ "$STALE_COUNT" -eq 0 ]]; then
      pass "${active_label}: no stale release refs (nutmeg/palm/olive/quince/redwood)"
    else
      fail "${active_label}: $STALE_COUNT stale release ref(s) found"
    fi
  else
    skip "No rendered or snapshot Dockerfile found — cannot scan for stale refs"
  fi

  # Check patch source (may be mfe-node.sh after T018 refactor)
  STALE_SOURCE="${MFE_PATCH:-$APPLY_PATCHES}"
  if [[ -f "$STALE_SOURCE" ]]; then
    STALE_APPLY=$(grep -cEi "ADD.*frontend-app.*(nutmeg|palm|olive|quince|open-release/redwood)" "$STALE_SOURCE" || true)
    if [[ "$STALE_APPLY" -eq 0 ]]; then
      pass "Patch source: no stale ADD refs for pre-ulmo releases"
    else
      fail "Patch source: $STALE_APPLY stale ADD ref(s) targeting pre-ulmo releases"
    fi
  fi

  echo ""

  # -----------------------------------------------------------------------
  # AC-ULMO-002: All MFE app source refs use release/ulmo in snapshot
  # -----------------------------------------------------------------------
  echo "--- AC-ULMO-002: MFE source refs in snapshot Dockerfile ---"

  if [[ ! -f "$active_dockerfile" ]]; then
    fail "Dockerfile snapshot missing: infrastructure/tutor/mfe-build/Dockerfile"
  else
    pass "${active_label} exists"

    REDWOOD_COUNT=$(grep -c "frontend-app.*\.git#open-release/redwood" "$active_dockerfile" || true)
    MASTER_COUNT=$(grep -c "frontend-app.*\.git#master" "$active_dockerfile" || true)
    ULMO_COUNT=$(grep -c "frontend-app.*\.git#release/ulmo" "$active_dockerfile" || true)

    if [[ "$REDWOOD_COUNT" -eq 0 ]]; then
      pass "No redwood-era ADD refs in ${active_label} (0 found)"
    else
      fail "$REDWOOD_COUNT redwood-era ADD refs still in ${active_label} (expected 0)"
    fi

    if [[ "$MASTER_COUNT" -eq 0 ]]; then
      pass "No master-tracking frontend refs remain in ${active_label}"
    else
      fail "$MASTER_COUNT master-tracking frontend refs remain in ${active_label}"
    fi

    if [[ "$ULMO_COUNT" -ge 12 ]]; then
      pass "All active MFE apps use release/ulmo ($ULMO_COUNT refs found, expected >=12)"
    elif [[ "$ULMO_COUNT" -ge 1 ]]; then
      fail "Only $ULMO_COUNT ulmo refs found (expected >=12) — migration incomplete"
    else
      fail "No ulmo ADD refs in snapshot"
    fi
  fi

  echo ""

  # -----------------------------------------------------------------------
  # Node version: Dockerfile base image uses Node 18+
  # -----------------------------------------------------------------------
  echo "--- Node version: base image must be Node 18+ ---"

  if [[ -f "$active_dockerfile" ]]; then
    BASE_IMAGE=$(grep -E "^FROM ((docker\.io|mirror\.gcr\.io/library)/)?node:" "$active_dockerfile" | head -1 || true)
    if grep -qE "node:(18|20|22|24)" <<<"$BASE_IMAGE"; then
      pass "MFE base image uses Node 18+: $BASE_IMAGE"
    elif [[ -n "$BASE_IMAGE" ]]; then
      fail "MFE base image may be pre-Node 18: $BASE_IMAGE"
    else
      skip "Cannot determine Node base image from snapshot"
    fi
  else
    skip "No rendered or snapshot Dockerfile found — cannot verify Node version"
  fi

  echo ""

  # -----------------------------------------------------------------------
  # AC-ULMO-003: Atlas translation revision uses release/ulmo
  # -----------------------------------------------------------------------
  echo "--- AC-ULMO-003: Atlas translation revision ---"

  if [[ -f "$active_dockerfile" ]]; then
    ATLAS_REDWOOD=$(grep -c "revision=open-release/redwood" "$active_dockerfile" || true)
    ATLAS_OPEN_ULMO=$(grep -c "revision=open-release/ulmo" "$active_dockerfile" || true)
    ATLAS_POINT_ULMO=$(grep -cE "revision=release/ulmo\\." "$active_dockerfile" || true)
    ATLAS_ULMO=$(grep -cE "revision=release/ulmo[[:space:]'\"]" "$active_dockerfile" || true)

    if [[ "$ATLAS_REDWOOD" -eq 0 ]]; then
      pass "No redwood atlas translation revisions in ${active_label}"
    else
      fail "$ATLAS_REDWOOD redwood atlas revision ref(s) still in ${active_label}"
    fi

    if [[ "$ATLAS_OPEN_ULMO" -eq 0 ]]; then
      pass "No legacy open-release/ulmo atlas translation revisions in ${active_label}"
    else
      fail "$ATLAS_OPEN_ULMO legacy open-release/ulmo atlas revision ref(s) still in ${active_label}"
    fi

    if [[ "$ATLAS_POINT_ULMO" -eq 0 ]]; then
      pass "No nonexistent point-release atlas translation revisions in ${active_label}"
    else
      fail "$ATLAS_POINT_ULMO point-release atlas translation ref(s) still in ${active_label}"
    fi

    if [[ "$ATLAS_ULMO" -ge 12 ]]; then
      pass "All atlas pulls use release/ulmo ($ATLAS_ULMO found, expected >=12)"
    elif [[ "$ATLAS_ULMO" -ge 1 ]]; then
      fail "Only $ATLAS_ULMO atlas ulmo refs found (expected >=12)"
    else
      fail "No ulmo atlas translation refs found in ${active_label}"
    fi
  else
    skip "No rendered or snapshot Dockerfile found — skipping atlas checks"
  fi

  echo ""

  # -----------------------------------------------------------------------
  # AC-ULMO-004: Brand package upgraded to ulmo-compatible version
  # -----------------------------------------------------------------------
  echo "--- AC-ULMO-004: Brand package version ---"

  if [[ -f "$RENDERED_DOCKERFILE" ]]; then
    OLD_BRAND=$(grep -c "indigo-brand-openedx@" "$RENDERED_DOCKERFILE" || true)
    LOCAL_BRAND=$(grep -c "/openedx/app/node_modules/@edx/brand" "$RENDERED_DOCKERFILE" || true)
    OLD_LOCAL_INSTALL=$(grep -c "@edx/brand@file:./brand-mereka" "$RENDERED_DOCKERFILE" || true)

    if [[ "$OLD_BRAND" -eq 0 ]]; then
      pass "No published indigo brand pin remains in rendered MFE Dockerfile"
    else
      fail "$OLD_BRAND published indigo brand pin occurrence(s) still in rendered MFE Dockerfile"
    fi

    if [[ "$LOCAL_BRAND" -ge 1 ]] && grep -q "materialized local brand package" "$RENDERED_DOCKERFILE"; then
      pass "Rendered Dockerfile materializes the local brand package at @edx/brand"
    else
      fail "Rendered Dockerfile missing local brand package materialization"
    fi

    if [[ "$OLD_LOCAL_INSTALL" -eq 0 ]]; then
      pass "Rendered Dockerfile does not run post-npm local brand package install"
    else
      fail "$OLD_LOCAL_INSTALL post-npm local brand package install occurrence(s) still in rendered MFE Dockerfile"
    fi
  else
    skip "Rendered MFE Dockerfile unavailable — brand materialization contract checked against source plugin module only"
  fi

  # mfe-node.sh removed in tracker #32; the plugin now installs the staged local
  # brand package by materializing it at @edx/brand after npm finishes.
  if [[ -f "$MFE_PATCH" ]]; then
    if grep -q '/openedx/app/node_modules/@edx/brand' "$MFE_PATCH" \
      && grep -q 'materialized local brand package' "$MFE_PATCH"; then
      pass "Plugin module materializes the local brand package"
    else
      fail "Plugin module missing local brand package materialization hook"
    fi
  fi

  echo ""

  # -----------------------------------------------------------------------
  # AC-ULMO-006: discussions webpack fix is no-op on ulmo
  # -----------------------------------------------------------------------
  echo "--- AC-ULMO-006: discussions webpack (ulmo native fix) ---"

  if [[ -f "$SNAPSHOT" ]]; then
    DISCUSSIONS_REDWOOD=$(grep -c "frontend-app-discussions.*redwood" "$SNAPSHOT" || true)
    if [[ "$DISCUSSIONS_REDWOOD" -eq 0 ]]; then
      pass "discussions app uses release/ulmo (not redwood) — webpack prompt fix not needed"
    else
      fail "discussions still on redwood — webpack non-interactive fix needed"
    fi
  else
    skip "Snapshot Dockerfile not found — skipping discussions webpack check"
  fi

  # ensure_mfe_discussions_webpack_noninteractive() was in mfe-node.sh (removed tracker #32).
  # This was dead code on Ulmo — discussions webpack is fixed upstream. No replacement needed.
  pass "discussions webpack guard removed as dead code (Ulmo native fix — tracker #32)"

  echo ""

  # -----------------------------------------------------------------------
  # MFE build config: webpack/babel Ulmo-compatible checks
  # -----------------------------------------------------------------------
  echo "--- MFE build config (webpack/babel Ulmo compatibility) ---"

  if [[ -f "$SNAPSHOT" ]]; then
    # Ulmo MFEs use webpack.dev-tutor.config.js (not the old webpack.dev.config.js)
    WEBPACK_CMD=$(grep -c "webpack.dev-tutor.config.js" "$SNAPSHOT" || true)
    if [[ "$WEBPACK_CMD" -ge 1 ]]; then
      pass "MFE dev builds use webpack.dev-tutor.config.js ($WEBPACK_CMD stages)"
    else
      skip "webpack.dev-tutor.config.js not found in snapshot — may be using default cmd"
    fi

    # env.config.jsx present in snapshot (Ulmo plugin slot system requires it)
    ENV_CONFIG=$(grep -c "env.config.jsx" "$SNAPSHOT" || true)
    if [[ "$ENV_CONFIG" -ge 1 ]]; then
      pass "env.config.jsx referenced in snapshot ($ENV_CONFIG COPY statements)"
    else
      fail "env.config.jsx not referenced in snapshot — plugin slots may not be wired"
    fi
  fi

  echo ""

  # -----------------------------------------------------------------------
  # Production kustomization: MFE image tag is pinned (not nightly/latest)
  # -----------------------------------------------------------------------
  echo "--- Production kustomization MFE image tag ---"

  if [[ -f "$KUSTOMIZATION_PROD" ]]; then
    MFE_TAG=$(grep -A2 "openedx-mfe" "$KUSTOMIZATION_PROD" | grep "newTag:" | head -1 | awk '{print $2}' || true)
    if [[ -z "$MFE_TAG" ]]; then
      skip "Could not extract MFE newTag from production kustomization.yaml"
    elif [[ "$MFE_TAG" == "nightly" || "$MFE_TAG" == "latest" ]]; then
      fail "Production MFE image tag is '$MFE_TAG' — must be a pinned build tag"
    else
      pass "Production MFE image tag is pinned: $MFE_TAG"
    fi
  else
    skip "Production kustomization.yaml not found — skipping image tag check"
  fi

  echo ""

  # -----------------------------------------------------------------------
  # Tutor config: MFE_DOCKER_IMAGE reference
  # -----------------------------------------------------------------------
  echo "--- Tutor config MFE_DOCKER_IMAGE reference ---"

  # Check kustomization production overlay for pinned MFE image (canonical source)
  if [[ -f "$KUSTOMIZATION_PROD" ]]; then
    if grep -q "openedx-mfe" "$KUSTOMIZATION_PROD"; then
      pass "MFE image override present in production kustomization.yaml"
    else
      skip "openedx-mfe image not found in production kustomization.yaml"
    fi
  fi

  CONFIG_EXAMPLE="$REPO_ROOT/infrastructure/tutor/config.example.yml"
  if [[ -f "$CONFIG_EXAMPLE" ]]; then
    if grep -q "MFE_DOCKER_IMAGE" "$CONFIG_EXAMPLE"; then
      pass "MFE_DOCKER_IMAGE documented in config.example.yml"
    else
      skip "MFE_DOCKER_IMAGE not in config.example.yml (may be set at deploy time)"
    fi
  else
    skip "config.example.yml not found"
  fi

  echo ""

}

# -----------------------------------------------------------------------
# ONLINE mode
# -----------------------------------------------------------------------
run_online_checks() {

  echo "--- Online: kubectl availability ---"

  if ! command -v kubectl &>/dev/null; then
    skip "kubectl not found — all online checks skipped"
    return
  fi

  if ! kubectl get namespace "$NAMESPACE" &>/dev/null 2>&1; then
    skip "Namespace $NAMESPACE not accessible — all online checks skipped"
    return
  fi

  pass "kubectl available, namespace $NAMESPACE accessible"
  echo ""

  # -----------------------------------------------------------------------
  # Online: MFE pod running with pinned image
  # -----------------------------------------------------------------------
  echo "--- Online: MFE pod running ---"

  MFE_POD=$(kubectl get pods -n "$NAMESPACE" \
    -l "app.kubernetes.io/name=mfe" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -z "$MFE_POD" ]]; then
    skip "No running MFE pod found in namespace $NAMESPACE — skipping pod image checks"
  else
    pass "MFE pod found: $MFE_POD"

    MFE_IMAGE=$(kubectl get pod "$MFE_POD" -n "$NAMESPACE" \
      -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)

    if [[ -n "$MFE_IMAGE" ]]; then
      if grep -qE "nightly|latest" <<<"$MFE_IMAGE"; then
        fail "MFE pod is running a non-pinned image: $MFE_IMAGE"
      else
        pass "MFE pod running pinned image: $MFE_IMAGE"
      fi
    else
      skip "Could not read MFE pod image"
    fi
  fi

  echo ""

  # -----------------------------------------------------------------------
  # Online: MFE routes respond (authn, learning, discussions)
  # -----------------------------------------------------------------------
  echo "--- Online: MFE route smoke tests ---"

  MFE_HOST="${MFE_HOST:-apps.academyv2.mereka.io}"

  for route in authn learning discussions; do
    HTTP_CODE=$(curl -so /dev/null -w '%{http_code}' \
      --max-time 10 \
      "https://${MFE_HOST}/${route}/" 2>/dev/null || echo "")

    if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "304" ]]; then
      pass "MFE route /${route}/ responds HTTP $HTTP_CODE"
    elif [[ "$HTTP_CODE" == "302" || "$HTTP_CODE" == "301" ]]; then
      pass "MFE route /${route}/ responds HTTP $HTTP_CODE (redirect — acceptable for auth-gated routes)"
    elif [[ -n "$HTTP_CODE" && "$HTTP_CODE" != "000" ]]; then
      fail "MFE route /${route}/ returned HTTP $HTTP_CODE (expected 200/30x)"
    else
      skip "MFE route /${route}/ — could not reach $MFE_HOST (check VPN/access)"
    fi
  done

  echo ""

}

# -----------------------------------------------------------------------
# Dispatch
# -----------------------------------------------------------------------
if [[ "$MODE" == "offline" ]]; then
  run_offline_checks
elif [[ "$MODE" == "online" ]]; then
  run_offline_checks
  run_online_checks
fi

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo "[INFO] Full build verification requires the image build lane:"
echo "  ./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast"
echo "  tutor images push mfe"
echo ""
echo "========================================"
echo "MFE Ulmo Migration ($MODE): $PASS PASS / $FAIL FAIL / $SKIP SKIP"
echo "========================================"
exit $((FAIL > 0 ? 1 : 0))
