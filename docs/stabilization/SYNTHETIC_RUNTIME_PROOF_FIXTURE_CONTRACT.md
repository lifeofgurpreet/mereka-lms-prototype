# Synthetic Runtime Proof Fixture Contract

> **Status**: Active
> **Environment scope**: dev active; staging and production manifests canonicalized for non-dev proof
> **Owner**: Runtime Proof Lane (lane-i)
> **Canonical path**: `docs/stabilization/SYNTHETIC_RUNTIME_PROOF_FIXTURE_CONTRACT.md`
> **Manifests**: `config/runtime-proof/*.synthetic-proof-fixtures.yaml`

---

## 1. Purpose

This contract defines the fixture layer required to execute safe, repeatable runtime proof of
enterprise features on Mereka LMS without touching real operator accounts, real tenant data, or
live production state.

It is **separate** from the real-tenant bootstrap system
(`scripts/tenants/bootstrap-enterprise-tenants.py`,
`config/enterprise-tenants/dev.enterprise-tenants.yaml`). The synthetic fixture layer exists
purely to enable:

- Browser-based proof flows by agents
- CI pre-merge smoke passes
- Safe team testing that cannot contaminate real operator accounts

The proof exercises the enterprise learner portal, MFE config endpoint, waffle flag resolution,
and the LMS-side vs enterprise-catalog-side data split — without needing a human operator to
sign in with real credentials.

---

## 2. Environments

| Environment | Manifest | Status |
|-------------|----------|--------|
| `dev` | `config/runtime-proof/dev.synthetic-proof-fixtures.yaml` | Active |
| `staging` | `config/runtime-proof/staging.synthetic-proof-fixtures.yaml` | Canonical non-dev proof contract |
| `production` | `config/runtime-proof/prod.synthetic-proof-fixtures.yaml` | Declarative contract only while production remains parked |

The `dev` environment targets the `mereka-lms-dev` namespace / `mereka-lms-dev` ArgoCD app,
with LMS at `academyv2.mereka.dev` and MFEs at `apps.academyv2.mereka.dev`.

The `staging` and `production` manifests exist so non-dev runtime proof and reactivation do not
depend on dev-only fixture truth. Their presence does not authorize uncontrolled writes in those
environments.

---

## 3. Fixture Classes

### 3.1 Synthetic Identities

Synthetic user accounts used exclusively for proof. All usernames carry the `lanea-` prefix
and all emails use the `@synthetic.test` domain, which is unroutable and unambiguous.

| Role | Username | Email | Purpose |
|------|----------|-------|---------|
| Platform admin | `lanea-platform-admin` | `lanea-platform-admin@synthetic.test` | LMS superuser, can verify admin surfaces |
| Enterprise admin | `lanea-enterprise-admin` | `lanea-enterprise-admin@synthetic.test` | Linked to "Biji Biji Initiative" enterprise customer as admin |
| Enterprise learner | `lanea-enterprise-learner` | `lanea-enterprise-learner@synthetic.test` | Linked as learner; used for learner portal proof flow |
| Negative / non-linked | `lanea-unlinked-user` | `lanea-unlinked-user@synthetic.test` | Has a valid LMS account but is NOT linked to any enterprise customer |

**Invariant**: No synthetic account email shall match any real operator email in the system.
The `@synthetic.test` TLD is not a valid IANA TLD and cannot receive email.

**Password discipline**: Passwords for synthetic accounts are stored in Infisical under the
active environment at path `/k8s/mereka-lms/`. They are never hardcoded in this repo.

### 3.2 LMS Enterprise Data

The following must exist as live database records in the `mereka-lms-dev` LMS:

- An `EnterpriseCustomer` with slug `biji-biji-initiative` and name `Biji Biji Initiative`
- An `EnterpriseCustomerCatalog` attached to that customer (at least one catalog)
- `EnterpriseCustomerUser` records linking:
  - `lanea-enterprise-admin` → `biji-biji-initiative` with admin role
  - `lanea-enterprise-learner` → `biji-biji-initiative` with learner role
