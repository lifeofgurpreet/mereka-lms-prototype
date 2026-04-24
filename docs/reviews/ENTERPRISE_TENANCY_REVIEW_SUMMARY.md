# Enterprise Tenancy — Review Summary

> For reviewers: what this lane produced, what is safe to merge now,
> and what remains gated on runtime or operator decisions.

## What this lane solved

The platform had a coherent tenancy architecture (ADR-024) and tooling (`provision_tenant.py`) but lacked:

1. **Explicit documentation** of the tenant/domain/surface model
2. **Enterprise data audit** showing missing catalogs, user links, and enrollment records
3. **Declarative bootstrap spec** to create enterprise data from a single YAML file
4. **Decision variants** for the two key operator choices
5. **Admin surface disambiguation** — which "admin" is which
6. **Salvage branch triage** — what to keep, supersede, or rework from `fix/enterprise-mfe-theme-config`
7. **ConfigMap rollout debt documentation** — why config changes don't restart pods

## What remains runtime-gated

These cannot be done until the runtime lane merges (`fix/enterprise-mfe-build-config`):

| Item | Why blocked |
|------|------------|
| Enterprise admin portal renders in browser | MFE build/config fix in progress |
| Enterprise learner portal renders in browser | Same |
| `bootstrap-enterprise-tenants.py --apply` | Pointless if portals don't render |
| Portal content verification | Need rendered portals to verify catalogs show courses |

## What remains decision-gated

Two operator decisions must be made before `--apply`:

| Decision | Options | Recommended | File |
|----------|---------|-------------|------|
| Partner course visibility | Shared (partners see MEREKA courses) vs Isolated (partners see only own courses) | **Shared** — partner orgs have 0 courses | `ENTERPRISE_TENANT_VARIANTS.md` |
| Slug normalization | `bijibiji` vs `biji-biji` | **`bijibiji`** — no hyphens, matches contract | Same doc |

## What is safe to review now

### PR A: Docs + Authority + Surfaces

| File | Safe to merge? |
|------|---------------|
| `docs/reference/architecture/TENANT_DOMAIN_SURFACE_AUTHORITY.md` | Yes |
| `docs/reference/architecture/TENANT_DOMAIN_AUTHORITY_MATRIX.md` | Yes |
| `docs/reference/architecture/TENANT_MODEL_RECOMMENDATION.md` | Yes |
| `docs/reference/architecture/ADMIN_SURFACES_AND_ENTRYPOINTS.md` | Yes |
| `docs/stabilization/ENTERPRISE_DATA_MODEL_AUDIT.md` | Yes |

**Risk**: Zero. Documentation only. No code changes.

### PR B: Bootstrap Spec + Tooling + Tests

| File | Safe to merge? |
|------|---------------|
| `config/enterprise-tenants/dev.enterprise-tenants.yaml` | Yes (declarative spec, no runtime effect) |
| `config/enterprise-tenants/dev.enterprise-tenants.shared-mereka.yaml` | Yes |
| `config/enterprise-tenants/dev.enterprise-tenants.partner-isolated.yaml` | Yes |
| `scripts/tenants/bootstrap-enterprise-tenants.py` | Yes (dry-run default, no auto-execution) |
| `scripts/tenants/validate-enterprise-tenants.py` | Yes (read-only) |
| `tests/tenants/test_bootstrap_spec.py` | Yes |
| `tests/tenants/fixtures/*` | Yes |
| `docs/reference/architecture/ENTERPRISE_TENANT_VARIANTS.md` | Yes |
| `docs/ops/runbooks/ENTERPRISE_BOOTSTRAP_APPLY_RUNBOOK.md` | Yes |

**Risk**: Zero. Tooling defaults to dry-run. No live writes unless explicitly invoked with `--apply`. Tests are pure unit tests with no Django dependency.

### PR C: Salvage Ledger + Config Debt

| File | Safe to merge? |
|------|---------------|
| `docs/reference/architecture/SALVAGE_BRANCH_LEDGER.md` | Yes |
| `docs/stabilization/STABLE_CONFIG_ROLLOUT_DEBT.md` | Yes |

**Risk**: Zero. Documentation only.

## What can be applied later

After runtime fix merges AND operator decisions are made:

1. Copy chosen variant → `dev.enterprise-tenants.yaml`
2. Run `bootstrap-enterprise-tenants.py --env dev` (dry-run first)
3. Run `bootstrap-enterprise-tenants.py --env dev --apply`
4. Run `validate-enterprise-tenants.py` to confirm
5. Verify enterprise portals show catalog content
6. Port salvage branch KEEP commits (5-6 small PRs)
7. Fix ConfigMap hash suffixes (standalone PR)

## Artifacts inventory

| Category | Count | Files |
|----------|-------|-------|
| Architecture docs | 6 | TENANT_DOMAIN_SURFACE_AUTHORITY, TENANT_DOMAIN_AUTHORITY_MATRIX, TENANT_MODEL_RECOMMENDATION, ADMIN_SURFACES_AND_ENTRYPOINTS, ENTERPRISE_TENANT_VARIANTS, SALVAGE_BRANCH_LEDGER |
| Operations docs | 3 | ENTERPRISE_DATA_MODEL_AUDIT, ENTERPRISE_DATA_AUDIT, ENTERPRISE_BOOTSTRAP_APPLY_RUNBOOK |
| Config rollout debt | 1 | STABLE_CONFIG_ROLLOUT_DEBT |
| Bootstrap specs | 3 | dev.enterprise-tenants.yaml, shared-mereka, partner-isolated |
| Tooling | 2 | bootstrap-enterprise-tenants.py, validate-enterprise-tenants.py |
| Tests | 1 | test_bootstrap_spec.py |
| Fixtures | 5 | valid-spec, invalid-spec-missing-slug, invalid-spec-bad-slug, duplicate-slugs, expected-dry-run-output.json |
| Review docs | 1 | This file |
| **Total** | **22 files** | |
