# Wave Operations Root Reset Tracker

Status: in_progress
Owner: codex
Branch: docs/operations-root-reset
Worktree: /home/gurpreet/projects/k8s/mereka-lms-wt-operations-root-reset
Started from: 4225380d7b4af95e9a41e8a7a5e8ab310c1d61e5

## Objective

Determine whether `docs/operations/**` can be retired as an active root, partially collapsed, or must be split into narrower packets because it still contains live operational truth.

## Initial Findings

- `docs/operations/README.md` is already a superseded pointer to `docs/ops/quickref/README.md`.
- The root still contains approximately 199 markdown files plus evidence and postmortem subdirectories.
- There are 98 filename collisions between `docs/operations/**` and `docs/ops/**`.
- Unlike the already-retired architecture root, this root is not a wrapper-only graveyard. It appears to mix:
  - runbooks and troubleshooting material
  - operational policy and readiness docs
  - evidence/log bundles
  - historical migration and rollout notes
  - duplicate quickrefs and access references

## Working Classification Hypothesis

### Likely living operational content

- deployment, release, troubleshooting, on-call, and maintenance runbooks
- incident and recovery procedures
- environment/access quick references if they are still active and not already superseded elsewhere

### Likely movable content

- operational standards and policy docs that belong under `docs/guides/standards/**`
- docs-program governance notes that belong under `docs/meta/docs-program/**`
- reference-style environment/domain material that belongs under `docs/reference/**`

### Likely archival or deletable content

- rollout notes, follow-ups, one-off fixes, and dated migration briefs
- evidence bundles already mirrored under `docs/evidence/**` or archive/status surfaces
- duplicate quickstarts that now exist under `docs/ops/**`

## Packet A Goal

- classify the root before deleting anything
- identify whether the next safe packet is:
  - a true root retirement
  - an evidence/archive extraction
  - or a move-to-`docs/ops/**` consolidation

## Open Risk

- Blindly deleting `docs/operations/**` would risk removing active operational truth, because this root is much denser and more live-looking than the already-retired architecture root.

## Duplicate-Surface Signal

Confirmed direct duplicate-name overlaps already exist with canonical `docs/ops/**` homes, including:

- `docs/operations/CI_CD_RUNNERS.md` -> `docs/ops/ci-cd/CI_CD_RUNNERS.md`
- `docs/operations/CI_OPTIMIZATION_TRACKER.md` -> `docs/ops/ci-cd/CI_OPTIMIZATION_TRACKER.md`
- `docs/operations/BUILD_CACHE_PIPELINE_RUNBOOK.md` -> `docs/ops/runbooks/BUILD_CACHE_PIPELINE_RUNBOOK.md`
- `docs/operations/DOMAIN_MANAGEMENT.md` -> `docs/ops/runbooks/DOMAIN_MANAGEMENT.md`
- `docs/operations/ENTERPRISE_SSO_GUIDE.md` -> `docs/ops/runbooks/ENTERPRISE_SSO_GUIDE.md`
- `docs/operations/TENANT_PROVISIONING.md` -> `docs/ops/runbooks/TENANT_PROVISIONING.md`
- `docs/operations/OBSERVABILITY_ROADMAP_MEREKA_LMS.md` -> `docs/ops/monitoring/OBSERVABILITY_ROADMAP_MEREKA_LMS.md`
- `docs/operations/SECRET_SCANNING.md` -> `docs/ops/security/SECRET_SCANNING.md`

This strongly suggests the next safe cleanup packet is:

1. convert or remove obvious duplicate `docs/operations/*.md` surfaces that already have canonical `docs/ops/**` counterparts
2. leave evidence, postmortems, and unique operational policy docs for later packets

## Packet B Scope

Narrow duplicate-collapse packet limited to obvious superseded wrappers whose canonical homes are already live:

