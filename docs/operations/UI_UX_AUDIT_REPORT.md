# Cross-MFE Multisite UX Consistency Audit

_Audience: Product + Engineering • Last updated: 2026-02-17_

## Audit Scope

| Domain | Brand | MFEs Covered |
|--------|-------|-------------|
| academyv2.mereka.io | Mereka Academy | All 11 MFEs |
| academy.biji-biji.com | Biji-Biji Academy | All 11 MFEs |
| skillourfuture.academy.mereka.io | Skill Our Future Academy | All 11 MFEs |

## Severity Taxonomy

| Severity | Definition | SLA |
|----------|-----------|-----|
| Critical | Broken functionality, data loss risk, or security issue | Fix before launch |
| High | Significant UX inconsistency affecting user trust | Fix within 1 sprint |
| Medium | Noticeable inconsistency but workaround exists | Fix within 2 sprints |
| Low | Minor cosmetic issue | Backlog |

## Audit Categories

### 1. Navigation Consistency
| # | Check | academyv2 | biji-biji | skillourfuture | Severity | Notes |
|---|-------|-----------|-----------|----------------|----------|-------|
| N-001 | Header brand logo matches domain | | | | | |
| N-002 | Footer variant matches domain | | | | | |
| N-003 | Nav links consistent across MFEs | | | | | |
| N-004 | Mobile nav hamburger works | | | | | |
| N-005 | Back navigation between MFEs | | | | | |

### 2. CTA Hierarchy
| # | Check | academyv2 | biji-biji | skillourfuture | Severity | Notes |
|---|-------|-----------|-----------|----------------|----------|-------|
| C-001 | Primary CTA uses brand primary color | | | | | |
| C-002 | Button styles consistent (border-radius: 999px) | | | | | |
| C-003 | Link colors match brand (info/teal) | | | | | |
| C-004 | Hover states work and use correct color | | | | | |

### 3. Spacing & Typography
| # | Check | academyv2 | biji-biji | skillourfuture | Severity | Notes |
|---|-------|-----------|-----------|----------------|----------|-------|
| T-001 | Body font is Poppins/Lato (not system default) | | | | | |
| T-002 | Heading font is Lato/Poppins | | | | | |
| T-003 | Font sizes consistent across MFEs | | | | | |
| T-004 | Line heights readable (>=1.5) | | | | | |
| T-005 | Card border-radius consistent (24px) | | | | | |

### 4. Cross-MFE Transitions
| # | Check | academyv2 | biji-biji | skillourfuture | Severity | Notes |
|---|-------|-----------|-----------|----------------|----------|-------|
| X-001 | Login → Dashboard transition smooth | | | | | |
| X-002 | Dashboard → Course player transition | | | | | |
| X-003 | Course → Discussions transition | | | | | |
| X-004 | Auth token persists across MFEs | | | | | |
| X-005 | No flash of unstyled content (FOUC) | | | | | |

### 5. Responsive Behavior
| # | Check | academyv2 | biji-biji | skillourfuture | Severity | Notes |
|---|-------|-----------|-----------|----------------|----------|-------|
| R-001 | Desktop layout (1280px) correct | | | | | |
| R-002 | Tablet layout (768px) correct | | | | | |
| R-003 | Mobile layout (375px) correct | | | | | |
| R-004 | Images scale properly | | | | | |

## Findings Summary

| Severity | Count | Fixed | Remaining |
|----------|-------|-------|-----------|
| Critical | 0 | 0 | 0 |
| High | 0 | 0 | 0 |
| Medium | 0 | 0 | 0 |
| Low | 0 | 0 | 0 |

## Quick Wins Delivered (AC-UIAUD-004)

_Target: At least 5 low-risk, high-impact fixes_

| # | Fix | File(s) | PR | Status |
|---|-----|---------|----|----|
| QW-001 | | | | PENDING |
| QW-002 | | | | PENDING |
| QW-003 | | | | PENDING |
| QW-004 | | | | PENDING |
| QW-005 | | | | PENDING |

## Implementation Backlog (AC-UIAUD-003)

| # | Finding | Severity | Owner | Effort | Bead |
|---|---------|----------|-------|--------|------|
| | | | | | |

## Related Documents
- **Design Tokens**: `infrastructure/tutor/themes/mereka/scss/_tokens.scss`
- **Paragon Alignment**: `docs/branding/PARAGON_TOKEN_ALIGNMENT.md`
- **Footer Mapping**: `docs/branding/FOOTER_V2_TO_LMS_MAPPING.md`
- **MFE-First Policy**: `docs/architecture/MFE_FIRST_POLICY.md`
- **Visual Regression**: `docs/operations/VISUAL_REGRESSION_RUNBOOK.md`
