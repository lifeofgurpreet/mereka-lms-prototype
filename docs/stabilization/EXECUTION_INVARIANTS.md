# Execution Invariants

> Stabilization document — rules that must hold for any agent or human working in this repo.
> Date: 2026-03-11

These invariants are **non-negotiable**. Violating any one of them has historically caused
commits landing on `main`, CI remaining broken for multiple sessions, or lost work.

---

## Invariant 1: Always Work on a Feature Branch

**Rule**: Never commit directly to `main`. Every change, no matter how small, goes on a
named feature branch.

```bash
# Before any mutation, verify you are not on main
git branch --show-current     # Must NOT return "main"

# Create a branch if needed
git checkout -b fix/my-change
```

**Enforcement**: If `git branch --show-current` returns `main`, stop. Create a branch before proceeding.

**Violation consequence**: Direct push to `main` bypasses CI and PR review. Revert the commit
immediately, then replay on a feature branch.

---

## Invariant 2: Verify Clean Tree Before Mutation

**Rule**: Before any file write, `git add`, or `git commit`, verify the working tree is in the
expected state.

```bash
git status                    # No unexpected modifications
git remote -v                 # Correct repository
git rev-parse --show-toplevel # Correct worktree root
```

A dirty tree from a previous failed operation will pollute your commit.

---

## Invariant 3: Run shellcheck Before Committing Shell Scripts

**Rule**: Any shell script touched in a PR must pass `shellcheck --severity=error` before commit.

```bash
shellcheck --severity=error scripts/my-script.sh
```

**Why**: shellcheck was wired into CI but the Action was broken (xz-utils missing on ARC runners).
Errors accumulated silently across many PRs. Now that shellcheck runs, every hidden error surfaces.

**What to look for**: SC1087 (array expansion), SC1072/SC1073 (expressions in `[[ ]]`), SC2086
(unquoted variables). See FAILURE_TAXONOMY.md for the full catalogue.

---

## Invariant 4: Run yamllint Before Committing YAML

**Rule**: Any YAML file touched in a PR must pass yamllint before commit.

```bash
yamllint -c .yamllint.yml path/to/file.yaml
```

**Why**: 64 files had Windows CRLF line endings. yamllint catches this and other formatting
issues that cause silent failures in Kubernetes and Tutor.

**Line endings**: YAML files must use LF, not CRLF. `.gitattributes` enforces this at checkout,
but verify with `file yourfile.yaml` if in doubt.

---

## Invariant 5: kubeconform Only Runs on K8s Manifests

**Rule**: `kubeconform` validation is scoped to `deploy/k8s/` only. It must not be run against:

| Excluded path | Reason |
|---|---|
| `registry.yaml` | Tool registry data, not a K8s manifest |
| `SECRET_CLASSIFICATION.yaml` | Security classification data file |
| `infrastructure/tutor/patches/` | Jinja2 template patches, not valid YAML |
| `infrastructure/tutor/config/` | Tutor config, not K8s |
| Helm values files | Not standalone K8s manifests |

**Correct invocation**:
```bash
kubeconform --ignore-missing-schemas --strict deploy/k8s/base/ deploy/k8s/overlays/
```

Never: `kubeconform **/*.yaml` from repo root.

---

## Invariant 6: ARC Lightweight Runners Have Known Gaps

**Rule**: Do not add CI steps to lightweight runner jobs that require:

- `xz-utils` (used by many GH Actions for self-installation)
- `lsb_release` (used by `actions/setup-python@v5` for pip cache key)
- `sudo` or `apt` (not available without privilege escalation)
- Docker daemon (only available on `mereka-k8s-heavy-builders`)

**Check the contract**: Before adding any new GH Action or CI step to a lightweight runner job,
consult `ARC_RUNNER_CAPABILITY_CONTRACT.md`.

**Labels**:
- Lightweight: `runs-on: mereka-k8s-runners`
- Heavy (Docker): `runs-on: mereka-k8s-heavy-builders`

---

## Invariant 7: Never Use Third-Party Actions That Download .tar.xz Without Fallback

**Rule**: If a third-party Action downloads a `.tar.xz` archive to install itself (e.g., the
`shellcheck-action`), it will fail on ARC lightweight runners. Use pip-installable alternatives
or vendor the binary into the repo.

**Approved alternatives**:

| Tool | Instead of | Use |
|---|---|---|
| shellcheck | `ludeeus/action-shellcheck` | `pip install shellcheck-py` |
| shfmt | GH Action | `go install` or vendored binary |
| yamllint | — | `pip install yamllint` (already works) |

---

## Invariant 8: CI Must Pass on main Before Any PR Can Be Evaluated

**Rule**: If `main` is red, no PR evaluation is meaningful. Stabilize `main` first.

**Protocol when main is red**:
1. Identify the root failure (not the cascade — the root).
2. Raise a `stabilization/` branch PR with the minimal fix.
3. Merge only that fix.
4. Verify CI is green on `main`.
5. Only then resume feature work.

Do not merge feature PRs onto a broken `main`. The cascade obscures real failures.

---

## Invariant 9: One Hypothesis Per PR

**Rule**: Each PR addresses exactly one failure mode or one feature. Never bundle multiple
unrelated fixes in a single PR.

**Why**: Bundled PRs make bisection impossible. If CI breaks after merge, you cannot tell which
change caused it.

**Exception**: A `stabilization/` PR may fix multiple instances of the same root cause (e.g.,
adding shebangs to all scripts at once) — this is one hypothesis applied broadly.

---

## Invariant 10: Never Debug on main

**Rule**: Do not push "let's see if this fixes it" commits to `main`. All experimental commits
go on a feature branch. CI validates them there first.

---

## Quick Reference Card

```
Before any session:
  git branch --show-current   # Not main
  git status                  # Clean tree
  git remote -v               # Right repo

Before committing:
  shellcheck --severity=error <scripts>
  yamllint <yaml files>
  git diff --stat             # Only expected files

Before merging:
  CI green on feature branch
  PR reviewed (if not a repo-only stabilization fix)
  main is green
```
