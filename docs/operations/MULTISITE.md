# Multi-site LMS Playbook
_Audience: Platform Eng + Design • Owner: Infra Team • Last verified: 2025-09-10_

This guide captures the steps required to attach additional branded experiences to the canonical `academyv2.mereka.io` Tutor deployment. It covers DNS, Tutor templating changes, database bootstrap, and validation.

> **Microsite boundary:** `academy.biji-biji.com` and `skillourfuture.academy.mereka.io` are distinct client tenants with their own organizations and catalogs. Treat them as separate brands, not aliases.

## 1. Domains, DNS, and TLS

| Brand | Hostname | Notes |
| --- | --- | --- |
| Biji-Biji Academy | `academy.biji-biji.com` | apex domain managed by the Biji-Biji team |
| Skill Our Future | `skillourfuture.academy.mereka.io` | subdomain that lives inside the existing academyv2 zone (keep the Cloudflare record DNS-only; Universal SSL does not cover two-level wildcards) |

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
- **Change approvals**: Any domain, TLS, or theme change requires a release checklist sign-off (see `docs/operations/RELEASE_CHECKLIST_DOMAIN_SECRETS.md`).

**Theming validation checklist**
1. Sync assets: `make branding-sync`
2. Verify logos: `./scripts/branding/verify-logo-setup.sh`
3. Confirm `course_org_filter` + `THEME_NAME` in `infrastructure/tutor/multisite-sites.yml`
4. Capture LMS/Studio/MFE screenshots for each microsite before release

## 5. Content governance

- **Organizations:** Authors must create courses under the correct org (`BIJIBIJI` or `SKILLOURFUTURE`). Organization-level roles keep Studio permissions separated even though everyone still signs into `studio.academyv2.mereka.io`.
- **Discovery / catalog:** The `course_org_filter` value surfaces the right subset of courses at runtime. Discovery also supports organization and catalog filters if you need to hide courses from anonymous visitors.
- **Themes:** All microsites currently reuse the Mereka comprehensive theme. When brand assets are ready, add new theme directories under `infrastructure/tutor/themes/` (e.g., `infrastructure/tutor/themes/biji-biji`) and update each site configuration with `THEME_NAME`. Tutor already copies the entire `infrastructure/tutor/themes/` tree, so per-site themes only require CSS + static assets.

## 6. Verification checklist

1. Run `./scripts/qa/public-health-check.sh prod` and verify all endpoints are green.
2. `curl -I https://academy.biji-biji.com/health` and `curl -I https://skillourfuture.academy.mereka.io/health` should return `200` after DNS + TLS propagate.
2. Visit each domain in a browser, confirm the navbar title, footer copy, and catalog results reflect the new brand.
3. Log into Studio (`https://studio.academyv2.mereka.io`), create a course under each organization, then make sure only the matching microsite displays it.
4. Spot-check CSRF/login by signing in/out through the new hostnames.
- If Cloudflare ever shows `525` for `skillourfuture…`, double-check the record is gray-clouded. Multi-level subdomains fall outside Universal SSL coverage, so Origin-only TLS is expected there.

## 7. Operational notes

- Microsites cover the learner-facing LMS and MFEs only. Studio, Discovery, ecommerce, and background services remain shared across all brands.
- Forum remains internal to LMS (no dedicated public hostname). Discussions render inside course pages, and moderation happens via Studio.
- Any `tutor config save` run must be followed by `./infrastructure/tutor/apply-patches.sh` so the additional host headers stay injected.
- Back up the database (`tutor local do backup-db` / `scripts/infra/backup-db.sh`) before rolling out further domain changes.
