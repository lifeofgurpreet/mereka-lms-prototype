# Repository Guidelines

## CRITICAL - Data Protection Rules

> **Master policy:** https://github.com/Biji-Biji-Initiative/BBI-K8/blob/main/docs/DATA_PROTECTION.md

### Forbidden Actions (Require Explicit User Confirmation)

1. Delete PVCs, PVs, or namespaces containing databases
2. Delete or scale StatefulSets/Deployments with databases to 0
3. Modify volumeClaimTemplates in StatefulSets
4. Run database DROP/TRUNCATE/DELETE commands
5. Delete Helm releases containing databases
6. Modify storage configurations that could cause data loss

### Before Any Risky Operation

Always create a Velero backup first:
```bash
velero backup create pre-op-<namespace>-$(date +%Y%m%d-%H%M) --include-namespaces <namespace> --wait
```

Then ask for explicit user confirmation before proceeding.

**Backup Docs:** https://github.com/Biji-Biji-Initiative/BBI-K8/blob/main/docs/BACKUP_AND_RECOVERY.md

---

## Project Structure & Module Organization
- **Infrastructure**: `infrastructure/` contains Tutor configs (`infrastructure/tutor/`), Terraform, K8s manifests, and themes
- **Scripts**: `scripts/` contains automation organized by domain (infra, migrations, branding, analytics, qa)
- **Services**: `services/` contains standalone microservices and webhooks
- **Documentation**: `docs/` organized by category (onboarding, operations, migrations, architecture, status)
- **Runtime artifacts**: `var/` (gitignored) contains logs, exports, and migration outputs

The generated Tutor state (`tutor_env/`) is git-ignored; use `infrastructure/tutor/config.example.yml` as a starting point for new overrides.

## Build, Test, and Development Commands
- **Setup**: `make bootstrap` sets up venv and pre-commit hooks, then `source infrastructure/tutor/tutor-env.sh` to activate Tutor environment.
- Redwood’s asset build needs headroom: configure Docker Desktop with ≥12 GB RAM and 2–4 GB swap (Settings → Resources) before running `tutor images build openedx`.
- `tutor images build mfe` rebuilds the micro-frontend image with the Node 18 patch applied.
- `tutor local quickstart -I` performs an end-to-end configure + launch of the nightly stack.
- `tutor local start -d` / `tutor local stop` manage day-to-day lifecycle; add `tutor local dc ps` to inspect container health and `tutor local logs --tail=100` to debug.
- `make tutor-apply` (or `./infrastructure/tutor/apply-patches.sh`) keeps Tutor's rendered local/k8s templates using `--default-authentication-plugin=mysql_native_password` so MySQL 8 starts cleanly after `tutor config save` regenerations.

## Branding Maintenance
- Theme tokens/fonts live in `infrastructure/tutor/themes/mereka` with the spec documented in `docs/BRANDING.md`; sync new assets into `assets/branding/` first, then run `make branding-sync` (or `./scripts/branding/sync-brand-assets.sh`).
- Enable the LMS/Studio theme locally by running `tutor config save --set THEME_DIR="$(pwd)/infrastructure/tutor/themes" --set THEME_NAME=mereka`, executing `make tutor-apply`, rebuilding `openedx`, and starting the stack.
- Use `./scripts/branding/setup-mfe-branding.sh` after `tutor dev start mfe --detach` to clone the canonical MFEs, copy the fonts, and drop `src/styles/mereka.scss` + import stubs. Each repo then runs `npm install && npm start` from `tutor_env/dev/frontend-app-*`.
- After any theme edit, rebuild `openedx`/`mfe` images (or rerun `npm start`) and capture screenshots before shipping.

## Theme Deployment to GKE (For AI Agents)

**🚨 CRITICAL: Understand the deployment architecture before making changes.**

### Architecture Overview
- **Theme files** live in `infrastructure/tutor/themes/mereka/` (SCSS, templates)
- **Brand assets** live in `assets/branding/` (logos, fonts, favicons)
- **Images are built locally** on VPS, then pushed to Artifact Registry
- **GKE pulls images** from `asia-southeast1-docker.pkg.dev/mereka-lms/openedx`
- **K8s deployments** must be updated to use new image tags

