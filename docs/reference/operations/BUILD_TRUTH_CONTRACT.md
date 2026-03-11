# Build Truth Contract

Parent policy:
- `docs/policies/operations/AGENT_EXECUTION_INVARIANTS.md`

## Prohibited Truth Models

The following are prohibited as primary build truth:

- required dependence on `latest`
- hidden or manual package rescue as normal operation
- ambiguous cache truth
- unlinked package assumptions
- unspecified image source

## Required Truth Inputs

Build claims MUST identify:

- source ref, tag, or digest
- package source and access contract
- whether cache was used
- which verifier or artifact proves the result

## Cache Discipline

Cache MAY accelerate builds, but cache MUST NOT be treated as authoritative truth.

If cache is used, the build record MUST state:

- cache source
- whether cache miss is acceptable
- whether rebuild without cache remains valid

## Package Access Contract

Any required package source MUST be durable and documented.

The build MUST NOT depend on:

- a maintainer manually republishing a package without repo record
- private package visibility that is not declared
- hidden runner login state

## Image Truth Evidence

When a build or image claim is made, the evidence SHOULD include:

- source SHA or tag
- image tag or digest
- package contract reference
- verifier or CI job reference