- `lanea-unlinked-user` must NOT be linked to any `EnterpriseCustomer`

The LMS-side enterprise data is necessary but not sufficient. See 3.3.

### 3.3 Enterprise-Catalog Service Data

The enterprise-catalog service (`enterprise-catalog` deployment in `mereka-lms-dev`) maintains
its own database of `CatalogQuery` and `EnterpriseCatalog` objects that mirror the LMS-side
`EnterpriseCustomerCatalog` records. **Both sides must be populated** for the learner portal to
serve content.

An LMS-only catalog (no matching record in enterprise-catalog) will result in the learner portal
displaying zero available courses. This is a known split that must be verified separately.

Required in enterprise-catalog service:

- A `CatalogQuery` covering BIJIBIJI org content (or all-platform content for proof purposes)
- An `EnterpriseCatalog` linked to the `biji-biji-initiative` enterprise UUID
- The catalog must return at least one course when queried via the enterprise-catalog API

### 3.4 Waffle Flags

The following platform-wide waffle flags must be active for enterprise features to function:

| Flag | Required value | Scope |
|------|---------------|-------|
| `enterprise.learner_bff_enabled` | `true` (on) | Platform-wide (not tenant-scoped) |
| `enterprise.enable_learner_portal` | `true` | Tenant-scoped switch for `biji-biji-initiative` |
| `enterprise.enable_integrated_learner_portal_search` | `true` | Tenant-scoped for `biji-biji-initiative` |

Waffle switches that are tenant-scoped follow the naming pattern:
`<base_flag>.<enterprise_slug>`.

### 3.5 Negative Cases

Negative cases are required for proof completeness but are not required for a green fixture
baseline. They validate that the platform correctly rejects non-eligible users.

| Scenario | User | Expected outcome |
|----------|------|-----------------|
| Non-linked user cannot access learner portal | `lanea-unlinked-user` | HTTP 403 or redirect to "no enterprise" error page |
| Non-linked user cannot access enterprise admin | `lanea-unlinked-user` | HTTP 403 |

---

## 4. Allowed and Forbidden Actions

### Allowed

- Creating synthetic user records in the LMS database with `@synthetic.test` emails
- Creating `EnterpriseCustomer`, `EnterpriseCustomerCatalog`, `EnterpriseCustomerUser`
  records keyed to `biji-biji-initiative` slug
- Creating waffle flags/switches in the LMS database
- Populating enterprise-catalog service records via its management API or management command
- Deleting synthetic records during rollback (see rollback contract)

### Forbidden

| Action | Reason |
|--------|--------|
| Modifying any real operator account (`team@mereka.io`, `admin@biji-biji.com`, etc.) | Real account mutation is explicitly prohibited by this contract |
| Creating accounts with real email domains | Cannot risk collision with real user accounts |
| Setting passwords visible in logs or committed to git | Password hygiene |
| Running this fixture pack in `staging` or `production` without the matching explicit manifest and release approval path | Environment scope isolation |
| Linking synthetic users to a real enterprise customer that has real learners | Could corrupt real enrollment data |
| Using `bootstrap-enterprise-tenants.py --apply` to install synthetic fixtures | That tool manages real tenants; synthetic fixtures have their own tool |

---

## 5. Why Real Accounts Are Prohibited

Real operator accounts (`team@mereka.io`, `admin@biji-biji.com`) have real enterprise data
attached. Modifying them during proof:

1. **Corrupts production-equivalent state** — if the dev environment is used to validate
   pre-production data, real-account modifications pollute that state.
2. **Breaks real login flows** — EnterpriseCustomerUser role changes can alter what menus
   and portals a real operator sees when they sign in.
3. **Cannot be safely undone** — there is no transactional rollback for multi-table enterprise
   data modifications; undoing them requires knowing the exact prior state.
4. **Violates least-privilege for agents** — agents running automated proof should have no
   authority over accounts that real humans use.

---

## 6. Durable vs Manual State

