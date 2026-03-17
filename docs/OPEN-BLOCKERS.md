# Open Blockers

Last updated: 2026-03-16T11:10Z

## Active Blockers (by priority)

| # | Blocker | Layer | Type | Owner | Next Action |
|---|---------|-------|------|-------|-------------|
| ~~1~~ | ~~oel_publishing schema fix is runtime-only~~ | DATA | **PATCHED_IN_REPO** | DR runbook step 5 | Recovery path documented in `DISASTER_RECOVERY.md` |
| ~~2~~ | ~~1-line vendor-sync drift~~ | REPO | **MERGED** | PR #1861 | Merged 2026-03-16 |
| 3 | **Stale /course-authoring route** — still serves HTTP 200, config no longer advertises it | RUNTIME | residual | Caddy config owner | Add redirect to /authoring |
| ~~4~~ | ~~disableNameSuffixHash in dev~~ | DELIVERY | **MERGED** | PR #1864 | Merged 2026-03-16; hash suffixes enabled, auto-rollout restored |
| 5 | **4 overlay Python forks (3500+ lines)** — duplicate app behavior in infra | REPO | durable | Architecture | Continue Wave 2 decomposition |
| 6 | **Staging pods stuck Pending** — CPU insufficient, auth fix deployed but can't take effect | RUNTIME | temporary | Cluster capacity | Free CPU or reduce other workloads |
| 7 | **Prod parked, image/config gap** — older image, guarded imports, needs rebuild pre-May | DELIVERY | durable | Image build / infra | Pre-May-1st image rebuild |

## Resolved (for reference)

| Blocker | Resolution | Lane |
|---------|-----------|------|
| CMS JWT public key mismatch | PR #926 + overlay fixes | S2 |
| Studio URL /course-authoring drift | PR #1838 + ConfigMap patch | P3 |
| Staging SameSite=Lax | PR #1859 | U2 |
| Multisite vendored drift | PR #1854 | A2 |
| Redundant MFE_CONFIG keys (20) | PRs #1855, #1857 | A3, A4 |
| Vendor-sync ENABLE_OAUTH2_PROVIDER | PR #1861 (merged 2026-03-16) | U3 |
| disableNameSuffixHash in dev | PR #1864 (merged 2026-03-16) | U4 |
