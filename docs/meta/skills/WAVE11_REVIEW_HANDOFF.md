# Wave 11 Review Handoff

Review Wave 11 in this order.

## 1. ABI and discovery

- `docs/meta/skills/AGENT_PACK_ABI.yaml`
- `docs/meta/skills/REPO_DISCOVERY_MODEL.yaml`
- `generated/skills/pack-registry.json`

Confirm:

- canonical packs are explicitly discoverable
- every registered pack has a schema
- no machine-local absolute paths appear in canonical pack discovery

## 2. Neutral skill layer

- `generated/skills/skill-registry.json`
- `generated/skills/evidence-sufficiency-map.json`
- `generated/skills/mixed-diff-arbitration.json`

Confirm:

- high-risk skills carry reviewer and evidence rules
- evidence classes resolve back to real skills
- mixed-diff rules reference real skill IDs and cover current categories

## 3. Runtime convergence

- `generated/skills/runtime-convergence-report.json`

Confirm:

- the report compares actual contracts, workflows, registries, and pack/runtime surfaces
- the remaining warning is explicit and intentional, not hidden drift

## 4. Enforcement

- `tools/skills/verify_agent_pack_schemas.py`
- `tools/skills/verify_skill_runtime.py`
- `tools/skills/verify_agent_pack_runtime.py`
- `scripts/qa/run-skill-runtime-gates.sh`
- `scripts/qa/run-agent-pack-runtime-gates.sh`
- `.github/workflows/docs-policy.yml`

Confirm:

- local and CI paths are aligned
- schema and runtime verification are both required
- the agent-pack runtime now participates in docs-policy CI

## 5. Start path

- `generated/skills/read-first.json`
- `generated/skills/read-first.md`
- `docs/meta/skills/WAVE11_CLOSEOUT.md`

Confirm:

- JSON is canonical
- Markdown is projection only
- default read-first remains at 12 entries or fewer

## Remaining risks

- assistant/front-door exports are not yet rebuilt on the fresh external Wave 11 branches
- Wave 10 generated agent packs are not present on this branch
- runtime convergence is still repo-truth convergence, not live runtime truth
