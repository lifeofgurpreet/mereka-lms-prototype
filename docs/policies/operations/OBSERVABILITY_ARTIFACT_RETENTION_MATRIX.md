# Observability Artifact Retention Matrix (Mereka LMS)

Date: 2026-02-25

## Purpose

Define how long observability artifacts are retained, where they are stored, and how operators should clean them without losing release evidence.

## Canonical Identity

Retention references in this matrix apply to:

- `var/ci/observability-*` parity outputs
- `var/ci/*observability*` compliance outputs
- `var/operations/*` runtime audits and evidence bundles
- External evidence locations referenced by release checklists and incident responses

## Retention Policy

| Artifact class | Artifact examples | Store location | Default retention | Hard deletion policy | Archive policy |
|---|---|---|---|---|---|
| Runtime compliance JSON/MD | `observability-compliance-runtime.json`, `observability-runtime-verify-runtime.md`, `observability-first-class-runtime-evidence-index.json`, `observability-correlation-headers-runtime.txt` | `var/ci/parity-<env>/` | 30 days | Delete after 30 days unless linked in release notes | Move to `var/ci-archive/` if run includes explicit release runbook reference |
| Parity deltas | `observability-parity-delta.json`, `observability-parity-delta.md` | `var/ci/parity-<env>/` | 90 days | Keep all release artifacts for at least one year; rotate only after release-close audit | Archive to long-term evidence path with release tag |
| Parity reviews | `observability-parity-review.md` | `var/ci/parity-<env>/` | 365 days | Remove only by approved evidence cleanup script | Long-term immutable archive required for incident retrospectives |
| Parity rollup | `observability-parity-rollup.json`, `observability-parity-rollup.md` | `var/ci/parity-artifacts/` | 365 days | Keep unless signed release indicates duplicate artifact exists | Archive in quarterly audit folder |
| CI compliance artifacts | `observability-compliance-report.json`, `observability-compliance-report.md`, `observability-audit-identity*.json` | `var/ci/` | 180 days | Keep for active on-call SLO horizon; purge after 180 days | Archive for quarterly review package |
| Evidence identity checksums | `observability-runtime-evidence-identity.json` | `var/ci/` and incident evidence dirs | 365 days | Keep for each production deploy + rollback event | Archive in incident packet |
| Long-form report bundles | `var/operations/<ticket|runbook>.tar.gz` | repo-local archive path or object storage copy | 1 year | Keep if not attached to IR closure | Move to long-term cold storage by operations lead |
| Release logs | `var/operations/release-*.log` | `var/operations/` | 90 days | Keep for post-deploy troubleshooting window | Archive into release bundle on closure |

## Retention Enforcement

- Automated checks should assert current day retention windows in CI using:
  - cleanup scripts in `scripts/ops/*` (if/when added)
  - `find` guardrails in runbooks and scheduled cron jobs
- Critical artifacts must be immutable once a release is closed.
- Any artifact deleted before retention window must have:
  - a release note reference
  - approval from platform observability owner
  - a reason logged in `docs/runbooks/operations/RELEASE_CHECKLIST.md` or equivalent postmortem

## Cleanup commands

These commands are examples and must be run from repo root only in maintenance windows:

```bash
# Dev/Nonprod runtime artifacts (30d)
find var/ci/parity-dev var/ci/parity-nonprod -type f \
  \( -name "observability-compliance-runtime.json" -o -name "observability-runtime-verify-runtime.md" -o -name "observability-first-class-runtime-evidence-index.json" -o -name "observability-correlation-headers-runtime.txt" \) \
  -mtime +30 -print

# Parity deltas and reviews (90d)
find var/ci/parity-dev var/ci/parity-nonprod var/ci/parity-prod -type f \
  \( -name "observability-parity-delta.json" -o -name "observability-parity-delta.md" -o -name "observability-parity-review.md" \) \
  -mtime +90 -print
```

## Owner and Exception Flow

- **Primary owner:** Observability and runtime operations.
- **Exception approval:** release owner + on-call lead.
- **Retention exception allowed when:** legal/compliance holds, incident response packet creation, or unresolved rollback audit.
