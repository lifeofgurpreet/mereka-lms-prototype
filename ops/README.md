# Ops Directory (Legacy - Migration in Progress)

⚠️ **This directory is being migrated to the new structure.**

## New Locations

All infrastructure configuration has moved to `infrastructure/`:

- `ops/tutor/` → `infrastructure/tutor/`
- `ops/themes/` → `infrastructure/tutor/themes/`
- `ops/terraform/` → `infrastructure/terraform/`
- `ops/k8s/` → `infrastructure/k8s/`
- `ops/monitoring/` → `infrastructure/monitoring/`
- `ops/cloudflare/` → `infrastructure/cloudflare/`
- `ops/storage/` → `infrastructure/storage/`
- `ops/tutor-env.sh` → `infrastructure/tutor/tutor-env.sh`

## Compatibility Shims

For backward compatibility, use these wrapper scripts:

### Tutor Environment

```bash
# Old (deprecated):
source ops/tutor-env.sh

# New:
source infrastructure/tutor/tutor-env.sh
```

### Apply Patches

```bash
# Old (deprecated):
./ops/tutor/apply-patches.sh

# New:
./infrastructure/tutor/apply-patches.sh
```

## Remaining Contents

- `ops/migrations/` - Migration scripts and data (will be reorganized separately)

## Migration Timeline

- **Phase 1**: Infrastructure moved (✅ Complete)
- **Phase 2**: Scripts reorganization (In Progress)
- **Phase 3**: Migrations reorganization (Pending)

**Update your scripts and documentation to use `infrastructure/` paths directly.**

