# UI Parity Evidence — Lane B Checkpoint
> Timestamp: 2026-02-20T10:37-11:00Z
> Branch: feat/23ry2-spec-dedupe-normalize
> Commit: (see git log — this bundle committed with lane-b deliverables)
> Bead: 1kwf (Lane B)

## Gate Results (source-level)

| Script | Result |
|--------|--------|
| `verify-footer-parity.sh` | **38 PASS / 0 FAIL / 1 WARN** (accepted: Enterprise MFE) |
| `verify-mfe-footer-slot.sh` | **30 PASS / 0 FAIL / 0 WARN** |
| `verify-studio-authoring-branding.sh` | **0 failures** |
| `verify-public-branding.sh` | 9 failures — **ALL live-site, deployment-blocked** |

## Deliverables This Bundle

1. `verify-footer-parity.sh` — extended with AC-FTPAR-006 (positive allowlist):
   - LMS footer must have mereka.io link
   - LMS footer must have dynamic copyright year (ERE fix: `\(\)` literal parens)
   - LMS footer must NOT have hardcoded year
   - MFE MerekaFooter must have all 4 v2 zones
   - MFE footer legal zone must have copyright + legal links
   - CMS footer widget must have explicit brand content
   - WARN allowlist documented (WARN-001, WARN-002)

2. `BRANDING_OPERATOR_GUIDE.md` — new single-page operator navigation guide:
   - Decision tree (MFE vs LMS/CMS vs Tenant)
   - Surface reference table with file paths + update triggers
   - apply-patches.sh vs Plugin decision guide
   - Banned patterns table
   - Accepted warnings with resolution tracking

3. Route matrix refreshed — Studio status updated to "source-fixed, awaiting image build"

## Deployment Blockers (WhiteCliff lane)

| Blocker | Fix | State |
|---------|-----|-------|
| Studio footer "Powered by Open edX" live | `tutor images build openedx` → push → deploy | Template committed 113fde8 |
| MFE branding rev mismatch | Deploy image `1c66529-20260220023917` | ArgoCD sync pending (bz9p) |

## Accepted Gaps (not blockers)

| Gap | Owner Bead | Priority |
|-----|------------|----------|
| Enterprise MFE portals use Open edX default footer | backlog | P4 |
| LMS nav links Mereka-specific (not multi-tenant) | 2rcf | P2 |
| Studio single static footer (no per-tenant) | 3sxq | P3 backlog |
