# Conveyor Closure Charter — Final Deliverables

**Date:** 2026-04-18
**Charter:** `docs/status/active/OPENEDX_CONVEYOR_CLOSURE_CHARTER_2026-04-18.md`
**PRs this sprint:** #1800 (merged `5f065d2c`), #1801 (merged `d0580feef`), #1802 (merged `2783e80b`), #1803 (merged `9211c5479`).

## 1. Baseline Table

| Layer | Value |
|---|---|
| Build SHA (canonical artifact) | `102a56a07d3270bb61d7c95b28d6ed0d67919360` |
| mereka-lms `main` HEAD | `9211c5479` (post-sprint; artifact live is still `102a56a07d`) |
| bbi-infrastructure `main` HEAD | `8e80444f` (includes promotion `506b9337` for `102a56a07d`) |
| Argo app | `mereka-lms-dev` @ ns `argocd`; source path `apps/mereka-lms/overlays/profiles/dev` |
| Argo sync status | `Synced`; synced revision `8e80444f` |
| Argo operationState | `Succeeded` |
| Argo health | `Progressing` (worker-probe side-effect; see RC-05) |
| openedx digest (artifact + overlay + deploy spec + live pod) | `sha256:d17ae77f533be1690b969b220b3507c4d9780ef7f477ecd5c47e2b7777b54578` |
| mfe digest (same four-way agreement) | `sha256:377923c0a2ce22c8e7bac7baf488c80f345a1445e2f7ac47b5c29e5b475b35e1` |
| Build workflow run | `24590743862` (success, 2026-04-17T23:14:15Z) |
| Promote workflow run | `24591542962` (success, 2026-04-17T23:45:23Z) |
| Promotion PR / commit | `bbi-infrastructure#3169` / `506b9337` |

## 2. RC-02 Evidence Packet

Directory: `docs/status/active/evidence/rc02-102a56a07d/`

Artifacts (from build run `24590743862`):
- `release-bundle.json` (1,354 bytes) — digest binding + contract refs
- `release-object.json` (1,958 bytes) — canonical `release-object/v1` projection
- `release-gate-envelope.json` (1,736 bytes) — gate identity
- `truth-ledger.json` (3,517 bytes)
- `build-provenance.json` (825 bytes)
- `promotion-dispatch-envelope.json` (7,538 bytes)
- `control-plane-release-bundle-projection.json` (2,938 bytes)
- `release-object-projection-schema.yaml` (5,969 bytes, extracted from `platform-control-plane@fa5065b`)

Verifier results (archived as `verify-*.out.txt` in the same directory):
- `scripts/qa/verify-release-object.sh`: **PASS** — `Release ID: ro-rb-102a56a0-20260417T232409Z` against `platform-control-plane@fa5065b9b083f569278ab80c67fc1dfa25c82b3c`
- `scripts/qa/verify-build-workflow-contract.sh`: **127 PASS / 0 FAIL** — 682-line script, 182 assertions (confirmed non-trivial by reviewer)

**Verdict: RC-02 CLOSED.**

## 3. RC-03 / RC-04 Single-Chain Image Proof

Eight layers, one digest each, bit-identical across all:

| # | Layer | openedx | mfe |
|---|---|---|---|
| 1 | `mereka-lms` source commit | `102a56a07d` | `102a56a07d` |
| 2 | Build workflow `24590743862` | success | success |
| 3 | `release-bundle.json.images.*.digest` | `sha256:d17ae77f…54578` | `sha256:377923c0…b35e1` |
| 4 | Promote workflow `24591542962` input | same | same |
| 5 | `bbi-infrastructure@506b9337` → `apps/mereka-lms/overlays/profiles/dev/kustomization.yaml` | same | same |
| 6 | Argo desired image (rendered from profiles/dev) | same | same |
| 7 | `mereka-lms-dev` deployment spec | same | same |
| 8 | Live pod `imageID` | same | same |

**Verdict: RC-03 CLOSED. RC-04 CLOSED.** Reviewer independently confirmed at 02:10Z.

## 4. RC-05 / RC-06 Runtime + Product-Surface Matrix

### Product-Surface (three tenants)

