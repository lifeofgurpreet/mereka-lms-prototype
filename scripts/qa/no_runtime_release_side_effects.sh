#!/usr/bin/env bash
# Fail if Deployment manifests contain migration or collectstatic in
# initContainers or lifecycle hooks.
#
# A normal pod restart should be boring — no schema migrations, no asset builds.
# Migrations belong in Jobs (deploy/k8s/base/jobs/), collectstatic belongs in
# the Docker image build, not at runtime.
set -euo pipefail

DEPLOY_DIR="${1:-deploy/k8s}"
FAILURES=0

# ── helpers ──────────────────────────────────────────────────────────────────

fail() {
  echo "FAIL: $*" >&2
  FAILURES=$(( FAILURES + 1 ))
}

# ── scan YAML files for Deployment kind ──────────────────────────────────────

# Collect all YAML files under deploy/k8s (excluding Jobs and CronJobs, where
# migrate commands and retry logic are intentional).
while IFS= read -r -d '' file; do
  # Skip files that live in the jobs/ directory — migrations are allowed there.
  case "$file" in
    */jobs/*) continue ;;
  esac

  # Only check files that contain a Deployment kind.
  if ! grep -q 'kind: Deployment' "$file" 2>/dev/null; then
    continue
  fi

  # 1. Check for migrate commands in initContainers or lifecycle hooks.
  if grep -Eq 'manage\.py.*(lms |cms )?migrate' "$file"; then
    fail "$file: contains manage.py migrate — move to a Job in deploy/k8s/base/jobs/"
  fi

  # 2. Check for collectstatic in initContainers or lifecycle hooks.
  if grep -q 'collectstatic' "$file"; then
    fail "$file: contains collectstatic — this belongs in the Docker image build, not pod startup"
  fi

  # 3. Check for || true error suppression in container commands.
  #    (Blanket suppression hides real failures; use specific error handling instead.)
  if grep -q '|| true' "$file"; then
    fail "$file: contains '|| true' error suppression — handle failures explicitly"
  fi

done < <(find "$DEPLOY_DIR" -name '*.yaml' -print0)

# ── result ────────────────────────────────────────────────────────────────────

if [ "$FAILURES" -gt 0 ]; then
  echo ""
  echo "FAIL: $FAILURES issue(s) found in Deployment manifests under $DEPLOY_DIR"
  echo "      Pod restarts must not trigger migrations, asset builds, or swallow errors."
  exit 1
fi

echo "PASS: no runtime release side effects found in Deployment manifests under $DEPLOY_DIR"
