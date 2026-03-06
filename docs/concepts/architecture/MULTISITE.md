# Multi-site LMS Playbook
_Audience: Platform Eng + Design • Owner: Infra Team • Last updated: 2026-03-05_

This guide covers DNS setup, Tutor templating, database bootstrap, host ownership policy, and governance gates for the Mereka Academy multi-tenant deployment. It supersedes the stale 2025-09-10 version.

> **Microsite boundary:** `academy.biji-biji.com` and `skillourfuture.academy.mereka.io` are distinct client tenants with their own organizations and catalogs. Treat them as separate brands, not aliases.

## 0. Host Ownership Matrix

Every tenant owns exactly the LMS, Studio (CMS), and MFE host that belongs to its domain prefix.
No two tenants may share a host in production. Dev/staging exceptions require an explicit allowlist entry with an owner and expiry date.

### Production (GKE)

| Tenant | LMS Host | CMS Host | MFE Host |
|---|---|---|---|
| **mereka** | `academyv2.mereka.io` | `studio.academyv2.mereka.io` | `apps.academyv2.mereka.io` |
| **biji-biji** | `academy.biji-biji.com` | `studio.academy.biji-biji.com` | `apps.academy.biji-biji.com` |
| **skillourfuture** | `skillourfuture.academy.mereka.io` | `studio.skillourfuture.academy.mereka.io` | `apps.skillourfuture.academy.mereka.io` |

All three rows are disjoint — no sharing is permitted in production.

### Dev (rke2-nonprod)

| Tenant | LMS Host | CMS Host | MFE Host | Notes |
|---|---|---|---|---|
| **mereka** | `academyv2.mereka.dev` | `studio.academyv2.mereka.dev` | `apps.academyv2.mereka.dev` | |
| **mereka-preview** | `preview.academyv2.mereka.dev` | `studio.academyv2.mereka.dev` | `apps.academyv2.mereka.dev` | Shared Studio/MFE — allowlisted (read-only preview node) |

biji-biji and skillourfuture do not yet have dev domains. Testing for those tenants uses the main `academyv2.mereka.dev` cluster.

### Staging

| Tenant | LMS Host | CMS Host | MFE Host | Notes |
|---|---|---|---|---|
| **mereka** | `staging.academyv2.mereka.io` | `studio.staging.academyv2.mereka.io` | `apps.staging.academyv2.mereka.io` | |
| **mereka-preview** | `preview.staging.academyv2.mereka.io` | `studio.staging.academyv2.mereka.io` | `apps.staging.academyv2.mereka.io` | Shared Studio/MFE — allowlisted |

### Shared-host Allowlist (dev/staging only)

Shared Studio/MFE hosts for preview lanes are explicitly allowlisted in
`infrastructure/tutor/multisite-shared-host-allowlist.txt`. Each entry requires:

| Field | Required | Description |
|---|---|---|
| `host` | Yes | The shared hostname |
| `owner=<team>` | Yes | Team or person responsible for the exception |
| `expires=YYYY-MM-DD` | Yes | Date after which the allowlist entry becomes a governance FAIL |

Enterprise (production `.mereka.io`, `.biji-biji.com`) hosts are **never** allowed in the allowlist.
The governance gate (`scripts/qa/audit-tenant-config-safety.sh`) enforces all three fields and
fails the CI pipeline on expired or malformed entries.

## 1. Domains, DNS, and TLS

| Brand | Hostname | Notes |
| --- | --- | --- |
| Biji-Biji Academy | `academy.biji-biji.com` | apex domain managed by the Biji-Biji team |
| Skill Our Future | `skillourfuture.academy.mereka.io` | subdomain that lives inside the existing academyv2 zone (keep the Cloudflare record DNS-only; Universal SSL does not cover two-level wildcards) |

Tenant host ownership contract (strict):
- `academy.biji-biji.com` -> `studio.academy.biji-biji.com` + `apps.academy.biji-biji.com`
- `skillourfuture.academy.mereka.io` -> `studio.skillourfuture.academy.mereka.io` + `apps.skillourfuture.academy.mereka.io`
- Shared CMS/MFE hosts are allowed only for preview/dev lanes via explicit allowlist.
  - Canonical file: `infrastructure/tutor/multisite-shared-host-allowlist.txt`
  - Policy: entries MUST be preview/dev/staging scoped only; enterprise hosts are forbidden.
