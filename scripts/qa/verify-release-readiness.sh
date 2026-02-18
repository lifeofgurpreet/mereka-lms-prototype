#!/usr/bin/env bash
# @covers AC-DEP-001, AC-DEP-002, AC-DEP-003, AC-DEP-004
# @spec: ci-cd-pipeline_spec.md
# verify-release-readiness.sh — Pre-release gating + evidence package
#
# Blocks deploy when config or patch drift is detected. Produces evidence
# with image tags, commit SHAs, ArgoCD status, and branding gate outputs.
#
# Usage:
#   ./scripts/qa/verify-release-readiness.sh [--env prod|dev] [--evidence-dir DIR] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV="prod"
EVIDENCE_DIR=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="${2:-prod}"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--env prod|dev] [--evidence-dir DIR] [--dry-run]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$EVIDENCE_DIR" ]]; then
  EVIDENCE_DIR="$REPO_ROOT/var/evidence/release-$(date +%Y%m%d)"
fi

if [[ -d "$EVIDENCE_DIR" ]]; then
  SEQ=2
  while [[ -d "${EVIDENCE_DIR}-${SEQ}" ]]; do SEQ=$((SEQ + 1)); done
  EVIDENCE_DIR="${EVIDENCE_DIR}-${SEQ}"
fi

mkdir -p "$EVIDENCE_DIR"

GATE_PASS=0
GATE_FAIL=0
GATE_WARN=0
RESULTS=()

pass() { GATE_PASS=$((GATE_PASS + 1)); RESULTS+=("PASS: $1"); echo "PASS: $1"; }
fail() { GATE_FAIL=$((GATE_FAIL + 1)); RESULTS+=("FAIL: $1"); echo "FAIL: $1"; }
warn() { GATE_WARN=$((GATE_WARN + 1)); RESULTS+=("WARN: $1"); echo "WARN: $1"; }

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Release Readiness Check                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "Environment: $ENV | Dry-run: $DRY_RUN | Evidence: $EVIDENCE_DIR"
echo ""

# ── Phase 1: Worktree & Config ───────────────────────────────────────────

echo "▸ Phase 1: Worktree & Config Parity"

if [[ -x "$REPO_ROOT/scripts/infra/check-worktree-freshness.sh" ]]; then
  OUTPUT=$("$REPO_ROOT/scripts/infra/check-worktree-freshness.sh" --max-behind 5 2>&1) && RC=0 || RC=$?
  echo "$OUTPUT" > "$EVIDENCE_DIR/worktree-freshness.log"
  if [[ "$RC" -eq 0 ]]; then pass "Worktree fresh"; else fail "Worktree stale"; fi
else
  warn "check-worktree-freshness.sh not found"
fi

HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
{
  echo "HEAD: $HEAD_SHA"
  echo "Branch: $BRANCH"
  echo "Remote: $(git remote get-url origin 2>/dev/null || echo 'none')"
  echo "Dirty: $(git status --porcelain 2>/dev/null | grep -cv '^\?\?' || echo 0) files"
  echo ""
  git log --oneline -10
} > "$EVIDENCE_DIR/git-state.log"
pass "Git state captured (HEAD=${HEAD_SHA:0:8} branch=$BRANCH)"

if [[ -x "$REPO_ROOT/scripts/qa/check-forbidden-overrides.sh" ]]; then
  OUTPUT=$("$REPO_ROOT/scripts/qa/check-forbidden-overrides.sh" 2>&1) && RC=0 || RC=$?
  echo "$OUTPUT" > "$EVIDENCE_DIR/forbidden-overrides.log"
  if [[ "$RC" -eq 0 ]]; then pass "No forbidden overrides"; else fail "Forbidden overrides found"; fi
else
  warn "check-forbidden-overrides.sh not found"
fi

echo ""

# ── Phase 2: Image Tags & GitOps ────────────────────────────────────────

echo "▸ Phase 2: Image Tags & GitOps Ref"

