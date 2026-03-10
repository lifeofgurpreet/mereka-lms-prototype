# Onboarding Documentation
_Audience: Developers + Agent Operators • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

## Scope
This is the canonical onboarding index for local setup and daily development workflow.

## Start here

- Need the fastest local bootstrap:
  - [`QUICK_START_LOCAL.md`](QUICK_START_LOCAL.md)
- Need the full canonical setup:
  - [`LOCAL_SETUP.md`](LOCAL_SETUP.md)
- Need the day-to-day command flow after setup:
  - [`WORKFLOW_LOCAL.md`](WORKFLOW_LOCAL.md)
- Working in a devcontainer instead of a host install:
  - [`DEVCONTAINER_GUIDE.md`](DEVCONTAINER_GUIDE.md)
- Coordinating with multiple contributors or agents:
  - [`MULTI_DEVELOPER_WORKFLOW.md`](MULTI_DEVELOPER_WORKFLOW.md)

## Canonical onboarding set

- [`README.md`](README.md)
- [`QUICK_START_LOCAL.md`](QUICK_START_LOCAL.md)
- [`LOCAL_SETUP.md`](LOCAL_SETUP.md)
- [`WORKFLOW_LOCAL.md`](WORKFLOW_LOCAL.md)
- [`DEVCONTAINER_GUIDE.md`](DEVCONTAINER_GUIDE.md)
- [`MULTI_DEVELOPER_WORKFLOW.md`](MULTI_DEVELOPER_WORKFLOW.md)
- [`REPOSITORY_GUIDE.md`](REPOSITORY_GUIDE.md)
- [`COURSE_IMPORT_GUIDE.md`](COURSE_IMPORT_GUIDE.md)

## Supporting guide

- [`AGENT_SETUP_CHECKLIST.md`](AGENT_SETUP_CHECKLIST.md) for agent-oriented preflight only

## Security note

Do not store local usernames, passwords, tokens, or copied service credentials in this directory.
Use the local setup flow to create a local-only admin password at bootstrap time, and use
[`../admin/SECRETS_MANAGEMENT_GUIDE.md`](../admin/SECRETS_MANAGEMENT_GUIDE.md) plus
[`../../ops/runbooks/SECRET_ROTATION_CHECKLIST.md`](../../ops/runbooks/SECRET_ROTATION_CHECKLIST.md)
if a credential is ever exposed.

## What this directory is not

Do not use this directory for:
- low-level operator procedures that belong in `docs/ops/**`
- living architecture rules that belong in `docs/concepts/architecture/**`
- active status or proof that belongs in `docs/status/**` or `docs/evidence/**`
