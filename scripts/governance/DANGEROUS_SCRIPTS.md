# Dangerous Scripts — Ungoverned Side-Effects Audit

Scripts with destructive side effects that are **not** registered in
`scripts/governance/script-registry.yaml`. Scripts already registered are
excluded; their side effects are already documented and governed there.

**Governed scripts with side effects** (registered, not listed here):
`canonical-release.sh`, `release-openedx-gitops.sh`, `create-release.sh`,
`bump-image-tags.sh`, `sync-gitops-prod-image-tags.sh`, `apply-kind-overlay.sh`,
`sync-mereka-lms-secrets-to-gcpsm.sh`, `infisical-sync-mereka-lms.sh`,
`bootstrap-kind-secrets.sh`, `provision-mysql-app-dbs.sh`,
`deploy-branded-image.sh`, `tutor-config-save.sh`.

---

## HIGH Risk — Production State Mutations

### scripts/ops/park-prod.sh
**Destructive action:** Scales all GKE production stateless workloads to 0 replicas
(LMS, CMS, workers, MFEs, enterprise services, ~22 deployments). Partial
cluster shutdown.

**Guards present:** `--dry-run` flag, Velero backup pre-check, `--skip-velero-check`
opt-out. No explicit confirmation token.

**Gap:** No double-confirmation token to prevent accidental invocation. A
mis-typed command can take production offline in seconds.

**Risk:** HIGH

**Recommendation:** REGISTER. Add a `CONFIRM_PARK_PROD=PARK_PROD` token guard
matching the pattern used in `canonical-release.sh`. Require `ALLOW_PROD_APPLY=1`
alongside the token.

---

### scripts/ops/unpark-prod.sh
**Destructive action:** Commits a change to the `bbi-infrastructure` repo and
waits for ArgoCD to reconcile production (restores replicas). Also makes a git
push to `bbi-infrastructure/main`.

**Guards present:** `--dry-run` flag, Velero check. No explicit confirmation token.

**Gap:** No double-confirmation token. A misrun unpark can trigger an ArgoCD
sync on production before the team is ready to accept traffic (e.g. during a
maintenance window).

**Risk:** HIGH

**Recommendation:** REGISTER. Add `CONFIRM_UNPARK_PROD=UNPARK_PROD` token guard.

---

### scripts/infra/prune-gcp-snapshots.sh
**Destructive action:** Permanently deletes GCP Compute snapshots older than
`RETENTION_DAYS`. Snapshot deletion is **irreversible** and affects disaster
recovery capability.

**Guards present:** Dry-run by default (no `--apply` = no deletion).
`--apply` requires `CONFIRM_PRUNE_GCP_SNAPSHOTS=PRUNE_GCP_SNAPSHOTS` AND
`ALLOW_PROD_APPLY=1`. Has `--max-delete` cap.

**Gap:** Script is ungoverned — nobody auditing the registry knows this script
exists or that it deletes backup snapshots.

**Risk:** HIGH

**Recommendation:** REGISTER. Already has strong guards; the gap is registry
visibility.

---

### scripts/infra/data-retention-jobs.sh
**Destructive action (indirect):** Generates and optionally applies K8s CronJob
manifests that will then delete database rows on a schedule (Stripe events,
Django sessions, userretirementstatus records, Open edX notifications).

**Guards present:** Generates manifests first; `--apply` applies them to cluster.
No confirmation token on `--apply`.

**Gap:** `--apply` mutates the cluster by creating CronJobs that run destructive
SQL at their next schedule. No explicit confirmation token.

**Risk:** HIGH

**Recommendation:** REGISTER. Add a `CONFIRM_APPLY_RETENTION_JOBS=APPLY_RETENTION_JOBS`
token for the `--apply` path. Document the CronJob schedule and retention windows.

---

### scripts/infra/sync-mongodb-from-production.sh
**Destructive action:** Dumps production MongoDB Atlas and restores into the
target MongoDB instance using `--drop` (drops and recreates all collections
in the target). Requires `ATLAS_URI` pointing at production.

