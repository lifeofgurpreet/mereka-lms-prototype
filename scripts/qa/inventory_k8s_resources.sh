#!/usr/bin/env bash
# inventory_k8s_resources.sh -- Inventory and classify deploy/k8s/ resources
#
# Answers:
#   1. What is rendered by deploy/k8s/base/kustomization.yaml
#   2. What is rendered by each overlay's kustomization.yaml
#   3. Which files under deploy/k8s/ are NOT rendered by any kustomization
#   4. Which resources are cluster-scoped
#   5. Which files contain environment-specific domains
#   6. Which files reference platform-owned services or operators
#
# Usage:
#   ./scripts/qa/inventory_k8s_resources.sh [--rendered-only] [--unrendered-only] [--json]
#
# Requirements: bash >= 4.2, find, grep

set -euo pipefail

# -- Config -------------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
K8S_DIR="${REPO_ROOT}/deploy/k8s"

RENDERED_ONLY=false
UNRENDERED_ONLY=false
JSON_OUTPUT=false

for arg in "$@"; do
  case "$arg" in
    --rendered-only)   RENDERED_ONLY=true ;;
    --unrendered-only) UNRENDERED_ONLY=true ;;
    --json)            JSON_OUTPUT=true ;;
    --help|-h)
      echo "Usage: $0 [--rendered-only] [--unrendered-only] [--json]"
      exit 0
      ;;
  esac
done

# -- Helpers ------------------------------------------------------------------

section() {
  echo ""
  echo "======================================================================"
  printf "  %s\n" "$*"
  echo "======================================================================"
}

subsection() {
  echo ""
  printf "  -- %s --\n" "$*"
}

# Extract items from a YAML list block. Given a kustomization.yaml path and
# a top-level key name (e.g. "resources"), prints one entry per line.
extract_yaml_list() {
  local file="$1"
  local key="$2"
  # Use awk to extract list items under the given key, stopping at the next top-level key
  awk -v key="${key}" '
    /^[a-zA-Z]/ { in_block = ($0 ~ "^" key ":") }
    in_block && /^[[:space:]]*-[[:space:]]/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]/, "", line)
      sub(/[[:space:]]*#.*/, "", line)
      if (line != "") print line
    }
  ' "${file}" 2>/dev/null || true
}

# Extract "path:" values from patches: block
extract_patch_paths() {
  local file="$1"
  awk '
    /^patches:/ { in_patches = 1; next }
    /^[a-zA-Z]/ && !/^patches:/ { in_patches = 0 }
    in_patches && /path:/ {
      line = $0
      sub(/.*path:[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*/, "", line)
      gsub(/["'"'"']/, "", line)
      if (line != "") print line
    }
  ' "${file}" 2>/dev/null || true
}

# Extract files listed inside configMapGenerator and secretGenerator blocks
extract_generator_files() {
  local file="$1"
  # Match lines that look like file paths (containing a dot extension)
  awk '
    /^configMapGenerator:|^secretGenerator:/ { in_gen = 1; next }
    /^[a-zA-Z]/ && !/^configMapGenerator:|^secretGenerator:/ { in_gen = 0 }
    in_gen && /\.(py|yml|yaml|js|json|ini|conf|html|txt|sh)/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]/, "", line)
      # Handle "key=path" notation used in configMapGenerator
      if (line ~ /=/) {
        sub(/^[^=]+=/, "", line)
      }
      sub(/[[:space:]]*#.*/, "", line)
      gsub(/["'"'"']/, "", line)
      if (line != "") print line
    }
  ' "${file}" 2>/dev/null || true
}

# Visited set to avoid infinite recursion
declare -A _VISITED

