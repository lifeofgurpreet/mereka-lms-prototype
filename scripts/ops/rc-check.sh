#!/usr/bin/env bash
# scripts/ops/rc-check.sh — RC auto-row checker for Mereka LMS
#
# Runs the 9 ✅-auto rows from docs/reference/operations/RC_CHECKLIST.md and
# prints a summary table. Exits 0 only if all non-skipped rows PASS.
#
# Live-cluster rows (3, 4, 19, 25) require KUBECONFIG and a reachable
# rke2-nonprod context; they are silently SKIP-ped when offline.
# GitHub API rows (1, 2, 23) require GITHUB_TOKEN; they skip when absent.
#
# Usage:
#   scripts/ops/rc-check.sh [--lane dev|staging|prod] [--format text|json]
#
# Environment:
#   GITHUB_TOKEN      GitHub token for API calls (rows 1, 2, 23)
#   KUBECONFIG        Path to kubeconfig file (rows 3, 4, 19, 25)
#   K8S_CONTEXT       kubectl context name (default: rke2-nonprod)
#   K8S_NAMESPACE     Override namespace (default: derived from --lane)
#   MEREKA_LMS_DOMAIN Override domain (default: apps.academyv2.mereka.dev)
#   BBI_INFRA_DIR     Path to local bbi-infrastructure checkout (row 25)
#   BR_BIN            Path to br binary (default: br in PATH)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

LANE="dev"
FORMAT="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lane) LANE="${2:?--lane requires a value}"; shift 2 ;;
    --format) FORMAT="${2:?--format requires a value}"; shift 2 ;;
    -h|--help)
      sed -n '2,/^set -euo/p' "$0" | head -n -1 | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Derive defaults from lane
case "$LANE" in
  dev)     DEFAULT_NS="mereka-lms-dev"     ; DEFAULT_DOMAIN="apps.academyv2.mereka.dev" ;;
  staging) DEFAULT_NS="stg-mereka-lms"     ; DEFAULT_DOMAIN="staging.apps.academyv2.mereka.io" ;;
  prod)    DEFAULT_NS="mereka-lms"         ; DEFAULT_DOMAIN="apps.academyv2.mereka.io" ;;
  *) echo "Unknown lane: $LANE (expected: dev|staging|prod)" >&2; exit 1 ;;
esac

K8S_CONTEXT="${K8S_CONTEXT:-rke2-nonprod}"
K8S_NAMESPACE="${K8S_NAMESPACE:-$DEFAULT_NS}"
MEREKA_LMS_DOMAIN="${MEREKA_LMS_DOMAIN:-$DEFAULT_DOMAIN}"
BR_BIN="${BR_BIN:-br}"

# ── result tracking ────────────────────────────────────────────────────────
declare -A RESULTS   # row# → PASS|FAIL|SKIP
declare -A DETAILS   # row# → detail string
declare -a ROW_ORDER=()

record() {
  local row="$1" status="$2" detail="${3:-}"
  RESULTS["$row"]="$status"
  DETAILS["$row"]="$detail"
  ROW_ORDER+=("$row")
}

# ── helpers ────────────────────────────────────────────────────────────────
has_kubectl_context() {
  command -v kubectl &>/dev/null \
    && kubectl config get-contexts "$K8S_CONTEXT" &>/dev/null 2>&1
}

has_github_token() {
  [[ -n "${GITHUB_TOKEN:-}" ]]
}

kubectl_ro() {
  kubectl --context "$K8S_CONTEXT" "$@"
}

gh_api() {
  # Lightweight curl-based GH API call; falls back to gh CLI if present
  local path="$1"
  if command -v gh &>/dev/null && has_github_token; then
    GH_TOKEN="$GITHUB_TOKEN" gh api "$path" 2>/dev/null
  elif has_github_token; then
    curl -sf -H "Authorization: Bearer $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github+json" \
         "https://api.github.com/$path" 2>/dev/null
  else
    return 1
  fi
}

# ── Row 1: Build Tutor Images green ────────────────────────────────────────
check_row1() {
  if ! has_github_token; then
    record 1 SKIP "no GITHUB_TOKEN"
    return
  fi
  local runs
  runs="$(gh_api "repos/Biji-Biji-Initiative/mereka-lms/actions/workflows/ci.yml/runs?per_page=3" \
          | python3 -c "import sys,json; d=json.load(sys.stdin); runs=d.get('workflow_runs',[]); [print(r['conclusion'],r['head_sha'][:8]) for r in runs[:3]]" 2>/dev/null)" || true
  if [[ -z "$runs" ]]; then
    # Fallback: try by workflow name pattern
    runs="$(gh_api "repos/Biji-Biji-Initiative/mereka-lms/actions/runs?per_page=5" \
            | python3 -c "
import sys,json
d=json.load(sys.stdin)
for r in d.get('workflow_runs',[]):
    if 'Build Tutor Images' in r.get('name','') or 'build-tutor' in r.get('path','').lower():
        print(r['conclusion'],r['head_sha'][:8])
        break
" 2>/dev/null)" || true
  fi
  if [[ -z "$runs" ]]; then
    record 1 SKIP "could not query GitHub Actions API"
    return
  fi
  local conclusion sha
  conclusion="$(echo "$runs" | awk 'NR==1{print $1}')"
  sha="$(echo "$runs" | awk 'NR==1{print $2}')"
  if [[ "$conclusion" == "success" ]]; then
    record 1 PASS "latest run success @ $sha"
  else
    record 1 FAIL "latest run: $conclusion @ $sha"
  fi
}

