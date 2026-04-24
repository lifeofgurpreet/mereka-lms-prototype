# Branding Incident Template
_Use this for any production branding regression (missing logo/fonts, unbranded surfaces, stale CSS/image drift)._

## 1) Incident Summary

- Date/Time (UTC):
- Reporter:
- Impacted domains:
- Impacted surfaces (LMS/Studio/MFE/ecommerce/credentials/forum/microsites):
- User impact:

## 2) Detection

- Which gate detected it:
  - `scripts/branding/run-branding-gates.sh`
  - `scripts/qa/audit-branding-surfaces.sh`
  - Monitoring alert/manual report
- First failing signal:
- Earliest known good version:

## 3) Root Cause

- Drift vector:
  - stale `openedx` image
  - stale `openedx-mfe` image
  - missed `apply-patches.sh`
  - asset sync drift
  - GitOps ref mismatch
  - caching/CDN artifact mismatch
  - other:
- Technical root cause detail:

## 4) Immediate Fix

- Commands run:
- Artifacts updated (image tags, Git SHAs):
- Verification commands and outcomes:
  - `./scripts/branding/run-branding-gates.sh prod`
  - `BRANDING_LEVEL=deep ./scripts/qa/verify-public-branding.sh prod`

## 5) Prevention

- Which guardrail failed to prevent this:
- What check is being added/strengthened:
- Bead IDs created/updated:
- Doc updates made:

## 6) Follow-ups

- [ ] Action 1 (owner/date)
- [ ] Action 2 (owner/date)
