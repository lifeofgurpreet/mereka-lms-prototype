# CI False-Red Prevention

Compact reference for classifying and resolving CI failures without blocking unrelated PRs.

---

## Failure Classification

| Category | Definition | Owner | Action |
|---|---|---|---|
| `REPO_CONTENT_DEFECT` | Lint, syntax, or convention violation in files changed by the PR | PR author | Fix in the same PR before merge |
| `CI_WORKFLOW_DEFECT` | Bug in `.github/workflows/`, composite action, or `run-scripts-parallel.sh` | CI lane | Fix in `.github/` — separate PR unless trivial |
| `RUNNER_CAPABILITY_DEFECT` | Missing binary, system package, or OS feature on ARC self-hosted runner | Platform team | Add `command -v` guard + fallback in workflow step or composite action |
| `BASELINE_DEBT_OUTSIDE_SCOPE` | Pre-existing failure reproducible on `main`, unrelated to PR changes | Debt lane | Open a separate PR; do not block the current one |
| `EXTERNAL_PLATFORM_TRANSIENT` | GitHub API timeout, runner scheduling delay, network flake, ephemeral OOM | Nobody | Re-run the job; no code change required |

---

## Prevention Rules

### 1. Docs-Only Scope Gating
`ci.yml` stays attached for documentation-only and CI-control-plane PRs so the
required branch-protection contexts still report. The current prevention model
is:

- `change-scope` computes `docs_only` for PR diffs
- heavyweight Tutor rendering is further narrowed by `tutor_required`
- dependency review and IaC scan no longer use workflow-level `paths-ignore`
  for docs-only PRs, so their required contexts still attach

Never reintroduce broad docs-only workflow detachment for required checks.
Scope heavy work inside jobs, not by dropping the workflow from the PR.

### 2. K8s vs Non-K8s YAML Separation
`kubeconform` must exclude data files that are valid YAML but not K8s API objects. The pipeline in `ci.yml` uses a `grep -v` chain before piping to `kubeconform`:

```
grep -v '/patches/'
grep -v '/config/'
grep -v '/settings/'
grep -v 'helm-values'
grep -v 'registry\.yaml'
grep -v 'SECRET_CLASSIFICATION'
```

When adding new non-manifest YAML under `deploy/k8s/`, extend this list. Do not pass data files to `kubeconform -strict`.

### 3. Shellcheck Portability — xz Fallback
`xz-utils` is not installed on ARC runners. The `shellcheck` install step uses a Python `lzma` fallback when `xz` is absent:

```bash
if command -v xz &>/dev/null; then
  tar xJf "${SC_TARBALL}"
else
  python3 -c "import lzma, tarfile, io ..."
fi
```

Never replace this with `apt-get install xz-utils` — ARC runners have no `sudo`. Never install shellcheck via a third-party GitHub Action that may call `xz` directly.

### 4. lsb_release Stub
`actions/setup-python` calls `lsb_release -rs` and `lsb_release -is` to build pip cache keys. ARC runners lack the `lsb-release` package. The `setup-python-env` composite action installs a minimal shell stub at `$GITHUB_WORKSPACE/.cache/bin/lsb_release` and prepends that directory to `$GITHUB_PATH`.

If a new composite action calls `actions/setup-python`, it must either use `setup-python-env` or duplicate the stub step.

### 5. Runner Capability Check Pattern
Before any tool use in a workflow step, guard with `command -v`:

```bash
if ! command -v <tool> &>/dev/null; then
  # install or fail with a clear error
fi
```

Provide an install path or emit a diagnostic message that names the missing tool. Never let a raw `command not found` propagate as the CI failure — it is a `RUNNER_CAPABILITY_DEFECT`, not a `REPO_CONTENT_DEFECT`.

### 6. Spec Integrity Gates — Fetch Depth
`verify-legacy-testmaps-frozen.sh` compares against `origin/main`. The `static-validation` job uses `fetch-depth: 0` on `push` events but the default shallow clone on PR events may lack `origin/main`. Use `fetch-depth: 0` or `fetch-depth: 2` on PR checkouts when any script compares against the base branch.

### 7. Markdown Linting
Markdown lint failures are informational. Suppress exit codes with `|| true` — they must never block a PR. Treat persistent markdown warnings as `BASELINE_DEBT_OUTSIDE_SCOPE`.

---

## Decision Tree

When CI fails on a PR, work through these questions in order:

```
1. Is the failure in files changed by this PR?
   YES → REPO_CONTENT_DEFECT — fix it in the PR.

2. Does the same failure reproduce on main (without this PR's changes)?
   YES → BASELINE_DEBT_OUTSIDE_SCOPE — document in REPO_ONLY_CI_BLOCKER_LEDGER.md,
         open a separate debt PR, do not block current PR.

3. Is the failure "command not found" or a missing OS package?
   YES → RUNNER_CAPABILITY_DEFECT — add a command -v guard + install fallback
         in the workflow step or composite action.

4. Is the failure intermittent (passes on re-run without code change)?
   YES → EXTERNAL_PLATFORM_TRANSIENT — re-run, no code change needed.
         If it happens >2 times in a week, file a runner health issue.

5. Does the failure come from a workflow step, composite action, or
   run-scripts-parallel.sh itself (not from a verify script)?
   YES → CI_WORKFLOW_DEFECT — fix in .github/ via a separate targeted PR.
```

---

## Quick Reference

| Symptom | Category | Fix |
|---|---|---|
| `ruff: E501 line too long` in changed file | REPO_CONTENT_DEFECT | Fix in PR |
| required checks absent on a docs-only PR | CI_WORKFLOW_DEFECT | Restore workflow attachment and scope inside jobs |
| `kubeconform: failed to parse` on a Helm values file | CI_WORKFLOW_DEFECT | Add grep -v exclusion |
| `xz: command not found` during shellcheck install | RUNNER_CAPABILITY_DEFECT | Python lzma fallback (already present) |
| `lsb_release: command not found` | RUNNER_CAPABILITY_DEFECT | setup-python-env stub (already present) |
| Script exits 1 on main too | BASELINE_DEBT_OUTSIDE_SCOPE | Ledger + debt PR |
| Job timed out, no log output | EXTERNAL_PLATFORM_TRANSIENT | Re-run |
| `import lzma` missing in shellcheck step | CI_WORKFLOW_DEFECT | Python 3.3+ has lzma built-in; check Python version |
