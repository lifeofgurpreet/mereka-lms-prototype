# OEP-65 Module Architecture Readiness

**Tech Radar Document**

**Status**: Audit complete — Adopt with conditions
**Maintained as of**: 2026-02-25
**Depends on**: T108 ([MFE_RUNTIME_CONFIG.md](MFE_RUNTIME_CONFIG.md)), T109 ([TUTOR_PATCHES_INVENTORY.md](TUTOR_PATCHES_INVENTORY.md))

---

## What Is OEP-65?

[OEP-65](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0065-arch-frontend-composability.html)
(Open edX Proposal 65 — Frontend Composability) defines the community-endorsed architecture for
composable, independently deployable frontend modules in Open edX. It builds on top of the
existing Plugin Framework (OEP-50) and formalises the direction toward a "shell + remote modules"
model using Webpack Module Federation.

### Key OEP-65 Requirements

| Requirement | What it means in practice |
|-------------|--------------------------|
| **Shell-driven composition** | A single `frontend-base` shell application hosts all MFE content; individual apps become remote modules loaded at runtime. |
| **Module Federation** | Each MFE is a Webpack Module Federation remote, exposing a named entry point consumed by the shell. |
| **Plugin Slots as primary extension point** | All site-operator and theme customisation must use `@openedx/frontend-plugin-framework` slot injection. Direct code modification of upstream MFE source is deprecated. |
| **`env.config.jsx` is a shell concern** | Plugin slot wiring lives in the shell, not per-MFE. A single shared `env.config.jsx` is loaded once by the shell. |
| **Runtime-first configuration** | Build-time baking of environment-specific values (domains, feature flags) is explicitly discouraged. All tuneable config must be delivered via the `mfe_config` API. |
| **No fork, no patch** | Downstream deployments should not maintain patched copies of upstream MFE source. Customisation is limited to brand packages, plugin slots, and Tutor hooks. |

### Relationship to Prior OEPs

| OEP | Scope | Status |
|-----|-------|--------|
| OEP-50 (Micro-frontends) | Defined the MFE architecture and `env.config.jsx` | Adopted; Mereka compliant |
| OEP-65 (Frontend Composability) | Defines shell + Module Federation target state | Draft/Experimental as of Ulmo; adoption in progress upstream |

