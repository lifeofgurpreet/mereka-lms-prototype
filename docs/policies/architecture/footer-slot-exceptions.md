# Footer Slot Exception Register

> Canonical inventory of MFE footer fallback paths that cannot use the `footer.v1` plugin slot.
> Each exception has an ID, rationale, owner, expiry, and visual evidence requirements.
>
> **Bead**: mereka-lms-115d.21
> **AC**: AC-FTRX-001, AC-FTRX-002, AC-FTRX-004
> **Last updated**: 2026-02-18

## Exception Policy

All MFE footer customizations MUST use the `org.openedx.frontend.layout.footer.v1` plugin slot
via the `MerekaFooter` React component registered in `mereka_lms.py`.

Exceptions are granted ONLY when:
1. The MFE uses a separate build pipeline that does not process `env.config.jsx` plugin slots
2. The MFE is upstream-managed (e.g., enterprise portals) with no Mereka build customization
3. A documented alternative exists (e.g., runtime JS injection pending upstream support)

---

## Active Exceptions

### FTRX-EXC-001: Enterprise Admin Portal

| Field | Value |
|-------|-------|
| **MFE** | `frontend-app-admin-portal` |
| **Surface** | Enterprise admin dashboard |
| **Current footer** | Default Open edX footer (unbranded) |
| **Why no slot** | Enterprise MFEs use separate Docker images built from upstream edX repos. They load `enterprise-mfe-env.js` (runtime config) which does not process Tutor `env.config.jsx` plugin slots. No MerekaFooter injection point exists. |
| **Impact** | Admin-only surface, not learner-facing. Low brand impact. |
| **Owner** | Mereka platform team |
| **Filed** | 2026-02-18 |
| **Expires** | 2026-Q4 |
| **Resolution path** | When enterprise MFEs adopt the Frontend Plugin Framework (FPF), wire `MerekaFooter` via `footer.v1` slot in their `env.config.jsx`. Alternatively, inject a runtime footer script via `enterprise-mfe-env.js` if FPF adoption is delayed. |
| **Rollback** | N/A — currently shows default footer. No regression from current state. |

### FTRX-EXC-002: Enterprise Learner Portal

| Field | Value |
|-------|-------|
| **MFE** | `frontend-app-learner-portal-enterprise` |
| **Surface** | Enterprise learner course catalog |
| **Current footer** | Default Open edX footer (unbranded) |
| **Why no slot** | Same as FTRX-EXC-001 — enterprise MFE build pipeline does not process Tutor plugin slots. |
| **Impact** | Enterprise learner-facing. Moderate brand impact for enterprise tenants. |
| **Owner** | Mereka platform team |
| **Filed** | 2026-02-18 |
| **Expires** | 2026-Q4 |
| **Resolution path** | Same as FTRX-EXC-001. Priority is higher due to learner visibility. |
| **Rollback** | N/A — currently shows default footer. |

### FTRX-EXC-003: Studio (CMS) Footer

| Field | Value |
|-------|-------|
| **MFE** | Studio (CMS) — not an MFE, but Mako-rendered |
| **Surface** | Course authoring interface |
| **Current footer** | Minimal Mako footer (CMS default) |
| **Why no slot** | Studio uses Mako templates, not React MFEs. The `studio_footer.v1` slot exists but is not yet wired. |
| **Impact** | Author-only surface. Low brand impact. |
| **Owner** | Mereka frontend team |
| **Filed** | 2026-02-18 |
| **Expires** | 2026-Q4 |
| **Resolution path** | Wire `MerekaStudioFooter` variant via `studio_footer.v1` slot in `mereka_lms.py`. See MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md entry #10. |
| **Rollback** | N/A — CMS footer is not learner-facing. |

---

## Visual Evidence Pack

Visual evidence must be captured for each MFE to confirm footer slot compliance.

### Screenshot Naming Convention

```
var/evidence/footer-slots-YYYYMMDD/
  footer-learner-dashboard.png    # Learner dashboard footer
  footer-learning.png             # Course learning page footer
  footer-profile.png              # Profile page footer
  footer-account.png              # Account settings footer
  footer-authn.png                # Login/registration page footer
  footer-admin-portal.png         # Enterprise admin (exception)
  footer-learner-portal.png       # Enterprise learner portal (exception)
  footer-studio.png               # Studio CMS (exception)
```