- `site_values` schema is enforced by `scripts/qa/verify-tenant-override-schema.sh` (required keys + allowed keys + org filter consistency).

> **Common mistake:** `skillsourfuture.academyv2.mereka.io` is **not** a canonical hostname and is not expected to resolve. The tenant domain is `skillourfuture.academy.mereka.io`.

1. Create `A`/`CNAME` records that resolve to the same load balancer / host IP that currently serves `academyv2.mereka.io`. The `skillourfuture.academy` record is tracked in `infrastructure/cloudflare/records.json` and must stay gray-clouded unless you buy an Advanced Certificate pack.
2. Manage `academy.biji-biji.com` from the `biji-biji.com` Cloudflare zone (flattened CNAME to `academyv2.mereka.io`, orange-clouded is fine there).  
3. Keep DNS-only CNAMEs for `preview.academyv2` and `notes.academyv2` pointing at `academyv2.mereka.io` so the edge proxy can keep issuing certificates without warnings.
3. Ensure the TLS certificate (Let’s Encrypt via Tutor’s Caddy proxy or your external ingress) contains both new hostnames. If you rely on Tutor’s built-in Caddy, re-run `tutor local start -d` after DNS is in place so Caddy can request new certificates.

## 2. Tutor templates & reverse proxy

Additional host headers need to flow through Caddy ➜ Nginx ➜ Django. The repo now patches Tutor templates automatically:

```bash
source infrastructure/tutor/tutor-env.sh
./infrastructure/tutor/apply-patches.sh
```

This script:

- Extends `ALLOWED_HOSTS`/`CSRF_TRUSTED_ORIGINS` inside `lms/production.py`.
- Adds the new hostnames to `env/apps/nginx/lms.conf`.
- Injects dedicated server blocks inside `env/apps/caddy/Caddyfile`.

After running the script, recycle the edge services so they reread the config:

```bash
source infrastructure/tutor/tutor-env.sh
tutor local restart caddy nginx lms
```

> **Note:** The restart is only required after the production `tutor_env/` tree has been patched. Git history already captures the template tweaks.

## 3. Bootstrap django_site + SiteConfiguration

The LMS reads per-domain overrides from Django’s Site framework. Use the helper that ships with this repo:

```bash
source infrastructure/tutor/tutor-env.sh
# Ensure PyMySQL + Cloud SQL connector are installed once (`pip install PyMySQL "cloud-sql-python-connector[pymysql]"`)
# Preview the operations first
python scripts/shared/multisite_bootstrap.py
# Apply when ready (requires connectivity to the LMS MySQL instance)
python scripts/shared/multisite_bootstrap.py --apply
```

What the script does:

1. Reads `tutor_env/env/apps/openedx/config/lms.env.yml` to locate the Open edX MySQL host/credentials.
2. Reads multisite definitions from `infrastructure/tutor/multisite-sites.yml` (source of truth).
3. Ensures the `MEREKA`, `BIJIBIJI`, and `SKILLOURFUTURE` records exist in `organizations_organization`.
4. Upserts `django_site` entries plus matching `SiteConfiguration` rows with:
   - `platform_name`, `site_name`, and logo metadata.
   - `LMS_ROOT_URL`, `CMS_ROOT_URL`, `MFE_BASE_URL` for correct redirects and MFE config behavior.
   - `course_org_filter` so each microsite only surfaces its own organization’s catalog.
   - `ENABLE_COMPREHENSIVE_THEMING` + `THEME_NAME=mereka` (custom themes can be layered in later).

**Dev environment:** use `infrastructure/tutor/multisite-sites.dev.yml` (or set `MULTISITE_DEFINITIONS_PATH`) to avoid accidentally applying production domains into the dev database.

**Connecting to Cloud SQL**

