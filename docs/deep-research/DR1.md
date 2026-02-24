
Mereka LMS Frontend Stack Deep Review
Executive summary
Your branding system is unusually disciplined for an Open edX deployment: you have a real design-token source (assets/branding/tokens.css) and you also ship explicit “branding revision markers” (e.g., --mereka-branding-rev, --mereka-mfe-branding-rev) that CI can validate inside built images, which is a strong operational move for preventing “wrong CSS in prod” incidents.
Plugin-first migration is directionally correct, but the boundary still leaks in key frontend places: the Tutor plugin (infrastructure/tutor/plugins/mereka_lms.py) can inject config and template snippets, but you still rely on non-trivial patch/script logic for “content-level” changes that plugins can’t express safely (notably the MFE footer slot replacement), which remains a brittleness hotspot. 
Your MFE “theme” is currently an override layer, not a durable theme: infrastructure/tutor/themes/mereka/mfe/mereka.scss uses broad selectors like [class*="learning"]/[data-testid*="course"] to chase MFE DOM structures. This will keep breaking as upstream MFEs refactor classnames and test IDs, so the maintenance cost is structurally high.
Release risk is driven more by QA gaps than by “migration completeness”: you have multiple QA scripts, but several are either (a) not connected to CI gates, or (b) easy to desync from routing/runtime reality. The result is weak regression protection exactly where teams tend to get surprised: routing and UI drift.
Accessibility is the biggest “quality debt” signal in the current brand layer: several core palette choices (notably teal + mid-gray text) fail WCAG contrast requirements for normal text (AA). WCAG requires 4.5:1 for normal text (3:1 only for large/bold text). 
Routing is improving, but needs consolidation: the MFE Caddy routing now explicitly addresses /course-authoring (and legacy /authoring), but your verification script still encodes outdated assumptions about the directory name mapping, which undermines confidence in the checks.
CI is strong at “image build + branding presence validation,” weak at “UX correctness”: the build workflow verifies that branded CSS exists in staticfiles.json for Open edX and that an MFE branding revision marker is present, but it does not prove that critical user flows render correctly, nor does it run an accessibility audit (axe) or authenticated UI smoke tests.
The worktree branch you flagged as critical appears operationally obsolete: the key fixes you referenced look already integrated into main (the branch is behind and not carrying unique commits), which is good news for release readiness but suggests process drift in “where to review for truth.”
Scorecard
Dimension	Score (0–100)	What drives the score
UX quality	72	Strong brand intent and coherent visual language in LMS/Studio theme styling, but high override debt and insufficient “state” coverage proof (errors/empty/loading) in MFEs.
Accessibility	46	Contrast failures in core token palette usage and uncertain keyboard/focus system across overrides; no CI-level a11y gating. WCAG contrast minimum guidance is clear and measurable. 
Frontend architecture	64	Clear direction toward plugin-driven configuration (Tutor plugin + docs), but continued dependence on patch/script transformations for frontend correctness and MFE slot replacement. 
Code quality	60	Good structure in tokens + theme organization, but brittle selectors, duplication across token sources, and a few correctness bugs (undefined variables).
Performance	63	Font preloads + baked-in static assets are good; caching behavior for MFEs is not convincingly enforced at the right layer; heavy CSS overrides can increase style recalculation/layout churn.
Operability	70	CI builds images and validates branding presence; vulnerability scanning included. But end-to-end frontend regressions are not strongly gated, and some QA scripts are desynchronized from routing reality.

Top findings by severity
P0 findings
P0 — Brand overrides include a correctness bug that can silently degrade UI styling
Impact: A missing CSS variable causes the browser to drop the declaration and fall back to inherited/default color, producing inconsistent typography contrast and undermining “token-driven” consistency (and potentially accessibility).
Evidence: infrastructure/tutor/themes/mereka/scss/theme.scss uses color: var(--mereka-color-ink-600); in the footer paragraph styling, but your token bridge defines ink-900/700/500/300 (no ink-600).
Exact file path(s):

