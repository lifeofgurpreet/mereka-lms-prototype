# Scripts Directory

This directory contains all automation scripts organized by domain.

## Structure

```
scripts/
├── infra/              # Infrastructure operations (GKE, Cloudflare, MongoDB, etc.)
├── migrations/         # Data migration scripts
│   ├── kajabi/        # Kajabi-specific migration tools
│   └── mct/           # MCT-specific migration tools
├── branding/           # Branding asset sync and theme helpers
├── analytics/          # Analytics exports and reconciliation
├── qa/                 # Quality assurance and testing scripts
└── shared/             # Shared utilities and common helpers
```

## Usage

All scripts should be run from the repository root:

```bash
# Infrastructure
./scripts/infra/backup-db.sh
./scripts/infra/check-cluster-status.sh

# Migrations
./scripts/migrations/kajabi/kajabi-export.mjs
./scripts/migrations/mct/mct-export.mjs

# Branding
./scripts/branding/sync-brand-assets.sh

# Analytics
./scripts/analytics/openedx-export-enrollments.py

# QA
./scripts/qa/smoke-test.sh
```

## Dependencies

- **Python**: See `pyproject.toml` for Python dependencies
- **Node**: See `package.json` for Node.js dependencies (v18)
- **Shell**: Scripts use `bash` with `set -euo pipefail`

## Adding New Scripts

1. Place scripts in the appropriate domain directory
2. Use shebang: `#!/usr/bin/env bash` or `#!/usr/bin/env python3`
3. Add error handling: `set -euo pipefail` for bash scripts
4. Document usage in script header comments
5. Update this README if adding a new domain

## Migration Notes

**⚠️ Compatibility**: The old `tools/` directory contains a compatibility shim. Update references to use `scripts/` paths directly.

