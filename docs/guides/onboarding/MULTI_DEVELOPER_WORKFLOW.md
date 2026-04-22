# Multi-Developer Workflow Guide
_Audience: Developer Operations • Owner: Platform Team • Last verified: 2026-04-21 • Status: canonical_

## 🎯 Overview

This guide keeps every developer on the same local source-to-render-to-artifact lane. The short version is: use the repo wrapper scripts, keep `tutor_env/` local and uncommitted, and prove setup with the same contracts CI uses.

## 🚀 New Developer Setup

### One-Command Setup
```bash
./scripts/qa/verify-cold-start-onboarding-contract.sh
./scripts/shared/setup-local.sh
./scripts/infra/verify-local-bootstrap-readiness.sh
```

This automatically:
- Sets up Python environment
- Configures Tutor for local development
- Builds Docker images
- Initializes database
- Configures multi-site
- Creates or prepares a local admin user
- Verifies everything works

**Time:** 45-90 minutes first time depending on image cache state, under 5 minutes for normal restart once images and data exist.

### Verify Setup
```bash
./scripts/qa/verify-cold-start-onboarding-contract.sh
./scripts/infra/verify-local-bootstrap-readiness.sh
```

## 🔄 Daily Workflow

### Starting Work
```bash
cd /path/to/mereka-lms
make tutor-start
```

### Making Changes

**Configuration Changes:**
```bash
./scripts/infra/tutor-config-save.sh --set KEY=value
make tutor-restart
```

**Code Changes:**
- Edit files in repo
- Test locally
- Commit and push

**Database Changes:**
- Make changes locally
- Test thoroughly
- Document migration steps
- Apply to production via proper channels

### Stopping Work
```bash
make tutor-stop
```

## 🔐 Environment Separation

### Local Development
- **Database:** Local Docker containers (`mysql`, `mongodb`, `redis`)
- **Storage:** Local Docker volumes
- **URLs:** `localhost`, `*.localhost`
- **Config:** `tutor_env/config.yml` (git-ignored)

### RKE2 (dev / staging / prod)
- **Database:** MySQL (cluster-internal), MongoDB Atlas, Redis (cluster-internal)
- **Storage:** Longhorn CSI on RKE2 (see bbi-infrastructure storage overlays)
- **URLs:** `academyv2.mereka.io`, `academyv2.mereka.dev`
- **Config:** Kubernetes ConfigMaps / ExternalSecrets synced from Infisical

> GKE is decommissioned as of 2026-04. All workloads run on RKE2 now. Older docs
> that reference GCS / Cloud SQL / Workload Identity describe a past state.

### Upcoming Developer Kubernetes Lanes

Kubernetes preview namespaces, Loft/vCluster, and devspace-style development are planned lanes. They are not the current quick-start path until they have rows and proof gates in `docs/reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md`.

### Key Rule
**Never mix local and production configs.**

## 📊 Verifying Parity

### Compare Local with Production
```bash
# Get production config (read-only)
./scripts/infra/sync-production-config.sh

# Analyze local data
./scripts/qa/analyze-local-data.sh

# Check parity
./scripts/qa/check-parity.sh
```

### What Should Match
- ✅ Open edX versions
- ✅ Plugin versions
- ✅ MFE versions
- ✅ Organizations
- ✅ Sites
- ✅ Feature flags

### What Should Differ
- ✅ Database hosts (local Docker vs Cloud SQL)
- ✅ URLs (localhost vs academyv2.mereka.io)
- ✅ Storage (local volumes vs GCS)
- ✅ User data (local test data vs production)

## 🛠️ Common Tasks

### Adding a New Developer

1. **Developer runs:**
   ```bash
   git clone <repo-url>
   cd mereka.academy
   ./scripts/shared/setup-local.sh
   ```

2. **Verify:**
   ```bash
   ./scripts/qa/verify-cold-start-onboarding-contract.sh
   ./scripts/infra/verify-local-bootstrap-readiness.sh
   ```