infrastructure/tutor/themes/mereka/scss/theme.scss
infrastructure/tutor/themes/mereka/scss/_tokens.scss
Recommendation: Replace --mereka-color-ink-600 usage with an actually defined token (--mereka-color-ink-500 or --mereka-color-ink-700), or formally define --mereka-color-ink-600 in _tokens.scss and mirror it in mereka-overrides.css.
P0 — MFE theming relies on brittle “substring match” selectors that will regress silently with upstream updates
Impact: A minor upstream refactor (classnames, DOM, data-testid changes) can break your layout guardrails (card layouts, image rails, auth screens) without compile-time failure—leading to “looks broken in prod” incidents.
Evidence: infrastructure/tutor/themes/mereka/mfe/mereka.scss targets UI by heuristics like [class*="learning"], [class*="learner-dashboard"], and [data-testid*="course"], which are not stable contracts. This is inherently fragile compared with official MFE extension points (frontend plugin framework slots). 
Exact file path(s):

infrastructure/tutor/themes/mereka/mfe/mereka.scss
Recommendation: Treat this file as a tactical bridge, then migrate “structural UI” changes to official plugin slots wherever possible, using the Frontend Plugin Framework approach (slot replace/insert/hide). 
Acceptance check: For each targeted MFE, list the slot IDs you rely on (footer/header/etc.) and remove at least one brittle selector block once the equivalent slot operation is implemented.
P0 — Your MFE footer customization is not truly “plugin-based”; it depends on patch-level content rewriting
Impact: The footer is part of global UX consistency; if the slot wiring breaks, you lose navigation/support links platform-wide. Because the replacement depends on string-level modifications in a generated env.config.jsx, it is sensitive to upstream config formatting changes.
Evidence: In infrastructure/tutor/plugins/mereka_lms.py, you define MerekaFooter and explicitly rely on apply-patches.sh to replace the default <Footer /> widget with <MerekaFooter /> via slot configuration manipulation (a content-level change). This is exactly the kind of “boundary leak” that creates operational fragility. 
Exact file path(s):

infrastructure/tutor/plugins/mereka_lms.py
infrastructure/tutor/apply-patches.sh
Recommendation: Stop relying on in-place string edits; instead, define the footer replacement as a first-class pluginSlots.footer_slot operation using the supported plugin framework contract. The Open edX docs explicitly describe slot-based replacement as the correct operator workflow. 
Acceptance check: A diff to env.config.jsx should be explainable as pure config, not “find/replace surgery,” and should survive upstream file formatting changes.
P0 — Routing + QA contract mismatch undermines regression detection for authoring MFEs
Impact: When checks don’t match reality, teams either ignore red builds (alert fatigue) or trust green builds that should be red (false confidence). Either way, release risk rises.
Evidence: deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile serves /course-authoring and legacy /authoring from the course-authoring dist directory; meanwhile scripts/qa/verify-mfe-branding.sh maps /course-authoring to "authoring" (legacy) and will fail (or encourage people to “fix the check,” not the system).
Exact file path(s):

deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile
scripts/qa/verify-mfe-branding.sh
Recommendation: Update the QA script route→directory mapping to reflect current routing intent (both /authoring and /course-authoring served by course-authoring), and add a minimal CI job that runs this verification against the committed Caddyfile.
P1 findings
P1 — Contrast failures in core palette usage create accessibility and readability risk
Impact: Users with low vision (and many mobile situations) will struggle to read key UI text; this can be a compliance blocker for partners/funders and increases support burden. WCAG 1.4.3 requires 4.5:1 contrast for normal text (3:1 only for large/bold). 
Evidence: Using your actual token values, #7B7B7B (ink-500) on white is ~4.23:1 and teal #2d898b on surface-primary #FBFAFB is ~3.98:1—both below 4.5:1 for normal text.
Exact file path(s):