**Guards present:** Requires `ATLAS_URI` to be set. No dry-run mode. No
confirmation token. No dev-only guard preventing accidental prod-to-prod run.

**Gap:** No confirmation token, no dry-run, no environment guard. Could
overwrite the wrong MongoDB instance if `ATLAS_URI` is misset.

**Risk:** HIGH

**Recommendation:** REGISTER. GUARD with `CONFIRM_SYNC_MONGO_FROM_PROD=SYNC_MONGO_FROM_PROD`
token and a `DEV_ONLY=1` guard that checks the target URI does not match the
source URI.

---

### scripts/infra/normalize-mysql-secrets.sh
**Destructive action:** Overwrites secret versions in GCP Secret Manager and
Infisical (source of truth) with trailing-whitespace-stripped values. Secrets
that were previously valid (with trailing newlines) are permanently overwritten.

**Guards present:** `APPLY=0` default (dry-run). Non-zero `APPLY` required for
mutations. Does not print secret values.

**Gap:** No explicit confirmation token. Any agent running `APPLY=1` executes
production secret rewrites with no second factor.

**Risk:** HIGH

**Recommendation:** REGISTER. Add `CONFIRM_NORMALIZE_MYSQL_SECRETS=NORMALIZE_MYSQL_SECRETS`
token gate before any GCP SM writes.

---

### scripts/infra/ensure-authentik-hardening.sh
**Destructive action:** `--apply` flag modifies live Authentik configuration:
adds/removes admin group members, mutates OIDC redirect URI allowlists, creates
MFA policy bindings. A misconfigured `--apply` can lock administrators out of
Authentik entirely.

**Guards present:** `--verify` mode is read-only. `--apply` mode is interactive
but has no confirmation token.

**Gap:** `--apply` directly mutates authentication configuration with no
confirmation token or double-check. Authentik lockout is a high-severity incident.

**Risk:** HIGH

**Recommendation:** REGISTER. Add `CONFIRM_APPLY_AUTHENTIK_HARDENING=APPLY_AUTHENTIK_HARDENING`
before any API writes.

---

### scripts/infra/ensure-authentik-admin-mfa.sh
**Destructive action:** `--apply` mutates Authentik's authentication flow by
binding a new MFA validation stage. If the MFA stage's `not_configured_action`
is set incorrectly, all admin logins can be blocked.

**Guards present:** `--verify` mode. No confirmation token on `--apply`.

**Gap:** Same gap as `ensure-authentik-hardening.sh` — Authentik flow mutation
without a confirmation token.

**Risk:** HIGH

**Recommendation:** REGISTER. Add explicit confirmation token.

---

## HIGH Risk — Data Deletion

### scripts/analytics/delete-user-events.sh
**Destructive action:** Executes `ALTER TABLE ... DELETE WHERE user_id = ?`
in ClickHouse. ClickHouse mutations are asynchronous and **irreversible** — once
issued they cannot be cancelled once the mutation begins applying.

**Guards present:** `--dry-run` flag prints the SQL without executing. Real
deletion requires no additional confirmation token beyond omitting `--dry-run`.

**Gap:** Omitting `--dry-run` immediately issues the irreversible ClickHouse
mutation with no second factor. A GDPR deletion is legitimate but still needs
an operator confirmation token to prevent accidents.

**Risk:** HIGH

**Recommendation:** REGISTER. Add `CONFIRM_DELETE_USER_EVENTS=DELETE_USER_EVENTS`
token required when `--dry-run` is not set.

---

### scripts/infra/seed-mongo-dev.sh
**Destructive action:** With `--obliterate` flag, drops MongoDB collections
before seeding. Script comment says "NEVER run against production" but there is
no programmatic guard preventing a production `MONGODB_CONNECTION_STRING` from
being passed.

**Guards present:** Comment warning. `--dry-run` mode. No environment detection
that blocks production URIs.

**Gap:** No guard against a production Atlas URI. An operator who sets
`MONGODB_CONNECTION_STRING` from Infisical prod and forgets `--dry-run` will
obliterate production collections.

**Risk:** HIGH

