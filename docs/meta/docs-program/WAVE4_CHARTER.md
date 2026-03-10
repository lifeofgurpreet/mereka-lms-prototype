# Wave 4 Charter

## Objective

Wave 4 turns the docs/specs twin-root system into a unified knowledge control plane without collapsing the filesystem layout.

## Operating rules

- `docs/` remains the human-facing lane for operational, conceptual, policy, evidence, and review material.
- `specs/` remains the normative contract lane for root specs, proposals, plans, and testplans.
- Generated surfaces must make lane ownership obvious instead of forcing reviewers to infer it from path shape.
- Compatibility wrappers remain compatibility-only surfaces and must never become a second source of truth.

## Shared vocabulary

- `root`: the top-level knowledge root, currently `docs` or `specs`
- `lane`: the semantic lane within a root, such as `normative`, `proposal`, `plan`, `testplan`, `concept`, `runbook`, `evidence`, `archive`, `review`, `generated`, or `index`
- `classification`: the reviewer-facing interpretation of a file, such as `canonical`, `supporting`, `generated`, `compatibility`, or `archival`
- `status`: the lifecycle state already carried by the owning lane

## Wave 4 phases

1. Shared schema and helpers
2. Unified generated surfaces
3. Wrapper retirement program
4. Merge-time governance

## Success criteria

- docs and specs can be classified from one shared model
- one combined reviewer-facing surface can explain what is true, proposed, planned, generated, or compatibility-only
- wrapper retirement becomes explicit and measurable
- merge-time governance prevents split truth from reappearing
