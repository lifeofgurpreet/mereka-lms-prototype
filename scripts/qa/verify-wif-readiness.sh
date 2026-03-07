#!/usr/bin/env bash
# Verify Workload Identity Federation (WIF) migration readiness.
#
# Checks:
#   1. Count workflows still using credentials_json / GCP_SA_KEY (legacy)
#   2. Count workflows already using workload_identity_provider (WIF)
#   3. Verify google-github-actions/auth is present in workflows
#   4. Check external-secrets.yaml for SA key references
#   5. Report migration readiness summary
#
# Usage:
#   ./scripts/qa/verify-wif-readiness.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNED=0

pass() { echo -e "${GREEN}PASS${NC}  $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}  $1"; FAILED=$((FAILED + 1)); }
warn() { echo -e "${YELLOW}WARN${NC}  $1"; WARNED=$((WARNED + 1)); }

WORKFLOWS_DIR=".github/workflows"
EXTERNAL_SECRETS_FILE="deploy/k8s/base/secrets/external-secrets.yaml"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║    Workload Identity Federation Readiness Check              ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "  Checks migration progress from GCP_SA_KEY to WIF"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ---------------------------------------------------------------------------
# 1. Workflows directory exists
# ---------------------------------------------------------------------------
echo "== Section 1: Workflows directory =="

if [[ -d "$WORKFLOWS_DIR" ]]; then
  pass "workflows directory exists: ${WORKFLOWS_DIR}"
else
  fail "workflows directory missing: ${WORKFLOWS_DIR}"
  echo ""
  echo "Summary: PASSED=${PASSED} FAILED=${FAILED} WARNED=${WARNED}"
  exit 1
fi

WORKFLOW_FILES=()
while IFS= read -r -d '' f; do
  WORKFLOW_FILES+=("$f")
done < <(find "$WORKFLOWS_DIR" -maxdepth 1 -name '*.yml' -type f -print0 | sort -z)

TOTAL_WORKFLOWS="${#WORKFLOW_FILES[@]}"

if [[ "$TOTAL_WORKFLOWS" -gt 0 ]]; then
  pass "found ${TOTAL_WORKFLOWS} workflow files"
else
  fail "no workflow files found in ${WORKFLOWS_DIR}"
  echo ""
  echo "Summary: PASSED=${PASSED} FAILED=${FAILED} WARNED=${WARNED}"
  exit 1
fi

echo ""

# ---------------------------------------------------------------------------
# 2. Count GCP_SA_KEY references (legacy JSON key auth)
# ---------------------------------------------------------------------------
echo "== Section 2: Legacy SA key usage (credentials_json / GCP_SA_KEY) =="

SA_KEY_WORKFLOWS=()
for wf in "${WORKFLOW_FILES[@]}"; do
  # Match actual YAML action input (credentials_json:) or secret reference (${{ secrets.GCP_SA_KEY }})
  # Excludes shell echo lines (which may mention these strings in documentation workflows)
  # Use variable capture to avoid SIGPIPE from grep -q closing pipe early under pipefail
  _filtered="$(grep -vE '^\s*echo\s' "$wf" 2>/dev/null || true)"
  if grep -qE 'credentials_json\s*:|secrets\.GCP_SA_KEY' <<< "$_filtered"; then
    SA_KEY_WORKFLOWS+=("$(basename "$wf")")
  fi
done

SA_KEY_COUNT="${#SA_KEY_WORKFLOWS[@]}"

if [[ "$SA_KEY_COUNT" -eq 0 ]]; then
  pass "no workflows use GCP_SA_KEY / credentials_json (migration complete)"
else
  warn "${SA_KEY_COUNT} workflow(s) still use GCP_SA_KEY / credentials_json:"
  for wf_name in "${SA_KEY_WORKFLOWS[@]}"; do
    echo "       - ${wf_name}"
  done
fi

echo ""

# ---------------------------------------------------------------------------
# 3. Count WIF usage (workload_identity_provider)
# ---------------------------------------------------------------------------
echo "== Section 3: WIF adoption (workload_identity_provider) =="

WIF_WORKFLOWS=()
for wf in "${WORKFLOW_FILES[@]}"; do
  # Match actual YAML key (workload_identity_provider:) not shell echo strings
  _filtered="$(grep -vE '^\s*echo\s' "$wf" 2>/dev/null || true)"
  if grep -qE 'workload_identity_provider\s*:' <<< "$_filtered"; then
    WIF_WORKFLOWS+=("$(basename "$wf")")
  fi
done

WIF_COUNT="${#WIF_WORKFLOWS[@]}"

if [[ "$WIF_COUNT" -gt 0 ]]; then
  pass "${WIF_COUNT} workflow(s) already use WIF:"
  for wf_name in "${WIF_WORKFLOWS[@]}"; do
    echo "       - ${wf_name}"
  done
else
  warn "no workflows use workload_identity_provider yet (migration not started)"
fi

echo ""

# ---------------------------------------------------------------------------
# 4. Check for google-github-actions/auth usage
# ---------------------------------------------------------------------------
echo "== Section 4: GCP auth action usage =="

AUTH_ACTION_WORKFLOWS=()
for wf in "${WORKFLOW_FILES[@]}"; do
  _filtered="$(grep -vE '^\s*echo\s' "$wf" 2>/dev/null || true)"
  if grep -q 'google-github-actions/auth' <<< "$_filtered"; then
    AUTH_ACTION_WORKFLOWS+=("$(basename "$wf")")
  fi
done

AUTH_COUNT="${#AUTH_ACTION_WORKFLOWS[@]}"

