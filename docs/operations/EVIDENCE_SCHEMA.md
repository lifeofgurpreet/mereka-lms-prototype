# Evidence Naming & Versioning Schema

**Status**: Active
**Last Updated**: 2026-02-18

> AC-WC-004: Canonical schema for all runtime smoke artifacts.

## Directory Convention

All evidence artifacts live under `var/evidence/` (gitignored). Directory names follow this pattern:

```
var/evidence/<category>-<YYYYMMDD>/
```

### Categories

| Category | Directory Pattern | Produced By |
|----------|-------------------|-------------|
| Release deploy | `release-<YYYYMMDD>` | `verify-post-deploy-smoke.sh --evidence-dir` |
| Rollback | `rollback-<YYYYMMDD>` | Manual capture during rollback procedure |
| Tenant onboarding | `tenant-onboarding/<slug>-<YYYYMMDD>` | `tenant-onboarding-dryrun.sh --evidence-dir` |
| Branding pipeline | `branding-<YYYYMMDD>` | `run-branding-evidence-pipeline.sh --evidence-dir` |
| Confidence bundle | `confidence-<YYYYMMDD>` | `ops-confidence.sh --evidence-dir` |

### Same-day re-runs

If an evidence directory already exists for today, append a sequence number:

```
var/evidence/release-20260218/     # First run
var/evidence/release-20260218-2/   # Second run same day
```

Scripts that accept `--evidence-dir` do not auto-increment — the operator chooses the directory.

## Artifact Naming

Within each evidence directory, artifact names correspond to the script that produced them:

| Script | Artifact Filename |
|--------|-------------------|
| `verify-tenant-branding-runtime.sh` | `verify-tenant-branding-runtime.log` |
| `verify-mfe-branding.sh` | `verify-mfe-branding.log` |
| `verify-analytics-key.sh` | `verify-analytics-key.log` |
| `verify-multisite-ux-consistency.sh` | `verify-multisite-ux-consistency.log` |
| `verify-post-deploy-smoke.sh` | `post-deploy-smoke.log` |
| `verify-gitops-drift.sh` | `verify-gitops-drift.log` |
| `verify-gitops-image-overrides.sh` | `verify-gitops-image-overrides.log` |
| `run-multisite-governance-gates.sh` | `run-multisite-governance-gates.log` |
| `run-branding-evidence-pipeline.sh` | `SUMMARY.md` + per-gate `.log` files |
| `ops-confidence.sh` | `confidence-summary.md` + per-gate `.log` files |
| `tenant-onboarding-dryrun.sh` | `dryrun-summary.md` + per-gate `.log` files |
| Per-domain MFE config | `mfe-config-<domain>.json` |

## Versioning Rules

1. **Artifact naming is deterministic**: Same script always produces same filename
2. **Directories are date-stamped**: Evidence is immutable within a dated directory
3. **Summaries are Markdown**: Human-readable with PASS/FAIL counts
4. **JSON outputs are machine-readable**: MFE config snapshots saved as `.json`
5. **Retention**: 30 days minimum (see `docs/ops/runbooks/BRANDING_RELEASE_RUNBOOK.md`)

## Referencing in Release Notes

When citing evidence in PRs or release notes, use the full relative path:

```markdown
**Evidence**: `var/evidence/release-20260218/post-deploy-smoke.log`
**Confidence bundle**: `var/evidence/confidence-20260218/confidence-summary.md`
```

## Cleanup

```bash
# Remove evidence older than 30 days
find var/evidence/ -maxdepth 1 -type d -mtime +30 -exec rm -rf {} +
```

## Related

- `docs/operations/EVIDENCE_REDACTION_POLICY.md` — Required redaction policy for committed evidence
- `docs/ops/runbooks/BRANDING_RELEASE_RUNBOOK.md` — Evidence retention policy
- `docs/operations/TENANT_ONBOARDING_PLAYBOOK.md` — Onboarding evidence template
- `scripts/qa/ops-confidence.sh` — Unified confidence bundle
