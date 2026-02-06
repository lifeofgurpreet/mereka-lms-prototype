# MongoDB Architecture (Reality + Target)
_Last updated: 2026-02-06_

This doc is intentionally opinionated and reality-first. Do not assume “Atlas-only” without verifying the live config.

## Current Reality (Production: GKE)

1. **Forum uses MongoDB Atlas** (`cs_comments_service`).
2. **LMS/CMS modulestore is currently configured to use in-cluster MongoDB** by default.
3. **In-cluster MongoDB in `mereka-lms` is not persistent today**:
   - `Deployment/mongodb` mounts `/data/db` from `emptyDir` (ephemeral).

Implication:
- If/when we import courses into modulestore while it is pointed at in-cluster MongoDB, course content will be lost on pod reschedule/restart.
- Treat “modulestore cutover” as a critical migration before any course import work.

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
- `DOC_STORE_HOST mongodb` means modulestore is in-cluster.
- `DOC_STORE_HOST mongodb+srv://...mongodb.net/...` means modulestore is Atlas.

### 2) Verify in-cluster MongoDB persistence (prod)
```bash
kubectl -n mereka-lms get deploy mongodb -o jsonpath='{.spec.template.spec.volumes}'
```
If it contains `emptyDir`, it is ephemeral.

## What To Fix (High Priority)

Choose one:

1. **Move modulestore to Atlas** (preferred, matches target architecture).
2. **Make in-cluster MongoDB persistent with a PVC** (acceptable as an interim step, but still operational burden).

Do not proceed with course imports until one of the above is done.

## Related Docs

- `docs/adr/001-mongodb-atlas.md` (decision record + cautions)
- `docs/operations/COURSE_DATA_RECOVERY.md` (recovery/import flow, now reality-first)
- `docs/operations/VELERO_BACKUP_AUDIT.md` (Velero posture, restore drill, and data-risk checks)

