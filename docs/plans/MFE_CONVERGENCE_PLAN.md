# MFE Convergence Plan — ground-truth rewrite 2026-04-23

**Supersedes** the 2026-04-22 version of this plan, which was based on a
false premise ("v1 light footer is stale; rewrite LMS Django footer to v2").
Direct file reads on 2026-04-23 show that Django footer templates are
**already v2 dark**, the canonical SCSS (`_mfe-footer.scss`, 267 lines) is
**already unified**, and `MFE_CONFIG["MEREKA_PUBLIC_FOOTER"]` **is** populated
at runtime (production.py:1074) — the earlier comment at
`lms/templates/footer.html:15` claiming it was never populated is now stale.

Parent bead: **mereka-lms-zy7k** (epic).
Scope: debt-cleanup lane, not an outage.

---

## 0. What this plan is *not*

- Not a migration from v1 to v2. No v1 light footer exists. All three Django
  footer templates (`lms/templates/footer.html`, `cms/templates/footer.html`,
  `cms/templates/widgets/footer.html`) already use `mereka-footer--v2` class
  and consume the canonical `_mfe-footer.scss` via `mereka-overrides.css`.
- Not a SCSS unification. `_mfe-footer.scss` is the single source of
  authored footer styling. Only `mereka-overrides.css` (compiled) is
  duplicated, and duplicates are byte-identical today (see Phase 2 below).
- Not `1kwf.1`. That bead was already absorbed as zy7k.1. The SCSS/structure
  acceptance criteria for 1kwf.1 are satisfied by the state we shipped before
  this plan was written.

---

## 1. What this plan *is*

Four drift risks that today either (a) require copy-paste to change anything
or (b) are silently broken but pass existing CI. Ordered by impact.

### Phase 1 — Unify the Django footer data source (highest drift risk)

**Problem.** `infrastructure/tutor/themes/mereka/lms/templates/footer.html`
hardcodes seven Python dicts (`footer_social_links`, `footer_nav_links`,
`footer_corporate`, `footer_marketplace`, `footer_academy`, `footer_space`)
in its Mako scope, lines 17–84. These dicts mirror `_MEREKA_PUBLIC_FOOTER` in
`deploy/k8s/base/apps/openedx/settings/lms/mereka_footer.py` but have no
shared storage, no CI parity check, and no runtime validation. Anyone
changing a nav link today must edit two files with different syntaxes
(Python dict vs Mako Python block) and pray they stay aligned. The JSX MFE
footer already reads from `settings.MEREKA_PUBLIC_FOOTER` via `MFE_CONFIG`.

**Misleading CI signal.** `scripts/qa/verify-footer-parity.sh:346` asserts
"LMS footer template renders shared MEREKA_PUBLIC_FOOTER content" if the
template string contains `MEREKA_PUBLIC_FOOTER`. A single comment on line 15
passes this check. The template still hardcodes. CI is lying.

**Acceptance.**
1. `footer.html` deletes its hardcoded dicts (lines 17–84) and replaces the
   data block with `<% footer_data = getattr(settings, 'MEREKA_PUBLIC_FOOTER', {}) %>`
   plus per-field lookups (`footer_data.get('socialLinks', [])`,
   `footer_data.get('sections', {}).get('corporate', {}).get('links', [])`, …).
