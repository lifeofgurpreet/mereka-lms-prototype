# Staging Runtime Convergence Evidence Bundle

> Environment: stg-mereka-lms (rke2-nonprod, shared with mereka-lms-dev)
> Bundle version: v1
> Generated: 2026-03-26
> Owner: Platform Team (convergence evidence)
> Status: SUBSTANTIALLY SATISFIED -- primary path and enterprise services CONFIRMED; remaining gaps are CSP multi-tenant, admin portal authenticated proof, and MFE Config BASE_URL alignment

## Executive Classification

The staging runtime environment is **materially stabilized for the primary tenant path but not fully convergence-ready**.

**What works**: SSO authentication via Authentik (browser-proven by CI canary), host acceptance for all 3 tenants across all 3 surfaces (9/9), SiteConfiguration seeded and verified, MFE Config API returning correct per-tenant URLs, cookie middleware active with correct domain resolution, Studio OAuth2 flow operational, ArgoCD sync healthy, TLS certificates valid for all tenants including Biji-Biji staging.

**What is still open**: Enterprise services are deployed and healthy (all 4 backends return OK, both MFE portals return HTTP 200, 4 migration Jobs completed), but authenticated enterprise portal sessions have not been browser-tested end-to-end. Synthetic test fixtures have not been provisioned on staging. CSP for secondary tenants blocks cross-origin MFE requests to their own LMS backends. The MFE Config API BASE_URL for the Mereka primary tenant has a Convention A/B mismatch warning. Third-party vendor images (caddy, credentials, discovery, ecommerce, elasticsearch) lack SHA256 digest pins; all first-party images are pinned.

**What was contradicted**: Earlier experience-proof runs showed critical failures (CSP violations, brand wiring empty, homepage layout degraded) that were superseded by later runs showing the same surfaces passing. The contradictions are recorded below.

## Hostname Convention Context

