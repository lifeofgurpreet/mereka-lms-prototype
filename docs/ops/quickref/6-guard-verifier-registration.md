# 6-Guard Registration Matrix for `scripts/qa/verify-*.sh`

Adding a new verifier requires touching **six coordinated surfaces**. Missing any one causes
CI to fail with a drift-only error that does not clearly point at the real gap.

> **History**: this was previously described as "5 guards" in memory and TRUTH_REPAIR_DOCTRINE.
> Guard #6 (verification catalog regen) was confirmed as a mandatory distinct step by PR #2104
> (bead `rq9k`, 2026-04-23). See [History](#history--why-6-and-not-5) below.

---

## The 6 Guards

| # | Guard | File | When required | How to apply |
|---|---|---|---|---|
| 1 | **CI static inventory** | `scripts/governance/script-registry.yaml` → `ci_static_inventory.entries` | Always (for offline/static CI execution) | Hand-edit; add `- script: scripts/qa/verify-<name>.sh` under `entries:` |
| 2 | **CI static derivative** | `.github/ci-scripts-static.txt` + shard files | Always (after #1) | `python3 scripts/governance/generate-ci-static-inventory.py --write` |
| 3 | **Sprawl budget** | `verification/manifests/verification_sprawl_budget.json` | Always | Bump `max_total_verify_scripts` by 1; append rationale string citing bead ID + failure class closed |
| 4 | **Reachability allowlist** | `scripts/qa/fixtures/verify-script-reachability-allowlist.json` | If `verify-verify-script-reachability.sh` would flag the new script | Add an entry; consumed by `verify-verify-script-reachability.sh` |
| 5 | **Staging vocabulary allowlist** | `scripts/qa/fixtures/staging-vocabulary-allowlist.json` | Only if script source text contains the word `staging` | Add vocabulary entry; consumed by `verify-staging-vocabulary-drift.sh` |
| 6 | **Verification catalog** | `verification/catalogs/verification_catalog.json` + `verification/catalogs/VERIFICATION_CATALOG.md` | Always (after #1) | `python3 scripts/qa/generate-verification-catalog.py` |

Guards #4 and #5 are **conditional**. All others are mandatory for every new `scripts/qa/verify-*.sh`.

---

## Minimal Check-in Sequence

```bash
# 1. Write the script
scripts/qa/verify-<name>.sh

# 2. Add to script-registry.yaml ci_static_inventory.entries (hand-edit)
#    Also add to ci_runtime_inventory.entries if it needs external/cluster deps

# 3. Bump sprawl budget
#    Edit verification/manifests/verification_sprawl_budget.json
#    Increment max_total_verify_scripts by 1
#    Append rationale with bead ID

# 4. (Conditional) Add to verify-script-reachability-allowlist.json
#    Run verify-verify-script-reachability.sh locally to check if needed

# 5. (Conditional) Add to staging-vocabulary-allowlist.json
#    Only if the script text contains "staging"

# 6. Regenerate the CI static derivative
python3 scripts/governance/generate-ci-static-inventory.py --write

# 7. Regenerate the verification catalog
python3 scripts/qa/generate-verification-catalog.py

# 8. git status should show exactly:
#    - the new script (+ any fixture files)
#    - scripts/governance/script-registry.yaml
#    - verification/manifests/verification_sprawl_budget.json
#    - .github/ci-scripts-static.txt (+ shard files)
#    - verification/catalogs/verification_catalog.json
#    - verification/catalogs/VERIFICATION_CATALOG.md
#    - (if #4): scripts/qa/fixtures/verify-script-reachability-allowlist.json
#    - (if #5): scripts/qa/fixtures/staging-vocabulary-allowlist.json
```

---

## Failure Modes and CI Symptoms

| CI symptom | Missing guard |
|---|---|
| `FAIL verify-verify-script-reachability` | Guard #4 — reachability allowlist |
| Script literally does not run (no entry in any shard file) | Guard #1 or #2 — registry entry missing, or derivative not regenerated |
| `FAIL total verify scripts N exceeds budget M` | Guard #3 — sprawl budget not bumped |
| `staging vocabulary allowlist` error in lint-repo-conventions | Guard #5 — staging vocabulary entry missing |
| `Verification catalog drift detected. Changed files: verification/catalogs/...` | Guard #6 — catalog not regenerated |

---

## Runtime-Only Scripts (ci_runtime_inventory path)

Scripts that require live cluster access, external endpoints, or secrets belong in
`ci_runtime_inventory`, not `ci_static_inventory`. They still need guards #3, #4 (conditional),
#5 (conditional), and #6. They do **not** need guards #1 and #2 (which are static-only).

Use `ci_runtime_inventory` for scripts that:
- `kubectl` against a real namespace
- `curl` an external endpoint
- Read from Infisical at runtime

---

## History — Why 6 and Not 5

- **Pre-2026-04-23**: memory and TRUTH_REPAIR_DOCTRINE referenced "5 coordinated changes"
  (reachability-allowlist + catalog regen + sprawl-budget + staging-vocabulary + rebase-catalog).
  That list conflated the two catalog steps and did not enumerate CI static + derivative as separate items.
- **2026-04-23, PR #2104 (bead `rq9k`)**: First PR to require all six surfaces explicitly.
  Verification catalog regeneration emerged as a distinct required step (#6), separate from the
  derivative regeneration (#2). CI gate `verify-verification-catalog` failed when catalog was stale.
- **If you hit a 7th guard failure that is stable and reproducible**, update this doc, bump the heading,
  and update the bead `crre` body. Do not silently add a step to your commit without documenting it here.

---

## Related

- `docs/ops/quickref/verification-scripts.md` — script template, `@covers` annotation syntax, catalog outputs
- `docs/meta/standing-orders/TRUTH_REPAIR_DOCTRINE.md` (Rule 5) — verifier-chain layer discipline
- `scripts/governance/script-registry.yaml` — canonical CI static + runtime inventory
- `verification/manifests/verification_sprawl_budget.json` — budget + rationale history
- Bead `crre` — this doc
- Bead `rq9k` (PR #2104) — first PR requiring all 6 guards; base-images-pin-contract verifier