| Tenant (apps.*) | LMS_BASE_URL | SITE_NAME | `/authn/login` | `/theme/core.min.css` |
|---|---|---|---|---|
| `apps.academyv2.mereka.dev` | `https://academyv2.mereka.dev` | **Mereka Academy** | 200 | 200 |
| `apps.skillourfuture.academyv2.mereka.dev` | `https://skillourfuture.academyv2.mereka.dev` | **Skill Our Future Academy** | 200 | 200 |
| `apps.academy.biji-biji.com` | `https://academy.biji-biji.com` | **Biji-Biji Academy** | 200 | 200 |

Each tenant returns its own `LMS_BASE_URL`, `SITE_NAME`, and tenant-prefixed `LOGO_URL` at `/api/mfe_config/v1`. **Tenant isolation proven.**

### Runtime Readiness

| Deployment | Ready / Desired | State |
|---|---|---|
| `lms`, `cms`, `mfe`, `caddy`, `mysql`, `mongodb`, `redis`, `meilisearch`, `elasticsearch`, enterprise-* (8), `clickhouse`, `superset*` (3), `ralph`, `xqueue`, `notes`, `credentials`, `discovery`, `preview-redirect`, `smtp` | 1 / 1 each | ✅ serving |
| `lms-worker` | 0 / 3 per k8s readiness | ⚠️ probe misreport — workers ARE running |
| `cms-worker` | 0 / 2 per k8s readiness | ⚠️ probe misreport — workers ARE running |

**Probe defect analysis (RUNTIME_MATRIX_ADDENDUM_2026-04-18T02.md):** Inside a "NotReady" worker pod: PID 1 = celery main (11+ min CPU, alive), plus 2 concurrency subprocs, plus accumulated `celery inspect ping` probe invocations. Registered tasks include `ScheduleRecurringNudge`, `update_course_schedules`, etc. Workers ARE consuming and processing tasks.

Root cause: probe uses `celery inspect ping -t 15` which broadcasts cluster-wide via Redis broker; reply round-trip exceeds the 15s Celery timeout at current cluster size (5 workers) and 20s probe timeout. Introduced by `bbi-infrastructure#3166` (closing bead `q5yz`).

**Consequences split:**
- User-facing impact: **ZERO** — all web surfaces serving
- Tenant isolation: **PROVEN** across 3 tenants
- Async tasks: **PROCESSING** despite probe misreport
- Rollout safety: **BROKEN** — rolling updates will fail readiness gate
- Background CPU load: **ELEVATED** — probe spawns a Python subprocess every 15s

**Verdict:**
- **RC-05 RE-OPENED** (honestly re-framed per reviewer finding F). Bead `mereka-lms-1li5` filed + elevated P1.
- **RC-06 CLOSED.**

## 5. RC-07 Graduation Report — **CLOSED END-TO-END**

**Graduation trigger:** PR #1801 — `chore(release): add argparse help text to generate_release_object.py`. Small, safe, intentional. Touches `scripts/release/**` which is on the image-content trigger path for `build-tutor-images.yml`.

**New canonical artifact (post-graduation):**
- commit SHA: `d0580feefd53580d378e1d9254d5e38dc5dfe066`
- openedx digest: `sha256:aceac3676a18ad5e238b5106122bd4b5cd1c9a21c94cdd995030d4a1445408ea`
- mfe digest: `sha256:8314b1538d27ff2da896db6f121e1da96b152f1230a7b3045a4b2abe103a8548`

**Full conveyor timeline — observed end-to-end:**

