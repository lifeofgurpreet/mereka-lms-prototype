# BUILD_OPTIMIZATIONS_REFACTOR.md

**Task**: T144
**Depends on**: T109 (TUTOR_PATCHES_INVENTORY.md, DONE)
**Status**: Audit + plan only — `build-optimizations.sh` is NOT modified.

---

## 1. Current Structure

`infrastructure/tutor/patches/build-optimizations.sh` is 686 lines and contains a single
function `apply_build_optimizations_patch()`. Internally it is split into two distinct
execution phases:

### Phase A — Python string surgery (lines 24–584)

A single `python - "${targets[@]}" <<'PY' ... PY` heredoc that iterates over 6 target
file paths and applies in-place string replacements. The targets are:

| Target variable | Rendered path |
|----------------|---------------|
| `$OPENEDX_TEMPLATE` | `tutor_env/env/build/openedx/Dockerfile` |
| `$LMS_SETTINGS_TEMPLATE` | `tutor_env/env/apps/openedx/settings/lms/production.py` |
| `$LMS_ASSETS_TEMPLATE` | `tutor_env/env/build/openedx/settings/lms/assets.py` |
| `$CMS_ASSETS_TEMPLATE` | `tutor_env/env/build/openedx/settings/cms/assets.py` |
| `$NGINX_LMS_TEMPLATE` | `tutor_env/env/apps/nginx/lms.conf` |
| `$CADDY_TEMPLATE` | `tutor_env/env/apps/caddy/Caddyfile` |

Within the Python heredoc there are 5 clearly bounded sub-sections separated by comment
banners (`# ── ... ──`):

| Section | Lines (approx) | Sub-operations |
|---------|---------------|----------------|
| Dockerfile patches | 39–398 | i18n URL, uv pip/build-isolation, pip retry, local req removal, optional apps, compilemessages, compilejsi18n, node_modules path, static bundles COPY, node cache reuse, postinstall, brand SASS + Google font strip, webpack conditional, cherry-pick removal, Tutor v21 node_modules mv, mereka-overrides.css bake, custom apps block, django-prometheus install |
| production.py patches | 399–479 | MFE discussions-only, DEFAULT_SITE_THEME, MFE OAuth fix config, mereka_tenancy config |
| assets.py patches | 480–513 | Optional app injection, JS_COMPRESSOR=None, safe_join monkey-patch |
| lms.conf patches | 514–543 | /health endpoint, /profile/api/ proxy |
| Caddyfile patches | 544–583 | MFE cache headers, /profile/api/ proxy |

### Phase B — Bash file sync (lines 586–685)

Pure shell operations after the Python heredoc closes:

| Sub-section | Lines | Operation |
|-------------|-------|-----------|
| Logo sync | 588–614 | `cp` logo PNG/SVG/favicon from `infrastructure/tutor/themes/mereka/` to `tutor_env/env/build/openedx/themes/mereka/` |
| Font sync | 617–635 | `cp` `.woff2` files to LMS + CMS theme build dirs |
| Theme templates/CSS sync | 637–663 | `cp -R` templates + CSS dirs for LMS, CMS, common into build context |
| Custom apps sync | 665–674 | `cp -R` `infrastructure/tutor/custom-apps/` into `tutor_env/env/build/openedx/` |
| Multi-tenancy plugin sync | 676–685 | `cp -R` `infrastructure/tutor/plugins/multi-tenancy` into build context |

---

## 2. Dependency Map

```
apply_build_optimizations_patch()
  │
  ├── requires (from _common.sh):
  │     OPENEDX_TEMPLATE, LMS_SETTINGS_TEMPLATE, LMS_ASSETS_TEMPLATE,
  │     CMS_ASSETS_TEMPLATE, NGINX_LMS_TEMPLATE, CADDY_TEMPLATE, REPO_ROOT
  │
  ├── Phase A (Python heredoc)
  │     ├── Dockerfile section ──────────────────────────────────────────────┐
  │     │     All sub-operations share `updated` state for the SAME file.    │
  │     │     Order is significant: node cache reuse must precede the mv fix. │
  │     │     Custom apps block has 3 conditional branches (marker-based).   │
  │     │     django-prometheus install anchors on pip retry marker.         │
  │     └─────────────────────────────────────────────────────────────────── ┘
  │     ├── production.py section (guarded by path.name == "production.py")
  │     ├── assets.py section    (guarded by path.name == "assets.py" + "derive_settings")
  │     ├── lms.conf section     (guarded by path.name == "lms.conf")
  │     └── Caddyfile section    (guarded by path.name == "Caddyfile")
  │
  └── Phase B (bash)
        ├── Logo sync      — reads from infrastructure/, writes to tutor_env/
        ├── Font sync      — reads from infrastructure/, writes to tutor_env/
        ├── Templates/CSS  — reads from infrastructure/, writes to tutor_env/
        ├── Custom apps    — reads from infrastructure/, writes to tutor_env/
        └── Tenancy plugin — reads from infrastructure/, writes to tutor_env/
```