**Recommendation:** REGISTER. Add a URI-inspection guard that rejects connection
strings pointing at the known production Atlas cluster name
(`cluster-mereka-lms.2pjex4s.mongodb.net`).

---

### scripts/infra/rebuild-dev-openedx-db.sh
**Destructive action:** Runs Django `flush`, `migrate`, and data initialization
commands against a dev cluster database. Wipes all course and user data in the
target namespace.

**Guards present:** Dry-run by default. Requires `RUN_DESTRUCTIVE=1` AND
`CONFIRM_REBUILD_DEV_DB=REBUILD_DEV_DB`. Refuses prod-like contexts without
override. Pre-op Velero backup.

**Gap:** Strong guards already present; needs registry visibility for operator
awareness.

**Risk:** HIGH (for the database) — guards reduce operational risk to LOW when
followed.

**Recommendation:** REGISTER. Guards are well-designed; this script just needs
to be in the registry so operators know it exists and use it instead of ad-hoc
`kubectl exec` commands.

---

### scripts/infra/retire-legacy-mongodb.sh
**Destructive action:** `RUN_DESTRUCTIVE=1` path deletes the `mongodb`
StatefulSet, its Service, and PVC from the cluster. PVC deletion is
**irreversible** without a Velero backup.

**Guards present:** Non-destructive by default. Requires `RUN_DESTRUCTIVE=1`
AND `CONFIRM_RETIRE_LEGACY_MONGODB=YES_DELETE_LEGACY_MONGODB`. Pre-op Velero
backup.

**Gap:** Registry visibility only — guards are solid.

**Risk:** HIGH (potential data loss) — guards reduce to LOW when followed.

**Recommendation:** REGISTER. Note in registry that this is a one-time migration
script for ADR-001 completion.

---

## MEDIUM Risk — Cluster Mutations

### scripts/infra/repair-gke-mysql-users.sh
**Destructive action:** Executes `ALTER USER` and `CREATE USER` SQL against
production GKE MySQL. Wrong credentials result in a production MySQL lockout
for all services.

**Guards present:** Non-destructive (no DB drops). Does not print secrets. Notes
that it reads from `secret/database-secrets`.

**Gap:** No dry-run mode, no confirmation token. Running this against the wrong
cluster context would alter production MySQL users immediately.

**Risk:** MEDIUM

**Recommendation:** REGISTER. GUARD with `--dry-run` that prints the SQL without
executing, and `CONFIRM_REPAIR_GKE_MYSQL=REPAIR_GKE_MYSQL` token for execution.

---

### scripts/infra/repair-kind-mysql-users.sh
**Destructive action:** Same as above for the kind-dev cluster. Has a
`CONFIRM_REPAIR_KIND_MYSQL_USERS` token already.

**Guards present:** Confirmation token, pre-op backup flag, context check.

**Gap:** Registry visibility only — guards are reasonable.

**Risk:** MEDIUM (dev cluster; lower blast radius than GKE).

**Recommendation:** REGISTER.

---

### scripts/infra/apply-multisite-config.sh
**Destructive action:** Runs Django management commands inside the LMS pod that
create or update `Site` and `SiteConfiguration` database records. Misconfiguration
can break all tenant routing for the affected environment.

**Guards present:** `DRY_RUN=true` by default.

**Gap:** No confirmation token for `DRY_RUN=false`. Tenant routing is a
platform-critical surface.

**Risk:** MEDIUM

**Recommendation:** REGISTER. Add `CONFIRM_APPLY_MULTISITE=APPLY_MULTISITE`
confirmation token when `DRY_RUN=false`.

---

### scripts/infra/optimize-pod-resources.sh
**Destructive action:** Issues `kubectl patch deployment` on all named
deployments in the namespace to lower memory requests. If a workload cannot run
within the new resource request, it is evicted and may crash-loop.

**Guards present:** None. No dry-run, no confirmation token.

**Gap:** No dry-run mode and no confirmation token. Silently patches live
deployments.

**Risk:** MEDIUM