| Event | Time (UTC) | Elapsed |
|---|---|---|
| PR #1801 opened | 01:21:05Z | T=0 |
| First CI run | 01:27Z | +6m |
| Drift-guard fails + fix (catalog regen + staging allowlist) | 01:31–01:32Z | — |
| CI all green | 01:45Z | +24m |
| Branch BEHIND main (due to #1800/#1802 merges) | 01:53Z | — |
| Merge main, re-push, CI re-run | 02:14–02:18Z | — |
| **Merged as `d0580feef`** | **02:18:14Z** | **+57m from open** |
| Build workflow `24594709469` spawned | 02:18:18Z | +4s from merge |
| Build MFE Image success | 02:21:12Z | +3m |
| Build OpenEdX Image success | 02:22:44Z | +4m |
| SLSA Provenance success | 02:25:45Z | +7m |
| Generate Release Bundle success | 02:27:57Z | +10m |
| Post-push MFE Scan success | 02:28:01Z | +10m |
| Post-push OpenEdX Scan success | 02:43:47Z | +25m |
| Dispatch Dev Promotion success | 02:45:42Z | +27m |
| **Build `24594709469` fully green** | **02:46:21Z** | **+28m (492s total)** |
| bbi-infrastructure promote run `24595184854` fired | 02:46:07Z | +25s from dispatch |
| Promotion PR `bbi-infrastructure#3195` opened | 02:46:42Z | +35s from promote |
| PR #3195 CI green + merged as `815c5be3` | 02:47:48Z | +66s from open |
| Argo synced to `815c5be3` (op=Succeeded) | 02:49:06Z | +78s from merge |
| **New ReplicaSets spawned** (lms, cms, mfe) | **02:54:12–15Z** | +5m (Argo jitter) |
| New pods Ready on new digests | ~02:55Z | — |
| **Full conveyor cycle** | **T+1h 34m** | (PR open → live pods on new digest) |
| **Build + promote + Argo only** | **T+37m** | (PR merge → live pods on new digest) |

**Digest chain verification on the NEW artifact (`d0580feef`):**

| Layer | openedx | mfe |
|---|---|---|
| bbi-infrastructure@`815c5be3` overlay | `sha256:aceac3676a18…` | `sha256:8314b1538d27…` |
| `mereka-lms-dev` deployment spec | `sha256:aceac3676a18…` | `sha256:8314b1538d27…` |
| Live pod imageID (new ReplicaSets) | `sha256:aceac3676a18…` | `sha256:8314b1538d27…` |

**3-tenant product-surface verified on new digests:**

| Tenant | LMS_BASE_URL | SITE_NAME | login | theme |
|---|---|---|---|---|
| academyv2 | `https://academyv2.mereka.dev` | Mereka Academy | 200 | 200 |
| skillourfuture | `https://skillourfuture.academyv2.mereka.dev` | Skill Our Future Academy | 200 | 200 |
| biji-biji | `https://academy.biji-biji.com` | Biji-Biji Academy | 200 | 200 |

**Observed manual interventions (governance-debt signals):**
1. **CI drift guards fired** on the first CI run: `verify-verification-catalog.sh` + `verify-staging-vocabulary-drift.sh` both failed (evidence docs bumped reference counts; argparse description mentioned "staging"). Fix required regenerating the catalog + adding the script to the staging allowlist. **Governance finding: two CI guards fire on seemingly-unrelated changes.**
2. **Branch fell BEHIND main** three times due to parallel merges; each required forward-merge + CI re-run (~10m per cycle).
3. **Reviewer pulse-check surfaced two WEAK findings** post-merge (E: help-text F-string + F: soft-dismissed RC-05 regression). Fixed in follow-up PR #1803.
4. **Forced Argo hard-refresh** at 02:48Z to nudge ArgoCD's kustomize repo-server cache — the documented "runtime-ops learning" for overlay-file merges. Known behavior, not a new problem, but counts as an intervention.

**Classification: GREEN — conveyor graduated end-to-end.**
- CI-guard friction (items 1–2) → governance debt, not conveyor defect
- Self-review gaps (item 3) → addressable via pre-merge adversarial review
- Argo refresh nudge (item 4) → known runtime-ops learning

**The conveyor itself (build → scan → bundle → dispatch → promote → Argo → live pods) self-executed correctly.** 37 minutes from merge to live pods on new digest. No human hand on image, digest, or overlay.

## 6. Governance Hardening Report (OG-01 / OG-02 / OG-03)

### OG-01 — Stale Argo Op Recovery Runbook
File: `docs/status/active/evidence/rc02-102a56a07d/OG-01-STALE-ARGO-OP-RUNBOOK.md` (273 lines).

Recovery decision tree (preference order):
1. `argocd.argoproj.io/refresh=hard` annotation (non-destructive)
2. `argocd app terminate-op` via CLI
3. `kubectl patch` via ArgoCD SA impersonation (last resort per `gitops-enforcement.md`)
4. Escalate on Kyverno denial / git auth failure

**Two surprise findings inlined and spot-verified:**
- ArgoCD v2+ has **NO built-in operation timeout**. `argocd-cmd-params-cm` has no `timeout.operation` key. A stuck op is permanent without intervention. Contradicts common "2 hour auto-clear" belief.
- Kyverno `protect-gitops-managed-resources` ClusterPolicy **does NOT exist** on `rke2-nonprod`. 14 other ClusterPolicies are present. The global rule `~/.claude/rules/gitops-enforcement.md` describes enforcement that isn't deployed. Filed as bead `mereka-lms-bv0n` (P3).

### OG-02 — Timing Scoreboard
File: `docs/status/active/evidence/rc02-102a56a07d/OG-02-TIMING-SCOREBOARD.md` (221 lines).

Sampled 50-build window. Only 4 confirmed end-to-end green cycles. Promote failure rate: **67%** (8 of 12 successful builds had a failed promote).

For green cycles: p50 total wall-clock **34m**, p95 **65m**. OpenEdX post-push scan is the long pole (7–27m), **not** the build itself (2–3m). Dispatch gap build→promote is sub-second.

**Key insight:** timing is not the blocker, reliability is. Fixing the 67% promote failure rate matters more than optimizing latency.

### OG-03 — Promote-Dev-Image Failure Cluster
File: `docs/status/active/evidence/rc02-102a56a07d/OG-03-PROMOTE-AUDIT.md`.

11 of 20 recent runs failed. Classes:
- **A.2 schema-evolution races** (3 failures) — e.g. `release_object_projection missing canonical identity field 'lane'`
- **B auth-dispatch-403** (1) — GitHub App lacks `actions:write`
- **C transient-panic** (1) — binary tool nil-pointer
- **A.1 control-plane-fetch transient 5xx** (1) — no retry-with-backoff
- **A.3 evidence-pack missing** (1) — producer/consumer contract mismatch
- **D empty-log "Create promotion PR"** (3) — needs deeper instrumentation
- **cascade** (2) — root cause was earliest failure in the run

**Ranked fix recommendations (highest ROI first):**
1. Fix GitHub App permissions for `actions:write` on bbi-infrastructure dispatch
2. Investigate empty-log Create-promotion-PR failures (likely `pull_requests:write` permission)
3. Add retry-with-backoff to control-plane contract fetch (`curl --retry 3`)
4. Pin or replace the panicking dispatch binary
5. Document schema-evolution producer-before-consumer coordination convention

Filed as bead `mereka-lms-1kd9` (P2).

## 7. Authority Verdict Memo

File: `docs/status/active/evidence/rc02-102a56a07d/OG-AUTHORITY-VERDICT.md`.

**Verdict: HARMLESS STALE DEBT.**

`apps/mereka-lms/overlays/dev/kustomization.yaml` still pins `dfbe7ef31806` / `sha256:87c04e6d…` for openedx. This is **shadowed** by `apps/mereka-lms/overlays/profiles/dev/kustomization.yaml` which pins the current artifact (`102a56a07d…` / `sha256:d17ae77f…`). Kustomize precedence (child patches override parent) ensures the rendered manifests ship the current digest.

Reviewer independently confirmed via `kustomize build apps/mereka-lms/overlays/profiles/dev` — output shows `102a56a07d` tag, no `dfbe7ef31806` drift.

**Recommended follow-on (non-blocking, future cycle):** small PR that EITHER sync the stale parent pin OR remove the `images:` block from `overlays/dev` entirely (preferred — eliminates the duplicate authority surface).

## 8. Final Recommendation

### Tackle Next (Ordered)

1. **Bead `mereka-lms-1li5` (P1): worker readinessProbe defect.** This is the one RC-05 regression still on the critical path. Pick Option 2 from the bead: swap the probe from broker-traversal (`celery inspect ping`) to a local-only readiness check (tasks-registered or process/port check). It's the only option that breaks the pathological growth-with-cluster-size pattern. Do this before the next dev rollout attempt, or a rolling update will stick at the first pod.
2. **Bead `mereka-lms-1kd9` (P2): promote-dev-image 67% failure rate.** Apply OG-03's ranked fixes. Start with the GitHub App permissions — highest ROI.
3. **Bead `mereka-lms-bv0n` (P3): Kyverno gap.** EITHER deploy `protect-gitops-managed-resources` ClusterPolicy OR update the global rule to reflect reality (selfHeal is the sole enforcement).
4. **Overlay authority cleanup (follow-on, non-blocking):** remove the `images:` block from `overlays/dev/kustomization.yaml` so `profiles/*` becomes sole authority.
5. **Post-Deploy E2E Gate retirement or repointing** (run `24591547989` classification): gate validates decommissioned GKE production parked-state, always fails, adds noise to the post-deploy channel. Either remove the workflow or repoint at staging/dev E2E suite.

### Stay Frozen Until Above Is Done

- **No Build Authority Phase 2 expansion.** The conveyor is not yet boring; don't add surface area.
- **No deterministic-build cleanup push.** Current image-chain agreement is proven; churn here is strict debt addition.
- **No MFE aggregate redesign.** 3-tenant isolation is green; do not regress.
- **No Indigo retirement tranche.** Out of scope for conveyor-closure work.
- **No observability/dashboards expansion** until OG-02 timing scoreboard's recommendation (reliability-before-latency) is actioned.
- **No tenant-runtime patches** triggered by RC-05 RE-OPENED. The probe defect is narrow; patching middleware or SiteConfiguration in response would be scope creep.

## Summary Statement

**The web-serving conveyor is proven.** The operator surface is not yet trustworthy.

What is real:
- eight-layer digest agreement for artifact `102a56a07d`
- eight-layer digest agreement for a second artifact `d0580feef` within 37 minutes of merge, organic push-to-main
- three-tenant product-surface isolation verified on both artifacts
- saved RC-02 evidence packet matches the GitHub artifact

What is still weak and NOT closed by this sprint:
- **RC-05 is RE-OPENED, not conditionally closed.** `lms-worker` 0/3 and `cms-worker` 0/2 despite Celery processing tasks. Rollout safety is broken. Bead `mereka-lms-1li5` (P1) is the real follow-on.
- **Operator truth on `ssh mereka` is branch-dependent and unreliable.** VPS checkouts were on a feature branch, not main; `platform-control-plane` schema was not discoverable; every operator session must now start with a preflight (branch / local HEAD / `origin/main` / dirty state).
- **RC-02 is not independently reproducible on the VPS** — only verifiable with the packet's saved schema. Needs either a discoverable `platform-control-plane` checkout or an explicit accept-saved-schema mode in the verifier.
- **The failed Post-Deploy E2E Gate (`24591547989`) is not runtime proof** — it fails on a stale GKE/GCP auth path, not on browser critical-path checks. This failure masquerades as app-runtime red and erodes signal quality.
- **Seven active scheduled workflows still route through `gcp-gke-auth` or `GKE_*` vars** (post-deploy-e2e, argocd-drift-check, operations-gates-runtime, daily-infrastructure-audit, mfe-slot-runtime-gates, dr-evidence-bundle, cloud-sql-backup). Active docs still teach the wrong control-plane model.
- **Overlay second-authority debt** at `apps/mereka-lms/overlays/dev/kustomization.yaml` still carries stale `dfbe7ef31806` pins. Harmless today, misleading on any future operator read.

Three beads filed (`1li5` P1, `1kd9` P2, `bv0n` P3). Two global rules needed correction. One adversarial review was incorporated + retrofitted. Two separate tracker docs (`OPENEDX_INDEPENDENT_REMOTE_AUDIT_2026-04-18.md`, `OPENEDX_NEXT_PHASE_PLAN_2026-04-18.md`) now hold the corrected framing.

**Web conveyor: proven. Operator surface: still untrustworthy. Sprint advanced, not closed.**

— claude-code, 2026-04-18T05:30Z
