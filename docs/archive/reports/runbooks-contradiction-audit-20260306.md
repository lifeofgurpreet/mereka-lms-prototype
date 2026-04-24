# Runbooks Contradiction Audit 2026-03-06
_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## Cluster
- `runbooks`

## Canonical Authority
- Canonical runbook tree: `docs/ops/runbooks/**`

## Contradictions Found
1. Dual runbook authority trees
- Finding: runbook content was split between legacy and canonical locations.
- Resolution: runbook authority consolidated to `docs/ops/runbooks/**`; legacy duplicates converted to compatibility stubs/non-canonical states.

2. Command/procedure drift risk across duplicate runbooks
- Finding: duplicate runbook files risked divergence.
- Resolution: canonical designation fixed to ops tree and legacy path references updated in verification scripts/workflows.

3. Discoverability split between legacy and canonical indexes
- Finding: users/agents could land on legacy routes first.
- Resolution: primary index and contributing guidance now enforce canonical-first navigation; transitional-path retirement timeline published.

## Waivers
- Transitional runbook stubs remain where inbound compatibility is still needed.

## Exit Decision
- Runbook contradiction requirement for Phase 3 is satisfied.
