# Operator Docs

`docs/ops/**` is the canonical operator-doc root.

Use this root when the question is operational:
- how to run, deploy, recover, or troubleshoot the platform
- how to execute a verified operator procedure
- which quick reference to use during an incident or release

## Start here

Choose the smallest subroot that matches the task:

- Need commands, URLs, or checklists quickly:
  - start in [`quickref/README.md`](quickref/README.md)
- Need a step-by-step production or recovery procedure:
  - start in [`runbooks/README.md`](runbooks/README.md)
- Need observability ownership or monitoring reference:
  - start in [`monitoring/README.md`](monitoring/README.md)
- Need build or release operations:
  - start in [`ci-cd/README.md`](ci-cd/README.md)
- Need operator-facing auth, secret, or security posture:
  - start in [`security/README.md`](security/README.md)

Do not use these losing roots as live operator authority:
- `docs/operations/README.md` tombstone only
- `docs/runbooks/**`
- `docs/archive/**`

## Subroots

- [`quickref/`](quickref/) for fast command and URL references
- [`runbooks/`](runbooks/) for step-by-step operational procedures
- [`monitoring/`](monitoring/) for observability references and ownership docs
- [`ci-cd/`](ci-cd/) for delivery and build operations
- [`security/`](security/) for operator-facing security procedures and policies

## Key starting points

- [`EXECUTION_DOCTRINE.md`](EXECUTION_DOCTRINE.md) for the operational execution model behind this root
- [`quickref/README.md`](quickref/README.md) for fast command and environment references
- [`runbooks/README.md`](runbooks/README.md) for recovery and rollout procedures
- [`monitoring/README.md`](monitoring/README.md) for observability ownership and runtime telemetry
- [`ci-cd/README.md`](ci-cd/README.md) for build and delivery operations
- [`security/README.md`](security/README.md) for auth, secret, and operator security posture

## What this root is not

Do not use this root for:
- living architecture rules that belong in `docs/concepts/architecture/**`,
- active proof that belongs in `docs/evidence/**`,
- active reporting that belongs in `docs/status/**`,
- or contributor guidance that belongs in `docs/guides/**`.

## Resolver

For the authority contract behind this root, read:
- [`../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`](../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
- [`../concepts/architecture/ARCHITECTURE_CHARTER.md`](../concepts/architecture/ARCHITECTURE_CHARTER.md)
