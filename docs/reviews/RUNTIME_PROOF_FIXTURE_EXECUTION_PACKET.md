# Runtime Proof Fixture Execution Packet

> **Lane**: lane-i (Runtime Proof Fixture Contract)
> **Environment**: dev
> **Mutation status**: NO live mutation in this lane — this is a repo-only tooling lane.
> **Canonical manifest**: `config/runtime-proof/dev.synthetic-proof-fixtures.yaml`
> **Contract**: `docs/stabilization/SYNTHETIC_RUNTIME_PROOF_FIXTURE_CONTRACT.md`

---

## Warning: No Live Mutation in This Lane

This execution packet documents the dry-run and validate commands that can be run
from any workstation without cluster access. It also documents the future apply command
(not yet wired) for reference.

**No `kubectl exec`, no Django ORM calls, no database writes are performed by running
the commands in this packet.** The bootstrap tool in its current form is a planning tool only.

---

## When to Run

Run the dry-run command:

- Before any browser-based proof flow against `mereka-lms-dev`
- After any change to `config/runtime-proof/dev.synthetic-proof-fixtures.yaml`
- In CI, as part of the static validation job
- Before opening a PR that touches enterprise fixture data

Run the validate command:

- In CI (included in `scripts/qa/verify-runtime-proof-fixture-pack.sh`)
- After any manifest change (confirm no schema regressions)

---

## Preconditions

### For dry-run and validate (this lane — no cluster needed)

- [ ] Python 3.10+ available
- [ ] PyYAML installed: `pip install pyyaml` (or `pip install -r requirements-tutor.txt`)
- [ ] Repo checked out at the correct branch
- [ ] `config/runtime-proof/dev.synthetic-proof-fixtures.yaml` exists

### For future apply (not yet wired — future runtime lane)

- [ ] All dry-run preconditions above
- [ ] `kubectl` configured and pointing at `mereka-lms-dev` namespace
- [ ] LMS pod is ready: `kubectl get pods -n mereka-lms-dev -l app.kubernetes.io/name=lms`
- [ ] Enterprise-catalog pod is ready: `kubectl get pods -n mereka-lms-dev -l app.kubernetes.io/name=enterprise-catalog`
- [ ] Operator has reviewed the dry-run output and confirmed it matches expectations
- [ ] Rollback packet (`docs/reviews/RUNTIME_PROOF_FIXTURE_ROLLBACK_PACKET.md`) has been read

---

## Exact Commands

### 1. Static Manifest Validation

```bash
# From repo root
python scripts/tenants/validate-runtime-proof-fixtures.py --env dev
```

Expected output:

```
VERDICT: VALID — all checks passed
```

Exit code 0 = valid. Exit code 1 = invalid (see check output for details).

Machine-readable variant (for CI):

```bash
python scripts/tenants/validate-runtime-proof-fixtures.py --env dev --json
```

### 2. Dry-Run Bootstrap Plan

```bash
# From repo root
python scripts/tenants/bootstrap-runtime-proof-fixtures.py --env dev
```

Expected output: a structured plan showing all CREATE_OR_NOOP, ASSERT_ABSENT,
ASSERT_SAFE, ENSURE_ACTIVE, ENSURE_INACTIVE, VERIFY_POST_BOOTSTRAP actions
that would be taken. No changes are written.

Machine-readable variant:

```bash
python scripts/tenants/bootstrap-runtime-proof-fixtures.py --env dev --json
```

### 3. CI Static Fixture Pack Verifier

```bash
# From repo root — runs all static checks including the above
bash scripts/qa/verify-runtime-proof-fixture-pack.sh
```

Exit code 0 = all static checks pass. Exit code 1 = one or more checks failed.

### 4. Future Apply Command (not yet wired)

```bash
# NOT AVAILABLE IN THIS LANE.
# When mutation is wired, this will be the command:
python scripts/tenants/bootstrap-runtime-proof-fixtures.py --env dev --apply
```

Running `--apply` in the current version prints a warning and exits with code 1.

For the future apply workflow (via kubectl exec from inside LMS pod):

```bash
kubectl exec -n mereka-lms-dev deploy/lms -- python \
  /openedx/scripts/tenants/bootstrap-runtime-proof-fixtures.py --env dev --apply
```

---

## Required Evidence

After running the dry-run and validate commands, capture the following as evidence:

| Evidence item | How to capture |
|---------------|---------------|
| Validate output | Paste `validate-runtime-proof-fixtures.py --env dev` output |
| Validate exit code | `echo $?` immediately after |
| Bootstrap dry-run output | Paste `bootstrap-runtime-proof-fixtures.py --env dev` output |
| Bootstrap dry-run JSON | Paste `--json` variant output |
| CI verifier output | Paste `verify-runtime-proof-fixture-pack.sh` output |
| Git commit SHA | `git rev-parse HEAD` |

For future apply runs, additional evidence is required — see the rollback packet.

---

## Fixture Pack Action Summary (Expected from Dry-Run)

The dry-run should produce actions in the following categories:

| Category | Kind | Count (approx) |
|----------|------|---------------|
| Real-Account Guards | ASSERT_SAFE | 1 |
| LMS User Accounts | CREATE_OR_NOOP | 4 |
| LMS Enterprise User Links | CREATE_OR_NOOP / ASSERT_ABSENT | 4 |
| LMS Enterprise Customers | CREATE_OR_NOOP | 1 |
| LMS Enterprise Catalogs | CREATE_OR_NOOP | 1 |
| Enterprise-Catalog Service | CREATE_OR_NOOP + VERIFY_POST_BOOTSTRAP | 2 |
| Waffle Flags (platform-wide) | ENSURE_ACTIVE | 1 |
| Waffle Switches (tenant-scoped) | ENSURE_ACTIVE / ENSURE_INACTIVE | 5 |

Total: approximately 19 actions. Deviation from this count is a signal to review the manifest.

---

## Known Limitations

1. **Enterprise-catalog UUID is null in manifest** — the `enterprise_catalog_uuid` field in
   `enterprise_catalog_service_data` is `null` until LMS-side bootstrap runs and assigns a UUID.
   After LMS bootstrap, retrieve the catalog UUID and update the manifest.

2. **Enterprise-catalog service records require separate step** — the bootstrap tool cannot
   write to the enterprise-catalog service in its current form. The enterprise-catalog management
   command or API must be used separately. The dry-run output flags this with a
   `VERIFY_POST_BOOTSTRAP` action.

3. **Passwords not set by this tool** — synthetic user passwords are stored in Infisical at
   `/runtime-proof/`. The bootstrap tool will print the Infisical path but will not fetch or
   set passwords. A future runtime lane step sets passwords via the LMS management command.
