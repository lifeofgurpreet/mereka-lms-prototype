#!/usr/bin/env bash
# verify-frontend-version-truth.sh — AC-UIVER-003: Frontend version drift checker
#
# Verifies that docs/architecture/MFE_VERSIONS.md (canonical source of truth)
# matches version pins in CI workflows, setup scripts, and K8s manifests.
#
# Usage: ./scripts/qa/verify-frontend-version-truth.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
MFE_VERSIONS_DOC="$REPO_ROOT/docs/architecture/MFE_VERSIONS.md"
BUILD_WORKFLOW="$REPO_ROOT/.github/workflows/build-tutor-images.yml"
SETUP_SCRIPT="$REPO_ROOT/scripts/shared/setup-local.sh"
KUSTOMIZATION_BASE="$REPO_ROOT/deploy/k8s/base/kustomization.yaml"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== AC-UIVER-003: Frontend Version Truth Checker ==="
echo ""

# 1. Verify MFE_VERSIONS.md exists and has Version Baseline table
echo "--- MFE_VERSIONS.md Canonical Doc Check ---"
if [ ! -f "$MFE_VERSIONS_DOC" ]; then
  do_fail "MFE_VERSIONS.md not found at docs/architecture/MFE_VERSIONS.md"
  echo ""
  echo "=== AC-UIVER-003 Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi

do_pass "MFE_VERSIONS.md exists"

if grep -q "## Version Baseline" "$MFE_VERSIONS_DOC"; then
  do_pass "Version Baseline section present"
else
  do_fail "Version Baseline section missing from MFE_VERSIONS.md"
fi

# Extract documented versions from MFE_VERSIONS.md
doc_tutor_version=""
doc_mfe_plugin_version=""
doc_node_version=""
doc_python_version=""
doc_plugin_version=""

if grep -q "| \*\*Tutor (pip)\*\*" "$MFE_VERSIONS_DOC"; then
  doc_tutor_version=$(grep "| \*\*Tutor (pip)\*\*" "$MFE_VERSIONS_DOC" | sed -E 's/.*\| ([0-9.]+).*/\1/' | head -1)
  do_pass "Tutor version documented: $doc_tutor_version"
else
  do_fail "Tutor version not documented in Version Baseline table"
fi

if grep -q "| \*\*Tutor MFE Plugin\*\*" "$MFE_VERSIONS_DOC"; then
  doc_mfe_plugin_version=$(grep "| \*\*Tutor MFE Plugin\*\*" "$MFE_VERSIONS_DOC" | sed -E 's/.*\| ([0-9.]+).*/\1/' | head -1)
  do_pass "Tutor MFE plugin version documented: $doc_mfe_plugin_version"
else
  do_fail "Tutor MFE plugin version not documented in Version Baseline table"
fi

if grep -q "| \*\*Node.js\*\*" "$MFE_VERSIONS_DOC"; then
  doc_node_version=$(grep "| \*\*Node.js\*\*" "$MFE_VERSIONS_DOC" | sed -E 's/.*\| ([0-9.]+).*/\1/' | head -1)
  do_pass "Node.js version documented: $doc_node_version"
else
  do_warn "Node.js version not documented in Version Baseline table"
fi

if grep -q "| \*\*Python (CI/Dev)\*\*" "$MFE_VERSIONS_DOC"; then
  doc_python_version=$(grep "| \*\*Python (CI/Dev)\*\*" "$MFE_VERSIONS_DOC" | sed -E 's/.*\| ([0-9.]+).*/\1/' | head -1)
  do_pass "Python version documented: $doc_python_version"
else
  do_warn "Python version not documented in Version Baseline table"
fi

if grep -q "| \*\*Mereka Plugin\*\*" "$MFE_VERSIONS_DOC"; then
  doc_plugin_version=$(grep "| \*\*Mereka Plugin\*\*" "$MFE_VERSIONS_DOC" | sed -E 's/.*\| ([0-9.]+).*/\1/' | head -1)
  do_pass "Mereka plugin version documented: $doc_plugin_version"
else
  do_warn "Mereka plugin version not documented in Version Baseline table"
fi

echo ""

# 2. Cross-reference build-tutor-images.yml
echo "--- CI Workflow Version Pins (.github/workflows/build-tutor-images.yml) ---"
if [ ! -f "$BUILD_WORKFLOW" ]; then
  do_fail "build-tutor-images.yml not found"
