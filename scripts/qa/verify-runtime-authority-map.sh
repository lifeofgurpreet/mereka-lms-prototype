#!/usr/bin/env bash
# verify-runtime-authority-map.sh
#
# Enforces the frozen baselines and structural invariants documented in
# deploy/k8s/RUNTIME_AUTHORITY_MAP.md.
#
# Checks:
#   1. Deprecated overlay file counts at or below frozen baselines
#   2. Platform-debt directory file counts at or below frozen baselines
#   3. No __pycache__ or .pyc files tracked in git
#   4. contract.json version matches VERSION file
#   5. No new kustomization.yaml files added to deprecated overlays
#   6. Deprecated overlay kustomizations contain DEPRECATED marker
#   7. Deprecated overlay image blocks carry non-authoritative sentinel comments
#   8. Base kustomization uses only pin-required sentinel tags (or no newTag at all)
#
# Usage:
#   bash scripts/qa/verify-runtime-authority-map.sh
#
# Exit: 0 = all checks pass, 1 = one or more checks failed

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
K8S_DIR="${REPO_ROOT}/deploy/k8s"

PASS=0
FAIL=1
failures=0

# ─── helpers ──────────────────────────────────────────────────────────────────

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; failures=$((failures + 1)); }
section() { echo ""; echo "==> $*"; }

# ─── frozen baselines ─────────────────────────────────────────────────────────

# Deprecated overlays — file counts must not increase
BASELINE_RKE2_NONPROD=21
BASELINE_STAGING=19
BASELINE_PRODUCTION=11

# Platform-debt directories — file counts must not increase
BASELINE_ARC=6
BASELINE_LOGGING=7
BASELINE_POLICIES=6

# ─── Check 1: Deprecated overlay file counts ──────────────────────────────────

section "Check 1: Deprecated overlay file counts (frozen baselines)"

check_overlay_baseline() {
    local overlay_path="$1"
    local baseline="$2"
    local label="$3"

    if [ ! -d "${K8S_DIR}/overlays/${overlay_path}" ]; then
        fail "${label}: directory not found (${K8S_DIR}/overlays/${overlay_path})"
        return
    fi

    local count
    count=$(find "${K8S_DIR}/overlays/${overlay_path}" -type f | wc -l)

    if [ "${count}" -le "${baseline}" ]; then
        pass "${label}: ${count} files (baseline: ${baseline})"
    else
        fail "${label}: ${count} files exceeds frozen baseline of ${baseline}. Files were added to a deprecated overlay. Remove them or update the baseline in RUNTIME_AUTHORITY_MAP.md with justification."
    fi
}

check_overlay_baseline "rke2-nonprod" "${BASELINE_RKE2_NONPROD}" "overlays/rke2-nonprod"
check_overlay_baseline "staging"      "${BASELINE_STAGING}"      "overlays/staging"
check_overlay_baseline "production"   "${BASELINE_PRODUCTION}"   "overlays/production"

# ─── Check 2: Platform-debt directory file counts ─────────────────────────────

section "Check 2: Platform-debt directory file counts (frozen baselines)"

check_platformdebt_baseline() {
    local dir_path="$1"
    local baseline="$2"
    local label="$3"

    if [ ! -d "${K8S_DIR}/base/${dir_path}" ]; then
        fail "${label}: directory not found (${K8S_DIR}/base/${dir_path})"
        return
    fi

    local count
    count=$(find "${K8S_DIR}/base/${dir_path}" -type f | wc -l)

    if [ "${count}" -le "${baseline}" ]; then
        pass "${label}: ${count} files (baseline: ${baseline})"
    else
        fail "${label}: ${count} files exceeds frozen baseline of ${baseline}. This is platform-debt — new files must go to bbi-infrastructure or platform-control-plane instead."
    fi
}

check_platformdebt_baseline "arc"      "${BASELINE_ARC}"      "base/arc"
check_platformdebt_baseline "logging"  "${BASELINE_LOGGING}"  "base/logging"
check_platformdebt_baseline "policies" "${BASELINE_POLICIES}" "base/policies"

# ─── Check 3: No tracked __pycache__ or .pyc files ───────────────────────────