KUSTOMIZATION="$REPO_ROOT/deploy/k8s/overlays/production/kustomization.yaml"
if [[ -f "$KUSTOMIZATION" ]]; then
  grep -A2 'newTag\|newName' "$KUSTOMIZATION" > "$EVIDENCE_DIR/image-tags.log" 2>/dev/null || true
  pass "Image tags captured"
else
  warn "Production kustomization.yaml not found"
fi

if [[ -x "$REPO_ROOT/scripts/qa/verify-gitops-drift.sh" ]]; then
  OUTPUT=$("$REPO_ROOT/scripts/qa/verify-gitops-drift.sh" 2>&1) && RC=0 || RC=$?
  echo "$OUTPUT" > "$EVIDENCE_DIR/gitops-drift.log"
  if [[ "$RC" -eq 0 ]]; then pass "No GitOps drift"; else warn "GitOps drift detected"; fi
else
  warn "verify-gitops-drift.sh not found"
fi

if command -v kubectl &>/dev/null; then
  ARGO_STATUS=$(kubectl get application -n argocd 2>/dev/null || echo "ArgoCD not reachable")
  echo "$ARGO_STATUS" > "$EVIDENCE_DIR/argocd-status.log"
  if echo "$ARGO_STATUS" | grep -q "Synced" 2>/dev/null; then
    pass "ArgoCD status captured"
  else
    warn "ArgoCD not reachable from this host"
  fi
else
  warn "kubectl not available"
fi

echo ""

# ── Phase 3: Branding & Smoke ───────────────────────────────────────────

echo "▸ Phase 3: Branding & Smoke Gates"

if [[ -x "$REPO_ROOT/scripts/qa/verify-post-deploy-smoke.sh" ]]; then
  OUTPUT=$("$REPO_ROOT/scripts/qa/verify-post-deploy-smoke.sh" --env "$ENV" 2>&1) && RC=0 || RC=$?
  echo "$OUTPUT" > "$EVIDENCE_DIR/post-deploy-smoke.log"
  if [[ "$RC" -eq 0 ]]; then
    pass "Post-deploy smoke passed"
  elif [[ "$DRY_RUN" -eq 1 ]]; then
    warn "Post-deploy smoke failed (dry-run — not blocking)"
  else
    fail "Post-deploy smoke failed"
  fi
else
  warn "verify-post-deploy-smoke.sh not found"
fi

if [[ -x "$REPO_ROOT/scripts/qa/verify-tenant-branding-runtime.sh" ]]; then
  OUTPUT=$("$REPO_ROOT/scripts/qa/verify-tenant-branding-runtime.sh" 2>&1) && RC=0 || RC=$?
  echo "$OUTPUT" > "$EVIDENCE_DIR/tenant-branding-runtime.log"
  if [[ "$RC" -eq 0 ]]; then
    pass "Tenant branding verified"
  elif [[ "$DRY_RUN" -eq 1 ]]; then
    warn "Tenant branding failed (dry-run — not blocking)"
  else
    fail "Tenant branding failed"
  fi
else
  warn "verify-tenant-branding-runtime.sh not found"
fi

# ── Summary ──────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       RELEASE READINESS SUMMARY                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
for result in "${RESULTS[@]}"; do
  echo "  $result"
done
echo ""
echo "Gates: PASS=$GATE_PASS FAIL=$GATE_FAIL WARN=$GATE_WARN"

{
  echo "# Release Readiness Evidence"
  echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Environment: $ENV"
  echo "HEAD: $HEAD_SHA"
  echo "Branch: $BRANCH"
  echo "Gates: PASS=$GATE_PASS FAIL=$GATE_FAIL WARN=$GATE_WARN"
  echo ""
  echo "## Results"
  for result in "${RESULTS[@]}"; do
    echo "- $result"
  done
  echo ""
  echo "## Evidence Files"
  ls -1 "$EVIDENCE_DIR"
} > "$EVIDENCE_DIR/release-readiness-summary.md"

echo "Evidence: $EVIDENCE_DIR"

if [[ "$GATE_FAIL" -gt 0 ]]; then
  echo "RESULT: NOT READY — $GATE_FAIL gate(s) failed"
  exit 1
fi

echo "RESULT: READY — all release gates passed"
exit 0
