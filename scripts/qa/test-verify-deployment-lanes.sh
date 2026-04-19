#!/usr/bin/env bash
# Seeded-defect self-test for verify-deployment-lanes.sh.
#
# Strategy: the verifier derives REPO_ROOT from BASH_SOURCE[0], so it cannot
# accept a REPO_ROOT_OVERRIDE env var.  Each fixture places a copy of the
# verifier at scripts/qa/ inside a tmpdir tree so that REPO_ROOT resolves to
# the tmpdir.  The original verifier is never modified.
#
# Fixtures:
#   1. happy-path  — minimal well-formed tree; expect exit 0
#   2. missing-overlay          — rke2-nonprod dir absent; expect exit 1
#   3. missing-topology-marker  — staging kustomization missing shared-cluster
#      truth marker; expect exit 1
#   4. missing-required-patch   — rke2-nonprod patches/domain-env.yaml absent;
#      expect exit 1
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFIER_SRC="$ROOT_DIR/scripts/qa/verify-deployment-lanes.sh"

# ── helpers ──────────────────────────────────────────────────────────────────

run_expect_pass() {
  local label="$1"
  local fixture_root="$2"
  set +e
  bash "$fixture_root/scripts/qa/verify-deployment-lanes.sh" \
    >"$fixture_root/.out" 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    echo "FAIL ${label}: expected exit 0, got $rc" >&2
    cat "$fixture_root/.out" >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  local fixture_root="$2"
  set +e
  bash "$fixture_root/scripts/qa/verify-deployment-lanes.sh" \
    >"$fixture_root/.out" 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected non-zero exit, but got 0" >&2
    cat "$fixture_root/.out" >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

# ── fixture builder ───────────────────────────────────────────────────────────
# build_fixture <tmpdir>
# Creates a minimal well-formed overlay tree that the verifier accepts.

build_fixture() {
  local d="$1"

  # required overlay directories
  mkdir -p \
    "$d/deploy/k8s/overlays/local" \
    "$d/deploy/k8s/overlays/rke2-nonprod/patches" \
    "$d/deploy/k8s/overlays/staging" \
    "$d/deploy/k8s/overlays/production" \
    "$d/deploy/k8s/base" \
    "$d/docs/reference/operations" \
    "$d/deploy" \
    "$d/scripts/infra" \
    "$d/scripts/qa"

  # local overlay
  cat >"$d/deploy/k8s/overlays/local/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
EOF

  # rke2-nonprod overlay — must contain the mandatory truth markers
  cat >"$d/deploy/k8s/overlays/rke2-nonprod/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
# NOT consumed by ArgoCD.
# ArgoCD deploys from bbi-infrastructure/apps/mereka-lms/overlays/dev/.
# rke2-nonprod overlay — bbi-infrastructure dev/staging cluster
resources:
  - ../../base
EOF

  # staging overlay — must contain the mandatory truth markers
  cat >"$d/deploy/k8s/overlays/staging/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
# NOT consumed by ArgoCD.
# ArgoCD deploys from bbi-infrastructure/apps/mereka-lms/overlays/staging/.
# Shares cluster with dev (rke2-nonprod) but uses staging.* domains.
resources:
  - ../../base
EOF

  # production overlay — must contain parked-prod marker
  cat >"$d/deploy/k8s/overlays/production/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
# NOT consumed by ArgoCD.
# ArgoCD deploys from bbi-infrastructure/apps/mereka-lms/overlays/prod/.
# GKE prod is scaled to zero replicas.
resources:
  - ../../base
EOF

  # required rke2-nonprod patches
  touch \
    "$d/deploy/k8s/overlays/rke2-nonprod/patches/externalsecrets-infisical.yaml" \
    "$d/deploy/k8s/overlays/rke2-nonprod/patches/domain-env.yaml" \
    "$d/deploy/k8s/overlays/rke2-nonprod/patches/enterprise-catalog-worker-nonprod.yaml"

  # docs
  cat >"$d/docs/reference/operations/DEPLOYMENT_LANES.md" <<'EOF'
# Deployment Lanes
ArgoCD does not deploy from `deploy/k8s/overlays/*` in this repo.
Non-local deployment is realized in bbi-infrastructure.

| env | cluster | status |
|-----|---------|--------|
| dev | shared `rke2-nonprod` | Active |
| staging | shared `rke2-nonprod` | Active |
| prod | GKE | Parked / explicit promotion only; keep zero replicas |
EOF

  cat >"$d/deploy/DEPLOYMENT.md" <<'EOF'
# Mereka LMS Deployment Guide

- **Environment realization**: `local` is applied from this repo. Dev and staging are realized in `bbi-infrastructure` on the shared `rke2-nonprod` cluster.
EOF

  # place verifier inside the fixture tree so BASH_SOURCE-based REPO_ROOT
  # resolves to this tmpdir, not the real repo root
  cp "$VERIFIER_SRC" "$d/scripts/qa/verify-deployment-lanes.sh"
  chmod +x "$d/scripts/qa/verify-deployment-lanes.sh"
}

# ── fixture 1: happy path ─────────────────────────────────────────────────────

tmpdir1="$(mktemp -d -t vdl-test-happy.XXXXXX)"
trap 'rm -rf "$tmpdir1"' EXIT
build_fixture "$tmpdir1"

run_expect_pass "happy-path: well-formed fixture exits 0" "$tmpdir1"

# ── fixture 2: missing overlay directory ─────────────────────────────────────

tmpdir2="$(mktemp -d -t vdl-test-missing-overlay.XXXXXX)"
trap 'rm -rf "$tmpdir2"' EXIT
build_fixture "$tmpdir2"
rm -rf "$tmpdir2/deploy/k8s/overlays/rke2-nonprod"

run_expect_fail "missing-overlay: absent rke2-nonprod dir is detected as failure" "$tmpdir2"

# ── fixture 3: missing topology marker in staging ────────────────────────────

tmpdir3="$(mktemp -d -t vdl-test-topology-marker.XXXXXX)"
trap 'rm -rf "$tmpdir3"' EXIT
build_fixture "$tmpdir3"
# overwrite staging kustomization WITHOUT the shared-cluster truth marker
cat >"$tmpdir3/deploy/k8s/overlays/staging/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
# NOT consumed by ArgoCD.
# ArgoCD deploys from bbi-infrastructure/apps/mereka-lms/overlays/staging/.
resources:
  - ../../base
EOF

run_expect_fail "missing-topology-marker: staging without shared-cluster truth fails" "$tmpdir3"

# ── fixture 4: missing required patch file ───────────────────────────────────

tmpdir4="$(mktemp -d -t vdl-test-missing-patch.XXXXXX)"
trap 'rm -rf "$tmpdir4"' EXIT
build_fixture "$tmpdir4"
rm -f "$tmpdir4/deploy/k8s/overlays/rke2-nonprod/patches/domain-env.yaml"

run_expect_fail "missing-required-patch: absent domain-env.yaml patch is detected as failure" "$tmpdir4"

echo "OK"
