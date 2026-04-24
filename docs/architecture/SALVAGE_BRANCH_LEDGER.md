# Salvage Branch Ledger: fix/enterprise-mfe-theme-config

> **Status**: TRIAGE COMPLETE
> **Branch**: `fix/enterprise-mfe-theme-config` (PR #833)
> **Commits**: 14 ahead of main
> **Rule**: DO NOT merge wholesale. Land as scoped PRs per group.

## Commit Classification

### Group 1: JWT Fix (CRITICAL — land first)

| SHA | Subject | Status | Notes |
|-----|---------|--------|-------|
| `548b7fb6` | fix(lms): derive JWT public key from private key at startup | **KEEP** | Fixes enterprise login. Hardcoded public key `n` drifted from private key. |

**PR scope**: Single commit. Changes `production.py` only. Test: enterprise JWT verification works.

### Group 2: MFE Routing / Caddy (CRITICAL — land second)

| SHA | Subject | Status | Notes |
|-----|---------|--------|-------|
| `fe0d769f` | fix(mfe): route all MFE ingress traffic through Caddy | **KEEP** | RKE2 hostNetwork fix. Without this, MFE API calls 504. |
| `3830cbad` | fix(mfe): wrap profile API proxy in handle block | **KEEP** | Caddy directive ordering fix. |
| `2b58db40` | fix(mfe): route enterprise LMS API proxy with correct Host header | **KEEP** | Multi-tenant Host header for enterprise APIs. |
| `a126cd7d` | fix(caddy): route all MFE API calls through Caddy to LMS | **KEEP** | Consolidated MFE routing. May subsume #3 and #12. |

**PR scope**: Review #13 (`a126cd7d`) for overlap with #3 and #12. If consolidated, 2-3 commits.

### Group 3: Enterprise MFE Config

| SHA | Subject | Status | Notes |
|-----|---------|--------|-------|
| `9ce13f3e` | fix(enterprise-mfe): PARAGON_THEME, env.config.js, head-extra mount | **KEEP** | Foundational enterprise MFE theming. |
| `c101938f` | fix(enterprise-mfe): runtime domain rewrite for non-prod | **KEEP** | Multi-env MFE support. |
| `c0cb5ea5` | fix(enterprise-mfe): fix sed domain rewrite ordering bug | **KEEP** | Prevents subdomain corruption. |

**PR scope**: 3 commits together. Test: enterprise MFE env.config.js renders correct domains.

### Group 4: Theme / Branding CSS

| SHA | Subject | Status | Notes |
|-----|---------|--------|-------|
| `393810da` | fix(theme): complete Paragon CSS + course about/search fixes | **KEEP** | Theme CSS customizations. |
| `d066b22e` | fix(branding): sync common overrides CSS with LMS copy | **KEEP** | Consistent branding. |
| `d722dcda` | fix(branding): sync CMS overrides CSS with common copy | **KEEP** | Studio branding consistency. |
| `ceab0da4` | fix(authn): align hero logo with text and fix tab divider | **KEEP** | Authn UI alignment. |

**PR scope**: 4 commits together. Test: visual branding parity across LMS/CMS/MFEs.

### Group 5: MFE Plugin Framework

| SHA | Subject | Status | Notes |
|-----|---------|--------|-------|
| `79975d41` | fix(mfe): replace PLUGIN_OPERATIONS.Replace with Hide+Insert | **KEEP** | Future-proofs for frontend-plugin-framework upgrades. |

**PR scope**: Single commit. Test: MFE header/footer renders correctly.

### Group 6: CI

| SHA | Subject | Status | Notes |
|-----|---------|--------|-------|
| `0149a137` | fix(ci): handle no_new_privs flag blocking sudo on ARC runners | **KEEP** | ARC heavy builders need this. |

**PR scope**: Single commit. Test: CI heavy builder workflow succeeds.

## Landing Order

1. **Group 1** (JWT) — unblocks enterprise auth
2. **Group 2** (MFE routing) — unblocks MFE API calls on RKE2
3. **Group 3** (Enterprise MFE config) — unblocks enterprise portal theming
4. **Group 4** (Branding CSS) — visual parity
5. **Group 5** (Plugin framework) — future-proofing
6. **Group 6** (CI) — operational

## After All Groups Land

Close PR #833 as superseded. Delete `fix/enterprise-mfe-theme-config` branch.
