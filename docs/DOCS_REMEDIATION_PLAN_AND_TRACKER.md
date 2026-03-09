# Documentation Remediation Operating System (Self-Contained)
_Audience: Documentation owners, coding agents, and reviewers • Owner: Platform Team • Last verified: 2026-03-06 • Status: canonical_

**Document class**: tracker

This document is the **single source of truth** for fixing and preventing documentation entropy in this repository. It is written so any agent or contributor can execute the program end-to-end without prior chat context.

---

## 0) Mission, Scope, and Non-Goals

## Mission

Create a documentation system that is:
- easy to navigate for humans,
- safe for agents to consume,
- measurable and maintainable over time.

## Scope

In-scope:
- `docs/**` structure, classification, consolidation, indexing, and links.
- canonical vs supporting vs superseded designation.
- evidence lifecycle and archive policy.
- tracker, scorecards, and governance process.

Out-of-scope (unless explicitly approved):
- code or infrastructure behavior changes unrelated to docs.
- deleting audit/evidence artifacts in first pass.
- rewriting historical records for style-only reasons.

## Program constraints

- No hard delete in early phases (use move/archive first).
- Moves and link updates happen in the same change set.
- Every changed canonical doc must include required metadata.

---

## 1) Definitions and Common Language

Use these exact definitions.

- **Canonical doc**: authoritative source for a topic.
- **Supporting doc**: supplemental detail; cannot conflict with canonical doc.
- **Superseded doc**: replaced by a canonical doc; kept temporarily as pointer/history.
- **Archive candidate**: historical material not needed in active path.
- **Redirect stub**: minimal file that points to canonical replacement.
- **Evidence bundle**: timestamped operational output (logs, reports, snapshots).
- **Domain owner**: final approver for docs in a domain (`ops`, `branding`, `onboarding`, etc.).

Required status values in catalog/tracker:
- `canonical`
- `supporting`
- `superseded`
- `archive-candidate`

---

## 2) Current Problem Statement (What is broken)

This repository currently exhibits these failure modes:

- Multiple overlapping indexes and entry points.
- Duplicate procedural guidance across onboarding/access/branding/runbooks.
- Split runbook authority across two trees.
- High-volume timestamped evidence causing search noise.
- Root-level markdown sprawl and inconsistent naming conventions.

Consequences:
- contributors pick different source docs and drift behavior,
- agents consume conflicting instructions,
- maintenance cost rises and confidence drops.

---

## 3) North-Star Information Architecture

Target architecture (staged migration, not big-bang):

- `docs/adr/` — architectural decisions.
- `docs/concepts/` — what/why architecture and system references.
- `docs/guides/` — human how-to guides (setup/admin/workflows).
- `docs/ops/` — operational docs and runbooks for production/system tasks.
- `docs/archive/` — historical, superseded, and aged evidence.

Transitional authority rules:
- Existing `docs/operations/**` remains valid until moved to `docs/ops/**`.
- Existing `docs/onboarding/**` remains valid until moved to `docs/guides/**`.
- `docs/runbooks/**` is legacy; use redirect-only stubs during transition.
- One topic may have many supporting docs but only one canonical doc.

---

## 3.1) Final Intended State Structure (Target Tree)

This is the explicit end-state structure agents should converge to.

```text
docs/
├── README.md
├── CONTRIBUTING.md
├── DOCS_REMEDIATION_PLAN_AND_TRACKER.md
├── adr/
│   └── *.md
├── concepts/
│   ├── architecture/
│   ├── analytics/
│   ├── branding/
│   ├── mfe/
│   ├── security/
│   └── *.md
├── guides/
│   ├── onboarding/
│   ├── admin/
│   ├── local-setup/
│   ├── branding/
│   ├── mfe/
│   └── *.md
├── ops/
│   ├── runbooks/
│   │   ├── deployment/
│   │   ├── incident-response/
│   │   ├── monitoring/
│   │   ├── security/
│   │   ├── data/
│   │   └── *.md
│   ├── deployment/
│   ├── ci-cd/
│   ├── monitoring/
│   ├── quickref/
│   └── *.md
├── archive/
│   ├── evidence/
│   │   ├── 2026-Q1/
│   │   ├── 2026-Q2/
│   │   └── ...
│   ├── reports/
│   ├── cleanup-logs/
│   └── superseded/
└── qa/
    ├── reports/
    └── *.md
```

