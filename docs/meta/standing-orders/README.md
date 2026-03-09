# Standing Orders
_Audience: Maintainers and agents • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory contains active standing orders for recurring contributor and agent workflows. Start here when you need a durable operating instruction for a recurring lane, not a one-off task note or an ADR.

## Start here

| If you need to... | Read this first |
|---|---|
| Check the GitOps/operator lane expectations | `GITOPS_AGENT.md` |
| Check governance-review expectations | `GOVERNANCE_AGENT.md` |
| Check LMS/platform lane expectations | `LMS_AGENT.md` |

## Use this root when

| Situation | Use this root? | Why |
|---|---|---|
| You need recurring instructions for a lane or role | Yes | Standing orders are stable operating expectations for repeat work |
| You need a one-off migration or handoff note | No | That belongs in `docs/meta/docs-program/**` or `docs/status/**` |
| You need runtime operator steps | No | Use `docs/ops/**` for runbooks and procedures |
| You need architecture law or source-of-truth routing | No | Use `docs/concepts/architecture/**` |

## Use this directory for

- lane-specific standing orders
- recurring governance handoff expectations
- durable contributor operating instructions that are not ADRs or runtime runbooks

## What this root is not

- Not a substitute for the architecture resolver or charter.
- Not the place for active docs program tracking. Use `docs/meta/docs-program/**`.
- Not the place for runtime operational runbooks. Use `docs/ops/**`.

## Review standard

- A standing order here should stay durable across multiple sessions, not narrate a single delivery wave.
- It should assign expectations, ownership, and boundaries clearly enough that an agent can act without guessing.
- If the content starts to read like a checklist for one incident or one PR, it belongs elsewhere.