CUSTOM_AUTH_WORKFLOWS=()
for wf in "${WORKFLOW_FILES[@]}"; do
  _filtered="$(grep -vE '^\s*echo\s' "$wf" 2>/dev/null || true)"
  if grep -q '\.github/actions/gcp-gke-auth' <<< "$_filtered"; then
    CUSTOM_AUTH_WORKFLOWS+=("$(basename "$wf")")
  fi
done

CUSTOM_AUTH_COUNT="${#CUSTOM_AUTH_WORKFLOWS[@]}"

if [[ "$AUTH_COUNT" -gt 0 || "$CUSTOM_AUTH_COUNT" -gt 0 ]]; then
  pass "found GCP auth action usage (google-github-actions/auth: ${AUTH_COUNT}, custom gcp-gke-auth: ${CUSTOM_AUTH_COUNT})"
else
  warn "no workflows use google-github-actions/auth or .github/actions/gcp-gke-auth — is GCP auth needed?"
fi

echo ""

# ---------------------------------------------------------------------------
# 5. Check id-token: write permission in WIF workflows
# ---------------------------------------------------------------------------
echo "== Section 5: id-token: write permission in WIF workflows =="

if [[ "$WIF_COUNT" -gt 0 ]]; then
  MISSING_ID_TOKEN=()
  for wf in "${WORKFLOW_FILES[@]}"; do
    if grep -q 'workload_identity_provider' "$wf" 2>/dev/null; then
      if ! grep -q 'id-token: write' "$wf" 2>/dev/null; then
        MISSING_ID_TOKEN+=("$(basename "$wf")")
      fi
    fi
  done

  if [[ "${#MISSING_ID_TOKEN[@]}" -eq 0 ]]; then
    pass "all WIF workflows have id-token: write permission"
  else
    fail "${#MISSING_ID_TOKEN[@]} WIF workflow(s) missing id-token: write:"
    for wf_name in "${MISSING_ID_TOKEN[@]}"; do
      echo "       - ${wf_name}"
    done
  fi
else
  warn "skipping id-token check — no WIF workflows found"
fi

echo ""

# ---------------------------------------------------------------------------
# 6. Check external-secrets.yaml for SA key references
# ---------------------------------------------------------------------------
echo "== Section 6: ExternalSecrets SA key references =="

if [[ -f "$EXTERNAL_SECRETS_FILE" ]]; then
  pass "ExternalSecrets file exists: ${EXTERNAL_SECRETS_FILE}"

  if grep -qi 'sa.key\|sa-key\|service.account.key\|serviceaccountkey' "$EXTERNAL_SECRETS_FILE" 2>/dev/null; then
    warn "ExternalSecrets file contains SA key references — verify these are intentional"
  else
    pass "ExternalSecrets file has no SA key references"
  fi
else
  warn "ExternalSecrets file not found at ${EXTERNAL_SECRETS_FILE} — skipping check"
fi

echo ""

# ---------------------------------------------------------------------------
# 7. Migration progress summary
# ---------------------------------------------------------------------------
echo "== Section 7: Migration progress =="

# Workflows needing GCP auth (union of SA key + WIF users)
NEEDS_GCP_AUTH=$((SA_KEY_COUNT + WIF_COUNT))

if [[ "$NEEDS_GCP_AUTH" -gt 0 ]]; then
  MIGRATION_PCT=0
  if [[ "$NEEDS_GCP_AUTH" -gt 0 ]]; then
    MIGRATION_PCT=$(( (WIF_COUNT * 100) / NEEDS_GCP_AUTH ))
  fi
  echo "  GCP-authenticated workflows : ${NEEDS_GCP_AUTH}"
  echo "  Using WIF                   : ${WIF_COUNT} (${MIGRATION_PCT}%)"
  echo "  Still using SA key          : ${SA_KEY_COUNT}"

  if [[ "$SA_KEY_COUNT" -eq 0 ]]; then
    pass "migration complete — all GCP workflows use WIF"
  elif [[ "$WIF_COUNT" -eq 0 ]]; then
    warn "migration not started — all ${SA_KEY_COUNT} workflows still use SA key"
  else
    warn "migration in progress — ${WIF_COUNT}/${NEEDS_GCP_AUTH} workflows migrated to WIF"
  fi
else
  pass "no GCP-authenticated workflows found"
fi

echo ""

# ---------------------------------------------------------------------------
# 8. Docs readiness
# ---------------------------------------------------------------------------
echo "== Section 8: WIF documentation =="

WIF_DOC="docs/operations/WORKLOAD_IDENTITY_FEDERATION.md"

if [[ -f "$WIF_DOC" ]]; then
  pass "WIF migration guide exists: ${WIF_DOC}"
else
  warn "WIF migration guide missing: ${WIF_DOC}"
fi

echo ""

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║    Summary                                                   ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo -e "  ${GREEN}PASS : ${PASSED}${NC}"
echo -e "  ${RED}FAIL : ${FAILED}${NC}"
echo -e "  ${YELLOW}WARN : ${WARNED}${NC}"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [[ "$FAILED" -gt 0 ]]; then
  echo -e "${RED}WIF readiness check encountered failures.${NC}"
  echo "  See above for details."
  echo ""
  exit 1
elif [[ "$WARNED" -gt 0 ]]; then
  echo -e "${YELLOW}WIF readiness check complete with warnings.${NC}"
  echo "  Review warning details above and resolve any remaining gaps."
  echo "  See docs/operations/WORKLOAD_IDENTITY_FEDERATION.md for steps."
  echo ""
  exit 0
else
  echo -e "${GREEN}WIF readiness check passed — migration appears complete.${NC}"
  echo ""
  exit 0
fi
