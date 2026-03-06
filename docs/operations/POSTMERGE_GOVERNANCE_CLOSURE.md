# Post-Merge Governance and Closure Evidence Pack

> **Bead**: mereka-lms-8jao.23
> **Last updated**: 2026-02-18
> **Status**: CLOSED — All 5 ACs verified (0 FAIL, 0 WARN)
> **Verifier**: `scripts/qa/verify-postmerge-governance-closure.sh`

---

## Table of Contents

1. [Child-Linked Issue Map (AC-POST-001)](#1-child-linked-issue-map-ac-post-001)
2. [Analytics and 4xx Flood-Check Evidence (AC-POST-002)](#2-analytics-and-4xx-flood-check-evidence-ac-post-002)
3. [Tenant-Branding Runtime and Build Contract (AC-POST-003)](#3-tenant-branding-runtime-and-build-contract-ac-post-003)
4. [Fallback Behavior Decision Log (AC-POST-004)](#4-fallback-behavior-decision-log-ac-post-004)
5. [2-Agent Execution Lock Guidance (AC-POST-005)](#5-2-agent-execution-lock-guidance-ac-post-005)
6. [Pass/Warn/Fail Summary](#6-passwarnfail-summary)

---

## 1. Child-Linked Issue Map (AC-POST-001)

### 8jao Bead Series — Master Issue Register

All beads in the 8jao series are child issues of the parent epic "Plugin-slot-first branding and selector hardening".

| Bead | Title | Status | Owner | Severity |
|------|-------|--------|-------|----------|
| 8jao.1 | MFE branding surfaces audit — baseline | CLOSED | Mereka platform team | Low |
| 8jao.2 | Token drift detection + CI gate | CLOSED | Mereka platform team | Medium |
| 8jao.3 | Selector hardening (data-testid primaries) | CLOSED | Mereka frontend team | High |
| 8jao.4 | Token integrity cross-check + contrast gate | CLOSED | Mereka frontend team | High |
| 8jao.5 | Footer slot migration — dual-path wiring | CLOSED | Mereka platform team | Critical |
| 8jao.6 | MFE route drift contract | CLOSED | Mereka frontend team | Medium |
| 8jao.7 | Multi-site UX consistency | CLOSED | Mereka frontend team | Medium |
| 8jao.8 | Footer parity (Mako + MFE) | CLOSED | Mereka frontend team | Medium |
| 8jao.9 | Plugin-slot migration register + DOM override inventory | CLOSED | Mereka platform team | High |
| 8jao.10 | Footer variant matrix — per-domain config | CLOSED | Mereka frontend team | Medium |
| 8jao.11 | MFE analytics plugin parity | CLOSED | Mereka frontend team | Medium |
| 8jao.12 | Tenant footer variant lane | CLOSED | Mereka platform team | High |
| 8jao.13 | Branding token integrity CI (cross-check gate) | CLOSED | Mereka platform team | High |
| 8jao.14 | MFE first policy verifier | CLOSED | Mereka frontend team | Medium |
| 8jao.15 | Interaction state contract (focus/hover) | CLOSED | Mereka frontend team | Low |
| 8jao.16 | Visual parity checkpoints | CLOSED | Mereka frontend team | Low |
| 8jao.17 | Multitenant brand platform verifier | CLOSED | Mereka platform team | High |
| 8jao.18 | Enterprise UI review gate | CLOSED | Mereka platform team | Medium |
| 8jao.19 | Footer slot-only policy + banned pattern gate | CLOSED | Mereka platform team | Critical |
| 8jao.20 | A11y contrast + focus gate | CLOSED | Mereka frontend team | High |
| 8jao.21 | UI-UX hardening bundle evidence | CLOSED | Mereka frontend team | Medium |
| 8jao.22 | Module surface validation | CLOSED | Mereka platform team | Medium |
| 8jao.23 | Post-merge governance and closure evidence pack | CLOSED | Mereka platform team | Low |

### Frontend/Branding Regression Inventory

Recurring regressions identified during the 8jao series. Each is assigned an owner and severity.

| Regression ID | Description | Root Cause | Owner | Severity | Resolved By |
|--------------|-------------|-----------|-------|----------|-------------|
| REG-001 | Footer reverts to Indigo default after `tutor config save` | apply-patches.sh not run after config save | Mereka platform team | Critical | FTRE-001 (registered fallback in apply-patches.sh) |
| REG-002 | `[class*="auth-page"]` selector becomes stale after authn MFE upgrade | authn MFE dropped the `auth-page` class | Mereka frontend team | High | Removed in bead 115d.18 (8jao.3); covered by `[class*="authn"]` primary |
| REG-003 | `[class*="discussion"]` (singular) over-matches non-forum elements | Selector too broad; MFE changed to plural | Mereka frontend team | Medium | Consolidated to `[class*="discussions"]` plural in bead 115d.18 |
| REG-004 | Segment key lowercased by template rendering layer | `.lower()` applied to key value in footer.html | Mereka platform team | High | Removed `.lower()` from extraction; guard uses `.lower()` for comparison only (8jao.11) |
| REG-005 | `undefined_license_key` sentinel appears in analytics calls | SEGMENT_KEY env var not set; sentinel not guarded | Mereka platform team | High | Sentinel guard added to footer.html (8jao.4/8jao.11) |
| REG-006 | Token drift: tokens.css updated but mereka-overrides.css not synced | No automated drift detection | Mereka platform team | Medium | `verify-token-drift.sh` CI gate added (8jao.2) |
| REG-007 | Studio footer shows Open edX default instead of Mereka footer | Studio uses Mako templates; plugin-slot not wired | Mereka frontend team | Low | Registered as exception FTRX-EXC-003; `studio_footer.v1` planned for 2026-Q4 |
| REG-008 | MFE branding revision marker missing after image rebuild without tag bump | Image rebuilt with same tag; CDN caches stale CSS | Mereka platform team | Medium | Branding rev marker added; image rebuild CI gate enforces tag bump |

---

## 2. Analytics and 4xx Flood-Check Evidence (AC-POST-002)

### Verification Scripts

| Script | Purpose | Last Result |
|--------|---------|-------------|
| `scripts/qa/verify-analytics-key.sh` | Confirms SEGMENT_KEY injection follows canonical path; no sentinel values | PASS (4 PASS, 1 SKIP) |
| `scripts/qa/verify-analytics-drift-guardrails.sh` | Ensures analytics config does not drift from source-of-truth settings | PASS |
| `scripts/qa/verify-analytics-decision-gate.sh` | Policy gate: Segment key must come from env, never hardcoded | PASS |

Run commands:

```bash
./scripts/qa/verify-analytics-key.sh
./scripts/qa/verify-analytics-drift-guardrails.sh
./scripts/qa/verify-analytics-decision-gate.sh
```

### 4xx Flood Evidence — Critical Surfaces

The following surfaces were checked for 4xx flood conditions on 2026-02-18. Checks are source-time (file/config content), not live-cluster checks, to remain CI-compatible.

| Surface | Check Type | Finding | Status |
|---------|-----------|---------|--------|
| Admin (`/admin/login/`) | Sentinel key guard in footer.html | `undefined_license_key` rejected by Jinja2 guard | PASS — no flood risk |
| Authn MFE (`/authn/login`) | SEGMENT_KEY injection path | Key sourced from `os.environ.get("MEREKA_SEGMENT_KEY")` via plugin; not lowercased | PASS |
| Ecommerce (`/ecommerce/`) | Non-canonical key references | No `ANALYTICS_SEGMENT_KEY` or `EDXAPP_SEGMENT_KEY` in footer.html | PASS |
| Studio (`/studio/`) | Studio-specific analytics | Studio uses Mako templates; Segment not injected in Studio (by design) | PASS — N/A |

### Token Sentinel Check Evidence

No hard-coded `undefined`, `none`, or `null` values for `SEGMENT_KEY` exist in:
- `infrastructure/tutor/plugins/mereka_lms.py`
- `infrastructure/tutor/themes/mereka/lms/templates/footer.html` (guard rejects sentinels)
- `infrastructure/tutor/themes/mereka/mfe/mereka.scss`

Verification command:

```bash
grep -rE 'SEGMENT_KEY\s*=\s*"(undefined|none|null|NONE|NULL)"' \
  infrastructure/tutor/plugins/ \
  infrastructure/tutor/themes/ \
  || echo "PASS: No sentinel values found"
```

Expected output: `PASS: No sentinel values found`

---

## 3. Tenant-Branding Runtime and Build Contract (AC-POST-003)

### Runtime Contract Verifier

The canonical runtime + build contract for tenant branding is verified by a suite of offline-capable scripts. These checks require no live cluster.

#### Run Commands

```bash
# Full offline contract check (recommended for CI)
./scripts/qa/verify-tenant-branding-contract.sh

# Runtime token and CSS contract
./scripts/qa/verify-tenant-branding-runtime.sh

# Branding matrix (which tenants have which overrides)
./scripts/qa/verify-tenant-branding-matrix.sh

# Footer variant per tenant/domain
./scripts/qa/verify-tenant-footer-variant-lane.sh

# Token drift (tokens.css vs theme files)
./scripts/branding/verify-token-drift.sh
```

#### Expected Outputs

| Script | Expected Output |
|--------|----------------|
| `verify-tenant-branding-contract.sh` | `0 FAIL` (WARNs acceptable for optional fields) |
| `verify-tenant-branding-runtime.sh` | `PASS: runtime contract met` or `0 FAIL` |
| `verify-tenant-branding-matrix.sh` | All known tenants listed with branding tier |
| `verify-tenant-footer-variant-lane.sh` | `footer_slot` wired for all production domains |
| `verify-token-drift.sh` | `0 drifted tokens` or `No drift detected` |

#### Build Contract

The build contract for tenant branding is:

1. `tokens.css` is the single source of truth for color/typography tokens.
2. `mereka-overrides.css` and `mereka.scss` must reference token values (not hardcoded hex).
3. After any `tutor config save`, run `infrastructure/tutor/apply-patches.sh`.
4. The branding revision marker (`--mereka-branding-rev`) must be bumped when CSS changes.

```bash
# Verify token consistency at build time
./scripts/qa/verify-design-tokens.sh
./scripts/qa/verify-token-definitions.sh
./scripts/qa/verify-token-reference-integrity.sh
```

Expected output for all three: `0 FAIL`

---

## 4. Fallback Behavior Decision Log (AC-POST-004)

### Purpose

This section documents all temporary fallback behaviors that operate outside the official plugin-slot path. Each entry has an expiry date and named owner. Any entry that reaches its expiry without renewal MUST be removed in the next sprint.

### Registered Fallback Exceptions

| Exception ID | File | Pattern | Rationale | Owner | Expiry | Rollback |
|-------------|------|---------|-----------|-------|--------|---------|
| `FTRE-001` | `infrastructure/tutor/apply-patches.sh` | `updated.replace("RenderWidget: <Footer />", "RenderWidget: <MerekaFooter />")` | Dual-path fallback for Tutor MFE versions where `tutormfe.hooks.PLUGIN_SLOTS` is not yet available. Swaps a JSX widget reference inside the existing plugin slot config — not raw HTML injection. | Mereka platform team | 2026-Q3 | Remove when all deployment targets run Tutor MFE ≥ version exposing `PLUGIN_SLOTS`. Set `_PLUGIN_SLOTS_AVAILABLE` guard to always-true. |
| `FTRE-002` | `infrastructure/tutor/apply-patches.sh` | `updated.replace("import Footer from '@edly-io/indigo-frontend-component-footer';\n", "")` | Removes the default Indigo footer import so `MerekaFooter` replaces it cleanly. Import-removal prevents the default from loading. | Mereka platform team | 2026-Q3 | Remove when Indigo template no longer imports the default footer, or when `PLUGIN_SLOTS keepDefault: False` suppresses it. |
| `FTRX-EXC-001` | Enterprise MFEs (admin-portal, learner-portal) | Separate build pipeline without plugin-slot support | Enterprise MFE builds do not expose `PLUGIN_SLOTS` in the same way as standard Tutor MFEs. Footer is handled via environment-specific config. | Mereka platform team | 2026-Q4 | When enterprise MFE build pipeline supports `PLUGIN_SLOTS`, wire `MerekaFooter` via slot. |
| `FTRX-EXC-002` | Enterprise learner-portal | Separate build pipeline — see above | Same rationale as EXC-001. | Mereka platform team | 2026-Q4 | Same as EXC-001. |
| `FTRX-EXC-003` | Studio CMS (`studio_footer.v1` slot not wired) | Mako template handles Studio footer; slot not wired | Studio uses Mako templates for footer, not React/MFE. `org.openedx.frontend.layout.studio_footer.v1` is available but not yet wired with `MerekaStudioFooter`. | Mereka frontend team | 2026-Q4 | Create `MerekaStudioFooter` component; wire via `studio_footer.v1` slot in `mereka_lms.py`. |
| `SEL-EXC-001` | `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | `[class*="learning"]` (11 rule blocks) | No upstream slot for learning MFE course grid layout. `ProgressCertificateStatusSlot` covers only certificate area. Filed as US7-TICKET-001. | Mereka / Upstream community | 2026-Q3 | File slot proposal for `org.openedx.frontend.learning.course_grid.v1`. Until approved, keep CSS with `SELECTOR-EXCEPTION` annotations. |
| `SEL-EXC-002` | `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | `[class*="discussions"]` (6 rule blocks) | No upstream slot for discussions MFE. P3/cosmetic rules only. Singular `[class*="discussion"]` eliminated in bead 115d.18. | Mereka frontend team | 2026-Q3 review | Monitor upstream discussions MFE for slot additions. Remove if upstream slot emerges. |

### Non-Plugin-Slot Paths: Summary

All non-plugin-slot paths are either:

1. **Registered exceptions** (FTRE-*, FTRX-EXC-*, SEL-EXC-*) — tracked above with expiry + owner.
2. **Stable Paragon BEM overrides** — library-controlled class names (`.pgn__card`, etc.), not subject to slot migration (P3/STABLE).
3. **Bootstrap/navbar CSS** — stable Bootstrap convention, low risk, tracked in migration register as P2.

See also:
- [`docs/operations/FOOTER_SLOT_ONLY_POLICY.md`](FOOTER_SLOT_ONLY_POLICY.md) — Full exception register for footer non-slot paths (FTRE-001, FTRE-002)
- [`docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`](MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md) — Full selector exception register (SEL-EXC-*)

### Exception Renewal Policy

- Exceptions must be reviewed at their expiry quarter.
- Renewal requires: (1) updated rationale, (2) updated expiry, (3) PR approval from platform lead.
- Expired exceptions not renewed must be removed within one sprint.
- The CI gate `verify-footer-slot-only.sh` emits WARN for registered exceptions and FAIL for unregistered non-slot-paths.

---

## 5. 2-Agent Execution Lock Guidance (AC-POST-005)

### Purpose

This section defines ownership boundaries to prevent parallel agent work from creating conflicts. Two agent roles are defined: **BoldBadger** (deploy/non-UI work) and **WhiteCliff** (UI/UX work). These names correspond to agent session identifiers used in the NTM orchestration system.

### Agent Domain Ownership

| Domain | Owner Agent | Agent Role | Owns |
|--------|-------------|-----------|------|
| Kubernetes manifests (`deploy/k8s/`) | BoldBadger | Deploy/infra | K8s YAML, kustomization, secrets, overlays |
| Tutor config + patches (`infrastructure/tutor/`) | BoldBadger | Deploy/infra | `apply-patches.sh`, `mereka_lms.py`, config templates |
| Runtime checks (`scripts/qa/verify-*.sh`) | BoldBadger | Deploy/infra | Verification scripts, CI gates, evidence bundles |
| Monitoring + alerting (`infrastructure/monitoring/`) | BoldBadger | Deploy/infra | PrometheusRules, Grafana dashboards, alert configs |
| UI/MFE theme files (`infrastructure/tutor/themes/`) | WhiteCliff | UI/UX | SCSS, branding tokens, MFE config, env.config.jsx |
| Runtime docs (`docs/operations/`) | WhiteCliff | UI/UX | Operations runbooks, policy docs, surface audits |
| Branding specs and registers (`docs/operations/MFE_*`, `FOOTER_*`) | WhiteCliff | UI/UX | Migration register, variant matrix, slot policy |
| Accessibility + contrast docs | WhiteCliff | UI/UX | A11y runbooks, WCAG gate docs |

### Execution Lock Rules

These rules prevent the two agents from clobbering each other's work when running in parallel:

#### Rule 1: Docs vs Checks Separation

- **BoldBadger** owns `scripts/qa/verify-*.sh` files (runtime checks).
- **WhiteCliff** owns `docs/operations/*.md` files (runtime docs).
- Neither agent should modify the other's primary file type without coordination.

**Conflict scenario**: BoldBadger adds a new verify script that adds a check for a policy doc. WhiteCliff updates the policy doc simultaneously. **Resolution**: BoldBadger creates the script; WhiteCliff updates the doc. Scripts reference docs by path. Docs describe what commands to run. No circular dependency.

#### Rule 2: apply-patches.sh is BoldBadger-Owned

`infrastructure/tutor/apply-patches.sh` is owned by BoldBadger. WhiteCliff must not modify it without an explicit coordination step. If WhiteCliff needs a new patch, it must:

1. File the patch requirement in `docs/ops/runbooks/BRANDING_RELEASE_RUNBOOK.md`
2. BoldBadger picks it up in the next deploy cycle and adds the patch

#### Rule 3: SCSS is WhiteCliff-Owned

`infrastructure/tutor/themes/mereka/mfe/mereka.scss` and `assets/branding/tokens.css` are owned by WhiteCliff. BoldBadger must not modify theme files. If a deploy-side change requires a theme update (e.g., new MFE endpoint requires new selector), BoldBadger documents the requirement in `docs/operations/` and WhiteCliff implements it.

#### Rule 4: Migration Register Lock

`docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md` is locked (LOCKED status as of Sprint S6, 2026-02-18). Any new entry requires:

1. PR from WhiteCliff (UI/UX owner) with full classification
2. CI gate `verify-migration-lock.sh` must pass
3. Explicit unlock comment from platform lead in the PR

#### Rule 5: Parallel Work Sequencing

When both agents are active on the same PR cycle:

```
Cycle start:
  1. BoldBadger: runs verification scripts, generates evidence artifacts
  2. WhiteCliff: updates docs, register, policy files
  3. Both: open PRs independently (no shared branch writes)
  4. BoldBadger: adds new verify script referencing WhiteCliff's updated docs
  5. WhiteCliff: updates doc to reference BoldBadger's new script path
  6. Final integration PR merges both (platform lead reviews)
```

#### Rule 6: Conflict Resolution Escalation

If a file is edited by both agents in the same cycle, the resolution order is:

1. **BoldBadger wins** on: `scripts/`, `deploy/k8s/`, `infrastructure/tutor/apply-patches.sh`, `infrastructure/tutor/plugins/`
2. **WhiteCliff wins** on: `docs/`, `assets/branding/`, `infrastructure/tutor/themes/`
3. **Platform lead arbitrates** on: `specs/`, `CLAUDE.md`, CI workflow files

### Quick Reference Card

```
BoldBadger (deploy/non-UI):
  OWNS: scripts/qa/verify-*.sh, deploy/k8s/, apply-patches.sh, mereka_lms.py
  WRITES: runtime checks, evidence bundles, CI gates, K8s manifests
  READS: docs/operations/ (for expected outputs and policies)

WhiteCliff (UI/UX):
  OWNS: docs/operations/, infrastructure/tutor/themes/, assets/branding/
  WRITES: runtime docs, SCSS, tokens, migration register, policy docs
  READS: scripts/qa/ (for command syntax and what to reference in docs)

SHARED (requires coordination):
  specs/, .github/workflows/ci.yml, CLAUDE.md
```

---

## 6. Pass/Warn/Fail Summary

### Verification Run (2026-02-18)

```bash
./scripts/qa/verify-postmerge-governance-closure.sh
```

| AC | Check | Result | Notes |
|----|-------|--------|-------|
| AC-POST-001 | Closure doc exists | PASS | `docs/operations/POSTMERGE_GOVERNANCE_CLOSURE.md` |
| AC-POST-001 | References 8jao series | PASS | All 23 beads listed |
| AC-POST-001 | Owner + Severity fields | PASS | Present in issue map and regression inventory |
| AC-POST-001 | Regression inventory | PASS | 8 regressions documented with root cause |
| AC-POST-002 | `verify-analytics-key.sh` exists | PASS | |
| AC-POST-002 | `verify-analytics-drift-guardrails.sh` exists | PASS | |
| AC-POST-002 | No `undefined` sentinel in plugin | PASS | |
| AC-POST-002 | No none/null sentinel in plugin | PASS | |
| AC-POST-002 | Analytics/4xx evidence in closure doc | PASS | Table with all 4 surfaces |
| AC-POST-003 | Runtime contract section in closure doc | PASS | Full run commands + expected outputs |
| AC-POST-003 | References `verify-tenant-branding-*` commands | PASS | |
| AC-POST-003 | Expected output examples present | PASS | `0 FAIL` examples for each script |
| AC-POST-003 | `verify-tenant-branding-runtime.sh` exists | PASS | |
| AC-POST-003 | `verify-tenant-branding-contract.sh` exists | PASS | |
| AC-POST-004 | `FOOTER_SLOT_ONLY_POLICY.md` exists | PASS | |
| AC-POST-004 | Exception Register section present | PASS | FTRE-001, FTRE-002 |
| AC-POST-004 | Expiry dates present | PASS | All entries have 2026-Q3 or 2026-Q4 |
| AC-POST-004 | Owner fields present | PASS | All entries have named owner |
| AC-POST-004 | Fallback section in closure doc | PASS | Full decision log with 7 exceptions |
| AC-POST-004 | Non-plugin-slot path references | PASS | FTRE-*, FTRX-EXC-*, SEL-EXC-* |
| AC-POST-005 | 2-agent execution lock in closure doc | PASS | BoldBadger + WhiteCliff defined |
| AC-POST-005 | Runtime docs vs checks ownership | PASS | Explicitly separated |
| AC-POST-005 | Agents named for each domain | PASS | Table with 8 domains |

**Summary**: 23 PASS, 0 FAIL, 0 WARN

### Next Actions

| Action | Owner | Due |
|--------|-------|-----|
| Review all `FTRE-*` and `FTRX-EXC-*` exceptions at expiry | Mereka platform team | 2026-Q3 end |
| Wire `MerekaStudioFooter` via `studio_footer.v1` slot | Mereka frontend team | 2026-Q4 |
| File upstream slot proposal for learning MFE course grid (`org.openedx.frontend.learning.course_grid.v1`) | Mereka / Upstream | 2026-Q3 |
| Phase authn branding to `login_component.v1` slot | Mereka frontend team | 2026-Q3 |
| Phase dashboard sidebar to `widget_sidebar.v1` slot | Mereka frontend team | 2026-Q3 |

---

## References

- [`docs/operations/FOOTER_SLOT_ONLY_POLICY.md`](FOOTER_SLOT_ONLY_POLICY.md) — Footer slot-only policy + exception register (FTRE-001, FTRE-002)
- [`docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`](MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md) — Full selector exception register + migration roadmap
- [`docs/operations/FOOTER_VARIANT_MATRIX.md`](FOOTER_VARIANT_MATRIX.md) — Per-domain footer configuration
- [`docs/operations/MFE_ANALYTICS_PLUGIN_PARITY.md`](MFE_ANALYTICS_PLUGIN_PARITY.md) — Analytics plugin parity across MFEs
- `scripts/qa/verify-postmerge-governance-closure.sh` — Automated verifier for this closure pack
- [`scripts/qa/verify-analytics-key.sh`](../../scripts/qa/verify-analytics-key.sh) — Analytics key injection verifier
- [`scripts/qa/verify-footer-slot-only.sh`](../../scripts/qa/verify-footer-slot-only.sh) — Footer slot-only policy gate
- [OEP-65: Frontend Plugin Framework](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0065-frontend-plugin-framework.html) — Upstream slot specification
