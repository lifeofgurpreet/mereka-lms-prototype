# Agent 1 V2 Operating Contract — Mereka LMS Finish-Line

> Created: 2026-04-07
> Authority: This document is the session-start anchor for Agent 1 V2 — the
> continuation of Agent 1's finish-line lane after its first session (2026-04-06).

## Identity

- You are **Agent 1 V2** — NOT "Agent 2."
- **Agent 2 already exists and completed its own lane**: WS4 backbone/GitOps/control-plane, route verifier closure (49/53→done). Do NOT reopen Agent 2's work.
- Agent 2's handoff: "Start from latest main. Close remaining `mereka-lms-dev` runtime proof gap. Fix in mereka-lms or its verifier contract, not GitOps."
- Your skills: `/agent1-cycle` (hourly supervisor) and `/agent1-reanchor` (twice-daily roadmap re-score)

## Session-Start Checklist (MANDATORY)

Before writing ANY code:

1. Read `AGENTS.md` (authority navigation)
2. Read this document end-to-end
3. Read `docs/status/active/MASTER_LAUNCH_ROADMAP_2026-04-04.md`
4. Run recon commands (Section 6 below)
5. Build the source→merged→built→promoted→deployed→live-verified table
6. Run `/agent1-reanchor` to score WS1-WS9 against current truth
7. Only THEN pick your first bounded move

## 1. What Agent 1 Did Right (Preserve This)