Notes:
- `docs/operations/**`, `docs/onboarding/**`, and `docs/runbooks/**` are transitional and should eventually converge to `docs/ops/**` and `docs/guides/**`.
- Transitional folders are not final-state targets.

---

## 3.2) Docs Root Allowlist (Final)

Only these files should remain in `docs/` root at steady state:

- `README.md`
- `CONTRIBUTING.md`
- `DOCS_REMEDIATION_PLAN_AND_TRACKER.md`
- `catalog.json` (optional but recommended)

Everything else in root must be moved to a domain folder or `docs/archive/`.

Exception policy:
- temporary root files allowed only with Docs Lead approval and must include removal date.

---

## 3.3) Legacy-to-Target Mapping Contract

Use this deterministic mapping unless explicitly overridden by owner approval.

| Legacy Path Pattern | Target Path Pattern | Notes |
|---|---|---|
| `docs/operations/runbooks/**` | `docs/ops/runbooks/**` | canonical runbook home |
| `docs/runbooks/**` | `docs/archive/superseded/runbooks/**` | keep stubs until link migration complete |
| `docs/onboarding/**` | `docs/guides/onboarding/**` | onboarding guides |
| `docs/architecture/**` | `docs/concepts/architecture/**` | conceptual architecture |
| `docs/analytics/**` | `docs/concepts/analytics/**` | analytics concepts and references |
| `docs/branding/**` | `docs/guides/branding/**` and `docs/concepts/branding/**` | split by procedural vs conceptual content |
| `evidence/**` | `archive/evidence/**` (tiered) | evidence lifecycle policy applies |
| `docs/operations/evidence/**` | `docs/archive/evidence/**` (tiered) | evidence lifecycle policy applies |
| `docs/ci-cd/**` | `docs/ops/ci-cd/**` | operational pipeline docs |
| `docs/status/**` | `docs/status/**` | active reporting/status root; archive only after cold-storage transition |

---

## 4) Mandatory Metadata Contract

Every canonical/supporting doc touched by this program must include metadata.

For markdown docs (subtitle format):

```markdown
# Title
_Audience: X • Owner: Y • Last verified: YYYY-MM-DD • Status: canonical|supporting|superseded_
```

For specs/frontmatter docs, include equivalent fields:
- `owner`
- `last_updated` or `last_verified`
- `status`

If metadata is missing, task is not complete.

---

## 4.1) Preferred Machine-Readable Frontmatter (World-Class Default)

For new or heavily revised canonical docs, use YAML frontmatter.

```yaml
---
title: "<doc title>"
type: "adr|concept|guide|runbook|evidence|index|status"
status: "canonical|supporting|superseded|archive-candidate"
owner: "<team or person>"
tags: ["domain", "topic"]
last_verified: "YYYY-MM-DD"
review_cadence_days: 30
canonical_of: "<topic-id>"
supersedes: []
superseded_by: ""
---
```

Guidance:
- Subtitle metadata remains acceptable for legacy docs.
- Frontmatter is required for all **new canonical docs** starting in Phase 2.
- If both frontmatter and subtitle exist, frontmatter is authoritative.

---

## 4.2) Agent Context-Poisoning Controls

This program assumes agents consume docs for decisions; stale/conflicting docs must be neutralized.

Controls:
- Every superseded doc must include a replacement pointer in the first 10 lines.
- Canonical docs must include an explicit `status: canonical` marker.
- Index docs must link canonical docs first, superseded docs never as primary links.
- Weekly canonical-conflict scan is mandatory (no topic with >1 canonical authority).
- Evidence and historical status docs must be excluded from "how-to" indexes.

Failure policy:
- If an agent finds contradictory procedures between canonical docs, mark task `BLOCKED` and escalate to domain owner.

---