- If you already have network access to the database (e.g., you are on a bastion/runner inside the GCP VPC), just run the commands above.
- To tunnel traffic from your laptop, run the Cloud SQL Auth Proxy (or `gcloud sql connect`) locally and point the script at `127.0.0.1`, e.g. `python scripts/shared/multisite_bootstrap.py --host 127.0.0.1 --port 3307 --apply`.
- When you are able to run inside GCP and prefer IAM authentication over a TCP tunnel, the script can talk through the Cloud SQL Python Connector: `python scripts/shared/multisite_bootstrap.py --use-connector --instance mereka-lms:asia-southeast1:mereka-lms-mysql --ip-type PRIVATE --apply`.  
  Private-IP connections still require the runtime to live on a host that can reach the same VPC; when you’re off-network, temporarily assigning a public IP that is locked down to your own `/32` and then removing it afterwards is the quickest path.

## 4. Governance & roles

- **Platform Admins**: Full access across all sites; approve domain/secret changes.
- **Client Admins**: Scoped to their org (`BIJIBIJI`, `SKILLOURFUTURE`) and responsible for catalog content.
- **Course Authors**: Must create courses under the correct org; violations surface on the wrong microsite.
- **Change approvals**: Any domain, TLS, or theme change requires a release checklist sign-off (see `docs/ops/security/RELEASE_CHECKLIST_DOMAIN_SECRETS.md`).

**Tenant Brand Pack Workflow**

For new tenants or brand updates, follow the **Fast-Path Brand Pack Flow**:

1. **Create brand pack**: Copy template from `infrastructure/tutor/themes/mereka/tenants/_template/`
2. **Validate**: Run `./scripts/tenants/validate-tenant-brand-pack.sh --slug <tenant-slug>`
3. **Apply branding**: Run `collectstatic` to sync assets
4. **Verify runtime**: Check MFE config API (`/api/v1/mfe_config`)

**Reference**:
- **Fast-Path Flow**: `docs/operations/TENANT_PROVISIONING.md#fast-path-brand-pack-flow`
- **Schema Docs**: `docs/guides/branding/TENANT_BRAND_PACK_SCHEMA.md`
- **Contract**: `docs/guides/branding/TENANT_BRANDING_CONTRACT.md`

**Theming validation checklist**
1. Sync assets: `make branding-sync`
2. Verify logos: `./scripts/branding/verify-logo-setup.sh`
3. Validate brand pack: `./scripts/tenants/validate-tenant-brand-pack.sh`
4. Confirm `course_org_filter` + `THEME_NAME` in `infrastructure/tutor/multisite-sites.yml`
5. Capture LMS/Studio/MFE screenshots for each microsite before release

## 5. Content governance

- **Organizations:** Authors must create courses under the correct org (`BIJIBIJI` or `SKILLOURFUTURE`). Organization-level roles and tenant-owned Studio hosts keep authoring boundaries explicit.
- **Discovery / catalog:** The `course_org_filter` value surfaces the right subset of courses at runtime. Discovery also supports organization and catalog filters if you need to hide courses from anonymous visitors.
- **Themes:** All microsites currently reuse the Mereka comprehensive theme. When brand assets are ready, add new theme directories under `infrastructure/tutor/themes/` (e.g., `infrastructure/tutor/themes/biji-biji`) and update each site configuration with `THEME_NAME`. Tutor already copies the entire `infrastructure/tutor/themes/` tree, so per-site themes only require CSS + static assets.

## 6. Verification checklist

1. Run `./scripts/qa/public-health-check.sh prod` and verify all endpoints are green.
2. `curl -I https://academy.biji-biji.com/health` and `curl -I https://skillourfuture.academy.mereka.io/health` should return `200` after DNS + TLS propagate.
2. Visit each domain in a browser, confirm the navbar title, footer copy, and catalog results reflect the new brand.
3. Log into Studio (`https://studio.academyv2.mereka.io`), create a course under each organization, then make sure only the matching microsite displays it.
4. Spot-check CSRF/login by signing in/out through the new hostnames.
- Governance wrapper: `./scripts/qa/run-multisite-governance-gates.sh --env dev` maps the tenant-branding runtime probe to `local` (the verifier accepts `prod|staging|local`).
- If Cloudflare ever shows `525` for `skillourfuture…`, double-check the record is gray-clouded. Multi-level subdomains fall outside Universal SSL coverage, so Origin-only TLS is expected there.

## 7. Operational notes

- Microsites cover the learner-facing LMS and MFEs only. Studio, Discovery, ecommerce (legacy Oscar, being replaced by Purchase Gateway), and background services remain shared across all brands.

