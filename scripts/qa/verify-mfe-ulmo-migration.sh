#!/usr/bin/env bash
# @spec: cross-cutting-requirements_spec.md
# @covers AC-ULMO-001: OPENEDX_COMMON_VERSION patch confirmed working (ensure_mfe_ulmo_source_refs)
# @covers AC-ULMO-002: All MFE app source refs use release/ulmo.1
# @covers AC-ULMO-003: Atlas translation pulls use open-release/ulmo.1
# @covers AC-ULMO-004: Brand package upgraded to ulmo-compatible version (^2.4.3)
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
# Patch functions moved to the modular patch file (T018 refactor)
MFE_PATCH="$REPO_ROOT/infrastructure/tutor/patches/mfe-node.sh"
SNAPSHOT="$REPO_ROOT/infrastructure/tutor/mfe-build/Dockerfile"
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

  # -----------------------------------------------------------------------
  # AC-ULMO-001: Patch function exists in apply-patches.sh
  # -----------------------------------------------------------------------
  echo "--- AC-ULMO-001: ensure_mfe_ulmo_source_refs patch function ---"

  if [[ ! -f "$APPLY_PATCHES" ]]; then
    fail "apply-patches.sh not found at $APPLY_PATCHES"
  else
    # After T018 refactor, patch functions live in patches/mfe-node.sh
    PATCH_SOURCE="$APPLY_PATCHES"
    if [[ -f "$MFE_PATCH" ]]; then
      PATCH_SOURCE="$MFE_PATCH"
    fi

    if grep -q "def ensure_mfe_ulmo_source_refs" "$PATCH_SOURCE"; then
      pass "ensure_mfe_ulmo_source_refs() present in $PATCH_SOURCE"
    else
      fail "ensure_mfe_ulmo_source_refs() missing from $PATCH_SOURCE"
    fi

    if grep -q "release/ulmo\.1" "$PATCH_SOURCE"; then
      pass "Patch source patches ADD refs to release/ulmo.1"
    else
      fail "Patch source has no ulmo.1 ref patch"
    fi

    # OPENEDX_COMMON_VERSION check (gitignored config.yml)
    TUTOR_CONFIG="$REPO_ROOT/tutor_env/config.yml"
    if [[ -f "$TUTOR_CONFIG" ]]; then
      CONFIG_VER=$(grep "OPENEDX_COMMON_VERSION" "$TUTOR_CONFIG" | head -1 || true)
      if echo "$CONFIG_VER" | grep -q "redwood"; then
        pass "OPENEDX_COMMON_VERSION=redwood.3 (patch approach active — not config-driven)"
      elif echo "$CONFIG_VER" | grep -q "ulmo"; then
        pass "OPENEDX_COMMON_VERSION=ulmo (config-driven approach — patch is no-op)"
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

  if [[ -f "$SNAPSHOT" ]]; then
    STALE_COUNT=$(grep -cEi "frontend-app.*#.*(nutmeg|palm|olive|quince|open-release/redwood)" "$SNAPSHOT" || true)
    if [[ "$STALE_COUNT" -eq 0 ]]; then
      pass "Snapshot Dockerfile: no stale release refs (nutmeg/palm/olive/quince/redwood)"
    else
      fail "Snapshot Dockerfile: $STALE_COUNT stale release ref(s) found — run apply-patches.sh"
    fi
  else
    skip "Snapshot Dockerfile not found — cannot scan for stale refs"
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
  # AC-ULMO-002: All MFE app source refs use release/ulmo.1 in snapshot
  # -----------------------------------------------------------------------
  echo "--- AC-ULMO-002: MFE source refs in snapshot Dockerfile ---"

  if [[ ! -f "$SNAPSHOT" ]]; then
    fail "Dockerfile snapshot missing: infrastructure/tutor/mfe-build/Dockerfile"
  else
    pass "Dockerfile snapshot exists"

    REDWOOD_COUNT=$(grep -c "frontend-app.*\.git#open-release/redwood" "$SNAPSHOT" || true)
    ULMO_COUNT=$(grep -c "frontend-app.*\.git#release/ulmo" "$SNAPSHOT" || true)

    if [[ "$REDWOOD_COUNT" -eq 0 ]]; then
      pass "No redwood-era ADD refs in snapshot (0 found)"
    else
      fail "$REDWOOD_COUNT redwood-era ADD refs still in snapshot (expected 0)"
    fi

    if [[ "$ULMO_COUNT" -ge 11 ]]; then
      pass "All MFE apps use release/ulmo.1 ($ULMO_COUNT refs found, expected >=11)"
    elif [[ "$ULMO_COUNT" -ge 1 ]]; then
      fail "Only $ULMO_COUNT ulmo refs found (expected >=11) — migration incomplete"
    else
      fail "No ulmo ADD refs in snapshot"
    fi
  fi

  echo ""

  # -----------------------------------------------------------------------
  # Node version: Dockerfile base image uses Node 18+
  # -----------------------------------------------------------------------
  echo "--- Node version: base image must be Node 18+ ---"

  if [[ -f "$SNAPSHOT" ]]; then
    BASE_IMAGE=$(grep -E "^FROM (docker\.io/)?node:" "$SNAPSHOT" | head -1 || true)
    if echo "$BASE_IMAGE" | grep -qE "node:(18|20|22|24)"; then
      pass "MFE base image uses Node 18+: $BASE_IMAGE"
    elif [[ -n "$BASE_IMAGE" ]]; then
      fail "MFE base image may be pre-Node 18: $BASE_IMAGE"
    else
      skip "Cannot determine Node base image from snapshot"
    fi
  else
    skip "Snapshot Dockerfile not found — cannot verify Node version"
  fi

  echo ""

  # -----------------------------------------------------------------------
  # AC-ULMO-003: Atlas translation revision uses open-release/ulmo.1
  # -----------------------------------------------------------------------
  echo "--- AC-ULMO-003: Atlas translation revision ---"

  if [[ -f "$SNAPSHOT" ]]; then
    ATLAS_REDWOOD=$(grep -c "revision=open-release/redwood" "$SNAPSHOT" || true)
    ATLAS_ULMO=$(grep -c "revision=open-release/ulmo" "$SNAPSHOT" || true)

    if [[ "$ATLAS_REDWOOD" -eq 0 ]]; then
      pass "No redwood atlas translation revisions in snapshot"
    else
      fail "$ATLAS_REDWOOD redwood atlas revision ref(s) still in snapshot"
    fi

    if [[ "$ATLAS_ULMO" -ge 11 ]]; then
      pass "All atlas pulls use open-release/ulmo.1 ($ATLAS_ULMO found)"
    elif [[ "$ATLAS_ULMO" -ge 1 ]]; then
      fail "Only $ATLAS_ULMO atlas ulmo refs found (expected >=11)"
    else
      fail "No ulmo atlas translation refs in snapshot"
    fi
  else
    skip "Snapshot Dockerfile not found — skipping atlas checks"
  fi

  echo ""

  # -----------------------------------------------------------------------
  # AC-ULMO-004: Brand package upgraded to ulmo-compatible version
  # -----------------------------------------------------------------------
  echo "--- AC-ULMO-004: Brand package version ---"

  if [[ -f "$SNAPSHOT" ]]; then
    OLD_BRAND=$(grep -c "indigo-brand-openedx@\^2\.1\.1" "$SNAPSHOT" || true)
    NEW_BRAND=$(grep -cE "indigo-brand-openedx@\^2\.[4-9]\.[0-9]" "$SNAPSHOT" || true)

    if [[ "$OLD_BRAND" -eq 0 ]]; then
      pass "No redwood-era brand pin (^2.1.1) in snapshot"
    else
      fail "$OLD_BRAND occurrence(s) of ^2.1.1 brand pin still in snapshot"
    fi

    if [[ "$NEW_BRAND" -ge 11 ]]; then
      pass "Brand upgraded to ulmo-compatible version ($NEW_BRAND installs, expected >=11)"
    elif [[ "$NEW_BRAND" -ge 1 ]]; then
      fail "Only $NEW_BRAND ulmo-compatible brand installs found (expected >=11)"
    else
      fail "No ulmo-compatible brand version (^2.4.x+) found in snapshot"
    fi
  fi

  # After T018 refactor, patch functions live in patches/mfe-node.sh
  BRAND_SOURCE="${MFE_PATCH:-$APPLY_PATCHES}"
  if [[ -f "$BRAND_SOURCE" ]]; then
    if grep -q "def ensure_mfe_brand_ulmo_version" "$BRAND_SOURCE"; then
      pass "ensure_mfe_brand_ulmo_version() present in patch source"
    else
      fail "ensure_mfe_brand_ulmo_version() missing from patch source ($BRAND_SOURCE)"
    fi

    if grep -qE "indigo-brand-openedx@\^2\.[4-9]\." "$BRAND_SOURCE"; then
      pass "Patch source references ulmo-compatible brand version (^2.4.x+)"
    else
      fail "Patch source still references pre-ulmo brand version"
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
      pass "discussions app uses ulmo.1 (not redwood) — webpack prompt fix not needed"
    else
      fail "discussions still on redwood — webpack non-interactive fix needed"
    fi
  else
    skip "Snapshot Dockerfile not found — skipping discussions webpack check"
  fi

  # After T018 refactor, this function lives in patches/mfe-node.sh
  DISCUSSIONS_SOURCE="${MFE_PATCH:-$APPLY_PATCHES}"
  if [[ -f "$DISCUSSIONS_SOURCE" ]]; then
    if grep -q "def ensure_mfe_discussions_webpack_noninteractive" "$DISCUSSIONS_SOURCE"; then
      pass "ensure_mfe_discussions_webpack_noninteractive() present as guard"
    else
      skip "ensure_mfe_discussions_webpack_noninteractive() not found — guard may have been removed"
    fi
  fi

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
      if echo "$MFE_IMAGE" | grep -qE "nightly|latest"; then
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
echo "  tutor images build mfe -a PIP_COMMAND=pip"
echo "  tutor images push mfe"
echo ""
echo "========================================"
echo "MFE Ulmo Migration ($MODE): $PASS PASS / $FAIL FAIL / $SKIP SKIP"
echo "========================================"
exit $((FAIL > 0 ? 1 : 0))
