#!/usr/bin/env bash
set -euo pipefail

# Aspects Analytics Environment Init
#
# Runs the full upstream Aspects init sequence for a given environment:
#   1. Create ClickHouse databases
#   2. Apply Tutor-rendered ConfigMaps
#   3. Run Alembic migrations + dbt models
#   4. Import Superset dashboards/charts/datasets
#   5. Backfill event_sink dimensional data
#
# Prerequisites:
#   - KUBECONFIG set and cluster accessible
#   - tutor-contrib-aspects installed: pip install tutor-contrib-aspects==3.0.3
#   - Tutor workspace configured: TUTOR_ROOT=.aspects-tutor-workspace
#   - ClickHouse, Superset, Ralph pods running in target namespace
#
# Usage:
#   ./scripts/aspects/init-aspects-env.sh --env dev
#   ./scripts/aspects/init-aspects-env.sh --env staging
#
# This script is idempotent — safe to re-run.

show_usage() {
  echo "Usage: $0 --env dev|staging"
  echo ""
  echo "Options:"
  echo "  --env dev       Target mereka-lms-dev namespace"
  echo "  --env staging   Target stg-mereka-lms namespace"
  echo "  --check         Dry-run: verify prerequisites only"
  exit 1
}

ENV_VALUE=""
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --env) ENV_VALUE="$2"; shift 2 ;;
    --check) CHECK_ONLY=true; shift ;;
    *) show_usage ;;
  esac
done

[[ -z "$ENV_VALUE" ]] && show_usage

case "$ENV_VALUE" in
  dev)     NS="mereka-lms-dev" ;;
  staging) NS="stg-mereka-lms" ;;
  *)       echo "ERROR: Unknown env '$ENV_VALUE'. Use 'dev' or 'staging'."; exit 1 ;;
esac

TUTOR_ROOT="${TUTOR_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)/.aspects-tutor-workspace}"

echo "============================================"
echo "Aspects Init: ${ENV_VALUE} (ns: ${NS})"
echo "Tutor workspace: ${TUTOR_ROOT}"
echo "============================================"

# Prerequisite checks
echo ""
echo "[1/6] Checking prerequisites..."
kubectl get ns "${NS}" > /dev/null 2>&1 || { echo "FAIL: Namespace ${NS} not found"; exit 1; }
kubectl get deployment clickhouse -n "${NS}" > /dev/null 2>&1 || { echo "FAIL: ClickHouse not running"; exit 1; }
kubectl get deployment superset -n "${NS}" > /dev/null 2>&1 || { echo "FAIL: Superset not running"; exit 1; }
kubectl get deployment ralph -n "${NS}" > /dev/null 2>&1 || { echo "FAIL: Ralph not running"; exit 1; }
[[ -f "${TUTOR_ROOT}/config.yml" ]] || { echo "FAIL: Tutor workspace not found at ${TUTOR_ROOT}"; exit 1; }

CH_PW=$(kubectl get secret aspects-secrets -n "${NS}" -o jsonpath='{.data.clickhouse-password}' | base64 -d)
[[ -n "${CH_PW}" ]] || { echo "FAIL: Cannot read ClickHouse password from aspects-secrets"; exit 1; }

echo "  All prerequisites OK"
${CHECK_ONLY} && { echo "Dry-run complete."; exit 0; }

# Step 2: ClickHouse databases
echo ""
echo "[2/6] Creating ClickHouse databases..."
for DB in xapi event_sink reporting openedx; do
  kubectl exec -n "${NS}" deployment/clickhouse -- \
    clickhouse-client --user openedx --password "${CH_PW}" \
    --query "CREATE DATABASE IF NOT EXISTS ${DB}" 2>/dev/null
done
kubectl exec -n "${NS}" deployment/clickhouse -- \
  clickhouse-client --user openedx --password "${CH_PW}" \
  --query "ALTER USER openedx SETTINGS check_table_dependencies=0" 2>/dev/null || true
echo "  Databases: xapi, event_sink, reporting, openedx"

