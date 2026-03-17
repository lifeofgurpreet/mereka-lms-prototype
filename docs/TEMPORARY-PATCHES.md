# Temporary Patches

Last updated: 2026-03-16T11:10Z

These exist in runtime only. They are NOT backed by Git.
They will be lost on DB restore, full cluster rebuild, or
specific pod/service recreation scenarios.

## Active Runtime-Only Patches

| # | What | Where | Survives Pod Restart | Survives DB Restore | Risk | Recovery Path |
|---|------|-------|---------------------|--------------------|----|---------------|
| 1 | `oel_publishing_publishableentity.can_stand_alone` column | MySQL dev DB | YES | **NO** | Studio outline breaks | DR runbook step 5 |
| 2 | `oel_publishing_draft.draft_log_record_id` column | MySQL dev DB | YES | **NO** | CMS downstreams breaks | DR runbook step 5 |
| 3 | `oel_publishing_publishlogrecord.dependencies_hash_digest` column | MySQL dev DB | YES | **NO** | CMS downstreams breaks | DR runbook step 5 |
| 4 | Test enrollment (lanea-platform-admin in Project Mgmt course) | MySQL dev DB | YES | NO | Test fixture only | N/A |

## Recovery Path for Patches 1-3

The exact check + repair SQL is now documented in:
`docs/ops/runbooks/DISASTER_RECOVERY.md` → "Data Integrity Verification" → step 5.

Operators MUST run this check after any DB restore. The check
is a single Django shell command; the repair is 3 ALTER TABLE
statements + CMS restart.

## Stale ConfigMap Content

~~The live `openedx-settings-lms-patched` ConfigMap contains some
settings lines removed from the overlay source in Waves 2A/2B.
Harmless (same values as base). Clears on next rollout-hash cycle.~~

RESOLVED: PR #1864 merged 2026-03-16. Hash-suffixed CMs are now live in dev;
next settings change will produce a fresh CM and the stale content will be gone.
