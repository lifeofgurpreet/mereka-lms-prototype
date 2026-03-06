#!/usr/bin/env bash
# data-retention-jobs.sh — generate and optionally apply K8s CronJob manifests
# for automated data retention enforcement across the Mereka Academy platform.
#
# This script GENERATES manifests into a directory; it does NOT delete data
# directly. Operators review and apply via:
#   kubectl apply -f /tmp/retention-jobs/
#   OR: this script --apply (applies generated manifests to the cluster)
#
# Scheduled jobs cover:
#   1. stripe_events cleanup       — delete rows older than 90 days (daily)
#   2. openedx_notifications       — delete rows older than 90 days (daily)
#   3. expired Django sessions     — flush from MySQL (daily)
#   4. retirement audit cleanup    — delete userretirementstatus rows >3 years (monthly)
#
# Loki log retention is enforced natively via limits_config.retention_period=720h.
# Velero backup TTL is set on the VolumeSnapshotClass / Schedule object (2160h = 90d).
# GCS backup lifecycle is configured via a GCS bucket lifecycle rule (age: 90).
# These are documented here for completeness but require no CronJob.
#
# Usage:
#   ./scripts/infra/data-retention-jobs.sh [--apply] [--namespace <ns>] [--dry-run]
#   NAMESPACE=mereka-lms \
#     CONFIRM_APPLY_DATA_RETENTION_JOBS=APPLY_DATA_RETENTION_JOBS \
#     ALLOW_PROD_APPLY=1 ./scripts/infra/data-retention-jobs.sh --apply
#
# Requirements:
#   - kubectl configured with access to target cluster (for --apply)
#   - MYSQL_SECRET env var pointing to the K8s secret that holds MySQL credentials
#     (defaults to openedx-secrets; must contain MYSQL_ROOT_PASSWORD or equivalent)
#   - PG_SECRET env var for PostgreSQL credentials (defaults to purchase-gateway-secrets)
#
# @covers AC-PRV-007, AC-PRV-008
# @spec: data-privacy-gdpr-compliance_spec.md

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

NAMESPACE="${NAMESPACE:-mereka-lms}"
MYSQL_SECRET="${MYSQL_SECRET:-openedx-secrets}"
PG_SECRET="${PG_SECRET:-purchase-gateway-secrets}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/retention-jobs}"
APPLY=0
DRY_RUN=0
K8S_CONTEXT="${K8S_CONTEXT:-}"
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-0}"
CREATE_PREOP_BACKUP="${CREATE_PREOP_BACKUP:-1}"
CONFIRM_APPLY_DATA_RETENTION_JOBS="${CONFIRM_APPLY_DATA_RETENTION_JOBS:-}"
CONFIRM_TOKEN="APPLY_DATA_RETENTION_JOBS"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --apply                 Apply generated manifests to the cluster via kubectl
  --context <ctx>         Kubernetes context override (default: current context)
  --namespace <ns>        Target namespace (default: mereka-lms)
  --dry-run               Print manifests to stdout instead of writing files
  --output-dir <dir>      Directory to write manifests (default: /tmp/retention-jobs)
  -h, --help              Show this help

Environment:
  NAMESPACE               Override --namespace
  MYSQL_SECRET            K8s secret with MySQL credentials (default: openedx-secrets)
  PG_SECRET               K8s secret with PostgreSQL credentials (default: purchase-gateway-secrets)
  OUTPUT_DIR              Override --output-dir
  K8S_CONTEXT             Default context override for --apply
  ALLOW_PROD_APPLY=1      Required for prod-like contexts when using --apply
  CREATE_PREOP_BACKUP=1   Default for prod-like contexts (Velero pre-op backup)
  CONFIRM_APPLY_DATA_RETENTION_JOBS=APPLY_DATA_RETENTION_JOBS
EOF
}

require_bool_01() {
  local var_name="$1"
  local value="$2"
  case "$value" in
    0|1) ;;
    *)
      echo "Invalid ${var_name}='${value}' (expected 0 or 1)" >&2
      exit 1
      ;;
  esac
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
}

