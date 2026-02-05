#!/usr/bin/env bash
# Export Cloud SQL databases to GCS.
set -euo pipefail

PROJECT=${PROJECT:-mereka-lms}
INSTANCE=${INSTANCE:-mereka-lms-mysql}
BUCKET=${BUCKET:-staging-academy-mereka-io-backup} # legacy bucket name used for production backups (no staging env)
STAMP=$(date -u +%Y-%m-%dT%H%M%SZ)
BASE_URI="gs://${BUCKET}/sql/${STAMP}"
DEFAULT_DATABASES=(openedx discovery ecommerce notes xqueue)

if [[ -n "${DATABASES:-}" ]]; then
  read -r -a DATABASES <<<"${DATABASES}"
else
  DATABASES=("${DEFAULT_DATABASES[@]}")
fi

mkdir -p /tmp/sql-backups >/dev/null 2>&1 || true

for db in "${DATABASES[@]}"; do
  DEST="${BASE_URI}/${db}.sql.gz"
  echo "Exporting ${db} -> ${DEST}"
  gcloud sql export sql "${INSTANCE}" "${DEST}" \
    --database="${db}" \
    --project="${PROJECT}" \
    --offload \
    --quiet
  echo "✔ ${db} export complete"
  echo
  # Respect API limits
  sleep 2
  done

echo "All exports stored under ${BASE_URI}"
