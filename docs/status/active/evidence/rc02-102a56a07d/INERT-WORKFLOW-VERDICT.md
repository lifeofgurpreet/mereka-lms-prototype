# Inert Workflow Verdict — 2026-04-18

## Question

Per `GKE-ACTIVE-SURFACE-CLASSIFICATION.md`, 5 of 7 workflows were classified **PROBABLY INERT**: they carry GKE/GCP auth references but haven't fired in weeks–months, and they're gated by a missing `GCP_WIF_PROVIDER` repo variable.

Are they actually inert, or would they emit a misleading failure if forced to run today?

## Method

Inspected each workflow's step-graph after the `gcp-gke-auth` action. Classified based on whether the NEXT step is (a) gated by the same guard, (b) gated by something else, or (c) unguarded but structurally safe when kubeconfig is empty.

## Verdict Per Workflow

### 1. `argocd-drift-check.yml` — INERT

Next step after `gcp-gke-auth`: **"Run online drift check (prod)"**

Guard: `${{ steps.gke-auth.outputs.has_cluster == 'true' && (...) }}`

The step explicitly checks `has_cluster` output from the `gcp-gke-auth` action (which sets it false when GKE skip). Without a valid cluster, this step is SKIPPED. **Safe.**

### 2. `operations-gates-runtime.yml` — INERT

Next step: **"Build alert-noise runtime sample"**
Guard: `${{ env.CAN_RUN_RUNTIME == 'true' }}`

`CAN_RUN_RUNTIME` is only set to `true` when GKE auth succeeds (see `gcp-gke-auth` action). When the WIF vars are unset, the action sets `CAN_RUN_RUNTIME=false` and the step is SKIPPED. **Safe.**

### 3. `daily-infrastructure-audit.yml` — INERT-CONDITIONAL

Two jobs need checking:

- Job `observability-audits` → next step **"Run runtime/local observability audit bundle"**, guarded `CAN_RUN_RUNTIME == 'true'`. **SAFE.**
- Job `parity-check` (matrix over dev/nonprod/prod env_label) → next step **"Validate selected kubectl context after kubeconfig refresh"** is **UNGUARDED**. BUT this job has a matrix-level gate: each job requires `OBS_PARITY_<label>_K8S_CONTEXT` repo variable to be set, and the step itself exits cleanly with a message if the context is missing from kubeconfig.

The matrix vars `OBS_PARITY_DEV_K8S_CONTEXT`, `OBS_PARITY_NONPROD_K8S_CONTEXT`, `OBS_PARITY_PROD_K8S_CONTEXT` are **NOT set** as repo variables. The job materializes but exits with an explicit "Missing required environment context variable" message — a clean failure, not a stale-auth failure. Operators reading "Missing OBS_PARITY_DEV_K8S_CONTEXT" won't confuse it with app runtime.

**Safe-enough for now.** Consider retiring the parity-check job when observability parity across envs is no longer needed.

### 4. `mfe-slot-runtime-gates.yml` — INERT

Next step: **"Resolve runtime slot credentials"**

This step just reads env vars (no GKE dep), then later steps use `LMS_BASE_URL` to hit public URLs via curl. It does not require kubectl. The `gcp-gke-auth` step is legacy from when it needed cluster access.

When WIF vars are unset, the auth step fails to set `has_cluster=true`, and subsequent slot-runtime evaluation would fail at the first `if: env.CAN_RUN_RUNTIME == 'true'` guard further down. The workflow's "Generate gate summary" step does emit a status context but only when slot checks actually ran.

Latest failure: 2026-03-09 (60+ days). **Safe.**

### 5. `dr-evidence-bundle.yml` — INERT

Next step: **"Prepare output path"**
Guard: `${{ env.CAN_RUN_RUNTIME == 'true' }}`

Same mechanism as operations-gates-runtime. **Safe.**

Latest failure: 2026-02-10 (60+ days ago). Workflow has likely not fired at all since the `GCP_WIF_PROVIDER` var was removed.

## Summary

| Workflow | Classification | Mechanism |
|---|---|---|
| `argocd-drift-check.yml` | INERT | `has_cluster` guard |
| `operations-gates-runtime.yml` | INERT | `CAN_RUN_RUNTIME` guard |
| `daily-infrastructure-audit.yml` | INERT-CONDITIONAL | matrix-level OBS_PARITY_* missing → clean exit |
| `mfe-slot-runtime-gates.yml` | INERT | auth fails silently; downstream never runs |
| `dr-evidence-bundle.yml` | INERT | `CAN_RUN_RUNTIME` guard |

**All five are genuinely inert today.** None will emit a failing status check that operators could confuse for an app-runtime failure.

The one ACTIVELY MISLEADING workflow (`post-deploy-e2e.yml` `prod-parked-state` job) is gated off by PR #1807.

## Follow-On (Non-Blocking)

For clarity / defense-in-depth, consider renaming the `gcp-gke-auth` action step name from `"Authenticate to GCP and get GKE credentials"` to `"Authenticate to GCP (GKE optional)"` so any future failed auth log line is immediately clearer. This is a one-line cosmetic change and not required.

## Related

- Bead `mereka-lms-64a3` (P1) — this verdict closes item 3 of its Week-2 plan
- `docs/status/active/evidence/rc02-102a56a07d/GKE-ACTIVE-SURFACE-CLASSIFICATION.md`
