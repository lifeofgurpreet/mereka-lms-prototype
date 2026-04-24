---
title: CI-Gate Defect Taxonomy
type: reference
owner: platform-release
status: active
observed_at: 2026-04-19
---

# CI-Gate Defect Taxonomy
_Audience: Platform operators and agents • Owner: platform-release • Status: active_

## Purpose

This document catalogs recurrent defect classes that cause CI gate failures during routine
operator and agent work on this repository. It exists so that when a gate fires, the operator
can identify the defect class in one sentence, find the fix command, and not repeat the same
mistake in future sessions. Consult it at the start of any CI-repair triage, before writing
a new verify script, and before rebasing a PR that touches catalog or workflow files. It is
not exhaustive; open a PR to add classes as new patterns emerge.

---

## DX-01 — Catalog Drift on New Scripts

**Symptom**

CI step `verify-verification-catalog` fails. Error message references a script path that is not
present in `verification/catalogs/verification_catalog.json`.

**Root cause**

A new `scripts/qa/verify-*.sh` (or any script registered in
`scripts/governance/script-registry.yaml`) was committed without regenerating the catalog
artifact. The catalog is a derivative of the registry; it must be re-emitted after every
registry change.

**Fix command**

```bash
bash scripts/qa/regen-verification-catalog.sh
git add verification/catalogs/verification_catalog.json
git commit -m "chore(ci): regen verification catalog after adding <script-name>"
```

**Prevention candidate**

Add a pre-commit hook that runs `regen-verification-catalog.sh --check` on any commit
touching `scripts/governance/script-registry.yaml` or `scripts/qa/verify-*.sh`.

---

## DX-02 — `continue-on-error` Keyword Classifier

**Symptom**

Governance verifier (`verify-build-workflow-contract.sh` or the workflow-contract static check)
rejects a step with an error similar to:

```
step "Upload coverage report" uses continue-on-error: true but name lacks required keyword
```

**Root cause**

Workflow steps marked `continue-on-error: true` must carry one of the approved keywords in
their `name` field so reviewers and verifiers can distinguish intentional non-blocking steps
from silently-swallowed failures. Approved keywords:

> `non-blocking` · `observability` · `tracked` · `debt` · `optional` · `desirable` ·
> `may not exist` · `failed` · `fallback`

**Fix command**

Edit the step name to include the keyword. Example:

```yaml
# Before
- name: Upload coverage report
  continue-on-error: true

# After
- name: Upload coverage report (non-blocking)
  continue-on-error: true
```

No script to run; the change is a YAML edit. Push and let CI re-evaluate.

**Prevention candidate**

Inline comment on the `continue-on-error: true` patterns in the composite actions README,
listing approved keywords.

---

## DX-03 — Sprawl Budget Exceeded by New Verify Script

**Symptom**

CI step referencing `verify-verification-sprawl-budget.sh` (or the static-validation job)
fails with a message like:

```
FAIL: total verify scripts (42) exceeds max_total_verify_scripts budget (41)
```

**Root cause**

Adding a new verify script increments the count of scripts tracked by the sprawl budget
manifest. The budget is a deliberate gate to prevent uncontrolled proliferation of one-off
check scripts.

**Fix command**

```bash
# Open verification/manifests/verification_sprawl_budget.json
# Increment max_total_verify_scripts by 1 and add a rationale comment
# Then commit alongside the new script
git add verification/manifests/verification_sprawl_budget.json
git commit -m "chore(ci): bump sprawl budget +1 for <script-name> — <rationale>"
```

**Prevention candidate**

Before adding any new verify script, confirm the new script cannot be an extension of an
existing one. Reserve new scripts for genuinely independent invariant classes.

---

## DX-04 — Reachability Chain via Comment Reference

**Symptom**

CI static analysis marks a script as "reachable" even though it is not wired into any
workflow job. The reachability classifier picked up a comment inside another script, e.g.:

```bash
# See also: scripts/qa/verify-foo.sh
```

**Root cause**

The reachability classifier follows comment references as implicit edges in the dependency
graph. A script mentioned in a comment is treated as reachable even if no workflow step
actually calls it.

**Fix command**

Option A — wire it properly (preferred):

```bash
# Add the script to the ci_static_inventory in scripts/governance/script-registry.yaml
# then regenerate the derivative
python3 scripts/governance/generate-ci-static-inventory.py --write
```

Option B — add it to the reachability allowlist if it is intentionally comment-only:

```bash
# Edit the allowlist in scripts/governance/script-registry.yaml
# under reachability_allowlist, add the script path with a rationale
```

**Prevention candidate**

Use full relative paths only in comments when you intend a reference, and ensure the
distinction between "mentioned" and "executed" is clear in script headers.

---

## DX-05 — Post-Dependency-Merge Stale Revert

**Symptom**

A PR adds a catalog-regen commit. After the dependency PR lands on `main`, a rebase of the
branch makes the catalog-regen commit an exact undo of `main`'s current catalog state. CI
then sees a catalog regression.

**Root cause**

When the dependency PR was merged it brought its own catalog-regen. The branch PR's regen
commit was generated against the pre-merge state of `main`. After rebase the branch's regen
and `main`'s regen cancel each other out or produce a stale artifact.

**Fix command**

