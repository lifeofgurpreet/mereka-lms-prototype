# Task Bundle: reviewer_handoff_or_policy_change

- Intent: Change reviewer handoff, skill policy, or runtime-facing control-plane docs.

## Read First
- `docs/meta/knowledge/REVIEW_HANDOFF_MODEL.md` priority `1`: Existing reviewer handoff runtime is primary.
- `docs/meta/contracts/REVIEW_HANDOFF_MODEL.md` priority `2`: Cross-repo reviewer path remains authoritative.

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
- `none`

## Related Runbooks
- `docs/ops/quickref/verification-scripts.md`
- `docs/ops/runbooks/BADGES_CREDENTIALS_RUNBOOK.md`
- `docs/ops/runbooks/DOMAIN_MANAGEMENT.md`
- `docs/ops/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md`
- `docs/ops/runbooks/FORUM_SERVICE_RUNBOOK.md`
- `docs/ops/runbooks/MOBILE_APPS_RUNBOOK.md`
- `docs/ops/runbooks/TENANT_PROVISIONING.md`
- `docs/ops/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md`

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
- `purchase-gateway` -> `infra_counterpart_required`; reviewers: architecture, platform, release, security

## Out Of Scope
- `specs/archive/**`

## Escalation Conditions
- review policy diverges from Wave 5 or Wave 6 source rules
