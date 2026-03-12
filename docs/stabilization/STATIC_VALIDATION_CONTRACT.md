# Static Validation Contract

> **Authority**: This document is the canonical reference for what `static-validation` checks,
> in what order, and what each failure means. CI source of truth: `.github/workflows/ci.yml`.

## Parallel Script Runner Mechanics

| Parameter | Value | Override |
|-----------|-------|----------|
| Script list | `.github/ci-scripts-static.txt` (~201 entries) | — |
| Entrypoint | `scripts/qa/run-release-verification-gates.sh` | — |
| Parallelism | `PARALLELISM=4` | env var |
| Per-script timeout | `TIMEOUT_SECS=120` | env var |
| Results dir | `var/ci-results/` | hardcoded |
| Summary file | `var/ci-results/summary.txt` | hardcoded |

Runner mechanics (`run-scripts-parallel.sh`):
- Reads list file; skips blank lines and `#` comments
- Strips inline comments (`entry%% #*`) before execution
- Invokes each script via `timeout $TIMEOUT_SECS bash $script $extra_args`
- Emits `PASS`, `FAIL (exit N)`, or `TIMEOUT` per script to stdout, teed to `summary.txt`
- On any FAIL or TIMEOUT: dumps last 20 lines of `var/ci-results/<name>.log` and exits 1
- SKIP lines are counted but do not cause job failure

---

## Phase A — Syntax

| # | Step name | Command | Validates |
|---|-----------|---------|-----------|
| 1 | Syntax check all shell scripts | `find scripts/ -name '*.sh' \| xargs -P8 bash -n` + explicit checks on `verify-multisite-ux-consistency.sh` and `apply-patches.sh` | Bash parse-time errors in all scripts under `scripts/` and two out-of-tree files |
| 2 | Lint Python files | `ruff check scripts/ services/` | Style, imports, unused vars in Python under `scripts/` and `services/` |
| 3 | Lint YAML files | `yamllint -c .yamllint.yml infrastructure/ deploy/` | YAML syntax and style under `infrastructure/` and `deploy/` |
| 4 | Enforce repo conventions | `./scripts/qa/lint-repo-conventions.sh` | Immutable `uses:` refs (pinned SHA), naming conventions, file placement rules |
| 5 | Lint shell scripts (shellcheck) | `find scripts/ -name '*.sh' \| xargs -0 shellcheck --severity=error` | Shellcheck error-level findings; warning/info suppressed |
| 6 | Validate Kubernetes manifests | `kubeconform -strict -ignore-missing-schemas` on filtered `deploy/k8s/` YAML | Structural conformance of K8s resource YAMLs against upstream schemas |

### Step 5 — shellcheck install path and Python lzma fallback

shellcheck v0.10.0 ships as `.tar.xz`. On ARC runners, `xz` may not be in the base image.

```
if command -v xz: tar xJf <tarball>
else:             python3 -c "import lzma, tarfile, io; ..."
```

The Python fallback uses stdlib `lzma.decompress()` + `tarfile.open()` — no pip install needed.
Binary installed to `$GITHUB_WORKSPACE/.cache/bin/shellcheck` (on `$PATH` via Prepare local tool cache step).

**Fragility**: If the ARC runner image gains `xz` later, the `else` branch becomes dead code (harmless).
If Python lacks lzma support (unusual in CPython 3.12), both branches fail → `CI_WORKFLOW_DEFECT`.

### Step 6 — kubeconform exclusion patterns

| Excluded path pattern | Reason |
|-----------------------|--------|
| `*/patches/*` | Partial Jinja2/sed fragments; not valid standalone YAML |
| `*/config/*` | Tutor-generated config files with non-K8s structure |
| `*/settings/*` | Django settings files (Python or rendered text) |
| `helm-values` (substring) | Helm values files; not K8s manifests |
| `registry.yaml` (filename) | Tutor plugin registry; not a K8s resource |
| `SECRET_CLASSIFICATION` (substring) | Classification metadata file; not YAML |

`-ignore-missing-schemas` allows CRDs (ExternalSecret, ServiceMonitor, etc.) to pass without
local CRD schema files. `-strict` rejects unknown fields that upstream schemas don't define.

---

## Phase B — Spec Integrity

| # | Step name | Command | Validates |
|---|-----------|---------|-----------|
| 7 | Run spec integrity gates | `bash scripts/qa/run-spec-integrity-gates.sh` | 13 sub-checks: frontmatter completeness, AC ID uniqueness, testmap sync, `legacy-testmaps-frozen` (see below), cross-reference integrity |
| 8 | Spec coverage report | `spec_coverage_report.py --fail-under 80` | Overall `@covers` annotation density across all specs; job fails if < 80% |
| 9 | Spec coverage report for PR | Same script, no `--fail-under` | PR-only artifact upload; no blocking threshold |
| 10 | Markdown linting | `markdownlint docs/ specs/ --ignore docs/archive/ \|\| true` | Markdown style; errors suppressed — informational only, never blocks |