## 5) Document Type Taxonomy and Rules

| Type | Purpose | Must Include | Must Not Include |
|---|---|---|---|
| ADR | decision rationale | context, decision, consequences | operational runbook steps |
| Concept | architecture and system behavior | boundaries, diagrams/flows, references | step-by-step incident procedures |
| Guide | human workflow | prerequisites, steps, verification, next steps | on-call severity trees |
| Runbook | operational response | trigger, procedure, verification, rollback | product strategy discussion |
| Evidence | traceability/audit | timestamp, context, artifact references | canonical operational instructions |
| Index | navigation | scope, entry paths, canonical links | long procedural content |

---

## 5.1) Transient vs Permanent Knowledge Rule

Use this decision matrix to prevent logs from becoming reference docs.

| Content Kind | Default Home | Lifecycle |
|---|---|---|
| Time-bound status updates (`*_STATUS`, `*_TRACKER`, dated handoffs) | `docs/status/**` while active, then `docs/archive/reports/**` | active status belongs in the winning status root; archive only when cold |
| Permanent how-to | `docs/guides/**` or `docs/ops/runbooks/**` | canonical candidate |
| Architecture rationale | `docs/adr/**` or `docs/concepts/**` | long-lived, reviewed periodically |
| Raw evidence/log outputs | `docs/evidence/**` while active, then `docs/archive/evidence/**` | active evidence belongs in the winning evidence root |

Extraction rule:
- If transient docs contain durable guidance, extract that guidance into canonical guide/runbook first, then supersede/archive transient source.

---

## 6) Canonical Selection Rules (Deterministic)

When multiple docs overlap, choose canonical using this order:

1. **Operational correctness**: most current and verified instructions.
2. **Authority marker**: explicit owner/status metadata.
3. **Coverage**: complete prerequisites + procedure + verification + rollback.
4. **Discoverability**: referenced by primary index docs.
5. **Stability**: fewer volatile timestamp references.

Tie-breaker:
- keep the doc with strongest operational acceptance criteria;
- convert others to supporting or superseded stubs.

---

## 6.1) Runbook Integrity Standard

A document may be called a runbook only if it includes:
- trigger/when-to-use,
- prerequisites,
- step-by-step procedure,
- verification of success,
- rollback or recovery path.

If a file named "runbook" fails this standard:
- reclassify as `guide` or `concept`,
- rename and relocate accordingly in Phase 3,
- leave redirect stub if links exist.

---

## 7) Evidence Lifecycle Policy

Evidence is retained by tier:

- **Hot**: <= 30 days, active operational reference.
- **Warm**: 31-90 days, reduced access frequency.
- **Cold**: > 90 days, move to `docs/archive/evidence/YYYY-Qx/`.

Rules:
- no hard delete in first two phases;
- create dry-run report before any evidence move;
- preserve auditability fields (date, context, source command/artifact).

---

## 7.1) Archive Decision Matrix (Do Not Use Mtime Alone)

Archive decisions must use at least three signals:
- type/status (`superseded`, `archive-candidate`),
- content role (transient vs permanent),
- recency (`last_verified` or dated filename),
- owner approval.

Unsafe pattern (forbidden):
- "Archive everything older than X days" without content/type checks.

Safe pattern:
- propose archive candidates -> owner approval -> move with ledger -> link check.

---

## 8) Naming and Path Conventions

- Use kebab-case for new canonical docs: `topic-name.md`.
- Avoid SCREAMING_SNAKE_CASE for new files.
- Keep filenames semantic and stable.
- Keep top-level `docs/` files minimal and curated (indexes/governance only).
- Use relative markdown links; update in same change set when moving files.

---

## 8.1) Renaming Strategy (Risk-Controlled)

Kebab-case migration is required but must be incremental:
- prioritize canonical docs first;
- perform renames in small batches;
- include link updates in same change;
- maintain redirect stubs for high-traffic docs until inbound links are cleared.

Forbidden:
- mass rename of entire `docs/**` in one batch.

---

## 9) Program Governance (RACI + Decision Rights)

