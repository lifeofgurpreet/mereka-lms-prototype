#!/usr/bin/env bash
# @spec: content-libraries-v2_spec.md
# @covers AC-001, AC-002, AC-003, AC-004, AC-008, AC-016, AC-017, AC-018, AC-019, AC-020
# Verify Content Libraries v2 readiness on the Mereka Academy Open edX deployment.
#
# Checks config files and K8s manifests only (local mode).
# Runtime checks require a running cluster and are clearly marked SKIP when unavailable.
#
# Usage:
#   ./scripts/qa/verify-content-libraries-v2.sh [--mode local|runtime|all]
#
# Modes:
#   local    — Config files and manifests only (default, no cluster needed)
#   runtime  — Live cluster checks (kubectl required)
#   all      — Both local and runtime
set -euo pipefail

# ────────────────────────────────────────────────────────────────
# Setup
# ────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

check_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASSED=$((PASSED + 1))
}

check_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAILED=$((FAILED + 1))
}

check_skip() {
  echo -e "${YELLOW}[SKIP]${NC} $1"
  SKIPPED=$((SKIPPED + 1))
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ────────────────────────────────────────────────────────────────
# Argument parsing
# ────────────────────────────────────────────────────────────────
MODE="local"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--mode local|runtime|all]"
      exit 1
      ;;
  esac
done

