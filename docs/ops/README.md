# Operator Docs

`docs/ops/**` is the canonical operator-doc root.

Use this root when the question is operational:
- how to run, deploy, recover, or troubleshoot the platform
- how to execute a verified operator procedure
- which quick reference to use during an incident or release

Do not use these losing roots as live operator authority:
- `docs/operations/**`
- `docs/runbooks/**`
- `docs/archive/**`

## Subroots

- [`quickref/`](quickref/) for fast command and URL references
- [`runbooks/`](runbooks/) for step-by-step operational procedures
- [`monitoring/`](monitoring/) for observability references and ownership docs
- [`ci-cd/`](ci-cd/) for delivery and build operations
- [`security/`](security/) for operator-facing security procedures and policies

## Resolver

For the authority contract behind this root, read:
- [`../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`](../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
- [`../concepts/architecture/ARCHITECTURE_CHARTER.md`](../concepts/architecture/ARCHITECTURE_CHARTER.md)
