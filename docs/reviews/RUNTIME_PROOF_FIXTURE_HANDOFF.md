# Runtime Proof Fixture Handoff

> **Lane**: lane-i / lane-j (Runtime Proof Fixture Contract + Execution Bridge)
> **Status**: Repo-only / tooling complete including execution bridge. Live mutation has NOT occurred.
> **Date**: 2026-03-12

---

## What Was Codified in This Lane

Lane-i delivered the contract, manifest, dry-run planner, static validator, CI verifier,
and tests. Lane-j (this lane) delivered the **execution bridge**: the apply code paths,
shared safety library, catalog companion tool, and live-readonly validation mode.

Nothing was mutated in any live cluster in either lane. All artifacts are static files in the repo, and non-dev manifests now exist so staging/prod proof planning does not depend on dev-only truth.

### Delivered artifacts

| Artifact | Path | Purpose |
|----------|------|---------|
| Contract document | `docs/stabilization/SYNTHETIC_RUNTIME_PROOF_FIXTURE_CONTRACT.md` | Single source of truth for fixture intent, allowed/forbidden actions, naming conventions |
| Fixture manifests | `config/runtime-proof/{dev,staging,prod}.synthetic-proof-fixtures.yaml` | Machine-readable fixture specs for active and non-dev proof planning |
| Shared safety library | `scripts/tenants/lib/proof_fixtures.py` | Guard functions, dataclasses, manifest loading — shared by all fixture tools |
| Shared library init | `scripts/tenants/lib/__init__.py` | Package init for shared library |
| Bootstrap tool (LMS) | `scripts/tenants/bootstrap-runtime-proof-fixtures.py` | Dry-run planner + `--apply` path (Django ORM, guard chain, idempotent creates) |
| Catalog companion tool | `scripts/tenants/bootstrap-runtime-proof-fixtures-catalog.py` | enterprise-catalog service records (CatalogQuery, EnterpriseCatalog); separate Django context |
| Validation tool | `scripts/tenants/validate-runtime-proof-fixtures.py` | Static validator + `--mode live-readonly` ORM checks; exit 0 = valid |
| CI static verifier | `scripts/qa/verify-runtime-proof-fixture-pack.sh` | CI-safe pack integrity check; sections 1–10 including new tooling checks |
| Execution packet | `docs/reviews/RUNTIME_PROOF_FIXTURE_EXECUTION_PACKET.md` | When to run, exact commands, required evidence, apply command docs |
| Rollback packet | `docs/reviews/RUNTIME_PROOF_FIXTURE_ROLLBACK_PACKET.md` | Rollback scope, safe/unsafe objects, distinguishing synthetic from real |
| Python tests | `tests/test_runtime_proof_fixtures.py` | 65-test pytest suite: manifest, dry-run, guards, shared library, catalog companion, idempotency, enterprise link |

### What the bootstrap tool covers

**Dry-run plan** (no Django required):

- 4 synthetic LMS user accounts with `lanea-` prefix and `@synthetic.test` emails
- 1 EnterpriseCustomer (`biji-biji-initiative`) with `@synthetic.test` contact email (real-account guard)
- 1 LMS-side EnterpriseCustomerCatalog with org filter covering BIJIBIJI + MEREKA
- EnterpriseCustomerUser links for admin and learner roles
- ASSERT_ABSENT for the negative/non-linked user
- 1 enterprise-catalog service catalog (mirrors LMS-side; UUID is `null` until LMS bootstrap runs)
- 1 platform-wide waffle flag (`enterprise.learner_bff_enabled`)
- 5 tenant-scoped waffle switches for `biji-biji-initiative`

**Apply path** (requires LMS Django context — code exists, live execution NOT performed):

- Guard chain (all-or-nothing): environment check, safety flag, email domain, real-account collision
- `User.objects.get_or_create` for each synthetic identity
- `EnterpriseCustomer.objects.get_or_create` for each enterprise customer (real-account guard)
- `EnterpriseCustomerCatalog.objects.get_or_create` for each catalog
- `EnterpriseCustomerUser.objects.get_or_create` for each linked user
- `Flag.objects.get_or_create` and `Switch.objects.get_or_create` for waffle state
- `ApplySummary` with created/reused/refused/skipped/error counts

