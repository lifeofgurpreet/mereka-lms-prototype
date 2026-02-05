# Current Cluster Status
_Last updated: 2026-02-05_

## Environments & Domains

### Production (GKE)
- **LMS**: https://academyv2.mereka.io
- **Studio**: https://studio.academyv2.mereka.io
- **MFE**: https://apps.academyv2.mereka.io
- **Discovery**: https://discovery.academyv2.mereka.io
- **Ecommerce**: https://ecommerce.academyv2.mereka.io
- **Credentials**: https://credentials.academyv2.mereka.io
- **Forum**: https://forum.academyv2.mereka.io
- **Notes**: https://notes.academyv2.mereka.io
- **Preview**: https://preview.academyv2.mereka.io

### Subsites (separate client microsites on the same LMS cluster)
- **Skill Our Future**: https://skillourfuture.academy.mereka.io
- **Biji-Biji**: https://academy.biji-biji.com

### Development (VPS kind)
- **LMS**: https://academyv2.mereka.dev
- **Studio**: https://studio.academyv2.mereka.dev
- **MFE**: https://apps.academyv2.mereka.dev
- **Discovery**: https://discovery.academyv2.mereka.dev
- **Ecommerce**: https://ecommerce.academyv2.mereka.dev
- **Credentials**: https://credentials.academyv2.mereka.dev
- **Forum**: https://forum.academyv2.mereka.dev
- **Notes**: https://notes.academyv2.mereka.dev
- **Preview**: https://preview.academyv2.mereka.dev

## Public Health Check Results (2026-02-05)
- LMS: **200**
- Studio: **200**
- Authn MFE: **200**
- Discovery: **200**
- Ecommerce: **200**
- Credentials: **200**
- Forum: **401** on `/health` (auth required)
- Notes: **200** on `/` (no dedicated `/health` endpoint)

## Cluster Snapshot (GKE)
- All core Open edX pods running: `lms` (2), `cms` (1), `lms-worker` (2), `cms-worker` (1),
  `mfe`, `caddy`, `discovery`, `ecommerce`, `credentials`, `forum`, `notes`, `mysql`,
  `redis`, `elasticsearch`, `smtp`, `xqueue`.

## Data State (prod)
- CourseOverview count: **0**
- Modulestore course count: **0**
- SQL backups exist in GCS: `gs://staging-academy-mereka-io-backup/sql/2025-12-13T180926Z/`

## Known Gaps
- Atlas backups not enabled (Atlas snapshots list is empty).
- Notes/Forum health endpoints need consistent 200 responses for monitoring.
