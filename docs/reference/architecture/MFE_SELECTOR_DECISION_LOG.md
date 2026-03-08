# MFE Selector Override Decision Log

> Tracks temporary approvals for brittle DOM selector overrides. Each entry has
> an expiry date and remediation owner.

## Policy

- Selector overrides targeting MFE internals are **temporary by default**
- Each override MUST have an expiry date (max 90 days from approval)
- Expired entries must be migrated to plugin-slot or removed
- Review cadence: monthly (1st of each month)

## Active Overrides

| ID | Selector Pattern | File | Approved | Expiry | Owner | Replacement Target | Status |
|----|-----------------|------|----------|--------|-------|-------------------|--------|
| SEL-001 | `.pgn__footer *` | `mereka-overrides.css` | 2026-02-18 | 2026-05-18 | BoldBadger | `footer-slot` plugin | Active |
| SEL-002 | `.header-default *` | `mereka-overrides.css` | 2026-02-18 | 2026-05-18 | BoldBadger | `header-slot` plugin | Active |
| SEL-003 | `body` typography | `mereka-overrides.css` | 2026-02-18 | N/A | — | Stable (CSS custom properties) | Permanent |

## Expired / Migrated

| ID | Selector | Migrated To | Date |
|----|----------|-------------|------|
| (none yet) | | | |

## Review History

| Date | Reviewer | Action |
|------|----------|--------|
| 2026-02-18 | WhiteCliff | Initial log created from codebase scan |

## Verification

```bash
# Check for expired overrides (compare dates)
grep -E "^\| SEL-" docs/reference/architecture/MFE_SELECTOR_DECISION_LOG.md | \
  awk -F'|' '{print $6}' | while read expiry; do
    if [[ "$(date -d "$expiry" +%s 2>/dev/null)" -lt "$(date +%s)" ]]; then
      echo "EXPIRED: $expiry"
    fi
  done

# Cross-reference with override inventory
diff <(grep "SEL-" docs/reference/architecture/MFE_SELECTOR_DECISION_LOG.md | awk -F'|' '{print $3}' | sort) \
     <(grep -rn 'pgn__\|paragon' infrastructure/tutor/themes/ | cut -d: -f1 | sort -u)
```