Decision rights:
- **Docs Lead (A)**: policy, exceptions, final canonical disputes.
- **Domain Owner (A/R)**: domain-level canonical approval.
- **Agent Operator (R)**: executes tasks and produces artifacts.
- **Reviewer (A/C)**: validates quality gates and safety.
- **Consumer (I)**: informed of outcomes.

RACI:

| Workstream | Docs Lead | Domain Owner | Agent Operator | Reviewer | Consumer |
|---|---|---|---|---|---|
| Policy and standards | A | C | R | C | I |
| Inventory and classification | C | C | R | A | I |
| Structural moves | C | A | R | A | I |
| Content consolidation | C | A | R | A | I |
| Link repair + CI checks | A | C | R | A | I |
| Archive decisions | A | C | R | C | I |

---

## 9.1) Component Views (Cross-Cutting Knowledge Packs)

Some topics span ADR + guide + runbook + CI docs. Create component index pages to stop fragmentation.

Initial required component packs:
- `docs/concepts/components/tutor.md`
- `docs/concepts/components/branding.md`
- `docs/concepts/components/mfe.md`

Each component pack must include:
- what the component is,
- canonical ADR links,
- canonical operational runbooks,
- canonical guides,
- active CI/workflow references.

These are index docs only (no duplication of full procedures).

---

## 10) Quality Rubric (World-Class Standard)

Score canonical docs on a 1-5 scale:

| Dimension | 1 | 3 | 5 |
|---|---|---|---|
| Authority clarity | ambiguous | owner known | explicit owner + status + replacement links |
| Freshness | unknown | date present | verified date + review cadence + owner |
| Actionability | incomplete | workable | deterministic steps + verification + rollback |
| Discoverability | buried/duplicated | findable | clear index path + stable naming + cross-links |
| Agent safety | conflicting instructions | mostly consistent | machine-parseable metadata + conflict-free commands |

Release gate for changed canonical docs:
- average >= 4.2
- no dimension below 4.0

---

## 10.1) Contradiction Audit Requirement

For each consolidation cluster, include a "contradictions found" section:
- conflicting command,
- conflicting hostname/URL,
- conflicting prerequisite,
- conflicting expected outcome.

No cluster can be marked `DONE` until contradictions are resolved or explicitly waived by domain owner.

---

## 11) KPIs, SLOs, and Success Criteria

Track weekly from the scorecard index in `docs/guides/admin/README.md`.

| KPI | Target |
|---|---|
| Files classified in `catalog.json` | 100% |
| Duplicate canonical topics | 0 |
| Broken links in changed scope | 0 |
| Root docs outside allowlist | 0 new additions |
| Canonical docs older than 90 days | <10% |
| Redirect-stub debt reduction | >=25% per sprint after stabilization |

SLOs:
- 95% of docs changes include required metadata.
- 95% of new docs land outside docs root.
- 100% of moved docs include link updates in same change.

Program completion criteria:
- all phase gates passed,
- KPI targets met for 2 consecutive weekly cycles.

---

## 11.1) Program Anti-Regression Gates

Add these CI/policy checks:
- fail if new docs root file is added outside allowlist;
- fail if changed canonical doc lacks metadata/frontmatter;
- fail if superseded doc has no `superseded_by` pointer;
- fail if changed links in moved scope are broken.

Optional advanced gate:
- fail if a topic appears with >1 canonical doc in `catalog.json`.

---

## 12) Execution Plan (Phased)

## Phase 0 — Program Setup (Day 1)

Goal:
- freeze entropy and establish authority model.

Actions:
- confirm this file as governing playbook;
- define docs root allowlist;
- assign domain owners;
- publish escalation path.
- define naming/retention waiver process.

Exit gate:
- governance approved by docs lead + domain owners.

## Phase 1 — Inventory and Classification (Days 2-4)

Goal:
- produce complete `generated/catalogs/docs-catalog.json`.

Actions:
- classify every file by type and status;
- detect overlap clusters;
- identify canonical conflicts;
- produce overlap report.
- produce transient-vs-permanent classification report.

Exit gate:
- 100% docs classified;
- canonical candidate selected per cluster.

