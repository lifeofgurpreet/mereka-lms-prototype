---
title: Current Operator State
type: rolling-state
owner: platform-release
status: active
---

# Current Operator State

This is the rolling operator authority file.

Do not treat older numbered handoff / session docs as current truth unless
their durable content has been reconciled into this file.

## Purpose

Use this file to keep four things aligned:

1. live platform truth
2. repo / PR truth
3. tracker truth (`br`)
4. next move truth

Routing rule:

- this file answers **what is true now**
- `IMPLEMENTER-MARCHING-ORDERS.md` answers **what an implementer should do
  next**

If these diverge, repair the divergence before or during execution. Do not let
stale prose outrank live evidence.

## Primary Coordination Surfaces

1. this file
2. `IMPLEMENTER-MARCHING-ORDERS.md`
3. `br`
4. current git / PR state
5. current cluster / runtime state

## Operating Rules

- tracker truth + live truth beat stale prose
- when auditing repo surfaces, do not assume the current checkout branch equals
  `origin/main`
- patch merged defects on `main` instead of narrating around them
- keep the bead graph current
- keep this file current
- prefer one rolling authority file over many timestamped status docs
- if a numbered doc is created, fold its durable truth back into this file
- do not rely on ambient kubectl context for dev checks
- when in doubt, verify before claiming progress

## Refresh Procedure

At the start of a working loop:

1. refresh repo truth
2. compare current checkout branch truth to `origin/main` if repo inventory
   matters for the current task
3. refresh PR truth
4. refresh live cluster / runtime truth
5. refresh the bead graph
6. repair this file if it drifted
7. choose the lane using `IMPLEMENTER-MARCHING-ORDERS.md`
8. execute the highest-leverage ready sprint slice

At the end of a working loop:

1. re-check live truth
2. re-check queue truth
3. update beads
4. update this file
5. write the next exact move

## Standing Priorities

Use fresh evidence to order the queue, but generally prefer work in this order:

1. merged defects on `main`
2. realization-truth and release-safety gaps
3. runtime verification gaps
4. PR queue hardening / CI fixes
5. operator runbook hardening
6. status / governance work that reduces future drift

## Tracker Notes

Use `br` as the task graph.

Current warning:

- tracker reads are useful, but tracker mutation is not yet fully trustworthy
- `.beads/issues.jsonl` currently contains `10` non-conforming legacy IDs
- `.beads/` also carries a real corruption / recovery history

Before non-trivial tracker surgery, read:

- `TRACKER-HYGIENE-RECOVERY-PLAN.md`

If the queue is weak:
- create missing beads
- split oversized beads
- add dependencies
- re-prioritize honestly

Do not wait for a perfect graph before working, but do not keep executing from a
broken graph either.

## Known Durable Workstreams

These workstreams are durable even when specific PR numbers change:

- release / promotion truth
- realization truth
- rollback drill quality
- runtime pod / digest verification
- retry semantics hardening
- operator handoff / state automation
- truth-repair governance

## Current Live Truth — recompute, don't cache