```bash
git fetch origin
git rebase origin/main
# After rebase, re-run the regen to produce a fresh artifact:
bash scripts/qa/regen-verification-catalog.sh
git add verification/catalogs/verification_catalog.json
git commit -m "chore(ci): post-rebase catalog regen"
```

**Prevention candidate**

Always run `regen-verification-catalog.sh` as the final step before pushing a rebased PR,
regardless of whether the rebase appeared clean.

---

## DX-06 — New Canonical Doc Requires Doc Catalog Entry

**Symptom**

CI step `verify-doc-catalog-governance` fails with `DOCS_CATALOG_GOVERNANCE_FAIL`. A doc at a
path that has become the canonical entry point for its topic is absent from
`generated/catalogs/docs-catalog.json` (and the mirror `docs/catalog.json`).

**Root cause**

A new document was added under `docs/ops/`, `docs/concepts/`, or another tracked subtree
without regenerating the doc catalog. The catalog tool walks the `docs/` tree at CI time;
uncatalogued files in governed subtrees fail the governance gate.

**Fix command**

```bash
python3 tools/docs/verify/build-doc-catalog.py --root .
git add docs/catalog.json generated/catalogs/docs-catalog.json
git commit -m "chore(docs): regen doc catalog after adding <doc-name>"
```

**Prevention candidate**

Run `build-doc-catalog.py --root . --check` locally before pushing any commit that adds a
file under `docs/`.

---

## DX-07 — Catalog Staleness After Rebase

**Symptom**

Same CI failure as DX-06 but triggered by a rebase rather than a new file. After rebasing
on `main`, the branch's catalog appears stale relative to the additions that landed in the
base branch during the rebase window.

**Root cause**

`git rebase` picks up main's new catalog entries silently via the merge machinery. If the
branch also modified catalog-generating sources (added verify scripts, renamed docs), the
resulting catalog reflects neither the fresh main state nor the branch's intended additions.

**Fix command**

```bash
git fetch origin
git rebase origin/main
# Explicit regen is required — rebase does not automatically reconcile generated artifacts
bash scripts/qa/regen-verification-catalog.sh
python3 tools/docs/verify/build-doc-catalog.py --root .
git add verification/catalogs/verification_catalog.json docs/catalog.json generated/catalogs/docs-catalog.json
git commit -m "chore(ci): post-rebase catalog regen (verification + docs)"
```

**Prevention candidate**

Treat catalog regen as a mandatory post-rebase step, not an optional one, whenever the
branch touches any script registry or docs subtree.

---

## DX-08 — Verifier Contract Literal-Substring Match

**Symptom**

`verify-build-workflow-contract.sh` (or a similar verifier that checks workflow file content)
fails after a workflow step's error message or label was edited. Example:

```
FAIL: workflow does not contain required substring 'timed out after 20m'
```

**Root cause**

Workflow-contract verifiers check for literal substrings in workflow YAML files to ensure
load-bearing strings (e.g., timeout annotations, error messages, required labels) are
present. Editing the surrounding prose while moving the functional string breaks the contract
check.

**Fix command**

Preserve the load-bearing substring. New context can go alongside it in parentheses:

```yaml
# Before (breaks contract — original string removed):
- name: Build image (build fails after 25m — extended timeout)

# After (contract holds — original substring preserved):
- name: Build image (timed out after 20m — hard limit)
```

No script to run. Edit the workflow YAML to restore the required substring, then push.

**Prevention candidate**

When editing step names or error messages in CI workflows, `grep` for the string first in
`scripts/qa/verify-*.sh` to confirm it is not a contract anchor before changing it.

---

## DX-09 — Ruff Lint as Blocking Gate

**Symptom**

`Static Validation Precheck` job fails. Log shows ruff exit non-zero on one or more scripts
under `scripts/`. Common violation codes:

| Code | Description |
|------|-------------|
| `F401` | Unused import |
| `I001` | Import block not sorted (isort ordering) |
| `B028` | `warnings.warn()` called without `stacklevel` argument |
| `B904` | `raise` inside `except` block lacks `from e` |

**Root cause**

The static-validation CI runner passes Python scripts through `ruff check`. Violations in
any registered script cause the gate to fail. `F401` and `I001` are auto-fixable; `B028` and
`B904` require manual edits.

**Fix command**

```bash
# Auto-fix F401 and I001
ruff check --fix scripts/

# Manual fix for B028 — add stacklevel:
warnings.warn("message", stacklevel=2)

# Manual fix for B904 — chain the exception:
except SomeError as e:
    raise RuntimeError("context") from e

# Verify clean before committing:
ruff check scripts/
```

**Prevention candidate**

Run `ruff check scripts/` (or `ubs scripts/<changed-file>.py`) before every commit that
touches Python files in `scripts/`. Add `ruff` to the project pre-commit config if not
already present.

---

## Related

- `docs/meta/standing-orders/README.md` — lane-specific standing orders for contributors and
  agents; complements this taxonomy for process-level expectations
- `scripts/governance/validate-registry.sh` — validates the script registry YAML for
  structural correctness before catalog regeneration
- `scripts/qa/regen-verification-catalog.sh` — regenerates
  `verification/catalogs/verification_catalog.json` from the registry; run after any
  registry change or post-rebase
- `tools/docs/verify/build-doc-catalog.py` — regenerates `docs/catalog.json` and
  `generated/catalogs/docs-catalog.json`; run after adding or renaming docs files

---

_Last verified: 2026-04-19_