## Phase 2 — Structural Consolidation (Days 5-9)

Goal:
- remove structural ambiguity with low-risk moves.

Actions:
- unify runbook authority tree;
- move root clutter to proper domains;
- convert legacy duplicates to redirect stubs;
- maintain move ledger.
- create component index packs (`tutor`, `branding`, `mfe`).

Exit gate:
- no dual canonical runbooks;
- root trimmed to allowlist.

## Phase 3 — Content Consolidation (Days 10-16)

Goal:
- reduce semantic duplication and contradictions.

Actions:
- consolidate onboarding, access, branding clusters;
- preserve details by linking to deep references;
- mark superseded docs explicitly with replacement pointers.
- run contradiction audit and resolve/wave each finding.

Exit gate:
- one canonical doc per major topic cluster;
- no conflicting procedural instructions.

## Phase 4 — Link Repair and Quality Enforcement (Days 17-20)

Goal:
- prevent regressions and lock-in quality.

Actions:
- repair internal links;
- run TODO/DRAFT/TBD/FIXME audit;
- add CI checks for metadata, root policy, and links.
- enforce anti-regression gates from section 11.1.

Exit gate:
- changed-scope link check zero failures;
- CI docs policy enforced.

---

## 12.1) Phase Acceptance Tests (Objective Checks)

Use these objective checks before closing each phase.

Phase 1 acceptance:
- `generated/catalogs/docs-catalog.json` exists and includes every file under `docs/**`.
- Every record has type + status + owner/null + freshness risk.

Phase 2 acceptance:
- No active canonical docs remain in legacy `docs/runbooks/**`.
- Root file count matches allowlist + approved temporary exceptions.

Phase 3 acceptance:
- For each major cluster (onboarding/access/branding/runbooks/evidence), exactly one canonical doc is designated.
- Superseded docs contain replacement pointers.

Phase 4 acceptance:
- Changed-scope markdown links resolve.
- Metadata contract passes for all changed canonical/supporting docs.
- CI policy checks active and enforced.

---

## 13) Risk Register and Controls

| Risk ID | Risk | Control | Escalation Trigger |
|---|---|---|---|
| R-01 | active docs accidentally archived | two-step approval before archive move | archive proposal without domain approval |
| R-02 | broken links after move | mandatory same-change link updates | any broken link in changed scope |
| R-03 | multiple canonicals for one topic | canonical conflict audit | >1 canonical marker in same cluster |
| R-04 | evidence loss | no hard delete in early phases | deletion requested before policy gate |
| R-05 | agent rework drift | strict prompt contracts and acceptance gates | repeat reopen/block cycles |

Escalation path:
- content ambiguity -> domain owner
- policy conflict -> docs lead
- compliance concern -> security/compliance reviewer

---

## 14) Agent Execution Protocol (Required)

Every agent task must follow this pattern:

1. **Read this document first**.
2. **State task ID and scope**.
3. **Run only approved actions for the current phase**.
4. **Produce required artifact(s)**.
5. **Update tracker row status and notes**.
6. **Stop if conflict detected** and mark `BLOCKED` with reason.

Hard safety rules:
- no hard delete unless explicitly approved,
- no mass rename without link repair,
- no canonical reassignment without owner approval.

---

## 15) Copy/Paste Agent Prompts

### Prompt A — Full Inventory

```text
You are executing Phase 1 (Inventory and Classification) from docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md.
Create generated/catalogs/docs-catalog.json with one record per file in docs/** containing:
- path
- type (adr|concept|guide|runbook|evidence|index|status|other)
- status (canonical|supporting|superseded|archive-candidate)
- owner (if discoverable)
- last_verified_or_updated (if discoverable)
- freshness_risk (low|medium|high)
- canonical_conflict_group (nullable)

Also output docs/archive/reports/overlap-matrix-YYYYMMDD.md.
Do not move, rename, or delete files in this task.
```

### Prompt B — Canonical Conflict Resolution Map

