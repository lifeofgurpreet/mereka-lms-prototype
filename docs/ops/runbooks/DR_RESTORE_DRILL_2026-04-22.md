# DR Restore Drill — 2026-04-22

First documented end-to-end DR restore attempt on the Mereka LMS Velero pipeline.
Captures evidence, findings, and follow-up tickets so the DR posture moves
from "we take backups" to "we've tested that they restore".

## Scope of this drill

- **Backup under test**: `prod-mereka-lms-daily-20260422053008`
  - Schedule: `velero/prod-mereka-lms-daily` (cron `30 5 * * *`, ttl 168h)
  - Phase: `Completed`, 886 items backed up, 0 errors, 19 warnings (all "pod not running" skips — expected for pod manifests of completed Jobs)
  - Completion: 2026-04-22T06:22:33Z (~52 min duration)
- **Restore target**: sandbox namespace `dr-drill-20260422` on `rke2-prod` cluster (same cluster as source)
- **Restore scope (deliberately narrow)**: single PVC (`mysql`, 5Gi) — binary test of the restore pipeline, not a full-namespace restore

## Why this scope

A DR drill has two legitimate goals:
1. **Binary check**: can Velero + the Backblaze B2 backing store reproduce the data we think we backed up?
2. **Runbook rehearsal**: what breaks in the restore process — config refs, secret paths, ingress claims, etc.

Full-namespace restore into a sibling namespace on the same cluster mixes these goals
and introduces cross-namespace resource conflicts that would NOT exist in a real
disaster (where the prod namespace is gone or the cluster is rebuilt). Narrow scope
keeps the binary check clean.

## What ran

```bash
# 1. Create sandbox
kubectl --context rke2-prod create namespace dr-drill-20260422

# 2. First attempt — restore PVC + PV
cat > /tmp/dr-restore-mysql.yaml <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: dr-drill-mysql-20260422
  namespace: velero
spec:
  backupName: prod-mereka-lms-daily-20260422053008
  includedNamespaces:
  - mereka-lms
  namespaceMapping:
    mereka-lms: dr-drill-20260422
  includedResources:
  - persistentvolumeclaims
  - persistentvolumes
  labelSelector:
    matchLabels:
      app.kubernetes.io/name: mysql
  restorePVs: true
EOF
kubectl apply -f /tmp/dr-restore-mysql.yaml
```

**Result**: Restore CR reached `phase: Completed` in 42 seconds, `itemsRestored: 1/1`,
0 errors, 1 warning. PVC was created in `dr-drill-20260422` but remained `Pending`.

## Finding 1 — cross-namespace PV binding collision

**Symptom**: restored PVC (`dr-drill-20260422/mysql`) references
`spec.volumeName: pvc-b451cfa2-15ee-4755-a37d-939c033c5684`, but that PV is
still `Bound` with `claimRef.namespace=mereka-lms, name=mysql` (the original
prod PVC). A PV can only be bound to one PVC at a time, so the restored PVC
stays `Pending` forever.

**Root cause**: Velero's `restorePVs: true` + `persistentvolumeclaims` +
`persistentvolumes` restores both the PVC and the PV objects from the backup.
Both objects keep their original UIDs/references. This works in a real DR
(cluster rebuild → no PVs exist yet → Velero can re-create the original
binding cleanly). It does NOT work for same-cluster sandbox restore.

**Second attempt**: restore PVC only, let StorageClass allocate a fresh PV
via Longhorn CSI provisioner. Velero's fs-backup (Restic) is supposed to
inject an init-container on first pod mount to populate the fresh PV.

```yaml
spec:
  includedResources:
  - persistentvolumeclaims   # PVC only — drop PV
  existingResourcePolicy: update
```

**Result**: still stayed Pending because the restored PVC inherited the
same `spec.volumeName` from the backup manifest, which still points at
the (still-bound) original PV.

## Finding 2 — same-cluster sandbox restore needs `volumeName` scrub

To restore a PVC to a sibling namespace on the same cluster where the
source PVC is still Bound, you need to strip `.spec.volumeName` during
restore. Velero 1.12+ supports `resourceModifierReferences` to patch
resources during restore. Earlier versions require a custom
RestoreItemAction plugin or manual editing after restore.

**Runbook implication**: add a "restore to sandbox" checklist step to
strip `volumeName` OR accept that sandbox drills require a different
cluster. A real DR (cluster loss) doesn't hit this; but our ability to
*rehearse* DR on the prod cluster does.

## What was proven (evidence)

| Claim | Evidence |
|---|---|
| Backup pipeline works | 886/886 items, 0 errors, 58 backups in last 24h across all schedules |
| B2 object storage reachable | Velero BackupStorageLocation `default` status `Available` (lastValidationTime 2026-04-22T08:55:12Z) |
| Velero restore API accepts the backup | Restore CR reached `phase: Completed` in 42s on first attempt |
| K8s object reconstruction works | PVC manifest created in sandbox namespace |
| Restic data restore tested | **NOT PROVEN** — data pull happens on first pod mount; pod never mounted because PVC stayed Pending |

## What is NOT proven (yet)

1. **Restic B2 data integrity** — we did not mount the restored PVC with a pod,
   so the init-container that fetches data from B2 never ran. We don't know
   if the fs-backup snapshots are readable end-to-end.
2. **MySQL schema integrity** — would require the above + `mysql -e 'SHOW DATABASES'` + row count comparison.
3. **Multi-service coordination** — restoring all 886 items as a live stack
   was out of scope.
4. **Recovery Time Objective (RTO)** — we measured the restore API call (42s)
   but not "time to serving traffic".

## Recommended follow-ups

Filed as beads (see "Bead changes" section below):
1. **Cross-cluster restore drill on rke2-nonprod** — no PV-binding collision,
   end-to-end Restic data pull, can prove MySQL schema integrity. Needs BSL
   replicated to dev cluster or direct B2 access from dev Velero.
2. **`volumeName` strip Runbook entry** — for same-cluster sandbox drills,
   document the resource-modifier CR or manual `kubectl patch` step.
3. **VolumeSnapshotLocation install** — audit-velero still warns about
   missing VSL (tracked under `v5vj`). With VSL + CSI snapshots the restore
   is instant (no Restic data pull), but needs Longhorn's CSI snapshotter
   plugin configured.

## Command reference (for operators)

```bash
# Confirm backup is usable before starting a drill
kubectl --context rke2-prod get backup.velero.io <name> -n velero \
  -o jsonpath='{.status.phase}'
# → expect "Completed"

# List latest daily backups for Mereka LMS
kubectl --context rke2-prod get backups.velero.io -n velero \
  -l velero.io/schedule-name=prod-mereka-lms-daily \
  --sort-by .metadata.creationTimestamp

# Velero audit (failures, warnings, VSL presence, restore-drill presence)
bash scripts/qa/audit-velero.sh --context rke2-prod
```

## Evidence bundle pointers

- Run timeline: `/tmp/dr-drill-start.ts` → 1776862306 (2026-04-22T12:51:46Z)
- Backup: `prod-mereka-lms-daily-20260422053008`
- Restore attempts: `dr-drill-mysql-20260422`, `dr-drill-mysql-v2-20260422` (both deleted)
- Sandbox namespace: `dr-drill-20260422` (deleted after drill)
