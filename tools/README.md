# Tools Directory (Deprecated)

**All scripts have been moved to `scripts/` subdirectories.**

This directory is deprecated. The scripts that were here have been relocated as follows:

## Migration Mapping

| Old Location | New Location |
|--------------|--------------|
| `scripts/shared/setup-local.sh` | `scripts/shared/setup-local.sh` |
| `scripts/shared/sync-from-production.sh` | `scripts/shared/sync-from-production.sh` |
| `scripts/infra/deploy-aspects-k8s.sh` | `scripts/infra/deploy-aspects-k8s.sh` |
| `scripts/infra/sync-mongodb-from-production.sh` | `scripts/infra/sync-mongodb-from-production.sh` |
| `scripts/infra/increase-gke-quota.sh` | `scripts/infra/increase-gke-quota.sh` |
| `scripts/infra/optimize-dev-costs.sh` | `scripts/infra/optimize-dev-costs.sh` |
| `scripts/infra/check-cluster-status.sh` | `scripts/infra/check-cluster-status.sh` |
| `scripts/infra/additional-cost-optimizations.sh` | `scripts/infra/additional-cost-optimizations.sh` |
| `scripts/qa/analyze-local-data.sh` | `scripts/qa/analyze-local-data.sh` |
| `scripts/qa/check-parity.sh` | `scripts/qa/check-parity.sh` |
| `scripts/analytics/openedx-analytics.py` | `scripts/analytics/openedx-analytics.py` |
| `scripts/migrations/bootstrap-courses-from-enrollments.sh` | `scripts/migrations/bootstrap-courses-from-enrollments.sh` |
| `scripts/migrations/import-production-courses.sh` | `scripts/migrations/import-production-courses.sh` |

## Scripts Directory Structure

All scripts are now organized under `scripts/`:

- `scripts/infra/` - Infrastructure and deployment scripts
- `scripts/migrations/` - Data migration scripts
- `scripts/branding/` - Theme and branding scripts
- `scripts/analytics/` - Analytics and reporting scripts
- `scripts/qa/` - Quality assurance and testing scripts
- `scripts/shared/` - Shared utilities

See `scripts/README.md` for the complete structure and usage guide.