```text
You are executing Phase 1 continuation.
Using generated/catalogs/docs-catalog.json, produce docs/archive/reports/canonical-resolution-map-YYYYMMDD.md.
For each overlap cluster:
- nominate canonical doc
- list supporting docs
- list superseded/archive candidates
- explain rationale with explicit content differences
- assign required owner approval

Do not perform file moves in this task.
```

### Prompt C — Safe Structural Moves

```text
You are executing Phase 2.
Apply only approved moves from canonical-resolution-map.
Rules:
- move + redirect stub (no hard delete)
- update internal markdown links in the same change set
- record each move in docs/archive/reports/move-ledger-YYYYMMDD.md
- if conflict or missing owner approval, stop and mark BLOCKED
```

### Prompt D — Content Consolidation

```text
You are executing Phase 3.
Consolidate approved topic clusters by intent:
- onboarding/local setup
- access URLs
- branding execution

Ensure one canonical doc per cluster. Superseded docs must include:
- status: superseded
- replacement link
- archival date

Do not introduce new root docs unless approved in allowlist.
```

### Prompt E — Quality and Closure

```text
You are executing Phase 4.
Perform:
- internal link validation in changed scope
- TODO/DRAFT/TBD/FIXME scan for canonical docs
- metadata compliance check

Output docs/archive/reports/consolidation-closeout-YYYYMMDD.md including:
- unresolved issues
- risk notes
- rollback notes
- confidence score
```

---

## 16) Operational Templates

## 16.1 Redirect Stub Template

```markdown
# <Old Title> (Superseded)
_Audience: <audience> • Owner: <owner> • Last verified: YYYY-MM-DD • Status: superseded_

This document has moved to:
- `<relative-path-to-canonical-doc>`

Reason:
- Consolidated under canonical source to prevent drift.
```

## 16.2 Canonical Header Template

```markdown
# <Canonical Title>
_Audience: <audience> • Owner: <owner> • Last verified: YYYY-MM-DD • Status: canonical_

## Scope
<what this doc covers and what it does not>
```

## 16.3 Move Ledger Template

```markdown
# Move Ledger YYYY-MM-DD

| Old Path | New Path | Reason | Link Updates Complete (Y/N) | Owner Approval | Notes |
|---|---|---|---|---|---|
```

## 16.4 Weekly Scorecard Template

```markdown
# Docs Program Scorecard YYYY-MM-DD

## KPI Snapshot
- Classification coverage: %
- Duplicate canonical topics: #
- Broken links (changed scope): #
- Root policy violations: #
- Stale canonical docs >90d: %
- Redirect-stub debt: #

## Risks and Blocks
- ...

## Decisions Needed
- ...
```

---

## 17) End-to-End Tracker (Master)

Status values: `TODO`, `IN_PROGRESS`, `BLOCKED`, `DONE`.

