# Backup Coverage Matrix & PVC Inventory Tooling - Status

**Date**: 2026-02-13
**Status**: COMPLETE

## Summary

Backup coverage matrix and PVC inventory tooling are fully operational and aligned with production reality.

## Deliverables Status

### ✓ Coverage Matrix
- **File**: `docs/reference/operations/BACKUP_COVERAGE_MATRIX.md`
- **Status**: Complete and reality-first
- **Coverage**:
  - In-cluster components (MySQL, Redis, Elasticsearch, Authentik, Infisical, n8n)
  - External/managed components (MongoDB Atlas, DNS, Container images)
  - Known gaps documented

### ✓ PVC Inventory Script
- **File**: `scripts/qa/list-critical-backup-pvcs.sh`
- **Features**:
  - Lists Bound PVCs covered by hourly critical schedule
  - Supports JSON and TSV output
  - Configurable context, namespace, and schedule name
- **Usage**: `./scripts/qa/list-critical-backup-pvcs.sh [--json]`

### ✓ Velero Audit Script
- **File**: `scripts/qa/audit-velero.sh`
- **Features**:
  - End-to-end backup posture audit
  - Validates schedule existence and recent backups
  - Checks volume snapshot counts
  - Surfaces silent failure modes
- **Usage**: `./scripts/qa/audit-velero.sh [--json]`

## Validation Evidence

Last validated: **2026-02-07**

```bash
./scripts/qa/audit-velero.sh
# Output: failures=0 warnings=0
```

### Current State
- Coverage matrix reflects prod state after MongoDB PVC retirement
- No orphan PVC/service warnings in production
- Hourly backup schedule actively snapshotting critical PVCs
- Volume snapshot counts match expected PVC inventory

## One-Command Posture Audit

```bash
./scripts/qa/audit-velero.sh --json | jq .
```

## Proof Commands

### List Bound PVCs
```bash
./scripts/qa/list-critical-backup-pvcs.sh
```

### Check Latest Hourly Backup
```bash
kubectl -n velero get backup -o json | jq -r '
  [.items[]
   | select(.metadata.labels["velero.io/schedule-name"]=="velero-local-hourly-critical-databases")
   | select(.status.phase=="Completed")]
  | sort_by(.status.completionTimestamp)
  | last
  | {name:.metadata.name, completed:.status.completionTimestamp, snapshots_completed:(.status.volumeSnapshotsCompleted//0)}
'
```

## References

- Coverage Matrix: `docs/reference/operations/BACKUP_COVERAGE_MATRIX.md`
- Velero DR Program: Bead `mereka-lms-1bj7`
- Spec: `specs/disaster-recovery-business-continuity_spec.md`
