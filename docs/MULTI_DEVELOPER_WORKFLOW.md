# Multi-Developer Workflow Guide
_Managing Local and Production for Multiple Developers • Last updated: 2025-11-12_

## 🎯 Overview

This guide ensures all developers can work efficiently without conflicts, with clear separation between local and production environments.

## 🚀 New Developer Setup

### One-Command Setup
```bash
./scripts/shared/setup-local.sh
```

This automatically:
- Sets up Python environment
- Configures Tutor for local development
- Builds Docker images
- Initializes database
- Configures multi-site
- Creates admin user
- Verifies everything works

**Time:** 45-60 minutes (first time), < 5 minutes (subsequent)

### Verify Setup
```bash
./scripts/qa/verify-setup.sh
```

## 🔄 Daily Workflow

### Starting Work
```bash
cd /path/to/mereka.academy
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor local start -d
```

### Making Changes

**Configuration Changes:**
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate
tutor config save --set KEY=value
./infrastructure/tutor/apply-patches.sh  # CRITICAL: Always run this
tutor local restart <affected-services>
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
tutor local stop
```

## 🔐 Environment Separation

### Local Development
- **Database:** Local Docker containers (`mysql`, `mongodb`, `redis`)
- **Storage:** Local Docker volumes
- **URLs:** `localhost`, `*.localhost`
- **Config:** `tutor_env/config.yml` (git-ignored)

### GKE/Kind
- **Database:** Cloud SQL, MongoDB Atlas, managed Redis
- **Storage:** GCS buckets
- **URLs:** `academyv2.mereka.io`, `academyv2.mereka.dev`
- **Config:** Kubernetes ConfigMaps/Secrets

### Key Rule
**NEVER mix local and production configs!**

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
   ./scripts/qa/verify-setup.sh
   ```

3. **Done!** Developer is ready to work.

### Updating Configuration

**Local (for testing):**
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save --set KEY=value
./infrastructure/tutor/apply-patches.sh
tutor local restart
```

**Production (after local testing):**
```bash
# Via kubectl or Tutor k8s commands
# Always test locally first!
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
- Run `./scripts/qa/comprehensive-test.sh` before PR

## 📋 Best Practices

### Before Starting Work
1. Pull latest changes: `git pull`
2. Verify setup: `./scripts/qa/verify-setup.sh`
3. Start services: `tutor local start -d`

### During Development
1. Test locally first
2. Run tests: `./scripts/qa/comprehensive-test.sh`
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
3. Test in dev (kind) first
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
tutor local stop
rm -rf tutor_env/data/*
tutor local launch -I --skip-build
```

### "Config issues"
```bash
# Recreate from example
cp infrastructure/tutor/config.example.yml tutor_env/config.yml
tutor config save  # Reconfigure
./infrastructure/tutor/apply-patches.sh
```

## 📚 Documentation

- **Onboarding:** `docs/DEVELOPER_ONBOARDING.md`
- **Quick Reference:** `docs/QUICK_REFERENCE.md`
- **Complete Guide:** `docs/LOCAL_DEVELOPMENT_GUIDE.md`
- **Parity Strategy:** `docs/LOCAL_PRODUCTION_PARITY.md`

## ✅ Checklist for New Developers

- [ ] Ran `./scripts/shared/setup-local.sh`
- [ ] Verified with `./scripts/qa/verify-setup.sh`
- [ ] Can access http://localhost
- [ ] Can login with admin/admin123
- [ ] Read `docs/DEVELOPER_ONBOARDING.md`
- [ ] Bookmarked `docs/QUICK_REFERENCE.md`
- [ ] Understand local vs production separation

---

**Remember:** Always test locally first, never mix configs, and verify parity regularly!
