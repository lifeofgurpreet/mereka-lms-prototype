# Runner Capability Contract

Parent policy:
- `docs/policies/operations/AGENT_EXECUTION_INVARIANTS.md`

## Required Capabilities

Repo-side automation that claims durable truth MUST make runner assumptions explicit.

Minimum expectations:

- `git`
- `bash`
- `python3`
- repo-pinned verifiers and scripts

Optional capabilities that MUST be checked before use:

- `docker`
- `docker buildx`
- GitHub CLI auth
- package registry access
- cloud CLIs

## Privilege Model

Jobs and lanes MUST state whether they require:

- read-only repo access
- repo write access
- GitHub API auth
- package registry auth
- docker daemon access

They MUST NOT assume:

- privileged docker
- buildx availability
- registry login
- hidden package mirrors
- secret-backed access not declared in the contract

## Package Manager Expectations

Any job that needs package access MUST document:

- package host
- auth expectation
- fallback behavior
- failure mode when access is absent

## Capability Drift

Capability drift MUST surface as:

- an explicit verifier failure
- a clear message naming the missing tool or privilege
- a blocker artifact, not silent fallback behavior

## What Jobs Must Not Assume

Jobs MUST NOT assume:

- `latest` image or package availability
- prewarmed caches
- hidden credentials
- write access to repos other than the declared repo
- extra tools not named in the lane or CI contract