# Resolve a kustomization.yaml recursively, printing all referenced files
# (absolute paths) to stdout.
resolve_kustomization() {
  local kust_file="$1"
  local kust_dir
  kust_dir="$(dirname "${kust_file}")"

  # Guard against infinite recursion
  if [[ -n "${_VISITED[${kust_file}]:-}" ]]; then
    return
  fi
  _VISITED["${kust_file}"]=1

  if [[ ! -f "${kust_file}" ]]; then
    return
  fi

  # Emit the kustomization file itself
  echo "${kust_file}"

  # Process resources: entries
  while IFS= read -r entry; do
    entry="$(echo "${entry}" | tr -d '\r')"
    [[ -z "${entry}" ]] && continue

    local resolved="${kust_dir}/${entry}"

    if [[ -d "${resolved}" ]]; then
      # Directory: find its kustomization.yaml
      for sub_kust in \
        "${resolved}/kustomization.yaml" \
        "${resolved}/kustomization.yml"
      do
        if [[ -f "${sub_kust}" ]]; then
          resolve_kustomization "${sub_kust}"
          break
        fi
      done
    elif [[ -f "${resolved}" ]]; then
      echo "${resolved}"
    fi
  done < <(extract_yaml_list "${kust_file}" "resources")

  # Process patches: path entries
  while IFS= read -r patch_path; do
    patch_path="$(echo "${patch_path}" | tr -d '\r')"
    [[ -z "${patch_path}" ]] && continue
    local resolved="${kust_dir}/${patch_path}"
    if [[ -f "${resolved}" ]]; then
      echo "${resolved}"
    fi
  done < <(extract_patch_paths "${kust_file}")

  # Process configMapGenerator / secretGenerator file entries
  while IFS= read -r cm_file; do
    cm_file="$(echo "${cm_file}" | tr -d '\r')"
    [[ -z "${cm_file}" ]] && continue
    local resolved="${kust_dir}/${cm_file}"
    if [[ -f "${resolved}" ]]; then
      echo "${resolved}"
    fi
  done < <(extract_generator_files "${kust_file}")
}

# Collect all non-Markdown files under deploy/k8s/
collect_all_files() {
  find "${K8S_DIR}" -type f ! -name "*.md" | sort
}

# -- Entry Points -------------------------------------------------------------

declare -A ENTRY_POINTS
ENTRY_POINTS["base"]="${K8S_DIR}/base/kustomization.yaml"
ENTRY_POINTS["local"]="${K8S_DIR}/overlays/local/kustomization.yaml"
ENTRY_POINTS["production"]="${K8S_DIR}/overlays/production/kustomization.yaml"
ENTRY_POINTS["rke2-nonprod"]="${K8S_DIR}/overlays/rke2-nonprod/kustomization.yaml"
ENTRY_POINTS["staging"]="${K8S_DIR}/overlays/staging/kustomization.yaml"
ENTRY_POINTS["arc"]="${K8S_DIR}/base/arc/kustomization.yaml"

# -- Collect rendered files per entry point -----------------------------------

declare -A RENDERED_BY  # absolute_file_path => "ep1 ep2 ..."

for ep_name in "${!ENTRY_POINTS[@]}"; do
  ep_file="${ENTRY_POINTS[${ep_name}]}"
  if [[ ! -f "${ep_file}" ]]; then
    continue
  fi

  # Reset visited set for each entry point
  unset _VISITED
  declare -A _VISITED

  while IFS= read -r rendered_file; do
    rendered_file="$(echo "${rendered_file}" | tr -d '\r')"
    [[ -z "${rendered_file}" ]] && continue
    existing="${RENDERED_BY[${rendered_file}]:-}"
    if [[ -z "${existing}" ]]; then
      RENDERED_BY["${rendered_file}"]="${ep_name}"
    else
      # Avoid duplicates
      if ! echo "${existing}" | grep -qw "${ep_name}"; then
        RENDERED_BY["${rendered_file}"]="${existing} ${ep_name}"
      fi
    fi
  done < <(resolve_kustomization "${ep_file}" 2>/dev/null | sort -u)
done

# -- Build rendered / unrendered lists ----------------------------------------

ALL_FILES=()
while IFS= read -r f; do
  ALL_FILES+=("${f}")
done < <(collect_all_files)

RENDERED_FILES=()
UNRENDERED_FILES=()

for f in "${ALL_FILES[@]}"; do
  if [[ -n "${RENDERED_BY[${f}]:-}" ]]; then
    RENDERED_FILES+=("${f}")
  else
    UNRENDERED_FILES+=("${f}")
  fi
done

# -- JSON output --------------------------------------------------------------