### Deployment Sequence (DO NOT SKIP STEPS)

1. **Modify theme files** in `infrastructure/tutor/themes/mereka/`
2. **Sync brand assets**: `./scripts/branding/sync-brand-assets.sh`
3. **Apply patches**: `./infrastructure/tutor/apply-patches.sh`
4. **Build images** (~60-90 min first build, ~15 min with cache):
   ```bash
   source .venv/bin/activate
   export TUTOR_ROOT="$(pwd)/tutor_env"
   tutor images build openedx
   tutor images build mfe  # if MFE changed
   ```
5. **Authenticate to Artifact Registry**: `gcloud auth configure-docker asia-southeast1-docker.pkg.dev`
6. **Tag images**:
   ```bash
   docker tag tutor_local/openedx:latest asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG
   ```
7. **Push images**: `docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG`
8. **Update K8s deployments**:
   ```bash
   kubectl set image deployment/lms lms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG -n mereka-lms
   # Repeat for cms, lms-worker, cms-worker, mfe
   ```
9. **Verify rollout**: `kubectl rollout status deployment/lms -n mereka-lms`

### Common Mistakes (AVOID THESE)
1. **Building locally without pushing** → Changes only exist on VPS, GKE still uses old images
2. **Forgetting to authenticate Docker** → 403 errors when pulling cache
3. **Not updating K8s deployments** → Pods still use stock Docker Hub images
4. **Skipping `apply-patches.sh`** → MySQL auth fails, Node version wrong

### Brand Guidelines Reference
Official Mereka brand assets: `https://github.com/biji-biji-initiative/bbbi-mereka-brand-assets/tree/main/brands/mereka`

| Color | Hex | Usage |
|-------|-----|-------|
| Teal | `#2d898b` | Primary accent, hover states |
| Magenta | `#ab3b78` | CTA buttons, highlights |
| Blue | `#295cad` | Links, info states |
| Black | `#000000` | Primary text, headings |

| Font | Usage |
|------|-------|
| Lato | Headings, UI labels |
| Poppins | Body text, paragraphs |

## MongoDB Atlas-Only Architecture

**🚨 CRITICAL: This project uses MongoDB Atlas exclusively. No local MongoDB is deployed.**

### Architecture Decision
- **Cluster**: `cluster-mereka-lms.2pjex4s.mongodb.net` (MongoDB Atlas)
- **Databases**: `openedx` (modulestore), `cs_comments_service` (forum)
- **Why Atlas**: Zero maintenance overhead, automatic backups, managed scaling
- **Local MongoDB**: Disabled in K8s manifests (commented out)

See `docs/adr/001-mongodb-atlas.md` for full rationale.

### Connection Details
| Service | Database | Connection |
|---------|----------|------------|
| LMS/CMS | `openedx` | Atlas via `MONGODB_PASSWORD` env var |
| Forum | `cs_comments_service` | Atlas via `MONGODB_PASSWORD` env var |

### Secret Management
- Password stored in Infisical: `MEREKA_LMS_MONGODB_PASSWORD`
- Synced to K8s via ExternalSecrets → `openedx-secrets`
- Python code uses `os.environ.get("MONGODB_PASSWORD")`

### NEVER DO
1. ❌ Deploy local MongoDB
2. ❌ Change connection strings to `localhost` or `mongodb`
3. ❌ Hardcode MongoDB password in files

## Coding Style & Naming Conventions
Shell scripts should begin with `#!/usr/bin/env bash`, enable `set -euo pipefail`, and prefer descriptive function names over inline command chains. Keep Bash indented with two spaces; YAML templates should mirror Tutor defaults and group environment variables in uppercase (e.g., `OPENEDX_RELEASE`). When extending scripts, mirror the existing comment style that summarizes intent rather than mechanics.

## Testing Guidelines
Treat `tutor local quickstart -I` as the acceptance test for major changes—capture failures before opening a PR. Use `tutor local dc ps` to confirm every service reports `Up`, and spot-check critical logs with `tutor local logs --tail=50 service`. If you alter the MFE patches, confirm `node:18` appears in the generated Dockerfile under `tutor_env/env/plugins/mfe/build/mfe/`, and sanity-check `tutor_env/env/local/docker-compose.yml` still exposes `MYSQL_ROOT_HOST: "%"`.