- `docs/operations/CI_CD_RUNNERS.md` -> `docs/ops/ci-cd/CI_CD_RUNNERS.md`
- `docs/operations/CI_OPTIMIZATION_TRACKER.md` -> `docs/status/active/CI_OPTIMIZATION_TRACKER.md`
- `docs/operations/CI_PIPELINE_COST_OPTIMIZATION.md` -> `reports/2026/learnings/CI_PIPELINE_COST_OPTIMIZATION.md`
- `docs/operations/COST_OPTIMIZATION.md` -> `docs/ops/ci-cd/COST_OPTIMIZATION.md`
- `docs/operations/DOMAIN_MANAGEMENT.md` -> `docs/ops/runbooks/DOMAIN_MANAGEMENT.md`
- `docs/operations/ENTERPRISE_SSO_GUIDE.md` -> `docs/ops/runbooks/ENTERPRISE_SSO_GUIDE.md`
- `docs/operations/TENANT_PROVISIONING.md` -> `docs/ops/runbooks/TENANT_PROVISIONING.md`
- `docs/operations/SECRET_SCANNING.md` -> `docs/reference/operations/SECRET_SCANNING.md`

Packet B rule:

- rewrite live active references first
- then delete the superseded wrappers
- do not touch evidence/postmortem trees yet

## Packet B Result

Completed narrow duplicate collapse for eight obvious wrapper files:

- deleted `docs/operations/CI_CD_RUNNERS.md`
- deleted `docs/operations/CI_OPTIMIZATION_TRACKER.md`
- deleted `docs/operations/CI_PIPELINE_COST_OPTIMIZATION.md`
- deleted `docs/operations/COST_OPTIMIZATION.md`
- deleted `docs/operations/DOMAIN_MANAGEMENT.md`
- deleted `docs/operations/ENTERPRISE_SSO_GUIDE.md`
- deleted `docs/operations/TENANT_PROVISIONING.md`
- deleted `docs/operations/SECRET_SCANNING.md`

Live references were rewritten to:

- `docs/ops/ci-cd/CI_CD_RUNNERS.md`
- `docs/status/active/CI_OPTIMIZATION_TRACKER.md`
- `reports/2026/learnings/CI_PIPELINE_COST_OPTIMIZATION.md`
- `docs/ops/ci-cd/COST_OPTIMIZATION.md`
- `docs/ops/runbooks/DOMAIN_MANAGEMENT.md`
- `docs/ops/runbooks/ENTERPRISE_SSO_GUIDE.md`
- `docs/ops/runbooks/TENANT_PROVISIONING.md`
- `docs/reference/operations/SECRET_SCANNING.md`

Residue intentionally left for later packets:

- `docs/operations/**` still contains substantial non-wrapper operational material
- evidence and postmortem trees are untouched
- root-collapse maps may still mention deleted legacy paths as migration history

## Packet C Scope

Second duplicate-collapse packet limited to additional superseded wrappers with no active repo consumers outside migration metadata:

- `docs/operations/A11Y_CONTRAST_FOCUS_GATE.md` -> `docs/ops/runbooks/A11Y_CONTRAST_FOCUS_GATE.md`
- `docs/operations/A11Y_REGRESSION_LANE.md` -> `docs/ops/runbooks/A11Y_REGRESSION_LANE.md`
- `docs/operations/A11Y_TENANT_BRANDING_GATE.md` -> `docs/ops/runbooks/A11Y_TENANT_BRANDING_GATE.md`
- `docs/operations/ADMIN_CONSOLE_SETUP.md` -> `docs/reference/operations/ADMIN_CONSOLE_SETUP.md`
- `docs/operations/ALERT_TUNING_SOP.md` -> `docs/ops/runbooks/ALERT_TUNING_SOP.md`
- `docs/operations/ALTERNATIVE_DOMAIN_BRANDING_FIX.md` -> `docs/ops/runbooks/ALTERNATIVE_DOMAIN_BRANDING_FIX.md`
- `docs/operations/ARGOCD_DRIFT.md` -> `docs/ops/runbooks/ARGOCD_DRIFT.md`
- `docs/operations/ARGOCD_HEALTH_TROUBLESHOOTING.md` -> `docs/ops/runbooks/ARGOCD_HEALTH_TROUBLESHOOTING.md`

Packet C rule:

- delete the wrapper when no live active refs remain
- keep collapse-map metadata untouched as migration history
- continue leaving evidence/postmortem trees alone
