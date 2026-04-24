# Failure Taxonomy

> Stabilization document — mereka-lms CI and agent work failure classification.
> Date: 2026-03-11

This document classifies recurring failure modes observed in CI and agent sessions.
Each entry has a category, root cause, and a canonical fix or mitigation.

---

## Categories

| Category | Meaning |
|---|---|
| `RUNNER_CAPABILITY` | ARC runner lacks a tool or system package |
| `LINT_DRIFT` | Code committed without running linters; hidden debt surfaces in CI |
| `CONFIG_DATA_BOUNDARY` | Validation tool applied to wrong file type |
| `AGENT_CONTEXT` | Agent operating on wrong repo, branch, or worktree |
| `CI_CASCADE` | Each fix reveals the next hidden failure; false-red chain |

---

## Failure Modes

### 1. CRLF in YAML Files

| Field | Value |
|---|---|
| Category | `LINT_DRIFT` |
| Impact | yamllint fails on 64 files with Windows line endings |
| Root cause | Files edited on Windows without `.gitattributes` enforcement |
| Detection | `file *.yaml \| grep CRLF` or `yamllint` reporting `wrong new-line character` |
| Fix | `git add --renormalize .` after adding `* text=auto` to `.gitattributes` |
| Prevention | `.gitattributes` with `*.yaml text eol=lf`, enforced at commit time |

---

### 2. lint-repo-conventions Failures

| Field | Value |
|---|---|
| Category | `LINT_DRIFT` |
| Impact | CI fails on regex escaping errors, missing shebangs, naming violations, unpinned GH Actions |
| Root cause | Conventions added to CI after code was written; never retroactively checked |
| Detection | `lint-repo-conventions.sh` script run in `static-validation` job |
| Fix | Each sub-failure has a targeted fix — see sub-items below |
| Prevention | Run `make lint` locally before every commit |

**Sub-failures:**

- **Regex escaping**: Shell scripts using `[[ $var =~ pattern ]]` with unquoted special chars; fix by quoting the regex or assigning to a variable.
- **Missing shebangs**: Shell scripts without `#!/usr/bin/env bash` on line 1; add the shebang.
- **Naming conventions**: Scripts not matching `kebab-case.sh`; rename and update references.
- **Unpinned GH Actions**: `uses: actions/checkout@v4` without SHA pin; pin to full commit SHA.

---

### 3. shellcheck GitHub Action Fails on ARC Runners

| Field | Value |
|---|---|
| Category | `RUNNER_CAPABILITY` |
| Impact | shellcheck Action cannot install itself — fails trying to extract `.tar.xz` |
| Root cause | `xz-utils` not present on lightweight ARC runners; `.tar.xz` extraction fails |
| Detection | Action log: `xz: command not found` or `Cannot open: No such file` during Action setup |
| Fix | Install `xz-utils` via init step, OR run shellcheck via `pip install shellcheck-py` (no xz required) |
| Workaround in place | `scripts/qa/shellcheck-runner.sh` uses `shellcheck-py` (pip-installable, no system dep) |
| Prevention | Never use third-party Actions that download `.tar.xz` on lightweight runners |

---

### 4. Pre-existing shellcheck Errors Hidden by Never-Running shellcheck