if [[ "${JSON_OUTPUT}" == true ]]; then
  printf '{\n'
  printf '  "rendered": {\n'
  first=true
  for f in "${RENDERED_FILES[@]}"; do
    rel="${f#${K8S_DIR}/}"
    rendered_by="${RENDERED_BY[${f}]}"
    if [[ "${first}" == true ]]; then first=false; else printf ',\n'; fi
    printf '    "%s": "%s"' "${rel}" "${rendered_by}"
  done
  printf '\n  },\n'
  printf '  "unrendered": [\n'
  first=true
  for f in "${UNRENDERED_FILES[@]}"; do
    rel="${f#${K8S_DIR}/}"
    if [[ "${first}" == true ]]; then first=false; else printf ',\n'; fi
    printf '    "%s"' "${rel}"
  done
  printf '\n  ]\n}\n'
  exit 0
fi

# -- Text Report --------------------------------------------------------------

if [[ "${RENDERED_ONLY}" == false && "${UNRENDERED_ONLY}" == false ]]; then
  echo "deploy/k8s/ Resource Inventory Report"
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Repository: ${REPO_ROOT}"
fi

# -- Section 1: What base renders ---------------------------------------------

if [[ "${UNRENDERED_ONLY}" == false ]]; then
  section "1. FILES RENDERED BY base/kustomization.yaml"
  echo "  (direct + transitive resources, configMapGenerator files, patches)"

  for f in "${ALL_FILES[@]}"; do
    rel="${f#${K8S_DIR}/}"
    rendered_by="${RENDERED_BY[${f}]:-}"
    if echo "${rendered_by}" | grep -qw "base"; then
      printf "  RENDERED  %-80s  [%s]\n" "${rel}" "${rendered_by}"
    fi
  done

  # -- Section 2: What each overlay renders -----------------------------------

  section "2. FILES RENDERED PER OVERLAY (unique to that overlay, not in base)"

  for ep_name in local production rke2-nonprod staging arc; do
    subsection "overlay: ${ep_name}"
    found=0
    for f in "${ALL_FILES[@]}"; do
      rel="${f#${K8S_DIR}/}"
      rendered_by="${RENDERED_BY[${f}]:-}"
      if echo "${rendered_by}" | grep -qw "${ep_name}"; then
        if ! echo "${rendered_by}" | grep -qw "base"; then
          printf "    OVERLAY-ONLY  %s\n" "${rel}"
          found=1
        fi
      fi
    done
    if [[ "${found}" == 0 ]]; then
      echo "    (none — all files are also rendered by base)"
    fi
  done
fi

# -- Section 3: Unrendered files ----------------------------------------------

if [[ "${RENDERED_ONLY}" == false ]]; then
  section "3. FILES NOT RENDERED BY ANY KUSTOMIZATION"
  echo "  Action required: quarantine, delete, document, or add to a kustomization"

  for f in "${UNRENDERED_FILES[@]}"; do
    rel="${f#${K8S_DIR}/}"
    printf "  NOT-RENDERED  %s\n" "${rel}"
  done

  echo ""
  printf "  Total unrendered: %d\n" "${#UNRENDERED_FILES[@]}"
fi

# -- Section 4: Cluster-scoped resources --------------------------------------

