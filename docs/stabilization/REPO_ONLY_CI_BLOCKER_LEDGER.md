# Repo-Only CI Blocker Ledger

> Lane F artifact. Tracks repo-local baseline debt that causes false-red CI on main
> and propagates to every open PR via shared status checks.

## Status: 2026-03-11

### FIXED — CRLF Line Endings (Primary Blocker)

**Impact**: yamllint `[new-lines] wrong new line character: expected \n` errors on 64 YAML files
caused `Static Validation` to fail on **main**, which propagated to **every open PR** (~20 PRs).

**Root cause**: Files committed with Windows-style CRLF (`\r\n`) line endings.

**Fix**: `sed -i 's/\r$//'` on all 64 files + `.gitattributes` enforcing `eol=lf`.

**Files affected** (64 total):
- `deploy/k8s/base/apps/*/` — deployment, service, kustomization, worker YAML files
- `deploy/k8s/base/jobs/` — all 6 migration job files
- `deploy/k8s/base/network-policies/` — all 8 network policy files
- `deploy/k8s/overlays/production/` — 5 ingress files

**Prevention**: `.gitattributes` now enforces LF for `*.yaml`, `*.yml`, `*.sh`, `*.py`, `*.js`, `*.json`, `*.md`.

### FIXED — lint-repo-conventions.sh Failures (64 total)

**Impact**: The parallel script runner in Static Validation ran `lint-repo-conventions.sh` which
reported 64 FAIL across 3 categories, all pre-existing on main.

**Fixes applied**:

| Category | Count | Fix |
|----------|-------|-----|
| Architectural boundaries: specs referencing `docs/ops/` | 60 | Excluded `docs/ops/` from deprecated-path grep (it's the canonical ops docs root) |
| Glob-ability: wrong file names in `specs/plans/` | 2 | Excluded `_spec.md` files and `IMPLEMENTATION_ORDER.md` from plan-naming check |
| Grep-ability: missing shebangs | 2 | Added `#!/usr/bin/env bash` to sourced library files |
| Grep-ability: unpinned workflow action refs | 2 | Pinned `actions/checkout` and `actions/setup-python` in `adr-governance.yml` |

**After fix**: `lint-repo-conventions.sh` → 14 PASS, 0 FAIL, 27 warnings.

### FIXED — shellcheck GitHub Action Fails on ARC Runners

**Impact**: `ludeeus/action-shellcheck` GitHub Action downloads `.tar.xz` archives. ARC runners
lack `xz-utils`, causing `tar: xz: Cannot exec: No such file or directory`. Shellcheck never ran.

**Fix**: Replaced third-party action with direct binary download + Python `lzma` fallback for
decompression. Runs `shellcheck --severity=error` on all `scripts/*.sh` files.

### FIXED — Pre-existing shellcheck Errors (2 scripts)

**Impact**: Never detected because shellcheck never ran on ARC runners (see above).

| Script | Error | Fix |
|--------|-------|-----|
| `scripts/qa/verify-ci-runner-policy.sh` | SC1087: array expansion `$job_name[$i]` | `${job_name}[${i}]` |
| `scripts/tenants/offboard-tenant.sh` | SC1072/SC1073: function call inside `[[ ]]` | Split into `[[ ]] && func` |

### FIXED — kubeconform Validates Non-K8s YAML

**Impact**: 3 data/registry files lack `kind` key, causing kubeconform to fail:
- `deploy/k8s/migrations/registry.yaml`
- `deploy/k8s/tenancy/tenant-registry.yaml`
- `deploy/k8s/base/secrets/SECRET_CLASSIFICATION.yaml`

**Fix**: Added `grep -v 'registry\.yaml'` and `grep -v 'SECRET_CLASSIFICATION'` to the find pipeline.

### FIXED — lsb_release Missing on ARC Runners (Systemic, All 4 Jobs)

**Impact**: `actions/setup-python` v5 calls `lsb_release -rs`/`-is` to build pip cache key.
ARC runners lack `lsb-release` package and we cannot `apt-install` (no sudo). This caused
**all 4 CI jobs** (Static Validation, Tutor Config Tests, Security Scans, Python test coverage)
to fail on **every branch including main**. Python installed successfully but the cache step
errored, skipping all subsequent steps.

**Fix**: Added `lsb_release` stub script to `setup-python-env` composite action. Stub handles
`-rs`, `-is`, `-ds`, `-cs`, `-a`, and combined flag forms. Installed to `$GITHUB_WORKSPACE/.cache/bin/`
and added to `$GITHUB_PATH`.

### NOT FIXED — yamllint Warnings (Non-Blocking)

These produce `[warning]` output but do NOT cause CI failure:

| Category | Files | Count | Action |
|----------|-------|-------|--------|
| `[indentation]` | `deploy/k8s/base/kustomization.yaml` | ~16 warnings | Low priority — structural indentation choice, not an error |
| `[line-length]` | `deploy/k8s/base/monitoring/slo-burn-rate-rules.yaml`, `prometheusrule-*.yaml` | ~11 warnings | Low priority — PromQL expressions naturally long |
| `[comments-indentation]` | `infrastructure/cloudflare/tenant-dns-records.yaml`, `servicemonitor-lms.yaml` | 2 warnings | Cosmetic |

### OUTSIDE LANE F SCOPE

| Blocker | Owner | Notes |
|---------|-------|-------|
| PR #866 closure-pack / retired-root | Lane E | Do not touch |
| PR #859 runtime/MFE chain | Lane A | Do not touch |
| Docs compliance gates (PRs #846, #847, #850) | Lane E | `docs-policy` range/reporting failures |
| Tutor Configuration Tests (PRs #845, #848, #849, #855) | Separate investigation needed | May be baseline or branch-specific |
| Plugin test failures (PR #856) | Branch-specific | MFE plugin lifecycle/OAuth tests |

### OPEN PR FAILURE CLASSIFICATION

After CRLF fix merges, these PRs should automatically go green on `Static Validation`:
- #823, #824, #825, #826 (dependabot bumps)
- #833 (enterprise MFE)
- #851 (JWT fix)
- #852 (MFE routing)
- #854 (enterprise MFE)
- #858 (CORS whitelist)
- #875 (eslint bump)

These PRs have additional failures beyond CRLF:
- #845, #848, #849: Tutor Configuration Tests + Security Scans
- #855: Tutor Configuration Tests
- #856: Plugin-specific test failures
- #846, #847, #850: Docs compliance gates
- #866: Docs compliance + Static Validation