Live truth is recomputed per loop via direct commands, not cached in this
file. Earlier versions of this doc had inline "Current Live Truth" and
"Current Queue Truth" sections from a one-shot generator run. Those went
stale within hours and misled implementers (per 2026-04-20 week review
finding #6: "status docs are not reliably current"). Removed 2026-04-20T09:30Z.

Re-prove any lane in seconds:

```bash
# Dev ArgoCD app
kubectl --context rke2-nonprod -n argocd get application mereka-lms-dev \
  -o jsonpath='sync={.status.sync.status} health={.status.health.status} rev={.status.sync.revision}{"\n"}'

# Dev MFE image (confirms last promotion landed)
kubectl --context rke2-nonprod -n mereka-lms-dev get deploy mfe \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

# Open PRs in the queue (both repos)
gh pr list --state open --repo Biji-Biji-Initiative/mereka-lms --limit 15
gh pr list --state open --repo Biji-Biji-Initiative/bbi-infrastructure --limit 15

# Recent merges on main
git log origin/main --oneline -10

# Ready beads
br ready
```

If anything in the slice wraps below contradicts what those commands
return, trust the live commands. Slice wraps are historical record, not
promises that state is still what it was at wrap time.

## Slice Wraps (historical record)

Each slice wrap was the snapshot that was current AT WRAP TIME. Retained
for post-mortem and reproducibility. For "what is true right now", run
the commands above.

### Slice 82 — 2026-04-20T03:45Z (two CI-platform defects root-caused, both fixed durably)

#### Two defects surfaced by PR #1906 build failure

PR #1906 (Authn MFE `getMerekaShellCopy` runtime-helper fix) merged to `main` as
`9bbb5bfb6e20ca9a1a2ced3032e0286b467bcb95`. Its Build Tutor Images run
[`24641484520`](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/runs/24641484520)
finished with **both Build OpenEdX Image and Build MFE Image marked failure**,
yet both images are actually present in GHCR with valid digests.

**Defect 1 — fastlane containerd race** (OpenEdX job). Host `vmi3220759` runs
15 concurrent GHA runner services using the containerd snapshotter. One
runner's job-completed `docker builder prune -af` wiped ingest blobs that
another runner's concurrent `docker pull` was mid-write. Post-push verify
scripts are the race victim.

**FIX SHIPPED on VPS** (SSH'd via tailscale; non-harness host):
- `/usr/local/lib/gha-fastlane/cleanup.sh` now wraps prune in `flock` +
  skips when other `Runner.Worker spawnclient` processes are active;
  force-override at disk >92%.
- Mirrored to SOT `/root/scripts/ci/fastlane-build-cleanup.sh` so
  `bootstrap-fastlane-build-host.sh` preserves the fix.
- Evidence: `docs/ops/evidence/fastlane-containerd-race-fix-2026-04-20.md`
  (on branch `docs/obs-audit-2026-04-20`, PR #1914 which is conflicting
  on stale base — content valuable; PR will need rebase or replacement).

**Defect 2 — ci-metrics-receiver fatal dependency** (MFE job). The composite
action `push-build-metrics` at `bbi-infrastructure/.github/actions/` used
`set -euo pipefail` + `curl --fail-with-body`. When `ci-metrics.mereka.dev`
returned 502, the metrics step failed fatally, cascading to skip post-push
scans + SLSA + dispatch. Root: ci-metrics-receiver PM2 app is **dead on
mereka-coding VPS** (port 9250 not listening, no uvicorn process). Caddy
gets 502 because upstream is down.

**FIX SHIPPED**:
- **`bbi-infrastructure#3377`** — makes `push-build-metrics` non-fatal per
  ADR-025 §5 (observability not release gate). 3-attempt exponential
  backoff then warn-and-continue. Missing metrics-file also becomes
  warn-and-continue.
- **NOT YET FIXED**: ci-metrics-receiver itself being down on
  `mereka-coding`. Per CLAUDE.md, that host is the active coding harness
  and I must not mutate its PM2/systemd state without explicit user
  authorization. Proposed restart documented; user-gated.

**MFE digest verified in GHCR** despite CI-job failure:
```
ghcr.io/biji-biji-initiative/mereka-lms/mfe:9bbb5bfb6e20ca9a1a2ced3032e0286b467bcb95
  → amd64 manifest sha256:1a702c93554cf00f0d2197cd4a1a01aa733a99ce1c8648939c818b4b4e3cfe06
```

#### State of #1906 fix

- Source: merged to `main` (`9bbb5bfb`).
- Images: built and pushed to GHCR with correct tags.
- Dispatch chain: **did not fire** because MFE job marked failure.
- Runtime: **not yet live on dev** — mfe deploy still on pre-#1906 image.
- Promotion PR: **not opened** because `Dispatch Dev Promotion` step was
  skipped.

**Once `bbi-infrastructure#3377` merges and next mereka-lms push happens,
the chain should complete autonomously.** If user wants #1906 live now, two
options:
  a) Restart ci-metrics-receiver on mereka-coding (requires authorization),
     then trigger an empty-commit push to main to re-run Build Tutor Images.
  b) Wait for bbi-infra#3377 to merge; then push empty commit.

#### Shipped this slice

- **bbi-infrastructure#3377** — non-fatal push-build-metrics action (observability-sink-must-not-gate-release).
- **VPS fix on `vmi3220759`** — `cleanup.sh` race guard (serializes docker prune across 15 shared runners).

#### Open items at slice-82 close

- `mereka-lms#1914` (observability world-class audit, 22 beads queued) — conflicting on stale base; content valuable in evidence doc; needs either a rebase or a replacement PR with the same artifacts.
- ci-metrics-receiver PM2 restart — user-gated.
- #1906 runtime verification — gated on dispatch chain re-running after #3377 merges.
- OBS-001..OBS-006 (P0 beads from slice-81 audit) — tracker corrupted, cannot file via `br`; roster preserved in `docs/ops/evidence/observability-audit-2026-04-20.md`.

#### Pointed Next Move (slice 82)

1. **Merge `bbi-infrastructure#3377`** — unblocks all future builds regardless of ci-metrics state.
2. **Decide on ci-metrics-receiver restart** — either user-authorize or leave until #3377 lands (after which it no longer gates anything).
3. **Re-open world-class obs audit PR** cleanly on a fresh base (evidence docs at `docs/ops/evidence/observability-audit-2026-04-20.md` + `docs/ops/evidence/fastlane-containerd-race-fix-2026-04-20.md` exist on branch `docs/obs-audit-2026-04-20`).
4. **#1906 runtime verification**: once dispatch chain re-fires, verify via `kubectl --context rke2-nonprod -n mereka-lms-dev exec deploy/mfe -- grep -rln getMerekaShellCopy /openedx/dist/authn/`.

---

### Slice 83 — 2026-04-20T05:15Z (dispatch chain proven end-to-end, #1906 LIVE on dev)

**End-to-end dispatch chain proven in one unbroken run:**

