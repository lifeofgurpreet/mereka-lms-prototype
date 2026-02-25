#!/usr/bin/env bash
# Apply local adjustments to Tutor templates until upstream catches up.
# This script sources modular patch functions from infrastructure/tutor/patches/
# and calls them in order. Each patch is idempotent (safe to run multiple times).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCHES_DIR="$REPO_ROOT/infrastructure/tutor/patches"

# Source shared setup (venv activation, template path discovery)
source "$PATCHES_DIR/_common.sh"

# Run branding health check if available
BRANDING_CHECK="$REPO_ROOT/scripts/branding/verify-branding-health.sh"
if [[ -x "$BRANDING_CHECK" ]]; then
  "$BRANDING_CHECK"
fi

# Source all patch modules
source "$PATCHES_DIR/mysql-auth.sh"
source "$PATCHES_DIR/mfe-node.sh"
source "$PATCHES_DIR/domain-names.sh"
source "$PATCHES_DIR/webpack-memory.sh"
source "$PATCHES_DIR/csrf-origins.sh"
source "$PATCHES_DIR/footer-component.sh"
source "$PATCHES_DIR/prometheus-metrics.sh"
source "$PATCHES_DIR/build-optimizations.sh"
source "$PATCHES_DIR/mongodb-atlas.sh"
source "$PATCHES_DIR/security-hardening.sh"

# Apply patches in dependency order
apply_mysql_auth_patch
apply_mfe_node_patch
apply_domain_names_patch
apply_webpack_memory_patch
apply_csrf_origins_patch
apply_footer_component_patch
apply_prometheus_metrics_patch
apply_build_optimizations_patch
apply_mongodb_atlas_patch
apply_security_hardening_patch

echo "Applied local Tutor patches."
