# Runtime Proof Fixture Handoff

> **Lane**: lane-i (Runtime Proof Fixture Contract)
> **Status**: Repo-only / tooling complete. Mutation not wired.
> **Date**: 2026-03-12

---

## What Was Codified in This Lane

This lane delivered a complete **repo-only, tooling-only** synthetic runtime proof fixture pack.
Nothing was mutated in any live cluster. All artifacts are static files in the repo.

### Delivered artifacts

| Artifact | Path | Purpose |
|----------|------|---------|
| Contract document | `docs/stabilization/SYNTHETIC_RUNTIME_PROOF_FIXTURE_CONTRACT.md` | Single source of truth for fixture intent, allowed/forbidden actions, naming conventions |
| Dev manifest | `config/runtime-proof/dev.synthetic-proof-fixtures.yaml` | Machine-readable fixture spec (identities, enterprise data, catalog split, waffle flags, negative cases) |
| Bootstrap planner | `scripts/tenants/bootstrap-runtime-proof-fixtures.py` | Dry-run capable planning tool; `--apply` is stubbed with warning |
| Validation tool | `scripts/tenants/validate-runtime-proof-fixtures.py` | Read-only schema/consistency validator; exit 0 = valid |
| CI static verifier | `scripts/qa/verify-runtime-proof-fixture-pack.sh` | CI-safe pack integrity check; runs in any environment |
| Execution packet | `docs/reviews/RUNTIME_PROOF_FIXTURE_EXECUTION_PACKET.md` | When to run, exact commands, required evidence |
| Rollback packet | `docs/reviews/RUNTIME_PROOF_FIXTURE_ROLLBACK_PACKET.md` | Rollback scope, safe/unsafe objects, distinguishing synthetic from real |
| Python tests | `tests/test_runtime_proof_fixtures.py` | pytest suite covering manifest parsing, fixture classes, dry-run stability, negatives |

### What the bootstrap tool covers (dry-run plan only)

- 4 synthetic LMS user accounts with `lanea-` prefix and `@synthetic.test` emails
- 1 EnterpriseCustomer (`biji-biji-initiative`) with `@synthetic.test` contact email (real-account guard)
- 1 LMS-side EnterpriseCustomerCatalog with org filter covering BIJIBIJI + MEREKA
- EnterpriseCustomerUser links for admin and learner roles
- ASSERT_ABSENT for the negative/non-linked user
- 1 enterprise-catalog service catalog (mirrors LMS-side; UUID is `null` until LMS bootstrap runs)
- 1 platform-wide waffle flag (`enterprise.learner_bff_enabled`)
- 5 tenant-scoped waffle switches for `biji-biji-initiative`

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

The following items are explicitly NOT codified in this lane and must be handled by a future
runtime mutation lane (run from inside the cluster):

| Item | Where it lives | Why not in this lane |
|------|---------------|---------------------|
| Actual DB writes (LMS users, EnterpriseCustomer records) | Live `mereka-lms-dev` MySQL | This is a repo-only lane; no kubectl, no Django ORM |
| Synthetic user password creation | Infisical `/runtime-proof/` + LMS management command | Passwords must never be committed; require cluster access |
| Enterprise-catalog service record creation | enterprise-catalog management API | Requires cluster access + post-LMS-bootstrap UUID |
| Waffle flag creation in DB | LMS Django admin or management command | Requires cluster access |
| Browser-based proof flow execution | Agent browser + live cluster | Requires live fixture state from the mutation step |
| Post-apply validation (live) | `validate-runtime-proof-fixtures.py --live` (placeholder) | `--live` is a stub; cluster checks not yet wired |

---

## What the Future Runtime Lane Can Do

A future lane (with cluster access) can build on this pack by:

1. Running `bootstrap-runtime-proof-fixtures.py --apply` from inside an LMS pod
   (mutation must be wired in the apply path)
2. Retrieving the LMS-assigned `EnterpriseCustomerCatalog` UUID and updating
   `enterprise_catalog_uuid` in the manifest
3. Running enterprise-catalog management command to create the service-side catalog
4. Verifying the catalog via the enterprise-catalog API endpoint documented in the manifest
5. Running the browser-based proof flow against `apps.academyv2.mereka.dev`
6. Capturing evidence per the execution packet

The static tooling and manifest in this lane serve as the **ground truth contract** that the
runtime lane must satisfy before claiming enterprise proof.

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
