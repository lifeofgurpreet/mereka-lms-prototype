# Orphan Script Shortlist

Scripts that exist in `scripts/` but are **not** registered in
`scripts/governance/script-registry.yaml` AND **not** listed in
`.github/ci-scripts-static.txt`.

Nobody currently runs these in CI or release automation. Each entry carries
a disposition: **REGISTER** (operational value, add to registry), **ARCHIVE**
(move to `docs/archive/`), or **DELETE** (no lasting value).

Generated against: 818 total scripts / 29 registered / 446 in CI list.
Orphan count: 350. This shortlist covers scripts with non-trivial operational
surface — trivial library sourced-helpers (`scripts/shared/`) are noted but
grouped at the bottom.

---

## scripts/infra — Infrastructure / Operations

| Script | Purpose | Disposition |
|--------|---------|-------------|
| `scripts/infra/backup-db.sh` | Export Cloud SQL databases to GCS; wraps `gcloud sql export`. Used as a pre-operation backup step in many other scripts. | **REGISTER** |
| `scripts/infra/argocd-refresh.sh` | Forces a hard ArgoCD refresh on named applications. Used after GitOps commits to speed up reconciliation without waiting 3 min. | **REGISTER** |
| `scripts/infra/verify-deployment.sh` | Post-deploy readiness check — polls pod status and core rollouts, wraps public health checks. Referenced in runbooks as the "one command after a rollout." | **REGISTER** |
| `scripts/infra/verify-tutor-config.sh` | Verifies all required Tutor patches are present in generated files. Superseded by `scripts/qa/verify-tutor-patches.sh` (which IS in CI). | **ARCHIVE** (duplicate of CI-registered script) |
| `scripts/infra/verify-tutor-patches.sh` | Manifest-driven patch verification with JSON output. Superseded by the CI-registered `scripts/qa/verify-tutor-patches.sh`. | **ARCHIVE** |
| `scripts/infra/tutor-config-rollback.sh` | Restore `tutor_env/config.yml` from a timestamped backup; re-applies patches. Valuable recovery step not covered elsewhere. | **REGISTER** |
| `scripts/infra/apply-monitoring-configs.sh` | Applies Prometheus/Alertmanager configs to the cluster. | **REGISTER** |
| `scripts/infra/apply-multisite-config.sh` | Runs Django multisite bootstrap inside an LMS pod to set up Site + SiteConfiguration records. Dry-run by default. | **REGISTER** |
| `scripts/infra/fix-service-selectors.sh` | Repairs service selector mismatches after pod restarts — listed in the main CLAUDE.md troubleshooting guide as the canonical fix. | **REGISTER** |
| `scripts/infra/repair-routing.sh` | Wrapper that delegates to `repair-staging-routing.sh`. | **ARCHIVE** (thin wrapper; keep the delegate) |
| `scripts/infra/repair-staging-routing.sh` | Rapid routing recovery for selector drift / missing HTTPS port on Caddy. Referenced as emergency fix in runbooks. | **REGISTER** |
| `scripts/infra/repair-gke-mysql-users.sh` | Aligns GKE (prod) MySQL user credentials to current secrets after drift. Non-destructive (ALTER USER only). | **REGISTER** |
| `scripts/infra/repair-kind-mysql-users.sh` | Same as above for the kind-dev cluster. Has confirmation token guard. | **REGISTER** |
| `scripts/infra/rebuild-dev-openedx-db.sh` | Canonical guarded dev DB rebuild flow with Velero pre-backup and explicit confirmation token. | **REGISTER** |
| `scripts/infra/seed-mongo-dev.sh` | Seeds a dev MongoDB Atlas cluster with fixtures. Has an `--obliterate` flag that drops collections — dev-only guard required. | **REGISTER** |
| `scripts/infra/normalize-mysql-secrets.sh` | Strips trailing CR/LF from MySQL password secrets across Infisical → GCP SM → K8s. Dry-run by default. | **REGISTER** |
| `scripts/infra/data-retention-jobs.sh` | Generates (and optionally applies) K8s CronJob manifests for automated data-retention enforcement. | **REGISTER** |
| `scripts/infra/prune-gcp-snapshots.sh` | Deletes GCP Compute snapshots older than RETENTION_DAYS. Dry-run by default; requires double-token confirmation for `--apply`. | **REGISTER** |
| `scripts/infra/purge-frontend-theme-cache.sh` | Purges Cloudflare cache for frontend branding paths. Dry-run by default; `--apply` + confirmation token for production. | **REGISTER** |
| `scripts/infra/cloudflare-sync.sh` | Syncs DNS records from `infrastructure/cloudflare/records.json` to Cloudflare API. Dry-run by default. | **REGISTER** |
| `scripts/infra/cloudflare-harden-zone.sh` | Sets baseline Cloudflare zone security settings (TLS min, HSTS, HTTPS rewrites). Has `DRY_RUN` guard. | **REGISTER** |
| `scripts/infra/cleanup-stale-branches.sh` | Removes merged local branches and stale git worktrees. Has `--dry-run` and `--remote` flags. | **REGISTER** |
| `scripts/infra/ensure-atlas-allowlist-gke-nodes.sh` | Ensures all GKE node external IPs are in the MongoDB Atlas allowlist. Dry-run supported. Should be run after node rotations. | **REGISTER** |
| `scripts/infra/ensure-atlas-allowlist-vps.sh` | Maintains Atlas allowlist for the VPS agent subnet. | **REGISTER** |
| `scripts/infra/ensure-authentik-hardening.sh` | Applies/verifies Authentik hardening config (admin group, OIDC redirect URIs, MFA policy). Has `--verify` / `--apply` flags. | **REGISTER** |
| `scripts/infra/ensure-authentik-admin-mfa.sh` | Enforces MFA for Authentik admin-surface-only login without affecting normal OIDC flows. | **REGISTER** |
| `scripts/infra/ensure-authentik-admin.sh` | Provisions/verifies Authentik admin account existence and group membership. | **REGISTER** |
| `scripts/infra/ensure-authentik-oidc-redirect-uris.sh` | Syncs OIDC redirect URI allowlist to Authentik for all LMS hostnames. | **REGISTER** |
| `scripts/infra/ensure-platform-admins.sh` | Provisions platform admin accounts in Open edX LMS. | **REGISTER** |
| `scripts/infra/ensure-studio-sso-canary.sh` | Establishes the Studio SSO canary user and credentials. | **REGISTER** |
| `scripts/infra/run-authenticated-sso-canary-from-infisical.sh` | Fetches canary credentials from Infisical and runs the Playwright SSO canary; never prints secrets. | **REGISTER** |
| `scripts/infra/sync-github-authenticated-sso-canary-from-infisical.sh` | Syncs SSO canary credentials from Infisical to GitHub secrets for CI. | **REGISTER** |
| `scripts/infra/configure-github-authenticated-sso-canary.sh` | Configures GitHub secrets/variables for the authenticated SSO canary gate. | **REGISTER** |
| `scripts/infra/sync-grafana-oidc-secret.sh` | Creates/updates `monitoring/grafana-oidc-client-secret` K8s secret from GCP SM. Non-destructive. | **REGISTER** |
| `scripts/infra/setup-github-repo-vars.sh` | Sets GitHub repository variables (`HAS_INFISICAL`, `HAS_GCP_SA_KEY`) used by CI conditionals. | **REGISTER** |
| `scripts/infra/provision-admin-api-key.sh` | Provisions `ADMIN_API_KEY` for Purchase Gateway across Infisical → GCP SM → ExternalSecrets. | **REGISTER** |
| `scripts/infra/provision-atlas-cluster.sh` | Provisions a MongoDB Atlas cluster (M10/M0) via `atlas` CLI. One-shot setup. | **REGISTER** |
| `scripts/infra/atlas-config-from-infisical.sh` | Reads Atlas credentials from Infisical and emits a local Atlas config file for CLI use. | **REGISTER** |
| `scripts/infra/user-data-export.sh` | DSAR (GDPR Article 20) export — generates a structured tar.gz of all PII for a given user. | **REGISTER** |
| `scripts/infra/sync-translations.sh` | Syncs Open edX i18n/translation files. | **REGISTER** |
| `scripts/infra/refresh-i18n-static.sh` | Refreshes i18n static files inside a running LMS pod. | **REGISTER** |
| `scripts/infra/fix-mfe-refresh-endpoint-site-config.sh` | Patches MFE config refresh endpoint in SiteConfiguration records. | **REGISTER** |
| `scripts/infra/prepare-bbi-infra-ref-bump.sh` | Prepares a bbi-infrastructure repo reference bump commit. | **REGISTER** |
| `scripts/infra/kind-load-openedx-image.sh` | Loads the built OpenEdX image into kind nodes (`kind load docker-image`). | **REGISTER** |
| `scripts/infra/setup-k8s-overrides.sh` | Applies K8s environment-specific overlay overrides. | **REGISTER** |
| `scripts/infra/setup-mobile-api.sh` | Wires up the Open edX mobile REST API configuration. | **REGISTER** |
| `scripts/infra/setup-google-oauth.sh` | Configures Google OAuth2 social auth in LMS Django admin. | **REGISTER** |
| `scripts/infra/setup-vps-atlas-allowlist-cron.sh` | Installs a cron job on the VPS to keep the Atlas allowlist current. | **REGISTER** |
| `scripts/infra/setup-vps-health-cron.sh` | Installs a cron job on the VPS for periodic public health checks. | **REGISTER** |
| `scripts/infra/setup-vps-branding-visual-regression-cron.sh` | Installs a cron job on the VPS for nightly visual regression screenshots. | **REGISTER** |
| `scripts/infra/cron-public-health-check.sh` | Cron payload script for VPS health checks. | **ARCHIVE** (invoked only by cron; minimal standalone value) |
| `scripts/infra/cron-branding-visual-regression.sh` | Cron payload script for VPS branding visual regression. | **ARCHIVE** (invoked only by cron; minimal standalone value) |
| `scripts/infra/recover-stale-build-tutor-images.sh` | Recovers from stale Tutor image builds by re-tagging. | **ARCHIVE** (incident-specific helper, rarely needed) |
| `scripts/infra/build-credentials-image.sh` | Builds the Credentials service Docker image locally. | **ARCHIVE** (superseded by CI build workflow) |
| `scripts/infra/build-enterprise-mfe-clean.sh` | Builds enterprise MFE with a clean node_modules. | **ARCHIVE** (superseded by CI build workflow) |
| `scripts/infra/optimize-pod-resources.sh` | Patches pod memory requests down to 512Mi for dev cost saving. No confirmation guard. | **REGISTER** |
| `scripts/infra/optimize-dev-costs.sh` | Reports dev-environment GKE/GCS cost-saving opportunities. Read-only. | **ARCHIVE** (one-time advisory; superseded by cost-tracking CI) |
| `scripts/infra/additional-cost-optimizations.sh` | Additional cost-saving opportunities report. Read-only informational. | **ARCHIVE** |
| `scripts/infra/increase-gke-quota.sh` | Requests GKE Autopilot quota increases for Aspects Analytics. One-time setup. | **ARCHIVE** |
| `scripts/infra/sync-production-config.sh` | Syncs production Tutor config for reference. | **ARCHIVE** (superseded by GitOps overlay) |
| `scripts/infra/sync-vendored-mfe-caddyfile.sh` | Syncs the vendored MFE Caddyfile from the tutor-generated env. | **ARCHIVE** |
| `scripts/infra/verify-k8s-overrides.sh` | Verifies K8s overlay overrides are applied. | **ARCHIVE** (superseded by CI verification scripts) |
| `scripts/infra/verify-prometheus-integration.sh` | Verifies Prometheus scrape targets are reachable. | **ARCHIVE** (superseded by CI observability scripts) |
| `scripts/infra/docker-cleanup.sh` | Runs `docker system prune` and shows disk usage. | **ARCHIVE** (trivial helper) |
| `scripts/infra/fix-velero-restore-test.sh` | Patches Velero restore-test CronJob to use a repo-managed script and correct image. | **REGISTER** |
| `scripts/infra/monitor-atlas-allowlist-vps.sh` | Continuously monitors Atlas allowlist for VPS IP drift. | **REGISTER** |
| `scripts/infra/check-atlas-allowlist-vps.sh` | One-shot check of Atlas allowlist vs. current VPS IP. | **REGISTER** |
| `scripts/infra/check-pr-handoff-discipline.sh` | Checks PR handoff discipline (open PRs, CI status, reviewer assignment). | **REGISTER** |
| `scripts/infra/sync-mongodb-from-production.sh` | Dumps production MongoDB Atlas and restores to local dev. Requires `ATLAS_URI`. | **REGISTER** |
| `scripts/infra/deploy-aspects-k8s.sh` | Legacy Tutor → K8s direct apply for Aspects. **Self-disabling**: exits unless `ALLOW_LEGACY_TUTOR_K8S=1`. | **ARCHIVE** (deprecated by script's own guard) |

---

## scripts/ops — Operational Procedures

| Script | Purpose | Disposition |
|--------|---------|-------------|
| `scripts/ops/park-prod.sh` | Scales GKE prod stateless workloads to 0 (warm-park mode). Has `--dry-run` and Velero backup validation. | **REGISTER** |
| `scripts/ops/unpark-prod.sh` | Reverses warm-park mode via GitOps commit to bbi-infrastructure + ArgoCD reconcile. Has `--dry-run`. | **REGISTER** |
| `scripts/ops/generate-sla-report.sh` | Generates a monthly Markdown SLA report from Prometheus metrics. | **REGISTER** |

---

## scripts/analytics — Data & Analytics

| Script | Purpose | Disposition |
|--------|---------|-------------|
| `scripts/analytics/delete-user-events.sh` | Deletes ClickHouse analytics events for a user (GDPR right to erasure). Has `--dry-run`. | **REGISTER** |
| `scripts/analytics/openedx-export-enrollments.sh` | Exports enrollment CSV from Open edX via `tutor local run lms`. | **REGISTER** |
| `scripts/analytics/verify-user-deletion.sh` | Verifies that a user's analytics data has been deleted from ClickHouse. | **REGISTER** |

---

## scripts/branding — Branding & Tokens

| Script | Purpose | Disposition |
|--------|---------|-------------|
| `scripts/branding/build-tokens.sh` | Compiles Paragon CSS token files (core, light, brand variants). | **REGISTER** |
| `scripts/branding/generate-tokens-from-canonical.sh` | Reads `assets/branding/tokens.css` and regenerates all downstream SCSS/CSS token files. Idempotent. | **REGISTER** |
| `scripts/branding/sync-brand-assets.sh` | Copies fonts from `assets/branding/` into all Tutor theme directories. | **REGISTER** |
| `scripts/branding/sync-brand-package.sh` | Syncs OEP-48 brand package assets (fonts, logos) into the Tutor theme. | **REGISTER** |
| `scripts/branding/sync-tokens-to-json.sh` | Converts token CSS to JSON for Paragon build pipeline. | **REGISTER** |
| `scripts/branding/update-token-provenance.sh` | Updates provenance metadata in token files. | **ARCHIVE** (narrow maintenance task) |
| `scripts/branding/setup-mfe-branding.sh` | Clones/updates MFE repos locally and wires in Mereka theme assets for dev mode. | **REGISTER** |
| `scripts/branding/run-branding-gates.sh` | Orchestrates all branding gate checks for a given environment. | **REGISTER** |
| `scripts/branding/repair-mfe-authn-branding.sh` | Repairs an MFE image when authn CSS references an unbranded bundle — rebuilds and retags. | **ARCHIVE** (incident-specific; superseded by build pipeline fixes) |
| `scripts/branding/deploy-logo-fix.sh` | Emergency: copies logo files into a running LMS pod without a full image rebuild. | **ARCHIVE** (emergency-only workaround; now documented in runbooks) |
| `scripts/branding/fix-logo-static-files.sh` | Emergency: syncs logo files and runs `collectstatic` in-pod. | **ARCHIVE** (same — emergency workaround) |
| `scripts/branding/verify-branding-css.sh` | Verifies branding CSS files exist and contain expected token blocks. | **ARCHIVE** (superseded by CI `verify-design-tokens.sh`) |
| `scripts/branding/verify-branding-health.sh` | Orchestrates multiple branding health checks. | **ARCHIVE** (superseded by CI `verify-branding-health.sh`) |

---

## scripts/migrations — Data Migrations

| Script | Purpose | Disposition |
|--------|---------|-------------|
| `scripts/migrations/kajabi/export.sh` | Verifies Kajabi export infrastructure and readiness (read-only). | **REGISTER** |
| `scripts/migrations/kajabi/resilient_import.sh` | Batch-imports Kajabi data into Open edX with retry logic and progress state. | **REGISTER** |
| `scripts/migrations/mct/export.sh` | Verifies MCT export infrastructure and readiness (read-only). | **REGISTER** |
| `scripts/migrations/mct/run_full_user_import.sh` | Runs MCT user import in batches with state tracking. | **REGISTER** |
| `scripts/migrations/mct/run_program_setup.sh` | Sets up MCT programs in Open edX. | **REGISTER** |
| `scripts/migrations/mct/run_user_import_k8s.sh` | MCT user import for K8s — has a **hardcoded pod name** (`lms-75c446d865-c77cn`), making it stale. | **ARCHIVE** (hardcoded pod name; use `run_full_user_import.sh`) |
| `scripts/migrations/mct/run_validation.sh` | Validates MCT import results. | **REGISTER** |
| `scripts/migrations/mct/create_programs_simple.sh` | Simplified MCT program creation. | **ARCHIVE** (superseded by `run_program_setup.sh`) |
| `scripts/migrations/mct/import_2_courses.sh` | Imports two specific MCT courses. | **ARCHIVE** (specific one-off; captured in migration history) |
| `scripts/migrations/mct/test-export-fixes.sh` | Tests export fixes. | **ARCHIVE** (one-time diagnostic) |
| `scripts/migrations/mct/test_user_import.sh` | Tests user import with a small sample. | **ARCHIVE** (dev helper; superseded by dry-run mode) |
| `scripts/migrations/mct/verify_mux_upload.sh` | Verifies Mux video upload completeness. Listed in CI as `scripts/migrations/mct/verify_video_mapping.sh` — this is the companion upload check. | **REGISTER** |
| `scripts/migrations/bootstrap-courses-from-enrollments.sh` | Bootstraps course stubs from an enrollment CSV for migration. | **REGISTER** |
| `scripts/migrations/import-production-courses.sh` | Imports production course OLX packages into Open edX. | **REGISTER** |
| `scripts/migrations/run-dry-run.sh` | Dry-run pass of the full migration pipeline. | **REGISTER** |
| `scripts/import-mct-batch.sh` | Root-level batch MCT course importer — uses hardcoded category array and a dynamic pod lookup. | **ARCHIVE** (root-level placement wrong; functionality duplicated by `migrations/mct/`) |
| `scripts/import-new-mct-courses.sh` | Root-level importer for 15 specific new MCT courses. | **ARCHIVE** (one-off; hardcoded course IDs) |

---

## scripts/tenants — Tenant Lifecycle

| Script | Purpose | Disposition |
|--------|---------|-------------|
| `scripts/tenants/onboard-enterprise-tenant.sh` | Deterministic 6-step enterprise tenant onboarding workflow (provision, IdP, branding, verification). | **REGISTER** |
| `scripts/tenants/offboard-tenant.sh` | Deactivates, exports data, disables SSO, and generates an offboarding audit report. Has `--dry-run`. | **REGISTER** |
| `scripts/tenants/provision-tenant.sh` | Provisions a single tenant's Site and TenantConfig via management command. | **REGISTER** |
| `scripts/tenants/provision-all-tenants.sh` | Provisions all tenants from the registry ConfigMap. | **REGISTER** |
| `scripts/tenants/configure-tenant-idp.sh` | Configures SAML or OIDC IdP for a tenant. | **REGISTER** |
| `scripts/tenants/generate-saml-keypair.sh` | Generates an RSA 2048-bit SAML SP keypair. Referenced in CLAUDE.md. | **REGISTER** |
| `scripts/tenants/repair-enterprise-schema.sh` | Runs enterprise Django migrations and verifies schema columns. Has confirmation token + Velero backup guard. | **REGISTER** |
| `scripts/tenants/sync-tenant-branding.sh` | Syncs branding assets for a specific tenant. | **REGISTER** |
| `scripts/tenants/sync-tenant-enterprise-mapping.sh` | Syncs the `ENTERPRISE_CUSTOMER_UUID` mapping into a tenant's SiteConfiguration. | **REGISTER** |
| `scripts/tenants/provision-mfe-config.sh` | Provisions MFE config API entries for a tenant. | **REGISTER** |

---

## scripts/mobile — Mobile

| Script | Purpose | Disposition |
|--------|---------|-------------|
| `scripts/mobile/setup-ios-app.sh` | One-time setup for the iOS mobile app (certificates, provisioning profiles). | **REGISTER** |

---

## scripts/qa — Quality Assurance (non-CI orphans)

Most `scripts/qa/` scripts are already in the CI list. The following are orphaned from CI and governance:

| Script | Purpose | Disposition |
|--------|---------|-------------|
| `scripts/qa/smoke-test.sh` | Smoke-tests all live public LMS/Studio URLs via HTTP checks. | **REGISTER** |
| `scripts/qa/public-health-check.sh` | Synthetic health checks for public prod + dev endpoints. | **REGISTER** |
| `scripts/qa/ops-preflight.sh` | Pre-flight check that prints exact environment prerequisites before ops. Exit 0 = all clear. | **REGISTER** |
| `scripts/qa/synthetic-alert-drill.sh` | Sends a test alert through Alertmanager → Slack/PagerDuty to verify delivery latency. | **REGISTER** |
| `scripts/qa/smoke-authenticated.sh` | Authenticated smoke test (requires valid session cookie). | **REGISTER** |
| `scripts/qa/smoke-authn-mfe.sh` | Smoke-tests the Authn MFE login page. | **REGISTER** |
| `scripts/qa/smoke-test-analytics.sh` | Smoke-tests analytics event capture. | **REGISTER** |
| `scripts/qa/tenant-onboarding-dryrun.sh` | Dry-run of the full tenant onboarding workflow. | **REGISTER** |
| `scripts/qa/tenant-onboarding-evidence.sh` | Captures evidence for a tenant onboarding completion. | **REGISTER** |
| `scripts/qa/fix-admin-login.sh` | Flushes Django sessions and Redis cache to resolve admin lockout. | **ARCHIVE** (dev-only break-glass; document in runbooks instead) |
| `scripts/qa/fix-parity.sh` | Fixes parity between environments. | **ARCHIVE** (unclear scope; likely superseded) |
| `scripts/qa/comprehensive-test.sh` | Orchestrates a comprehensive suite of local tests. | **ARCHIVE** (superseded by CI `ci-scripts-static.txt`) |
| `scripts/qa/course-data-sanity.sh` | Sanity-checks course data in Open edX. | **REGISTER** |
| `scripts/qa/ops-confidence.sh` | Prints operational confidence scores based on recent check outputs. | **ARCHIVE** (informational; not machine-actionable) |
| `scripts/qa/generate-evidence-pack.sh` | Generates an evidence pack for a given release or audit. | **REGISTER** |
| `scripts/qa/test-stripe-webhook-delivery.sh` | Sends a test Stripe webhook to verify Purchase Gateway delivery. | **REGISTER** |
| `scripts/qa/load-test-libraries.sh` | Load-tests Content Libraries v2 endpoints. | **REGISTER** |
| `scripts/qa/load-test-tenants.sh` | Load-tests tenant resolution middleware. | **REGISTER** |
| `scripts/qa/visual-regression-auth.sh` | Visual regression screenshots for the Authn surface. | **REGISTER** |
| `scripts/qa/visual-regression-branding.sh` | Visual regression screenshots for branded surfaces. | **REGISTER** |
| `scripts/qa/visual-regression-test.sh` | General visual regression test runner. | **REGISTER** |
| `scripts/qa/validation-pack/pre-deploy-checklist.sh` | Human-readable pre-deploy checklist. | **ARCHIVE** (superseded by `verify-release-readiness.sh`) |
| `scripts/qa/validation-pack/post-deploy-verify.sh` | Post-deploy verification (duplicate of root-level `post-deploy-verify.sh`). | **ARCHIVE** (duplicate) |
| `scripts/qa/validation-pack/smoke-tests.sh` | Smoke tests in validation pack. | **ARCHIVE** (duplicate of `smoke-test.sh`) |

### scripts/qa/deprecated/ — Already Deprecated (DELETE)

All 21 scripts under `scripts/qa/deprecated/` are explicitly deprecated. They
should be **DELETED** in a follow-up cleanup PR. They are not executed anywhere
and their directory name signals this intent.

---

## scripts/gen / scripts/tools — Generators & Tools

| Script | Purpose | Disposition |
|--------|---------|-------------|
| `scripts/gen/update-openedx-hostnames-doc.sh` | Regenerates the Open edX hostnames documentation file. | **REGISTER** |
| `scripts/tools/beads-post-sync-hook.sh` | Git post-sync hook for the `beads` issue tracker. | **ARCHIVE** (project-tooling; managed by ACFS, not this repo) |
| `scripts/tools/sync-beads-viewer.sh` | Syncs the beads viewer web app. | **ARCHIVE** (project-tooling; managed by ACFS) |

---

## scripts/ root-level — Top-level Scripts

| Script | Purpose | Disposition |
|--------|---------|-------------|
| `scripts/export-k8s-manifests.sh` | Legacy Tutor → K8s manifest export. **Self-disabling**: exits unless `ALLOW_LEGACY_TUTOR_K8S=1`. | **ARCHIVE** (deprecated by its own guard) |
| `scripts/migrate-to-bbi-k8.sh` | Migration helper for moving data from `mereka-lms` GCP project to `bbi-k8` shared cluster. One-time completed migration. | **ARCHIVE** (migration completed) |
| `scripts/import-mct-batch.sh` | Root-level MCT batch importer (see migrations section). | **ARCHIVE** |
| `scripts/import-new-mct-courses.sh` | Root-level one-off importer. | **ARCHIVE** |

---

## scripts/shared/ — Shared Libraries (informational)

The `scripts/shared/` directory contains sourced helper libraries, not
standalone scripts. They are not appropriate for the CI scripts list or
registry, but they must not be deleted:

| File | Role |
|------|------|
| `scripts/shared/config.sh` | Central configuration variables sourced by most scripts |
| `scripts/shared/lib.sh` | Common bash logging and utility functions |
| `scripts/shared/setup-local.sh` | One-click local dev bootstrapper |
| `scripts/shared/ci-skip-guards.sh` | Shared CI skip condition helpers |
| `scripts/shared/mereka_plugin_contract.sh` | Plugin contract helpers |
| `scripts/shared/create-demo-course.sh` | Creates a demo course in a dev LMS |
| `scripts/shared/sync-discovery.sh` | Triggers a discovery service course re-index |
| `scripts/shared/sync-from-production.sh` | Pulls production DB snapshot for local dev |

These are internal library scripts. They should remain undisturbed.

---

## MongoDB Migration Scripts (ARCHIVE)

These three scripts were used for the one-time MongoDB Atlas migration (now complete
per ADR-001 and MEMORY.md entries). They should be archived:

| Script | Disposition |
|--------|-------------|
| `scripts/infra/mongodb-to-atlas.sh` | **ARCHIVE** — migration completed |
| `scripts/infra/mongodb-atlas-cutover.sh` | **ARCHIVE** — migration completed |
| `scripts/infra/retire-legacy-mongodb.sh` | **ARCHIVE** — migration completed |
| `scripts/infra/downgrade-mongodb-to-m0.sh` | **ARCHIVE** — cost decision already made |
| `scripts/infra/create-atlas-m10-cluster.sh` | **ARCHIVE** — cluster exists; one-time setup |

---

## Summary Counts

| Disposition | Count (approx) |
|-------------|---------------|
| REGISTER | ~75 |
| ARCHIVE | ~45 |
| DELETE | 21 (`scripts/qa/deprecated/`) |
| Shared library (no action) | 8 |
| QA run-scripts / build-scripts (informational) | ~200 (qa/run-*, qa/build-*) |