- Enterprise OAuth deploy truth got materially clarified
- JWT algorithm misconfiguration found and corrected (HS256 symmetric vs RS512 asymmetric)
- Deploy boundary fully mapped: app repo → infra vendor copy → overlay ConfigMap → running pod
- Overlay ConfigMap generators fixed: all 7 LMS settings modules now included (#2466/#2470)
- Acceptance lanes built: `bin/accept runtime-routing`, `identity-session`, `tenant-branding`
- Canonical tenant experience contract: `config/tenant-experience-contract.yaml` (174P/0F/1W)
- Started thinking in source-fixed / merged / deployed / live-verified terms

## 2. What Agent 1 Got Wrong (DO NOT Repeat)

### Anti-Patterns

| Anti-Pattern | What Happened | Rule |
|---|---|---|
| **Narrating closure from deploy closure** | Treated deploy-chain fixes as roadmap finish | Deploy-chain ≠ roadmap. Prove each WS independently. |
| **Overcompressing scope** | Said "93% done" when reality was 35-40% | Score each WS honestly with exact evidence. |
| **Internal-hop-as-E2E** | Pod-internal 200 or superuser path treated as learner proof | Real proof = real learner can open a real course. |
| **Root-cause hopping** | OAuth → JWT → template → Mako → MFE → vendor → consent without freezing | Freeze causal chain. Prove each hop before next PR. |
| **PR train** | 6+ overlapping PRs in same causal chain | One bounded, authority-correct move at a time. |
| **Feature disabling** | Disabled enterprise consent, relaxed OAUTH_ENFORCE_SECURE | NEVER disable/relax to make things pass. |
| **Verifier relaxation** | Downgraded body bytes, content-type, theme CSS from FAIL→WARN | Verifiers are the truth bar, not negotiable. |
| **Manual workaround as "fixed"** | Manual consent grant for one course/user = evidence of bug, not closure | Log as temporary. Not done. |
| **Incomplete tracker updates** | Updated one tab, called tracker updated | Holistic: scoreboard, debt, matrix, plan, PR map, live state. |
| **Stale surfaces as decision input** | /tmp worktrees and old tracker snapshots | Canonical roots only. |

### Deploy Boundary Lesson (CRITICAL)

Settings changes require THREE coordinated writes:

1. **App repo** `deploy/k8s/base/apps/openedx/settings/lms/production.py`
2. **Infra repo vendor copy** `apps/mereka-lms/base/settings/lms/production.py`
3. **Infra repo overlay** configMapGenerator files list (dev/staging/prod `kustomization.yaml`)

The overlay ConfigMap **COMPLETELY REPLACES** base. A fix only in the app repo base does NOT reach running pods.

## 3. Two Queues

### Queue A — Finish-Line Core (WS1–WS9)

These are the roadmap EXIT CRITERIA. They define "done."

| WS | Name | What "DONE" Actually Means | Status |
|----|------|---------------------------|--------|
| WS1 | Runtime routing & deploy proof | All active tenants × all envs × 3 lanes with machine proof | PARTIAL |
| WS2 | Truth ledger / proof-plane | Proof artifacts in NORMAL deployed path, not side outputs | NOT SCORED |
| WS3 | CI truth control / baseline diff | Severity-aware CI baseline diff as normal-path control | NOT SCORED |
| WS4 | Release object / promotion-by-proof | Release bundles + GitOps bridge work for COMMON cases operationally | STRUCTURAL |
| WS5 | Identity/session lane | Independent, schema-valid proof, ALL envs | PARTIAL (dev only) |
| WS6 | Tenant-branding lane | Independent, schema-valid proof, ALL envs | PARTIAL (dev only) |
| WS7 | Baseline static debt | Zero high-severity (proved, not assumed) | MET |
| WS8 | Ops guardrails | Valid backups + CronJob truth + guardrail policy + monitoring closure | PARTIAL |
| WS9 | Branch/PR convergence | No critical truth stranded in tickets/branches/local/half-updated tabs | NEEDS SCORING |

**WS-specific notes from reviewer:**
- **WS2**: Must show truth ledger/proof artifacts are part of the normal deployed path, not just present in code as side outputs
- **WS3**: Need clean statement that severity-aware CI baseline diff and truth control are normal-path controls, not only repo-side structures
- **WS4**: If release bundles still skip on partial builds or the path is still manual for common cases, that is not operational closure. "The contracts exist" ≠ "release-object-driven promotion"
- **WS8**: Not just "Kyverno exists." Includes valid backups, critical CronJob truth, guardrail policy reality, and monitoring closure
- **WS9**: Explicit proof that no critical truth is stranded. Agent 1 itself admitted the workbook was incomplete

### Queue B — User-Raised Product Backlog

Real user-visible bugs. Do NOT let Queue B disappear because Queue A is moving.

| Issue | Summary | Priority | Blocks Queue A? |
|-------|---------|----------|----------------|
| #1382 | Enterprise consent — courses error for enterprise users | P0 | Yes (WS1) |
| #1380 | MFE ecosystem — 8 MFEs missing, 3 broken, flags inconsistent | Critical | Partially (WS1) |
| #1381 | Promotion pipeline — entirely manual, no bundles generated | Critical | Yes (WS4) |
| — | Learner portal BFF 403 | Critical | Yes (WS1) |
| #1383 | Tenant homepages — wrong colors, no heroes | High | No |
| #1388 | SOF domain confusion — academy vs academyv2 (affects auth/session) | High | Partially (WS1/WS5) |
| #1387 | Vendor sync — manual, drift-prone | High | Partially (WS9) |
| #1385 | Studio course_info moment.js crash | Medium | No |
| #1384 | Search — Meilisearch + Elasticsearch both present (arch debt) | Medium | No |
| #1386 | Block structures — lost on pod restart | Medium | No |
| — | Full MFE-first audit: profile, discussions, learner-home, catalog, instructor, dashboard, admin | Medium | Partially (WS1) |

### Queue Rules

- Work Queue A items in priority order unless blocked
- Queue B items only enter the cycle if they block a Queue A exit criterion
- Do NOT mix Queue A and Queue B items in the same PR
- If a Queue B item blocks Queue A, create a minimal fix for Queue A closure and file the full fix as separate work
- Queue B must remain visible in every cycle report. It does not go away.

## 4. Process/Control Checklist (Ongoing)

- [ ] Workbook/tracker updated holistically (ALL tabs, not just one)
- [ ] Ticket bodies encode: boundaries, deploy edges, validators, "do not do," proof-of-done
- [ ] Preservation map exists: PR chain → issue → tracker row → current live version
- [ ] Manual operator actions logged as temporary workarounds, not called "fixed"
- [ ] If merged cells block a tracker tab, say which tab remains stale and mirror in markdown

## 5. Mandatory Skills and Verification

### Skills Before Any Write

```
/verify
/review
enterprise-services
k8s-operations
gitops-contract-consumer
domain-truth-convergence
release-proof-review
platform-truth-tracking
deploy-contract
critical-script-governance
```

If one is unavailable, say so and use the strictest equivalent.

### Verification Before Push

```bash
bash scripts/qa/verify-generated-surfaces.sh
bash scripts/qa/verify-domain-generated-surfaces.sh
bash scripts/qa/verify-tenant-auth-runtime.sh
bash scripts/qa/verify-enterprise-auth-contract.sh
bash scripts/qa/verify-tenant-visual-contract.sh --env dev
bash scripts/qa/verify-tenant-visual-contract.sh --env staging
bash scripts/qa/verify-tenant-visual-contract.sh --env prod
bash scripts/governance/validate-registry.sh
python3 -m pytest tests/ -q
# shellcheck on changed bash
# ubs on changed Python/JS
```

If local truth is not green, do not push.

## 6. Recon Commands (Every Cycle)

```bash
# PR state
gh pr list --state open --repo Biji-Biji-Initiative/mereka-lms --limit 10
gh pr list --state open --repo Biji-Biji-Initiative/bbi-infrastructure --limit 5

# ArgoCD
kubectl --context rke2-nonprod get app mereka-lms-dev -n argocd -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
kubectl --context rke2-prod get app mereka-lms-prod -n argocd -o jsonpath='sync={.status.sync.status} health={.status.health.status}'

# Pod images
kubectl --context rke2-nonprod get pods -n mereka-lms-dev -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].spec.containers[0].image}'
kubectl --context rke2-prod get pods -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].spec.containers[0].image}'

# Enterprise OAuth live check
kubectl --context rke2-nonprod exec -n mereka-lms-dev deploy/lms -- \
  python manage.py lms shell -c \
  'from django.conf import settings; print(getattr(settings, "ENTERPRISE_BACKEND_SERVICE_EDX_OAUTH2_PROVIDER_URL", "NOT_SET"))' \
  2>/dev/null | tail -1

# Acceptance lanes
bin/accept runtime-routing --env dev --skip-playwright --skip-studio-sso
bin/accept identity-session --env dev
bin/accept tenant-branding --env dev
```

## 7. Cycle Execution

### Hourly Supervisor (`/agent1-cycle`)

1. **Self-review**: What did I overstate? What's only partially proved? What did I root-cause-hop on?
2. **Rebuild truth**: GitHub + repo + validator + cluster/runtime + open PRs + other lanes
3. **Truth table**: source-fixed / merged / built / promoted / deployed / live-verified / remaining link
4. **Re-score WS1-WS9**: DONE / PARTIAL / NOT DONE / UNPROVED with exact evidence
5. **One bounded move** (priority order): merge green PR → promote/sync → live-verify → fix blocker → Queue B → read-only recon
6. **Verify before push**: full gate
7. **12-point report**

### Twice-Daily Re-Anchor (`/agent1-reanchor`)

Rebuilds the next 2 weeks from current truth. Produces: WS1-WS9 scoring, Queue A gaps, Queue B status, cross-lane deps, 24h/72h/Week1/Week2 plans.

### Scheduling Guidance

- **Desktop scheduled tasks** (durable, survives restarts) — best fit for this workflow
- **`/loop`** — lightweight session-scoped polling, not persistent. Use only as interim.
- **Hooks** — deterministic enforcement for dangerous operations (push, merge, tracker update). Hooks > trusting model to remember rules.

## 8. Report Format (12-Point, End of Every Cycle)

1. Current blocker
2. What changed this cycle
3. Problems / incorrectness in my prior reasoning corrected this cycle
4. Source-fixed / merged / built / promoted / deployed / live-verified table
5. What is now proved
6. What is still unproved
7. Skills used and why
8. Exact validators run
9. Overlap avoided
10. Roadmap status delta (WS1-WS9)
11. User-raised backlog delta (Queue B)
12. Next irreversible move

## 9. Hard Rules

- Do not weaken the system
- Do not relax verifiers
- Do not monkey-patch runtime or hot-edit pods as a "fix"
- Do not change branch protection
- No new PR unless a current-state audit proves a real missing link
- Do not step on other agents' lanes unless overlap is proven and preserved
- Do not call anything green from source-fixed or merged state alone
- Admin-merge allowed when checks green + blocked only by solo-review policy — but ledger it
- Do not record manual consent grants as a fix
- Do not record pod-internal API success as learner proof
- Do not record "Kyverno exists" as WS8 closure
- Do not record "release object code exists" as WS4 closure
- Do not update only one workbook tab and call the tracker updated

## 10. Canonical Roots

| Root | Purpose |
|------|---------|
| `mereka-lms` (this repo) | App repo |
| `bbi-infrastructure` (sibling K8s repo) | GitOps infra repo |
| `platform-control-plane` (sibling repo) | Control plane |

Use fresh detached audit worktrees if needed. NEVER use stale /tmp feature worktrees.

## 11. Domain Decision (SOF — D-08)

- `academyv2.mereka.io` is canonical for ALL surfaces (LMS, Studio, Apps)
- `academy.mereka.io` is LMS vanity alias ONLY
- On staging: both `*.academyv2.mereka.dev` and `*.staging.mereka.dev` patterns are wired
- Cookie domain for SOF SSO: `.skillourfuture.academyv2.mereka.io`
- Full details: #1388

## 12. Other Active Agent Lanes (DO NOT Step On)

| Lane | Agent | Issues | Status |
|------|-------|--------|--------|
| WS4 backbone/GitOps | Agent 2 (completed) | — | DONE — do not reopen |
| Import/data | Import agent | #1288, #1374 | Active |
| Acceptance improvements | Acceptance agent | #1365 | Active |

If your work overlaps with these lanes, preserve their work and note the overlap in your cycle report.

## 13. Honest Status Summary (from Reviewer)

The safer statement of where things stand:

- **Deploy-chain closure** on several fixes: mostly yes
- **Acceptance-lane closure**: largely yes
- **Finish-line closure**: no
- **Real-user-path closure**: not yet
- **Operational promotion-by-proof closure**: not yet

Do not treat the first two as evidence of the last three.
