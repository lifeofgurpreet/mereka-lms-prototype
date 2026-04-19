---
title: GKE-auth scheduled workflow classification
type: evidence-bundle
owner: platform-release
observed_at: 2026-04-19T05:00Z
bead: mereka-lms-64a3
status: active
---

# GKE-auth scheduled workflow classification

Bead `64a3` ("Seven active scheduled workflows still route through
`gcp-gke-auth` — produce stale GKE failures that read like app runtime
failures").

This bundle resolves what "active" means per workflow, grounded in the
GitHub Actions API at observation time.

## Authoritative state at 2026-04-19T05:00Z

Source: `GET /repos/Biji-Biji-Initiative/mereka-lms/actions/workflows`.

| Workflow | API state | Actually fires? | GKE refs | Recent 5 runs | Operator signal today |
|----------|-----------|-----------------|---------:|---------------|-----------------------|
| `post-deploy-e2e.yml` | `active` | yes, on `workflow_run` from Build Tutor Images | 5 | `success,success,success,success,success` (recent default lane is staging E2E) | **amber** — prod-parked-state job path still tries GKE auth when triggered with `env=production`; fails as "Authenticate to GCP and get GKE credentials" |
| `cloud-sql-backup.yml` | `active` | yes, schedule `0 18 */3 * *` | 2 | `skipped,skipped,skipped,skipped,skipped` | **green** — job gated on `vars.ENABLE_CLOUD_SQL_BACKUPS == 'true'` (unset) |
| `argocd-drift-check.yml` | `disabled_manually` | no | 5 | `failure,failure,failure,failure,failure` (last 2026-03-14) | **green-today / red-on-reenable** — disabled since 2026-03-14 |
| `daily-infrastructure-audit.yml` | `disabled_manually` | no | 14 | `failure,failure,failure,failure,failure` (last 2026-03-14) | **green-today / red-on-reenable** — same 2026-03-14 dormancy |
| `dr-evidence-bundle.yml` | `disabled_manually` | no | 5 | `failure,failure,failure,failure,failure` | **green-today / red-on-reenable** |
| `mfe-slot-runtime-gates.yml` | `disabled_manually` | no | 5 | `failure` (only 1 historical run) | **green-today / red-on-reenable** |
| `operations-gates-runtime.yml` | `disabled_manually` | no | 5 | `failure,failure,failure,failure,failure` (last 2026-03-14) | **green-today / red-on-reenable** |

Repo variables relevant to gating:

- `GCP_WIF_PROVIDER` / `GCP_WIF_SA`: **not set** → any step gated on these
  skips.
- `ENABLE_CLOUD_SQL_BACKUPS`: **not set** → `cloud-sql-backup` job skips.
- `CI_FASTLANE_*`, `OPERATIONS_GATES_RUNTIME_ENV_SCOPE=staging`,
  `RUN_AUTHENTICATED_SSO_CANARY=true` are set.

Production kubernetes state:

- **`rke2-prod` context** (authoritative for production):
  - Namespace `mereka-lms` exists, 30 deployments Running (2026-04-19T06:00Z).
  - ArgoCD Application `mereka-lms-prod` present, OutOfSync/Healthy.
  - lms 2/2, cms 1/1, mfe 1/1, enterprise-access/catalog/subsidy/admin/learner
    all 1/1, plus MySQL, Redis, Meilisearch, Caddy, xqueue, ralph, ClickHouse,
    Superset, payments stack.
- **`rke2-nonprod` context** (where this repo's CI runs):
  - No `mereka-lms-prod` namespace (production does not run here).
  - Live namespaces: `mereka-dev`, `mereka-lms-dev`, `mereka-staging`,
    `stg-mereka-lms`.
- **Bead 64a3's "seven stale workflows" assumed a parked-prod reality.
  That assumption is stale.** Production is live on a separate cluster
  not reachable from the CI context via `gcp-gke-auth`. The correct
  verification lane is either (a) public HTTPS probe + cookie assertions
  on https://academyv2.mereka.io, or (b) cross-cluster kubectl (via
  rke2-prod kubeconfig secret) — neither of which is what the current
  `prod-parked-state` job does.

Runtime proof policy (`config/runtime-proof-policy.env`):

- `PROD_RUNTIME_MODE=parked` — **stale**. Production is in fact LIVE on
  `rke2-prod` cluster, namespace `mereka-lms` (verified 2026-04-19T06:00Z:
  30 deployments Running — lms 2/2, cms 1/1, mfe 1/1, full enterprise
  stack, MySQL, Redis). https://academyv2.mereka.io returns HTTP 200
  with live Django LMS body (195KB, csrf + sessionid cookies, tenant
  header). The "parked" mode in this file predates the RKE2 migration
  and was never retracted.
- `POST_DEPLOY_WORKFLOW_RUN_ENV=production` — drives the post-deploy E2E
  gate to the prod-parked-state job when triggered by Build Tutor
  Images. With `PROD_RUNTIME_MODE=parked` still set, the gate routes to
  the parked-verifier path which fails on GKE auth (GKE decommissioned).

## Classification

Using the three categories from bead `64a3`:

### A. Stale-actively-misleading (real operator impact)

1. **`post-deploy-e2e.yml` prod-parked-state job** — the only workflow
   in this set that still generates a user-visible failure on routine
   events. When the prod build path kicks off Build Tutor Images, this
   workflow fires on `workflow_run` → resolves to `env=production` via
   policy → dispatches the `prod-parked-state` job → fails at the
   `Authenticate to GCP and get GKE credentials` step.

   The failure shows up as a commit status on the graduation SHA and
   reads to operators as a runtime problem, but it's purely the
   decommissioned GKE auth path. Example: run 24591547989 on
   `d0580feef`.

   **Fix shape (revised after observing production truth):** production
   is NOT parked. The `prod-parked-state` job verifies a reality that
   no longer exists. Correct fix is one of:
     (a) **Retire parked mode entirely**: set `PROD_RUNTIME_MODE=active`
         in `config/runtime-proof-policy.env`, remove the prod-parked-state
         job, let the `e2e-critical-paths` job run against
         https://academyv2.mereka.io using the same Playwright flow that
         runs against staging today. This matches reality and removes
         the GKE dependency in one move.
     (b) **Teach the existing parked-verifier about rke2-prod**: rewrite
         `scripts/qa/verify-prod-parked-state.sh` to accept a
         `rke2-prod` kubeconfig secret, point at `mereka-lms` namespace,
         and invert the assertion (expect workloads Running, not at 0).
         This is more invasive and still leaves a "parked" label that
         doesn't match reality.
   (a) is the truthful, lower-line-count, lower-surprise path.

### B. Dormant-but-fragile (time-bombs on re-enable)

2. **`operations-gates-runtime.yml`** — disabled 2026-03-14. GKE auth is
   conditionally-gated on `vars.GCP_WIF_PROVIDER != ''` — when that was
   set historically, the workflow actually ran; today the step would
   skip, but downstream `if: env.CAN_RUN_RUNTIME == 'true'` chain means
   runtime assertions silently skip too. Re-enabling without setting the
   vars masks half the purpose (alert routing, enterprise runtime audit,
   strict-runtime asserts).

3. **`mfe-slot-runtime-gates.yml`** — disabled. Same shape: needs runtime
   access to assert MFE slots live.

4. **`argocd-drift-check.yml`** — disabled. ArgoCD now lives on
   `rke2-nonprod`, not GKE. This check must be rewritten for the RKE2
   control plane or deleted in favor of the `rke2-argo-watcher` surface
   (see `bbi-infrastructure`).

5. **`dr-evidence-bundle.yml`** — disabled. DR evidence generation
   depended on live cluster introspection; post-migration the
   authoritative DR evidence is in `bbi-infrastructure` and recent
   `docs/ops/evidence/` bundles.

6. **`daily-infrastructure-audit.yml`** — disabled since 2026-03-14. The
   Phase 3 Tier-A scorecard job inside this host is now served by
   standalone `code-quality-scorecard.yml` (PR #1860). Remaining 6 jobs
   inside the host remain dormant pending individual triage.

### C. Historical-only / no action needed

7. **`cloud-sql-backup.yml`** — job gated on
   `ENABLE_CLOUD_SQL_BACKUPS=true` (unset). Skipped cleanly, no failure
   noise. Production MySQL has moved to in-cluster on RKE2 with Velero
   backing up PVCs (per the workflow's own "Note" step). This workflow
   can be deleted as part of the final GKE cleanup, but it is not
   generating signal now.

## Recommended next moves (for a future slice, not this one)

Per the reviewer directive in effect (no new Batch 3 expansion PRs),
these are documented but not opened now.

| ID | Workflow | Proposed PR scope | Risk |
|----|----------|-------------------|------|
| A1 | `post-deploy-e2e.yml` | **retire prod-parked-state job**; set `PROD_RUNTIME_MODE=active`; run production E2E through `e2e-critical-paths` against https://academyv2.mereka.io (same shape as staging today). Production is LIVE, parked-mode is stale, GKE auth is decommissioned — all three problems collapse into one rewrite. | medium — policy + workflow + verifier retirement + ensure SSO_CANARY_*_PROD secrets still flow |
| B1 | `argocd-drift-check.yml` | delete workflow; reference the bbi-infrastructure `rke2-argo-watcher` surface in docs | low — already disabled, no runtime signal to preserve |
| B2 | `dr-evidence-bundle.yml` | delete workflow; link to canonical DR evidence bundles | low — already disabled |
| B3 | `operations-gates-runtime.yml` | split into `public-surface-gate` (no GKE) and `runtime-gate` (RKE2-aware). Disabled workflow stays disabled until RKE2 side is written. | medium — rewrite |
| B4 | `mfe-slot-runtime-gates.yml` | same split — public MFE probe vs RKE2 pod-level assertion | medium |
| B5 | `daily-infrastructure-audit.yml` | narrow scope: remove GKE-dependent jobs, keep secret-rotation and parity checks where possible | medium |
| C1 | `cloud-sql-backup.yml` | delete workflow after confirming production DB is in-cluster on RKE2 + Velero coverage is active | low — no operator signal |

The A1 fix is highest-leverage: it's the only workflow generating
user-visible noise today. B1 / B2 / C1 are cleanup (close-out of
disabled surfaces). B3 / B4 / B5 are rewrites, not fixes — schedule
accordingly.

## Invariants worth capturing

1. **An "active" workflow is not the same as an "emitting" workflow.**
   Five of the seven bead-cited workflows are already `disabled_manually`
   — they have not emitted failure signals since 2026-03-14. The bead's
   "seven active scheduled workflows" framing was tracker-stale;
   corrected here.

1a. **Check production reality on rke2-prod, not rke2-nonprod.** A prior
    draft of this doc claimed "production is truly parked at zero
    replicas (no namespace exists on RKE2 either)" based on checking
    rke2-nonprod. That was wrong — rke2-prod is a separate cluster
    (different kubeconfig context), and it runs the real production
    workload. The `--context rke2-nonprod` discipline from AGENTS.md
    guards against ambient-context drift for dev checks, but the same
    discipline requires `--context rke2-prod` for prod checks.

2. **`workflow_run` triggers bypass the `schedule`-based disable.** Even
   if a workflow is disabled via UI, `workflow_run` triggers off a
   separate workflow can still cause it to execute. `post-deploy-e2e` is
   `active` and fires on Build Tutor Images completion; its production
   path then routes to a GKE-auth step that always fails. This is the
   only live-signal offender.

3. **The 2026-03-14 dormancy cliff** corresponds to when the RKE2
   migration reached "production parked / dev live" state and the
   GKE-dependent audit workflows stopped making sense. Five workflows
   were manually disabled rather than fixed; the debt sits here.

## Related

- Bead: `mereka-lms-64a3`
- Prior surface-classification doc:
  `docs/status/active/OPENEDX_NEXT_PHASE_PLAN_2026-04-18.md` (Phase 3 + 4)
- Prior scorecard recovery: `#1860`
- Rolling state: `docs/status/active/CURRENT-OPERATOR-STATE.md`