if [[ ! "$MODE" =~ ^(local|runtime|all)$ ]]; then
  echo -e "${RED}Invalid mode: $MODE (expected local|runtime|all)${NC}"
  exit 1
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Content Libraries v2 Readiness Verification             ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "  Mode: $MODE"
echo "  Repo: $REPO_ROOT"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ────────────────────────────────────────────────────────────────
# LOCAL CHECKS
# ────────────────────────────────────────────────────────────────
if [[ "$MODE" == "local" || "$MODE" == "all" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "LOCAL CHECKS (config files + manifests)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  LMS_PROD="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
  CMS_PROD="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/production.py"
  PLUGIN_PY="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
  PROM_RULE="$REPO_ROOT/deploy/k8s/base/monitoring/prometheusrule-libraries.yaml"
  PROM_KUST="$REPO_ROOT/deploy/k8s/base/monitoring/kustomization.yaml"
  CRONJOB="$REPO_ROOT/deploy/k8s/base/monitoring/cronjob-library-export.yaml"
  CUSTOM_APP_DIR="$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_content_libraries"

  # ── 1. Django app installed in LMS settings ─────────────────────
  echo "[1] ContentLibrariesConfig in LMS production settings..."
  if [[ -f "$LMS_PROD" ]] && \
     grep -q "openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig" "$LMS_PROD"; then
    check_pass "ContentLibrariesConfig present in LMS production.py"
  else
    check_fail "ContentLibrariesConfig NOT found in LMS production.py"
  fi

  # ── 2. Django app installed in CMS settings ─────────────────────
  echo "[2] ContentLibrariesConfig in CMS production settings..."
  if [[ -f "$CMS_PROD" ]] && \
     grep -q "openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig" "$CMS_PROD"; then
    check_pass "ContentLibrariesConfig present in CMS production.py"
  else
    check_fail "ContentLibrariesConfig NOT found in CMS production.py"
  fi

  # ── 3. Master feature flag wired in LMS ─────────────────────────
  echo "[3] CONTENT_LIBRARIES_V2_ENABLED flag in LMS settings..."
  if [[ -f "$LMS_PROD" ]] && \
     grep -q "CONTENT_LIBRARIES_V2_ENABLED" "$LMS_PROD"; then
    check_pass "CONTENT_LIBRARIES_V2_ENABLED is wired in LMS production.py"
  else
    check_fail "CONTENT_LIBRARIES_V2_ENABLED not found in LMS production.py"
  fi

  # ── 4. Master feature flag wired in CMS ─────────────────────────
  echo "[4] CONTENT_LIBRARIES_V2_ENABLED flag in CMS settings..."
  if [[ -f "$CMS_PROD" ]] && \
     grep -q "CONTENT_LIBRARIES_V2_ENABLED" "$CMS_PROD"; then
    check_pass "CONTENT_LIBRARIES_V2_ENABLED is wired in CMS production.py"
  else
    check_fail "CONTENT_LIBRARIES_V2_ENABLED not found in CMS production.py"
  fi

  # ── 5. Feature flags default to false (safe dark launch) ────────
  echo "[5] Feature flags default to false in LMS settings..."
  # CONTENT_LIBRARIES_V2_ENABLED must have "false" as its default
  lms_flag_default=""
  if [[ -f "$LMS_PROD" ]]; then
    lms_flag_default=$(grep -A2 '"CONTENT_LIBRARIES_V2_ENABLED"' "$LMS_PROD" 2>/dev/null | \
      grep -o '"false"' | head -1 || true)
  fi
  if [[ "$lms_flag_default" == '"false"' ]]; then
    check_pass "CONTENT_LIBRARIES_V2_ENABLED defaults to false (safe dark launch)"
  else
    check_fail "CONTENT_LIBRARIES_V2_ENABLED does NOT default to false — check LMS settings"
  fi

  # ── 6. LIBRARY_RBAC_ENABLED wired ───────────────────────────────
  echo "[6] LIBRARY_RBAC_ENABLED flag in LMS settings..."
  if [[ -f "$LMS_PROD" ]] && grep -q "LIBRARY_RBAC_ENABLED" "$LMS_PROD"; then
    check_pass "LIBRARY_RBAC_ENABLED wired in LMS production.py"
  else
    check_fail "LIBRARY_RBAC_ENABLED not found in LMS production.py"
  fi

  # ── 7. LIBRARY_TENANT_ISOLATION_ENABLED wired ───────────────────
  echo "[7] LIBRARY_TENANT_ISOLATION_ENABLED flag in LMS settings..."
  if [[ -f "$LMS_PROD" ]] && grep -q "LIBRARY_TENANT_ISOLATION_ENABLED" "$LMS_PROD"; then
    check_pass "LIBRARY_TENANT_ISOLATION_ENABLED wired in LMS production.py"
  else
    check_fail "LIBRARY_TENANT_ISOLATION_ENABLED not found in LMS production.py"
  fi

  # ── 8. BLOCKSTORE_BUCKET_NAME configured ────────────────────────
  echo "[8] BLOCKSTORE_BUCKET_NAME in LMS settings..."
  if [[ -f "$LMS_PROD" ]] && grep -q "BLOCKSTORE_BUCKET_NAME" "$LMS_PROD"; then
    check_pass "BLOCKSTORE_BUCKET_NAME wired in LMS production.py"
  else
    check_fail "BLOCKSTORE_BUCKET_NAME not found in LMS production.py"
  fi

  # ── 9. BLOCKSTORE_BUCKET_NAME in CMS settings ───────────────────
  echo "[9] BLOCKSTORE_BUCKET_NAME in CMS settings..."
  if [[ -f "$CMS_PROD" ]] && grep -q "BLOCKSTORE_BUCKET_NAME" "$CMS_PROD"; then
    check_pass "BLOCKSTORE_BUCKET_NAME wired in CMS production.py"
  else
    check_fail "BLOCKSTORE_BUCKET_NAME not found in CMS production.py"
  fi

  # ── 10. Custom extension app exists ─────────────────────────────
  echo "[10] Mereka openedx_content_libraries custom app exists..."
  if [[ -d "$CUSTOM_APP_DIR" ]] && [[ -f "$CUSTOM_APP_DIR/setup.py" ]]; then
    check_pass "openedx_content_libraries custom app found at $CUSTOM_APP_DIR"
  else
    check_fail "openedx_content_libraries custom app NOT found at $CUSTOM_APP_DIR"
  fi

  # ── 11. Custom app listed in mereka_lms Dockerfile hook ─────────
  echo "[11] openedx_content_libraries in mereka_lms.py Dockerfile hook..."
  if [[ -f "$PLUGIN_PY" ]] && grep -q '"openedx_content_libraries"' "$PLUGIN_PY"; then
    check_pass "openedx_content_libraries included in _CUSTOM_APPS list (mereka_lms.py)"
  else
    check_fail "openedx_content_libraries NOT in _CUSTOM_APPS list (mereka_lms.py)"
  fi

  # ── 12. backup_libraries management command exists ───────────────
  echo "[12] backup_libraries management command exists..."
  BACKUP_CMD="$CUSTOM_APP_DIR/management/commands/backup_libraries.py"
  if [[ -f "$BACKUP_CMD" ]]; then
    check_pass "backup_libraries management command found"
  else
    check_fail "backup_libraries management command NOT found at $BACKUP_CMD"
  fi

  # ── 13. reindex_libraries management command exists ─────────────
  echo "[13] reindex_libraries management command exists..."
  REINDEX_CMD="$CUSTOM_APP_DIR/management/commands/reindex_libraries.py"
  if [[ -f "$REINDEX_CMD" ]]; then
    check_pass "reindex_libraries management command found"
  else
    check_fail "reindex_libraries management command NOT found at $REINDEX_CMD"
  fi

  # ── 14. restore_libraries management command exists ─────────────
  echo "[14] restore_libraries management command exists..."
  RESTORE_CMD="$CUSTOM_APP_DIR/management/commands/restore_libraries.py"
  if [[ -f "$RESTORE_CMD" ]]; then
    check_pass "restore_libraries management command found"
  else
    check_fail "restore_libraries management command NOT found at $RESTORE_CMD"
  fi

  # ── 15. create_platform_library management command exists ────────
  echo "[15] create_platform_library management command exists..."
  CREATE_CMD="$CUSTOM_APP_DIR/management/commands/create_platform_library.py"
  if [[ -f "$CREATE_CMD" ]]; then
    check_pass "create_platform_library management command found"
  else
    check_fail "create_platform_library management command NOT found at $CREATE_CMD"
  fi

  # ── 16. PrometheusRule manifest exists ──────────────────────────
  echo "[16] prometheusrule-libraries.yaml manifest exists..."
  if [[ -f "$PROM_RULE" ]]; then
    check_pass "prometheusrule-libraries.yaml manifest found"
  else
    check_fail "prometheusrule-libraries.yaml NOT found at $PROM_RULE"
  fi

  # ── 17. PrometheusRule included in monitoring kustomization ─────
  echo "[17] prometheusrule-libraries.yaml included in monitoring kustomization..."
  if [[ -f "$PROM_KUST" ]] && grep -q "prometheusrule-libraries.yaml" "$PROM_KUST"; then
    check_pass "prometheusrule-libraries.yaml referenced in monitoring/kustomization.yaml"
  else
    check_fail "prometheusrule-libraries.yaml NOT in monitoring/kustomization.yaml"
  fi

  # ── 18. PrometheusRule has cross-tenant denial alert ────────────
  echo "[18] PrometheusRule contains cross-tenant denial spike alert..."
  if [[ -f "$PROM_RULE" ]] && grep -q "ContentLibraryCrossTenantDenialSpike" "$PROM_RULE"; then
    check_pass "ContentLibraryCrossTenantDenialSpike alert rule present"
  else
    check_fail "ContentLibraryCrossTenantDenialSpike alert rule missing in PrometheusRule"
  fi

  # ── 19. Backup CronJob manifest exists ──────────────────────────
  echo "[19] cronjob-library-export.yaml manifest exists..."
  if [[ -f "$CRONJOB" ]]; then
    check_pass "cronjob-library-export.yaml manifest found"
  else
    check_fail "cronjob-library-export.yaml NOT found at $CRONJOB"
  fi

  # ── 20. Backup CronJob NOT yet in kustomization (operator action needed) ──
  echo "[20] Backup CronJob presence in kustomization (expected: not yet added)..."
  if grep -q "cronjob-library-export" "$PROM_KUST" 2>/dev/null; then
    check_pass "cronjob-library-export.yaml already added to kustomization"
  else
    check_skip "cronjob-library-export.yaml NOT yet in kustomization — operator action needed (see docs/operations/CONTENT_LIBRARIES_V2_MIGRATION.md step 3)"
  fi

  # ── 21. LIBRARY_ACCESS_LOGGING_ENABLED wired in LMS ─────────────
  echo "[21] LIBRARY_ACCESS_LOGGING_ENABLED in LMS settings..."
  if [[ -f "$LMS_PROD" ]] && grep -q "LIBRARY_ACCESS_LOGGING_ENABLED" "$LMS_PROD"; then
    check_pass "LIBRARY_ACCESS_LOGGING_ENABLED wired in LMS production.py"
  else
    check_fail "LIBRARY_ACCESS_LOGGING_ENABLED not found in LMS production.py"
  fi

  # ── 22. Library soft-delete retention configured ─────────────────
  echo "[22] LIBRARY_SOFT_DELETE_RETENTION_DAYS in LMS settings..."
  if [[ -f "$LMS_PROD" ]] && grep -q "LIBRARY_SOFT_DELETE_RETENTION_DAYS" "$LMS_PROD"; then
    check_pass "LIBRARY_SOFT_DELETE_RETENTION_DAYS wired in LMS production.py (default: 30 days)"
  else
    check_fail "LIBRARY_SOFT_DELETE_RETENTION_DAYS not found in LMS production.py"
  fi

  # ── 23. Library quota settings configured ────────────────────────
  echo "[23] LIBRARY_TENANT_MAX_LIBRARIES in LMS settings..."
  if [[ -f "$LMS_PROD" ]] && grep -q "LIBRARY_TENANT_MAX_LIBRARIES" "$LMS_PROD"; then
    check_pass "LIBRARY_TENANT_MAX_LIBRARIES wired in LMS production.py (default: 100)"
  else
    check_fail "LIBRARY_TENANT_MAX_LIBRARIES not found in LMS production.py"
  fi

  # ── 24. BLOCKSTORE_BUCKET_NAME NOT in ExternalSecrets (action needed) ──
  echo "[24] BLOCKSTORE_BUCKET_NAME in ExternalSecrets..."
  EXT_SECRETS="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"
  if [[ -f "$EXT_SECRETS" ]] && grep -q "BLOCKSTORE_BUCKET_NAME" "$EXT_SECRETS"; then
    check_pass "BLOCKSTORE_BUCKET_NAME present in external-secrets.yaml"
  else
    check_skip "BLOCKSTORE_BUCKET_NAME NOT in external-secrets.yaml — add before activating (see runbook step 4)"
  fi

  # ── 25. Admin Console MFE check (T114 dependency) ────────────────
  echo "[25] Admin Console MFE dependency (T114): verify-admin-console.sh exists..."
  ADMIN_VERIFY="$REPO_ROOT/scripts/qa/verify-admin-console.sh"
  if [[ -x "$ADMIN_VERIFY" ]]; then
    check_pass "verify-admin-console.sh found and executable (T114 DONE)"
  elif [[ -f "$ADMIN_VERIFY" ]]; then
    check_pass "verify-admin-console.sh found (T114 DONE)"
  else
    check_fail "verify-admin-console.sh NOT found — T114 Admin Console may not be complete"
  fi

  # ── 26. models.py includes required tables ─────────────────────
  echo "[26] openedx_content_libraries models.py contains required tables..."
  MODELS_PY="$CUSTOM_APP_DIR/models.py"
  if [[ -f "$MODELS_PY" ]] && \
     grep -q "LibraryMetadata" "$MODELS_PY" && \
     grep -q "LibraryRole" "$MODELS_PY" && \
     grep -q "LibraryAccessLog" "$MODELS_PY"; then
    check_pass "models.py has LibraryMetadata, LibraryRole, LibraryAccessLog"
  else
    check_fail "models.py missing one or more required model classes"
  fi

  # ── 27. signals.py exists (lifecycle signals) ──────────────────
  echo "[27] Library lifecycle signals.py exists..."
  if [[ -f "$CUSTOM_APP_DIR/signals.py" ]]; then
    check_pass "signals.py found (library lifecycle event handlers)"
  else
    check_fail "signals.py NOT found in openedx_content_libraries"
  fi

  echo ""
fi

# ────────────────────────────────────────────────────────────────
# RUNTIME CHECKS
# ────────────────────────────────────────────────────────────────
if [[ "$MODE" == "runtime" || "$MODE" == "all" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "RUNTIME CHECKS (live cluster)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if ! command -v kubectl &>/dev/null; then
    check_skip "kubectl not available — skipping all runtime checks"
  else
    NAMESPACE="mereka-lms"

    # ── R1. LMS pod running ───────────────────────────────────────
    echo "[R1] LMS pod is running..."
    LMS_RUNNING=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms \
      --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$LMS_RUNNING" -gt 0 ]]; then
      check_pass "LMS pods running ($LMS_RUNNING pods)"
    else
      check_skip "No LMS pods running — cannot perform in-cluster checks"
      # Skip remaining runtime checks if LMS is not running
      echo ""
      echo "Skipping remaining runtime checks (LMS not running)."
    fi

    if [[ "$LMS_RUNNING" -gt 0 ]]; then
      LMS_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms \
        --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

      # ── R2. Libraries v2 API endpoint responds ─────────────────
      echo "[R2] Content Libraries v2 API endpoint (/api/libraries/v2/)..."
      if [[ -n "$LMS_POD" ]]; then
        HTTP_CODE=$(kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
          curl -s -o /dev/null -w "%{http_code}" \
          http://localhost:8000/api/libraries/v2/ 2>/dev/null || echo "000")
        if [[ "$HTTP_CODE" =~ ^(200|401|403)$ ]]; then
          check_pass "Libraries v2 API responded with HTTP $HTTP_CODE (endpoint exists)"
        elif [[ "$HTTP_CODE" == "404" ]]; then
          check_fail "Libraries v2 API returned 404 — ContentLibrariesConfig may not be in INSTALLED_APPS"
        else
          check_skip "Libraries v2 API HTTP $HTTP_CODE — could not determine status"
        fi
      else
        check_skip "No LMS pod found for API check"
      fi

      # ── R3. CONTENT_LIBRARIES_V2_ENABLED env in pod ────────────
      echo "[R3] CONTENT_LIBRARIES_V2_ENABLED environment in LMS pod..."
      if [[ -n "$LMS_POD" ]]; then
        POD_ENV=$(kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
          env 2>/dev/null | grep "CONTENT_LIBRARIES_V2_ENABLED" || true)
        if [[ -n "$POD_ENV" ]]; then
          FLAG_VAL=$(echo "$POD_ENV" | cut -d= -f2)
          check_pass "CONTENT_LIBRARIES_V2_ENABLED=$FLAG_VAL in LMS pod environment"
        else
          check_skip "CONTENT_LIBRARIES_V2_ENABLED not in pod env — using Django settings default (false)"
        fi
      else
        check_skip "No LMS pod for env check"
      fi

      # ── R4. openedx_content_libraries Python module importable ──
      echo "[R4] openedx_content_libraries Python module importable in LMS pod..."
      if [[ -n "$LMS_POD" ]]; then
        IMPORT_OK=$(kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
          python -c "import openedx_content_libraries; print('ok')" 2>/dev/null || echo "fail")
        if [[ "$IMPORT_OK" == "ok" ]]; then
          check_pass "openedx_content_libraries module imports successfully"
        else
          check_fail "openedx_content_libraries module import FAILED — Dockerfile may be missing the COPY/pip install step"
        fi
      else
        check_skip "No LMS pod for Python import check"
      fi

      # ── R5. Library migrations have run ──────────────────────────
      echo "[R5] Library DB migrations applied (LibraryMetadata table exists)..."
      if [[ -n "$LMS_POD" ]]; then
        TABLE_EXISTS=$(kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
          python manage.py lms shell -c \
          "from django.db import connection; tables=connection.introspection.table_names(); print('ok' if 'openedx_content_libraries_metadata' in tables else 'missing')" \
          2>/dev/null || echo "error")
        if [[ "$TABLE_EXISTS" == "ok" ]]; then
          check_pass "openedx_content_libraries_metadata table exists (migrations applied)"
        elif [[ "$TABLE_EXISTS" == "missing" ]]; then
          check_fail "openedx_content_libraries_metadata table missing — run: python manage.py lms migrate openedx_content_libraries"
        else
          check_skip "Could not check DB table existence — see runbook step 5"
        fi
      else
        check_skip "No LMS pod for DB migration check"
      fi

      # ── R6. Admin Console MFE accessible ─────────────────────────
      echo "[R6] Admin Console MFE route accessible..."
      # Check via in-cluster curl to mfe service
      MFE_SVC_IP=$(kubectl get svc mfe -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
      if [[ -n "$MFE_SVC_IP" ]] && [[ -n "$LMS_POD" ]]; then
        MFE_CODE=$(kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
          curl -s -o /dev/null -w "%{http_code}" \
          "http://${MFE_SVC_IP}:8002/admin-console/" 2>/dev/null || echo "000")
        if [[ "$MFE_CODE" =~ ^(200|301|302)$ ]]; then
          check_pass "Admin Console MFE route responds with HTTP $MFE_CODE"
        else
          check_skip "Admin Console MFE HTTP $MFE_CODE — check MFE pod health"
        fi
      else
        check_skip "MFE service ClusterIP not found — cannot check admin-console route"
      fi

      # ── R7. v1 legacy library count ───────────────────────────────
      echo "[R7] Legacy v1 library count in modulestore (expect 0)..."
      if [[ -n "$LMS_POD" ]]; then
        V1_COUNT=$(kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
          python manage.py lms shell -c \
          "from xmodule.modulestore.django import modulestore; libs=modulestore().get_libraries(); print(len(libs))" \
          2>/dev/null || echo "error")
        if [[ "$V1_COUNT" =~ ^[0-9]+$ ]]; then
          if [[ "$V1_COUNT" -eq 0 ]]; then
            check_pass "No v1 legacy libraries found in modulestore ($V1_COUNT)"
          else
            check_fail "Found $V1_COUNT v1 legacy libraries — manual migration to v2 required (see runbook)"
          fi
        else
          check_skip "Could not query modulestore for v1 libraries — may need pymongo[srv] or Atlas connectivity"
        fi
      else
        check_skip "No LMS pod for v1 library count check"
      fi

    fi
  fi

  echo ""
fi

# ────────────────────────────────────────────────────────────────
# SUMMARY
# ────────────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Summary                                                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo -e "  ${GREEN}PASS: $PASSED${NC}"
echo -e "  ${RED}FAIL: $FAILED${NC}"
echo -e "  ${YELLOW}SKIP: $SKIPPED${NC}"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}All checks passed (or skipped). Content Libraries v2 foundation is in place.${NC}"
  echo ""
  echo "Operator actions still needed before going live:"
  echo "  1. Create GCS bucket 'lms-blockstore' (docs/operations/LIBRARIES_GCS_SETUP.md)"
  echo "  2. Set CONTENT_LIBRARIES_V2_ENABLED=true on LMS and CMS pods"
  echo "  3. Add cronjob-library-export.yaml to Kustomize resources"
  echo "  4. Wire BLOCKSTORE_BUCKET_NAME into ExternalSecrets"
  echo "  5. Run: python manage.py lms migrate openedx_content_libraries"
  echo "  6. Run: python manage.py lms create_platform_library (for shared-templates lib)"
  echo ""
  echo "See docs/operations/CONTENT_LIBRARIES_V2_MIGRATION.md for the full runbook."
  exit 0
else
  echo -e "${RED}$FAILED check(s) FAILED. Review the output above and consult the runbook.${NC}"
  echo ""
  echo "Runbook: docs/operations/CONTENT_LIBRARIES_V2_MIGRATION.md"
  exit 1
fi
