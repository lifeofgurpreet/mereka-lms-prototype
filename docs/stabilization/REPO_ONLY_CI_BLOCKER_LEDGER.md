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