if [[ "${RENDERED_ONLY}" == false && "${UNRENDERED_ONLY}" == false ]]; then
  section "4. CLUSTER-SCOPED RESOURCES"
  echo "  (ClusterRole, ClusterRoleBinding, ClusterPolicy, ClusterSecretStore,"
  echo "   ClusterIssuer, Namespace, Application[argocd])"

  CLUSTER_SCOPED_KINDS=(
    "ClusterRole"
    "ClusterRoleBinding"
    "ClusterPolicy"
    "ClusterSecretStore"
    "ClusterIssuer"
    "Namespace"
  )

  for f in "${ALL_FILES[@]}"; do
    for kind in "${CLUSTER_SCOPED_KINDS[@]}"; do
      if grep -qE "^kind:[[:space:]]+${kind}[[:space:]]*$" "${f}" 2>/dev/null; then
        rel="${f#${K8S_DIR}/}"
        name="$(grep -m1 -E '^\s*name:\s+' "${f}" 2>/dev/null | sed -E 's/^\s*name:\s+//' | head -1 || echo '?')"
        rendered_by="${RENDERED_BY[${f}]:-NOT-RENDERED}"
        printf "  %-45s  kind=%-25s  name=%s  [%s]\n" \
          "${rel}" "${kind}" "${name}" "${rendered_by}"
      fi
    done
    # ArgoCD Applications
    if grep -qE "^kind:[[:space:]]+Application[[:space:]]*$" "${f}" 2>/dev/null && \
       grep -qE "namespace:[[:space:]]+argocd" "${f}" 2>/dev/null; then
      rel="${f#${K8S_DIR}/}"
      name="$(grep -m1 -E '^\s*name:\s+' "${f}" 2>/dev/null | sed -E 's/^\s*name:\s+//' | head -1 || echo '?')"
      rendered_by="${RENDERED_BY[${f}]:-NOT-RENDERED}"
      printf "  %-45s  kind=%-25s  name=%s  [%s]\n" \
        "${rel}" "Application(argocd)" "${name}" "${rendered_by}"
    fi
  done

  # -- Section 5: Environment-specific domain references ---------------------

  section "5. FILES CONTAINING ENVIRONMENT-SPECIFIC DOMAINS"
  echo "  Domains: .mereka.io, .mereka.dev, biji-biji.com, skillourfuture, academyv2"

  ENV_DOMAIN_PATTERNS=(
    "mereka\\.io"
    "mereka\\.dev"
    "biji-biji\\.com"
    "skillourfuture"
    "academyv2\\."
  )

  for f in "${ALL_FILES[@]}"; do
    matches=""
    for domain in "${ENV_DOMAIN_PATTERNS[@]}"; do
      if grep -qE "${domain}" "${f}" 2>/dev/null; then
        label="${domain//\\/}"
        matches="${matches} ${label}"
      fi
    done
    if [[ -n "${matches}" ]]; then
      rel="${f#${K8S_DIR}/}"
      rendered_by="${RENDERED_BY[${f}]:-NOT-RENDERED}"
      printf "  %-70s  domains=[%s]  [%s]\n" \
        "${rel}" "${matches# }" "${rendered_by}"
    fi
  done

  # -- Section 6: Platform operator references --------------------------------

  section "6. FILES REFERENCING PLATFORM-OWNED OPERATORS"
  echo "  Operators: prometheus, promtail, loki, tempo, kyverno, argocd, cert-manager, velero"

  PLATFORM_PATTERNS=(
    "prometheus"
    "promtail"
    "loki"
    "tempo"
    "kyverno"
    "argocd"
    "cert-manager"
    "velero"
    "argoproj\\.io"
    "kyverno\\.io"
    "monitoring\\.coreos\\.com"
    "external-secrets\\.io"
  )

  for f in "${ALL_FILES[@]}"; do
    matches=""
    for pattern in "${PLATFORM_PATTERNS[@]}"; do
      if grep -qiE "${pattern}" "${f}" 2>/dev/null; then
        label="${pattern//\\/}"
        matches="${matches} ${label}"
      fi
    done
    if [[ -n "${matches}" ]]; then
      rel="${f#${K8S_DIR}/}"
      rendered_by="${RENDERED_BY[${f}]:-NOT-RENDERED}"
      printf "  %-70s  refs=[%s]  [%s]\n" \
        "${rel}" "${matches# }" "${rendered_by}"
    fi
  done

  # -- Summary ---------------------------------------------------------------

  section "SUMMARY"
  printf "\n"
  printf "  Total files under deploy/k8s/  : %d\n" "${#ALL_FILES[@]}"
  printf "  Rendered by at least one kust  : %d\n" "${#RENDERED_FILES[@]}"
  printf "  NOT rendered by any kust       : %d\n" "${#UNRENDERED_FILES[@]}"
  printf "\n"
  echo "  Entry points surveyed:"
  for ep_name in base local production rke2-nonprod staging arc; do
    ep_file="${ENTRY_POINTS[${ep_name}]}"
    if [[ -f "${ep_file}" ]]; then
      printf "    [EXISTS]  %-15s  %s\n" "${ep_name}" "${ep_file#${REPO_ROOT}/}"
    else
      printf "    [MISSING] %-15s  %s\n" "${ep_name}" "${ep_file#${REPO_ROOT}/}"
    fi
  done
  printf "\n"
  echo "  For the full classification, see:"
  echo "    docs/reference/architecture/RESOURCE_OWNERSHIP_MATRIX.md"
  echo "    docs/concepts/architecture/DEPLOYMENT_BOUNDARY.md"
fi
