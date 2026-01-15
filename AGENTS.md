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

## Coding Style & Naming Conventions
Shell scripts should begin with `#!/usr/bin/env bash`, enable `set -euo pipefail`, and prefer descriptive function names over inline command chains. Keep Bash indented with two spaces; YAML templates should mirror Tutor defaults and group environment variables in uppercase (e.g., `OPENEDX_RELEASE`). When extending scripts, mirror the existing comment style that summarizes intent rather than mechanics.

## Testing Guidelines
Treat `tutor local quickstart -I` as the acceptance test for major changes—capture failures before opening a PR. Use `tutor local dc ps` to confirm every service reports `Up`, and spot-check critical logs with `tutor local logs --tail=50 service`. If you alter the MFE patches, confirm `node:18` appears in the generated Dockerfile under `tutor_env/env/plugins/mfe/build/mfe/`, and sanity-check `tutor_env/env/local/docker-compose.yml` still exposes `MYSQL_ROOT_HOST: "%"`.

## Commit & Pull Request Guidelines
There is no upstream history yet, so follow Conventional Commits (`feat:`, `fix:`, `docs:`) to seed a consistent log; e.g., `fix: ensure tutor env script exits when .venv missing`. PRs should include a concise summary, the Tutor commands you ran, and links to any relevant docs you touched. Attach log excerpts or screenshots whenever behaviour changes, and request review before rolling out infrastructure-affecting adjustments.

## Security & Configuration Notes
Never commit secrets—`tutor_env/config.yml` stays local and is recreated from `ops/tutor/config.example.yml`. Run `tutor local do backup-db` before upgrades and stash dumps outside the repo. When experimenting with new Tutor plugins or releases, isolate the changes under a feature branch and document toggles in `docs/` so operators can reproduce the configuration, and re-run the patch script immediately after each `tutor config save`.

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

**Login failures (CSRF 403 or 500 on login_session).** Ensure `CSRF_TRUSTED_ORIGINS` includes `https://staging.academy.mereka.io`, `https://studio.staging.academy.mereka.io`, `https://apps.staging.academy.mereka.io`, `https://academy.biji-biji.com`, and `https://skillourfuture.staging.academy.mereka.io`. Set `CSRF_COOKIE_DOMAIN=staging.academy.mereka.io` and `SESSION_COOKIE_DOMAIN=.staging.academy.mereka.io` in `openedx-config-*.json` and restart lms/cms. If a specific user still errors with JSONDecodeError on login, reset `user.profile.meta` to `{}` and reset the password.

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