3. **Done!** Developer is ready to work.

### Updating Configuration

**Local (for testing):**
```bash
./scripts/infra/tutor-config-save.sh --set KEY=value
make tutor-restart
```

**Production (after local testing):**
```bash
# Use the release-object-driven GitOps path documented in:
# docs/architecture/PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md
```

### Syncing Production Data (Read-Only)

**Never sync production data to local without:**
- Understanding what you're syncing
- Backing up local data first
- Verifying data is sanitized
- Getting approval from team

**If you must sync (for testing):**
```bash
# Use production backup tools
# Restore to local database
# Document what was synced
```

## 🚨 Conflict Prevention

### Database Conflicts
- Each developer has isolated local database
- Never share `tutor_env/data/` directory
- Reset local database as needed: `rm -rf tutor_env/data/*`

### Configuration Conflicts
- `tutor_env/config.yml` is git-ignored
- Each developer has their own config
- Use `infrastructure/tutor/config.example.yml` as template

### Code Conflicts
- Use Git branches for features
- Test locally before pushing
- Run `./scripts/qa/verify-cold-start-onboarding-contract.sh` and the smallest relevant QA gate before PR

## 📋 Best Practices

### Before Starting Work
1. Pull latest changes: `git pull`
2. Verify setup: `./scripts/qa/verify-cold-start-onboarding-contract.sh`
3. Start services: `make tutor-start`

### During Development
1. Test locally first
2. Run the smallest relevant test or verifier for the changed surface
3. Check parity: `./scripts/qa/check-parity.sh`
4. Document changes

### Before Committing
1. Run tests
2. Verify no secrets in commits
3. Update documentation if needed
4. Check `tutor_env/config.yml` is git-ignored

### Before Deploying
1. Verify locally works perfectly
2. Compare with production config
3. Test in the approved dev GitOps lane when the change affects deployed runtime
4. Document deployment steps

## 🔍 Troubleshooting

### "My local doesn't match production"
```bash
# Compare configs
./scripts/infra/sync-production-config.sh
./scripts/qa/check-parity.sh

# Fix local config
./scripts/qa/fix-parity.sh
```

### "Database conflicts"
```bash
# Reset local database
make tutor-stop
rm -rf tutor_env/data/*
tutor local launch -I --skip-build
```

### "Config issues"
```bash
# Recreate from example
cp infrastructure/tutor/config.example.yml tutor_env/config.yml
./scripts/infra/tutor-config-save.sh \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set RUN_MONGODB=true \
  --set DOCKER_IMAGE_OPENEDX=openedx:nightly \
  --set MFE_DOCKER_IMAGE=openedx-mfe:nightly
```

## 📚 Documentation

- **Quick start:** `docs/guides/onboarding/QUICK_START_LOCAL.md`
- **Full setup:** `docs/guides/onboarding/LOCAL_SETUP.md`
- **Daily workflow:** `docs/guides/onboarding/WORKFLOW_LOCAL.md`
- **Quick Reference:** `docs/ops/quickref/README.md`
- **Environment Access:** `docs/ops/quickref/access-urls.md`

## ✅ Checklist for New Developers

- [ ] Ran `./scripts/shared/setup-local.sh`
- [ ] Verified source/docs contract with `./scripts/qa/verify-cold-start-onboarding-contract.sh`
- [ ] Verified initialized state with `./scripts/infra/verify-local-bootstrap-readiness.sh`
- [ ] Can access http://localhost
- [ ] Can log in with the local admin account created during setup
- [ ] Read `docs/guides/onboarding/LOCAL_SETUP.md`
- [ ] Bookmarked `docs/ops/quickref/README.md`
- [ ] Understand local vs production separation

---

**Remember:** stay in the documented lane, never mix configs, and record anything that blocks setup so the guide or verifier can be improved.