**Recommendation:** REGISTER. GUARD with `--dry-run` that prints patches without
applying, and `DRY_RUN=true` default.

---

### scripts/infra/argocd-refresh.sh
**Destructive action (indirect):** Forces a hard ArgoCD refresh on the named
applications. A hard refresh clears the manifest cache and triggers
re-synchronization. If ArgoCD auto-sync is enabled and manifests have drifted,
this can trigger an immediate cluster mutation (rollout, resource delete/recreate).

**Guards present:** None.

**Gap:** No guard. Running against production ArgoCD apps when there is unreviewed
git drift can trigger unintended rollouts.

**Risk:** MEDIUM

**Recommendation:** REGISTER. Document that this should only be called after
confirming the target git state is intentional.

---

### scripts/infra/fix-velero-restore-test.sh
**Destructive action:** Patches the `restore-test` CronJob ConfigMap and
updates the CronJob container image. These are ArgoCD-managed resources.
Per `gitops-enforcement.md`, direct kubectl mutations on ArgoCD-managed
resources are forbidden.

**Guards present:** None — the script patches directly without checking for
ArgoCD ownership annotations.

**Gap:** Violates the GitOps enforcement rule. Any ArgoCD sync after this
patch will revert it, potentially causing a loop. The fix needs to go through
bbi-infrastructure.

**Risk:** MEDIUM (GitOps violation, not data loss)

**Recommendation:** RESTRICT. This script should be deleted or replaced with
a PR workflow against bbi-infrastructure. Add a comment pointing to the correct
GitOps path.

---

### scripts/infra/sync-grafana-oidc-secret.sh
**Destructive action:** Creates or updates the `grafana-oidc-client-secret` K8s
Secret in the `monitoring` namespace. Updating the wrong value disables Grafana
SSO login.

**Guards present:** Read-only check for existing secret, non-destructive (updates
only one key).

**Gap:** No dry-run mode, no confirmation token.

**Risk:** MEDIUM

**Recommendation:** REGISTER. Add `--dry-run` that prints the intended secret
write without executing.

---

### scripts/infra/setup-github-repo-vars.sh
**Destructive action:** Sets GitHub repository variables via `gh` CLI. Incorrect
variable values (`HAS_INFISICAL=false` when it should be true) silently disable
entire CI job categories.

**Guards present:** None.

**Gap:** No dry-run, no confirmation token. Misconfigured CI variables degrade
the CI pipeline silently.

**Risk:** MEDIUM

**Recommendation:** REGISTER. Add a read-back verification step that confirms
the variables were set to the intended values.

---

### scripts/tenants/onboard-enterprise-tenant.sh
**Destructive action:** Provisions a new `Site` and `EnterpriseCustomer` record,
configures an IdP (SAML/OIDC), syncs branding. A mis-invocation (wrong slug)
creates orphaned tenant records that require manual database cleanup.

**Guards present:** 6-step workflow with verification at each stage. No
confirmation token for the provisioning steps.

**Gap:** No single confirmation token before the workflow begins mutating
production database records.

**Risk:** MEDIUM

**Recommendation:** REGISTER. Add a `CONFIRM_ONBOARD_TENANT=ONBOARD_<SLUG>`
pattern (similar to how `offboard-tenant.sh` uses `OFFBOARD_TENANT`).

---

### scripts/tenants/offboard-tenant.sh
**Destructive action:** Deactivates `EnterpriseCustomer` and `TenantConfig`
records and disables IdP configuration. `--force-delete` path permanently
removes tenant records from the database.

**Guards present:** `--dry-run` flag. `CONFIRM_OFFBOARD_TENANT=OFFBOARD_TENANT`
token for deactivation. `CONFIRM_FORCE_DELETE_TENANT=FORCE_DELETE_TENANT`
for destructive delete.

**Gap:** Registry visibility only — guards are strong.

**Risk:** MEDIUM (deactivation) / HIGH (`--force-delete`)

**Recommendation:** REGISTER.

---

### scripts/tenants/repair-enterprise-schema.sh
**Destructive action:** Runs Django enterprise app migrations (`manage.py migrate`)
against the live cluster database. A bad migration cannot always be cleanly
rolled back.

