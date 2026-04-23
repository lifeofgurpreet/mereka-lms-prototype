---
title: Truth Repair Doctrine
type: standing-order
owner: platform-release
observed_at: 2026-04-18
status: canonical
bead: mereka-lms-y69t
---

# Truth Repair Doctrine

_Audience: every agent, operator, and reviewer working on this platform._

Durable artifacts in this repository — runbooks, handoff docs, escalation tables, verification catalogs, retry helpers — repeatedly rot within hours of being created. The root cause is consistent across every instance: **canonical artifacts are being written as narrative instead of as executable contract.** A narrative reads convincingly; a contract fails visibly when it drifts.

This doctrine is the correction. Five rules. Each is enforceable. Each names the defect it prevents.

---

## Rule 1 — Canonical means generated or dry-run-verified

A document, script, or helper is only **canonical** (authority for future work) after at least one of:

- it is mechanically generated from live state by CI (or by a pinned script that an agent can re-run), or
- it has been dry-run end-to-end against the target environment, with evidence captured somewhere the next reader can find.

Hand-edited markdown and hand-written runbooks are **drafts**, not authority, until one of those conditions holds.

**Defect this prevents.** A runbook shipped with an undefined variable (`${BASELINE_DIGEST}` referenced, never exported) because nobody had executed it end-to-end before merge. Observed on `docs/ops/runbooks/promotion-rollback-drill.md` at the #1817 merge; repaired in #1821. If the author had been required to dry-run it, the defect would have been caught in draft, not in production authority.

**How to comply.**

- If you ship a runbook, open a follow-up bead titled "dry-run `<runbook>` end-to-end on `<env>` and capture evidence at `<path>`" at P2 or higher, blocking on runbook merge. The runbook is not closed until the drill is run.
- If you ship a helper script, the PR must include a self-test that exercises the default behaviour and at least one seeded failure mode.
- If you ship a status doc, it must either carry a regeneration command in its header _or_ cite the CI job that produced it.

---

## Rule 2 — Retractions patch the source, not just the margins

If a claim, hypothesis, or recommendation in a canonical artifact turns out to be wrong, the fix is **to patch every occurrence of the claim in every canonical artifact** in the same tranche as the retraction. A PR comment, a chat message, or an annotation in one section of the file does not count.

**Defect this prevents.** The `managedFields=null` hypothesis about stuck Argo selfHeal was retracted at §Symptom and §Root-Cause Hypotheses in `docs/runbooks/ArgoAppSelfHealStuck.md`, but the escalation table at §When to Escalate still listed `managedFields=null confirmed on >50% of Deployments` as an L3 condition. Operators reading the escalation table in an incident would be re-anchored on a retracted theory. Repaired in #3229.

**How to comply.**

- When you write a retraction, `rg` the canonical artifact (and sibling runbooks in the same directory) for the retracted term before you commit. If any occurrence survives, the retraction is incomplete.
- Retraction commits must touch every canonical artifact that carried the claim. Cross-repo retractions (app repo + infra repo) must reference each other's commit SHA or PR number in the message.
- A retraction note added below an escalation table or diagnostic block is fine **in addition to** patching the claim, not as a substitute for it.

---

## Rule 3 — A runbook is not executable until it has been run

A runbook that has never been dry-run end-to-end against the target environment is a **draft**. It may be correct; it is not yet canonical. Execute it once, capture the evidence, repair any friction discovered, and only then mark the runbook as canonical authority.

**Defect this prevents.** The rollback-drill runbook merged with the `BASELINE_DIGEST` variable undefined, unqualified `kubectl` commands (ambient context was `rke2-prod` on `ssh mereka` at the time of merge), and a `<baseline-digest>` literal placeholder never substituted. All three defects would have surfaced in the first 30 seconds of a dry-run. None would have survived into authority.

**How to comply.**

- "Evidence of execution" means a file under `docs/ops/evidence/<runbook-name>-<YYYY-MM-DD>.md` with timestamps, commands as actually executed (including `--context`), actual outputs, and at least one "friction encountered / follow-up filed" bullet.
- The SLO classifications in a runbook must reflect something observed, not something assumed. `≤ 10 min` is an aspiration on paper and a contract only after it has been met once.
- The `status:` frontmatter value `executable` is reserved for runbooks that have been executed. `draft` is the default. Promote only after dry-run.

---

## Rule 4 — Helpers ship with a call site or a wire-in bead

A helper script, CLI wrapper, or shared library is not "S-something complete" when it merges — it is complete when it is **wired into the workflow that made the problem urgent**. A PR that merges a helper without at least one live call site must file a P2-or-higher follow-up bead for the wire-in. No helper counts as a subtask completion; only its wire-in does.

**Defect this prevents.** `emit-promotion-chain-metrics.sh` (S6.1) and `run-with-retry.sh` (S6.2) both shipped as helpers without workflow call sites. A handoff document described S6 as "aggressively shipped," which is true but misleading: the helpers exist, the promotion chain is not yet instrumented, and the scanner retry is not yet bounded. Wire-ins filed as `mereka-lms-lb4c.6` and `mereka-lms-lb4c.7`.