### Evidence Capture Commands

```bash
# Automated evidence (for slot-compliant MFEs)
# These should show MerekaFooter with correct branding per SITE_VARIANTS

# learner-dashboard
curl -s https://apps.academyv2.mereka.io/learner-dashboard/ | grep -o 'mereka-footer[^"]*' | head -3

# learning (requires active course enrollment)
curl -s https://apps.academyv2.mereka.io/learning/ | grep -o 'mereka-footer[^"]*' | head -3

# profile
curl -s https://apps.academyv2.mereka.io/profile/ | grep -o 'mereka-footer[^"]*' | head -3

# account
curl -s https://apps.academyv2.mereka.io/account/ | grep -o 'mereka-footer[^"]*' | head -3

# authn
curl -s https://apps.academyv2.mereka.io/authn/login | grep -o 'mereka-footer[^"]*' | head -3
```

### Per-MFE Status

| MFE | Footer Source | Slot Compliant | Exception ID | Evidence |
|-----|-------------|----------------|--------------|----------|
| learner-dashboard | MerekaFooter (slot) | Yes | — | `footer-learner-dashboard.png` |
| learning | MerekaFooter (slot) | Yes | — | `footer-learning.png` |
| profile | MerekaFooter (slot) | Yes | — | `footer-profile.png` |
| account | MerekaFooter (slot) | Yes | — | `footer-account.png` |
| authn | MerekaFooter (slot) | Yes | — | `footer-authn.png` |
| admin-portal | Default Open edX | No | FTRX-EXC-001 | `footer-admin-portal.png` |
| learner-portal | Default Open edX | No | FTRX-EXC-002 | `footer-learner-portal.png` |
| Studio (CMS) | Mako template | No | FTRX-EXC-003 | `footer-studio.png` |

---

## Quarterly Maintenance Playbook

### Review Cadence

Footer fallback debt is reviewed every quarter (Q1, Q2, Q3, Q4) as part of the
MFE plugin-slot migration sprint.

### Quarterly Review Checklist

1. **Check upstream FPF adoption**: Have enterprise MFEs adopted the Frontend Plugin Framework?
   - If yes: wire `MerekaFooter` via `footer.v1` slot and retire exception
   - If no: renew exception with updated expiry (max 2 renewals, 18 months total)

2. **Run verification gates**:
   ```bash
   ./scripts/qa/verify-mfe-footer-fallbacks.sh
   ./scripts/qa/verify-footer-parity.sh
   ./scripts/qa/verify-footer-variant-matrix.sh
   ```

3. **Update evidence pack**: Capture fresh screenshots for all MFEs

4. **Review exception expiry dates**: Any exception past its expiry MUST be either:
   - Resolved (slot wired, exception removed)
   - Renewed with updated rationale and new expiry (requires team approval)
   - Escalated to platform lead if renewal limit (2) exceeded

5. **Update this register**: Remove resolved exceptions, update expiry dates

### Retirement Criteria

An exception can be retired (removed from this register) when:
1. The MFE footer renders `MerekaFooter` via plugin slot
2. `verify-mfe-footer-fallbacks.sh` passes without the exception ID
3. Visual evidence confirms correct branding on all tenant domains
4. The exception entry is moved to the "Retired Exceptions" section below

### Phase-Out Priority

| Exception | Priority | Phase-Out Path |
|-----------|----------|----------------|
| FTRX-EXC-002 (learner-portal) | HIGH | Learner-facing; first to migrate when enterprise FPF ready |
| FTRX-EXC-003 (Studio footer) | MEDIUM | `studio_footer.v1` slot available; needs component variant |
| FTRX-EXC-001 (admin-portal) | LOW | Admin-only; last priority |

---

## Retired Exceptions

_None yet._

---

## Related Documents

- `docs/reference/architecture/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md` — Full slot migration inventory
- `docs/guides/branding/PLUGIN_MIGRATION_SURVEY.md` — All override categories (not just footer)
- `docs/guides/branding/BRANDING_OPERATING_MODEL.md` — Exception policy with expiry
- `infrastructure/tutor/plugins/mereka_lms.py` — MerekaFooter component + PLUGIN_SLOTS wiring
- `docs/ops/runbooks/FRONTEND_REGRESSION_CHECKLIST.md` — Regression triage for footer issues