## Commit & Pull Request Guidelines
There is no upstream history yet, so follow Conventional Commits (`feat:`, `fix:`, `docs:`) to seed a consistent log; e.g., `fix: ensure tutor env script exits when .venv missing`. PRs should include a concise summary, the Tutor commands you ran, and links to any relevant docs you touched. Attach log excerpts or screenshots whenever behaviour changes, and request review before rolling out infrastructure-affecting adjustments.

## Security & Configuration Notes
Never commit secrets—`tutor_env/config.yml` stays local and is recreated from `infrastructure/tutor/config.example.yml`. Run `tutor local do backup-db` before upgrades and stash dumps outside the repo. When experimenting with new Tutor plugins or releases, isolate the changes under a feature branch and document toggles in `docs/` so operators can reproduce the configuration, and re-run the patch script immediately after each `tutor config save`.

## Secrets Management Architecture

**Full Documentation**: `/home/gurpreet/projects/secrets-management/specs/`

### Single Source of Truth: Infisical

**All secrets are managed in Infisical** (secrets.mereka.io) with automated propagation to downstream systems.

```
Infisical (edit here) → GCP Secret Manager → K8s Secrets (ESO) → Pods
                     ↓
                     VPS Apps (infisical run)
```

### Key Principles

1. **NEVER edit secrets in GCP, K8s, or .env files directly** - Infisical is the only place for edits
2. **Runtime injection** - Secrets injected via environment variables, never stored in files
3. **Automated sync** - GitHub Actions sync Infisical → GCP (on every push)
4. **External Secrets Operator (ESO)** - Syncs GCP → K8s Secrets (1h refresh)

### Folder Structure

See `/home/gurpreet/projects/secrets-management/specs/02-infisical/FOLDER-STRUCTURE.md` for complete structure.

```
/ (root)
├── /shared/                    # Shared across apps
│   ├── /ai/                    # OPENAI_API_KEY, GEMINI_API_KEY, etc.
│   ├── /oauth/                 # Google OAuth credentials
│   ├── /infra/                 # Contabo, Sentry
│   └── /integrations/          # Rube, Context7, Celery
│
├── /vps/                       # VPS standalone apps
│   ├── /g-finances/
│   ├── /nfc-cards/
│   ├── /spoken/
│   └── /legal-agent/
│
└── /k8s/                       # Kubernetes apps
    ├── /authentik/
    ├── /n8n/
    ├── /listmonk/
    ├── /temporal/
    ├── /twentycrm/
    ├── /reka-slackbot/
    └── /mereka-backend/
```

### Mereka LMS Secret Placement
- **All** `MEREKA_LMS_*` secrets live under `/k8s/mereka-lms` (prod + dev envs).
- Shared admin test credentials live under `/shared/oauth`:
  - `GOOGLE_IMPERSONATE_EMAIL`
  - `GOOGLE_IMPERSONATE_PASSWORD`
  - Use these for Authentik + LMS (GKE + VPS kind). Never commit values.

### AWS SES Configuration

**IAM User**: `ses-smtp-user.20251113-104139-g-test-singapore`
**Region**: `ap-southeast-1` (Singapore)
**Status**: Production mode (200,000 emails/day @ 100/sec)

#### Credentials Locations

| System | Secret Name | Location |
|--------|-------------|----------|
| **Infisical** | `AWS_ACCESS_KEY_ID`<br>`AWS_SECRET_ACCESS_KEY` | `/` (root, prod env) |
| **GCP Secret Manager** | `aws-access-key-id`<br>`aws-secret-access-key`<br>`ses-smtp-username`<br>`ses-smtp-password` | `mereka-lms` project |
| **K8s Secret** | `RELAY_USERNAME`<br>`RELAY_PASSWORD` | `ses-smtp-credentials` (mereka-lms namespace) |
| **AWS CLI** | Configured | `~/.aws/credentials` |

#### AWS CLI Usage