section "Check 3: No __pycache__ or .pyc files tracked in git"

if ! git -C "${REPO_ROOT}" rev-parse --git-dir > /dev/null 2>&1; then
    fail "Not a git repository — cannot check tracked files"
else
    pycache_files=$(git -C "${REPO_ROOT}" ls-files --error-unmatch '*.pyc' '**/__pycache__/**' 2>/dev/null || true)
    tracked_pycache=$(git -C "${REPO_ROOT}" ls-files | grep -E '(__pycache__|\.pyc$)' || true)

    if [ -z "${tracked_pycache}" ]; then
        pass "No __pycache__ or .pyc files tracked in git"
    else
        fail "Tracked Python cache files found — add to .gitignore and remove from git index:"
        echo "${tracked_pycache}" | sed 's/^/    /'
    fi
fi

# ─── Check 4: contract.json version matches VERSION file ──────────────────────

section "Check 4: contract.json version matches deploy/k8s/VERSION"

CONTRACT_JSON="${K8S_DIR}/contract.json"
VERSION_FILE="${K8S_DIR}/VERSION"

if [ ! -f "${CONTRACT_JSON}" ]; then
    fail "contract.json not found at ${CONTRACT_JSON}"
elif [ ! -f "${VERSION_FILE}" ]; then
    fail "VERSION file not found at ${VERSION_FILE}"
else
    contract_version=$(python3 -c "import json,sys; d=json.load(open('${CONTRACT_JSON}')); print(d['version'])" 2>/dev/null || true)
    version_file_content=$(tr -d '[:space:]' < "${VERSION_FILE}")

    if [ -z "${contract_version}" ]; then
        fail "Could not parse version from contract.json"
    elif [ "${contract_version}" = "${version_file_content}" ]; then
        pass "contract.json version (${contract_version}) matches VERSION file (${version_file_content})"
    else
        fail "Version mismatch: contract.json has '${contract_version}', VERSION file has '${version_file_content}'. Update both files together."
    fi
fi

# ─── Check 5: No new kustomization.yaml files in deprecated overlays ─────────

section "Check 5: No new kustomization.yaml files added to deprecated overlays"

check_no_new_kustomizations() {
    local overlay_path="$1"
    local label="$2"
    # Each deprecated overlay should have exactly one kustomization.yaml (at root)
    # Additional kustomization files in subdirs would signal expansion of a frozen overlay

    if [ ! -d "${K8S_DIR}/overlays/${overlay_path}" ]; then
        return  # Already caught in check 1
    fi

    local kustomization_count
    kustomization_count=$(find "${K8S_DIR}/overlays/${overlay_path}" -name "kustomization.yaml" -o -name "kustomization.yml" | wc -l)

    if [ "${kustomization_count}" -le 1 ]; then
        pass "${label}: ${kustomization_count} kustomization file(s) (expected ≤1)"
    else
        fail "${label}: ${kustomization_count} kustomization files found. Deprecated overlays must not be expanded. Only the root kustomization.yaml is permitted."
    fi
}

check_no_new_kustomizations "rke2-nonprod" "overlays/rke2-nonprod"
check_no_new_kustomizations "staging"      "overlays/staging"
check_no_new_kustomizations "production"   "overlays/production"

# ─── Check 6: Deprecated overlay kustomizations contain DEPRECATED marker ────

section "Check 6: Deprecated overlay kustomizations contain DEPRECATED marker"

check_deprecated_marker() {
    local overlay_path="$1"
    local label="$2"
    local kustomization_file="${K8S_DIR}/overlays/${overlay_path}/kustomization.yaml"

    if [ ! -f "${kustomization_file}" ]; then
        fail "${label}: kustomization.yaml not found"
        return
    fi

    if grep -q "DEPRECATED" "${kustomization_file}"; then
        pass "${label}: DEPRECATED marker present in kustomization.yaml"
    else
        fail "${label}: kustomization.yaml missing DEPRECATED marker. Add '# DEPRECATED — boundary.debt — NOT consumed by ArgoCD.' as the first line."
    fi
}

check_deprecated_marker "rke2-nonprod" "overlays/rke2-nonprod"
check_deprecated_marker "staging"      "overlays/staging"
check_deprecated_marker "production"   "overlays/production"

