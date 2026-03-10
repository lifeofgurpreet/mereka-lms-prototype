# Task Bundle: evidence_or_status_change

- Intent: Change evidence, status, readiness, or proof surfaces without altering the governing contract.

## Read First
- `docs/meta/knowledge/CHANGE_RUNTIME_CLOSEOUT.md` priority `1`: Wave 5 defines evidence and review runtime semantics.
- `docs/meta/contracts/CHANGE_RUNTIME_CLOSEOUT.md` priority `2`: Wave 6 defines release and contract evidence semantics.

## Commands
- `bash scripts/qa/run-knowledge-runtime-gates.sh`
- `bash scripts/qa/run-cross-repo-contract-gates.sh`
- `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`
- `python3 tools/knowledge/resolve_task_context.py --repo-root . --range origin/main...HEAD --output generated/knowledge/task-context-report.json`
- `python3 tools/knowledge/resolve_task_context.py --check --repo-root . --range origin/main...HEAD --output generated/knowledge/task-context-report.json`
- `python3 tools/knowledge/build_task_bundle.py --repo-root . --range origin/main...HEAD --all --output-dir generated/knowledge/task-bundles`
- `python3 tools/knowledge/build_task_bundle.py --check --repo-root . --range origin/main...HEAD --all --output-dir generated/knowledge/task-bundles`
- `python3 tools/knowledge/build_skill_index.py --repo-root .`
- `python3 tools/knowledge/build_skill_index.py --check --repo-root .`
- `python3 tools/knowledge/verify_task_runtime.py --repo-root . --range origin/main...HEAD`
- `bash scripts/qa/run-task-runtime-gates.sh`

## Related Contracts
- `docs/meta/contracts/CHANGE_RUNTIME_CLOSEOUT.md`
- `docs/meta/contracts/CONTRACT_RUNTIME_MODEL.md`
- `docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml`
- `docs/meta/contracts/ENVIRONMENT_SURFACES.yaml`
- `docs/meta/contracts/INFRA_CROSSWALK.md`
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml`
- `docs/meta/contracts/REVIEW_HANDOFF_MODEL.md`
- `docs/meta/contracts/WAVE6_EXECUTION_TRACKER.md`

## Related Specs
- `specs/_generated/testmaps/README.md`
- `specs/_generated/testmaps/mobile-apps-enterprise_spec.testmap.yml`
- `specs/_generated/testmaps/mobile-apps-secrets-management_spec.testmap.yml`
- `specs/_generated/testmaps/paragon-design-tokens-migration_spec.testmap.yml`
- `specs/testmaps/RETIREMENT_PLAN.md`
- `specs/testmaps/mobile-apps-enterprise_spec.testmap.yml`
- `specs/testmaps/mobile-apps-secrets-management_spec.testmap.yml`

## Related Runbooks
- `none`

## Reviewers And Evidence
-
 
r
e
v
i
e
w
e
r
s
:
 
a
r
c
h
i
t
e
c
t
u
r
e
,
 
d
o
c
s
,
 
p
l
a
t
f
o
r
m
-
 
e
v
i
d
e
n
c
e
:
 
r
e
q
u
i
r
e
_
a
d
r
_
u
p
d
a
t
e
,
 
r
e
q
u
i
r
e
_
e
v
i
d
e
n
c
e
_
p
a
c
k
,
 
r
e
q
u
i
r
e
_
r
u
n
b
o
o
k
_
u
p
d
a
t
e
,
 
r
e
q
u
i
r
e
_
s
t
a
t
u
s
_
u
p
d
a
t
e

## Cross-Repo Dependencies
- `openedx` -> `manual_review_required`; reviewers: architecture, platform, release

## Out Of Scope
- `specs/archive/**`

## Escalation Conditions
- evidence claims move without corresponding runtime or contract updates
