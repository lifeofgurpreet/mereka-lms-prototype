#!/usr/bin/env bash
# @covers AC-INT-002
# @spec: ci-cd-pipeline_spec.md
#
# Enforce that migration/init behavior is declared in manifests, not manual runbooks.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
README_FILE="$REPO_ROOT/deploy/k8s/README.md"
ASPECTS_JOBS_FILE="$REPO_ROOT/deploy/k8s/base/plugins/aspects/jobs.yml"

ENTERPRISE_DEPLOYMENTS=(
  "$REPO_ROOT/deploy/k8s/base/apps/enterprise/enterprise-access-deployment.yaml"
  "$REPO_ROOT/deploy/k8s/base/apps/enterprise/enterprise-catalog-deployment.yaml"
  "$REPO_ROOT/deploy/k8s/base/apps/enterprise/enterprise-subsidy-deployment.yaml"
  "$REPO_ROOT/deploy/k8s/base/apps/enterprise/license-manager-deployment.yaml"
)

PASS=0
FAIL=0

pass() {
  echo "PASS $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL $1"
  FAIL=$((FAIL + 1))
}

if [[ -f "$README_FILE" ]]; then
  pass "deploy/k8s README exists"
else
  fail "missing deploy/k8s README"
fi

if [[ -f "$README_FILE" ]]; then
  if grep -Fqi "run manually before first deployment" "$README_FILE"; then
    fail "deploy/k8s README still documents manual-first init flow"
  else
    pass "deploy/k8s README no longer documents manual-first init flow"
  fi

  if grep -Fqi "initContainers" "$README_FILE" && grep -Fqi "base/jobs" "$README_FILE"; then
    pass "deploy/k8s README documents in-graph init/migration contracts"
  else
    fail "deploy/k8s README missing in-graph init/migration contract wording"
  fi
fi

if [[ -f "$ASPECTS_JOBS_FILE" ]]; then
  pass "aspects jobs manifest exists"
  if grep -Fq "name: superset-init" "$ASPECTS_JOBS_FILE" && grep -Fq "name: clickhouse-init" "$ASPECTS_JOBS_FILE"; then
    pass "aspects init jobs declared (superset-init, clickhouse-init)"
  else
    fail "aspects jobs manifest missing required init jobs"
  fi
else
  fail "missing aspects jobs manifest"
fi

for deployment_file in "${ENTERPRISE_DEPLOYMENTS[@]}"; do
  rel_path="${deployment_file#$REPO_ROOT/}"
  if [[ ! -f "$deployment_file" ]]; then
    fail "missing enterprise deployment: $rel_path"
    continue
  fi
  pass "enterprise deployment exists: $rel_path"

  if grep -Fq "name: migrate" "$deployment_file" && grep -Fq "manage.py\", \"migrate\"" "$deployment_file"; then
    pass "enterprise deployment includes migrate init contract: $rel_path"
  else
    fail "enterprise deployment missing migrate init contract: $rel_path"
  fi
done

echo "Summary: PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

