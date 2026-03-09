# Spec System Charter

`specs/` is the first-class normative root for intended system behavior.

## Use this root for

- normative behavior contracts
- system, domain, integration, and security specifications
- generated verification surfaces derived from specs
- proposal-stage spec candidates under `specs/proposals/**`
- execution and rollout planning tied to specs under `specs/plans/**`

## Do not use this root for

- architecture law that belongs in `docs/concepts/architecture/**`
- operator procedures that belong in `docs/ops/**`
- evidence or status reporting that belongs in `docs/evidence/**` and `docs/status/**`
- generated documentation that belongs in `docs/**`

## Spec truth model

- specs define expected behavior
- tests and QA verify against specs
- generated spec surfaces must not become an independent truth plane
