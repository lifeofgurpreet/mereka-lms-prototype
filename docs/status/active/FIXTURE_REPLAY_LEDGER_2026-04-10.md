# Fixture Replay Ledger — Agent 1 VNext

_Owner: Agent 1. Created: 2026-04-10. Status: active_

This ledger records the verification state of fixture canon — the
claim that running `bootstrap-runtime-proof-fixtures.py` or
`apply-multisite-config.sh` against a live cluster produces NO-OP
because source == runtime.

## Source Manifests

| Manifest | Path | Purpose |
|----------|------|---------|
| Prod fixtures | `config/runtime-proof/prod.synthetic-proof-fixtures.yaml` | Synthetic users, enterprise customers, waffle flags |
| Dev fixtures | `config/runtime-proof/dev.synthetic-proof-fixtures.yaml` | Same for dev environment |
| Staging fixtures | `config/runtime-proof/staging.synthetic-proof-fixtures.yaml` | Same for staging |
| Multisite sites | `infrastructure/tutor/multisite-sites.yml` | Prod tenant definitions |
| Multisite sites (dev) | `infrastructure/tutor/multisite-sites.dev.yml` | Dev tenant definitions |
| Multisite sites (staging) | `infrastructure/tutor/multisite-sites.staging.yml` | Staging tenant definitions |

## Replay Scripts

| Script | What it replays | Safety guards |
|--------|----------------|---------------|
| `scripts/tenants/bootstrap-runtime-proof-fixtures.py` | Synthetic users, enterprise customers, waffle flags | Blocks `--apply --env prod` (dev-only). Defaults to dry-run. |
| `scripts/tenants/bootstrap-enterprise-tenants.py` | EnterpriseCustomer, CustomerUser, catalogs, waffle switches | Real-account collision guard |
| `scripts/infra/apply-multisite-config.sh` | django_site + SiteConfiguration rows | Requires `ALLOW_PROD_APPLY=1` + `CONFIRM_APPLY_MULTISITE_CONFIG=APPLY_MULTISITE_CONFIG` for prod |

## Replay State (2026-04-10)

### Prod — `academyv2.mereka.io` namespace `mereka-lms`

| Script | Invocation | Result | Timestamp |
|--------|-----------|--------|-----------|
| `bootstrap-runtime-proof-fixtures.py --env prod` | Dry-run (local) | All actions `CREATE_OR_NOOP` | 2026-04-09 11:20Z |
| `bootstrap-runtime-proof-fixtures.py --env prod --apply` | In-pod run | **Blocked by guard**: "Environment 'prod' not in allowed list ('dev',)" | 2026-04-09 11:25Z |
| `apply-multisite-config.sh --apply --env prod` | First run (RCB-01) | Updated: 9 MFE_CONFIG keys added | 2026-04-09 11:31Z |
| `apply-multisite-config.sh --apply --env prod` | Second run (branding fix) | Updated: SITE_NAME, colors, logo subpath | 2026-04-09 14:22Z |
| `apply-multisite-config.sh --apply --env prod` | Third run (verification) | Expected: NO-OP | NOT RUN (TODO) |

**Status**: Source-consistent for tenant/SiteConfiguration truth. The
prod-mutation guard on `bootstrap-runtime-proof-fixtures.py` is
intentional — production fixtures are operator-owned, not script-owned.

### Dev — `academyv2.mereka.dev` namespace `mereka-lms-dev`

| Script | Invocation | Result | Timestamp |
|--------|-----------|--------|-----------|
| `bootstrap-runtime-proof-fixtures.py --env dev --apply` | Previous session (Agent 1 V2) | NO-OP | 2026-04-08 (prior session) |
| `apply-multisite-config.sh --apply --env dev` | Previous session | Idempotent | 2026-04-08 |
| `verify-dev-runtime-proof.sh` | Current session | **40/40 PASS** | 2026-04-09 many times |

**Status**: Fully source-consistent. Runtime proof passes cleanly.

### Staging — `staging.academyv2.mereka.io` namespace `stg-mereka-lms`

| Script | Invocation | Result | Timestamp |
|--------|-----------|--------|-----------|
| `verify-staging-runtime-proof.sh` | After ARC runner capacity fix | **40/40 PASS** | 2026-04-09 |
| `apply-multisite-config.sh --apply --env staging` | NOT RUN | — | — |
| `verify-enterprise-runtime-app-wiring.sh --env staging` | After #2602 + ArgoCD sync | **PASS** (mereka_tenancy + middleware present) | 2026-04-10 |

**Status**: Source-consistent after fix for missing `mereka_tenancy` app
registration (bbi-infrastructure #2602).

## Source-Owned vs Operator-Owned

| Item | Owned by | Replay creates? |
|------|----------|-----------------|
| Synthetic fixture user **accounts** | Source (manifest) | YES on dev |
| Synthetic fixture user **passwords** | Operator (Infisical secrets) | NO — looked up at runtime |
| OAuth2 applications (`cms-sso`) | Source (manifest) | YES |
| OAuth2 client **secrets** | Operator (Infisical) | NO |
| `EnterpriseCustomer` rows | Source (`enterprise-tenants/*.yaml`) | YES |
| `EnterpriseCustomer.uuid` | Operator (one-time generated, committed back) | NO — preserved across runs |
| `django_site` rows | Source (`multisite-sites.yml`) | YES |
| `SiteConfiguration.site_values` | Source + derived | YES (replay script computes derived keys) |
| `SiteConfiguration.MFE_CONFIG` brand colors | Source (`multisite-sites.yml` `primary_color` etc.) | YES |
| Waffle flags (platform-wide) | Source (`enterprise-tenants/*.yaml` `waffle_flags`) | YES |
| Waffle switches (tenant-scoped) | Source | YES |
| Django user **profile pics** | Runtime uploads | NO |

## NO-OP Verification Gaps

Items where we have NOT yet proven replay is NO-OP on prod:

1. Second run of `apply-multisite-config.sh --apply` on prod immediately
   after the first run — never executed. Should produce zero diff.
2. In-pod dry-run of `bootstrap-runtime-proof-fixtures.py` against prod
   to diff source against live DB state — blocked by safety guard.
   Future: add a read-only `--diff --env prod` mode.

## Rules

1. After any fixture manifest edit, replay on dev first and verify the
   runtime proof script still passes.
2. Prod fixture replay requires explicit operator intent (ALLOW_PROD_APPLY).
3. Never edit SiteConfiguration via Django admin — always update the source
   manifest and replay.
4. Every `apply-multisite-config.sh --apply` MUST be logged in
   `MUTATION_LEDGER_2026-04-10.md`.
