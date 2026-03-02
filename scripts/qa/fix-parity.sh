#!/usr/bin/env bash
# Fix local/production parity issues.
set -euo pipefail

echo "=============================================================="
echo "Fixing Local/Production Parity Issues"
echo "=============================================================="
echo

export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate

# Check if cloud IP exists in local config.
if grep -q "10\.97\.0\." tutor_env/config.yml; then
  echo "Found cloud IPs in config:"
  grep "10\.97\.0\." tutor_env/config.yml | sed 's/^/  /'
  echo

  echo "1. Fixing Superset database host..."
  tutor config save --set ASPECTS_SUPERSET_DATABASE_HOST=clickhouse

  echo "2. Applying patches..."
  ./infrastructure/tutor/apply-patches.sh

  echo "3. Restarting Superset services..."
  tutor local restart superset superset-worker superset-worker-beat

  echo
  echo "Fixed. Verifying..."
  if grep -q "ASPECTS_SUPERSET_DATABASE_HOST: clickhouse" tutor_env/config.yml; then
    echo "  Superset database host set to: clickhouse"
  else
    echo "  Warning: Config may not have updated correctly"
  fi
else
  echo "No cloud IPs found in config"
fi

echo
echo "=== Final Verification ==="
echo "Checking for remaining cloud IPs..."
if grep -q "10\.97\.0\." tutor_env/config.yml; then
  echo "Still found cloud IPs:"
  grep "10\.97\.0\." tutor_env/config.yml | sed 's/^/  /'
else
  echo "No cloud IPs remaining"
fi

echo
echo "=============================================================="
echo "Parity Fix Complete"
echo "=============================================================="
echo
echo "Run ./scripts/qa/check-parity.sh to verify all issues are resolved"