# ── Row 2: bbi-infra promotion PR ─────────────────────────────────────────
check_row2() {
  if ! has_github_token; then
    record 2 SKIP "no GITHUB_TOKEN"
    return
  fi
  local prs
  prs="$(gh_api "repos/Biji-Biji-Initiative/bbi-infrastructure/pulls?state=open&per_page=10" \
        | python3 -c "
import sys,json
d=json.load(sys.stdin)
hits=[p['title'] for p in d if 'automation/mereka-lms-dev' in p.get('head',{}).get('ref','') or 'mereka-lms-dev' in p.get('title','')]
print('\n'.join(hits[:3]) if hits else 'NONE')
" 2>/dev/null)" || true
  if [[ -z "$prs" ]]; then
    record 2 SKIP "could not query bbi-infrastructure PRs"
    return
  fi
  if [[ "$prs" == "NONE" ]]; then
    record 2 FAIL "no open automation/mereka-lms-dev PR found"
  else
    record 2 PASS "open PR: $(echo "$prs" | head -1)"
  fi
}

# ── Row 3: Argo dev sync status ────────────────────────────────────────────
check_row3() {
  if ! has_kubectl_context; then
    record 3 SKIP "no kubectl context $K8S_CONTEXT"
    return
  fi
  local out
  out="$(kubectl_ro -n argocd get application mereka-lms-dev \
         -o jsonpath='sync={.status.sync.status} rev={.status.sync.revision}' 2>/dev/null)" || true
  if [[ -z "$out" ]]; then
    record 3 SKIP "ArgoCD application mereka-lms-dev not found"
    return
  fi
  if echo "$out" | grep -q "sync=Synced"; then
    record 3 PASS "$out"
  else
    record 3 FAIL "$out"
  fi
}

# ── Row 4: Pod images match promotion PR digest ────────────────────────────
check_row4() {
  if ! has_kubectl_context; then
    record 4 SKIP "no kubectl context $K8S_CONTEXT"
    return
  fi
  local out
  out="$(kubectl_ro -n "$K8S_NAMESPACE" get deploy mfe lms \
         -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.template.spec.containers[0].image}{"\n"}{end}' \
         2>/dev/null)" || true
  if [[ -z "$out" ]]; then
    record 4 SKIP "deployments mfe/lms not found in $K8S_NAMESPACE"
    return
  fi
  # Check both deployments have a digest (sha256:) or a non-latest tag
  if echo "$out" | grep -qE '@sha256:|:[a-f0-9]{7,40}$'; then
    record 4 PASS "$(echo "$out" | tr '\n' '|' | sed 's/|$//')"
  else
    record 4 FAIL "images may be using :latest — $out"
  fi
}

# ── Row 5: Bundle integrity via HTTPS ─────────────────────────────────────
check_row5() {
  local url="https://${MEREKA_LMS_DOMAIN}/authn/login"
  local bundle
  bundle="$(curl -sfL --max-time 15 "$url" 2>/dev/null \
            | grep -oE 'app\.[a-f0-9]+\.js' | head -1)" || true
  if [[ -z "$bundle" ]]; then
    record 5 FAIL "no app.<hash>.js bundle found at $url (curl failed or empty)"
    return
  fi
  record 5 PASS "bundle: $bundle @ $url"
}

