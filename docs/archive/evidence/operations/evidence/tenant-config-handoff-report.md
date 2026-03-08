# Tenant Config Handoff Report

**Bead**: 31yg
**ACs**: AC-UI-601, AC-UI-602, AC-UI-603, AC-UI-604, AC-UI-605
**Date**: 2026-02-18
**Status**: Complete

---

## Summary

This report documents the evidence for the multi-tenant branding config handoff guide
introduced in bead 31yg. The guide formalises the handoff path for per-tenant branding
configuration, covering asset precedence, onboarding checklist, validation commands,
rollback procedures, and links to related subsystem docs.

**Primary artifact**: `docs/guides/branding/TENANT_CONFIG_HANDOFF.md`
**Verification script**: `scripts/qa/verify-tenant-config-handoff.sh`

---

## AC Pass/Fail Summary

| AC | Description | Result |
|----|-------------|--------|
| AC-UI-601 | Per-tenant precedence for assets, domains, and plugin overrides defined | PASS |
| AC-UI-602 | New-tenant onboarding checklist covers DNS/hostname and domain mapping verification | PASS |
| AC-UI-603 | Validation commands for tenant-specific branding and plugin config are present | PASS |
| AC-UI-604 | Rollback and recovery actions for tenant misconfiguration are documented | PASS |
| AC-UI-605 | Links to enterprise host and subsystem mappings docs are present | PASS |

All 5 ACs pass. Verification script: `scripts/qa/verify-tenant-config-handoff.sh`

---

## AC-UI-601: Per-Tenant Precedence

The handoff guide defines a three-layer asset resolution order:

1. Platform defaults (`assets/branding/tokens.css`, base theme)
2. Tenant base (`infrastructure/tutor/themes/mereka/`)
3. Domain-specific (`SITE_VARIANTS[hostname]` in `mereka_lms.py`)

The plugin override chain is documented from `mereka_lms.py` `PLUGIN_SLOTS` through
`MerekaFooter` reading `window.location.hostname` to look up the `SITE_VARIANTS` map.

Config files covered: `_tokens.scss`, `mereka_lms.py` (SITE_VARIANTS), `env.config.jsx`,
tenant ConfigMap at `deploy/k8s/base/apps/`.

---

## AC-UI-602: New Tenant Onboarding Checklist

The guide provides a 10-step onboarding checklist:

1. Register domain in DNS (Cloudflare)
2. Add hostname to Caddy/Ingress routing
3. Add `SITE_VARIANTS` entry in `mereka_lms.py`
4. Configure tenant-specific assets (logo, favicon, CSS variables)
5. Create/update tenant ConfigMap entry
6. Run `scripts/tenants/provision-tenant.sh`
7. Re-run `apply-patches.sh` and rebuild MFE
8. Verify domain resolves: `curl -sI https://<tenant-domain>`
9. Verify branding: check footer shows correct brand name
10. Screenshot review and signoff

Each step includes a verification command.

---

## AC-UI-603: Validation Commands

The guide's validation section includes:

- `curl -sI https://<tenant-domain> | head -5` — domain resolution check
- `grep '<tenant-domain>' infrastructure/tutor/plugins/mereka_lms.py` — SITE_VARIANTS check
- `./scripts/qa/verify-footer-slot-evidence-rollback.sh` — footer slot evidence check
- `./scripts/qa/verify-tenant-branding-contract.sh` — tenant branding contract
- `./scripts/qa/verify-brand-pack-schema.sh` — brand pack schema
- `./scripts/qa/verify-plugin-slot-wiring.sh` — plugin-slot wiring chain
- `./scripts/qa/verify-token-drift.sh` — token drift guard
- `./scripts/qa/verify-tenant-config-handoff.sh` — this guide's own verification

---

## AC-UI-604: Rollback and Recovery

Four rollback scenarios are documented:

1. **Misconfigured domain** — `git revert` the SITE_VARIANTS commit, re-run
   `apply-patches.sh`, rebuild MFE.
2. **Broken branding** — Default fallback brand (`Mereka Academy`) activates automatically
   when a hostname is not in `SITE_VARIANTS`.
3. **ConfigMap misconfiguration** — `kubectl rollout undo deployment/lms -n mereka-lms`
4. **Full plugin revert** — `git revert` the plugin commit + restart

The `try/except ImportError` + `_PLUGIN_SLOTS_AVAILABLE` guard in `mereka_lms.py` is
referenced as the safety net for slot-wiring failures.

---

## AC-UI-605: Enterprise Host and Subsystem Mappings

The guide links to:

- `docs/reference/operations/MULTITENANT_BRAND_PLATFORM.md`
- `docs/guides/branding/BRANDING_OPERATING_MODEL.md`
- `docs/guides/branding/TENANT_BRANDING_CONTRACT.md`
- `docs/guides/branding/TENANT_BRAND_PACK_SCHEMA.md`
- `docs/runbooks/architecture/LEGACY_FOOTER_REMOVAL.md`
- `docs/operations/MULTISITE.md`
- `docs/reference/operations/ENTERPRISE_MULTI_TENANCY_NAVIGATION.md`
- `infrastructure/tutor/plugins/mereka_lms.py`
- `deploy/k8s/base/apps/`

Enterprise hostname table covers `academyv2.mereka.io`, `academy.biji-biji.com`, and
`skillourfuture.academy.mereka.io`.

---

## Related Files

- `docs/guides/branding/TENANT_CONFIG_HANDOFF.md` — primary handoff guide
- `scripts/qa/verify-tenant-config-handoff.sh` — verification script
- `infrastructure/tutor/plugins/mereka_lms.py` — SITE_VARIANTS, PLUGIN_SLOTS, MerekaFooter
- `docs/archive/evidence/operations/evidence/footer-slot-evidence-rollback-report.md` — related rollback evidence (bead 2dcy.8)