OEP-65 is not yet mandatory for Ulmo (release/ulmo). The upstream `frontend-base` shell is
available but not yet integrated by the standard Tutor MFE plugin. Adoption is voluntary and
incremental. The canonical tracking issue is
[openedx/frontend-base](https://github.com/openedx/frontend-base).

---

## Current Mereka MFE Architecture

### Deployment Shape

```
┌──────────────────────────────────────────────────────────────────────┐
│  Single Docker image (openedx-mfe)                                   │
│                                                                      │
│  Caddy (port 8002) serves /dist/<app-name>/ for each MFE            │
│                                                                      │
│  /dist/authn/         /dist/learning/        /dist/authoring/        │
│  /dist/account/       /dist/discussions/     /dist/gradebook/        │
│  /dist/profile/       /dist/learner-dashboard/ /dist/learner-record/ │
│  /dist/communications/ /dist/ora-grading/   /dist/admin-console/    │
└──────────────────────────────────────────────────────────────────────┘
```

Each MFE is a **self-contained Webpack bundle** — a completely independent React application.
There is no shared shell, no Module Federation, and no runtime module loading. Each app builds
its own React tree from scratch and includes its own copy of React and all shared libraries.

### Customisation Points Currently in Use

| Point | Mechanism | OEP-65 alignment |
|-------|-----------|-----------------|
| Footer replacement | `PLUGIN_SLOTS` + `mfe-env-config-runtime-definitions` ENV_PATCH | **Aligned** — slot-driven |
| Dark theme toggle | `PLUGIN_SLOTS` insert into `footer_slot` | **Aligned** — slot-driven |
| Mereka SCSS | `npm install @edx/brand` alias + `mereka.scss` COPY in Dockerfile | **Aligned** — brand package pattern |
| `@openedx/frontend-plugin-framework` | Installed at build time per MFE | **Aligned** — FPF is OEP-65 prerequisite |
| Cookie domains baked in image | `ARG SESSION_COOKIE_DOMAIN` / `ARG CSRF_COOKIE_DOMAIN` per MFE | **Not aligned** — should be runtime |
| `ENABLE_NEW_RELIC` build ARG | Per-MFE Docker `ARG ENABLE_NEW_RELIC=false` | **Not aligned** — should be runtime |
| `SITE_VARIANTS` hostname map | Hardcoded in `env.config.jsx` React component | **Not aligned** — tight coupling to domain list |
| Hardcoded footer nav/social links | Arrays in `env.config.jsx` component body | **Not aligned** — should be runtime config |
| `@edx/brand` package version | Pinned in Dockerfile (`@edly-io/indigo-brand-openedx@^2.4.3`) | **Aligned** — brand package pattern |
| Multi-stage Dockerfile surgery | `mfe-node.sh` + `build-optimizations.sh` regex patches | **Not aligned** — inhibits upstream adoption |
| Node 18 base image override | `mfe-node.sh` regex on Tutor-generated Dockerfile | **Not aligned** — forks the generated Dockerfile |
| Branch ref rewrites (ulmo) | `mfe-node.sh` changes `#open-release/redwood` to `#release/ulmo` | **Aligned** — tracks correct release; low risk |
| `--legacy-peer-deps` for FPF | Required by FPF ^1.8.0 peer dep conflicts | **Acceptable** — upstream FPF issue, not ours |

---

## Gap Analysis: Mereka vs OEP-65

### Gap 1 — No Shell / Module Federation (Blocking for Full Adoption)

**Current state**: Each MFE is a standalone Webpack bundle. The Caddy `try_files` pattern
serves each from its own sub-path.

**OEP-65 target**: A single `frontend-base` shell loads each MFE as a Webpack Module Federation
remote. The shell provides shared React, shared `@edx/frontend-platform`, and a single
`env.config.jsx`.

**Impact of gap**: Full OEP-65 adoption is not possible without this. However, OEP-65 does not
require all-or-nothing adoption. All downstream customisations currently using Plugin Slots will
transfer unchanged to the shell model. The gap is architectural, not in our customisation patterns.

**Upstream status**: `frontend-base` shell is available but the standard Tutor MFE plugin
(`tutor-contrib-mfe` / `tutormfe`) does not yet generate Module Federation remotes. Upstream
resolution is required before Mereka can adopt.

**Recommended action**: Track `openedx/frontend-base` releases. No Mereka-side spike needed
until Tutor MFE plugin integrates Module Federation.

---

### Gap 2 — Build-Time Domain Coupling (Actionable Now)

**Current state**: Every MFE bakes `SESSION_COOKIE_DOMAIN=.academyv2.mereka.io` and
`CSRF_COOKIE_DOMAIN=.academyv2.mereka.io` as Docker `ARG`/`ENV` in every `*-common` stage of
`infrastructure/tutor/mfe-build/Dockerfile` (12 occurrences).

**OEP-65 target**: All environment-specific config is runtime-delivered via `mfe_config` API.

**Impact**: The same image cannot be used for dev (`academyv2.mereka.dev`) and prod
(`academyv2.mereka.io`) without rebuild. A staging environment would require a third build.

**Fix** (T108 Phase 1): Remove the four `ARG`/`ENV` lines from each `*-common` stage. The
upstream `@edx/frontend-platform` reads `SESSION_COOKIE_DOMAIN` and `CSRF_COOKIE_DOMAIN` from
the `mfe_config` API response, where the LMS already serves correct values per
`SiteConfiguration`.

**Effort**: Low (12 occurrences, mechanical removal).

---

### Gap 3 — Dockerfile Surgery Inhibits Upstream Adoption (Medium Priority)

**Current state**: `mfe-node.sh` (334 LOC) applies regex surgery to the Tutor-generated MFE
Dockerfile to: change the base image to `node:24.11.0-bullseye-slim`, inject toolchain packages, add
cookie ARGs, add brand package installs, and rewrite branch refs. `build-optimizations.sh`
(686 LOC) further patches the openedx Dockerfile with positional insertions.

**OEP-65 impact**: When the upstream Tutor MFE plugin adopts Module Federation, the generated
Dockerfile structure will change significantly (new stages for remote builds, different `COPY`
patterns). Every regex in `mfe-node.sh` is an anchor on the current generated file structure.
Each structural change upstream breaks one or more regexes.

**OEP-65 target**: Customisations live in Tutor `ENV_PATCHES` (additive, append-only hooks),
not in regex surgery on generated files. The `mfe-dockerfile-pre-npm-install` and
`mfe-dockerfile-post-npm-install` hooks already exist for this purpose.

**What is already aligned**: The Tutor plugin (`mereka_lms.py`) already declares
`mfe-dockerfile-pre-npm-install`, `mfe-dockerfile-post-npm-install`, and
`mfe-dockerfile-npm-install` ENV_PATCHES covering toolchain, cookie env, and npm resilience.
The bash patches are belt-and-suspenders on rendered files.

**Fix path**: When Tutor MFE plugin adds Module Federation support, audit `mfe-node.sh` for
broken regexes. Migrate remaining bash operations to ENV_PATCHES where possible. The base image
selection and brand package installs are the most likely to break.

**Effort**: Medium when triggered by upstream change. No immediate action required.

---

### Gap 4 — `env.config.jsx` Contains Build-Time Hostname Coupling

**Current state**: `tutor_env/env/plugins/mfe/build/mfe/indigo/env.config.jsx` contains:

```jsx
const SITE_VARIANTS = {
  'academyv2.mereka.io': { brand: 'Mereka Academy', copyrightHolder: 'MEREKA', whatsapp: '...' },
  'academy.biji-biji.com': { brand: 'Biji-Biji Academy', ... },
  'skillourfuture.academy.mereka.io': { brand: 'Skill Our Future Academy', ... },
};
const variant = SITE_VARIANTS[hostname] || { brand: siteName, ... };
```

This hostname-keyed map is compiled into every MFE bundle. Adding a new tenant domain requires
a rebuild and redeploy of all 12 MFEs.

**OEP-65 target**: Per-site config is resolved by the LMS `SiteConfiguration` and delivered
via the `mfe_config` API. The shell (or individual MFE) reads a single `MEREKA_SITE_VARIANT`
config key — the LMS already knows which site is being served because the Caddy proxy forwards
`Host`.

**Fix** (T108 Phase 3): Replace `SITE_VARIANTS` map with a read from `getConfig().MEREKA_SITE_VARIANT`
(or equivalent). Add the key to the LMS `SiteConfiguration` default values.

**Effort**: Medium (JSX change + LMS SiteConfiguration update).

---

### Gap 5 — Hardcoded Footer Nav Links (Low Priority)

**Current state**: `navLinks`, `corporateLinks`, `marketplaceUserLinks`, `marketplaceBusinessLinks`,
`academyLinks`, `spaceLinks`, and `socialLinks` are all hardcoded arrays in `env.config.jsx`.
Any marketing site restructure requires a full MFE rebuild.

**OEP-65 target**: Content that changes independently of code should be runtime-configurable.
The LMS `SiteConfiguration` can serve arbitrary JSON via the `mfe_config` API when keys are
present in the `values` field.

**Fix** (T108 Phase 2): Read links from `getConfig().MEREKA_FOOTER_CONFIG` (a JSON blob served
by the LMS). Fall back to current hardcoded values for backward compatibility.

**Effort**: Medium (JSX change + LMS `SiteConfiguration` seeding).

---

### Gap 6 — `--legacy-peer-deps` for Plugin Framework (Tracking)

**Current state**: `@openedx/frontend-plugin-framework@^1.8.0` requires `--legacy-peer-deps`
because it has peer dependency conflicts with some upstream MFE packages (React version
mismatches between FPF and Indigo or individual MFEs).

**OEP-65 target**: FPF is a first-class dependency of all Open edX MFEs. No `--legacy-peer-deps`
should be needed. Upstream FPF and MFEs should agree on React and peer versions.

**Impact**: Low — `--legacy-peer-deps` is a build-time workaround with no runtime consequences.

**Recommended action**: When upgrading FPF or individual MFE packages, attempt to remove
`--legacy-peer-deps`. Track FPF releases for the peer dep fix.

---

### Gap 7 — No Shared Shell for `env.config.jsx` (Architectural)

**Current state**: Each MFE has its own `COPY env.config.jsx` in its Dockerfile stage. The
shared `env.config.jsx` (from Indigo) is copied into every app. If the file changes, all 12
MFEs must rebuild.

**OEP-65 target**: The shell loads `env.config.jsx` once. Remote MFEs inherit the slot
configuration from the shell without bundling their own copy.

**Impact**: This is the same as Gap 1 — it resolves automatically when the shell is adopted.
Until then, the single `env.config.jsx` copy-per-MFE is the correct pattern for the standalone
bundle model.

---

## What Is Already Aligned with OEP-65

### Plugin Slots (Fully Aligned)

The Mereka footer is injected using `@openedx/frontend-plugin-framework` `PLUGIN_SLOTS`:

```python
# mereka_lms.py — slot registration (Tutor v21 tutormfe hook)
PLUGIN_SLOTS.add_items([
    ("all", "footer_slot", PluginSlot(id="footer_slot", ...))
])
```

```jsx
// env.config.jsx — Direct plugin insert
const config = {
  pluginSlots: {
    footer_slot: {
      keepDefault: false,
      plugins: [{ op: PLUGIN_OPERATIONS.Insert, widget: { ... RenderWidget: <MerekaFooter /> } }],
    },
  },
};
```

This is the exact pattern OEP-65 requires for site-operator customisation. When the shell model
is adopted, this slot registration will move to the shell's `env.config.jsx` with zero code
change to the `MerekaFooter` component.

### Brand Package (Fully Aligned)

The Mereka brand is delivered as an npm package alias:

```dockerfile
RUN npm install --legacy-peer-deps '@edx/brand@npm:@edly-io/indigo-brand-openedx@^2.4.3'
```

SCSS is imported in `env.config.jsx`:

```jsx
import './mereka/mereka.scss';
```

This is the OEP-65/OEP-50 endorsed brand override pattern.

### Runtime Config (Partially Aligned)

The `mfe_config` API is already the primary delivery mechanism for LMS URL, Studio URL, authn
redirect, cookie posture, and feature flags. `MFE_CONFIG_API_URL` is already set to a relative
path (`/api/mfe_config/v1`) — the correct OEP-65 pattern.

### `@openedx/frontend-plugin-framework` Installed (Aligned)

All 12 MFEs install FPF as part of the build. FPF is the prerequisite library for OEP-65
plugin slot composition. This is a foundation, not a gap.

---

## Readiness Assessment

### Tech Radar Position: **TRIAL** (Move toward Adopt over 2 releases)

| Dimension | Score | Notes |
|-----------|-------|-------|
| Plugin Slots adoption | **Green** | Footer fully slot-driven; FPF installed on all MFEs |
| Runtime config | **Amber** | Cookie domains and hostname map still build-time |
| Brand delivery | **Green** | Brand package pattern correct |
| Dockerfile maintainability | **Amber** | Bash regex surgery on generated files; breaks on structural Dockerfile changes |
| Shell / Module Federation | **Red** | Not applicable yet — upstream not ready |
| `env.config.jsx` coupling | **Amber** | SITE_VARIANTS and nav links hardcoded |
| Dependency health | **Amber** | `--legacy-peer-deps` for FPF; tracking |

### Summary

Mereka is **well-positioned for OEP-65 adoption** in the dimensions that are actionable today:
Plugin Slots, brand packages, and the runtime config foundation are all correct. The remaining
gaps are either low-effort cleanup (cookie domain baking, T108 Phase 1) or blocked on upstream
Tutor MFE plugin work (Module Federation, shell adoption).

The Dockerfile surgery risk is real but non-blocking — it only activates when the upstream
generated Dockerfile structure changes. The best mitigation is to complete the ENV_PATCHES
migration outlined in TUTOR_PATCHES_INVENTORY.md before upstream adopts Module Federation.

No immediate code changes are required to maintain OEP-65 compatibility in the current Ulmo
release cycle. The recommended actions below should be prioritised for Palms (next release).

---

## Recommended Actions by Priority

### P1 — Actionable now, low risk

| Action | File(s) | Effort | OEP-65 gap |
|--------|---------|--------|------------|
| Remove `SESSION_COOKIE_DOMAIN` / `CSRF_COOKIE_DOMAIN` from Dockerfile | `infrastructure/tutor/mfe-build/Dockerfile` (12 occurrences) | Low | Gap 2 |
| Remove `ENABLE_NEW_RELIC` build ARG; drive from `mfe_config` LMS key | `infrastructure/tutor/mfe-build/Dockerfile` + LMS settings | Low | Gap 2 |

### P2 — Medium effort, medium payoff

| Action | File(s) | Effort | OEP-65 gap |
|--------|---------|--------|------------|
| Replace `SITE_VARIANTS` map with `getConfig().MEREKA_SITE_VARIANT` | `env.config.jsx` + LMS SiteConfiguration | Medium | Gap 4 |
| Replace hardcoded nav links with `getConfig().MEREKA_FOOTER_CONFIG` | `env.config.jsx` + LMS SiteConfiguration | Medium | Gap 5 |
| Convert `security-hardening.sh` Django settings block to ENV_PATCH | `infrastructure/tutor/apply-patches.sh` + `mereka_lms.py` | Low | TUTOR_PATCHES_INVENTORY recommendation |

### P3 — Watch and react

| Action | Trigger |
|--------|---------|
| Audit `mfe-node.sh` regex anchors | When Tutor MFE plugin releases Module Federation support |
| Adopt `frontend-base` shell | When `tutormfe` plugin generates Module Federation remotes |
| Remove `--legacy-peer-deps` for FPF | When FPF releases peer dep fix |

---

## Spike Branch Recommendation

A spike branch for OEP-65 Module Federation is **not recommended at this time** because:

1. The upstream `frontend-base` shell does not yet have Tutor integration.
2. The generated Dockerfile format for Module Federation remotes is not yet stable.
3. All current Mereka customisations (Plugin Slots, brand, runtime config) will transfer
   unchanged to the shell model — there is no Mereka-specific spike work needed.

The appropriate spike moment is when `tutor-contrib-mfe` publishes a Module Federation build
mode, at which point the relevant spike would be: "run the generated Module Federation
Dockerfile and verify Mereka Plugin Slots and brand still work."

---

## Files Referenced

| File | Relevance |
|------|-----------|
| `infrastructure/tutor/mfe-build/Dockerfile` | Build-time config gaps (Gap 2) |
| `tutor_env/env/plugins/mfe/build/mfe/indigo/env.config.jsx` | `SITE_VARIANTS`, nav links (Gap 4, 5) |
| `infrastructure/tutor/plugins/mereka_lms.py` | `PLUGIN_SLOTS` registration, `ENV_PATCHES` |
| `infrastructure/tutor/apply-patches.sh` | Dockerfile surgery (Gap 3) |
| `docs/architecture/MFE_RUNTIME_CONFIG.md` | Full runtime config migration plan |
| `docs/architecture/TUTOR_PATCHES_INVENTORY.md` | Bash patch classification and risk assessment |
| `scripts/qa/verify-oep65-readiness.sh` | Automated readiness checks for this document |