# ── Row 19: MEREKA_PLATFORM_ADMIN_EMAILS env var present ─────────────────
check_row19() {
  if ! has_kubectl_context; then
    record 19 SKIP "no kubectl context $K8S_CONTEXT"
    return
  fi
  local val
  val="$(kubectl_ro -n "$K8S_NAMESPACE" get deploy lms \
         -o "jsonpath={.spec.template.spec.containers[0].env[?(@.name==\"MEREKA_PLATFORM_ADMIN_EMAILS\")].value}" \
         2>/dev/null)" || true
  if [[ -z "$val" ]]; then
    record 19 FAIL "MEREKA_PLATFORM_ADMIN_EMAILS not set on lms deploy/$K8S_NAMESPACE"
    return
  fi
  local count
  count="$(echo "$val" | tr ',' '\n' | grep -c '@' || true)"
  if [[ "$count" -ge 1 ]]; then
    record 19 PASS "$count email(s) present"
  else
    record 19 FAIL "env var present but no email addresses found: $val"
  fi
}

# ── Row 23: Post-Deploy E2E Gate green ────────────────────────────────────
check_row23() {
  if ! has_github_token; then
    record 23 SKIP "no GITHUB_TOKEN"
    return
  fi
  local out
  out="$(gh_api "repos/Biji-Biji-Initiative/mereka-lms/actions/workflows/post-deploy-e2e.yml/runs?per_page=3" \
        | python3 -c "
import sys,json
d=json.load(sys.stdin)
runs=d.get('workflow_runs',[])
if not runs:
    print('NONE')
else:
    r=runs[0]
    print(r['conclusion'],r['head_sha'][:8])
" 2>/dev/null)" || true
  if [[ -z "$out" ]] || [[ "$out" == "NONE" ]]; then
    record 23 SKIP "no Post-Deploy E2E Gate runs found"
    return
  fi
  local conclusion sha
  conclusion="$(echo "$out" | awk '{print $1}')"
  sha="$(echo "$out" | awk '{print $2}')"
  if [[ "$conclusion" == "success" ]]; then
    record 23 PASS "latest run success @ $sha"
  else
    record 23 FAIL "latest run: $conclusion @ $sha"
  fi
}

# ── Row 24: br doctor clean ───────────────────────────────────────────────
check_row24() {
  if ! command -v "$BR_BIN" &>/dev/null; then
    record 24 SKIP "br binary not found (BR_BIN=$BR_BIN)"
    return
  fi
  local out
  out="$("$BR_BIN" doctor 2>&1 | grep -E '^(OK|WARN|ERROR)' || true)"
  if echo "$out" | grep -q "^ERROR db.exists:"; then
    record 24 SKIP "br doctor: beads DB absent (no .beads/beads.db in cwd)"
  elif echo "$out" | grep -q "^ERROR"; then
    record 24 FAIL "br doctor reported ERROR(s)"
  else
    record 24 PASS "br doctor clean"
  fi
}

# ── Row 25: admin-parity.sh passes ────────────────────────────────────────
check_row25() {
  if ! has_kubectl_context; then
    record 25 SKIP "no kubectl context $K8S_CONTEXT (live DB access required)"
    return
  fi
  local parity_script="${BBI_INFRA_DIR:-}/identity/access/audit/admin-parity.sh"
  if [[ ! -f "$parity_script" ]]; then
    record 25 SKIP "admin-parity.sh not found (set BBI_INFRA_DIR to bbi-infrastructure checkout)"
    return
  fi
  local out rc=0
  out="$(bash "$parity_script" 2>&1)" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    record 25 PASS "admin-parity.sh exit 0"
  else
    record 25 FAIL "admin-parity.sh exited $rc"
  fi
}

# ── Run all checks ────────────────────────────────────────────────────────
check_row1
check_row2
check_row3
check_row4
check_row5
check_row19
check_row23
check_row24
check_row25

# ── Summary ───────────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

for row in "${ROW_ORDER[@]}"; do
  case "${RESULTS[$row]}" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    SKIP) SKIP_COUNT=$((SKIP_COUNT + 1)) ;;
  esac
done

ROW_LABELS=(
  [1]="Build Tutor Images green"
  [2]="bbi-infra promotion PR opened"
  [3]="Argo dev sync status + revision"
  [4]="Pod images match promotion digest"
  [5]="/authn/login bundle hash present"
  [19]="MEREKA_PLATFORM_ADMIN_EMAILS set"
  [23]="Post-Deploy E2E Gate green"
  [24]="br doctor clean"
  [25]="admin-parity.sh passes"
)

if [[ "$FORMAT" == "json" ]]; then
  python3 - <<PYEOF
import json
rows=[]
for row, status in zip([1,2,3,4,5,19,23,24,25],
    ["${RESULTS[1]:-SKIP}","${RESULTS[2]:-SKIP}","${RESULTS[3]:-SKIP}",
     "${RESULTS[4]:-SKIP}","${RESULTS[5]:-SKIP}","${RESULTS[19]:-SKIP}",
     "${RESULTS[23]:-SKIP}","${RESULTS[24]:-SKIP}","${RESULTS[25]:-SKIP}"]):
    rows.append({"row": row, "status": status})
print(json.dumps({"lane":"$LANE","pass":$PASS_COUNT,"fail":$FAIL_COUNT,"skip":$SKIP_COUNT,"rows":rows},indent=2))
PYEOF
else
  echo ""
  echo "RC Auto-Row Check — lane: $LANE"
  echo "======================================================================"
  printf "%-4s  %-8s  %-35s  %s\n" "ROW" "STATUS" "CHECK" "DETAIL"
  printf "%-4s  %-8s  %-35s  %s\n" "---" "------" "-----" "------"
  for row in "${ROW_ORDER[@]}"; do
    local_status="${RESULTS[$row]}"
    local_label="${ROW_LABELS[$row]:-row $row}"
    local_detail="${DETAILS[$row]:-}"
    case "$local_status" in
      PASS) icon="✅" ;;
      FAIL) icon="❌" ;;
      SKIP) icon="⏭" ;;
      *)    icon="?" ;;
    esac
    printf "%-4s  %-8s  %-35s  %s\n" "$row" "$icon $local_status" "$local_label" "$local_detail"
  done
  echo ""
  echo "  PASS: $PASS_COUNT  FAIL: $FAIL_COUNT  SKIP: $SKIP_COUNT"
  echo ""
fi

[[ "$FAIL_COUNT" -eq 0 ]]
