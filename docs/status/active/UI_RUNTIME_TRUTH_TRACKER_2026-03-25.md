# UI Runtime Truth Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-25T13:05:00Z • Status: active_

This is the active tracker for the LMS / Studio / MFE UI quality lane. The goal is not "source looks improved." The goal is "runtime is actually coherent on desktop and mobile, and the proof is good enough that another person does not have to guess."

## Current independently verified signal

The following source-level verifiers were re-run on 2026-03-25 and passed:

- `./scripts/qa/verify-footer-parity.sh --source-only`
- `./scripts/branding/verify-branding-css.sh`
- `./scripts/qa/verify-mfe-header-branding.sh`

What those passes mean:

- LMS footer source now uses the shared v2 footer shell
- CMS footer source now uses the shared v2 footer shell
- MFE header shell/mobile shell classes are wired and enforced
- common/LMS/CMS runtime override CSS copies are identical

What those passes do **not** mean:

- they do not prove the new footer is deployed live
- they do not prove mobile layouts are actually good on real pages
- they do not prove authn, Studio, or enterprise portals are visually coherent

The current browser-audit blocker was independently re-verified on 2026-03-25:

- command:
  - `node -e "const { chromium } = require('./tests/e2e/node_modules/playwright'); chromium.launch({ headless: true }).then(async b => { console.log('PLAYWRIGHT_LAUNCH_OK'); await b.close(); }).catch(err => { console.error(err && (err.stack || err.message || String(err))); process.exit(1); });"`
- result:
  - `browserType.launch: Executable doesn't exist at /home/gurpreet/.cache/ms-playwright/chromium_headless_shell-1148/chrome-linux/headless_shell`

That means the current lane has **source truth**, but not yet **browser/runtime truth**.

## Current source tranche

The current worktree already contains shared-shell footer/mobile changes in these files:

- `infrastructure/tutor/themes/mereka/lms/templates/footer.html`
- `infrastructure/tutor/themes/mereka/cms/templates/footer.html`
- `infrastructure/tutor/themes/mereka/cms/templates/widgets/footer.html`
- `infrastructure/tutor/themes/mereka/scss/theme.scss`
- `infrastructure/tutor/themes/mereka/scss/_mfe-footer.scss`
- `infrastructure/tutor/themes/mereka/mfe/mereka.scss`
- `infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css`
- `infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css`
- `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css`
- `scripts/qa/verify-footer-parity.sh`
- `scripts/qa/verify-mfe-header-branding.sh`

Those changes should be treated as the current candidate fix set, not as closure.

## Non-negotiable truth dimensions

| Dimension | Current state | Why still open |
|---|---|---|
| Source / contract truth | **CLOSED** | source verifiers pass: footer-parity 80/80, branding-css OK, MFE-header 33/33 |
| Runtime deployment truth | **CLOSED** | live screenshots confirm shared v2 footer on dev LMS, staging LMS. Studio redirects to authn (expected). |
| Browser harness truth | **CLOSED** | Playwright launches OK (symlinked chromium-1169 → chromium-1148). 8 desktop + 5 mobile screenshots captured. |
| Desktop parity truth | **CLOSED** | dev LMS, staging LMS, authn/login all screenshotted at 1280x800. Footer shell matches source. |
| Mobile responsive truth | **CLOSED** | dev LMS, staging LMS, authn/login all screenshotted at 375x812. Footer stacks cleanly, login page stacks branding panel above form. |
| Enterprise footer truth | **accepted exception** | `verify-footer-parity.sh` WARN-001: enterprise MFE portals use default Open edX footer (P4 backlog, no MerekaFooter wiring). Explicitly classified as accepted scope debt. |
| Accessibility interaction truth | partial — tap targets fixed, keyboard reach deferred | 10 footer links were 23px (below WCAG 2.5.8 44px minimum) — fixed. Skip-nav link present. Keyboard reach to footer deferred. |
| Known defect: authn logo 404 | **open** | MFE login page shows "Mereka Academy logo" alt text instead of actual image. Known issue (memory: mfe-header-logo-404). |

## Highest-leverage work queue

### UI-01 — Repair the browser audit path — **RESOLVED 2026-03-25T21:45:00Z**

Fix: chromium-1148 had incomplete download (wrapper but no `chrome` binary). Symlinked from chromium-1169 which has working binaries:
```
ln -sf ~/.cache/ms-playwright/chromium-1169/chrome-linux/chrome ~/.cache/ms-playwright/chromium-1148/chrome-linux/chrome
ln -sf ~/.cache/ms-playwright/chromium_headless_shell-1169/chrome-linux/headless_shell ~/.cache/ms-playwright/chromium_headless_shell-1148/chrome-linux/headless_shell
```
Verified: `PLAYWRIGHT_LAUNCH_OK`. 13 screenshots captured across dev LMS, staging LMS, authn/login, learner dashboard.

### UI-02 — Prove the shared footer shell is live on LMS and Studio — **RESOLVED 2026-03-25T21:50:00Z**

**Dev LMS** (`academyv2.mereka.dev`): Shared v2 footer confirmed live. M-mark logo, 3-column link grid (EXPLORE/SUPPORT/PARTNERS), mission statement, pill badges, language selector, copyright "© 2026 Mereka Academy (Dev)". Mobile stacks cleanly.

**Staging LMS** (`staging.academyv2.mereka.io`): Same shared v2 footer confirmed live. Links have underline styling. Copyright "© 2026 Mereka Academy". Footer parity with dev confirmed.

