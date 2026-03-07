---
id: ADR-028
title: Platform Sources of Truth and Control Planes
decision_status: accepted
decision_type: foundation
rollout_state: active
owner: platform-team
created: 2026-03-07
last_reviewed: 2026-03-07
review_due: 2026-06-30
supersedes: []
amends: ["ADR-003", "ADR-019", "ADR-021", "ADR-026", "ADR-027"]
depends_on: []
read_next: ["ADR-029", "ADR-030", "ADR-031", "ADR-032", "ADR-033"]
governs: ["repo-boundary", "gitops-contract", "image-source-of-truth", "runtime-control-plane"]
does_not_govern: ["feature-level business logic", "tenant-specific UX copy"]
related_oep: []
related_tutor_docs: ["https://docs.tutor.edly.io"]
related_specs: ["specs/repository-structure_spec.md"]
related_runbooks: ["docs/operations/REPO_BOUNDARIES.md", "docs/ops/runbooks/BUILD_PIPELINE_RUNBOOK.md"]
related_evidence: []
fitness_functions: ["scripts/qa/verify-repo-structure.sh", "scripts/qa/verify-gitops-image-overrides.sh --check-infra"]
expiry_date: null
removal_condition: null
---

# ADR-028: Platform Sources of Truth and Control Planes

## Decision

Mereka LMS MUST operate with explicit control planes:
- Code and docs control plane: this repository.
- GitOps runtime control plane: infrastructure repository overlays.
- Runtime state control plane: Kubernetes cluster objects rendered from GitOps.

## Scope

This ADR governs how truth is declared for image references, deployment manifests, and operational ownership boundaries.

## Non-goals

- Defining all domain-level business decisions.
- Replacing domain ADRs for auth, commerce, or tenancy behavior.

## Context

Current corpus contains contradictions across build/deploy ADRs that mix historical and active control planes. This causes drift and ambiguous execution paths.

## Decision details

- Deployment references MUST resolve through GitOps overlays and pinned refs.
- Production image references MUST resolve from GHCR.
- Tutor-generated artifacts MUST be treated as render outputs, not hand-edited truth.
- Repo boundary contracts MUST be encoded in docs and validated via QA scripts.

## Invariants

- Control-plane ownership MUST be singular per artifact class.
- Production runtime state MUST be reproducible from Git refs.
- Manual, out-of-band runtime edits MUST NOT become undocumented policy.

## Verification

- `scripts/qa/verify-repo-structure.sh`
- `scripts/qa/verify-gitops-image-overrides.sh --check-infra`
- `scripts/qa/verify-ci-cd-pipeline.sh --section gitops`

## Failure modes

- Image/source mismatch between repo and GitOps overlays.
- Runtime drift masked by stale docs.
- Duplicate ownership lanes for the same deployment artifact.

## Consequences

- Contradiction resolution across build/deploy ADRs is required.
- New deployment changes MUST name the control plane and owning artifact.

## Alternatives considered

- Keep mixed implied control planes.
  - Rejected: preserves ambiguity and recurrent drift.