> **Note**: The legacy Oscar-based ecommerce service is being replaced by the custom Purchase Gateway (`services/purchase-gateway/`). See `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md` for details.
- Forum is deployed at `forum.academyv2.mereka.io` (and `.dev`) but is **API-first**; the learner discussion UI is embedded inside LMS course pages, and moderation happens via Studio.
- Any `tutor config save` run must be followed by `./infrastructure/tutor/apply-patches.sh` so the additional host headers stay injected.
- Back up the database (`tutor local do backup-db` / `scripts/infra/backup-db.sh`) before rolling out further domain changes.

## 8. Host Ownership Migration and Rollback

### When to use this section

Use this procedure when:
- Assigning a new dedicated Studio or MFE host to a tenant that currently shares one
- Renaming a tenant domain
- Removing an expired allowlist entry that is still in active use

### Pre-migration checklist

```bash
# 1. Confirm current state of the audit gate (must be green before starting)
STRICT=1 ./scripts/qa/audit-tenant-config-safety.sh

# 2. Snapshot the Site/SiteConfiguration state in MySQL
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms shell -c "
from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
for s in Site.objects.all():
  try:
    sc = s.configuration
    print(s.domain, sc.values.get('CMS_ROOT_URL'), sc.values.get('MFE_BASE_URL'))
  except SiteConfiguration.DoesNotExist:
    print(s.domain, 'no-SiteConfiguration')
"

# 3. Take a database backup
./scripts/infra/backup-db.sh
```

### Migration steps

1. **Update the YAML source of truth** — edit `infrastructure/tutor/multisite-sites.yml`
   (prod), `multisite-sites.dev.yml` (dev), or `multisite-sites.staging.yml` (staging)
   with the new host values.

2. **Update the allowlist if required** — add or remove entries in
   `infrastructure/tutor/multisite-shared-host-allowlist.txt` with correct `owner=` and
   `expires=` fields.

3. **Run the governance gate** to confirm no violations:

   ```bash
   STRICT=1 ./scripts/qa/audit-tenant-config-safety.sh
   ```

4. **Commit and push** — CI will re-run the gate on the PR.

5. **Apply to the live cluster** (after merge):

   ```bash
   # Re-bootstrap SiteConfiguration from the updated YAML
   python scripts/shared/multisite_bootstrap.py --apply

   # Restart LMS to pick up the new SiteConfiguration cache
   kubectl rollout restart -n mereka-lms deployment/lms
   kubectl rollout status -n mereka-lms deployment/lms
   ```

6. **Verify** each affected domain:

   ```bash
   # Check LMS responds on the new host
   curl -I https://<new-lms-host>/health

   # Check CMS (Studio) responds on the new host
   curl -I https://<new-cms-host>/health

   # Check MFE renders (expect 200 on the login page)
   curl -I https://<new-mfe-host>/authn/login
   ```

### Rollback procedure

If the migration causes issues, rollback in reverse order:

```bash
# 1. Revert the YAML file(s) to the previous commit
git revert HEAD --no-edit   # or git checkout <previous-sha> -- infrastructure/tutor/multisite-sites.yml

# 2. Re-run bootstrap to restore the previous SiteConfiguration
python scripts/shared/multisite_bootstrap.py --apply

# 3. Restart LMS
kubectl rollout restart -n mereka-lms deployment/lms
kubectl rollout status -n mereka-lms deployment/lms

# 4. Confirm the governance gate is green again
STRICT=1 ./scripts/qa/audit-tenant-config-safety.sh

# 5. If DNS records were changed, revert them via bbi-infrastructure (Cloudflare IaC).
#    DNS TTL is typically 60–300 s; wait for propagation before declaring rollback complete.
```

### Verification commands reference

| Command | What it checks |
|---|---|
| `STRICT=1 ./scripts/qa/audit-tenant-config-safety.sh` | Host uniqueness, allowlist policy, expiry |
| `OUTPUT_FORMAT=json ./scripts/qa/audit-tenant-config-safety.sh` | Same checks, machine-readable |
| `STRICT=1 ./scripts/qa/verify-multisite-config.sh prod` | Live DB — SiteConfiguration correctness |
| `./scripts/qa/public-health-check.sh prod` | HTTP health of all public endpoints |
| `./scripts/qa/run-multisite-governance-gates.sh --env both` | Full governance sweep (all environments) |
