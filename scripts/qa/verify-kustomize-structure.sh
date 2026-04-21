#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-025
# @spec: k8s-deployment_spec.md
#
# Verify Kustomize overlay structural integrity:
#   - Base and overlay directories exist with valid kustomization.yaml
#   - All referenced patches and resources exist on disk
#   - No orphaned YAML files in patches/ directories
#   - Production images do not use :latest tag when production overlay is app-local
#   - Production overlay sets namespace to mereka-lms when production overlay is app-local
#   - ExternalSecrets file exists in base/secrets/
#
# App repo ownership note:
#   deploy/k8s/base/ and deploy/k8s/overlays/local/ live in this repo.
#   Environment-specific overlays, including production, are realized by
#   bbi-infrastructure. A missing production overlay here is therefore not an
#   app-repo structural failure unless VERIFY_KUSTOMIZE_REQUIRE_PRODUCTION_OVERLAY=1.
#
# Usage:
#   scripts/qa/verify-kustomize-structure.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
K8S_DIR="${REPO_ROOT}/deploy/k8s"
BASE_DIR="${K8S_DIR}/base"
LOCAL_DIR="${K8S_DIR}/overlays/local"
PROD_DIR="${K8S_DIR}/overlays/production"
REQUIRE_PRODUCTION_OVERLAY="${VERIFY_KUSTOMIZE_REQUIRE_PRODUCTION_OVERLAY:-0}"
SCOPE_MODE="${VERIFY_KUSTOMIZE_STRUCTURE_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_KUSTOMIZE_STRUCTURE_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

