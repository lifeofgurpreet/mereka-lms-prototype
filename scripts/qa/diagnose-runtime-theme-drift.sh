#!/usr/bin/env bash
# diagnose-runtime-theme-drift.sh — consolidated runtime-theme drift triage.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "${REPO_ROOT}/.." && pwd)}"
LOG_DIR="$REPO_ROOT/var/qa"
mkdir -p "$LOG_DIR"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/runtime-theme-drift-diagnose-${TIMESTAMP}.log"

FAILURES=0
FAIL_PROD_PREFLIGHT=0
FAIL_DEV_PREFLIGHT=0
FAIL_GITOPS_PARITY=0
INFRA_REPO=""
INFRA_BRANCH=""
INFRA_HINT="<infra-repo>"

run_check() {
  local fail_var="$1"
  local label="$2"
  shift 2
  echo "" | tee -a "$LOG_FILE"
  echo "=== ${label} ===" | tee -a "$LOG_FILE"
  if "$@" 2>&1 | tee -a "$LOG_FILE"; then
    echo "PASS: ${label}" | tee -a "$LOG_FILE"
    printf -v "$fail_var" '%s' "0"
  else
    echo "FAIL: ${label}" | tee -a "$LOG_FILE"
    FAILURES=$((FAILURES + 1))
    printf -v "$fail_var" '%s' "1"
  fi
}

echo "Runtime theme drift diagnosis started at ${TIMESTAMP}" | tee "$LOG_FILE"

for candidate in \
  "${WORKSPACE_ROOT}/infrastructure" \
  "${WORKSPACE_ROOT}/bbi-infrastructure" \
  "${HOME}/projects/k8s/infrastructure" \
  "${HOME}/projects/k8s/bbi-infrastructure"; do
  if [[ -d "$candidate/.git" ]]; then
    INFRA_REPO="$candidate"
    break
  fi
done

if [[ -n "$INFRA_REPO" ]]; then
  INFRA_HINT="$INFRA_REPO"
  INFRA_BRANCH="$(git -C "$INFRA_REPO" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -n "$INFRA_BRANCH" ]]; then
    echo "Detected infra checkout: $INFRA_REPO (branch: $INFRA_BRANCH)" | tee -a "$LOG_FILE"
  fi
fi

run_check \
  FAIL_PROD_PREFLIGHT \
  "Prod runtime theme preflight" \
  "$REPO_ROOT/scripts/qa/verify-paragon-runtime.sh" \
  --runtime-url https://apps.academyv2.mereka.io \
  --require-runtime \
  --require-slot-markers

run_check \
  FAIL_DEV_PREFLIGHT \
  "Dev runtime theme preflight" \
  "$REPO_ROOT/scripts/qa/verify-paragon-runtime.sh" \
  --runtime-url https://apps.academyv2.mereka.dev \
  --require-slot-markers

run_check \
  FAIL_GITOPS_PARITY \
  "GitOps image override parity (infra checkout)" \
  "$REPO_ROOT/scripts/qa/verify-gitops-image-overrides.sh" \
  --check-infra

echo "" | tee -a "$LOG_FILE"
echo "Diagnosis log: $LOG_FILE" | tee -a "$LOG_FILE"

if [[ "$FAILURES" -ne 0 ]]; then
  echo "" | tee -a "$LOG_FILE"
  echo "Summary: ${FAILURES} check(s) failed." | tee -a "$LOG_FILE"
  echo "Targeted remediation:" | tee -a "$LOG_FILE"

  if [[ "$FAIL_GITOPS_PARITY" -eq 1 ]]; then
    cat <<EOF | tee -a "$LOG_FILE"
1. Fix app/infra GitOps parity first:
   - scripts/infra/sync-gitops-prod-image-tags.sh --infra-repo ${INFRA_HINT} --apply
   - scripts/infra/sync-vendored-mfe-caddyfile.sh --infra-repo ${INFRA_HINT} --apply
EOF
  fi

  if [[ "$FAIL_PROD_PREFLIGHT" -eq 1 || "$FAIL_DEV_PREFLIGHT" -eq 1 ]]; then
    if [[ "$FAIL_GITOPS_PARITY" -eq 0 ]]; then
      cat <<EOF | tee -a "$LOG_FILE"
2. GitOps parity is clean, but runtime theme preflight still fails:
   - This indicates rollout/runtime drift (cluster not serving expected MFE artifacts yet).
   - Run canonical release/sync flow, then verify runtime:
     ./scripts/infra/release-openedx-gitops.sh --openedx-tag <OPENEDX_TAG> --mfe-tag <MFE_TAG> --apply --commit --push --verify-runtime
EOF
      if [[ -n "$INFRA_BRANCH" && "$INFRA_BRANCH" != "main" ]]; then
        cat <<EOF | tee -a "$LOG_FILE"
   - Note: infra checkout is currently on '$INFRA_BRANCH'. Ensure changes are merged/promoted to the Argo-tracked branch (typically 'main').
EOF
      fi
    else
      echo "2. After GitOps parity fix is merged/synced, re-check runtime preflight." | tee -a "$LOG_FILE"
    fi
  fi

  cat <<EOF | tee -a "$LOG_FILE"
3. Re-run:
   - make qa-runtime-theme-mode-prod
   - make qa-runtime-theme-mode-dev
   - make qa-phase2-smoke-evidence-prod
EOF
  exit 1
fi

echo "Summary: all runtime-theme drift checks passed." | tee -a "$LOG_FILE"
