# Tools Directory (Legacy - Migration Complete)

_Audience: Platform Team • Owner: Platform Team • Last verified: 2026-03-06 • Status: archive-candidate_

⚠️ **This directory has been migrated to `scripts/`.**

All scripts have been reorganized into domain-specific directories under `scripts/`:

- Infrastructure scripts → `scripts/infra/`
- Migration scripts → `scripts/migrations/`
- Branding scripts → `scripts/branding/`
- Analytics scripts → `scripts/analytics/`
- QA scripts → `scripts/qa/`
- Shared utilities → `scripts/shared/`

## Update Your References

**Old (deprecated):**
```bash
./tools/backup-db.sh
./tools/kajabi-export.mjs
./tools/sync-brand-assets.sh
```

**New:**
```bash
./scripts/infra/backup-db.sh
./scripts/migrations/kajabi/kajabi-export.mjs
./scripts/branding/sync-brand-assets.sh
```

See `scripts/README.md` for the complete structure and usage guide.