infrastructure/tutor/themes/mereka/scss/_tokens.scss
infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css
assets/branding/tokens.css
Recommendation: Introduce an accessibility-reviewed “text on surface” palette tier (e.g., ink-600/650 darker than current ink-500) and restrict teal to accents, borders, and large text. Add an automated contrast audit for your token pairs in CI (simple script is enough).
P1 — Token duplication across three sources increases drift risk
Impact: Anyone making “small brand changes” can easily update one layer and miss the others, producing subtle inconsistencies between LMS/Studio and MFEs.
Evidence: You define token-like values in (a) assets/branding/tokens.css (Figma-exported design tokens), (b) _tokens.scss (Paragon bridge), and (c) runtime CSS mereka-overrides.css (production “brand signal carrier”).
Exact file path(s):

assets/branding/tokens.css
infrastructure/tutor/themes/mereka/scss/_tokens.scss
infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css
Recommendation: Declare one canonical source of truth. Practically: keep assets/branding/tokens.css canonical, generate _tokens.scss + mereka-overrides.css from it, and enforce drift checks in CI.
P1 — Tutor version “truth” is unclear across docs vs pipeline, increasing upgrade risk
Impact: Frontend build breakages tend to appear during Tutor/MFE upgrades (Node, webpack, Paragon, plugin slot structures). If your docs and pipeline disagree on the actual Tutor baseline, upgrades become guesswork.
Evidence: Your CI build workflow pins Tutor to tutor[full]==18.2.2 and tutor-mfe==18.1.0, while some docs imply later Tutor behavior.
Exact file path(s):

.github/workflows/build-tutor-images.yml
docs/architecture/MFE_VERSIONS.md
infrastructure/tutor/MIGRATION_TO_PLUGIN.md
Recommendation: Make one file the “source of operational truth” (ideally docs/architecture/MFE_VERSIONS.md) and have CI verify it by printing Tutor version during builds and failing if it diverges from documented expectations.
P2 findings
P2 — Over-customized “global” elements increase unintended side effects
Impact: Styling .card, .btn-primary, .navbar, etc., globally can unintentionally affect third-party blocks (XBlocks, legacy Studio/Indigo surfaces) where you don’t control markup, creating “whack-a-mole UI.”
Evidence: _tokens.scss and theme.scss apply global element/class styling and deep overrides across multiple surfaces.
Exact file path(s):

infrastructure/tutor/themes/mereka/scss/_tokens.scss
infrastructure/tutor/themes/mereka/scss/theme.scss
Recommendation: Re-scope where possible (e.g., a .mereka-theme root wrapper on pages you control) and prefer token variables over global selector overrides.
P2 — Visual regression scripts exist but don’t prove authenticated user journeys render
Impact: Many important MFE pages require auth; unauthenticated screenshots often capture only the login redirect, masking true regressions.
Evidence: The visual regression approach is primarily screenshot+diff driven; without a login harness, it will not validate learner dashboard/courseware correctness.
Exact file path(s):

scripts/qa/visual-regression-test.sh
scripts/qa/visual-regression-branding.sh
Recommendation: Add an authenticated smoke harness (even a single test user + cookie injection) for 3–5 critical routes, then use those screenshots for visual diffing.
What is done vs what remains for plugin-first migration
Your repo reflects the Open edX community direction: move branding/customization away from ad-hoc patches toward supported extension points like brand packages and plugin slots. OEP-48 formalizes the “brand package” approach for MFEs and shared theming. 

Done (credible progress):

A consolidated Tutor plugin exists and is clearly intended as the “configuration brain” (infrastructure/tutor/plugins/mereka_lms.py), aligning with Tutor’s hooks/patch patterns and the tutor-mfe guidance around ENV_PATCHES for MFE customization. 
MFEs are being themed using Paragon variable bridging and a consistent palette/typography strategy, which aligns with the goal of cross-surface branding (LMS/Studio + MFEs). 
CI validates that branded assets are actually present in built images (a strong operational control).
Remaining (the true blockers to “plugin-first” meaningfully reducing risk):

Eliminate patch-level string rewriting for MFE slot behavior and convert it into explicit frontend-plugin-framework slot configuration (replace/hide/insert). This is the supported mechanism for swapping portions of MFE UI. 
Reduce dependence on brittle CSS heuristics by shifting from DOM-chasing selectors to stable extension points (slots, brand package variables, Paragon token mechanisms). 
Align QA scripts with routing + expected dist directories so the “verification layer” becomes trustworthy again.
Three-sprint frontend roadmap
Sprint A
Milestones:

