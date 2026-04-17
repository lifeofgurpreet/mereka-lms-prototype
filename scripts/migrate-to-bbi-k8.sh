#!/usr/bin/env bash
# DECOMMISSIONED: GKE (mereka-lms GCP project) was decommissioned and the migration
# to BBI-K8/RKE2 is complete. This script was the one-shot migration tool; running it
# again would target a dead source cluster. Retained for historical reference only.
#
set -euo pipefail

# Mereka-LMS Migration Script to BBI-K8
# This script helps migrate data from the standalone mereka-lms GCloud project
# to the BBI-K8 shared cluster.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
SOURCE_PROJECT="mereka-lms"
SOURCE_CLUSTER="mereka-lms"
SOURCE_ZONE="asia-southeast1"
SOURCE_NAMESPACE="mereka-lms"

TARGET_CONTEXT=""  # Set this to your BBI-K8 context
TARGET_NAMESPACE="mereka-lms"

BACKUP_DIR="$PROJECT_ROOT/var/migration-backup-$(date +%Y%m%d-%H%M%S)"

usage() {
    cat << EOF
Usage: $0 <command>

Commands:
    backup-mysql      Export MySQL databases from source Cloud SQL
    backup-mongodb    Export MongoDB databases from source Atlas
    restore-mysql     Import MySQL databases to BBI-K8
    restore-mongodb   Import MongoDB databases to BBI-K8
    reindex-es        Reindex Elasticsearch after migration
    verify            Run verification checks
    full              Run full migration (backup + restore + verify)

Options:
    --source-context  Kubernetes context for source cluster
    --target-context  Kubernetes context for BBI-K8 cluster
    --dry-run         Show what would be done without executing

Examples:
    $0 backup-mysql --source-context gke_mereka-lms_asia-southeast1_mereka-lms
    $0 restore-mysql --target-context bbi-k8-prod
    $0 full --source-context SOURCE --target-context TARGET
EOF
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing=()
    command -v kubectl &>/dev/null || missing+=("kubectl")
    command -v mysql &>/dev/null || missing+=("mysql client")
    command -v mongodump &>/dev/null || missing+=("mongodump")
    command -v mongorestore &>/dev/null || missing+=("mongorestore")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing prerequisites: ${missing[*]}"
        exit 1
    fi

    log_info "All prerequisites met"
}

backup_mysql() {
    log_info "Starting MySQL backup from source cluster..."

    mkdir -p "$BACKUP_DIR/mysql"

    # Get MySQL credentials from source cluster
    if [[ -n "$SOURCE_CONTEXT" ]]; then
        kubectl config use-context "$SOURCE_CONTEXT"
    fi

    # For Cloud SQL, we need the private IP and credentials
    # This assumes you've set up port forwarding or have direct access
    local MYSQL_HOST="${MYSQL_HOST:-10.97.0.2}"
    local MYSQL_PORT="${MYSQL_PORT:-3306}"
    local MYSQL_USER="${MYSQL_USER:-root}"
    local MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"

    if [[ -z "$MYSQL_PASSWORD" ]]; then
        log_warn "MYSQL_PASSWORD not set. Attempting to get from Kubernetes secret..."
        # Try to get password from K8s secret
        MYSQL_PASSWORD=$(kubectl get secret -n "$SOURCE_NAMESPACE" mysql-credentials -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "")
    fi

    if [[ -z "$MYSQL_PASSWORD" ]]; then
        log_error "Could not determine MySQL password. Set MYSQL_PASSWORD env var."
        exit 1
    fi

    local databases=("openedx" "discovery" "notes" "ecommerce" "xqueue")

    for db in "${databases[@]}"; do
        log_info "Backing up database: $db"
        mysqldump -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
            --single-transaction --routines --triggers \
            "$db" > "$BACKUP_DIR/mysql/${db}.sql"
    done

    log_info "MySQL backup complete: $BACKUP_DIR/mysql/"
}

backup_mongodb() {
    log_info "Starting MongoDB backup from source..."

    mkdir -p "$BACKUP_DIR/mongodb"

    # Get MongoDB URI from tutor config
    local MONGODB_URI="${MONGODB_URI:-}"

    if [[ -z "$MONGODB_URI" ]]; then
        if [[ -f "$PROJECT_ROOT/tutor_env/config.yml" ]]; then
            MONGODB_URI=$(grep "MONGODB_URI:" "$PROJECT_ROOT/tutor_env/config.yml" | awk '{print $2}' | tr -d '"')
        fi
    fi

    if [[ -z "$MONGODB_URI" || "$MONGODB_URI" == '""' ]]; then
        # Fall back to local MongoDB
        MONGODB_URI="mongodb://mongodb:27017"
        log_warn "Using local MongoDB URI: $MONGODB_URI"
    fi

    local databases=("edxapp" "cs_comments_service")

    for db in "${databases[@]}"; do
        log_info "Backing up MongoDB database: $db"
        mongodump --uri="$MONGODB_URI" --db="$db" --out="$BACKUP_DIR/mongodb/"
    done

    log_info "MongoDB backup complete: $BACKUP_DIR/mongodb/"
}