**How to comply.**

- Helper PRs must include either a workflow reference (`.github/workflows/<name>.yml`) that calls the helper, or a comment body that says "follow-up bead `<id>` covers the wire-in, merging helper alone does not close the parent."
- Bead closure messages must distinguish "helper shipped" from "wired in" explicitly.
- The subtask bead for the underlying problem (e.g. S6.1 "instrument promotion chain timing") closes on wire-in, not on helper merge. This maps bead state to user-visible behaviour change, not to repo-internal artifact existence.

---

## Rule 5 — Verifier-affecting changes update all five layers, or none

A change that affects what CI considers a passing build must coherently update **all five** of:

1. the workflow (`.github/workflows/*.yml`)
2. the policy or configuration that the workflow consults (`scripts/governance/script-registry.yaml`, CI inventory generators, allowlists)
3. the verifier itself (the script or helper under validation)
4. the self-test or fixture that exercises the verifier
5. the runbook that tells an operator what to do when the verifier fails

If any one of the five lags, the system lies: CI can pass while the artifact is wrong, or fail while the artifact is right.

**Defect this prevents.** PR #1492 (adding a manual-only verify script) required **five coordinated changes** to land cleanly — reachability-allowlist + catalog regen + sprawl-budget bump + staging-vocabulary-allowlist + rebase-catalog regen — and each guard was discovered sequentially over 5 iterations. The cost was paid because the five layers were not treated as an atomic shape. As of 2026-04-23 (PR #2104, bead `rq9k`) the verified count is **six guards**; the canonical matrix is [`docs/ops/quickref/6-guard-verifier-registration.md`](../../../docs/ops/quickref/6-guard-verifier-registration.md).

**How to comply.**

- Every PR that changes a verifier must include a checkbox in the PR body: `- [ ] Verifier-chain layers updated: workflow | policy/config | verifier | self-test | runbook` with each layer named or marked N/A with justification.
- Reviewers treat an N/A without justification as a request for changes.
- A change where only 1-2 of the five layers are touched is suspect. Either the change is truly narrow (then mark the other layers N/A and explain) or the change is incomplete.

---

## Failure classes this doctrine is designed to retire

Each of these is a real defect class observed in the last six weeks. The rule that prevents each is listed.

| Failure class | Example | Rule |
|---|---|---|
| Runbook references undefined variable | `${BASELINE_DIGEST}` in rollback drill (#1817) | Rule 1, Rule 3 |
| Retracted hypothesis survives in escalation table | `managedFields=null` in ArgoAppSelfHealStuck (#3229) | Rule 2 |
| Runbook uses unqualified `kubectl` on an operator host whose ambient context drifts | Every runbook merged before 2026-04-18 on this branch | Rule 3 |
| Helper script merged with no call site, subtask reported as "shipped" | S6.1 #1818, S6.2 #1819 | Rule 4 |
| Verifier, workflow, allowlist, and catalog diverge | #1492 5-iteration merge | Rule 5 |
| Hand-written handoff doc stale before the next agent reads it | docs 22, 23, 1820 | Rule 1, Rule 3 |
| Status doc claims "S6 2/5 merged, 3/5 in CI" while queue has moved | #1820 | Rule 1 |

---

## How this doctrine is enforced

This doctrine is enforced by agents and reviewers. It is not a CI check (yet). Two escalation paths make it durable:

1. Any canonical artifact that violates a rule should be repaired in a follow-up PR that cites the rule number in the commit message (`per TRUTH_REPAIR_DOCTRINE rule N`).
2. The operator or reviewer who discovers a violation must both open the follow-up PR and file a bead so the pattern is tracked across the platform rather than fixed locally and forgotten.

Future automation:
- `scripts/governance/verify-runbook-executable.sh` — walks every `docs/ops/runbooks/*.md` with `status: executable` frontmatter and asserts a matching evidence file exists. (Bead to file.)
- `scripts/governance/verify-retraction-sweep.sh` — given a retraction PR, `rg`s the retracted term against the canonical artifact set and fails if any occurrence survives. (Bead to file.)
- Brief-generator (`mereka-lms-5dz5`) — canonical handoff artifacts are emitted from live state, not hand-written, so they cannot drift.

---

## Why this exists

Six weeks of data shows the platform's biggest remaining risk is no longer code correctness — it is **narrative that masquerades as authority**. This doctrine puts that pattern on paper so the next agent, reviewer, or operator can name it the moment they see it recurring.

The doctrine is short on purpose. Five rules, each with the defect it prevents and how to comply. If it grows beyond one page, it has itself become narrative.

---

## Related

- Bead: `mereka-lms-y69t` (this doctrine's tracking bead)
- Bead: `mereka-lms-5dz5` (brief-generator — Rule 1 automation)
- `docs/meta/standing-orders/README.md` (root index)
- `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md` (where this doctrine sits in the authority chain)
- Evidence PRs: #1817, #1819, #1820, #1821 (mereka-lms); #3229, #3248 (bbi-infrastructure)
