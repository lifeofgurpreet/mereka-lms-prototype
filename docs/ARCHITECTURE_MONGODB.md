# MongoDB Architecture (Reality + Target)
_Last updated: 2026-02-07_

This doc is intentionally opinionated and reality-first. Do not assume “Atlas-only” without verifying the live config.

## Current Reality (Production: GKE)

1. **Forum uses MongoDB Atlas** (`cs_comments_service`).
2. **LMS/CMS modulestore uses Atlas** (`openedx`) through `MONGODB_HOST` + Atlas-aware settings.
3. **In-cluster MongoDB in `mereka-lms` still exists and is not persistent**:
   - `Deployment/mongodb` mounts `/data/db` from `emptyDir` (ephemeral).

Implication:
- Active modulestore traffic is no longer on in-cluster MongoDB.
- Legacy in-cluster MongoDB must still be treated as risky infra until removed or PVC-backed.

## Target Architecture (Atlas-only)

- Forum: Atlas (`cs_comments_service`)
- Modulestore: Atlas (`openedx`)
- In-cluster MongoDB removed (or disabled) after cutover is verified.

## How To Verify What We’re Actually Using

### 1) Verify modulestore host (prod/dev)
```bash
./scripts/qa/course-data-sanity.sh --env prod
./scripts/qa/course-data-sanity.sh --env dev
```

You are looking for:
- `DOC_STORE_HOST mongodb+srv://...mongodb.net/...` means modulestore is Atlas (expected for prod).
- `DOC_STORE_HOST mongodb` means modulestore is in-cluster (drift/risk for production).

### 2) Verify in-cluster MongoDB persistence (prod)
```bash
kubectl -n mereka-lms get deploy mongodb -o jsonpath='{.spec.template.spec.volumes}'
```
If it contains `emptyDir`, it is ephemeral.

## Remaining High-Priority Fixes

1. **Retire legacy in-cluster MongoDB** after explicit backup + approval (preferred).
2. **Or make in-cluster MongoDB PVC-backed** if it must remain temporarily.
3. Keep `audit-velero` clean (`failures=0`) and treat any Atlas drift as a release blocker.

Guarded retirement helper (non-destructive by default):
```bash
./scripts/infra/retire-legacy-mongodb.sh
```

Destructive mode requires:
- runtime Atlas verification
- pre-op Velero backup
- explicit confirmation token

## Related Docs

- `docs/adr/001-mongodb-atlas.md` (decision record + cautions)
- `docs/operations/COURSE_DATA_RECOVERY.md` (recovery/import flow, now reality-first)
- `docs/operations/VELERO_BACKUP_AUDIT.md` (Velero posture, restore drill, and data-risk checks)