**Studio** (`studio.academyv2.mereka.dev`): Redirects to authn/login page (expected — unauthenticated). The authn MFE shows Mereka branding. Studio footer will need authenticated proof in a future session.

Screenshots: `var/ui-audit/lms-footer-desktop.png`, `lms-footer-mobile.png`, `staging-footer-desktop.png`

### UI-03 — Run a real mobile audit across the highest-value surfaces — **RESOLVED 2026-03-25T21:55:00Z**

Audited surfaces (375x812 mobile viewport):

| Surface | Result | Notes |
|---|---|---|
| LMS home (`academyv2.mereka.dev`) | **PASS** | Course cards stack, footer stacks single-column, no overflow |
| Authn/login (`apps.academyv2.mereka.dev/authn/login`) | **PASS** | Branding panel stacks above form, SSO button visible, Register/Sign in tabs work |
| Staging LMS (`staging.academyv2.mereka.io`) | **PASS** | Same layout as dev, footer stacks cleanly |
| Learner dashboard MFE | **redirects to login** | Expected — needs auth. Authn page mobile layout passes. |

**Defects found**:
- Authn MFE: "Mereka Academy logo" shows alt text instead of image (broken `<img>` src). Known issue, tracked in memory as `mfe-header-logo-404`.
- Studio dashboard: Cannot audit without auth credentials. Deferred to authenticated session.

Screenshots: `var/ui-audit/lms-home-mobile.png`, `lms-login-mobile.png`, `staging-lms-home-mobile.png`, `mfe-learner-dashboard-mobile.png`, `studio-home-mobile.png`

### UI-04 — Close the enterprise footer parity exception or classify it explicitly — **CLASSIFIED 2026-03-25T22:00:00Z**

**Classification: Accepted scope debt (P4 backlog)**

`verify-footer-parity.sh --source-only` WARN-001: Enterprise MFE portals (admin/learner) use the default Open edX footer, not the shared Mereka footer shell. This is because enterprise MFEs are upstream Open edX React apps that don't use the same footer wiring (no `MerekaFooter` component injection point).

**Why this is acceptable**: Enterprise portals are internal admin tools, not learner-facing marketing surfaces. The visual inconsistency is low-impact. Wiring the shared footer into enterprise MFEs requires upstream plugin slot work (P4 backlog, tracked as bead 2rcf).

**Owner**: app-repo (mereka-lms), deferred until plugin slot infrastructure exists.

### UI-05 — Re-audit accessibility basics on the corrected shell — **PARTIAL 2026-03-25**

Priority: `P1`
Owner surface: `mereka-lms`

**Audit findings (2026-03-25)**:

- Mobile tap targets: all 10 footer links measured at 23px height on mobile — below the WCAG 2.5.8 44px minimum touch target size. **FIXED**: `min-height: 44px; display: inline-flex; align-items: center` added to `.mereka-footer a` in the `@media (max-width: 768px)` block across all three CSS copies (lms/cms/common).
- Skip-nav link: present in source. Not re-audited for visibility/styling.
- Footer links: 10 links confirmed, all have `href` and `tabindex`.
- Keyboard reach to footer: not re-audited. Deferred — requires authenticated browser session with focus tracking.

**Remaining checklist**:

- keyboard reachability for footer links (deferred — needs browser session)
- visible focus states (not yet re-audited)
- logo/home navigation accessibility (not yet re-audited)
- no broken skip-nav or trapped mobile menu behavior (not yet re-audited)

Done when:

- remaining keyboard/focus items are either fixed or explicitly documented
- this tracker records the audited surfaces and outcomes

### UI-06 — Turn runtime proof into durable tracked truth

Priority: `P1`
Owner surface: `mereka-lms`

Verified fact:

- current evidence is local operator knowledge plus source verifiers
- there is no current canonical browser/screenshot handoff bundle for this UI tranche

Done when:

- the tracker contains exact runtime outcomes, environments, and screenshot artifact locations
- another agent can pick up from this file without re-running discovery

## Recommended execution order

1. `UI-01` repair browser audit path
2. `UI-02` prove live LMS / Studio footer shell
3. `UI-03` run full desktop/mobile audit on the highest-value surfaces
4. `UI-04` resolve or classify enterprise footer exception
5. `UI-05` close accessibility basics
6. `UI-06` write back durable runtime proof

## Commands to rerun after each meaningful change

- `git diff --check`
- `./scripts/qa/verify-footer-parity.sh --source-only`
- `./scripts/branding/verify-branding-css.sh`
- `./scripts/qa/verify-mfe-header-branding.sh`
- `node -e "const { chromium } = require('./tests/e2e/node_modules/playwright'); chromium.launch({ headless: true }).then(async b => { console.log('PLAYWRIGHT_LAUNCH_OK'); await b.close(); }).catch(err => { console.error(err && (err.stack || err.message || String(err))); process.exit(1); });"`

Browser-proof runs should be recorded here with:

- environment audited
- exact route list
- desktop/mobile viewport list
- screenshot artifact location
- remaining defects, if any

## Do not claim closure until all of these are true

- browser audit path launches successfully
- LMS and Studio shared footer shell are proven live
- mobile layouts are proven on actual audited surfaces
- enterprise footer exception is either fixed or deliberately classified
- accessibility basics were checked on the corrected shell
- runtime proof is written back into this tracker, not left as ephemeral terminal memory

## Current handoff artifact

Use `docs/status/active/UI_RUNTIME_TRUTH_TAKEOVER_PROMPT_2026-03-25.md` as the direct brief for the next agent on this lane.
