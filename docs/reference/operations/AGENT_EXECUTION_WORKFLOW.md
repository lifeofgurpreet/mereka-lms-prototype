# AGENT_EXECUTION_WORKFLOW
_Audience: Agents working this repo · Owner: Platform Team · Status: canonical_

This is the repo-local execution method for future agents.

## Layer-first workflow (mandatory)

1. Identify broken surface.
2. Identify owner layer.
3. Collect live proof before patching.
4. Patch canonical authority at the owning layer.
5. Validate rendered/build artifact.
6. Promote via release object.
7. Verify realization.
8. Rerun runtime proof.
9. Add regression guard and record proof artifact.

## Fast incident workflow (10-minute table)

| Field | Fill this before patching |
|---|---|
| Broken surface | env + tenant + domain + route |
| Owner layer | source / build-render / promotion / realization / runtime / proof |
| Source authority | exact file/contract that should define truth |
| Rendered/build artifact | exact artifact that ships (rendered Dockerfile/config/image) |
| Realized/live artifact | live deployment/configmap/image hash |
| Proof artifact | current runtime/browser evidence |
| Regression guard to add | verifier/test/check that prevents recurrence |

## Hard-won lessons (includes #1327 incident class)

1. **Plugin registration is not automatically shipping truth.**
   - A registration file can be correct while the real build path still ignores it.
2. **Patch the real generator/build path, not the nearest source file.**
   - In the account-MFE/build-path incident class, the shipping path was regex-based
     Dockerfile surgery; plugin-only edits were insufficient.
3. **Never patch generated artifacts alone.**
   - Patch generator/build path and add guard that inspects rendered artifact.
4. **Rendered/tracked artifact checks are required when incident evidence proved source-only checks insufficient.**
5. **Never rerun proof against a known-unpatched live bundle.**
6. **Never promote from a dirty worktree.**

## Mandatory operating rules

- Clean-worktree rule: no promotion from dirty tree.
- Release-object-first rule: no manual SHA/digest stitching.
- Generated-artifact rule: no generated-only patches.
- Proof rule: no proof rerun before patched bundle is live.
- Regression rule: each incident leaves one stronger guard.
- Docs separation rule:
  - `docs/status/active` = operational state
  - `docs/architecture` = stable system model
  - `docs/reference/contracts` = contracts
  - `AGENTS.md` + this doc = working method

## CI stall classification

- If CI is queued/hung past normal threshold, classify as infra block.
- Record block in status docs; do not keep re-running unrelated checks.
- Fix code defects only when failure is deterministic and localizable.

## Related

- [PLATFORM_AUTHORITY_MAP.md](../../architecture/PLATFORM_AUTHORITY_MAP.md)
- [PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md](../../architecture/PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md)
- [VERIFIER_CONTRACT_CATALOG.md](../contracts/VERIFIER_CONTRACT_CATALOG.md)