2. Per-tenant override honored: where `configuration_helpers.get_value(
   'MEREKA_PUBLIC_FOOTER', settings.MEREKA_PUBLIC_FOOTER)` differs from the
   Django default, the template reflects the tenant value. (Today it does
   not — that's a separate regression closed by this work.)
3. `verify-footer-parity.sh:346` check is replaced with a real parity
   assertion: render the Django template with the test payload; assert the
   JSX `MerekaFooter` component consuming the same payload produces the same
   visible link set. Comment-string match is no longer sufficient.
4. No change to visible output on any of the three tenants (mereka, SOF,
   biji-biji) — pre/post browser capture must match.

**Trap to avoid.** Mako's expression_filter="h" escapes HTML. Ensure the
social icon SVG `iconPath` data is not HTML-escaped when embedded in the
`<path d="...">` attribute — the current hardcoded path uses `| n` to opt
out (verify in current rendered template, keep same filter behavior).

**Files.**
- `infrastructure/tutor/themes/mereka/lms/templates/footer.html` — rewrite.
- `scripts/qa/verify-footer-parity.sh` — replace weak check (~line 346) with
  parity assertion; keep existing PASS conditions as prerequisites.
- `tests/` — new test that loads `mereka_footer.py`, renders both surfaces,
  diffs visible content.

**Bead.** `mereka-lms-zy7k.1` — reframed from "SCSS unification + stale v1
delete" to "unify Django footer data source + replace fake parity guard."

---

### Phase 2 — Deduplicate `mereka-overrides.css` (pre-drift hygiene)

**Problem.** Three files at `infrastructure/tutor/themes/mereka/{lms,cms,common}/static/css/mereka-overrides.css`
are 1103 lines, byte-identical today (verified 2026-04-23). They are
post-compile output of the SCSS pipeline but committed to git. Any manual
patch to one (by a past agent fixing a symptom) and not the others silently
diverges the three surfaces.

**Acceptance.**
1. Either: collapse to one file with the other two as symlinks / COPY steps
   in the Mereka theme build.
2. Or: add a CI assertion that the three files are byte-identical, and if
   they should differ in the future (unlikely), the authored SCSS sources
   (not the compiled CSS) carry the difference.
3. If the files are produced by `compile-sass --theme mereka`, audit why
   three copies land in three directories; the canonical pattern is one
   per theme-lms-or-cms context, not three.

**Trap.** Some Open edX asset paths expect a file at each of the three
locations; blindly symlinking breaks `collectstatic` on disk because hashed
staticfiles storage doesn't follow symlinks. Options: (a) keep three files
and add the byte-identical CI check; (b) move to one file and teach the
theme build to re-emit each copy at build time.

**Recommendation.** Start with option (a). Option (b) can be a later bead if
drift ever happens.

**Files.**
- `scripts/qa/verify-theme-override-parity.sh` — new script.
- CI static inventory (`scripts/governance/script-registry.yaml`
  `ci_static_inventory`) — register the new script.
- `.github/ci-scripts-static.txt` — regenerate the derivative.

**Bead.** New child `mereka-lms-zy7k.2` — reframed from "rewrite LMS Django
footer v2" to "deduplicate mereka-overrides.css + CI parity guard." Old
.2 scope is subsumed by new .1.

---

### Phase 3 — Collapse three copies of `getMerekaPublicFooter()`

**Problem.** The same JS helper is defined three times:
- `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/tenant-resolution.js:133` (canonical).
- `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js:147` (deprecated path).
- `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/tenant-resolution-runtime.js:44`.

`mfe_runtime.py:130` has `_sync_compat_runtime_definitions()` to keep the
deprecated copy in sync with the canonical one, but the third file has no
sync; drift is only caught if an MFE regression happens at runtime.

**Acceptance.**
1. Single authored definition of `getMerekaPublicFooter(config)`. All three
   consumer surfaces import from that one file (or the build step emits
   identical copies from it with a checksum assertion).
2. Add a static guard: `scripts/qa/verify-mfe-runtime-helpers.sh` diffs the
   three function bodies; FAIL if they differ.
3. Document the pattern in `infrastructure/tutor/plugins/README.md` so the
   next agent adding a runtime helper doesn't repeat the sprawl.

**Trap.** `mfe_runtime_definitions.js` is marked deprecated in comments but
is actually loaded as the runtime source for MFE shells that haven't
migrated to the split `mfe_runtime/*.js` layout. Don't delete it until the
last consumer migrates — check the MFE build for which file is in the
webpack entry.

**Files.**
- `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/*.js` — refactor.
- `scripts/qa/verify-mfe-runtime-helpers.sh` — new.
- `infrastructure/tutor/plugins/README.md` — doc the pattern.

**Bead.** New child `mereka-lms-zy7k.3` — same scope-name as old .3
("brand-package.sh sed-injection"), but deferred. The sed-injection debt is
real and worth closing, but has less drift risk than helper-sprawl. Reframe
to the helper dedup work and file a new bead for the brand-package
migration as zy7k.5 or a sibling.

---

### Phase 4 — Migrate `brand-package.sh` sed injection to `@mereka/brand-openedx` npm package

**Problem.** `infrastructure/tutor/patches/brand-package.sh` sed-injects
brand tokens (colors, fonts, logo paths) into the built MFE bundle. This is
a post-render mutation that the Build Authority epic is retiring. The
forward path is a real npm package published under `@mereka/brand-openedx`
and consumed as a normal MFE dependency via `@edx/brand` alias.

**This is the only phase that touches build/MFE-build internals.** Coordinate
with the Build Authority agent before filing or implementing. If the
Build Authority lane is still stabilizing, hold this phase.

**Acceptance.**
1. `@mereka/brand-openedx` npm package published with color/font/logo tokens.
2. MFE build consumes it via `@edx/brand` alias; brand-package.sh retired.
3. `apply-patches.sh`' `apply_brand_package` function removed.
4. Per `ADR-021`, this matches the "frontend → plugin slots + design tokens
   + @edx/brand" binding decision.

**Trap.** `@edx/brand` alias resolution is configured in MFE webpack via
`resolve.alias`. The current behavior of overriding brand via
`infrastructure/tutor/custom-apps/edx-brand/` also needs audit; the two
paths (sed-inject vs `@edx/brand` alias) currently coexist and may conflict
on specific tokens.

**Files.**
- New repo or npm package publish flow for `@mereka/brand-openedx`.
- `infrastructure/tutor/patches/brand-package.sh` — retire.
- `infrastructure/tutor/patches/manifest` — update.
- `apply-patches.sh` — remove `apply_brand_package`.

**Bead.** New child `mereka-lms-zy7k.4` — reframed from "retire
apply-patches.sh" to this specific brand-package migration. The broader
apply-patches.sh retirement is a Build Authority concern and should stay
there, not here.

**Coordination required.** Build Authority lane.

---

### Phase 5 — Dual-SiteConfiguration parity verifier (cross-cut)

**Problem.** Each tenant has TWO `SiteConfiguration` rows — one keyed on the
LMS host (e.g. `skillourfuture.academy.mereka.io`) and one on the apps host
(e.g. `apps.skillourfuture.academy.mereka.io`). The MFE config API
(`/api/mfe_config/v1`) resolves off the apps host row. A past incident
(see `memory/dev-mfe-dual-siteconfig.md`) had live-patching only the LMS
row leave the API stale.

**Acceptance.**
1. New verifier `scripts/qa/verify-dual-siteconfig-parity.sh` compares the
   two SiteConfiguration rows per tenant on `MEREKA_PUBLIC_FOOTER`,
   `MFE_CONFIG_OVERRIDES`, `PLATFORM_NAME`, `SUPPORT_EMAIL`, and the other
   keys the footer + runtime config read.
2. CI runtime inventory registers it with live credentials available in
   the target env.
3. Runbook entry at `docs/ops/runbooks/TENANT_SITECONFIG_PARITY.md` so
   when parity fails, the operator knows which row is authoritative.

**Trap.** The "authoritative" row is not the same for all keys. `PLATFORM_NAME`
is typically read off the LMS host row; `MFE_CONFIG_OVERRIDES` off the apps
host row. The verifier needs per-key expected-authority mapping, not a flat
"they must match" assertion.

**Files.**
- `scripts/qa/verify-dual-siteconfig-parity.sh` — new.
- `scripts/governance/script-registry.yaml` (`ci_runtime_inventory`) — register.
- `.github/ci-scripts-runtime.txt` — regenerate derivative.
- `docs/ops/runbooks/TENANT_SITECONFIG_PARITY.md` — new.

**Bead.** `mereka-lms-zy7k.5` — carries forward unchanged from previous plan.

---

## 2. Parallel debts not in this epic (same lane)

**Runtime-config & observability hygiene (OBS cluster).** Separate sibling
epic covers four beads:
- `mereka-lms-jdsx` — LOGIN_ISSUE_SUPPORT_LINK verification (work mostly
  already done at `lms_settings.py:99`; remaining = post-PR #1928 smoke).
- `mereka-lms-9ib2` — Sentry DSN K8s overlay wiring (bbi-infrastructure
  lane; lms_settings.py:123 already reads `MEREKA_MFE_SENTRY_DSN` env).
- `mereka-lms-mx78` — Upptime prod domains.
- `mereka-lms-e09t` — authn-MFE 5-min cron synthetic.

These do not depend on and do not block any zy7k phase. See
`docs/plans/BEAD_GRAPH_ZY7K_EXPANSION.md` for evidence per bead.

**Studio SSO structural P0.** `mereka-lms-cm9c` is unclaimed and P0.
Blocks enterprise B2B tenants from Studio access. Lives in the same
MFE/authn lane but is a larger refactor — do not fold into zy7k. Own bead,
own plan session when you want to pick it up.

**Celery probes.** `mereka-lms-9pnu` epic. The 9pnu.1 PR also closes
`mereka-lms-1li5` (same root symptom filed 4 days apart). Tracked in
`docs/plans/INVESTIGATION_CELERY_PROBES.md`.

**HPA restore.** `mereka-lms-b7nl` epic — carries over from prior plan.
Tracked in `docs/plans/INVESTIGATION_HPA_RESTORATION.md`.

---

## 3. Phase ordering

Recommended sequence: **1 → 3 → 2 → 5 → 4**.

- **1 first** because the CI guard is materially lying and data-source
  divergence is the highest-blast-radius debt.
- **3 before 2** because helper sprawl is easier to fix once and adds a
  CI guard; CSS dedup benefits from the same static-guard pattern.
- **5 anytime after 1** — it's cross-cut and can land in parallel with 2/3.
- **4 last** and only after coordinating with Build Authority lane. If the
  build-lane agent says "not now," defer indefinitely and file as a
  standalone bead outside zy7k.

---

## 4. Open questions before implementation

1. The `FRONTEND_RUNTIME_CLOSURE_TRACKER_2026-04-01.md` archive claims the
   Django LMS fallback footer is a "separate ongoing item." Is there an
   existing bead for it older than zy7k? If yes, link. If no, zy7k.1 is
   that bead.
2. When was the `# Previously read from settings.MEREKA_PUBLIC_FOOTER` comment
   added to `lms/templates/footer.html:15`? `git blame` to understand what
   the original symptom was — if it was a regression in MFE_CONFIG
   population that later got fixed, the hardcoded dicts are dead weight
   that nobody noticed could be removed.
3. Does `tenant_cache/branding.py:_default_public_footer()` actually get
   called in the request path, or is it dead code? The `mfe.get(
   'MEREKA_PUBLIC_FOOTER', ...)` pattern at line 101 suggests a prior
   multi-source resolution that Phase 1 should consolidate.

---

## 5. Not in scope

- Any `0z5g.*` work (Build Authority Phase 2 epic). The build-lane agent
  owns that.
- Brand-package/npm work beyond Phase 4 scope.
- MFE build performance, cache-pinning, or ARC runner hygiene.
- Discovery or enterprise-service MFE slots — those are separate epics.
