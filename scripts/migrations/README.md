# Migration Scripts

Scripts for migrating data from Kajabi and MCT (Microsoft Community Training) to Open edX.

## Structure

- `kajabi/` - Kajabi export, transform, and import scripts
- `mct/` - MCT export and import scripts
- General migration utilities (bootstrap, import, rollback, verification)

## Usage

See `docs/migrations/` for complete migration playbooks.

### Kajabi Migration

```bash
# Export from Kajabi
./scripts/migrations/kajabi/kajabi-export.mjs

# Transform and prepare imports
python scripts/migrations/kajabi/kajabi-ndjson-to-csv.py

# Import to Open edX
python scripts/migrations/kajabi/verify-and-sync-kajabi-to-openedx.py
```

### MCT Migration

```bash
# Export from MCT
./scripts/migrations/mct/mct-export.mjs

# Import courses
python scripts/migrations/mct/import_courses_k8s.py
```

## Outputs

All migration outputs go to `var/migrations/` (gitignored).