| Fixture class | State type | Notes |
|---------------|-----------|-------|
| Synthetic user accounts | Manual — created by bootstrap tool | Persists across pod restarts; survives DB migrations |
| LMS enterprise records | Manual — created by bootstrap tool | Persists; idempotent on re-run |
| Enterprise-catalog records | Manual — created by catalog management command or API | Persists; may need re-seed after full DB reset |
| Waffle flags | Manual — created by bootstrap tool | Persists; idempotent |
| MFE config snapshot | Durable — read from live `/api/mfe_config/v1` response | Not persisted; re-read on each proof run |
| Negative case proof | Durable — tested via HTTP at proof time | Not persisted; verified each run |

"Durable" here means the fixture is derived at proof runtime rather than pre-created.
"Manual" means it must be explicitly bootstrapped and will persist in the DB.

---

## 7. Pre-Browser-Proof Verification Checklist

Before running any browser-based proof agent against the dev cluster, confirm:

- [ ] `scripts/tenants/validate-runtime-proof-fixtures.py --env <env>` exits 0 for the selected environment
- [ ] `scripts/tenants/bootstrap-runtime-proof-fixtures.py --env <env> --dry-run` exits 0 with expected plan
- [ ] LMS pod is ready: `kubectl get pods -n mereka-lms-dev -l app.kubernetes.io/name=lms`
- [ ] Enterprise-catalog pod is ready: `kubectl get pods -n mereka-lms-dev -l app.kubernetes.io/name=enterprise-catalog`
- [ ] `/api/mfe_config/v1` returns HTTP 200 from `apps.academyv2.mereka.dev`
- [ ] Waffle flag `enterprise.learner_bff_enabled` is active (check via LMS Django admin or shell)
- [ ] `lanea-enterprise-learner` account exists and is linked to `biji-biji-initiative`
- [ ] Enterprise-catalog `biji-biji-initiative` catalog returns at least one result
- [ ] `lanea-unlinked-user` is NOT linked to any enterprise customer

---

## 8. Fixture Naming Convention

All synthetic objects use one of two prefixes:

| Prefix | Used for | Example |
|--------|---------|---------|
| `lanea-` | User accounts (usernames) | `lanea-enterprise-learner` |
| `proof-` | Enterprise customer slugs and catalog titles (synthetic-only) | `proof-biji-biji-initiative` |

The `biji-biji-initiative` slug aligns with the real enterprise customer name, but the
synthetic fixture creates it with a distinct contact email (`@synthetic.test`) that
distinguishes it from the real tenant record. If a real `biji-biji-initiative`
`EnterpriseCustomer` already exists with a real contact email, the bootstrap tool will detect
this and refuse to overwrite it (real-account protection guard).

---

## 9. Relationship to Real Tenant Bootstrap

```
Real tenant bootstrap (existing)          Synthetic proof fixtures (this contract)
─────────────────────────────────         ────────────────────────────────────────
config/enterprise-tenants/                config/runtime-proof/
  dev.enterprise-tenants.yaml               dev.synthetic-proof-fixtures.yaml
                                           staging.synthetic-proof-fixtures.yaml
                                           prod.synthetic-proof-fixtures.yaml

scripts/tenants/                          scripts/tenants/
  bootstrap-enterprise-tenants.py           bootstrap-runtime-proof-fixtures.py
  validate-enterprise-tenants.py            validate-runtime-proof-fixtures.py

Purpose: Production-equivalent tenant     Purpose: Safe synthetic proof only
         setup, real account linkage               No real accounts touched
         Mutates DB when --apply used              Dry-run by default; --apply
                                                   prints warning and exits
```

The two systems are intentionally isolated. Running the synthetic bootstrap tool will never
invoke the real tenant bootstrap tool and vice versa.

---

## 10. Change Control

Changes to this contract require:

1. PR to `main` with updated manifest and contract doc
2. Re-run of `scripts/qa/verify-runtime-proof-fixture-pack.sh` in CI (passes before merge)
3. If fixture classes are removed or renamed: update rollback packet accordingly
4. If new fixture classes are added: update pre-browser-proof checklist (section 7)
