# Wave 8 Agent Review Handoff

## Reviewer Path

Review Wave 8 in this order:

1. `generated/knowledge/agent-entrypoints.json`
2. `generated/knowledge/agent-task-bundles/`
3. `generated/knowledge/agent-readiness-report.json`
4. `docs/meta/knowledge/AGENT_CONSUMPTION_MODEL.md`
5. `docs/meta/knowledge/AGENT_TASK_TAXONOMY.yaml`
6. `tools/knowledge/build_agent_entrypoints.py`
7. `tools/knowledge/build_agent_task_bundles.py`
8. `tools/knowledge/build_agent_readiness_report.py`
9. `tools/knowledge/verify_agent_consumption_runtime.py`
10. `scripts/qa/run-agent-readiness-gates.sh`

## What Humans Should Check

Humans should verify:

- every domain entrypoint starts from canonical roots and not archive
- every task bundle names the right normative, proposal, plan, generated, and historical surfaces
- reviewer and evidence obligations match Wave 5 and Wave 6 expectations
- validation commands are executable and minimal
- cross-repo fallout is visible where relevant
- the readiness report stays green and does not hide unresolved domains or tasks

## What Agents Should Consume First

Future skills and coding agents should start from:

- `generated/knowledge/agent-entrypoints.json` for domain routing
- `generated/knowledge/agent-task-bundles/*.md` for task execution
- `generated/knowledge/agent-readiness-report.json` for safety and gap checks

## What Still Requires Human Judgment

Wave 8 improves determinism, but humans still decide:

- mixed high-risk diffs spanning multiple truth planes
- cross-repo changes where Wave 6 still marks exact infra paths unknown
- release-impact decisions that exceed repo-local truth
- whether evidence is sufficient for a real promotion decision