```bash
# Already configured - credentials auto-loaded from GCP Secret Manager
source .venv/bin/activate

# Check sending quota
aws ses get-send-quota

# List verified domains/emails (16 identities including mereka.io)
aws ses list-identities

# Send test email
aws ses send-email \
  --from noreply@mereka.io \
  --to your@email.com \
  --subject "Test Email" \
  --text "Test message"

# Get sending statistics
aws ses get-send-statistics

# Verify new email/domain
aws ses verify-email-identity --email-address new@mereka.io
```

#### SMTP vs API Credentials

- **SMTP Credentials** (`RELAY_USERNAME`/`RELAY_PASSWORD`): Used by Open edX email relay (port 587)
- **API Credentials** (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`): Used by AWS CLI for SES management

**IMPORTANT**: SMTP password ≠ AWS Secret Access Key. SMTP password is derived from the IAM credentials but is NOT reversible.

### Retrieving Secrets

#### From Infisical (Primary Source)

```bash
cd ~/projects/k8s/reka-slackbot  # Has .infisical.json

infisical secrets get SECRET_NAME \
  --domain https://secrets.mereka.io/api \
  --env prod --path / --plain
```

#### From GCP Secret Manager

```bash
gcloud secrets versions access latest \
  --secret=SECRET_NAME \
  --project=mereka-lms
```

#### From Kubernetes

```bash
kubectl get secret SECRET_NAME -n NAMESPACE \
  -o jsonpath='{.data.KEY}' | base64 -d
```

### Common Secrets

| Secret | Infisical Path | Used By |
|--------|----------------|---------|
| `AWS_ACCESS_KEY_ID` | `/` | AWS CLI, SES API |
| `AWS_SECRET_ACCESS_KEY` | `/` | AWS CLI, SES API |
| `CLOUDFLARE_TOKEN_MEREKA_IO` | `/` (use `--recursive`) | DNS management |
| `CLOUDFLARE_TOKEN_MEREKA_DEV` | `/` (NO recursive) | DNS management |
| `B2_ACCOUNT_ID` | `/` | Backblaze backups |
| `B2_APPLICATION_KEY` | `/` | Backblaze backups |
| `OPENAI_API_KEY` | `/shared/ai` | AI features |

### Security Best Practices

1. **Never commit secrets** - `.env`, `config.yml`, credentials go in `.gitignore`
2. **Use Infisical CLI in CI/CD** - `infisical run -- command` for runtime injection
3. **Rotate credentials regularly** - Update in Infisical, sync propagates automatically
4. **Least privilege** - Apps only access their scoped paths
5. **Audit logs** - All Infisical access is logged

### Related Documentation

- Architecture: `/home/gurpreet/projects/secrets-management/specs/01-architecture/OVERVIEW.md`
- Inventory: `/home/gurpreet/projects/secrets-management/specs/00-overview/INVENTORY.md`
- Operations: `/home/gurpreet/projects/secrets-management/specs/07-operations/INCIDENT-RESPONSE.md`

## Local Development Priority

**🚨 CRITICAL: Always develop and test locally before touching cloud instances.**

### Quick Reference
- **Setup Guide:** `docs/onboarding/LOCAL_DEVELOPMENT_GUIDE.md` (complete instructions)
- **Quick Start:** `docs/onboarding/QUICK_START_LOCAL.md` (5-minute setup)
- **Daily Workflow:** `docs/onboarding/WORKFLOW_LOCAL.md`

### Essential Rules

1. **Always set `TUTOR_ROOT`** before Tutor commands:
   ```bash
   export TUTOR_ROOT="$(pwd)/tutor_env"
   source .venv/bin/activate
   ```

2. **Always use local Docker service names** in config:
   - ✅ `MYSQL_HOST=mysql` (local Docker service)
   - ❌ `MYSQL_HOST=10.97.0.2` (cloud IP - WRONG!)

3. **Always run `make tutor-apply`** (or `./infrastructure/tutor/apply-patches.sh`) after:
   - `tutor config save`
   - Plugin changes
   - Any config modification

4. **Verify config is local** before starting:
   ```bash
   grep -E "MYSQL_HOST|MONGODB_HOST|REDIS_HOST" tutor_env/config.yml
   # Should show: mysql, mongodb, redis (NOT cloud IPs)
   ```

### Fix Cloud IPs Immediately

If you see cloud IPs (like `10.97.0.2`) in config:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate
tutor config save \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set MONGODB_PORT=27017
make tutor-apply
```

### Verification Commands

```bash
# Check containers running
docker ps --filter "name=tutor_local" | wc -l  # Should be 24

# Check config is local
grep MYSQL_HOST tutor_env/config.yml  # Should be "mysql"

# Test services
curl -I http://localhost
curl -I http://apps.localhost/authn/login
```

## Troubleshooting & Site Recovery
**🚨 If the site is down**, start with `docs/operations/TROUBLESHOOTING.md`—it has a 5-command diagnostic checklist. The most common issue is service selector mismatches after pod restarts. Quick fix: run `./scripts/infra/fix-service-selectors.sh` to automatically sync all service selectors with current pod instance IDs. Always check `kubectl get endpoints -n mereka-lms` first—empty endpoints (`<none>`) mean services can't route traffic. After any pod restarts or `tutor k8s` commands, verify endpoints are populated.

**Redis host drift will hard-hang LMS/CMS.** If pods are healthy but requests time out/return 499, inspect the rendered configmap (`openedx-config-*.json`). The Redis host must be `redis:6379`; replace any baked-in IPs (e.g., `10.x.x.x:6379`) and restart lms/cms.

**Login failures (CSRF 403 or 500 on login_session).** Ensure `CSRF_TRUSTED_ORIGINS` includes `https://academyv2.mereka.io`, `https://studio.academyv2.mereka.io`, `https://apps.academyv2.mereka.io`, `https://academy.biji-biji.com`, and `https://skillourfuture.academy.mereka.io`. Set `CSRF_COOKIE_DOMAIN=.academyv2.mereka.io` and `SESSION_COOKIE_DOMAIN=.academyv2.mereka.io` in `openedx-config-*.json` and restart lms/cms. If a specific user still errors with JSONDecodeError on login, reset `user.profile.meta` to `{}` and reset the password.

### Domain & Auth Notes (Current)
- **Production (GKE):** `academyv2.mereka.io`, `studio.academyv2.mereka.io`, `apps.academyv2.mereka.io`,
  `discovery.academyv2.mereka.io`, `ecommerce.academyv2.mereka.io`, `credentials.academyv2.mereka.io`,
  `forum.academyv2.mereka.io`, `notes.academyv2.mereka.io`, `preview.academyv2.mereka.io`
- **Development (VPS kind):** `academyv2.mereka.dev`, `studio.academyv2.mereka.dev`, `apps.academyv2.mereka.dev`,
  `discovery.academyv2.mereka.dev`, `ecommerce.academyv2.mereka.dev`, `credentials.academyv2.mereka.dev`,
  `forum.academyv2.mereka.dev`, `notes.academyv2.mereka.dev`, `preview.academyv2.mereka.dev`
- **Subsites (separate clients):** `skillourfuture.academy.mereka.io`, `academy.biji-biji.com`
- Authentik base URL: `https://auth0.mereka.io`
- Authn MFE shows two login methods: local LMS credentials + “Sign in with Mereka” (OIDC)
- Shared admin test creds in Infisical `/shared/oauth`: `GOOGLE_IMPERSONATE_EMAIL`, `GOOGLE_IMPERSONATE_PASSWORD`

**Operational learnings (read these before touching auth/Forum/Secrets):**
- Atlas allowlist drift breaks dev forum; see `docs/MONGODB_ATLAS.md` and `docs/operations/TROUBLESHOOTING.md`.
- Infisical is the single source of truth; validate with `scripts/infra/infisical-validate-mereka-lms.sh`.
- Use `scripts/infra/infisical-sync-mereka-lms.sh` to consolidate `MEREKA_LMS_*` secrets under `/k8s/mereka-lms`.
- Public endpoint health checks + cert SAN verification: `scripts/qa/public-health-check.sh` and `scripts/infra/check-cert-sans.sh`.
- Branding checks are part of health verification: `CHECK_BRANDING=1 scripts/qa/public-health-check.sh prod`.
- Blank account settings/profile pages usually indicate stale cookies or MFE config mismatch; test in a fresh browser and verify `https://apps.academyv2.mereka.io/api/mfe_config/v1`.
- Studio course creation requires `CourseCreator` state=granted (see `docs/operations/TROUBLESHOOTING.md`).
- Atlas user must have `readWrite` on `openedx` + `cs_comments_service` for modulestore + forum.
- Atlas CLI can be configured from Infisical keys via `scripts/infra/atlas-config-from-infisical.sh` (keys in `/k8s/mereka-lms/atlas`).

---

## iOS CI/CD Rules (CRITICAL for AI Agents)

**Spec**: `docs/ios-cicd-spec.md`  
**Learnings**: `docs/IOS_DEPLOYMENT_LEARNINGS.md`  
**Workflow**: `.github/workflows/build-ios-app.yml`

### Non-Negotiables

| Rule | Reason |
|------|--------|
| NEVER put signing flags in `xcargs` | Breaks framework targets |
| NEVER use `fastlane produce` for capabilities | Requires username/password, not API Key |
| NEVER delete entitlements to make builds pass | Breaks features in production |
| NEVER use fixed build numbers | TestFlight rejects duplicates |
| ALWAYS override `fastlane/Appfile` in CI | Prevents org.openedx.app bundle ID |
| ALWAYS disable signing for framework targets | Frameworks don't use provisioning profiles |

### Quick Fixes

| Error | Solution |
|-------|----------|
| `Framework.framework does not support provisioning profiles` | Remove signing from xcargs, use export_options only |
| `No suitable application records - org.openedx.app` | Override Appfile: `cat > fastlane/Appfile <<< 'app_identifier(ENV["BUNDLE_ID"])'` |
| `Profile doesn't support capability X` | Enable manually in Apple Portal, NOT via Fastlane |
| `No signing certificate for target 'Profile'` | Set `CODE_SIGNING_ALLOWED = NO` for framework targets |

### Correct build_app Configuration

```ruby
build_app(
  export_options: {
    signingStyle: "manual",
    teamID: ENV.fetch("TEAM_ID"),
    provisioningProfiles: {
      ENV.fetch("BUNDLE_ID") => "match AppStore #{ENV.fetch("BUNDLE_ID")}"
    }
  },
  # NO signing flags in xcargs!
  xcargs: "-skipPackagePluginValidation -skipMacroValidation"
)
```

### Enabling New Capabilities

1. Go to https://developer.apple.com/account/resources/identifiers/
2. Find `com.mereka.academy.mobile`
3. Enable the capability
4. Trigger CI build (match will regenerate profile with `force: true`)

---

## Skills (For AI Agents)

This project uses shared skills from the team-skills repository. These skills provide reusable prompts and workflows for common tasks.

**Skills Repository:** `https://github.com/Biji-Biji-Initiative/team-skills`

### Enabled Plugins

| Plugin | Path | Description |
|--------|------|-------------|
| core | `plugins/core` | Universal standards - commit, review, security, testing, **readme** |
| web | `plugins/web` | Web frontend - React, Next.js, CSS, accessibility |
| backend | `plugins/backend` | Backend services - API design, databases, auth |

### Available Skills

From `plugins/core/skills/`:
- **commit** - Conventional commit messages
- **review** - Code review checklist
- **security** - Security audit patterns
- **testing** - Test coverage strategies
- **readme** - TTFS-focused README creation (Time-to-First-Success)

From `plugins/web/skills/`:
- **react** - React component patterns
- **nextjs** - Next.js app patterns
- **styling** - CSS/Tailwind patterns

From `plugins/backend/skills/`:
- **api-design** - REST/GraphQL API design
- **postgres** - PostgreSQL patterns
- **typescript** - TypeScript best practices

### How to Use Skills

**For Claude Code:** Skills are auto-loaded via `.claude/settings.json`

**For Codex/Other Agents:** Reference skills directly:
```
Use the readme skill from https://github.com/Biji-Biji-Initiative/team-skills/blob/main/plugins/core/skills/readme/SKILL.md
```

Or fetch the skill content:
```bash
curl -s https://raw.githubusercontent.com/Biji-Biji-Initiative/team-skills/main/plugins/core/skills/readme/SKILL.md
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   br sync --flush-only
   git add .beads/
   git commit -m "sync beads"
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