# ─── Check 7: Deprecated overlay image blocks carry sentinel comments ─────────

section "Check 7: Deprecated overlay image blocks carry non-authoritative sentinel comments"

check_overlay_image_sentinel() {
    local overlay_path="$1"
    local label="$2"
    local kustomization_file="${K8S_DIR}/overlays/${overlay_path}/kustomization.yaml"

    if [ ! -f "${kustomization_file}" ]; then
        fail "${label}: kustomization.yaml not found"
        return
    fi

    local images_line
    images_line=$(grep -nE '^[[:space:]]*images:' "${kustomization_file}" | head -n1 | cut -d: -f1 || true)

    if [ -z "${images_line}" ]; then
        pass "${label}: no images block present"
        return
    fi

    local start_line=1
    if [ "${images_line}" -gt 6 ]; then
        start_line=$((images_line - 6))
    fi

    local sentinel_block
    sentinel_block=$(sed -n "${start_line},$((images_line - 1))p" "${kustomization_file}")

    local missing=0
    if ! grep -q "MANAGED-BY: bbi-infrastructure" <<< "${sentinel_block}"; then
        fail "${label}: images block missing 'MANAGED-BY: bbi-infrastructure' sentinel"
        missing=1
    fi
    if ! grep -q "do not edit image pins here" <<< "${sentinel_block}"; then
        fail "${label}: images block missing 'do not edit image pins here' sentinel"
        missing=1
    fi
    if ! grep -q "overridden by the GitOps overlay in bbi-infrastructure" <<< "${sentinel_block}"; then
        fail "${label}: images block missing GitOps override sentinel"
        missing=1
    fi

    if [ "${missing}" -eq 0 ]; then
        pass "${label}: images block is explicitly marked non-authoritative"
    fi
}

check_overlay_image_sentinel "rke2-nonprod" "overlays/rke2-nonprod"
check_overlay_image_sentinel "staging"      "overlays/staging"
check_overlay_image_sentinel "production"   "overlays/production"

# ─── Check 8: Base kustomization uses only pin-required sentinel tags ─────────

section "Check 8: Base kustomization uses only pin-required or absent newTag for images"

BASE_KUSTOMIZATION="${K8S_DIR}/base/kustomization.yaml"

if [ ! -f "${BASE_KUSTOMIZATION}" ]; then
    # Not all repos have a single root kustomization — check sub-kustomizations
    pass "No root base/kustomization.yaml found — skipping (sub-kustomizations govern images)"
else
    # newTag must either be 'pin-required' (sentinel) or absent
    # Mutable tags like 'latest', 'main', branch names are forbidden
    bad_tags=$(grep -E "^\s+newTag:" "${BASE_KUSTOMIZATION}" | grep -Ev "pin-required" || true)

    if [ -z "${bad_tags}" ]; then
        pass "base/kustomization.yaml: all image newTag values use pin-required sentinel or are absent"
    else
        fail "base/kustomization.yaml: mutable newTag values found (must be 'pin-required' or omitted):"
        echo "${bad_tags}" | sed 's/^/    /'
    fi
fi

# Also scan app sub-kustomizations for mutable tags leaking into base
mutable_base_tags=$(find "${K8S_DIR}/base" -name "kustomization.yaml" -exec grep -l "newTag:" {} \; 2>/dev/null | \
    xargs -I{} grep -H "newTag:" {} 2>/dev/null | \
    grep -Ev "(pin-required|#)" || true)

if [ -z "${mutable_base_tags}" ]; then
    pass "base/ sub-kustomizations: no mutable newTag values found"
else
    fail "base/ sub-kustomizations: mutable newTag values found (must be 'pin-required' or omitted):"
    echo "${mutable_base_tags}" | sed 's/^/    /'
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "============================================================"
if [ "${failures}" -eq 0 ]; then
    echo "RESULT: ALL CHECKS PASSED"
    echo "============================================================"
    exit 0
else
    echo "RESULT: ${failures} CHECK(S) FAILED"
    echo "============================================================"
    echo ""
    echo "See deploy/k8s/RUNTIME_AUTHORITY_MAP.md for authority classification rules."
    exit 1
fi