Key coupling: **all Dockerfile sub-operations within Phase A accumulate changes
on a single `updated` variable**. Splitting the Dockerfile section into separate
Python scripts would require either (a) running them sequentially on the same
file path, or (b) passing state between them, which adds complexity.

Phase B sub-sections are independent of each other and of Phase A.

---

## 3. Proposed Module Split

The goal is modules of <300 lines each, each with a single responsibility. The
split below respects the coupling constraints identified above.

### Module 1: `build-opt-dockerfile.sh` (~360 lines)

**Responsibility**: All Python string surgery on the openedx Dockerfile.

Extracts lines 24–398 of the current Python heredoc (the Dockerfile section only),
plus the `python - "${targets[@]}" <<'PY'` wrapper scoped to just the Dockerfile
target pair:

```
("$OPENEDX_TEMPLATE", "$REPO_ROOT/tutor_env/env/build/openedx/Dockerfile")
```

Function: `apply_build_opt_dockerfile_patch()`

Sub-operations included (in order — order matters):
1. i18n archive URL fix
2. uv pip / no-build-isolation
3. pip install retry wrapping
4. Local requirements removal
5. Optional apps injection (coursewarehistoryextended)
6. compilemessages fix
7. compilejsi18n output paths
8. node_modules COPY path fix
9. Static bundles COPY normalization
10. Node cache reuse (FROM openedx_node_cache)
11. postinstall fix
12. Brand SASS compile + Google fonts strip
13. Webpack conditional
14. Cherry-pick removal
15. Tutor v21 node_modules mv
16. mereka-overrides.css bake
17. Custom apps block
18. django-prometheus pip install

Estimated LOC: ~370 (Python heredoc content ~340 + ~30 shell wrapper).

**Note**: This remains above 300 lines because the Dockerfile sub-operations are
tightly coupled via the single `updated` variable — splitting them further would
require architectural changes (sequential file writes) that risk regression.
A 370-line single-target module is a meaningful improvement over the current
686-line mixed module.

### Module 2: `build-opt-settings.sh` (~120 lines)

**Responsibility**: Python string surgery on `production.py` and both `assets.py` files.

Extracts lines 399–513 (production.py + assets.py sections), plus the Python wrapper
scoped to three targets:

```
("$LMS_SETTINGS_TEMPLATE", "$REPO_ROOT/tutor_env/.../lms/production.py")
("$LMS_ASSETS_TEMPLATE",   "$REPO_ROOT/tutor_env/.../lms/assets.py")
("$CMS_ASSETS_TEMPLATE",   "$REPO_ROOT/tutor_env/.../cms/assets.py")
```

Function: `apply_build_opt_settings_patch()`

Sub-operations:
- production.py: MFE discussions-only, DEFAULT_SITE_THEME, MFE OAuth fix, mereka_tenancy
- assets.py: optional apps, JS_COMPRESSOR, safe_join monkey-patch

### Module 3: `build-opt-routing.sh` (~80 lines)

**Responsibility**: Python string surgery on `lms.conf` and `Caddyfile`.

Extracts lines 514–583, scoped to two targets:

```
("$NGINX_LMS_TEMPLATE",  "$REPO_ROOT/tutor_env/env/apps/nginx/lms.conf")
("$CADDY_TEMPLATE",      "$REPO_ROOT/tutor_env/env/apps/caddy/Caddyfile")
```

Function: `apply_build_opt_routing_patch()`

Sub-operations:
- lms.conf: /health endpoint, /profile/api/ proxy
- Caddyfile: MFE cache headers, /profile/api/ proxy

### Module 4: `build-opt-theme-sync.sh` (~110 lines)

**Responsibility**: All bash file sync operations (Phase B — lines 586–685).

Function: `apply_build_opt_theme_sync()`