restore_mysql() {
    log_info "Restoring MySQL to BBI-K8 cluster..."

    if [[ -z "$TARGET_CONTEXT" ]]; then
        log_error "TARGET_CONTEXT not set. Use --target-context flag."
        exit 1
    fi

    kubectl config use-context "$TARGET_CONTEXT"

    # Find MySQL pod in target cluster
    local mysql_pod
    mysql_pod=$(kubectl get pod -n "$TARGET_NAMESPACE" -l app.kubernetes.io/name=mysql -o jsonpath='{.items[0].metadata.name}')

    if [[ -z "$mysql_pod" ]]; then
        log_error "MySQL pod not found in namespace $TARGET_NAMESPACE"
        exit 1
    fi

    log_info "Found MySQL pod: $mysql_pod"

    # Copy and restore each database
    for sql_file in "$BACKUP_DIR/mysql/"*.sql; do
        local db_name
        db_name=$(basename "$sql_file" .sql)
        log_info "Restoring database: $db_name"

        # Copy SQL file to pod
        kubectl cp "$sql_file" "$TARGET_NAMESPACE/$mysql_pod:/tmp/"

        # Create database if not exists and restore
        kubectl exec -n "$TARGET_NAMESPACE" "$mysql_pod" -- \
            mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $db_name;"

        kubectl exec -n "$TARGET_NAMESPACE" "$mysql_pod" -- \
            bash -c "mysql -u root -p'$MYSQL_ROOT_PASSWORD' $db_name < /tmp/$(basename "$sql_file")"

        # Cleanup
        kubectl exec -n "$TARGET_NAMESPACE" "$mysql_pod" -- rm "/tmp/$(basename "$sql_file")"
    done

    log_info "MySQL restore complete"
}

restore_mongodb() {
    log_info "Restoring MongoDB to BBI-K8 cluster..."

    if [[ -z "$TARGET_CONTEXT" ]]; then
        log_error "TARGET_CONTEXT not set. Use --target-context flag."
        exit 1
    fi

    kubectl config use-context "$TARGET_CONTEXT"

    # Find MongoDB pod
    local mongo_pod
    mongo_pod=$(kubectl get pod -n "$TARGET_NAMESPACE" -l app.kubernetes.io/name=mongodb -o jsonpath='{.items[0].metadata.name}')

    if [[ -z "$mongo_pod" ]]; then
        log_error "MongoDB pod not found in namespace $TARGET_NAMESPACE"
        exit 1
    fi

    log_info "Found MongoDB pod: $mongo_pod"

    # Copy backup directory to pod
    kubectl cp "$BACKUP_DIR/mongodb/" "$TARGET_NAMESPACE/$mongo_pod:/tmp/mongodb-restore/"

    # Restore
    kubectl exec -n "$TARGET_NAMESPACE" "$mongo_pod" -- \
        mongorestore /tmp/mongodb-restore/

    # Cleanup
    kubectl exec -n "$TARGET_NAMESPACE" "$mongo_pod" -- rm -rf /tmp/mongodb-restore

    log_info "MongoDB restore complete"
}

reindex_elasticsearch() {
    log_info "Reindexing Elasticsearch..."

    if [[ -z "$TARGET_CONTEXT" ]]; then
        log_error "TARGET_CONTEXT not set. Use --target-context flag."
        exit 1
    fi

    kubectl config use-context "$TARGET_CONTEXT"

    # Find LMS pod
    local lms_pod
    lms_pod=$(kubectl get pod -n "$TARGET_NAMESPACE" -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')

    if [[ -z "$lms_pod" ]]; then
        log_error "LMS pod not found in namespace $TARGET_NAMESPACE"
        exit 1
    fi

    log_info "Running reindex on pod: $lms_pod"

    kubectl exec -n "$TARGET_NAMESPACE" "$lms_pod" -- \
        ./manage.py lms reindex_course --setup --all

    log_info "Elasticsearch reindex complete"
}

verify_migration() {
    log_info "Running verification checks..."

    if [[ -z "$TARGET_CONTEXT" ]]; then
        log_error "TARGET_CONTEXT not set. Use --target-context flag."
        exit 1
    fi

    kubectl config use-context "$TARGET_CONTEXT"

    # Check all pods are running
    log_info "Checking pod status..."
    kubectl get pods -n "$TARGET_NAMESPACE"

    # Check services have endpoints
    log_info "Checking service endpoints..."
    kubectl get endpoints -n "$TARGET_NAMESPACE"

    # Test LMS health
    log_info "Testing LMS health..."
    local lms_pod
    lms_pod=$(kubectl get pod -n "$TARGET_NAMESPACE" -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -n "$TARGET_NAMESPACE" "$lms_pod" -- curl -s localhost:8000/heartbeat || log_warn "LMS heartbeat failed"

    # Test CMS health
    log_info "Testing CMS health..."
    local cms_pod
    cms_pod=$(kubectl get pod -n "$TARGET_NAMESPACE" -l app.kubernetes.io/name=cms -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -n "$TARGET_NAMESPACE" "$cms_pod" -- curl -s localhost:8000/heartbeat || log_warn "CMS heartbeat failed"

    log_info "Verification complete"
}

# Parse arguments
COMMAND=""
DRY_RUN=false
SOURCE_CONTEXT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        backup-mysql|backup-mongodb|restore-mysql|restore-mongodb|reindex-es|verify|full)
            COMMAND="$1"
            shift
            ;;
        --source-context)
            SOURCE_CONTEXT="$2"
            shift 2
            ;;
        --target-context)
            TARGET_CONTEXT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$COMMAND" ]]; then
    usage
    exit 1
fi

# Execute command
check_prerequisites

case "$COMMAND" in
    backup-mysql)
        backup_mysql
        ;;
    backup-mongodb)
        backup_mongodb
        ;;
    restore-mysql)
        restore_mysql
        ;;
    restore-mongodb)
        restore_mongodb
        ;;
    reindex-es)
        reindex_elasticsearch
        ;;
    verify)
        verify_migration
        ;;
    full)
        log_info "Running full migration..."
        backup_mysql
        backup_mongodb
        restore_mysql
        restore_mongodb
        reindex_elasticsearch
        verify_migration
        log_info "Full migration complete!"
        ;;
esac