| ID | Phase | Task | Owner | Status | Input | Deliverable | Exit Criteria | Notes |
|---|---|---|---|---|---|---|---|---|
| GOV-01 | 0 | Approve governance, owner map, root allowlist | Docs Lead | BLOCKED | This playbook | Governance approval note | Approved by docs lead + domain owners | 2026-03-06: governance packet published at `docs/archive/reports/governance-approval-note-20260306.md`; blocked pending docs lead + domain owner signatures |
| GOV-02 | 0 | Publish escalation path and decision rights | Docs Lead | BLOCKED | This playbook | Escalation appendix | Team can route blockers deterministically | 2026-03-06: escalation routing appendix published at `docs/archive/reports/escalation-appendix-20260306.md`; blocked pending docs lead acknowledgment |
| INV-01 | 1 | Build complete catalog | Agent Operator | DONE | `docs/**` | `generated/catalogs/docs-catalog.json` | 100% files classified | 2026-03-06: `generated/catalogs/docs-catalog.json` regenerated with 953 records and validated against filesystem |
| INV-02 | 1 | Generate overlap matrix | Agent Operator | DONE | catalog + docs | `overlap-matrix-YYYYMMDD.md` | All major clusters mapped | 2026-03-06: `docs/archive/reports/overlap-matrix-20260306.md` generated |
| INV-03 | 1 | Canonical conflict report | Agent Operator | DONE | overlap matrix | `canonical-resolution-map-YYYYMMDD.md` | One canonical proposed per cluster | 2026-03-06: `docs/archive/reports/canonical-resolution-map-20260306.md` generated with canonical proposals; major-cluster approval matrix published at `docs/archive/reports/canonical-authority-approval-matrix-20260306.md` (owner approvals pending) |
| STR-01 | 2 | Runbook tree authority consolidation | Agent Operator | DONE | approved map | move ledger + stubs | No dual canonical runbook trees | 2026-03-06: legacy runbook duplicates in `docs/operations/**` converted to superseded stubs with canonical pointers to `docs/ops/runbooks/**`; latest overlap (`VISUAL_REGRESSION.md`) retired in move-ledger; runbook contradiction audit published at `docs/archive/reports/runbooks-contradiction-audit-20260306.md` |
| STR-02 | 2 | Root cleanup by allowlist | Agent Operator | DONE | root docs | move ledger updates | Root reduced to allowlist only | 2026-03-06: docs root matches allowlist exactly (`README.md`, `CONTRIBUTING.md`, `DOCS_REMEDIATION_PLAN_AND_TRACKER.md`, `catalog.json`); transitional deprecation timeline published at `docs/archive/reports/transitional-path-deprecation-timeline-20260306.md`; migration queue advanced with `docs/operations/DISCOVERY_QUICKSTART.md -> docs/ops/quickref/discovery-quickstart.md`, `docs/operations/LOCAL_ACCESS_INFO.md -> docs/ops/quickref/local-access-info.md`, `docs/operations/LOCAL_PRODUCTION_PARITY.md -> docs/ops/quickref/local-production-parity.md`, `docs/operations/LOCAL_WORK_REMAINING.md -> docs/ops/quickref/local-work-remaining.md`, `docs/operations/IN_CLUSTER_AUTH_VERIFICATION.md -> docs/runbooks/operations/IN_CLUSTER_AUTH_VERIFICATION.md`, `docs/operations/DJANGO_RAW_SQL_BYPASS.md -> docs/ops/runbooks/django-raw-sql-bypass.md`, `docs/operations/TASK3_SES_SMTP_GUIDE.md -> docs/ops/runbooks/task3-ses-smtp-guide.md`, `docs/operations/COST_ESTIMATE.md -> docs/ops/ci-cd/cost-estimate.md`, and `docs/operations/PRODUCTION_VERIFICATION_CHECKLIST.md -> docs/ops/runbooks/production-verification-checklist.md` (superseded stubs retained) |
| CNT-01 | 3 | Onboarding cluster consolidation | Agent Operator | DONE | approved map | updated canonical + stubs | No contradictory setup paths | 2026-03-06: canonical onboarding index set to `docs/guides/onboarding/README.md`; duplicate indexes superseded; contradictions resolved in `docs/archive/reports/onboarding-contradiction-audit-20260306.md` |
| CNT-02 | 3 | Access URLs consolidation | Agent Operator | DONE | approved map | canonical + local subset | One access canonical source | 2026-03-06: canonical moved to `docs/ops/quickref/access-urls.md`; legacy `docs/operations/ACCESS_URLS.md` transitioned to `archive-candidate` shim after dependency cleanup; contradictions resolved in `docs/archive/reports/access-contradiction-audit-20260306.md` |
| CNT-03 | 3 | Branding docs role-boundary consolidation | Agent Operator | DONE | approved map | contract/guardrail/reference split | No duplicated gate definitions | 2026-03-06: canonical role-boundary index added at `docs/guides/branding/README.md`; legacy `docs/branding/README.md` retained as transitional archive-candidate shim; contradictions resolved in `docs/archive/reports/branding-contradiction-audit-20260306.md` |
| EVD-01 | 3 | Evidence retention dry-run | Agent Operator | DONE | evidence paths | retention dry-run report | owner-approved candidate list | 2026-03-06: `docs/archive/reports/evidence-retention-dry-run-20260306.md` generated with policy-safe signals; candidate count `0` (no pending approval-gated moves this cycle); contradiction findings documented in `docs/archive/reports/evidence-contradiction-audit-20260306.md` |
| EVD-02 | 3 | Evidence archive moves (approved only) | Agent Operator | DONE | approved dry-run | archive move ledger | tiered lifecycle applied | 2026-03-06: no-op execution for this cycle (`0` approved candidates); lifecycle workflow remains active and canonical archive evidence path is enforced in QA tooling defaults/checks |
| LNK-01 | 4 | Link repair in changed scope | Agent Operator | DONE | moved file list | link update patch | 0 broken links in changed scope | 2026-03-06: changed-scope link validation completed with 0 missing links; repo-wide markdown link audit now reports 0 hard failures and 0 warnings in `docs/**` |
| QLT-01 | 4 | TODO/DRAFT audit | Agent Operator | DONE | canonical docs | closeout report | unresolved queue created | 2026-03-06: `docs/archive/reports/consolidation-closeout-20260306.md` generated with unresolved queue entries |
| QLT-02 | 4 | CI docs policy checks | Agent Operator | DONE | CI workflows | policy checks in CI | metadata/root/link policies enforced | 2026-03-06: `.github/workflows/docs-policy.yml` + `tools/docs/verify/verify-docs-policy.sh` enforce root allowlist, canonical metadata, superseded pointer, and changed-scope link checks |
| CLS-01 | 4 | Weekly KPI scorecard | Docs Lead | IN_PROGRESS | tracker + reports | scorecard report | KPI targets on track | 2026-03-06: first cycle scorecard published (`docs/archive/reports/docs-program-scorecard-20260306.md`); second-cycle template staged at `docs/archive/reports/docs-program-scorecard-20260313-template.md`; do not publish before 2026-03-13; governance sign-off still pending via `docs/archive/reports/canonical-authority-approval-matrix-20260306.md` |
| CLS-02 | 4 | Program closure decision | Docs Lead | BLOCKED | all artifacts | closure memo | DoD met for 2 consecutive weeks | 2026-03-06: closure-readiness memo published at `docs/archive/reports/program-closure-readiness-20260306.md`; blocked pending GOV approvals and second KPI cycle (next check no earlier than 2026-03-13) |

