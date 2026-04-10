# CI / Verifier False-Green Register

_Owner: Agent 2 | Last verified: 2026-04-10T00:00:00Z | Status: active_

## Known False-Green Risks

| # | Risk | Severity | Status | Mitigation |
|---|------|----------|--------|------------|
| 1 | Grep appeasement in verifiers — checking string patterns instead of semantics | MEDIUM | **FIXED** (PR #1462 merged) | Semantic verification replaces grep patterns |
| 2 | Docs-only PRs not reporting required checks | HIGH | **FIXED** (PR #1474 removed paths-ignore, skip-job pattern active) | All 7 required checks report on every PR |
| 3 | Generated surface staleness — `.github/ci-scripts-static.txt` can drift from `script-registry.yaml` | MEDIUM | **CONTROLLED** (freshness gate in CI precheck, auto-regen hooks PR #1465) | `--check` flag validates; pre-commit hooks regenerate |
| 4 | Release-object schema version mismatch (config says "1.0", code emits "release-object/v1") | LOW | **FIXED** (PR #1489 aligned to "release-object/v1") | Single source of truth in generator code |
| 5 | Ops reliability streak emitted but not consumed | LOW | **FIXED** (PR #1493 added consumer script) | Script reads artifact, reports streak status |
| 6 | verify-realized-image-identity.sh exists but may not be invoked in all proof flows | MEDIUM | EXISTS ON MAIN | Script implemented; invoked by runtime-routing.sh when file exists + namespace set |
| 7 | Verification sprawl budget can silently block new scripts if not bumped | LOW | KNOWN | Budget at 622; bump when adding new verify scripts |

## False-Green Risks That Remain Open

| # | Risk | Why Not Fixed Yet | Impact |
|---|------|-------------------|--------|
| 1 | Manual GitOps bridge can race with automated dispatch | Automated path not yet organically proven | Both paths can write image tags; no atomic promotion gate |
| 2 | Proof gate contract (`config/proof-gate-contract.yaml`) not machine-enforced | Declarative only; no workflow step references it by ID | Gates exist in docs but not checked at CI time |
| 3 | `kustomize-structure` verifier flaky on ARC runners | Passes locally, fails intermittently in CI | Rerun clears it; root cause likely runner environment |

## CI Trust Assessment

- `ci.yml` on main: **3 consecutive successes** (as of 2026-04-09)
- `build-tutor-images.yml` on main: **blocked by runner instability**, not code issues
- All 7 required status checks report correctly on all PR types
- Generated-surface freshness gates active and working (caught real drift during this session)
