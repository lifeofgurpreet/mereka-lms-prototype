# Current Cluster Status
_Last updated: 2026-02-07_

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

## Public Health Check Results (2026-02-07)
- Command: `./scripts/qa/public-health-check.sh prod`
- Result: **All checks passed** (18/18)
- Key surfaces:
  - LMS/Studio/Authn MFE: `200`
  - Discovery/Credentials/Notes/Forum heartbeat: `200`
  - Ecommerce dashboard: `302` (expected login redirect)
  - Ecommerce Stripe webhook GET: `405` (expected POST-only endpoint)
  - Microsites (`skillourfuture`, `academy.biji-biji.com`, Biji Studio + MFE): `200`

## Cluster Snapshot (GKE)
- All core Open edX pods running: `lms` (2), `cms` (1), `lms-worker` (2), `cms-worker` (1),
  `mfe`, `caddy`, `discovery`, `ecommerce`, `credentials`, `forum`, `notes`, `mysql`,
  `redis`, `elasticsearch`, `smtp`, `xqueue`.
- Legacy `Deployment/mongodb` is retired in production.

## Data Plane State (prod)
- Atlas guard command:
  - `STRICT_RUNTIME=1 FAIL_ON_LEGACY_MONGODB=1 FAIL_ON_LEGACY_MONGODB_SERVICE=1 ./scripts/qa/verify-atlas-modulestore-path.sh --mode runtime`
- Result:
  - LMS/CMS modulestore host resolves Atlas (`*.mongodb.net`)
  - Legacy `Deployment/mongodb` absent
  - Legacy `Service/mongodb` absent

## Known Gaps
1. DR evidence process must remain monthly and reviewed (not just scripted).

## Canonical Verification Commands
```bash
./scripts/qa/public-health-check.sh prod
STRICT_RUNTIME=1 FAIL_ON_LEGACY_MONGODB=1 FAIL_ON_LEGACY_MONGODB_SERVICE=1 \
  ./scripts/qa/verify-atlas-modulestore-path.sh --mode runtime
./scripts/qa/audit-velero.sh
```
