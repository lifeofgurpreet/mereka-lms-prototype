# Wave 7 Agent Skill Charter

## Purpose

Wave 7 turns the existing documentation, specification, review, and contract runtimes
into a direct agent-consumption interface.

After Wave 7, an agent should be able to resolve a task into:

- canonical read-first surfaces
- governing specs, contracts, and runbooks
- required reviewers
- required evidence
- required validators
- escalation conditions
- out-of-scope boundaries

## What Wave 7 consumes

Wave 7 does not create a new truth plane.

It consumes already-authoritative surfaces:

1. Wave 4 doc and spec topology, canonical roots, and generated navigation surfaces
2. Wave 5 change intelligence, review routing, evidence obligations, and truth impact
3. Wave 6 cross-repo contract, release obligation, and deployment impact intelligence

## Authority order

Wave 7 bundles must resolve authority in this order:

1. canonical normative sources:
   - specs, contracts, and governing docs that define what must be true
2. runtime policy sources:
   - Wave 5 and Wave 6 source-controlled rules for reviewers, evidence, and cross-repo obligations
3. generated read models:
   - catalogs, manifests, graphs, review bundles, impact reports, and obligation reports
4. handoff and closeout surfaces:
   - closeout notes, reviewer front doors, and execution trackers

If two surfaces disagree, the earlier layer wins.

## Required task runtime behavior

Every supported task type must resolve:

- one-line intent
- authority order
- canonical read-first surfaces
- generated surfaces to refresh
- affected truth surfaces
- required reviewers
- required evidence
- required commands
- likely cross-repo dependencies
- out-of-scope boundaries
- escalation conditions

## Non-goals

Wave 7 does not:

- redesign canonical roots
- move major doc or spec trees
- reopen wrapper retirement policy
- replace Wave 5 or Wave 6 review logic
- infer live-cluster truth
- hand-author generated task bundles

## Task model boundary

Task types must be mutually understandable and minimally overlapping.

Resolution rules:

- use the highest-risk matching task type when a change touches multiple lanes
- keep generated-surface-only work in the lowest-risk bucket
- escalate to human judgment when a single diff spans multiple high-risk truth planes

## Expected consumer

Wave 7 is for:

- coding agents
- review agents
- orchestration agents
- human reviewers who need the same deterministic entry path
