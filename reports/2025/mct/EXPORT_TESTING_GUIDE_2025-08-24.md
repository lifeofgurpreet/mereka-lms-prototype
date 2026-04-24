# MCT Export Script Testing Guide
_Audience: QA • Owner: Migration Squad • Last verified: 2025-08-24 • Status: historical_

This document preserves the historical export-test procedure used during the original MCT export validation. It is not part of the active migration operator hot path.

## Pre-Testing Checklist

### Script Readiness
- Export script created (`scripts/migrations/mct/mct-export.mjs`)
- Authentication pattern matched the working implementation
- Dry-run mode, validation, and summary reporting were implemented

### Authentication Setup

Use secure retrieval for active credentials. Do not record real client secrets in docs.

Required values:
- `MCT_BASE_URL`
- `MCT_CLIENT_ID`
- `MCT_CLIENT_SECRET`
- `MCT_TENANT_ID`
- `MCT_API_URI`

## Historical Test Flow

### 1. Dry run
```bash
MCT_BASE_URL=learn.skillourfuture.org \
node scripts/migrations/mct/mct-export.mjs --dry-run
```

### 2. Authentication check
```bash
MCT_BASE_URL=learn.skillourfuture.org \
MCT_API_URI=api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3 \
MCT_CLIENT_ID=<client-id> \
MCT_CLIENT_SECRET=<retrieve-from-secret-manager> \
MCT_TENANT_ID=<tenant-id> \
node scripts/migrations/mct/mct-export.mjs --dry-run
```

### 3. Small export
```bash
MCT_BASE_URL=learn.skillourfuture.org \
MCT_API_URI=api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3 \
MCT_CLIENT_ID=<client-id> \
MCT_CLIENT_SECRET=<retrieve-from-secret-manager> \
MCT_TENANT_ID=<tenant-id> \
node scripts/migrations/mct/mct-export.mjs \
  --resources organizations \
  --start-page 1 \
  --end-page 1
```

## Historical Notes

- This guide was written before the current migration-root rationalization.
- Current active export instructions live in [`../../../docs/ops/runbooks/migrations/mct/EXPORT_GUIDE.md`](../../../docs/ops/runbooks/migrations/mct/EXPORT_GUIDE.md).
- Historical output/results remain in archive/report surfaces.