Fix the missing token variable bug (--mereka-color-ink-600) and add a minimal token validation script that fails CI if CSS variables referenced in theme files are undefined.
Update scripts/qa/verify-mfe-branding.sh to match current MFE routing directory structure (course-authoring) and add a CI job that runs it.
Add an accessibility “quick gate” for contrast: validate key text-on-surface pairs meet WCAG 1.4.3 contrast minimum requirements. 
Acceptance checks:

CI fails if any referenced CSS variable is undefined.
CI fails if MFE authoring routes don’t match expected dist roots.
Contrast checker script passes for your defined “body text” token pair.
Sprint B
Milestones:

Implement footer replacement using frontend plugin framework slot operations (no string surgery). 
Reduce MFE brittle selectors by at least 30% by replacing them with slot-based customizations and/or scoped wrappers.
Add basic keyboard/focus audit rules (no outline: none unless replaced by a visible focus style with adequate contrast).
Acceptance checks:

A diff shows the footer customization is purely slot config (replace/hide/insert), not DOM-chasing CSS or generated-file rewriting.
Axe (or equivalent) reports no new serious focus/label/landmark regressions on login + one authenticated page.
Documented slot IDs used and why.
Sprint C
Milestones:

Move toward an OEP-48-aligned brand packaging model for MFEs (or at minimum, a single canonical token source that generates the rest). 
Add authenticated UI smoke + visual regression for 3–5 critical routes (learner dashboard, learning, profile/account, course-authoring entry).
Add performance budget checks: ensure MFE HTML is not cached incorrectly and static assets can be cached immutably (verify via headers in staging).
Acceptance checks:

Tokens have a single source-of-truth with automated generation or strict drift detection.
Authenticated screenshots stabilize and catch at least one seeded regression during a test PR.
Headers verified in staging align with “no-cache for HTML, long-cache for hashed assets.”
Merge now, fix before merge, defer
Merge now:

Treat main as the sole baseline. The worktree branch you referenced appears not to carry unique frontend fixes anymore; standardize review and delete/archive stale branches to avoid “phantom diffs.”
Keep scripts/qa/verify-custom-app-drift.sh and wire it into CI where appropriate (it meaningfully prevents a common class of runtime failures).
Fix before merge:

Fix --mereka-color-ink-600 usage or define it properly (this is a correctness issue, not a stylistic preference).
Update scripts/qa/verify-mfe-branding.sh to match current MFE routing for authoring/course-authoring.
Address WCAG contrast failures for your default text tokens (this is measurable and will improve UX immediately). 
Replace the MFE footer via official slot operations rather than patch-level string rewriting. 
Defer:

Full OEP-48 brand package formalization (worth doing, but best after the immediate correctness + QA alignment work is stable). 
Large-scale MFE CSS refactors beyond the “top brittle blocks” until slot-based customization is in place.
Where to look first in GitHub
Start with:

The compare view you listed (but re-validate that it still contains unique changes; currently it appears the practical changes are already in main).
infrastructure/tutor/plugins/mereka_lms.py for: MFE theme import, footer strategy, and the plugin-vs-script boundary.
infrastructure/tutor/apply-patches.sh for: any remaining string rewrite operations and filesystem sync that still define frontend correctness.
deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile for: MFE routing correctness and compatibility for /authoring vs /course-authoring.
infrastructure/tutor/themes/mereka/ for: token bridge (scss/_tokens.scss), LMS/Studio runtime overrides (*/static/css/mereka-overrides.css), and MFE override strategy (mfe/mereka.scss).
scripts/qa/verify-mfe-branding.sh + scripts/qa/visual-regression-*.sh for: whether your regression protection actually matches the real risk surface.
.github/workflows/build-tutor-images.yml for: what CI truly guarantees today (branding presence and image integrity) versus what it does not (UX correctness, a11y conformance, authenticated rendering).