else
  do_pass "build-tutor-images.yml exists"

  # Check Tutor version pin in workflow.
  # Supported patterns:
  #   1) Inline pin: pip install "tutor[full]==X.Y.Z" "tutor-mfe==A.B.C"
  #   2) Requirements file pin via setup-python-env action.
  if grep -q "pip install.*tutor\[full\]==" "$BUILD_WORKFLOW"; then
    workflow_tutor=$(grep "pip install.*tutor\[full\]==" "$BUILD_WORKFLOW" | head -1 | sed -E 's/.*tutor\[full\]==([0-9.]+).*/\1/')
    if [ "$workflow_tutor" = "$doc_tutor_version" ]; then
      do_pass "CI Tutor version matches docs: $workflow_tutor"
    else
      do_fail "CI Tutor version ($workflow_tutor) != docs ($doc_tutor_version)"
    fi

    workflow_mfe_plugin=$(grep "pip install.*tutor-mfe==" "$BUILD_WORKFLOW" | head -1 | sed -E 's/.*tutor-mfe==([0-9.]+).*/\1/')
    if [ "$workflow_mfe_plugin" = "$doc_mfe_plugin_version" ]; then
      do_pass "CI MFE plugin version matches docs: $workflow_mfe_plugin"
    else
      do_fail "CI MFE plugin version ($workflow_mfe_plugin) != docs ($doc_mfe_plugin_version)"
    fi
  elif grep -q "requirements-file:" "$BUILD_WORKFLOW"; then
    requirements_file=$(grep "requirements-file:" "$BUILD_WORKFLOW" | head -1 | sed -E "s/.*requirements-file:[[:space:]]*'?(\"?)([^'\"[:space:]]+).*/\2/")
    requirements_path="$REPO_ROOT/$requirements_file"

    if [ -f "$requirements_path" ]; then
      do_pass "CI workflow pins via requirements file: $requirements_file"

      workflow_tutor=$(grep -E '^tutor\[full\]==[0-9.]+' "$requirements_path" | head -1 | sed -E 's/^tutor\[full\]==([0-9.]+).*/\1/')
      if [ -n "$workflow_tutor" ] && [ "$workflow_tutor" = "$doc_tutor_version" ]; then
        do_pass "CI Tutor version matches docs: $workflow_tutor"
      elif [ -n "$workflow_tutor" ]; then
        do_fail "CI Tutor version ($workflow_tutor) != docs ($doc_tutor_version)"
      else
        do_fail "CI requirements file missing tutor[full] pin: $requirements_file"
      fi

      workflow_mfe_plugin=$(grep -E '^tutor-mfe==[0-9.]+' "$requirements_path" | head -1 | sed -E 's/^tutor-mfe==([0-9.]+).*/\1/')
      if [ -n "$workflow_mfe_plugin" ] && [ "$workflow_mfe_plugin" = "$doc_mfe_plugin_version" ]; then
        do_pass "CI MFE plugin version matches docs: $workflow_mfe_plugin"
      elif [ -n "$workflow_mfe_plugin" ]; then
        do_fail "CI MFE plugin version ($workflow_mfe_plugin) != docs ($doc_mfe_plugin_version)"
      else
        do_fail "CI requirements file missing tutor-mfe pin: $requirements_file"
      fi
    else
      do_fail "CI workflow references missing requirements file: $requirements_file"
    fi
  else
    do_fail "No Tutor version pin found in build-tutor-images.yml (inline pip or requirements-file)"
  fi

  # Check Python version in workflow
  if grep -q "python-version:" "$BUILD_WORKFLOW"; then
    workflow_python=$(grep "python-version:" "$BUILD_WORKFLOW" | head -1 | sed -E "s/.*python-version: ['\"]?([0-9.]+)['\"]?.*/\1/")
    if [ "$workflow_python" = "$doc_python_version" ]; then
      do_pass "CI Python version matches docs: $workflow_python"
    else
      do_warn "CI Python version ($workflow_python) != docs ($doc_python_version)"
    fi
  fi
fi

echo ""

# 3. Cross-reference setup-local.sh
echo "--- Local Setup Script Version Pins (scripts/shared/setup-local.sh) ---"
if [ ! -f "$SETUP_SCRIPT" ]; then
  do_warn "setup-local.sh not found (optional)"
else
  do_pass "setup-local.sh exists"

  if grep -q "pip install.*tutor\[full\]==" "$SETUP_SCRIPT"; then
    setup_tutor=$(grep "pip install.*tutor\[full\]==" "$SETUP_SCRIPT" | head -1 | sed -E 's/.*tutor\[full\]==([0-9.]+).*/\1/')
    if [ "$setup_tutor" = "$doc_tutor_version" ]; then
      do_pass "setup-local.sh Tutor version matches docs: $setup_tutor"
    else
      do_fail "setup-local.sh Tutor version ($setup_tutor) != docs ($doc_tutor_version)"
    fi

    setup_mfe_plugin=$(grep "pip install.*tutor-mfe==" "$SETUP_SCRIPT" | head -1 | sed -E 's/.*tutor-mfe==([0-9.]+).*/\1/')
    if [ "$setup_mfe_plugin" = "$doc_mfe_plugin_version" ]; then
      do_pass "setup-local.sh MFE plugin version matches docs: $setup_mfe_plugin"
    else
      do_fail "setup-local.sh MFE plugin version ($setup_mfe_plugin) != docs ($doc_mfe_plugin_version)"
    fi
  else
    do_fail "No Tutor version pin found in setup-local.sh"
  fi
fi

echo ""

