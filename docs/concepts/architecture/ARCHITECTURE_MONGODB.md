# MongoDB Architecture (Reality + Target)
_Audience: Operations • Owner: Docs Team • Last verified: 2026-02-07 • Status: canonical_

This doc is intentionally opinionated and reality-first. Do not assume “Atlas-only” without verifying the live config.

## Current Reality (Production: GKE)

1. **Forum uses MongoDB Atlas** (`cs_comments_service`).
2. **LMS/CMS modulestore uses Atlas** (`openedx`) through `MONGODB_HOST` + Atlas-aware settings.
3. **Legacy in-cluster MongoDB deployment is retired in production**:
   - `Deployment/mongodb` has been deleted after backup + runtime Atlas verification.
   - `Service/mongodb` has been removed via `infrastructure` production overlay patching.

Implication:
- Active modulestore/forum traffic is Atlas-backed.
- Any reintroduction of in-cluster MongoDB in production is drift and should fail gates.

## Target Architecture (Atlas-only)

- Forum: Atlas (`cs_comments_service`)
- Modulestore: Atlas (`openedx`)
- In-cluster MongoDB deployment/service absent from production runtime.

## How To Verify What We’re Actually Using

### 1) Verify modulestore host (prod/dev)
```bash
./scripts/qa/course-data-sanity.sh --env prod
./scripts/qa/course-data-sanity.sh --env dev
```

You are looking for:
- `DOC_STORE_HOST mongodb+srv://...mongodb.net/...` means modulestore is Atlas (expected for prod).
- `DOC_STORE_HOST mongodb` means modulestore is in-cluster (drift/risk for production).

### 2) Verify legacy in-cluster MongoDB resources are absent (prod)
```bash
kubectl -n mereka-lms get deploy mongodb
kubectl -n mereka-lms get svc mongodb
```
Both commands should return `NotFound` after GitOps reconciliation.

## Remaining High-Priority Fixes

1. Keep `verify-atlas-modulestore-path` green with strict runtime checks.
2. Keep `audit-velero` clean (`failures=0`) and treat any Atlas drift as a release blocker.
3. Keep production overlay patch that deletes `Service/mongodb` in place.

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