Staging uses a **mixed convention** that is intentional and documented (PR #1034):

| Tenant | Convention | LMS | MFE |
|--------|-----------|-----|-----|
| Mereka (primary) | Convention A | `staging.academyv2.mereka.io` | `staging.apps.academyv2.mereka.io` |
| Biji-Biji (secondary) | Convention B | `staging.academy.biji-biji.com` | `apps.staging.academy.biji-biji.com` |
| Skill Our Future (secondary) | Convention B | `staging.skillourfuture.academy.mereka.io` | `apps.staging.skillourfuture.academy.mereka.io` |

Convention A: `staging.{role}.{domain}`. Convention B: `{role}.staging.{domain}`.

The mixed convention is the deployed reality across DNS, TLS, ingress, ALLOWED_HOSTS, and Caddy. The repo contract was aligned to this reality in PR #1034 (18 files updated). Compatibility aliases for service hosts exist during a migration window.

## Claim Lineage Table

### Browser / Auth Truth

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| BA1 | SSO canary PASSED on staging (full OIDC round-trip via Authentik) | GitHub Actions run 23582180752; commit `b3df37fc` records evidence | CONFIRMED | DURABLE | -- | Yes |
| BA2 | LMS OIDC flow completes through `staging.auth0.mereka.io` (Authentik) | GitHub Actions run 23582180752 (sso-canary job, all steps green) | CONFIRMED | DURABLE | -- | Yes |
| BA3 | Studio SSO OAuth2 token exchange works | `var/proof/staging-experience-proof.json` (EXP-08-mereka: HTTP 200, correct OAuth2 redirect chain); PR #1038 (CMS `LMS_INTERNAL_ROOT_URL` fixed) | CONFIRMED | DURABLE | -- | Yes |
| BA4 | `SESSION_COOKIE_SECURE = True` on live staging pod | `DEV_STAGING_TRUTH_TRACKER_2026-03-25.md` (verified on live pod) | CONFIRMED | DURABLE | -- | Yes |
| BA5 | `SESSION_COOKIE_SAMESITE = None` (correct for OIDC redirect chain) | `var/proof/staging-runtime-proof-session3-final.json` (`SESSION_COOKIE_SAMESITE: "None"` from `runtime_verification_session3_night.settings`); user attestation | CONFIRMED | DURABLE | -- | Yes |
| BA6 | Auth redirect correct for all 3 tenants | `var/proof/staging-auth-redirect-proof.json` (3/3 correct); `var/proof/staging-experience-proof.json` (EXP-06 PASS for all 3 tenants) | CONFIRMED | DURABLE | -- | Yes |
| BA7 | Auth page renders and login form is interactive for primary tenant (Mereka) | `var/proof/staging-experience-proof.json` (EXP-01-mereka: PASS, "Login form usable in 4.48s") | CONFIRMED | DURABLE | Earlier rerun proof `staging-experience-proof-rerun` showed EXP-01-mereka FAIL (CSP logo block), superseded by later proof showing PASS | Yes |
| BA8 | Auth page renders for secondary tenants (Biji-Biji, SOF) but has CSP violations | `var/proof/staging-experience-proof.json` (EXP-01-biji-biji: PASS status, but `failed_requests` lists 4 CSP-blocked requests; EXP-01-skillourfuture: PASS status with 4 CSP-blocked requests) | PROVISIONAL | DURABLE (login form works, CSP blocks are non-fatal for form usability) | The CSP `connect-src` only allows `staging.academyv2.mereka.io` -- secondary tenant LMS hosts are blocked. This is a known multi-tenant CSP gap, not a staging-specific regression. | No -- CSP for secondary tenants needs fix |

### Host / Tenant Truth

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| HT1 | Host acceptance 9/9 (all 3 tenants x 3 surfaces: LMS, Studio, MFE) | `var/proof/staging-proof-summary.json` (host_acceptance: "9/9", collected 2026-03-26T05:30:18Z) | CONFIRMED | DURABLE | Earlier probe showed 5/9 (pre-PR #1034 hostname fix). Superseded by 9/9 post-fix. | Yes |
| HT2 | SiteConfiguration seeded and enabled for all 3 staging tenants | `var/proof/staging-siteconfig-proof.json` (3 entries: site_exists=true, sc_exists=true, sc_enabled=true, correct LMS_ROOT_URL, CMS_ROOT_URL, MFE_BASE_URL for each) | CONFIRMED | DURABLE | -- | Yes |
| HT3 | MFE Config API returns correct per-tenant URLs | `var/proof/staging-mfe-config-proof.json` (3 entries, biji-biji and skillourfuture status "ok", mereka status "warning") | PROVISIONAL | DURABLE | Mereka primary tenant returns `BASE_URL: "apps.staging.academyv2.mereka.io"` (Convention B) but expected `"staging.apps.academyv2.mereka.io"` (Convention A). MFE authn still works at Convention A URL despite the config mismatch. | No -- BASE_URL value needs Convention A alignment or explicit acceptance |
| HT4 | Convention A/B mixed convention is intentional and documented | PR #1034 (merged, commit `190d6a2c`), PR #1040, PR #1039 | CONFIRMED | DURABLE | -- | Yes |
| HT5 | TLS certificates valid for all 3 tenant domains | `DEV_STAGING_TRUTH_TRACKER_2026-03-25.md`: Biji-Biji staging certs Ready=True (notAfter 2026-06-24), mereka staging cert valid (notAfter 2026-06-05 per browser proof) | CONFIRMED | DURABLE | -- | Yes |
| HT6 | Tenant page titles correct but welcome text shows "Mereka Academy" for all tenants | `var/proof/staging-browser-visual-proof.json`: biji-biji title="Biji-Biji Academy" but welcome_text="Welcome to Mereka Academy"; skillourfuture title="Skill Our Future" but welcome_text="Welcome to Mereka Academy" | CONFIRMED | DURABLE (this is a branding/template issue, not a routing issue) | -- | Yes (with documented caveat: tenant welcome text customization is deferred branding work, not a convergence blocker) |

### Cookie / Middleware Truth

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| CM1 | `MerekaCookieDomainMiddleware` is active at position 19, before `SafeSessionMiddleware` (20) | `var/proof/staging-runtime-proof-session3-final.json` (middleware section) | CONFIRMED | DURABLE | -- | Yes |
| CM2 | Cookie domain resolution correct for all tenant surfaces | `var/proof/staging-runtime-proof-session3-final.json`: mereka=`.academyv2.mereka.io`, biji-biji=`.academy.biji-biji.com`, skillourfuture=`.skillourfuture.academy.mereka.io` | CONFIRMED | DURABLE | -- | Yes |
| CM3 | 7-cookie middleware scope covers all required cookies | `var/proof/staging-runtime-proof-session3-final.json`: sessionid, csrftoken, edx-jwt-cookie-header-payload, edx-jwt-cookie-signature, edxloggedin, edx-user-info, openedx-language-preference | CONFIRMED | DURABLE | -- | Yes |
| CM4 | `SHARED_COOKIE_DOMAIN = None` (no cross-tenant cookie leakage) | `var/proof/staging-runtime-proof-session3-final.json` (settings.SHARED_COOKIE_DOMAIN: "None") | CONFIRMED | DURABLE | -- | Yes |

### Runtime Infrastructure Truth

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| RI1 | ArgoCD app `mereka-lms-staging` is Synced/Healthy | `DEV_STAGING_TRUTH_TRACKER_2026-03-25.md`: "mereka-lms-staging is now Synced / Progressing at revision b8c4ab0a" (updated to Healthy after reconciliation) | CONFIRMED | DURABLE | -- | Yes |
| RI2 | CMS `LMS_INTERNAL_ROOT_URL` set to `https://staging.academyv2.mereka.io` (fixed from `http://localhost`) | PR #1038 (merged); `var/proof/staging-runtime-proof-session3-final.json` (settings.LMS_ROOT_URL) | CONFIRMED | DURABLE | -- | Yes |
| RI3 | MFE logo MIME type fixed (`text/css` -> `image/svg+xml`) | PR #1051 (merged, commit `4c4b4e30`): removed forced `text/css` Content-Type on `/theme/*` | CONFIRMED | DURABLE | -- | Yes |
| RI4 | LMS heartbeat OK (modulestore=OK, sql=OK) | `var/proof/staging-runtime-proof-session3-final.json` (lms_heartbeat: "OK") | CONFIRMED | DURABLE | -- | Yes |
| RI5 | CMS heartbeat OK (modulestore=OK, sql=OK) | `var/proof/staging-runtime-proof-session3-final.json` (cms_heartbeat: "OK") | CONFIRMED | DURABLE | -- | Yes |
| RI6 | `DEFAULT_SITE_THEME = mereka` is live | `var/proof/staging-runtime-proof-session3-final.json` (settings.DEFAULT_SITE_THEME: "mereka"); bbi-infrastructure PR #1422 (merged) | CONFIRMED | DURABLE | -- | Yes |
| RI7 | Staging DB migrations clean (0 pending) | `var/proof/staging-runtime-proof-session3-final.json` (migration_truth.staging.pending: 0) | CONFIRMED | DURABLE | -- | Yes |

### GitOps Truth

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| GO1 | All runtime fixes deployed via ArgoCD (not kubectl apply) | `DEV_STAGING_TRUTH_TRACKER_2026-03-25.md`: ArgoCD synced, all bbi-infrastructure PRs merged (#2125, #2127, #2128, #2129, #2131, #2132, #2135, #2137) | CONFIRMED | DURABLE | -- | Yes |
| GO2 | No manual patches required for basic LMS/CMS/MFE function on staging | Staging pods restart cleanly via ArgoCD; cookie middleware, theme, LMS_INTERNAL_ROOT_URL are all codified in GitOps overlays | CONFIRMED | DURABLE | -- | Yes |
| GO3 | cert-manager-dev is Synced/Healthy with Biji-Biji staging issuer | `DEV_STAGING_TRUTH_TRACKER_2026-03-25.md`: ClusterIssuer `letsencrypt-bijibiji-staging` Ready=True, reason=ACMEAccountRegistered; bbi-infrastructure PR #2131 merged | CONFIRMED | DURABLE | -- | Yes |

### Admin Portal (Enterprise)

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| AP1 | Enterprise admin portal renders (HTTP 200) at `admin.staging.academyv2.mereka.io` | `var/proof/staging-experience-proof.json` (SEC-enterprise-admin: PASS, HTTP 200) | CONFIRMED | DURABLE | -- | Yes |
| AP2 | Admin user can authenticate via SSO | BA1 + BA2 (SSO canary proves OIDC round-trip on staging). However, admin portal authenticated session is not independently verified -- SSO canary tests LMS, not admin portal. | PROVISIONAL | MANUAL_STATE | SSO canary proves LMS login, not enterprise admin portal login specifically. | No -- needs admin-portal-specific authenticated browser proof |
| AP3 | Admin portal shows enterprise data | NOT VERIFIED via authenticated browser session. Enterprise backend services are deployed and healthy (catalog/access/subsidy/license-manager all return `{"overall_status":"OK"}`), but enterprise data visibility requires an authenticated admin portal session which has not been run. | PROVISIONAL | MANUAL_STATE | Services are up but authenticated enterprise data path is untested in browser. | No -- needs authenticated admin portal browser proof |

### Learner Portal -- Primary Path

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| LP1 | LMS homepage renders for all 3 tenants (HTTP 200) | `var/proof/staging-experience-proof.json` (EXP-04: PASS for all 3 tenants); `var/proof/staging-browser-visual-proof.json` (homepage HTTP 200) | CONFIRMED | DURABLE | Earlier browser-visual-proof noted client-side JS redirect to `academyv2.mereka.dev` (returning 502). However, the later experience-proof runs show homepage rendering correctly via curl (HTTP 200, domcontentloaded OK). The JS redirect is a branding/configuration issue, not a routing failure. | Yes (with caveat: client-side JS redirect exists in some browser contexts) |
| LP2 | Learner can reach authentication page via SSO (login redirect works) | BA6 (auth redirect correct 3/3); BA1 + BA2 (SSO canary PASS) | CONFIRMED | DURABLE | -- | Yes |
| LP3 | Dashboard redirect to MFE authn login works | `var/proof/staging-experience-proof.json` (EXP-06-mereka: PASS, redirect to authn/login?next=%2Fdashboard); `var/proof/staging-browser-visual-proof.json` (dashboard correctly redirects to login with ?next=/dashboard) | CONFIRMED | DURABLE | -- | Yes |
| LP4 | Search/courses page renders | `var/proof/staging-browser-visual-proof.json` (courses page HTTP 200, "Courses | Mereka Academy" title, course search box present, empty catalog expected) | CONFIRMED | DURABLE | -- | Yes |

### Learner Portal -- Secondary Path

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| LS1 | Enterprise learner portal renders (HTTP 200) at `learner.staging.academyv2.mereka.io` | `var/proof/staging-experience-proof.json` (SEC-enterprise-learner: PASS, HTTP 200) | CONFIRMED | DURABLE | -- | Yes (non-critical check -- enterprise content not verified) |
| LS2 | Learner portal authenticated enterprise paths | Enterprise backend services are deployed and healthy. Enterprise learner portal returns HTTP 200. Authenticated enterprise paths (enrollment, course catalog with enterprise license) have not been browser-tested with a real enterprise license. | PROVISIONAL | MANUAL_STATE | Services deployed and reachable; end-to-end authenticated learner enterprise path not yet browser-verified. | No -- needs authenticated enterprise learner path browser proof |

### Build Truth

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| BT1 | First-party staging images have SHA256 digest pins | Verified live 2026-03-26: CMS/LMS `ghcr.io/.../openedx:d7f015d2@sha256:788964d7...`; enterprise-access `@sha256:5315667f...`; enterprise-catalog `@sha256:5ef5ee4b...`; enterprise-subsidy `@sha256:2d701f8f...`; enterprise-admin-portal `@sha256:853ce591...`; enterprise-learner-portal `@sha256:185bbcc3...` | CONFIRMED | DURABLE | Third-party vendor images lack digest pins (caddy:2.7.4, credentials:21.0.0, discovery:21.0.1, ecommerce:19.0.0, elasticsearch:7.17.13). Vendor images are the known exception. | Yes (first-party images confirmed; vendor image gap is documented) |
| BT2 | MFE images built from explicit source tags (not :latest) | Verified live 2026-03-26: enterprise-admin-portal and enterprise-learner-portal both use `@sha256:...` digest pins. Inherited from dev build contract (`docs/stabilization/ENTERPRISE_MFE_BUILD_CONTRACT.md`); the same build pipeline produces staging images. | CONFIRMED | DURABLE | -- | Yes |
| BT3 | OpenEdX image `8a556621` built and pushed to GHCR | `var/proof/staging-runtime-proof-session3-final.json` (workstream_c_image_build: openedx_status SUCCESS, head_sha 8a556621) | CONFIRMED | DURABLE | -- | Yes |

### Image Truth

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| IT1 | All deployed staging images traceable to source | Verified live 2026-03-26: first-party images include both the git SHA tag (e.g. `openedx:d7f015d2`) and a SHA256 digest pin, providing a two-anchor traceability chain from source commit to deployed image. | CONFIRMED | DURABLE | Third-party vendor images traceable to upstream version tag but not to a source commit (expected, no digest pin). | Yes (first-party images; vendor images are documented exception) |
| IT2 | No floating tags in staging deployment manifests (first-party images) | Verified live 2026-03-26: all first-party images use SHA-tagged refs with digest pins. Vendor images use version tags (e.g. `caddy:2.7.4`) without digest pins -- these are the known and accepted exception. | CONFIRMED | DURABLE | Vendor images (caddy, credentials, discovery, ecommerce, elasticsearch) use version tags without digest pins. This is a documented gap, not an architectural regression. | Yes (with documented vendor-image exception) |

### Data-Layer Truth

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| DL1 | Synthetic test fixtures NOT provisioned on staging | User attestation | PARKED | -- | -- | No -- enterprise services are deployed but test fixtures have not been provisioned |
| DL2 | Enterprise catalog both-sides NOT populated on staging | User attestation. Enterprise services are deployed and healthy, but enterprise catalog content (programs, courses linked to enterprise) has not been seeded for staging. | PARKED | -- | -- | No -- enterprise catalog data not yet seeded for staging |

## Contradicted Truths -- Must Stay Open

| Earlier Claim | Source | Contradicted By | Correction |
|--------------|--------|----------------|-----------|
| EXP-01-mereka FAIL (CSP logo block on auth page) | `var/proof/staging-experience-proof-rerun/staging-experience-proof.json` (2026-03-09T07:05) | `var/proof/staging-experience-proof.json` (2026-03-09T11:58): EXP-01-mereka PASS, "Login form usable in 4.48s" | Later proof shows auth page working. CSP logo block may have been transient or fixed by deployment between runs. |
| EXP-02 Brand wiring empty (`PARAGON_THEME.brand.themeUrls.core.fileName` empty) for all tenants | `var/proof/staging-experience-proof-rerun/staging-experience-proof.json` (2026-03-09T07:05) | `var/proof/staging-experience-proof.json` (2026-03-09T11:58): EXP-02 PASS, `brand.themeUrls.core.fileName=../theme/mereka-brand.min.css` | Brand wiring resolved between the two proof runs. |
| Homepage layout degraded (course cards 61px wide, "collapsed into strips") | `var/proof/staging-experience-proof-rerun/staging-experience-proof.json` (EXP-04-mereka FAIL) | `var/proof/staging-experience-proof.json` (EXP-04-mereka PASS, "HTTP 200, domcontentloaded OK") | Later proof does not show layout degradation. However, the later proof uses a different check (domcontentloaded) rather than card width measurement. The contradiction is partially resolved -- homepage renders but layout quality is not re-measured. |
| Staging tenant proof was 5/9 on corrected host matrix | `DEV_STAGING_TRUTH_TRACKER_2026-03-25.md` (recorded at 2026-03-25T15:28) | `var/proof/staging-proof-summary.json` (2026-03-26T05:30): host_acceptance 9/9 | Later proof at 2026-03-26 shows 9/9 after infra runtime fixes from bbi-infrastructure PRs #2127, #2128, #2131 were deployed. |
| Staging browser auth "not canonically closed" | `DEV_STAGING_TRUTH_TRACKER_2026-03-25.md` | GitHub Actions run 23582180752 (2026-03-26): SSO canary PASS on staging. Commit `b3df37fc` records this. | SSO canary now provides tracked, CI-level browser auth evidence. |
| MFE `BASE_URL` for Mereka uses Convention B (`apps.staging.academyv2.mereka.io`) | `var/proof/staging-mfe-config-proof.json` (mereka status: "warning") | NOT RESOLVED. The SiteConfiguration `MFE_CONFIG.BASE_URL` value uses Convention B while the deployed MFE host uses Convention A. This is a cosmetic mismatch -- MFE authn works at the Convention A URL. | Contradiction remains open. Mereka tenant MFE config BASE_URL needs alignment. |

## Durable Truths -- Promotable Now

These claims have merged fixes, verified deployments, and no contradictions:

1. **SSO authentication works on staging** -- OIDC round-trip via Authentik proven by CI canary (BA1, BA2)
2. **Host acceptance 9/9** -- all 3 tenants x 3 surfaces accept requests (HT1)
3. **SiteConfiguration seeded and correct** -- 3 tenants, all enabled, correct URLs (HT2)
4. **Cookie middleware active and correct** -- MerekaCookieDomainMiddleware at position 19, correct domain resolution, 7-cookie scope, no cross-tenant leakage (CM1-CM4)
5. **Auth redirects correct for all tenants** -- LMS `/login` redirects to correct tenant MFE authn URL (BA6)
6. **Studio SSO works** -- OAuth2 token exchange operational, CMS LMS_INTERNAL_ROOT_URL fixed (BA3, RI2)
7. **ArgoCD sync healthy** -- all runtime fixes deployed via GitOps, no manual patches for basic function (GO1, GO2, RI1)
8. **TLS certificates valid** -- all tenant domains covered, including Biji-Biji staging via dedicated issuer (HT5, GO3)
9. **LMS and CMS heartbeats OK** -- modulestore and SQL healthy (RI4, RI5)
10. **Theme and branding active** -- `DEFAULT_SITE_THEME=mereka`, `MerekaCookieDomainMiddleware` live (RI6)
11. **DB migrations clean** -- 0 pending (RI7)
12. **Homepage and courses pages render** -- HTTP 200 for all tenants (LP1, LP4)
13. **Enterprise services deployed and healthy** -- all 4 backends (catalog, access, subsidy, license-manager) return `{"overall_status":"OK"}`, both MFE portals return HTTP 200, 4 migration Jobs completed (verified 2026-03-26) (AP1, AP3-partial, LS1, LS2-partial)
14. **First-party images have SHA256 digest pins** -- CMS, LMS, enterprise-access, enterprise-catalog, enterprise-subsidy, enterprise-admin-portal, enterprise-learner-portal all pinned with `@sha256:...` (BT1, BT2, IT1, IT2-partial)

## Provisional Truths -- Awaiting Promotion

These claims need additional evidence or specific verification:

1. **HT3 -- MFE Config API BASE_URL mismatch for Mereka tenant**: Convention B value returned but Convention A expected. MFE authn works despite mismatch. Needs explicit Convention A alignment or documented acceptance.
2. **BA8 -- Secondary tenant CSP blocks**: MFE `connect-src` / `img-src` CSP only allows `staging.academyv2.mereka.io`. Secondary tenant LMS hosts (`staging.academy.biji-biji.com`, `staging.skillourfuture.academy.mereka.io`) are blocked by CSP. Login form still works but CSRF token fetch and logo loading fail. Needs CSP multi-tenant fix.
3. **AP2 -- Admin portal authenticated session**: SSO canary proves LMS login, not admin portal login. Needs admin-portal-specific auth proof.
4. **AP3 -- Admin portal enterprise data visibility**: Enterprise services are deployed and healthy. Authenticated admin portal session showing enterprise data not yet browser-proven.
5. **LS2 -- Enterprise learner portal authenticated paths**: Enterprise services deployed. End-to-end authenticated enterprise learner flow not yet browser-proven.
6. **IT2 -- Vendor image digest pins**: First-party images have SHA256 digest pins (CONFIRMED). Vendor images (caddy, credentials, discovery, ecommerce, elasticsearch) still use version tags without digest pins.

## Parked Claims -- Explicitly Deferred

These are intentionally not evaluated for this phase gate:

| # | Claim | Why Parked |
|---|-------|-----------|
| DL1 | Synthetic test fixtures on staging | Enterprise services are deployed; test fixtures not yet provisioned |
| DL2 | Enterprise catalog both-sides populated on staging | Enterprise services deployed; catalog data not yet seeded for staging |
| LP1-caveat | Client-side JS redirect to `academyv2.mereka.dev` | Branding/config issue, not routing. Sub-paths work. Deferred. |

## Exact Blockers: Stabilization -> Convergence (Staging)

| # | Blocker | Owner | What Unblocks It |
|---|---------|-------|-----------------|
| BLK-S1 | Admin portal authenticated browser proof | Lane A | Run admin-portal-specific authenticated browser proof on staging (enterprise backend services are deployed and healthy) |
| BLK-S2 | Vendor image digest pinning (caddy, credentials, discovery, ecommerce, elasticsearch) | Release Evidence Owner | Pin third-party vendor images to SHA256 digest refs in staging overlay; first-party images already pinned |
| BLK-S3 | CSP multi-tenant gap (secondary tenant hosts blocked) | App Owner (mereka-lms) | Add secondary tenant LMS hosts to MFE CSP `connect-src` / `img-src` directives |
| BLK-S4 | MFE Config BASE_URL Convention A/B mismatch for Mereka tenant | App Owner (mereka-lms) | Align SiteConfiguration `MFE_CONFIG.BASE_URL` to Convention A, or document acceptance of Convention B as intentional |
| BLK-S5 | Synthetic fixture creation on staging | Data-Layer Owner | Script-based enterprise catalog + fixture provisioning (services are deployed; data layer needs seeding) |
| BLK-S6 | Authenticated enterprise learner path browser proof | Lane A | Run end-to-end enterprise learner flow with real enterprise license (services deployed, path untested in browser) |

## What Staging Proves That Dev Did Not

1. **CI-tracked SSO canary** -- staging has a passing GitHub Actions run (23582180752) with 30-day artifact retention. Dev had local proof only at the time of its bundle.
2. **Convention A/B documentation and alignment** -- 18-file hostname contract repair (PR #1034) resolved the mixed convention with explicit documentation. Dev bundle did not face this ambiguity.
3. **Cross-repo infra fixes merged and synced** -- bbi-infrastructure PRs #2125, #2127, #2128, #2129, #2131, #2132, #2135, #2137 are all merged and ArgoCD-synced. Dev bundle had pending PRs.
4. **Biji-Biji TLS resolution** -- dedicated `letsencrypt-bijibiji-staging` ClusterIssuer with cert-manager-dev synced. Dev bundle did not cover this.

## What This Bundle Does NOT Claim

- Do NOT claim enterprise portal authenticated session convergence readiness (services are deployed and healthy, but authenticated browser paths through the admin portal and enterprise learner flow have not been browser-proven)
- Do NOT claim vendor image digest pinning (caddy, credentials, discovery, ecommerce, elasticsearch use version tags without digest pins; first-party images ARE pinned)
- Do NOT claim CSP is fully correct for multi-tenant MFE (secondary tenant LMS hosts blocked by CSP `connect-src`)
- Do NOT claim enterprise catalog data is seeded on staging (services deployed, data not populated)
- Do NOT claim synthetic fixtures exist on staging (not provisioned)
- Do NOT claim convergence gate is fully satisfied from this bundle alone (see blockers)

## Evidence Source Cross-References

### Merged PRs (mereka-lms)

| PR | Title | Relevance |
|----|-------|-----------|
| #1034 | fix(staging): resolve hostname convention split -- tenant proof 9/9 | HT1, HT4 |
| #1035 | fix(release): add closure_level to proof artifacts | Build truth |
| #1038 | docs(staging): close T-02 (cookie fix runtime-verified) + T-07 Notes 400 | RI2, CM1-CM4 |
| #1039 | fix(staging): linter-applied hostname fixes + staging alignment gate | HT4 |
| #1040 | fix(staging): remaining Convention A alignment in docs + QA | HT4 |
| #1041 | feat(staging): add staging SSO canary surface for browser proof | BA1 |
| #1043 | docs(ui): close UI-01 through UI-04 with live runtime proof | Branding |
| #1044 | fix(a11y): mobile footer tap targets meet 44px WCAG minimum | LP1 |
| #1047 | fix(ci): remove --with-deps from Playwright install on ARC runners | BA1 CI support |
| #1048 | fix(staging): align runtime gates with live contract | GO1, RI1 |
| #1049 | fix(ci): auto-regenerate verification catalog via pre-commit hook | CI |
| #1050 | fix(ci): increase sso-canary timeout to 20 min | BA1 CI support |
| #1051 | fix(mfe): remove forced text/css Content-Type on /theme/* | RI3 |
| #1052 | docs(ui): make browser-proof handoff reproducible | LP1 |
| #1053 | fix(credentials): harden zoneinfo runtime contract | RI4-RI5 |
| #1054 | fix(cms): admit skillourfuture studio host | HT1 |
| #1055 | (recent staging/QA alignment) | Various |

### Merged PRs (bbi-infrastructure)

| PR | Title | Relevance |
|----|-------|-----------|
| #2125 | Staging runtime fixes (initial) | GO1 |
| #2127 | Secondary host runtime truth alignment | HT1 |
| #2128 | Staging overlay/certificate/domain-registry alignment | HT5, GO3 |
| #2129 | Staging runtime support | GO1 |
| #2131 | Biji-Biji staging TLS issuer realization | GO3, HT5 |
| #2132 | Staging infrastructure alignment | GO1 |
| #2135 | Staging runtime fixes | GO1 |
| #2137 | Staging fixes | GO1 |

### Proof Artifacts (var/proof/, local input only)

| File | Collected | Use |
|------|-----------|-----|
| `staging-proof-summary.json` | 2026-03-26T05:30:18Z | HT1 (host acceptance 9/9) |
| `staging-runtime-proof.json` | 2026-03-08T23:37:46Z | HT2, HT3, BA6 (SiteConfig, MFE Config, auth redirect) |
| `staging-runtime-proof-session3-final.json` | 2026-03-10T08:25:00+08:00 | CM1-CM4, RI2, RI4-RI7, BA5, BT3 |
| `staging-experience-proof.json` | 2026-03-09T11:58:19Z | BA7, BA8, LP1, AP1, LS1 |
| `staging-browser-visual-proof.json` | 2026-03-09T16:00:00+08:00 | LP1, LP3, LP4, HT6 |
| `staging-siteconfig-proof.json` | (matches runtime-proof) | HT2 |
| `staging-mfe-config-proof.json` | (matches runtime-proof) | HT3 |
| `staging-auth-redirect-proof.json` | (matches runtime-proof) | BA6 |

### CI Evidence (canonical, non-local)

| Run ID | Job | Date | Result |
|--------|-----|------|--------|
| 23582180752 | SSO Canary (staging) | 2026-03-26 | PASS, all steps green, artifacts uploaded with 30-day retention |

## Phase Gate Assessment

### Stabilization -> Convergence: SUBSTANTIALLY SATISFIED for staging

| Gate Requirement | Status | Evidence |
|-----------------|--------|----------|
| Repo-side stabilization contracts merged and current | CONFIRMED | Control board cites all contracts as merged |
| Canonical runtime/browser evidence bundle merged | THIS DOCUMENT (pending merge) | -- |
| Primary learner path classified | CONFIRMED | LP1-LP4 |
| Secondary learner path classified | PROVISIONAL | LS1 confirmed (renders); LS2 provisional (services deployed, authenticated enterprise path not browser-tested) |
| Manual runtime mitigations removed or recorded | CONFIRMED | No manual patches required for basic function (GO2) |
| Immutable image refs (first-party) | CONFIRMED | BT1-BT3 (first-party images have SHA256 digest pins; vendor images are documented exception) |
| Enterprise services deployed and healthy | CONFIRMED | All 4 backends return OK; both MFE portals HTTP 200; 4 migration Jobs completed (verified 2026-03-26) |
| Enterprise authenticated paths browser-proven | PROVISIONAL | Services deployed; admin portal and enterprise learner authenticated sessions not yet browser-verified |

**Verdict**: Staging is significantly further along than dev was at its bundle time. The primary path is CONFIRMED across all dimensions (auth, host, cookie, GitOps, runtime). Enterprise services are deployed and healthy. The remaining blockers are concentrated in authenticated enterprise portal browser proof and vendor image digest pinning. These are verification gaps, not architectural gaps.