**Guards present:** Read-only default. `--apply` requires `CONFIRM_REPAIR_ENTERPRISE_SCHEMA=REPAIR_ENTERPRISE_SCHEMA`
AND `ALLOW_PROD_APPLY=1`. Pre-op Velero backup.

**Gap:** Registry visibility only — guards are well-designed.

**Risk:** MEDIUM

**Recommendation:** REGISTER.

---

## MEDIUM Risk — Secret / Registry Mutations

### scripts/infra/provision-admin-api-key.sh
**Destructive action:** Creates a new secret version in both Infisical (source
of truth) and GCP Secret Manager. Also may create/rotate the `ADMIN_API_KEY`
used by Purchase Gateway.

**Guards present:** Checks that Infisical CLI and gcloud are authenticated.
No dry-run, no confirmation token.

**Gap:** No dry-run or confirmation token. Secret rotation of `ADMIN_API_KEY`
will invalidate all in-flight Purchase Gateway admin requests.

**Risk:** MEDIUM

**Recommendation:** REGISTER. Add `--dry-run` that prints intended Infisical/GCP
SM writes without executing.

---

### scripts/infra/sync-github-authenticated-sso-canary-from-infisical.sh
**Destructive action:** Overwrites GitHub repository secrets for SSO canary
credentials (`SSO_CANARY_EMAIL_PROD`, `SSO_CANARY_PASSWORD_PROD`). Overwriting
with wrong values breaks the SSO canary CI gate.

**Guards present:** Does not print secret values. Reads from Infisical.

**Gap:** No dry-run, no confirmation token.

**Risk:** MEDIUM

**Recommendation:** REGISTER. Add `--dry-run` that lists the secrets that would
be written without writing them.

---

### scripts/infra/configure-github-authenticated-sso-canary.sh
**Destructive action:** Writes GitHub secrets/variables for the SSO canary gate
using values passed as environment variables. Misconfigured secrets break CI.

**Guards present:** Does not print secret values.

**Gap:** No dry-run, no confirmation token.

**Risk:** MEDIUM

**Recommendation:** REGISTER. Add `--dry-run`.

---

## LOW Risk — Informational / Reversible Mutations

