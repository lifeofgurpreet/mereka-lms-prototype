# Tenant Branding QA Runbook

> One-command verification of all tenant branding, footer variants, and token checks.
>
> **Bead**: mereka-lms-8jao.12
> **Last updated**: 2026-02-18

## Quick Start

```bash
./scripts/qa/run-tenant-branding-qa.sh
```

This runs **8 verification suites** in sequence and produces a consolidated summary table.

## Suites Executed

| # | Suite | Script | What It Checks |
|---|-------|--------|----------------|
| 1 | Analytics Key (8jao.1) | `verify-analytics-key.sh` | Segment key injection, sentinel guards, single source |
| 2 | Selector Hardening (8jao.3) | `verify-mfe-selector-hardening.sh` | data-testid coverage threshold, BRITTLE markers |
| 3 | Token Integrity (8jao.4) | `verify-branding-token-integrity.sh` | Token cross-reference, ink-600 gap, WCAG AA contrast |
| 4 | Plugin Slot Register (8jao.9) | `verify-plugin-slot-migration-register.sh` | Migration register completeness, no P0 open |
| 5 | Footer Variant Matrix (8jao.10) | `verify-footer-variant-matrix.sh` | SITE_VARIANTS coverage, field completeness, DRY |
| 6 | Tenant Branding Runtime | `verify-tenant-branding-runtime.sh` | Live endpoint checks per domain (needs network) |
| 7 | Branding Gates | `run-branding-gates.sh` | Full branding gate sweep (needs live cluster) |
| 8 | Multisite Governance | `run-multisite-governance-gates.sh` | Governance policy compliance |

## Interpreting Results

### Exit Codes
- **0**: All suites passed (WARNs are non-blocking)
- **1**: One or more suites had FAIL > 0

### WARN Taxonomy (non-blocking)

| Category | Meaning | Action |
|----------|---------|--------|
| `blocked-by-design` | Feature requires live cluster or external service | None — expected in CI/offline |
| `aspirational` | Documented but not yet implemented | Track in backlog |
| `config-drift` | Minor config difference, not a regression | Review at next deploy |

### Quick-Fix Table

| Failure | Likely Cause | Fix |
|---------|-------------|-----|
| Analytics Key sentinel | SEGMENT_KEY contains placeholder | Set real key in `MEREKA_SEGMENT_KEY` env var |
| Selector threshold below minimum | CSS selectors removed/renamed | Re-run `verify-mfe-selector-hardening.sh` to see which |
| Token cross-reference mismatch | Token added to `tokens.css` but not `_tokens.scss` | Sync token definitions across all 3 files |
| SITE_VARIANTS missing domain | New domain not added to MerekaFooter | Add to `SITE_VARIANTS` in `mereka_lms.py` |
| Branding gates live failures | Older image deployed, CSS not yet updated | Rebuild and deploy openedx image |
| Runtime check timeout | Network issue or endpoint down | Check cluster health first |

## When to Escalate

- **Token integrity FAIL**: Tokens are foundational — fix immediately
- **SITE_VARIANTS missing production domain**: Users see wrong brand — P0
- **>3 suites failing simultaneously**: Likely a config regression — check recent `tutor config save`

## References

- [FOOTER_VARIANT_MATRIX.md](FOOTER_VARIANT_MATRIX.md) — Per-domain footer config
- [MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md](MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md) — Slot migration status
- [MFE_SELECTOR_HARDENING_AUDIT.md](MFE_SELECTOR_HARDENING_AUDIT.md) — Selector risk matrix
- [TOKEN_INTEGRITY_REMEDIATION.md](TOKEN_INTEGRITY_REMEDIATION.md) — Token architecture
