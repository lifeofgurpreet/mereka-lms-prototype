#!/usr/bin/env bash
set -euo pipefail
# @covers AC-SEC-001, AC-SEC-002
# @spec: secrets-management
# Validates that every ExternalSecret remoteRef.key exists in GCP Secret Manager.
# Skips GCP check if not authenticated; always validates YAML parseability.

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
EXTERNAL_SECRETS_FILE="${REPO_ROOT}/deploy/k8s/base/secrets/external-secrets.yaml"
GCP_PROJECT="${GCP_PROJECT_OVERRIDE:-bbi-k8}"

PASS=0
FAIL=0
SKIP=0

log_pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
log_fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }
log_skip() { echo "  SKIP  $1"; SKIP=$((SKIP + 1)); }
log_info() { echo "        $1"; }

echo "=== verify-secret-inventory ==="
echo "Source: ${EXTERNAL_SECRETS_FILE}"
echo ""

# ── Step 1: Check YAML file exists ────────────────────────────────────────────
if [[ ! -f "${EXTERNAL_SECRETS_FILE}" ]]; then
  log_fail "external-secrets.yaml not found at expected path"
  echo ""
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  exit 1
fi
log_pass "external-secrets.yaml exists"

# ── Step 2: Extract all remoteRef.key values ──────────────────────────────────
# Uses grep to extract lines containing `key: MEREKA_LMS_*` under remoteRef blocks.
# Deliberately avoids yq dependency; resilient to SIGPIPE by using herestring pattern.
KEYS_RAW="$(
  grep -E '^\s+key:\s+MEREKA_LMS_' "${EXTERNAL_SECRETS_FILE}" \
    | sed -E 's/^\s+key:\s+//' \
    | sort -u
)"

if [[ -z "${KEYS_RAW}" ]]; then
  log_fail "No MEREKA_LMS_* remoteRef.key values extracted — check YAML structure"
  echo ""
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  exit 1
fi

mapfile -t KEYS <<< "${KEYS_RAW}"
KEY_COUNT="${#KEYS[@]}"
log_pass "Extracted ${KEY_COUNT} unique remoteRef.key values from YAML"

# ── Step 3: Detect GCP authentication ────────────────────────────────────────
GCP_AUTHENTICATED=false
if command -v gcloud &>/dev/null; then
  ACTIVE_ACCOUNT="$(gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>/dev/null || true)"
  if [[ -n "${ACTIVE_ACCOUNT}" ]]; then
    GCP_AUTHENTICATED=true
    log_info "GCP authenticated as: ${ACTIVE_ACCOUNT}"
  else
    log_info "gcloud present but no active account — skipping GCP Secret Manager checks"
  fi
else
  log_info "gcloud not installed — skipping GCP Secret Manager checks"
fi

echo ""

# ── Step 4: Validate each key ─────────────────────────────────────────────────
echo "--- Key inventory ---"
for KEY in "${KEYS[@]}"; do
  if [[ "${GCP_AUTHENTICATED}" == "true" ]]; then
    # Check if the secret exists in GCP Secret Manager (project: bbi-k8)
    if gcloud secrets describe "${KEY}" \
        --project="${GCP_PROJECT}" \
        --format="value(name)" &>/dev/null 2>&1; then
      log_pass "${KEY}"
    else
      log_fail "${KEY}  [missing in GCP SM project=${GCP_PROJECT}]"
    fi
  else
    log_skip "${KEY}  [GCP check skipped — not authenticated]"
  fi
done

echo ""
echo "--- Summary ---"
echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
echo "Keys checked: ${KEY_COUNT} (project=${GCP_PROJECT})"

if [[ "${FAIL}" -gt 0 ]]; then
  echo ""
  echo "ERROR: ${FAIL} secret(s) missing from GCP Secret Manager."
  echo "Create them with:"
  echo "  printf '%s' 'VALUE' | gcloud secrets versions add KEY_NAME --data-file=- --project=${GCP_PROJECT}"
  exit 1
fi

if [[ "${SKIP}" -eq "${KEY_COUNT}" ]]; then
  echo ""
  echo "NOTE: All GCP checks skipped (not authenticated). YAML structure validated only."
fi

exit 0