# Step 3: Alembic + dbt
echo ""
echo "[3/6] Running Alembic + dbt (this may take 2-3 minutes)..."
kubectl delete pod "aspects-init-${ENV_VALUE}" -n "${NS}" 2>/dev/null || true
kubectl run "aspects-init-${ENV_VALUE}" \
  --image=docker.io/edunext/aspects:3.0.3 \
  -n "${NS}" --restart=Never \
  --overrides="{
    \"spec\": {
      \"volumes\": [
        {\"name\": \"migrations\", \"configMap\": {\"name\": \"$(kubectl get cm -n "${NS}" -o name | grep aspects-migrations-[0-9a-z]*$ | head -1 | sed 's|configmap/||')\"}},
        {\"name\": \"alembic\", \"configMap\": {\"name\": \"$(kubectl get cm -n "${NS}" -o name | grep aspects-migrations-alembic-[0-9a-z]*$ | head -1 | sed 's|configmap/||')\"}},
        {\"name\": \"versions\", \"configMap\": {\"name\": \"$(kubectl get cm -n "${NS}" -o name | grep aspects-migrations-alembic-versions | head -1 | sed 's|configmap/||')\"}},
        {\"name\": \"scripts\", \"configMap\": {\"name\": \"$(kubectl get cm -n "${NS}" -o name | grep aspects-scripts | head -1 | sed 's|configmap/||')\"}},
        {\"name\": \"dbt-profile\", \"configMap\": {\"name\": \"$(kubectl get cm -n "${NS}" -o name | grep aspects-dbt | head -1 | sed 's|configmap/||')\"}}
      ],
      \"containers\": [{
        \"name\": \"aspects\",
        \"image\": \"docker.io/edunext/aspects:3.0.3\",
        \"command\": [\"bash\", \"-c\", \"pip install -q alembic clickhouse-connect dbt-core dbt-clickhouse && cd /tmp/migrations && alembic upgrade head && mkdir -p /root/.dbt && cp /tmp/dbt-profile/profiles.yml /root/.dbt/profiles.yml && cd /app/aspects-dbt && dbt run\"],
        \"volumeMounts\": [
          {\"name\": \"migrations\", \"mountPath\": \"/tmp/migrations\"},
          {\"name\": \"alembic\", \"mountPath\": \"/tmp/migrations/alembic\"},
          {\"name\": \"versions\", \"mountPath\": \"/tmp/migrations/alembic/versions\"},
          {\"name\": \"scripts\", \"mountPath\": \"/tmp/scripts\"},
          {\"name\": \"dbt-profile\", \"mountPath\": \"/tmp/dbt-profile\"}
        ]
      }]
    }
  }" 2>/dev/null

echo "  Waiting for completion..."
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded \
  "pod/aspects-init-${ENV_VALUE}" -n "${NS}" --timeout=300s 2>/dev/null || {
  echo "  WARNING: Pod did not complete successfully. Check logs:"
  echo "  kubectl logs -n ${NS} aspects-init-${ENV_VALUE}"
}
RESULT=$(kubectl logs -n "${NS}" "aspects-init-${ENV_VALUE}" --tail=3 2>/dev/null | tail -1)
echo "  ${RESULT}"
kubectl delete pod "aspects-init-${ENV_VALUE}" -n "${NS}" 2>/dev/null || true

# Step 4: Import Superset assets
echo ""
echo "[4/6] Importing Superset dashboards..."
SUPERSET_POD=$(kubectl get pods -n "${NS}" -l app.kubernetes.io/name=superset \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
SCRIPTS_DIR="${TUTOR_ROOT}/env/plugins/aspects/apps/superset/pythonpath"

kubectl cp "${SCRIPTS_DIR}/create_assets.py" "${NS}/${SUPERSET_POD}:/tmp/create_assets.py" -c superset 2>/dev/null
kubectl cp "${SCRIPTS_DIR}/assets.yaml" "${NS}/${SUPERSET_POD}:/tmp/assets.yaml" -c superset 2>/dev/null
kubectl cp "${SCRIPTS_DIR}/aspects_asset_list.yaml" "${NS}/${SUPERSET_POD}:/tmp/aspects_asset_list.yaml" -c superset 2>/dev/null
kubectl cp "${SCRIPTS_DIR}/openedx/" "${NS}/${SUPERSET_POD}:/tmp/openedx/" -c superset 2>/dev/null

# Ensure admin user exists
kubectl exec -n "${NS}" deployment/superset -- python3 -c "
from superset.app import create_app; app = create_app()
with app.app_context():
    from superset.extensions import security_manager
    if not security_manager.find_user('y1iQD7k4elbC'):
        security_manager.add_user('y1iQD7k4elbC', 'Tutor', 'Admin', 'admin@aspects.openedx.org',
            security_manager.find_role('Admin'), password='admin')
" 2>/dev/null

# Prepare and import
kubectl exec -n "${NS}" deployment/superset -- bash -c '
sed "s|/app/assets|/tmp/assets|g; s|/app/pythonpath|/tmp|g" /tmp/create_assets.py > /tmp/create_assets_fixed.py
mkdir -p /tmp/assets/superset
date=$(date -u +"%Y-%m-%dT%H:%M:%S.%6N+00:00")
printf "version: 1.0.0\ntype: assets\ntimestamp: \"%s\"\n" "$date" > /tmp/assets/superset/metadata.yaml
export PYTHONPATH="/tmp:${PYTHONPATH}"
python3 -c "
import sys; sys.path.insert(0, \"/tmp\")
from pathlib import Path
from superset.app import create_app
app = create_app()
with app.test_request_context():
    from openedx.create_assets_utils import load_configs_from_directory
    load_configs_from_directory(Path(\"/tmp/assets/superset\"), overwrite=True, force_data=True)
    print(\"Dashboards imported successfully\")
" 2>&1 | tail -1
' 2>&1
echo "  Done"

# Step 5: Create ClickHouse users (for Superset connections)
echo ""
echo "[5/6] Ensuring ClickHouse users..."
for USER in ch_report ch_cms ch_lrs ch_vector; do
  kubectl exec -n "${NS}" deployment/clickhouse -- \
    clickhouse-client --user openedx --password "${CH_PW}" \
    --query "CREATE USER IF NOT EXISTS ${USER} IDENTIFIED WITH plaintext_password BY 'password' DEFAULT DATABASE event_sink" 2>/dev/null
  kubectl exec -n "${NS}" deployment/clickhouse -- \
    clickhouse-client --user openedx --password "${CH_PW}" \
    --query "GRANT ALL ON *.* TO ${USER}" 2>/dev/null
done
echo "  Users: ch_report, ch_cms, ch_lrs, ch_vector"

# Step 6: Backfill event_sink
echo ""
echo "[6/6] Backfilling event_sink data..."
LMS_POD=$(kubectl get pods -n "${NS}" -l app.kubernetes.io/name=lms \
  -o jsonpath='{.items[?(@.status.containerStatuses[0].ready==true)].metadata.name}' 2>/dev/null | awk '{print $1}')

if [[ -z "${LMS_POD}" ]]; then
  echo "  WARNING: No ready LMS pod found. Skipping backfill."
else
  for OBJ in course_overviews course_enrollment user_profile; do
    echo "  Dumping ${OBJ}..."
    kubectl exec -n "${NS}" "${LMS_POD}" -- python manage.py lms dump_data_to_clickhouse \
      --object "${OBJ}" --force --batch_size 10000 --sleep_time 0 \
      --url "http://clickhouse:8123" --username openedx --password "${CH_PW}" \
      --database event_sink 2>&1 | grep "Dumped" | tail -1 || echo "    (check LMS logs for errors)"
  done
fi

echo ""
echo "============================================"
echo "Init complete for ${ENV_VALUE}"
echo "============================================"
echo ""
echo "Verify:"
echo "  kubectl get pods -n ${NS} -l app.kubernetes.io/part-of=aspects"
echo "  curl -sk https://analytics.academyv2.mereka.dev/health  # (dev)"
echo "  curl -sk https://analytics.staging.academyv2.mereka.io/health  # (staging)"
