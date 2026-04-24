# Architecture-Coupled Runbooks
_Audience: Operators • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This subroot holds operator procedures that implement architecture-sensitive frontend and runtime changes.

## Start here

- Need enterprise or MFE maintenance:
  - start with [`ENTERPRISE_MFE_MAINTENANCE.md`](ENTERPRISE_MFE_MAINTENANCE.md)
- Need footer-slot or selector migration work:
  - start with [`FOOTER_SLOT_MIGRATION.md`](FOOTER_SLOT_MIGRATION.md) or [`MFE_FOOTER_SLOT_MIGRATION.md`](MFE_FOOTER_SLOT_MIGRATION.md)
- Need token or runtime remediation:
  - start with [`TOKEN_DRIFT_REMEDIATION.md`](TOKEN_DRIFT_REMEDIATION.md) or [`TOKEN_INTEGRITY_REMEDIATION.md`](TOKEN_INTEGRITY_REMEDIATION.md)

## Runbooks in this subroot

- [`ENTERPRISE_MFE_MAINTENANCE.md`](ENTERPRISE_MFE_MAINTENANCE.md)
- [`FOOTER_SLOT_MIGRATION.md`](FOOTER_SLOT_MIGRATION.md)
- [`LEGACY_FOOTER_REMOVAL.md`](LEGACY_FOOTER_REMOVAL.md)
- [`MFE_FOOTER_SLOT_MIGRATION.md`](MFE_FOOTER_SLOT_MIGRATION.md)
- [`MFE_OAUTH_FIX_DEPLOYMENT.md`](MFE_OAUTH_FIX_DEPLOYMENT.md)
- [`MFE_ROUTING_PARITY.md`](MFE_ROUTING_PARITY.md)
- [`SUPERSET_DEPLOYMENT_RUNBOOK.md`](SUPERSET_DEPLOYMENT_RUNBOOK.md)
- [`TOKEN_DRIFT_REMEDIATION.md`](TOKEN_DRIFT_REMEDIATION.md)
- [`TOKEN_INTEGRITY_REMEDIATION.md`](TOKEN_INTEGRITY_REMEDIATION.md)

## What this subroot is not

Do not use this subroot for:
- architecture front doors, which belong in `docs/architecture/**`
- policy rules, which belong in `docs/policies/**`
- proof bundles, which belong in `docs/evidence/**`
- active reporting, which belongs in `docs/status/**`
