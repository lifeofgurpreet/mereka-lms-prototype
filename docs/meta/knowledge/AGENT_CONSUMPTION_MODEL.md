# Wave 8 Agent Consumption Model

## Purpose

Wave 8 turns the existing documentation, specification, review, and contract runtimes
into deterministic agent-consumption surfaces.

The goal is not new governance theory.
The goal is to let a coding agent answer, from repo artifacts alone:

- what to read first
- what is authoritative
- what reviewers and evidence are required
- what commands must run
- what cross-repo fallout must be inspected

## What Wave 8 Consumes

Wave 8 does not replace prior runtimes.

It consumes:

1. Wave 4 canonical docs/spec topology and generated navigation surfaces
2. Wave 5 change, review, evidence, and truth-impact runtime surfaces
3. Wave 6 cross-repo manifest, deployment impact, and release-obligation runtime surfaces
4. repo-local canonical docs, specs, contracts, and runbooks

## What Wave 8 Produces

Wave 8 produces two deterministic read models:

1. Domain entrypoints
   - machine-readable starting surfaces for major domains
   - authoritative roots
   - read-first surfaces
   - reviewers, evidence, validators, and cross-repo surfaces

2. Task bundles
   - read-first operational bundles for common agent tasks
   - what is normative, proposal-only, plan-only, generated, and historical
   - what commands must run
   - what evidence and reviewers are mandatory
   - what to exclude and when to escalate

## Domain Entrypoints vs Task Bundles

Domain entrypoints answer:
- where should an agent start for this domain?

Task bundles answer:
- how should an agent execute this type of task safely?

Domain entrypoints are machine-readable source surfaces.
Task bundles are operational read-first bundles for humans and agents.

## Authoritative Starting Surfaces

An authoritative starting surface is:

- a canonical doc, spec, contract, or runbook under the settled roots
- a source-controlled policy surface from Wave 5 or Wave 6
- a generated runtime artifact directly derived from those source surfaces

An authoritative starting surface is not:

- archive by default
- transitional compatibility surfaces
- generated inventory without a canonical upstream source
- ad hoc freeform notes that are not part of the control plane

## Forbidden Low-Signal Surfaces

Forbidden low-signal starting points include:

- archive or superseded paths unless explicitly labeled historical context
- compatibility or wrapper paths as default entrypoints
- generated ledgers or reports when a canonical upstream source exists
- broad repo-root searches as a substitute for task resolution

## Canonicality Rules

Wave 8 must:

- prefer canonical docs/specs/contracts/runbooks
- surface archive only under explicit historical context
- distinguish normative, proposal, plan, generated, and archive lanes clearly
- use existing Wave 5 and Wave 6 obligations instead of restating them by hand

## Determinism Rules

All generated Wave 8 artifacts must:

- be reproducible from local commands
- be stable in ordering
- fail check mode when stale
- preserve canonical-path discipline

## Escalation Boundary

Wave 8 does not fake precision.

Agents must escalate when:

- a domain has no clean canonical entrypoint
- a task spans multiple high-risk truth planes
- cross-repo impact remains unknown or manual-review-only
- evidence or reviewer obligations cannot be resolved deterministically
- a required starting surface exists only in archive/transitional locations
