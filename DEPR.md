# Deprecation Register — Mereka LMS

Follows [OEP-21 Deprecation Process](https://open-edx-proposals.readthedocs.io/en/latest/processes/oep-0021-proc-deprecation.html).

## Process Summary

1. **Announce** — add entry here with target removal date, migration path, and owner.
2. **Communicate** — note in ADR or PR; add `[DEPRECATED]` comments in code.
3. **Remove** — after target date, open PR to delete. Reference this entry in the commit message.

---

## Active Deprecations

### DEPR-001 — Legacy Ecommerce (Oscar)

| Field | Value |
|-------|-------|
| **Status** | Active — transition period (dark-launch replacement deployed) |
| **Replacement** | Purchase Gateway (`services/purchase-gateway/`) |
| **Target removal** | 2026-Q3 (after `ENABLE_GATEWAY_FULFILLMENT=true` in production) |
| **Owner** | Platform team |
| **ADR** | `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md` |
| **Tracker** | AC-027, AC-028 in `specs/ecommerce-purchase-gateway_spec.md` |

**Migration notes**: Oscar Deployment, Service, Caddy routes, DNS records, LMS settings
(`ECOMMERCE_PUBLIC_URL_ROOT` etc.) and Oscar secrets all remain until cutover.
Run `scripts/infra/decommission-legacy-ecommerce.sh` to clean up post-cutover.
See `scripts/qa/verify-oscar-deprecation.sh` for live status.

---

### DEPR-002 — Legacy Content Libraries v1

| Field | Value |
|-------|-------|
| **Status** | Pending migration |
| **Replacement** | Content Libraries v2 (bundled in Open edX Ulmo) |
| **Target removal** | 2026-Q4 (after all course authors migrated to v2 UI) |
| **Owner** | Curriculum team + Platform team |
| **Tracker** | `specs/content-libraries-v2-baseline_spec.md` |

**Migration notes**: Authors must republish libraries using the v2 editor. v1 libraries remain
readable but new libraries must be created in v2. See `scripts/qa/verify-content-libraries-v2-baseline.sh`.

---

### DEPR-003 — `tools/` directory

| Field | Value |
|-------|-------|
| **Status** | Removed (tombstone only) |
| **Replacement** | `scripts/` (all sub-domains: infra, migrations, branding, analytics, qa) |
| **Removed** | 2025-Q4 |
| **Owner** | Platform team |

**Migration notes**: Directory is absent or contains only `README.md`. All active
tooling has been in `scripts/` since 2025-Q4. No action required.

---

### DEPR-004 — `ops/` directory

| Field | Value |
|-------|-------|
| **Status** | Removed (tombstone only) |
| **Replacement** | `infrastructure/` (IaC) and `scripts/` (automation) |
| **Removed** | 2025-Q4 |
| **Owner** | Platform team |

**Migration notes**: Directory is absent or contains only `README.md`. No action required.

---

### DEPR-005 — Legacy Courseware XModule Runtime

| Field | Value |
|-------|-------|
| **Status** | Deprecated upstream — Open edX Ulmo still ships both runtimes |
| **Replacement** | XBlock runtime (Learning Core) |
| **Target removal** | Follows Open edX upstream timeline (~Quince/Redwood cycle) |
| **Owner** | Platform team (upstream-driven) |

**Migration notes**: Course content already uses XBlock-compatible format. No active
XModule-only content identified. Monitor upstream OEP-58 for removal timeline.
See: https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0058-arch-xblock-learning-core.html

---

### DEPR-006 — `scripts/shared/_common.sh`

| Field | Value |
|-------|-------|
| **Status** | Removed |
| **Replacement** | `scripts/shared/setup-local.sh` and `scripts/shared/lib.sh` |
| **Removed** | 2025-Q3 |
| **Owner** | Platform team |

**Migration notes**: Shared utility functions were split into `lib.sh` (sourced by
`config.sh`) and `setup-local.sh`. No references to the old path remain in active
scripts. Note: `infrastructure/tutor/patches/_common.sh` is a separate active file —
it is NOT deprecated.

---

### DEPR-007 — Footer Slot Sibling Verifiers (4 scripts)

| Field | Value |
|-------|-------|
| **Status** | Deprecated |
| **Affects** | `verify-footer-slot-only.sh`, `verify-footer-slot-migration.sh`, `verify-mfe-footer-slot-migration.sh`, `verify-footer-slot-evidence-rollback.sh` |
| **Replacement** | `scripts/qa/verify-footer-parity.sh` (canonical gate, `criticality: release-blocking`) |
| **Target removal** | 2026-Q3 |
| **Owner** | Platform team |
| **Bead** | mereka-lms-1kwf.1 PR-B |

**Migration notes**: All four scripts were written during the footer plugin-slot migration
(2026-Q1). The migration is complete and stable. Their assertion surface is fully subsumed
by `verify-footer-parity.sh` which is the canonical footer parity gate. Scripts are archived
under `scripts/qa/deprecated/` and must not be referenced in CI or new verifiers.

---

## Completed Deprecations

| ID | Item | Removed | Replacement |
|----|------|---------|-------------|
| — | `ops/` directory | 2025-Q4 | `infrastructure/` + `scripts/` |
| — | `tools/` directory | 2025-Q4 | `scripts/` |
| — | `scripts/shared/_common.sh` | 2025-Q3 | `lib.sh` + `setup-local.sh` |