should_skip_scope() {
  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    case "$path" in
      .github/workflows/ci.yml|\
      deploy/k8s/*|\
      scripts/qa/verify-kustomize-structure.sh)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS verify-kustomize-structure (scope skip: no kustomize-structure-relevant changes)"
  exit 0
fi

# Counters
PASS=0
FAIL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() {
  echo -e "${GREEN}PASS${NC}  $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC}  $1"
  FAIL=$((FAIL + 1))
}

production_overlay_present() {
  [[ -d "${PROD_DIR}" && -f "${PROD_DIR}/kustomization.yaml" ]]
}

# ---------------------------------------------------------------------------
# Helper: validate a YAML file parses without errors
# ---------------------------------------------------------------------------
yaml_valid() {
  python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$1" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Helper: extract list values from a kustomization.yaml key
#   Usage: kustomize_list <file> <key>   e.g. kustomize_list kustomization.yaml resources
# Returns one value per line.
# ---------------------------------------------------------------------------
kustomize_list() {
  local file="$1" key="$2"
  python3 -c "
import yaml, sys
data = yaml.safe_load(open('${file}'))
items = data.get('${key}', []) or []
if isinstance(items, list):
    for item in items:
        if isinstance(item, dict) and 'path' in item:
            print(item['path'])
        elif isinstance(item, str):
            print(item)
"
}

echo "=== Kustomize Structure Verification ==="
echo "Repository: ${REPO_ROOT}"
echo ""

# ---------------------------------------------------------------------------
# 1. Base directory and kustomization.yaml
# ---------------------------------------------------------------------------
echo "--- Base layer ---"

if [[ -d "${BASE_DIR}" ]]; then
  pass "[AC-001] Base directory exists: deploy/k8s/base/"
else
  fail "[AC-001] Base directory missing: deploy/k8s/base/"
fi

if [[ -f "${BASE_DIR}/kustomization.yaml" ]]; then
  if yaml_valid "${BASE_DIR}/kustomization.yaml"; then
    pass "[AC-001] base/kustomization.yaml is valid YAML"
  else
    fail "[AC-001] base/kustomization.yaml is invalid YAML"
  fi
else
  fail "[AC-001] base/kustomization.yaml missing"
fi

# ---------------------------------------------------------------------------
# 2. Overlay directories and kustomization.yaml
# ---------------------------------------------------------------------------
overlay_names=(local)
if [[ -d "${PROD_DIR}" || "${REQUIRE_PRODUCTION_OVERLAY}" == "1" ]]; then
  overlay_names+=(production)
else
  pass "[AC-002] Production overlay absent in app repo; environment overlays are infra-owned"
fi

for overlay_name in "${overlay_names[@]}"; do
  if [[ "${overlay_name}" == "local" ]]; then
    overlay_dir="${LOCAL_DIR}"
    ac="AC-001"
  else
    overlay_dir="${PROD_DIR}"
    ac="AC-002"
  fi

  echo ""
  echo "--- Overlay: ${overlay_name} ---"

  if [[ -d "${overlay_dir}" ]]; then
    pass "[${ac}] Overlay directory exists: overlays/${overlay_name}/"
  elif [[ "${overlay_name}" == "production" && -f "${REPO_ROOT}/docs/reference/architecture/DEPLOYMENT_CONTRACT.md" ]]; then
    # Wave 9 (ADR-025): production overlay relocated to bbi-infrastructure.
    # Boundary doc presence is the canonical statement of the move.
    pass "[${ac}] Overlay absent: overlays/${overlay_name}/ (Wave 9 shadow deletion — canonical boundary doc present)"
    continue
  else
    fail "[${ac}] Overlay directory missing: overlays/${overlay_name}/"
    continue
  fi

  if [[ -f "${overlay_dir}/kustomization.yaml" ]]; then
    if yaml_valid "${overlay_dir}/kustomization.yaml"; then
      pass "[${ac}] overlays/${overlay_name}/kustomization.yaml is valid YAML"
    else
      fail "[${ac}] overlays/${overlay_name}/kustomization.yaml is invalid YAML"
    fi
  else
    fail "[${ac}] overlays/${overlay_name}/kustomization.yaml missing"
    continue
  fi

  # -----------------------------------------------------------------------
  # 3. All referenced resources exist
  # -----------------------------------------------------------------------
  resources=$(kustomize_list "${overlay_dir}/kustomization.yaml" "resources")
  while IFS= read -r res; do
    [[ -z "${res}" ]] && continue
    target="${overlay_dir}/${res}"
    if [[ -f "${target}" || -d "${target}" ]]; then
      pass "[${ac}] Resource resolvable: ${res}"
    else
      fail "[${ac}] Resource missing: ${res} (expected at ${target})"
    fi
  done <<< "${resources}"

  # -----------------------------------------------------------------------
  # 4. All referenced patches exist
  # -----------------------------------------------------------------------
  patches=$(kustomize_list "${overlay_dir}/kustomization.yaml" "patches")
  while IFS= read -r patch; do
    [[ -z "${patch}" ]] && continue
    target="${overlay_dir}/${patch}"
    if [[ -f "${target}" ]]; then
      pass "[${ac}] Patch exists: ${patch}"
    else
      fail "[${ac}] Patch missing: ${patch}"
    fi
  done <<< "${patches}"

  # -----------------------------------------------------------------------
  # 5. No orphaned YAML files in patches/ that aren't referenced
  # -----------------------------------------------------------------------
  patches_dir="${overlay_dir}/patches"
  if [[ -d "${patches_dir}" ]]; then
    while IFS= read -r yaml_file; do
      [[ -z "${yaml_file}" ]] && continue
      relative="patches/$(basename "${yaml_file}")"
      if echo "${patches}" | grep -qF "${relative}"; then
        pass "[${ac}] Patch referenced: ${relative}"
      else
        fail "[${ac}] Orphaned patch file: ${relative} (not referenced in kustomization.yaml)"
      fi
    done < <(find "${patches_dir}" -maxdepth 1 -name '*.yaml' -o -name '*.yml' | sort)
  fi
done

# ---------------------------------------------------------------------------
# 6. Base resources are all resolvable
# ---------------------------------------------------------------------------
echo ""
echo "--- Base resources ---"
base_resources=$(kustomize_list "${BASE_DIR}/kustomization.yaml" "resources")
while IFS= read -r res; do
  [[ -z "${res}" ]] && continue
  target="${BASE_DIR}/${res}"
  if [[ -f "${target}" || -d "${target}" ]]; then
    pass "[AC-001] Base resource resolvable: ${res}"
  else
    fail "[AC-001] Base resource missing: ${res}"
  fi
done <<< "${base_resources}"

# ---------------------------------------------------------------------------
# 7. ExternalSecrets file exists in base/secrets/
# ---------------------------------------------------------------------------
echo ""
echo "--- Secrets ---"
if [[ -f "${BASE_DIR}/secrets/external-secrets.yaml" ]]; then
  pass "[AC-001] ExternalSecrets file exists: base/secrets/external-secrets.yaml"
else
  fail "[AC-001] ExternalSecrets file missing: base/secrets/external-secrets.yaml"
fi

# ---------------------------------------------------------------------------
# 8. Production images do not use :latest tag
# ---------------------------------------------------------------------------
echo ""
echo "--- Production image tags ---"
latest_count=0
if ! production_overlay_present; then
  pass "[AC-025] Production overlay absent in app repo; production image tags are infra-owned"
else
  while IFS= read -r tag_line; do
    [[ -z "${tag_line}" ]] && continue
    if echo "${tag_line}" | grep -qiE '^\s*newTag:\s*["'"'"']?latest["'"'"']?\s*$'; then
      latest_count=$((latest_count + 1))
    fi
  done < <(grep -E '^\s*newTag:' "${PROD_DIR}/kustomization.yaml" 2>/dev/null || true)

  if [[ ${latest_count} -eq 0 ]]; then
    pass "[AC-025] No :latest image tags in production overlay"
  else
    fail "[AC-025] Found ${latest_count} :latest image tag(s) in production overlay"
  fi
fi

# ---------------------------------------------------------------------------
# 9. Production overlay namespace is mereka-lms
# Wave 9 (ADR-025): the production overlay was relocated to
# bbi-infrastructure. When the directory is absent in this repo, treat the
# namespace contract as infra-owned unless the caller explicitly requires the
# production overlay in this app checkout.
# ---------------------------------------------------------------------------
echo ""
echo "--- Namespace ---"
if ! production_overlay_present; then
  pass "[AC-002] Production overlay namespace is infra-owned"
else
  prod_ns=$(python3 -c "
import yaml
data = yaml.safe_load(open('${PROD_DIR}/kustomization.yaml'))
print(data.get('namespace', ''))
" 2>/dev/null || true)

  if [[ "${prod_ns}" == "mereka-lms" ]]; then
    pass "[AC-002] Production overlay namespace is mereka-lms"
  else
    fail "[AC-002] Production overlay namespace is '${prod_ns}', expected 'mereka-lms'"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
echo -e "Passed: ${GREEN}${PASS}${NC}"
echo -e "Failed: ${RED}${FAIL}${NC}"
echo ""

if [[ ${FAIL} -eq 0 ]]; then
  echo -e "${GREEN}All Kustomize structure checks passed.${NC}"
  exit 0
else
  echo -e "${RED}${FAIL} check(s) failed.${NC}"
  exit 1
fi