| Field | Value |
|---|---|
| Category | `LINT_DRIFT` |
| Impact | SC1087, SC1072, SC1073 errors found across scripts once shellcheck was actually wired up |
| Root cause | shellcheck was added to CI config but the Action was broken (see #3 above), so errors accumulated silently |
| Detection | `shellcheck --severity=error scripts/**/*.sh` |
| Fix | Address each error class: |
| Prevention | Block merge if shellcheck exits non-zero |

**Common error classes found:**

| SC Code | Description | Fix |
|---|---|---|
| SC1087 | Array expansion `$array[*]` missing braces | Change to `${array[*]}` |
| SC1072 | Unexpected token in `[[ ]]` (often a function call) | Move function call outside `[[ ]]` |
| SC1073 | Couldn't parse `[[ ... ]]` (malformed expression) | Restructure the conditional |

---

### 5. kubeconform Validation Fails on Non-K8s YAML Data Files

| Field | Value |
|---|---|
| Category | `CONFIG_DATA_BOUNDARY` |
| Impact | `kubeconform` rejects `registry.yaml`, `SECRET_CLASSIFICATION.yaml`, helm values, tutor patches |
| Root cause | kubeconform run glob includes all `.yaml` files in the repo, not only K8s manifests |
| Detection | `kubeconform` output: `error validating ... no matches for kind` |
| Fix | Scope kubeconform to `deploy/k8s/` only; add `--ignore-missing-schemas` for CRDs |
| Prevention | CI script must explicitly scope manifest validation: `kubeconform deploy/k8s/` |

---

### 6. lsb_release Missing on ARC Runners

| Field | Value |
|---|---|
| Category | `RUNNER_CAPABILITY` |
| Impact | `actions/setup-python@v5` pip cache key computation fails; step errors or skips |
| Root cause | `lsb_release` is part of `lsb-core` — not installed on lightweight ARC runners |
| Detection | Action log: `lsb_release: command not found` during pip cache key step |
| Fix | Stub `lsb_release` script installed to `$GITHUB_WORKSPACE/.cache/bin/lsb_release` |
| Workaround in place | `scripts/qa/install-lsb-stub.sh` writes a minimal stub returning `Ubuntu 22.04` |
| Prevention | See ARC_RUNNER_CAPABILITY_CONTRACT.md — document runner gaps before adding new Actions |

---

### 7. Wrong Repo / Wrong Branch / Wrong Worktree Mistakes

| Field | Value |
|---|---|
| Category | `AGENT_CONTEXT` |
| Impact | Changes committed to wrong repository, branch, or worktree; merge conflicts; lost work |
| Root cause | Agents inherit shell cwd from session start; worktree confusion after parallel spawning |
| Detection | `git remote -v`, `git branch --show-current`, `git rev-parse --show-toplevel` |
| Fix | Always verify context at turn start: repo, branch, working tree clean status |
| Prevention | EXECUTION_INVARIANTS.md mandates context check before any mutation |

---

### 8. Dirty Tree Mutation (Committing to main)

| Field | Value |
|---|---|
| Category | `AGENT_CONTEXT` |
| Impact | Commits land on `main` directly, bypassing CI and PR review |
| Root cause | Agent forgets to create feature branch; or reuses a session already on `main` |
| Detection | `git branch --show-current` returns `main` before commit |
| Fix | Revert commit (`git revert`), push revert, then replay on a feature branch |
| Prevention | EXECUTION_INVARIANTS.md: never commit if `git branch --show-current` returns `main` |

---

### 9. False-Red CI Cascades

| Field | Value |
|---|---|
| Category | `CI_CASCADE` |
| Impact | Each fix to CI uncovers the next hidden failure; CI appears permanently broken |
| Root cause | Multiple independent lint/capability failures accumulated over time; fixing one unmasks the next |
| Detection | Pattern: CI passes after fix → new unrelated failure appears in next run |
| Fix | Stabilization sprint: enumerate all failures upfront before fixing any; fix in dependency order |
| Prevention | `static-validation` job must run cleanly on `main` at all times; gate merges on green CI |

---

## Summary Table

| # | Failure | Category | Fixed? |
|---|---|---|---|
| 1 | CRLF in YAML | LINT_DRIFT | Partial |
| 2 | lint-repo-conventions | LINT_DRIFT | Partial |
| 3 | shellcheck Action xz-utils | RUNNER_CAPABILITY | Workaround |
| 4 | Pre-existing shellcheck errors | LINT_DRIFT | In progress |
| 5 | kubeconform scope | CONFIG_DATA_BOUNDARY | Partial |
| 6 | lsb_release missing | RUNNER_CAPABILITY | Workaround |
| 7 | Wrong repo/branch/worktree | AGENT_CONTEXT | Process |
| 8 | Committing to main | AGENT_CONTEXT | Process |
| 9 | False-red CI cascade | CI_CASCADE | Ongoing |
