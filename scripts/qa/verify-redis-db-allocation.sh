#!/usr/bin/env bash
# @covers AC-ENT-001
# @spec: k8s-deployment_spec.md
#
# Verify Redis DB numbers are unique per service (no collisions).
# Each enterprise service must use a distinct Redis DB for cache and celery.
#
# Allocation map:
#   DB 0-7:  reserved (LMS, CMS, forum, etc.)
#   DB 8:    enterprise-catalog cache
#   DB 9:    enterprise-catalog celery
#   DB 10:   enterprise-subsidy cache
#   DB 11:   license-manager cache
#   DB 12:   enterprise-access cache
#   DB 13:   enterprise-access celery
#   DB 14:   purchase-gateway / license-manager celery
#   DB 15:   reserved
#
# Exit 0 = no collisions
# Exit 1 = collision detected
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENTERPRISE_DIR="${REPO_ROOT}/deploy/k8s/base/apps/enterprise"
FAILURES=0

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

echo "=== Redis DB Allocation Verification ==="
echo ""

# Collect all (service, db) pairs from CACHE_LOCATION and celery vhost
declare -A cache_dbs
declare -A celery_dbs

for deploy_file in "${ENTERPRISE_DIR}"/*-deployment.yaml "${ENTERPRISE_DIR}"/workers/*-deployment.yaml; do
  [[ -f "$deploy_file" ]] || continue
  svc=$(basename "$deploy_file" -deployment.yaml)
  # Workers share Redis DB with parent service — normalize name
  svc="${svc%-worker}"

  # Extract cache Redis DB from env var or Python default
  cache_db=$(grep -oP "CACHE_LOCATION.*redis://redis:6379/\K\d+" "$deploy_file" | tail -1 || true)
  if [[ -n "$cache_db" ]]; then
    if [[ -n "${cache_dbs[$cache_db]:-}" && "${cache_dbs[$cache_db]}" != "$svc" ]]; then
      fail "Redis DB ${cache_db} collision: ${cache_dbs[$cache_db]} AND ${svc}"
    elif [[ -z "${cache_dbs[$cache_db]:-}" ]]; then
      cache_dbs[$cache_db]="$svc"
      pass "${svc}: cache DB ${cache_db}"
    fi
  fi

  # Extract celery vhost
  celery_vhost=$(grep -oP "CELERY_BROKER_VHOST.*['\"]?\K\d+" "$deploy_file" | tail -1 || true)
  if [[ -n "$celery_vhost" ]]; then
    if [[ -n "${celery_dbs[$celery_vhost]:-}" && "${celery_dbs[$celery_vhost]}" != "$svc" ]]; then
      fail "Redis celery vhost ${celery_vhost} collision: ${celery_dbs[$celery_vhost]} AND ${svc}"
    elif [[ -z "${celery_dbs[$celery_vhost]:-}" ]]; then
      celery_dbs[$celery_vhost]="$svc"
      pass "${svc}: celery vhost ${celery_vhost}"
    fi
  fi
done

# Also check purchase-gateway
pg_deploy="${REPO_ROOT}/deploy/k8s/base/apps/purchase-gateway/deployment.yaml"
if [[ -f "$pg_deploy" ]]; then
  pg_db=$(grep -oP "REDIS_URL.*redis://redis:6379/\K\d+" "$pg_deploy" | tail -1 || true)
  if [[ -n "$pg_db" ]]; then
    if [[ -n "${cache_dbs[$pg_db]:-}" ]]; then
      fail "Redis DB ${pg_db} collision: ${cache_dbs[$pg_db]} AND purchase-gateway"
    else
      pass "purchase-gateway: DB ${pg_db}"
    fi
  fi
fi

echo ""
echo "=== Allocation Map ==="
for db in $(echo "${!cache_dbs[@]}" | tr ' ' '\n' | sort -n); do
  echo "  DB ${db}: ${cache_dbs[$db]} (cache)"
done
for db in $(echo "${!celery_dbs[@]}" | tr ' ' '\n' | sort -n); do
  echo "  DB ${db}: ${celery_dbs[$db]} (celery)"
done

echo ""
echo "=== Results: ${FAILURES} failures ==="
if [[ $FAILURES -gt 0 ]]; then
  echo "VERDICT: FAIL"
  exit 1
fi
echo "VERDICT: PASS"
exit 0
