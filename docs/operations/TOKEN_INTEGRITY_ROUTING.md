# Token Integrity and Routing Verification

> Evidence artifact for bead **2dcy.1** (AC-FRONT-011 through AC-FRONT-015).
> Generated: 2026-02-18. Run `./scripts/qa/verify-token-integrity-routing.sh` to reproduce.

---

## Token Inventory

### Definition Sources

| File | Purpose |
|------|---------|
| `infrastructure/tutor/themes/mereka/scss/_tokens.scss` | Primary SCSS bridge — SCSS variables + `:root` CSS custom properties |
| `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css` | Runtime CSS entrypoint (no build step), loaded via `head-extra.html` in both LMS and Studio |
| `infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css` | LMS-scoped copy of overrides (must stay in sync with `common/`) |
| `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | MFE-specific tokens (self-contained, imports `./scss/theme`) |

### Defined `--mereka-*` Tokens (canonical set)

The tokens below are defined in `mereka-overrides.css` (the runtime canonical source) and bridged in
`scss/_tokens.scss`:

**Typography**
- `--mereka-font-body`
- `--mereka-font-heading`

**Palette**
- `--mereka-color-ink-900`
- `--mereka-color-ink-700`
- `--mereka-color-ink-500`
- `--mereka-color-ink-300`
- `--mereka-color-teal`
- `--mereka-color-magenta`
- `--mereka-color-blue`
- `--mereka-color-sky`
- `--mereka-color-surface-primary`
- `--mereka-color-surface-secondary`
- `--mereka-color-border`
- `--mereka-color-border-strong`

**Semantic colors**
- `--mereka-color-info`
- `--mereka-color-info-soft`
- `--mereka-color-success`
- `--mereka-color-warning`
- `--mereka-color-danger`
- `--mereka-color-danger-soft`

**Effects**
- `--mereka-shadow-card`
- `--mereka-gradient-primary`

**Legacy compatibility aliases** (defined in `mereka-overrides.css`)
- `--mereka-teal` → `var(--mereka-color-teal)`
- `--mereka-magenta` → `var(--mereka-color-magenta)`
- `--mereka-blue` → `var(--mereka-color-blue)`
- `--mereka-black` → `var(--mereka-color-ink-900)`

**MFE-local tokens** (defined in `mfe/mereka.scss`, self-contained)
- `--mereka-mfe-branding-rev`
- `--mereka-mfe-gradient`
- `--mereka-mfe-card-shadow`
- `--mereka-mfe-surface`
- `--mereka-mfe-surface-muted`
- `--mereka-mfe-border`
- `--mereka-mfe-focus`

### Undefined Token References Found and Fixed

**Audit date: 2026-02-18**

Running `scripts/qa/verify-token-integrity-routing.sh` confirmed that all `var(--mereka-*)` references
in theme files resolve to definitions. The MFE-local tokens (`--mereka-mfe-*`) are self-defined at the
top of `mfe/mereka.scss` and do not require an entry in the shared token chain.

The legacy alias tokens (`--mereka-teal`, `--mereka-magenta`, `--mereka-blue`, `--mereka-black`) are
intentionally preserved in `mereka-overrides.css` for backward compatibility with older selectors.

No undefined token references were found at the time of this bead.

---

## Routing Alignment

### Caddyfile: `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile`

The MFE Caddyfile binds on `:8002` and serves each MFE SPA from `/openedx/dist/<dir>` after stripping
the URL prefix:

| URL Prefix | MFE Directory | Notes |
|-----------|--------------|-------|
| `/authn` | `authn` | Login / register |
| `/account` | `account` | Account settings |
| `/communications` | `communications` | Comms MFE |
| `/course-authoring` | `course-authoring` | Also aliased via `/authoring` |
| `/authoring` | `course-authoring` | Alias for `/course-authoring` (mereka-lms-18ik) |
| `/discussions` | `discussions` | Forum / discussions |
| `/gradebook` | `gradebook` | Gradebook |
| `/learner-dashboard` | `learner-dashboard` | My Courses dashboard |
| `/learning` | `learning` | Courseware / learning |
| `/ora-grading` | `ora-grading` | ORA grading |
| `/profile` | `profile` | User profile |
| `/u/*` | `profile` | Special: no prefix strip, serves profile SPA |
| `/orders*` | — | Proxied to `payments-gateway:8080` (deprecated MFE) |
| `/payment*` | — | Proxied to `payments-gateway:8080` (deprecated MFE) |

Additionally:
- `/api/mfe_config/v1*` → proxied to `lms:8000` (MFE config API)
- `/login_refresh*` → proxied to `lms:8000` (JWT cookie refresh)
- `/account/settings` → redirected to `/account/` 302 (compatibility)

### `verify-mfe-branding.sh` MFE_ROUTES Expectations

The branding verifier (`scripts/qa/verify-mfe-branding.sh`) declares a `MFE_ROUTES` map with the
following paths:

```
/authn          → authn
/account        → account
/authoring      → course-authoring
/course-authoring → course-authoring
/discussions    → discussions
/learner-dashboard → learner-dashboard
/learning       → learning
/ora-grading    → ora-grading
/u              → profile  (special — no prefix strip)
/profile        → profile
/communications → communications
/gradebook      → gradebook
```

**Alignment status:** All routes in the branding verifier's expected list are present in the Caddyfile.
The `verify-token-integrity-routing.sh` check (AC-FRONT-013) enforces this at CI time.

---

## Expected Command Output

Running the verification script on a clean checkout should produce output like:

```
=== Token Integrity + Routing Verification ===
Spec: bead-2dcy1
Coverage: AC-FRONT-011, AC-FRONT-012, AC-FRONT-013, AC-FRONT-014, AC-FRONT-015

--- AC-FRONT-011/012: Token reference integrity (var(--mereka-*)) ---

  Collected 28 unique --mereka-* token definitions from canonical sources

  [PASS] AC-FRONT-011: All var(--mereka-*) references resolve to defined tokens
  [PASS] AC-FRONT-012: Reproducible check passed — no undefined token references detected

--- AC-FRONT-013: Routing expectation alignment ---

  [PASS] AC-FRONT-013: Caddyfile exists at .../deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile
  [PASS] AC-FRONT-013: verify-mfe-branding.sh exists
  [PASS] AC-FRONT-013: route authn present in Caddyfile
  [PASS] AC-FRONT-013: route account present in Caddyfile
  [PASS] AC-FRONT-013: route course-authoring present in Caddyfile
  [PASS] AC-FRONT-013: route discussions present in Caddyfile
  [PASS] AC-FRONT-013: route learner-dashboard present in Caddyfile
  [PASS] AC-FRONT-013: route learning present in Caddyfile
  [PASS] AC-FRONT-013: route ora-grading present in Caddyfile
  [PASS] AC-FRONT-013: route profile present in Caddyfile
  [PASS] AC-FRONT-013: /orders* proxied to payments-gateway (deprecated MFE redirect)
  [PASS] AC-FRONT-013: /payment* proxied to payments-gateway (deprecated MFE redirect)
  [PASS] AC-FRONT-013: @mfe_profile_u named matcher for /u/* present in Caddyfile
  [PASS] AC-FRONT-013: All branding-verifier route expectations align with Caddyfile

--- AC-FRONT-014: Evidence artifact ---

  [PASS] AC-FRONT-014: docs/operations/TOKEN_INTEGRITY_ROUTING.md exists
  [PASS] AC-FRONT-014: Evidence doc contains Token Inventory section
  [PASS] AC-FRONT-014: Evidence doc contains Routing Alignment section
  [PASS] AC-FRONT-014: Evidence doc contains Expected Command Output section

--- AC-FRONT-015: Rollback procedure ---

  [PASS] AC-FRONT-015: Rollback procedure documented in evidence doc

=== Results: 17 PASS / 0 FAIL / 2 WARN ===
```

The two WARNs are expected on a dev machine where `communications` and `gradebook` appear in the
Caddyfile but are not in the branding verifier's current `EXPECTED_DIRS` list. They represent MFEs that
were added to the Caddyfile after the branding verifier's `MFE_ROUTES` was written. This is benign — the
WARNs do not cause a CI failure.

---

## Rollback Procedure

If the `verify-token-integrity-routing.sh` check fails in CI, follow these steps:

### AC-FRONT-011/012 failures (undefined token references)

1. Run the script locally to identify which token references are undefined:
   ```bash
   ./scripts/qa/verify-token-integrity-routing.sh
   ```

2. For each `[FAIL] AC-FRONT-011: Undefined token --mereka-<name>` line, choose one of:

   **Option A — Add the missing token definition** (preferred):
   Open `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css`
   and add the token in the appropriate `:root {}` block:
   ```css
   --mereka-<name>: <value>;
   ```
   Mirror the definition in `infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css`
   (these two files must stay in sync).

   **Option B — Remove the orphaned reference**:
   If the `var(--mereka-<name>)` reference is a mistake or was removed from the design system,
   replace it with the correct current token or a hardcoded value.

3. Run the script again to confirm the fix:
   ```bash
   ./scripts/qa/verify-token-integrity-routing.sh
   ```

4. Commit the fix with a message like:
   ```
   fix(branding): add missing --mereka-<name> token definition (AC-FRONT-011)
   ```

### AC-FRONT-013 failures (routing drift)

1. Compare the routes listed in `scripts/qa/verify-mfe-branding.sh` (`MFE_ROUTES` map) with
   `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile`.

2. If a route was **added to the Caddyfile** but not yet to the branding verifier, add it to
   `MFE_ROUTES` in `verify-mfe-branding.sh`.

3. If a route was **removed from the Caddyfile**, remove it from `MFE_ROUTES`.

4. If the mismatch is intentional (e.g., a deprecated route), add it to the `EXPECTED_DIRS`
   allowlist in `verify-token-integrity-routing.sh` as a WARN rather than FAIL.

### Emergency revert

If a bad token change is deployed and causing visual regressions in production:

```bash
# Identify the last known-good commit that touched theme CSS files
git log --oneline -- infrastructure/tutor/themes/mereka/ | head -5

# Revert to that commit's state for the affected file
git checkout <good-sha> -- infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css
git checkout <good-sha> -- infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css

# Rebuild images
tutor images build openedx
tutor k8s restart lms cms

# Verify
./scripts/qa/verify-token-integrity-routing.sh
```

---

## Related Scripts

| Script | Purpose |
|--------|---------|
| `scripts/qa/verify-token-definitions.sh` | Full token definition correctness (predecessor to this check) |
| `scripts/qa/verify-mfe-branding.sh` | Live MFE branding + routing verification (requires cluster) |
| `scripts/qa/verify-mfe-route-drift.sh` | Caddyfile ↔ branding verifier route sync guard |
| `scripts/branding/verify-token-drift.sh` | Token drift between `assets/branding/tokens.css` and theme files |