is_prod_like_context() {
  local ctx="$1"
  [[ "$ctx" == *"gke_bbi-k8"* ]] || [[ "$ctx" == "prod" ]] || [[ "$ctx" == "production" ]] || [[ "$ctx" == "gke-prod" ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --context) K8S_CONTEXT="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --namespace) NAMESPACE="${2:-}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }
require_bool_01 "ALLOW_PROD_APPLY" "$ALLOW_PROD_APPLY"
require_bool_01 "CREATE_PREOP_BACKUP" "$CREATE_PREOP_BACKUP"

context_args=()
if [[ -n "${K8S_CONTEXT:-}" ]]; then
  context_args+=(--context "$K8S_CONTEXT")
fi

emit() {
  local name="$1"
  local manifest="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "---"
    echo "# $name"
    echo "$manifest"
  else
    mkdir -p "$OUTPUT_DIR"
    echo "$manifest" > "$OUTPUT_DIR/${name}.yaml"
    log "Written: $OUTPUT_DIR/${name}.yaml"
  fi
}

# ── Job 1: stripe_events cleanup (PostgreSQL) ─────────────────────────────────
# Deletes stripe_events rows older than 90 days.
# Schedule: 02:00 UTC daily.
# Purpose: stripe_events.payload_json may contain buyer email (PII); 90-day
# retention is the minimum audit window needed for Stripe dispute resolution.
# Reference: DATA_RETENTION_POLICY.md §3.4

STRIPE_EVENTS_JOB=$(cat <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: stripe-events-cleanup
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: stripe-events-cleanup
    app.kubernetes.io/component: data-retention
    app.kubernetes.io/managed-by: data-retention-jobs
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        metadata:
          labels:
            app.kubernetes.io/name: stripe-events-cleanup
        spec:
          restartPolicy: OnFailure
          containers:
            - name: cleanup
              image: postgres:16-alpine
              command:
                - sh
                - -c
                - |
                  psql "\$DATABASE_URL" -c "
                    DELETE FROM stripe_events
                    WHERE created_at < NOW() - INTERVAL '90 days';
                  "
                  echo "stripe_events cleanup complete"
              env:
                - name: DATABASE_URL
                  valueFrom:
                    secretKeyRef:
                      name: ${PG_SECRET}
                      key: DATABASE_URL
              resources:
                requests:
                  cpu: 50m
                  memory: 64Mi
                limits:
                  cpu: 200m
                  memory: 128Mi
              securityContext:
                allowPrivilegeEscalation: false
                runAsNonRoot: true
                runAsUser: 999
                readOnlyRootFilesystem: true
                capabilities:
                  drop: ["ALL"]
          securityContext:
            seccompProfile:
              type: RuntimeDefault
EOF
)
emit "stripe-events-cleanup" "$STRIPE_EVENTS_JOB"

# ── Job 2: openedx_notifications cleanup (MySQL) ──────────────────────────────
# Deletes notification rows older than 90 days.
# Schedule: 03:00 UTC daily.
# Purpose: notifications contain user_id and notification content (BEHAVIORAL PII);
# 90 days is sufficient for any in-flight notification or support query window.
# Reference: DATA_RETENTION_POLICY.md §3.1

NOTIFICATIONS_JOB=$(cat <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: notifications-cleanup
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: notifications-cleanup
    app.kubernetes.io/component: data-retention
    app.kubernetes.io/managed-by: data-retention-jobs
spec:
  schedule: "0 3 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        metadata:
          labels:
            app.kubernetes.io/name: notifications-cleanup
        spec:
          restartPolicy: OnFailure
          containers:
            - name: cleanup
              image: mysql:8.0
              command:
                - sh
                - -c
                - |
                  mysql -h "\$MYSQL_HOST" -u "\$MYSQL_USER" -p"\$MYSQL_PASSWORD" "\$MYSQL_DATABASE" <<'SQL'
                    DELETE FROM openedx_notifications_notification
                    WHERE created < NOW() - INTERVAL 90 DAY;
                  SQL
                  echo "notifications cleanup complete"
              env:
                - name: MYSQL_HOST
                  valueFrom:
                    secretKeyRef:
                      name: ${MYSQL_SECRET}
                      key: MYSQL_HOST
                - name: MYSQL_USER
                  valueFrom:
                    secretKeyRef:
                      name: ${MYSQL_SECRET}
                      key: MYSQL_USER
                - name: MYSQL_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: ${MYSQL_SECRET}
                      key: MYSQL_PASSWORD
                - name: MYSQL_DATABASE
                  value: openedx
              resources:
                requests:
                  cpu: 50m
                  memory: 64Mi
                limits:
                  cpu: 200m
                  memory: 128Mi
              securityContext:
                allowPrivilegeEscalation: false
                runAsNonRoot: true
                runAsUser: 999
                readOnlyRootFilesystem: true
                capabilities:
                  drop: ["ALL"]
          securityContext:
            seccompProfile:
              type: RuntimeDefault
EOF
)
emit "notifications-cleanup" "$NOTIFICATIONS_JOB"

# ── Job 3: expired Django sessions flush (MySQL) ──────────────────────────────
# Runs Django's clearsessions management command to remove expired sessions.
# Schedule: 04:00 UTC daily.
# Purpose: sessions contain encrypted user_id blobs (DIRECT PII); expired sessions
# are functionally invalid and add unnecessary storage and PII exposure risk.
# Reference: DATA_RETENTION_POLICY.md §3.1

SESSIONS_JOB=$(cat <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: expired-sessions-cleanup
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: expired-sessions-cleanup
    app.kubernetes.io/component: data-retention
    app.kubernetes.io/managed-by: data-retention-jobs
spec:
  schedule: "0 4 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        metadata:
          labels:
            app.kubernetes.io/name: expired-sessions-cleanup
        spec:
          restartPolicy: OnFailure
          containers:
            - name: clearsessions
              image: "{{ DOCKER_IMAGE_OPENEDX }}"
              command:
                - python
                - manage.py
                - lms
                - clearsessions
              envFrom:
                - secretRef:
                    name: ${MYSQL_SECRET}
              resources:
                requests:
                  cpu: 100m
                  memory: 256Mi
                limits:
                  cpu: 500m
                  memory: 512Mi
              securityContext:
                allowPrivilegeEscalation: false
                runAsNonRoot: true
                readOnlyRootFilesystem: false
                capabilities:
                  drop: ["ALL"]
          securityContext:
            seccompProfile:
              type: RuntimeDefault
EOF
)
emit "expired-sessions-cleanup" "$SESSIONS_JOB"

# ── Job 4: retirement audit record cleanup (MySQL) ────────────────────────────
# Deletes user_api_userretirementstatus rows older than 3 years.
# Schedule: 02:00 UTC on the 1st of each month.
# Purpose: retirement status records contain original_username and original_email
# (DIRECT PII) retained as an audit trail. 3 years is the maximum audit window
# needed for any realistic GDPR / PDPA enforcement action.
# Reference: DATA_RETENTION_POLICY.md §3.1

RETIREMENT_AUDIT_JOB=$(cat <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: retirement-audit-cleanup
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: retirement-audit-cleanup
    app.kubernetes.io/component: data-retention
    app.kubernetes.io/managed-by: data-retention-jobs
spec:
  schedule: "0 2 1 * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 1
      template:
        metadata:
          labels:
            app.kubernetes.io/name: retirement-audit-cleanup
        spec:
          restartPolicy: OnFailure
          containers:
            - name: cleanup
              image: mysql:8.0
              command:
                - sh
                - -c
                - |
                  mysql -h "\$MYSQL_HOST" -u "\$MYSQL_USER" -p"\$MYSQL_PASSWORD" "\$MYSQL_DATABASE" <<'SQL'
                    DELETE FROM user_api_userretirementstatus
                    WHERE modified < NOW() - INTERVAL 3 YEAR
                      AND current_state = 'COMPLETE';
                  SQL
                  echo "retirement audit cleanup complete"
              env:
                - name: MYSQL_HOST
                  valueFrom:
                    secretKeyRef:
                      name: ${MYSQL_SECRET}
                      key: MYSQL_HOST
                - name: MYSQL_USER
                  valueFrom:
                    secretKeyRef:
                      name: ${MYSQL_SECRET}
                      key: MYSQL_USER
                - name: MYSQL_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: ${MYSQL_SECRET}
                      key: MYSQL_PASSWORD
                - name: MYSQL_DATABASE
                  value: openedx
              resources:
                requests:
                  cpu: 50m
                  memory: 64Mi
                limits:
                  cpu: 200m
                  memory: 128Mi
              securityContext:
                allowPrivilegeEscalation: false
                runAsNonRoot: true
                runAsUser: 999
                readOnlyRootFilesystem: true
                capabilities:
                  drop: ["ALL"]
          securityContext:
            seccompProfile:
              type: RuntimeDefault
EOF
)
emit "retirement-audit-cleanup" "$RETIREMENT_AUDIT_JOB"

# ── Non-CronJob retention mechanisms (documented here for completeness) ────────

log "---"
log "Additional retention mechanisms (not CronJob-managed):"
log ""
log "Loki log retention:"
log "  Configured in: infrastructure/monitoring/loki-config.yaml"
log "  Setting: limits_config.retention_period: 720h  (30 days)"
log "  Enforced by: Loki compactor running continuously inside the Loki pod"
log "  No CronJob required."
log ""
log "Velero backup expiry:"
log "  Configure TTL on each Velero Schedule object:"
log "    kubectl patch schedule <name> -n velero --type=merge \\"
log "      -p '{\"spec\":{\"template\":{\"ttl\":\"2160h0m0s\"}}}'"
log "  TTL 2160h = 90 days. Velero deletes expired backups automatically."
log "  No CronJob required."
log ""
log "GCS backup lifecycle:"
log "  Configure via GCS bucket lifecycle rule:"
log "    gsutil lifecycle set - gs://mereka-lms-backups <<'JSON'"
log "    {\"rule\": [{\"action\": {\"type\": \"Delete\"},"
log "               \"condition\": {\"age\": 90}}]}"
log "    JSON"
log "  Age is in days. GCS enforces this daily."
log "  No CronJob required."

# ── Apply if requested ────────────────────────────────────────────────────────

if [[ "$APPLY" -eq 1 ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "ERROR: --apply and --dry-run are mutually exclusive" >&2
    exit 1
  fi
  require_cmd kubectl
  effective_context="${K8S_CONTEXT:-$(kubectl config current-context 2>/dev/null || true)}"
  if [[ "$CONFIRM_APPLY_DATA_RETENTION_JOBS" != "$CONFIRM_TOKEN" ]]; then
    log "ERROR: Refusing --apply without explicit confirmation token. Set CONFIRM_APPLY_DATA_RETENTION_JOBS=${CONFIRM_TOKEN}" >&2
    exit 1
  fi
  if is_prod_like_context "$effective_context" && [[ "$ALLOW_PROD_APPLY" != "1" ]]; then
    log "ERROR: Refusing --apply on prod-like context '$effective_context' without ALLOW_PROD_APPLY=1" >&2
    exit 1
  fi
  if is_prod_like_context "$effective_context"; then
    if [[ "$CREATE_PREOP_BACKUP" == "1" ]]; then
      require_cmd velero
      backup_name="pre-op-${NAMESPACE}-data-retention-jobs-$(date -u +%Y%m%d-%H%M)"
      log "Creating Velero pre-op backup: $backup_name"
      velero backup create "$backup_name" --include-namespaces "$NAMESPACE" --wait
    else
      log "WARNING: CREATE_PREOP_BACKUP=0 on prod-like context '$effective_context' (operator override)"
    fi
  fi
  log "Applying manifests to namespace: $NAMESPACE (context=${effective_context:-default})"
  kubectl "${context_args[@]}" apply -f "$OUTPUT_DIR/"
  log "Applied. Verify with: kubectl get cronjobs -n $NAMESPACE -l app.kubernetes.io/component=data-retention"
else
  if [[ "$DRY_RUN" -eq 0 ]]; then
    log ""
    log "Manifests written to: $OUTPUT_DIR"
    log "Review and apply with:"
    log "  kubectl apply -f $OUTPUT_DIR/"
    log "Or re-run with: $0 --apply"
  fi
fi
