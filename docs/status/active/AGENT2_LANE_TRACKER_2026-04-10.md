# Agent 2 Lane Tracker

_Owner: Agent 2 | Last verified: 2026-04-10T00:00:00Z | Status: active_

## Lane: Promotion Trust, Release Identity, GitOps Realization, CI/Verifier Discipline

## Session Progress (2026-04-09/10)

### PRs Merged (7)

| PR | What | Category |
|----|------|----------|
| #1484 | Dispatch payload contract fix + action replacement | WS4 |
| #1489 | Schema version drift fix (1.0 → release-object/v1) | Duplicate writer |
| #1493 | Ops-streak consumer (B-027) | Guardrail |
| #1494 | MFE SCSS COPY fix | Build pipeline |
| #1499 | Git HTTPS for Docker builds | Build pipeline |
| #1502 | DinD DNS fallback | Build pipeline |
| #1462 | Semantic verification (merged by others) | CI/verifier |

### WS4 Dispatch Chain Status

| Step | Proved? | How |
|------|---------|-----|
| Dispatch auth | YES | 2 canary dispatches accepted (HTTP 204) |
| Payload contract | YES | Canary v2 passed full validation |
| Infra reception | YES | First `repository_dispatch` ever received |
| Promotion PR creation | YES | bbi-infrastructure PR #2601 |
| Organic push-build dispatch | NO | Runner instability blocks MFE builds |
| Argo realization | NO | Pending PR merge |
| Runtime consumption | NO | Agent 1's lane |

### Hardening Claims Verified

| # | Claim | Status |
|---|-------|--------|
| 1 | Release object for prod promotion | VERIFIED TRUE |
| 2 | Truth ledger hardened | VERIFIED TRUE |
| 3 | Docs-only required checks | VERIFIED TRUE |
| 4 | Realized image identity script | EXISTS ON MAIN (more complete version) |
| 5 | Generated-surface regen hooks | VERIFIED TRUE |
| 6 | Vendored sync automation | VERIFIED TRUE |
| 7 | No stranded repairs | VERIFIED TRUE |
| 8 | Ops reliability streak | Was dead telemetry → NOW HAS CONSUMER (#1493) |
| 9 | Tracker accuracy | VERIFIED TRUE |
| 10 | CI on main trustworthy | VERIFIED TRUE |

### Duplicate Writers Identified

| Writer | Canonical | Shadow | Status |
|--------|-----------|--------|--------|
| Release-object schema version | `generate_release_object.py` | `config/release-object-schema.yaml` | FIXED (PR #1489) |
| Dispatch payload contract | `promote-dev-image.yml` receiver | `build-tutor-images.yml` sender | ALIGNED (PR #1484) |
| Lane normalize | PCP contract | `scripts/lib/lane-normalize.sh` | NOT YET MIGRATED |
| Image tag writers | Automated dispatch | Manual GitOps bridge | RETIRE MANUAL after chain proved |
| CI inventory | `script-registry.yaml` | `.github/ci-scripts-static.txt` | CONTROLLED (freshness gate active) |

### Ulmo Upgrade Gap (Pre-Analysis)

- 29 total customizations
- 23 safe (plugin API / config only)
- 6 fragile (template patches / shell-script surgery)
- Worst offender: `webpack-memory.sh` (15+ hardcoded string replacements)
- ADR-021 compliant overall

## Next Steps (Per Reviewer Guidance)

1. Get one clean organic push build through MFE
2. Observe organic dispatch from that build
3. Merge bbi-infrastructure promotion PR → verify Argo realization
4. Hand release-ID to Agent 1 for runtime consumption proof
5. Move dispatch contract + release-object schema authority to PCP
6. Retire manual GitOps bridge once automated chain is proved
7. Produce closure report

## Session 2 Corrections (2026-04-10)

### Bugs found and fixed in Session 1 work

| Bug | Impact | Fix |
|-----|--------|-----|
| `build-mfe-image.sh` added `--opt max-parallelism=N` to `docker buildx build` — flag does not exist | Would cause "unknown flag: --opt" on every MFE build | Removed `BUILDX_EXTRA_ARGS` block entirely (502baf534) |
| `BUILDKIT_MAX_PARALLELISM` env var is not respected by `docker-container` driver buildx | OOM cap was ineffective | Added `buildkitd-flags: '--oci-worker-max-parallelism 4'` to `setup-buildx-action` step (a38cc718e) |

### Session 3 additions (context continuation)

| Fix | Impact | Commit |
|-----|--------|--------|
| Release-bundle schema aligned to PCP v1.1 | Prevents consumer rejection when strict validation added | 64f009dad |
| Verifier accepts schema_version 1.0.0 or 1.1 | Prevents verifier from rejecting valid v1.1 bundles | d8e08a635 |

### Session 4 additions (guard fix)

| Fix | Impact | Commit |
|-----|--------|--------|
| Account MFE guard v1→v2 in plugin | Guard was checking minified dist for variable that webpack renames — always failing | 635e388ff |
| Account MFE guard v1→v2 in mfe-build/Dockerfile snapshot | Keeps QA reference file consistent with generated Dockerfile | 798e2547a |

**Root cause of build 24219065443 failure** (after 42 min): Guard v1 searched compiled `.js`/`.map` for `const socialLinks = ...`. Webpack production builds minify variable names → `socialLinks` becomes a short identifier → `required_found` was always `False` → `SystemExit` every build. Fixed by checking SOURCE file (pre-minification) for the fix, and dist only for the OLD forbidden pattern.

### PR #1507 additions (cumulative)
- 5 artifact docs files (tracker, ledger, chain map, registers)
- `--opt` bug fix in `build-mfe-image.sh`
- Proper `buildkitd-flags` cap (real OOM fix)
- Release-bundle schema version/family/contract aligned to PCP v1.1
- Verifier updated to accept 1.0.0 or 1.1
- **Account MFE guard fixed v1→v2** (root cause of 42-min build failure)

## Current Status (Session 4 — end)

Push build 24219065443 FAILED at "Build MFE image" after 42 min — account guard v1 always exits 1.
PR #1507 CI running — Dependency Review: SUCCESS, IaC Security Scan: SUCCESS, CodeQL in progress.

### Session 4 complete fix (3-layer):
1. `mfe-dockerfile-pre-npm-build-account` plugin hook — patches source BEFORE webpack
2. Guard v2 — checks source (not minified dist) — passes after patch runs
3. mfe-build/Dockerfile snapshot + tests aligned to v2

### What happens next (after PR #1507 merges):
1. Next push build on main runs with v2 guard + patch hook
2. Account MFE builds successfully → release-bundle generated
3. Dispatch fires to bbi-infrastructure
4. promote-dev-image.yml creates PR with fresh MFE+OpenEdX digests
5. Merge infra PR → ArgoCD realization
6. WS4 organically proved end-to-end
