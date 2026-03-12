# Release Evidence Bundle Contract

> Target release-truth model for post-stabilization convergence.

## Purpose

This contract defines what a future release/evidence bundle must contain so release truth is
durable, pinned, and reviewable. It does **not** implement release automation in this lane.

## Required release-truth rules

1. Image refs must be immutable.
2. Promotion truth must be pinned.
3. Evidence links must point to tracked or durable artifacts.
4. Convenience aliases such as `latest` are not authoritative.
5. In plain terms: latest are not authoritative.
6. Manual runtime mitigations must not appear inside the release bundle as if they were durable.
7. In plain terms: manual runtime mitigations must not appear inside the release bundle as if they were durable.

## Target bundle contents

Every future release evidence bundle should contain:

- app or chart ref
- image tags and digests
- environment or lane scope
- evidence links
- approval fields
- owner fields
- bundle timestamp

## Required semantics

### App or chart ref

The bundle must identify the exact app revision or chart revision being promoted.

### Image tags and digests

Image truth must be pinned to immutable refs. A floating alias may be included as a convenience
annotation, but never as the authoritative release identity.

### Evidence links

Evidence must be linkable and durable. Browser/runtime evidence should be clearly labeled as:

- canonical tracked proof
- external lane evidence
- local proof input

Only canonical tracked proof may close release questions.

### Approval and owner fields

The bundle must show who owns the release decision and who approved the evidence.

## What is not authoritative

- `latest`
- unpinned cache inputs
- manual shell history
- pod-local hot-patch notes
- operator memory
- admin merge status without semantic evidence

## Manual runtime mitigation rule

Manual runtime mitigation can appear only as an explicit non-durable note. It must never be
listed as if it were the release bundle's durable source of truth.
