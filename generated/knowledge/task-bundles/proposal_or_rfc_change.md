# Task Bundle: proposal_or_rfc_change

- Intent: Change proposal-lane, RFC, or future-shape design material.

## Read First
- `docs/meta/docs-program/WAVE4_CLOSEOUT.md` priority `1`: Keeps proposal work aligned with canonical topology.
- `specs/proposals/README.md` priority `2`: Governs proposal-lane meaning and boundaries.

## Commands
- `bash scripts/qa/run-knowledge-runtime-gates.sh`
- `bash scripts/qa/run-cross-repo-contract-gates.sh`
- `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`
- `python3 tools/specs/verify_spec_frontmatter.py --repo-root .`
- `python3 tools/specs/verify_spec_taxonomy.py --repo-root .`
- `python3 tools/specs/verify_spec_paths.py --repo-root .`
- `python3 tools/specs/verify_docs_specs_boundary.py --repo-root .`
- `python3 tools/knowledge/resolve_task_context.py --repo-root . --range origin/main...HEAD --output generated/knowledge/task-context-report.json`
- `python3 tools/knowledge/resolve_task_context.py --check --repo-root . --range origin/main...HEAD --output generated/knowledge/task-context-report.json`
- `python3 tools/knowledge/build_task_bundle.py --repo-root . --range origin/main...HEAD --all --output-dir generated/knowledge/task-bundles`
- `python3 tools/knowledge/build_task_bundle.py --check --repo-root . --range origin/main...HEAD --all --output-dir generated/knowledge/task-bundles`
- `python3 tools/knowledge/build_skill_index.py --repo-root .`
- `python3 tools/knowledge/build_skill_index.py --check --repo-root .`
- `python3 tools/knowledge/verify_task_runtime.py --repo-root . --range origin/main...HEAD`
- `bash scripts/qa/run-task-runtime-gates.sh`

## Related Contracts
- `none`

## Related Specs
- `specs/plans/external-registration-hubspot_plan.md`
- `specs/plans/external-registration-hubspot_testplan.md`
- `specs/plans/mobile-apps-enterprise_plan.md`
- `specs/plans/mobile-apps-enterprise_testplan.md`
- `specs/plans/proctoring-integration_plan.md`
- `specs/plans/proctoring-integration_testplan.md`
- `specs/proposals/external-registration-hubspot_spec.md`
- `specs/proposals/mobile-apps-enterprise_spec.md`
- `specs/proposals/mobile-apps-secrets-management_spec.md`
- `specs/proposals/proctoring-integration_spec.md`

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
p
l
a
n
_
r
e
f
r
e
s
h
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
- none

## Out Of Scope
- `specs/archive/**`
- `docs/archive/**`

## Escalation Conditions
- root normative specs are touched in the same packet