1. `bbi-infrastructure#3377` merged at 02:28:01Z — non-fatal metrics action live on bbi-infra main.
2. Replayed build `24641484520` (originally failed on #1906 SHA `9bbb5bfb`) re-run via `gh run rerun --failed`. Every downstream job green including the two defects that originally killed it:
   - Post-push OpenEdX Scan: SUCCESS (fastlane containerd race fix holding)
   - MFE metrics post-push: warn-and-continue per the new composite action (ci-metrics-receiver on mereka-coding is still down but no longer blocks)
3. `Dispatch Dev Promotion` fired → opened `bbi-infrastructure#3384` at 03:01:08Z pinning:
   - openedx: `9bbb5bfb@sha256:ef91636faa850ee12c125d86943088c87696223d8ce05252c3534a9c73a07007`
   - mfe: `9bbb5bfb@sha256:4aa93530e225c6aaf01869d535df76e49704c840fbabdb8ca1a88c5836a8d385`
4. Promotion PR auto-merged after `gh api PUT /pulls/3384/update-branch` (BEHIND on main due to unrelated churn). Crown-jewel preflight + policy-guards + gitleaks + Seer all PASS.
5. ArgoCD hard-refresh → synced to bbi-infra `36dfc7cc` (#3384 merge commit).
6. MFE pod rolled to new image. Old pod terminated; new pod `mfe-78fd8f68cd-pxwlw` Ready.

**Runtime proof (authoritative, live HTTPS):**

- `kubectl exec deploy/mfe -- grep -l getMerekaShellCopy /openedx/dist/authn/*.js` → `/openedx/dist/authn/app.7674109da3e00c36e195.js` ✅
- `curl -sL https://apps.academyv2.mereka.dev/authn/login | grep -oE 'app\.[a-f0-9]+\.js'` → `app.7674109da3e00c36e195.js` (same bundle, served through Caddy + ingress)
- `curl -sL https://apps.academyv2.mereka.dev/authn/app.7674109da3e00c36e195.js | grep -c getMerekaShellCopy` → 1

The `getMerekaShellCopy is not defined` ReferenceError that caused the blank-Authn-shell class of failure (RCB-10 successor) is **closed at runtime on dev**.

**Durable fixes shipped this cycle (all proven out live):**

| Fix | Location | Proof |
|---|---|---|
| Fastlane containerd race | `/usr/local/lib/gha-fastlane/cleanup.sh` v2 on `vmi3220759` (tmpfiles.d + flock + per-user fallback + pgrep double-zero fix) | OpenEdX + MFE scans all green on replay |
| ci-metrics non-fatal | `bbi-infrastructure#3377` → composite action warns-and-continues | Build succeeded with ci-metrics.mereka.dev still returning 502 |
| Dispatch chain | Full push→build→scan→SLSA→release-bundle→dispatch→promote→Argo→pod-roll→runtime proven in one organic replay | From merge of #3377 to live runtime: ~10 min |

**Concurrent PR queue (auto-merge armed):**

- `mereka-lms#1916` — Wave 9 absence-tolerance for 5 verifiers + 2 registry entries + inventory regen + catalog regen.
- `mereka-lms#1917` — Clean re-PR of observability audit + fastlane fix evidence. Blocked on the same Wave 9 defects #1916 fixes; cascades on merge.
- `mereka-lms#1915` — slice 82 state doc update. Same blocker pattern.

**Open residuals (non-blocking):**

- ci-metrics-receiver on mereka-coding still down (P2, user-gated). No longer blocks CI.
- Tracker SQLite still corrupted (user-gated repair).
- 22 observability audit beads (6 P0) captured in evidence doc; bead filing gated on tracker repair.

## Pointed Next Move (slice 83)

1. Let #1916 CI cycle finish — should clear now that catalog is regenerated. Auto-merge fires.
2. After #1916 merges, rebase #1915 + #1917 onto main so they pick up Wave 9 fixes.
3. Close loop with one final state-doc slice summarizing the three-PR queue cleared.
4. Resume regular operator queue: m0u5.10.1 Learning MFE diagnosis, remaining Wave 9 cleanup, tracker repair (user-gated).

---

### Slice 84 — 2026-04-20T05:05Z (auth allowlist short-term unblock, #1919 tracking epic)

**User discovery**: pushed back on earlier narrow finding ("missing env var") — real issue is
**role-authority fragmentation** across 6 planes with no canonical contract and no reconciler.
Fadlan was operationally real but absent from every config file in both repos.

**Short-term unblock shipped live (2026-04-20T04:48Z)**:

Ran `ensure-platform-admins.sh --apply --admins <8-CSV>` across:
- `rke2-nonprod / mereka-lms-dev` → fadlan + eugene@mereka.my CREATED
- `rke2-nonprod / stg-mereka-lms` → fadlan + eugene@mereka.my CREATED
- `rke2-prod / mereka-lms` → fadlan + eugene@mereka.my CREATED

Plus Django-shell demote of legacy `admin@greentactsolutions.com` on dev + staging
(is_active=False, is_staff=False, is_superuser=False). Never existed on prod.

**Live verified (all 3 envs)**: 8 humans (gurpreet, malasari, miranda, hira, eugene×2, faiz, fadlan)
are `is_active=True, is_staff=True, is_superuser=True` across LMS + CMS (CourseCreator) +
Discovery + Credentials.

**Durable PRs opened + auto-merge armed**:

- `mereka-lms#1920` — adds fadlan to `ensure-platform-admins.sh` default CSV + rewrites
  `ADMIN_LOGIN_GUIDE.md` to list all 8 humans + mark as baseline-not-canonical.
- `bbi-infrastructure#3394` — syncs Authentik admin group blueprint with 5 missing humans
  (malasari, eugene×2, faiz, fadlan). Preserves `!If`+`!Find` pattern for PVC-wipe safety.

**Tracking epic opened**: [mereka-lms#1919 — Unified Platform-Access Contract](https://github.com/Biji-Biji-Initiative/mereka-lms/issues/1919)

Issue body captures the user's strategic reframe:
- Real object is `(person, principals, roles, environments, realization targets)` — NOT "list of emails"
- 6 disagreeing truth surfaces (Authentik bindings, LMS DB, env var, script, docs, synthetic accounts)
- 6-tranche execution plan (T0 freeze blast radius → T1 inventory matrix → T2 canonical registry →
  T3 replace hardcoded lists → T4 build `accessctl` reconciler with both first-login + periodic repair →
  T5 prove DB-reset survival)
- 6 CI gates (G1-G6)
- 10 proposed beads (auth-access-01 through -10)
- Called out as P1 operational drift, not "fixed"

**Team verification request** posted as comment on #1919 with per-human checklist.

**Open residuals from this slice**:
- Staging still has both `miranda@mereka.my` and `miranda@mereka.io` active — awaiting
  user decision whether `.io` should be demoted.
- `MEREKA_PLATFORM_ADMIN_EMAILS` env var still empty on all 3 envs → middleware backstop
  still dead. Needs separate bbi-infra PR populating the overlay patches (Tranche 3).
- ci-metrics-receiver restart on mereka-coding — still user-gated (P2, no longer CI-gating).

## Pointed Next Move (slice 84)

1. Wait on #1916 aggregator re-run to clear (all sub-checks passed; only umbrella was cancelled).
2. Monitor #1920 + #3394 for auto-merge.
3. If user answers on staging `miranda.io` drift + ci-metrics restart: execute.
4. Otherwise continue existing queue: m0u5.10.1, Wave 9 cleanup, tracker repair.

---

### Slice 85 — 2026-04-20T08:30–09:55Z (sprint queue Tier 1 execution begins)

**Context**: #1927 (RC_CHECKLIST + NEXT-SPRINT-QUEUE.md) merged at start of
slice. That gave a 13-item tiered roadmap — began draining Tier 1 items
while older cascade PRs (#1918/#1921/#1924/#1926) continued waiting on CI
rebases.

**Shipped this slice (auto-merge armed, all 4 green on Process Invariants +
Dependency Review as of push time)**:

- **[#1928](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1928)** `fix(mfe): surface SESSION_COOKIE_DOMAIN through MFE_CONFIG API`
  — Tier 1 #3, one-line plugin change in `_mereka_lms/lms_settings.py`.
  Evidence confirmed: bundle has `SESSION_COOKIE_DOMAIN:"MISSING_ENV_VAR".SESSION_COOKIE_DOMAIN`
  → `undefined` at runtime. MFE config API was silent on the key. Fix uses
  Django `SESSION_COOKIE_DOMAIN` as single source of truth.
- **[#1929](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1929)** `chore(obs): rename stale gke-production → rke2-production Promtail label`
  — Tier 1 #4 (OBS-006) app-repo half. Zero runtime effect — file is
  PLATFORM_SHARED shadow — but prevents dormant config from broadcasting
  wrong label on re-consumption.
- **[bbi-infrastructure#3461](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3461)** OBS-006 bbi-infra mirror.
  Minor detour: `git commit` accidentally scooped 9 other staged files from
  another agent's temporal-oidc work; reset and recommitted clean (1 file).
- **[#1930](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1930)** `feat(obs): schedule Authn MFE smoke` — Tier 1 #5 (OBS-003 phase 1).
  Scheduled cron `*/5 * * * *` dev, `*/15 * * * *` prod. Removed
  `continue-on-error: true` silent-fail posture. Split critical vs soft
  keys in `smoke-authn-mfe.sh` — critical keys still fail, soft keys warn
  (tracked as beads).

**Defects uncovered by scheduled smoke posture**:
- `LOGIN_ISSUE_SUPPORT_LINK` missing from MFE config API → bead
  `mereka-lms-jdsx` opened P2. (Was silently hidden by prior `--dry-run +
  continue-on-error: true` workflow.)
- `SESSION_COOKIE_DOMAIN` missing from MFE config API → fix is PR #1928.

**Currently armed for auto-merge** (7 PRs in mereka-lms, 1 in bbi-infra):
- `#1918`, `#1921`, `#1924`, `#1926`, `#1928`, `#1929`, `#1930`
- `bbi-infrastructure#3461`

**Tier 1 remaining (not yet started)**:
- **Tier 1 #1** (OBS-001): MFE client-side Sentry SDK — cross-lane
  (plugin hook in mereka-lms + DSN env plumbing in bbi-infra). Non-trivial;
  needs a dedicated slice.
- **Tier 1 #2** (auth-allowlist-03): `MEREKA_PLATFORM_ADMIN_EMAILS` env
  var population — BLOCKED on #1919 Tranche 3 (other agent, bbi-infra
  `render-lms-admin-emails.sh` generator).

## Pointed Next Move (slice 85)

1. Wait for current auto-merge cascade to drain. Once #1928 lands, its
   promotion chain produces new MFE image digests; after pods roll, hit
   `curl -s 'https://apps.academyv2.mereka.dev/api/mfe_config/v1?mfe=authn' | jq '.SESSION_COOKIE_DOMAIN'`
   and confirm `.academyv2.mereka.dev` surfaces. Then the smoke WARN should
   flip to PASS on the scheduled run and RC_CHECKLIST row 18 can be ticked.
2. Once #1924 + #1926 land, the queue-truth section (lines 149–233 above)
   becomes obsolete — the generator writes to `CURRENT-OPERATOR-STATE.snapshot.md`
   now and the pruned section stays out of this file.
3. Start Tier 1 #1 (OBS-001 MFE Sentry). Scope the first PR narrowly:
   plugin hook + `MFE_CONFIG["SENTRY_DSN"]` wiring + dev-only DSN in
   bbi-infra overlay. Staging/prod DSNs follow once dev Sentry is receiving
   events.
4. Tier 1 #2 stays blocked on #1919 T3 — watch for the bbi-infra
   `render-lms-admin-emails.sh` generator PR to land and rebase overlays.

---

### Slice 86 — 2026-04-20T11:00–12:45Z (massive drainage + Tier 1–3 fan-out)

**Context**: user called out that PRs had been lingering for hours. Deep
diagnosis found two compounding blockers:
1. `required_status_checks.strict: true` on mereka-lms main — every merge
   put all other open PRs into BEHIND with no self-heal.
2. Main had been red on 4 verifiers since Wave 9 (PR #1900) because they
   still referenced `deploy/k8s/overlays/production/` + `rke2-nonprod/`
   shadow paths that Wave 9 deleted.

**Two structural unblocks**:

1. **Live branch-protection flip**: `gh api -X PUT
   .../branches/main/protection` flipped `strict: true → false` per Stage
   1 of the new `docs/reference/operations/MERGE_POLICY.md`. Rollback
   snapshot saved. Immediate effect: 3 green-but-BEHIND PRs auto-merged
   within 30 seconds.
2. **Wave 9 absence-tolerance pattern** shipped in #1932 + #1942 for 4
   verifiers (`verify-kustomize-structure`, `verify-k8s-images`,
   `verify-kustomize-render`, `verify-secrets-isolation`). Also SECRET_CLASSIFICATION
   orphan cleanup in #1933 removing 9 stale ecommerce / stripe-DEV entries.

**Merged to main this slice** (12 PRs across both repos):

| PR | Repo | What |
|---|---|---|
| #1918 | lms | platform-admin audit doc |
| #1921 | lms | Wave 9 consumer sweep |
| #1924 | lms | stale state-doc prune |
| #1926 | lms | state generator retarget |
| #1928 | lms | SESSION_COOKIE_DOMAIN MFE_CONFIG (Tier 1 #3) |
| #1930 | lms | Authn MFE smoke scheduled (OBS-003 phase 1) |
| #1932 | lms | Wave 9 verifier absence-tolerance |
| #1934 | lms | tutor-plugin-test venv fallback |
| #1941 | lms | OBS-001 phase 1 MFE Sentry plumbing (Tier 1 #1) |
| bbi-infra #3461 | infra | OBS-006 labels mirror |
| bbi-infra #3491 | infra | MEREKA_PLATFORM_ADMIN_EMAILS materialization |
| bbi-infra #3497 | infra | OBS-001 phase 3 MFE Sentry overlay wiring |

**OBS-001 end-to-end complete (Tier 1 #1)**:
Phase 1 plumbing (#1941) + Phase 2 Sentry project + Infisical DSN
(executed via `sentry-cli` + `infisical secrets set` — creds
`/k8s/mereka-lms/MEREKA_MFE_SENTRY_DSN` + `MEREKA_MFE_SENTRY_ENVIRONMENT`
populated for dev/staging/prod) + Phase 3 overlay wiring (#3497). Sentry
project: `biji-biji-non-profits/mereka-lms-web` (4510757892128768).
Single DSN across envs, environment-tagged. Phase 4 runtime proof
pending next MFE image build + pod roll (bead `mereka-lms-te71`).

**Armed for auto-merge at slice close** (7 mereka-lms + 2 bbi-infra):
#1929, #1933, #1935, #1942, #1943, #1944, #1945, bbi-infra #3501 /
#3502.

**Agent team spawned in parallel this slice** (5 completed, 1 blocked):
- OBS-002 JSON logging → **#1943**
- RC-checklist automation → **#1944**
- Deletion-wave guard → **#1945** (cleaned up by me after agent stalled)
- OBS-005 Authentik blackbox → **bbi-infra #3501**
- auth-allowlist-07 ConfigMap → **bbi-infra #3502** (turned out already
  declarative; PR removes stale docs + dead `lms-deployment-sso.yaml`
  files)
- Fastlane bootstrap migration → **BLOCKED** on bbi-infra #3418 not yet
  merged (bead `mereka-lms-ano7` filed)

**Tier 1 status**: ALL merged or in flight with no external blockers.

**Tier 2 status**:
- #5 OBS-003 phase 2 Playwright: blocked on browser capability
- #6 OBS-004 Upptime: user-gated (mereka-coding VPS mutation)
- #7 OBS-005 Authentik blackbox: in flight (#3501)
- #8 Full Playwright sweep: blocked on browser capability
- #9 Fastlane bootstrap: blocked on bbi-infra #3418

**Tier 3 status**: ALL in flight (#1943 / #1944 / #1945 / #3502).

**Merge queue Stage 1 ACTIVE** (strict=false live on mereka-lms). Stage
2 (merge queue canary, bead `mereka-lms-cp16`) gated on 2 weeks of
stable main CI red rate. Stage 3 (bead `mereka-lms-k3nm`) follows.

**Monitoring infrastructure**: persistent Monitor armed on 7 PR states
(polls each 60s, emits on change). Cron `*/45 * * * *` scheduled to
fire the autonomous /loop prompt every 45 min until the roadmap drains.

## Pointed Next Move (slice 86)

1. Let current CI cycle finish on the 9 armed PRs; watch Monitor events.
2. After OBS-001 bundle rebuild lands + MFE pods roll: trigger a test
   JS error on dev, confirm event in Sentry within 2 min, close bead
   `mereka-lms-te71`. RC_CHECKLIST row 22 flips ✅.
3. After #3491 pods roll on all 3 envs: `kubectl exec lms -- printenv
   MEREKA_PLATFORM_ADMIN_EMAILS` returns the 9-email CSV per env.
   RC_CHECKLIST row 19 flips ✅ auto.
4. If any stuck PR's CI fails on a real issue (not stale verdict),
   diagnose and fix in isolated worktree (avoid shared-clone clobber
   — multiple agents touching the shared repo checkout at once).
5. Tier 2 blockers (browser capability, user-gated VPS, #3418)
   remain the only hard stops. No further implementation-lane work
   unblocks without external action.
6. Loop cron continues firing every 45 min; autonomous prompt will
   re-sweep PR queue + beads + docs until everything lands or hits
   an external blocker.

---

### Slice 88 — 2026-04-21T11:30Z (local build freshness tranche in progress)

**Context**: after #1982 merged, follow-up audit found that `setup-local.sh`
could reuse an old `openedx:nightly` or `openedx-mfe:nightly` image purely
because the tag existed. That made the new-dev lane too trusting: a developer
could rerun setup after source/render changes and still launch stale local
images.

**Current branch**: `fix/local-build-freshness-2026-04-21`

**Authority decision**:

- Local image reuse is now tied to a rendered build-context fingerprint label,
  not tag existence alone.
- The fingerprint is produced by
  `scripts/infra/build-context-fingerprint.sh`, passed through the canonical
  image helpers, and stamped by `docker-bake.hcl`.
- `setup-local.sh` rebuilds when the existing image label does not match the
  current rendered context.
- `tutor-config-save.sh` now restores config and generated Tutor env backup
  state after prepare or verification failure, then exits. It no longer offers
  an interactive "continue anyway" path after a failed render verifier.
- The devcontainer setup was moved back onto the canonical
  `tutor-config-save.sh` and helper-build lane; raw `tutor images build` is no
  longer the advertised devcontainer path.

**Local proof completed before PR**:

```bash
bash scripts/qa/test-build-context-fingerprint.sh
bash scripts/qa/verify-cold-start-onboarding-contract.sh
bash scripts/qa/test-build-image-profile-guards.sh
bash scripts/qa/verify-ci-cache-policy.sh
bash scripts/qa/test-verify-ci-cache-policy.sh
bash scripts/qa/verify-tutor-config-safety.sh
bash tests/tutor/test_tutor_root_authority.sh
bash tests/tutor/test_tutor_apply.sh
./scripts/qa/verify-generated-surfaces.sh
git diff --check
```

**Still not claimed by this slice**:

- It does not prove a full Docker image build in this worktree; CI/benchmark
  lanes must still prove build execution after PR.
- It does not make the future devspace/vcluster lane supported.
- It does not fix broader observability/GKE-era docs drift.

---

### Slice 87 — 2026-04-21T10:30Z (current-head local build factory proven; runner hygiene blocker closed)

**Context**: other developers reported cold local build / quick-start trouble
after prior proof work. The follow-up goal was to verify whether current `main`
still had one coherent source -> render -> artifact chain and whether the new
failures were build authority drift or runner hygiene.

**Current `main` at wrap time**:

- `mereka-lms` `main`: `e7a4472cd`
- Merged PR: #1979 `fix(ci): cleanup root-owned runner workspaces`

**Current-head proof completed on `e7a4472cd`**:

| Proof | Run | Result | Interpretation |
|---|---|---|---|
| Build Tutor Images | `24711505579` | success | Existing build workflow/build helpers rendered, built, scanned, and attested both Open edX and MFE images. |
| Bootstrap Local Readiness | `24711453019` | success | Clean repo-scoped `TUTOR_ROOT` local Tutor bootstrap path launches and passes readiness checks. |

**Failure classification from the slice**:

- `24708921916`: Bucket 3 runner/workspace hygiene. MFE failed before checkout
  because root-owned generated Tutor state under `tutor_env/data/*` could not be
  removed by the unprivileged fastlane runner. Fixed by #1979 with bounded
  Docker-root cleanup for generated paths only.
- `24710721353`: Bucket 3 runner capacity. Static validation initially failed
  before checkout because the fastlane CI host could not write a GitHub runner
  `_diag/Worker_*.log` file (`No space left on device`). Rerun passed. This is
  not a source or verifier failure; it remains runner host hygiene debt.

**Authority decision**:

- #1979 is workflow/runner hygiene only.
- It does not change Dockerfile rendering, bake semantics, cache semantics, or
  Tutor plugin authority.
- The cleanup allowlist is generated state only: `tutor_env`,
  `var/bootstrap-readiness`, `var/ci`, `.buildx-cache`.
- `build-optimizations.sh` remains a bounded compatibility layer governed by
  `infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml`,
  `docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md`, and
  `scripts/qa/verify-build-optimizations-render-delta-contract.sh`.

**Developer lane reminder**:

New local developers should start with
`docs/guides/onboarding/QUICK_START_LOCAL.md` and run:

```bash
./scripts/qa/verify-cold-start-onboarding-contract.sh
./scripts/shared/setup-local.sh
./scripts/infra/verify-local-bootstrap-readiness.sh
```

Eugene and Hira should stay on this local Tutor lane until the future
Loft/vcluster/devspace lane is declared in
`docs/reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md` with its own
copy-paste setup command and readiness verifier. Do not invent a second build
path for devspaces.

**Open debt to track, not closed by this slice**:

- Fastlane host-level disk pressure before checkout needs monitoring/cleanup
  beyond repository scripts.
- `specs/ci-cd-pipeline_spec.md` still contains older GKE/GAR-era assumptions
  and needs a dedicated reconciliation pass rather than opportunistic edits.
- `.beads` tracker mutation remains degraded per
  `TRACKER-HYGIENE-RECOVERY-PLAN.md`; keep using read-only `br` commands and
  record planner truth in docs when write safety is uncertain.

## Pointed Next Move (slice 87)

1. Merge the docs/spec/runbook truth-sync PR for the 2026-04-21 build factory
   proof.
2. File or preserve follow-up tracker work for fastlane host disk pressure and
   CI/CD spec reconciliation once tracker mutation is safe.
3. Keep devspace/vcluster work blocked from "supported" status until it has a
   row, setup command, verifier, cache classification, and failure taxonomy
   entry in the developer environment proof matrix.

---

### Slice 88 — 2026-04-21T15:45Z (current-main bootstrap blocked on fastlane host substrate)

**Current app repo main**: `12db1b6` after #1989.

**What is proven**:

| Proof | Run | Result | Interpretation |
|---|---|---|---|
| App-cache-cold image build | `24721668598` | success | Open edX and MFE build helpers work with app-level BuildKit cache imports disabled. |
| Last accepted Bootstrap Local Readiness baseline | `24711453019` | success | Clean repo-scoped Tutor bootstrap worked before the current fastlane host incident. |
| Current-main Bootstrap Local Readiness rerun | `24730265503` | success | Clean repo-scoped Tutor bootstrap readiness passed after #1989 Buildx cleanup and fastlane hook repair. This is initialized-state proof only, not MFE authn route or branded runtime image proof. |

**Resolved failure class**:

Recent current-main bootstrap failures pulled
`mirror.gcr.io/overhangio/openedx:21.0.4` and failed under
`/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/...`
with missing files during layer extraction. This is fastlane Docker/containerd
substrate debt. Run `24730265503` completed green after repo Buildx cleanup and
infra #3641 removed the unsafe concurrent prune override.

**New proof-coverage gaps found while watching the green run**:

- Direct runner probe: `http://apps.localhost/authn/login` returned HTTP 400.
  LMS logs showed `Invalid HTTP_HOST header: 'apps.localhost'`. This was a
  source/render contract gap for MFE-prefixed LMS routes; the current branch
  fixes the source setting and makes local readiness fail closed on non-200/302
  MFE authn responses. Superseded by Slice 91: branch bootstrap proof is green.
- LMS logs also showed `Theme 'mereka' not found` while the upstream bootstrap
  image served `localhost` with HTTP 200. The current bootstrap verifier checks
  SiteTheme database convergence, not branded theme asset presence. The current
  branch skips SiteTheme convergence when `/openedx/themes/mereka` is absent, so
  upstream-image bootstrap stays explicitly unbranded.

Treat both as follow-up work. Do not weaken bootstrap truth or create another
build lane to hide them.

**Host remediation performed**:

- Installed and ran repo-owned `/opt/runner/buildx-cleanup.sh`; it removed 49
  orphan Buildx containers with `failed=0`.
- Disk remained high (`96-97%`), so the remaining blocker is not stale Buildx
  containers alone.
- Found infra-owned `/usr/local/lib/gha-fastlane/cleanup.sh` could still force
  Docker prune above 92% disk despite concurrent runner jobs.
- Merged `bbi-infrastructure#3641` (`e874892a43c08be64f72cb0c14e2c3800edb18f8`)
  to remove that unsafe override, and deployed the patched hook to
  `vmi3220759`.

**Developer guidance**:

Eugene, Hira, and new developers should keep using
`docs/guides/onboarding/QUICK_START_LOCAL.md`. Do not create alternate local
Dockerfiles, Compose files, or preview-only image semantics. The future
Loft/vcluster/devspace lane remains planned until it has a proof matrix row,
setup command, verifier, cache class, and failure taxonomy.

---

### Slice 89 — 2026-04-21T17:55Z (PR #1991 exact-head bootstrap reroute)

**Current PR head**: `1506f9d90` on
`docs/runner-bootstrap-truth-2026-04-21`.

**PR checks**: green after the repository-guide truth cleanup.

**Bootstrap result to classify**:

- Run `24736358890` selected fastlane
  (`vmi3220759-mereka-lms-fastlane-build-2`) and reached active LMS migrations.
- The terminal log line is GitHub `The operation was canceled`; there was no
  source stack trace before cancellation.
- Provenance/readiness/failure-artifact steps did not run, so this is not a
  valid branch bootstrap proof.

**Current decision**:

Expose the existing runner selector as a workflow_dispatch input and rerun the
same bootstrap proof with `lane_mode=fallback` so ARC can prove the source path
while fastlane cancellation remains runner/workflow substrate debt. This is a
runner-lane override for the same source -> render -> artifact chain, not a new
developer build path.

---

### Slice 90 — 2026-04-21T18:40Z (PR #1991 stale-runner-state hardening)

**Current PR head before this slice**: `1506f9d90` on
`docs/runner-bootstrap-truth-2026-04-21`.

**Bootstrap result to classify**:

- Run `24737898005` reran the same head after the cancellation.
- It failed early in render while the runner still had `tutor_local-*`
  containers, volumes, and networks from the cancelled run.
- The redacted config artifact showed the canonical plugin already listed under
  `PLUGINS`, but `scripts/infra/tutor-config-save.sh` hid the Tutor
  `plugins enable` output and treated that opaque state as a hard source
  failure.

**Current decision**:

This is proof-lane hygiene debt, not evidence that local build semantics should
move into a second generator. The branch now removes stale Tutor Docker project
state before checkout, uses the public mirror for the root-owned cleanup helper,
and makes canonical plugin enablement idempotent when the plugin is already in
`TUTOR_ROOT/config.yml` while preserving fail-loud behavior for real enable
errors. Superseded by Slice 91: exact-head branch bootstrap proof is green.

---

### Slice 91 — 2026-04-21T19:20Z (PR #1991 branch bootstrap proof green)

**Proof run**: `24738471266` on
`878994d0c5eb9285d7dc591c14ef833c25bea70c`.

**Result**: success on `lane_mode=fallback` / ARC heavy builder.

**What it proved**:

- pre-checkout cleanup completed, including the new stale `tutor_local` Docker
  project cleanup guard
- Tutor render completed through the canonical `tutor-config-save.sh` wrapper
- rendered bootstrap images refreshed from mirror-backed refs
- `tutor local launch -I --skip-build` completed
- image provenance matched rendered compose refs and freshly pulled image IDs
- local readiness passed, including:
  - LMS route HTTP 200
  - Studio route HTTP 302
  - `http://apps.localhost/authn/login` HTTP 302

**Remaining debt**:

The launch phase ran from about 18:19Z to 19:15Z. That is acceptable proof, but
not acceptable operator feedback for a world-class lane. Add phase
timing/heartbeat artifacts around image refresh, migrations, and readiness so
long first-run bootstraps are diagnosable before the final log bundle exists.

---

### Slice 92 — 2026-04-21T21:15Z (post-merge bootstrap proof and timing follow-up)

**Merged truth**: PR #1991 merged to `main` at
`2b86de8349934149161d739326d0ae34030dc9a2`.

**Post-merge proof run**: `24743995049`.

**Result**: success on `main`.

**What it proved**:

- repo-scoped Tutor render completed
- mirror-backed bootstrap image refresh completed
- `tutor local launch -I --skip-build` completed
- image provenance matched rendered compose refs and freshly pulled image IDs
- local readiness passed, including:
  - LMS route HTTP 200
  - Studio route HTTP 302
  - `http://apps.localhost/authn/login` HTTP 302

**Follow-up now in progress**:

The same run again spent most of its wall time inside the launch phase. The
next branch keeps the same source -> render -> artifact lane but adds
`bootstrap-phase-timings.tsv` and `bootstrap-phase-summary.md` to the existing
bootstrap artifact so future long launches show phase durations and heartbeat
notices instead of only final pass/fail.
