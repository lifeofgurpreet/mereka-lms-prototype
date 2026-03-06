#!/usr/bin/env bash
# @covers AC-WC-001
# @spec: multi-site-domains_spec.md
# ops-preflight.sh — Pre-flight check for br + Tutor + GitOps operations
#
# Prints exact environment prerequisites before any combined operation.
# Exit 0 = all clear, Exit 1 = blockers found.
#
# Usage:
#   ./scripts/qa/ops-preflight.sh [--strict]

set -euo pipefail

STRICT=0
[[ "${1:-}" == "--strict" ]] && STRICT=1
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "WARN: $1"; if [[ "$STRICT" -eq 1 ]]; then FAIL=$((FAIL + 1)); fi; }

echo "=== Ops Pre-Flight Check ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ── Git state ────────────────────────────────────────────────────────────────

echo "--- Git ---"
if command -v git &>/dev/null; then
  pass "git available: $(git --version | head -1)"
else
  fail "git not found"
fi

BRANCH="$(git branch --show-current 2>/dev/null || echo "")"
if [[ "$BRANCH" == "main" ]]; then
  pass "On branch main"
else
  warn "On branch '$BRANCH' (expected main)"
fi

DIRTY="$(git status --porcelain 2>/dev/null | grep -v '^\?\?' | head -1 || true)"
if [[ -z "$DIRTY" ]]; then
  pass "Working tree clean (no staged/modified files)"
else
  warn "Working tree has uncommitted changes"
fi

# ── Beads (br) ───────────────────────────────────────────────────────────────

echo ""
echo "--- Beads ---"
if command -v br &>/dev/null; then
  BR_VERSION="$(br --version 2>/dev/null || echo "unknown")"
  pass "br available: $BR_VERSION"
else
  fail "br (beads_rust) not found in PATH"
fi

if [[ -f ".beads/issues.jsonl" ]]; then
  ISSUE_COUNT="$(wc -l < .beads/issues.jsonl)"
  pass ".beads/issues.jsonl present ($ISSUE_COUNT entries)"
else
  warn ".beads/issues.jsonl not found"
fi

# ── Tutor ────────────────────────────────────────────────────────────────────

echo ""
echo "--- Tutor ---"
if [[ -n "${TUTOR_ROOT:-}" ]]; then
  pass "TUTOR_ROOT set: $TUTOR_ROOT"
else
  warn "TUTOR_ROOT not set (run: export TUTOR_ROOT=\$(pwd)/tutor_env)"
fi

if [[ -f "tutor_env/config.yml" ]]; then
  pass "tutor_env/config.yml exists"
else
  warn "tutor_env/config.yml not found (may need tutor config save)"
fi

if command -v tutor &>/dev/null; then
  pass "tutor CLI available"
else
  warn "tutor CLI not in PATH"
fi

# ── Docker ───────────────────────────────────────────────────────────────────

echo ""
echo "--- Docker ---"
if command -v docker &>/dev/null; then
  DOCKER_INFO="$(docker info 2>/dev/null || true)"
  DOCKER_RUNNING="$(echo "$DOCKER_INFO" | grep -c "Server Version" || true)"
  if [[ "$DOCKER_RUNNING" -gt 0 ]]; then
    DOCKER_MEM="$(docker info 2>/dev/null | grep "Total Memory" | awk '{print $3, $4}' || echo "unknown")"
    pass "Docker running (Memory: $DOCKER_MEM)"
  else
    warn "Docker installed but daemon not running"
  fi
else
  warn "Docker not found"
fi

# ── Kubernetes / GitOps ──────────────────────────────────────────────────────

echo ""
echo "--- Kubernetes / GitOps ---"
if command -v kubectl &>/dev/null; then
  CONTEXT="$(kubectl config current-context 2>/dev/null || echo "none")"
  pass "kubectl available (context: $CONTEXT)"
else
  warn "kubectl not found"
fi

BBI_INFRA=""
for candidate in "${WORKSPACE_ROOT}/bbi-infrastructure" "${WORKSPACE_ROOT}/infrastructure"; do
  if [[ -d "$candidate/.git" ]]; then
    BBI_INFRA="$candidate"
    break
  fi
done

if [[ -n "$BBI_INFRA" ]]; then
  pass "bbi-infrastructure repo: $BBI_INFRA"
  INFRA_BRANCH="$(git -C "$BBI_INFRA" branch --show-current 2>/dev/null || echo "unknown")"
  if [[ "$INFRA_BRANCH" == "main" ]]; then
    pass "bbi-infrastructure on main"
  else
    warn "bbi-infrastructure on '$INFRA_BRANCH' (expected main)"
  fi
else
  warn "bbi-infrastructure repo not found"
fi

# ── Agent Mail ───────────────────────────────────────────────────────────────

echo ""
echo "--- Agent Mail ---"
MAIL_HEALTH="$(curl -s --max-time 3 http://127.0.0.1:8007/health 2>/dev/null || echo "")"
if [[ -n "$MAIL_HEALTH" ]]; then
  pass "Agent Mail reachable (port 8007)"
else
  warn "Agent Mail unreachable"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "=== Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN ==="

if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: BLOCKED — fix FAILs before proceeding"
  exit 1
fi

echo "RESULT: READY — all prerequisites met"
exit 0