### Step 7 — `legacy-testmaps-frozen` shallow clone issue

The `legacy-testmaps-frozen` sub-check compares current testmap state against `origin/main`
using `git diff origin/main...HEAD`. This requires `fetch-depth: 0` (full history).

The `static-validation` job uses the default checkout action **without** `fetch-depth: 0`.
If the runner's git clone is shallow (depth=1), `origin/main` is unavailable and the sub-check
fails with `fatal: ambiguous argument 'origin/main'`.

**Classification**: `CI_WORKFLOW_DEFECT` — fix by adding `fetch-depth: 0` to the checkout step
or by converting the gate to compare against the merge-base SHA passed as an env var.

**Current mitigation**: The job's `change-scope` predecessor uses `fetch-depth: 0`; the
`static-validation` checkout does not. If this gate starts failing on shallow clones,
add `fetch-depth: 0` to the `static-validation` checkout.

---

## Phase C — Static Verification Scripts

| # | Step name | Mechanics |
|---|-----------|-----------|
| 11 | Run static verification scripts | Parallel runner; ~201 scripts from `ci-scripts-static.txt`; PARALLELISM=4, TIMEOUT=120s |

Each script in `.github/ci-scripts-static.txt`:
- Must exit 0 on success, non-zero on failure
- May emit `SKIP` lines to stdout (counted, not blocking)
- Gets `var/ci-results/<basename>.log` for stdout+stderr
- Inline flags after the path are passed as extra args (`$extra_args`)

Adding a new verification script: append its path (relative to repo root) to
`.github/ci-scripts-static.txt`. Scripts not in this file are never run in CI.

---

## Phase D — Branding / Design / Monitoring / Translation

| # | Step name | Domain |
|---|-----------|--------|
| 12–13 | A11y smoke + WCAG AA contrast (sequential, R5 dependency) | Accessibility |
| 14–16 | Design token syntax, provenance, theme values | Design tokens |
| 17 | Token drift verifier | Design tokens |
| 18 | config.example.yml validation | Config hygiene |
| 19 | OPENEDX_HOSTNAMES.md generated and current | Docs generation |
| 20–21 | Axe journey coverage, visual regression page count | A11y/visual |
| 22–23 | Visual smoke baseline, visual parity checkpoints | Visual regression |
| 24 | Generated token layers in sync | Branding |
| 25 | Source-only branding gate (`RUN_LIVE_GATE=0`) | Branding |
| 26 | Certificate branding surfaces | Branding |
| 27 | FPF slot coverage truth | MFE plugin slots |
| 28 | Frontend performance spot-check | Performance |
| 29 | Local observability audit | Monitoring |
| 30 | (additional gates per ci.yml) | Various |

---

## Failure Classifications

| Classification | Meaning | Example trigger |
|----------------|---------|-----------------|
| `REPO_CONTENT_DEFECT` | A script, YAML, or spec in the repo is wrong | `bash -n` fails; kubeconform rejects a manifest; spec AC ID collision |
| `CI_WORKFLOW_DEFECT` | CI setup is broken independent of repo content | shallow clone breaks `legacy-testmaps-frozen`; pinned action SHA mismatch |
| `RUNNER_CAPABILITY_DEFECT` | ARC runner lacks a binary or system dep | `xz` missing (mitigated by lzma fallback); `rg` not in PATH (mitigated by install step) |

---

## Known Fragility Points

| Sub-check | Fragility | Status |
|-----------|-----------|--------|
| `legacy-testmaps-frozen` (step 7) | Needs `fetch-depth: 0`; fails on shallow clone | Open — add fetch-depth to checkout or pass merge-base as env var |
| shellcheck install (step 5) | `xz` absent on some ARC images; Python lzma fallback | Mitigated |
| kubeconform download (cached) | Network fetch on cache miss; SHA pinned to v0.6.4 | Mitigated by `actions/cache` |
| ripgrep install | Verification scripts call `rg`; install step skipped if already in PATH | Mitigated |
| Markdown linting (step 10) | `|| true` — never blocks; errors are silently ignored | By design; informational only |
| Parallel runner SIGPIPE | `rg -q` in scripts with `set -o pipefail` exits 141 (false FAIL) | Scripts must use herestring (`rg -q <<< "$var"`) not pipe |
| Spec coverage threshold (step 8) | Threshold set at 80%; adding unmapped ACs without `@covers` annotations fails CI | Fix: annotate new ACs before merging |
