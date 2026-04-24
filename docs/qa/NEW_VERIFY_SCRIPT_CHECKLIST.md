# New `scripts/qa/verify-*.sh` Checklist

> **Purpose**: one canonical place to list every allowlist, catalog, and budget a new verifier script must register with. Capture of the pain during bead `mereka-lms-te71` (PR #1960), which iterated 6 times against 5 drift guards before merging.

If you skip a step here, CI will tell you — but each miss costs one full CI cycle (~10–15 min on fastlane). Run the preflight block below and you'll ship the right diff the first time.

## The guard matrix

Five allowlists plus one budget, depending on the shape of the script:

| Guard | Fixture path | When required |
|---|---|---|
| `verification_catalog` | `verification/catalogs/verification_catalog.json` + `.md` | **ALWAYS** for any `scripts/qa/verify-*.sh` or `test-*.sh` |
| `script-governance-orphan` | `scripts/qa/fixtures/script-governance-orphan-allowlist.txt` | If path is **NOT** `scripts/qa/verify-*.sh` (e.g. `scripts/tenants/*.sh` / `scripts/ops/*.sh`) |
| `staging-vocabulary-drift` | `scripts/qa/fixtures/staging-vocabulary-allowlist.json` | If the script **body** contains the word `staging` |
| `siteconfig-authority` | `scripts/qa/fixtures/siteconfig-authority-allowlist.txt` | If the script **mutates** SiteConfiguration (grep patterns in `scripts/qa/verify-siteconfig-authority.sh`) |
| `verify-script-reachability` | `scripts/qa/fixtures/verify-script-reachability-allowlist.json` | If manual-only / runtime-only (NOT wired into `.github/run-release-verification-gates.sh`) |
| `verification-sprawl-budget` | `verification/manifests/verification_sprawl_budget.json` | **ALWAYS** — bump `max_total_verify_scripts` by 1 with rationale |

## Preflight (run before push)

```bash
# 1. Regenerate the verification catalog
python3 scripts/qa/generate-verification-catalog.py

# 2. Regenerate the CI inventories (if the new script runs in CI)
python3 scripts/governance/generate-ci-static-inventory.py --write
python3 scripts/governance/generate-ci-runtime-inventory.py --write

# 3. Run the five drift guards LOCALLY — each one will tell you exactly what to add
bash scripts/qa/verify-staging-vocabulary-drift.sh   | grep -E 'FAIL|Summary'
bash scripts/qa/verify-script-governance-orphans.sh
bash scripts/qa/verify-siteconfig-authority.sh
bash scripts/qa/verify-verify-script-reachability.sh
bash scripts/qa/verify-verification-catalog-drift.sh

# 4. Bump the sprawl budget
#    verification/manifests/verification_sprawl_budget.json:
#      "max_total_verify_scripts": <old + 1>
#      "last_updated_reason": "+ scripts/qa/verify-<new-name>.sh for bead mereka-lms-<xxxx>"
```

## Per-guard decision flow

```
            new scripts/qa/verify-*.sh
                   │
                   ├── regen verification_catalog ──────────> always
                   ├── bump verification_sprawl_budget ─────> always
                   │
                   ├── script body contains "staging"? ─────> add to staging-vocabulary-allowlist.json
                   │
                   ├── script mutates SiteConfiguration? ───> add to siteconfig-authority-allowlist.txt
                   │
                   ├── manual/runtime-only? ────────────────> add to verify-script-reachability-allowlist.json
                   │   (if wired into CI gates, skip this)
                   │
                   └── path NOT scripts/qa/verify-*.sh? ────> add to script-governance-orphan-allowlist.txt
                       (e.g. scripts/tenants/*.sh)
```

## Evidence — why this checklist exists

Bead `mereka-lms-te71` PR #1960 added **one** script (`scripts/qa/verify-obs-001-mfe-sentry-phase4.sh`). Before merge, CI iterated against each guard in sequence:

| Iteration | Failed guard | Fix |
|---|---|---|
| 1 | `verification-catalog-drift` | regen catalog JSON + MD |
| 2 | `staging-vocabulary-drift` | add to allowlist (script mentioned `staging` in a URL example) |
| 3 | `verify-script-reachability` | add to allowlist (manual-only) |
| 4 | `siteconfig-authority` | add to allowlist (script reads SiteConfiguration) |
| 5 | `verification-sprawl-budget` | bump `max_total_verify_scripts` by 1 |
| 6 | green — merged |

Had this checklist existed, a single commit could have landed all 5 adjustments in one push.

## Related

- Bead: `mereka-lms-crre`.
- Parent incident bead: `mereka-lms-te71`.
- Referenced by: `AGENTS.md` (onboarding) — a one-line pointer can be added.
- Similar session trap for `ci_static_inventory` vs `ci_runtime_inventory` differentiation is captured in `CLAUDE.md`.