### What the validation tool checks (statically)

- `real_account_mutation_forbidden: true` presence (safety invariant — hard stop if absent)
- All four required fixture classes present
- All synthetic user emails end in `@synthetic.test` (real-account email rejection)
- Enterprise customer `contact_email` is `@synthetic.test`
- Both LMS catalog side AND enterprise-catalog service side are represented (two-sided split)
- Platform-wide waffle flags include `enterprise.learner_bff_enabled`
- Tenant-scoped switches present

---

## What Remains External / Runtime-Owned

The following items require live cluster execution and are NOT performed in lane-i or lane-j:

| Item | Where it lives | Why not in these lanes |
|------|---------------|----------------------|
| Actual DB writes (LMS users, EnterpriseCustomer records) | Live `mereka-lms-dev` MySQL | Code exists; live execution requires cluster access from inside LMS pod |
| Synthetic user password creation | Infisical `/runtime-proof/` + LMS management command | Passwords must never be committed; setting them requires cluster access |
| Enterprise-catalog service record creation | enterprise-catalog pod Django context | Code exists in catalog companion; live execution requires cluster access |
| Browser-based proof flow execution | Agent browser + live cluster | Requires live fixture state from the apply step |
| Post-apply live validation | `validate-runtime-proof-fixtures.py --mode live-readonly` | Code exists and is wired; execution requires LMS pod context |

---

## What the Future Runtime Lane Can Do

A future lane (with cluster access) has everything it needs — the code is written:

1. Run `bootstrap-runtime-proof-fixtures.py --apply` from inside the LMS pod:
   ```bash
   kubectl exec -n mereka-lms-dev deploy/lms -- python \
     /openedx/scripts/tenants/bootstrap-runtime-proof-fixtures.py --env dev --apply
   ```
2. Retrieve the LMS-assigned `EnterpriseCustomerCatalog` UUID and update
   `enterprise_catalog_uuid` in the manifest.
3. Run the catalog companion from inside the enterprise-catalog pod:
   ```bash
   kubectl exec -n mereka-lms-dev deploy/enterprise-catalog -- python \
     /openedx/scripts/tenants/bootstrap-runtime-proof-fixtures-catalog.py --env dev --apply
   ```
4. Validate live state (read-only) from inside the LMS pod:
   ```bash
   kubectl exec -n mereka-lms-dev deploy/lms -- python \
     /openedx/scripts/tenants/validate-runtime-proof-fixtures.py \
     --env dev --mode live-readonly
   ```
5. Run the browser-based proof flow against `apps.academyv2.mereka.dev`.
6. Capture evidence per the execution packet.

The runtime lane does NOT need to write any new code. All apply paths, guard chains,
idempotency semantics, and live-readonly validation are already implemented.

---

## What This Pack Does Not Claim

- **Does not prove enterprise login works** — that requires a live browser flow
- **Does not prove the learner portal serves content** — requires live DB state and the
  enterprise-catalog service to be populated
- **Does not prove negative cases in production** — the negative case assertions are documented
  in the manifest but not executed by static tooling
- **Does not replace the real tenant bootstrap** — `config/enterprise-tenants/` and
  `scripts/tenants/bootstrap-enterprise-tenants.py` are unchanged and unaffected
- **Does not create any K8s resources** — this is a repo-only tooling lane

---

## CI Integration

The static verifier is registered in `.github/ci-scripts-static.txt` and runs as part of the
`static-validation` CI job on every push and PR:

```
scripts/qa/verify-runtime-proof-fixture-pack.sh
```

The script is CI-safe (no cluster access, no env vars required beyond Python 3.10 + PyYAML)
and exits 0/1.

---

## Key Invariants to Preserve in Future Lanes

1. All synthetic emails must end in `@synthetic.test` — enforced by both validate tool and tests
2. `real_account_mutation_forbidden: true` must remain in the manifest — the validate tool hard-stops if absent
3. Both LMS catalog side AND enterprise-catalog service side must always be represented — the catalog split check fails if either is absent
4. Synthetic fixtures must stay separate from the real tenant bootstrap system — never merge the two manifests or tool invocations
5. `lanea-` and `proof-` prefixes are reserved for synthetic objects — do not use them for real tenant data