Sub-operations (all independent):
- Logo PNG/SVG sync → `tutor_env/env/build/openedx/themes/mereka/lms/static/images/`
- Font `.woff2` sync → `tutor_env/env/build/openedx/themes/mereka/{lms,cms}/static/fonts/`
- Theme templates + CSS sync → `tutor_env/env/build/openedx/themes/mereka/`
- Custom apps sync → `tutor_env/env/build/openedx/infrastructure/tutor/custom-apps/`
- Multi-tenancy plugin sync → `tutor_env/env/build/openedx/infrastructure/tutor/plugins/`

---

## 4. Module Size Summary

| Module | Lines (est.) | Target reduction |
|--------|-------------|-----------------|
| `build-opt-dockerfile.sh` | ~370 | -316 from current |
| `build-opt-settings.sh` | ~120 | — |
| `build-opt-routing.sh` | ~80 | — |
| `build-opt-theme-sync.sh` | ~110 | — |
| Total | ~680 | split across 4 files |

The Dockerfile module slightly exceeds the 300-line target due to the tight coupling
of 18 sub-operations on a single `updated` accumulation variable. This is documented
as an accepted deviation in the refactoring plan.

---

## 5. Refactoring Plan

### Step 1: Extract `build-opt-theme-sync.sh` (lowest risk)

Phase B is entirely bash, has no Python heredoc, and each sub-section is
independent. Extract first, verify with `bash -n`, wire into `apply-patches.sh`.

### Step 2: Extract `build-opt-routing.sh`

The lms.conf and Caddyfile sections are guarded by `path.name` checks and have
no dependencies on the Dockerfile section's `updated` state. Extract into a
self-contained Python heredoc.

### Step 3: Extract `build-opt-settings.sh`

The production.py and assets.py sections share no state with the Dockerfile
section. Extract into a separate Python heredoc.

### Step 4: Rename remainder to `build-opt-dockerfile.sh`

After steps 1–3, the remaining file contains only the Dockerfile section.
Rename and update `apply-patches.sh` wiring.

### Step 5: Update `apply-patches.sh` call sequence

Replace the single `apply_build_optimizations_patch` call with four calls
in dependency order:

```bash
apply_build_opt_dockerfile_patch
apply_build_opt_settings_patch
apply_build_opt_routing_patch
apply_build_opt_theme_sync
```

### Step 6: Update `verify-patch-modularity.sh`

Add the four new modules to `PATCH_FILES` and remove `build-optimizations.sh`.

### Invariants to preserve

- Each module must be idempotent (sentinel strings already enforce this in the
  original; preserve all sentinel checks).
- Each module must handle missing target files gracefully (`if not path.exists(): continue`
  already does this in Python; bash guards already use `-d` and `-f` checks).
- The call order in `apply-patches.sh` must be: dockerfile → settings → routing → sync.
  The settings and routing modules do not depend on the dockerfile module's output,
  but this order matches the logical dependency (Dockerfile is built before settings
  are injected at runtime).

---

## 6. Risk Assessment

| Step | Risk | Mitigation |
|------|------|------------|
| Extract theme-sync | LOW | Pure bash, independent, easy to test |
| Extract routing | LOW | Short heredoc, guarded by `path.name` |
| Extract settings | MEDIUM | production.py patches are stateful; keep all in one heredoc |
| Dockerfile extraction | MEDIUM | 18 ordered sub-ops; must preserve `updated` accumulation order |
| Rename + rewire | LOW | Mechanical; covered by `verify-patch-modularity.sh` |

---

## 7. Files to Create/Modify

| File | Action |
|------|--------|
| `infrastructure/tutor/patches/build-opt-dockerfile.sh` | CREATE (from Dockerfile section) |
| `infrastructure/tutor/patches/build-opt-settings.sh` | CREATE (from production.py + assets.py) |
| `infrastructure/tutor/patches/build-opt-routing.sh` | CREATE (from lms.conf + Caddyfile) |
| `infrastructure/tutor/patches/build-opt-theme-sync.sh` | CREATE (from Phase B) |
| `infrastructure/tutor/patches/build-optimizations.sh` | DELETE (after all modules extracted) |
| `infrastructure/tutor/apply-patches.sh` | UPDATE (source + call 4 modules) |
| `scripts/qa/verify-patch-modularity.sh` | UPDATE (PATCH_FILES map) |
| `docs/architecture/TUTOR_PATCHES_INVENTORY.md` | UPDATE (replace entry) |