# 4. Cross-reference kustomization.yaml image tags (no :latest)
echo "--- K8s Image Tags (deploy/k8s/base/kustomization.yaml) ---"
if [ ! -f "$KUSTOMIZATION_BASE" ]; then
  do_fail "kustomization.yaml not found at deploy/k8s/base/"
else
  do_pass "kustomization.yaml exists"

  # Check for :latest tags
  if grep -q ":latest" "$KUSTOMIZATION_BASE"; then
    do_fail "Found ':latest' tag in kustomization.yaml (must pin to specific tags)"
  else
    do_pass "No ':latest' tags in kustomization.yaml"
  fi

  # Verify openedx and openedx-mfe images have newTag
  # Use awk to find the image name and extract newTag from subsequent lines
  openedx_tag=$(awk '/- name: docker.io\/overhangio\/openedx$/{f=1; next} f && /newTag:/{print; f=0}' "$KUSTOMIZATION_BASE" | sed 's/.*newTag: //' | tr -d ' ')
  if [ -n "$openedx_tag" ] && [ "$openedx_tag" != "latest" ]; then
    do_pass "OpenEdX image pinned to tag: $openedx_tag"
  else
    do_fail "OpenEdX image not pinned or uses ':latest' in kustomization.yaml"
  fi

  mfe_tag=$(awk '/- name: docker.io\/overhangio\/openedx-mfe$/{f=1; next} f && /newTag:/{print; f=0}' "$KUSTOMIZATION_BASE" | sed 's/.*newTag: //' | tr -d ' ')
  if [ -n "$mfe_tag" ] && [ "$mfe_tag" != "latest" ]; then
    do_pass "MFE image pinned to tag: $mfe_tag"
  else
    do_fail "MFE image not pinned or uses ':latest' in kustomization.yaml"
  fi
fi

echo ""

# 5. Cross-reference plugin __version__
echo "--- Mereka Plugin Version (plugin contract sources) ---"
if ! mereka_plugin_has_any "$REPO_ROOT"; then
  do_warn "Plugin contract sources not found (expected mereka_lms.py)"
else
  do_pass "Plugin contract source exists"

  plugin_version=""
  plugin_version_source=""
  while IFS= read -r plugin_file; do
    if grep -q "^__version__" "$plugin_file"; then
      plugin_version="$(grep "^__version__" "$plugin_file" | sed -E 's/^__version__[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/' | head -1)"
      plugin_version_source="${plugin_file#$REPO_ROOT/}"
      break
    fi
  done < <(mereka_plugin_contract_files "$REPO_ROOT")

  if [ -n "$plugin_version" ]; then
    do_pass "Plugin __version__ found: $plugin_version (${plugin_version_source})"

    # Compare with documented version if present
    if [ -n "$doc_plugin_version" ]; then
      if [ "$plugin_version" = "$doc_plugin_version" ]; then
        do_pass "Plugin version matches docs: $plugin_version"
      else
        do_fail "Plugin version ($plugin_version) != docs ($doc_plugin_version)"
      fi
    fi
  else
    do_warn "No __version__ found in plugin contract sources"
  fi
fi

echo ""

# 6. Verify Current Image Tags table exists
echo "--- Current Image Tags Documentation ---"
if grep -q "### Current Image Tags (Production)" "$MFE_VERSIONS_DOC"; then
  do_pass "Current Image Tags section present"

  # Check for image tag entries
  if grep -q "| \*\*OpenEdX\*\*" "$MFE_VERSIONS_DOC"; then
    do_pass "OpenEdX image tag documented"
  else
    do_fail "OpenEdX image tag missing from Current Image Tags table"
  fi

  if grep -q "| \*\*MFE\*\*" "$MFE_VERSIONS_DOC"; then
    do_pass "MFE image tag documented"
  else
    do_fail "MFE image tag missing from Current Image Tags table"
  fi
else
  do_fail "Current Image Tags section missing from MFE_VERSIONS.md"
fi

echo ""

# 7. Verify Upgrade Procedure documented
echo "--- Upgrade Procedure Documentation (AC-UIVER-004) ---"
if grep -q "### Upgrade Procedure for Tutor 21" "$MFE_VERSIONS_DOC"; then
  do_pass "Upgrade Procedure section present"

  # Check for key upgrade steps
  if grep -q "Pre-Upgrade Research" "$MFE_VERSIONS_DOC"; then
    do_pass "Pre-Upgrade Research step documented"
  else
    do_warn "Pre-Upgrade Research step missing from Upgrade Procedure"
  fi

  if grep -q "Update Version Baseline Documentation" "$MFE_VERSIONS_DOC"; then
    do_pass "Update Version Baseline Documentation step present"
  else
    do_warn "Update Version Baseline Documentation step missing"
  fi

  if grep -q "Post-Upgrade Verification Contract" "$MFE_VERSIONS_DOC"; then
    do_pass "Post-Upgrade Verification Contract documented"
  else
    do_warn "Post-Upgrade Verification Contract missing"
  fi
else
  do_fail "Upgrade Procedure section missing from MFE_VERSIONS.md (AC-UIVER-004)"
fi

echo ""
echo "=== AC-UIVER-003 Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