| Script | Side Effect | Gap | Recommendation |
|--------|-------------|-----|----------------|
| `scripts/infra/cleanup-stale-branches.sh` | Deletes merged local git branches; with `--remote` also prunes remote merged branches. | Has `--dry-run`. Remote pruning requires explicit opt-in. | REGISTER |
| `scripts/infra/cloudflare-sync.sh` | Upserts/deletes Cloudflare DNS records against the live zone. `DRY_RUN` guard. | No confirmation token. DNS changes propagate globally in seconds. | REGISTER. Add `CONFIRM_CLOUDFLARE_SYNC=CLOUDFLARE_SYNC` token. |
| `scripts/infra/cloudflare-harden-zone.sh` | Sets Cloudflare zone settings (TLS version, HSTS). `DRY_RUN` guard. | No confirmation token for live zone mutations. | REGISTER. Add confirmation token. |
| `scripts/infra/ensure-atlas-allowlist-gke-nodes.sh` | Adds/removes IPs from the MongoDB Atlas network allowlist. | No explicit dry-run; reads GKE node IPs and pushes to Atlas. | REGISTER. Add `--dry-run` mode. |
| `scripts/infra/ensure-atlas-allowlist-vps.sh` | Adds/removes VPS IP from Atlas allowlist. | No dry-run. | REGISTER. Add `--dry-run`. |
| `scripts/infra/monitor-atlas-allowlist-vps.sh` | Polls Atlas allowlist continuously and adds the VPS IP if missing. Designed to run as a daemon/cron. | No dry-run for the polling loop. | REGISTER. |
| `scripts/infra/backup-db.sh` | Exports Cloud SQL databases to GCS. Creates new objects in GCS; no deletion. | No guard needed — additive only. | REGISTER. |
| `scripts/infra/refresh-i18n-static.sh` | Runs `compilemessages` and copies i18n files inside a running pod. Temporary file state change. | No dry-run needed. | REGISTER. |
| `scripts/infra/fix-mfe-refresh-endpoint-site-config.sh` | Patches `MFE_CONFIG_API_URL` in `SiteConfiguration` records. Database mutation. | No dry-run mode. | REGISTER. Add `--dry-run`. |
| `scripts/infra/argocd-refresh.sh` | Forces ArgoCD hard refresh (see MEDIUM section above). | Listed here also for completeness. | REGISTER. |
| `scripts/infra/setup-vps-atlas-allowlist-cron.sh` | Installs a system cron entry on the VPS. Persistent system mutation. | No dry-run. | REGISTER. |
| `scripts/infra/setup-vps-health-cron.sh` | Installs a system cron entry on the VPS. | No dry-run. | REGISTER. |
| `scripts/infra/setup-vps-branding-visual-regression-cron.sh` | Installs a system cron entry on the VPS. | No dry-run. | REGISTER. |
| `scripts/analytics/delete-user-events.sh` | ClickHouse mutation (see HIGH section above). | Already detailed above. | REGISTER. |
| `scripts/migrations/kajabi/resilient_import.sh` | Writes users/enrollments/courses into Open edX LMS database via management commands. | Idempotent for existing records; creates new records on each run for missing ones. No dry-run. | REGISTER. |
| `scripts/migrations/mct/run_full_user_import.sh` | Bulk-imports MCT users into Open edX. Stateful (tracks progress in a state file). | No dry-run; state file prevents double-import but does not protect against wrong environment. | REGISTER. |
| `scripts/tenants/sync-tenant-enterprise-mapping.sh` | Updates `ENTERPRISE_CUSTOMER_UUID` in `SiteConfiguration`. Database mutation. | No dry-run. | REGISTER. Add `--dry-run`. |
| `scripts/tenants/provision-mfe-config.sh` | Creates/updates MFE config API entries in the Open edX database. | No dry-run. | REGISTER. Add `--dry-run`. |
| `scripts/user-data-export.sh` | Exports PII to a local archive. No external mutation. | Low risk; additive only. | REGISTER (GDPR sensitivity demands audit trail). |

---

## Scripts with Emergency Self-Disabling Guards (document, then archive)

These scripts contain an explicit deprecation guard that exits unless a
legacy-override env var is set. They are dangerous only if the bypass is
used carelessly:

| Script | Self-Disable Guard | Risk |
|--------|--------------------|------|
| `scripts/export-k8s-manifests.sh` | `ALLOW_LEGACY_TUTOR_K8S=1` | LOW — guard is effective |
| `scripts/infra/deploy-aspects-k8s.sh` | `ALLOW_LEGACY_TUTOR_K8S=1` | LOW — guard is effective |

Both should be **ARCHIVED** (see ORPHAN_SHORTLIST.md). The `ALLOW_LEGACY_TUTOR_K8S`
env var should be documented in `docs/archive/` so future operators understand
the emergency path.

---

## Summary

| Risk | Ungoverned Scripts | Immediate Action |
|------|--------------------|-----------------|
| HIGH | 9 | REGISTER + add missing confirmation tokens |
| MEDIUM | 12 | REGISTER; add dry-run/token where noted |
| LOW | 18 | REGISTER; dry-run additions optional |
| GitOps Violation | 1 (`fix-velero-restore-test.sh`) | RESTRICT — delete and route through GitOps |

**Priority order for next governance sprint:**
1. `park-prod.sh` / `unpark-prod.sh` — production availability impact
2. `delete-user-events.sh` — GDPR irrevocability
3. `sync-mongodb-from-production.sh` — `--drop` without environment guard
4. `data-retention-jobs.sh` — scheduled irreversible SQL
5. `normalize-mysql-secrets.sh` — source-of-truth overwrites
6. `ensure-authentik-hardening.sh` / `ensure-authentik-admin-mfa.sh` — auth lockout risk
7. `fix-velero-restore-test.sh` — GitOps violation
