# Docs / Specs Boundary

`docs/` and `specs/` are sibling first-class roots.

## Docs own

- architecture standards
- ADRs and RFCs
- operator docs
- guides
- reference
- policies
- evidence
- status

## Specs own

- normative intended behavior
- system, domain, integration, and security contracts
- generated verification artifacts
- spec proposals
- spec implementation plans

## Boundary rule

- docs explain and govern
- specs define expected behavior
- tests and QA verify against specs
- generated surfaces must not create a second truth plane
