# Repository Reorganization - Migration Checklist

**Date**: 2025-11-13  
**Status**: ✅ Complete - Ready for Team Migration

## ✅ Completed Tasks

### Phase 0-1: Safety & Hygiene
- [x] Updated `.gitignore` for comprehensive coverage
- [x] Created `var/` structure for runtime artifacts
- [x] Moved all generated files to `var/`

### Phase 2: Infrastructure
- [x] Moved `ops/` → `infrastructure/`
- [x] Created compatibility shims in `ops/`
- [x] Updated `tutor-env.sh` path references

### Phase 3: Scripts
- [x] Reorganized 40+ scripts into domain folders
- [x] Created READMEs for each script category
- [x] Updated critical script references

### Phase 4: Services
- [x] Moved webhook apps to `services/`
- [x] Created service READMEs
- [x] Updated service configurations

### Phase 5: Documentation
- [x] Reorganized 70+ docs into categories
- [x] Updated main documentation index
- [x] Created category READMEs

### Phase 6: Automation
- [x] Created `Makefile` with common tasks
- [x] Added pre-commit hooks configuration
- [x] Created `pyproject.toml` and `package.json`
- [x] Added `.editorconfig` and `CONTRIBUTING.md`

### Phase 7: Validation
- [x] Updated `README.md` and `AGENTS.md`
- [x] Updated CI/CD workflow
- [x] Updated critical script references
- [x] Created migration summary

## 🔄 Team Migration Steps

### For Developers

1. **Pull latest changes**
   ```bash
   git pull origin main
   ```

2. **Update your local environment**
   ```bash
   # Old paths still work via compatibility shims, but update to new paths:
   source infrastructure/tutor/tutor-env.sh  # instead of ops/tutor-env.sh
   make tutor-apply  # instead of ./infrastructure/tutor/apply-patches.sh
   ```

3. **Update your scripts/documentation**
   - Replace `ops/tutor-env.sh` → `infrastructure/tutor/tutor-env.sh`
   - Replace `infrastructure/tutor/apply-patches.sh` → `make tutor-apply` or `./infrastructure/tutor/apply-patches.sh`
   - Replace `tools/` → `scripts/{domain}/`
   - Replace `docs/QUICK_START_LOCAL.md` → `docs/onboarding/QUICK_START_LOCAL.md`
   - Replace `docs/ops/TROUBLESHOOTING.md` → `docs/operations/TROUBLESHOOTING.md`

4. **Test your workflows**
   ```bash
   make tutor-start
   make tutor-apply
   make branding-sync
   ```

### For CI/CD

- [x] Updated `.github/workflows/cloud-sql-backup.yml` to use `scripts/infra/backup-db.sh`
- [ ] Review other workflows (if any) and update paths
- [ ] Test workflows in dev (kind/VPS) before production

### For Documentation

- [x] Updated main `README.md` and `AGENTS.md`
- [x] Updated `docs/README.md` with new structure
- [x] Updated `docs/BRANDING_PLAN.md` paths
- [x] Updated `scripts/migrations/mct/README.md` paths
- [ ] Review team-specific docs and update references

## 📋 Verification Checklist

Before considering migration complete:

- [ ] All team members have pulled latest changes
- [ ] All local development environments tested with new paths
- [ ] CI/CD workflows tested and passing
- [ ] Documentation references updated
- [ ] No broken links or missing files
- [ ] Compatibility shims tested (should still work)

## 🗑️ Future Cleanup (After 1-2 Sprints)

Once team is fully migrated:

1. Remove compatibility shims:
   - `ops/tutor-env.sh` symlink
   - `infrastructure/tutor/apply-patches.sh` symlink
   - `ops/README.md` (keep migration note for reference)

2. Remove `tools/README.md` (keep migration note)

3. Archive old documentation references if needed

## 📚 Key Reference Documents

- [`REORGANIZATION_SUMMARY.md`](REORGANIZATION_SUMMARY.md) - Complete reorganization details
- [`CONTRIBUTING.md`](CONTRIBUTING.md) - Development workflow and guidelines
- [`docs/README.md`](docs/README.md) - Documentation index
- [`scripts/README.md`](scripts/README.md) - Scripts documentation
- [`infrastructure/README.md`](infrastructure/README.md) - Infrastructure docs

## 🆘 Need Help?

- Check [`docs/operations/TROUBLESHOOTING.md`](docs/operations/TROUBLESHOOTING.md) for common issues
- Review [`docs/onboarding/LOCAL_DEVELOPMENT_GUIDE.md`](docs/onboarding/LOCAL_DEVELOPMENT_GUIDE.md) for setup
- See [`REORGANIZATION_SUMMARY.md`](REORGANIZATION_SUMMARY.md) for path mappings