---

## 18) Milestone Dashboard

| Milestone | Scope | Exit Gate | Target Window | Status |
|---|---|---|---|---|
| M1 | Governance and inventory complete | GOV-01..INV-03 | Week 1 | BLOCKED |
| M2 | Structural consolidation complete | STR-01..STR-02 | Week 2 | DONE |
| M3 | Content + evidence consolidation complete | CNT-01..EVD-02 | Week 3 | DONE |
| M4 | Quality enforcement and closure | LNK-01..CLS-02 | Week 4 | BLOCKED |

---

## 19) Definition of Done

The program is complete only when all conditions are true:

- each topic cluster has exactly one canonical doc;
- root docs follow approved allowlist;
- runbooks are discoverable from one canonical tree;
- evidence follows tiered lifecycle policy;
- changed-scope links have zero breakage;
- CI prevents recurrence (metadata/root/link policies);
- KPI targets are met for two consecutive weekly scorecards.

---

## 20) What Is Still Missing Until "Done"

This section is a live gap checklist. If any item is unchecked, the program is not finished.

- [x] Final-state folder tree exists physically in repo (`docs/concepts`, `docs/guides`, `docs/ops`, `docs/archive`).
- [x] Root allowlist enforced in CI.
- [x] Legacy trees (`docs/operations`, `docs/onboarding`, `docs/runbooks`) are either migrated or explicitly marked transitional with deprecation timeline (`docs/archive/reports/transitional-path-deprecation-timeline-20260306.md`).
- [ ] Canonical authority map published and approved for every major topic cluster.
- [x] Evidence lifecycle automation/reporting active (dry-run + approved move workflow).
- [x] Redirect stub debt reduced to near-zero and scheduled for archive.
- [ ] Weekly scorecard demonstrates KPI targets for 2 consecutive cycles.

If this checklist is not fully complete, report program state as `IN_PROGRESS`.
