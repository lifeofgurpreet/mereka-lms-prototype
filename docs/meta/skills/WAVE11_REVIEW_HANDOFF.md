# Wave 11 Review Handoff
_Audience: reviewers and future agent-runtime implementors • Owner: Platform Team • Status: canonical_

## Review order

1. `docs/meta/skills/SKILL_RUNTIME_MODEL.yaml`
2. `docs/meta/skills/SKILL_TAXONOMY.yaml`
3. `generated/skills/skill-registry.json`
4. `generated/skills/command-registry.json`
5. `generated/skills/scenario-packs.json`
6. `generated/skills/read-first.md`
7. `generated/skills/skill-dependency-graph.json`
8. `tools/skills/verify_skill_runtime.py`
9. `scripts/qa/run-skill-runtime-gates.sh`

## What to verify

- every skill points only to canonical or compiled truthful surfaces
- every command entry points to a live script, workflow, or validator
- no scenario references a missing skill or command
- the read-first pack stays within 12 entries
- no default read-first path points into archive or transitional roots

## Human review questions

- Does each skill solve a real recurring task rather than repeat prose?
- Are any command entrypoints still ambiguous or duplicated?
- Are any high-risk skills missing reviewer or evidence classes?
- Does the read-first pack feel minimal enough for a new engineer or agent?

## Remaining risks

- cross-repo runtime convergence is still not machine-proven
- some external Wave 10 compiled assistant/front-door surfaces are not yet rebuilt on the new Wave 11 branches
- the current runtime is neutral and machine-consumable, but not yet packaged behind a stable vendor-facing ABI

## Reviewer start command

```bash
bash scripts/qa/run-skill-runtime-gates.sh
```
