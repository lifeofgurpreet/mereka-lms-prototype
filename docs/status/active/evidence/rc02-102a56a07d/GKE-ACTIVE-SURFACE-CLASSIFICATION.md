# GKE/GCP Active-Surface Classification — 2026-04-18

## Why classify

Per feedback 2026-04-18: **do NOT do a blind string-replace of `GKE`/`GCP`.** Classify every active surface into one of three buckets first:

- **HARMLESS** — historical-only, no fire trigger, doesn't mislead operators today
- **STILL-REQUIRED** — touches a real surviving GCP service (Cloud SQL, Secret Manager, Artifact Registry, IAM / WIF), must not be removed
- **ACTIVELY MISLEADING** — fires on schedule or workflow_run, fails at a GKE-auth step, and produces a failure signal that operators read as runtime or app failure

Only then edit, and only the ACTIVELY MISLEADING surfaces.

## Workflow Classification

| Workflow | Triggers | Guards | Recent conclusion | Class | Why |
|---|---|---|---|---|---|
| `post-deploy-e2e.yml` | `workflow_run`, `workflow_dispatch` | guarded=1 (partial), `skip_gke=0` | **failure today 03:05Z** | **ACTIVELY MISLEADING** | Runs on every build workflow_run; fails at `Authenticate to GCP and get GKE credentials` while labelled `Verify Production Parked State`. Operators see "Post-Deploy E2E Gate FAILED" in the PR checks — reads as runtime break. It actually checks decommissioned GKE parked-state. |
| `argocd-drift-check.yml` | `schedule`, `workflow_run`, `workflow_dispatch` | guarded=2 | failure 2026-03-14 (40+ days ago) | **PROBABLY INERT** | Last failure predates `GCP_WIF_PROVIDER` being removed from repo vars. Guard `if: vars.GCP_WIF_PROVIDER != ''` likely short-circuits today. Verify with one forced run before declaring inert. |
| `operations-gates-runtime.yml` | `schedule`, `workflow_dispatch` | guarded=2 | failure 2026-03-14 | **PROBABLY INERT** | Same as above. `OPERATIONS_GATES_RUNTIME_ENV_SCOPE=staging` var exists (2026-03-26). Verify one run. |
| `daily-infrastructure-audit.yml` | `schedule`, `workflow_dispatch` | guarded=4, has explicit `# GKE decommissioned` comments | failure 2026-03-14 | **PROBABLY INERT** | Explicitly acknowledges GKE decommissioned in comments. Guards keep it from running. |
| `mfe-slot-runtime-gates.yml` | `schedule`, `workflow_dispatch` | guarded=2 | failure 2026-03-09 (60+ days ago) | **PROBABLY INERT** | Very old failure. |
| `dr-evidence-bundle.yml` | `schedule`, `workflow_dispatch` | guarded=2 | failure 2026-02-10 (2+ months) | **PROBABLY INERT** | Oldest failure; likely hasn't fired in months. |
| `cloud-sql-backup.yml` | `schedule`, `workflow_dispatch` | guarded=2, **`skip_gke: 'true'`** | **skipped** (gated by `ENABLE_CLOUD_SQL_BACKUPS=true` var, not set) | **STILL-REQUIRED (CORRECTLY GATED)** | Uses GCP for Cloud SQL (real surviving service) NOT GKE. Action sets `skip_gke: 'true'`. Workflow correctly opts out of compute-side GKE. Works as designed when enabled. **Leave alone.** |

**Verified facts supporting the classification:**

`gh variable list` on Biji-Biji-Initiative/mereka-lms shows:
```
CI_FASTLANE_BUILD_LABEL
CI_FASTLANE_CI_LABEL
OPERATIONS_GATES_RUNTIME_ENV_SCOPE
RUN_AUTHENTICATED_SSO_CANARY
```

`GCP_WIF_PROVIDER` and `GCP_WIF_SA` are **NOT** set as repo variables. Workflows guarded `if: vars.GCP_WIF_PROVIDER != ''` simply short-circuit their GCP auth step, but the rest of the job still runs — and if the rest of the job assumes GKE credentials are available it will fail downstream. The 6 "probably inert" workflows need each to be verified individually.

The only workflow that is explicitly, currently, today producing a failing signal that reads like app runtime trouble is `post-deploy-e2e.yml`. **It is Priority 1.**

## Active-Doc Classification

| Doc | Claim | Class |
|---|---|---|
| `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md` | Line 16: `prod \| gke \| 1 \| n/a` | **ACTIVELY MISLEADING** — directly contradicts reality (prod runs on RKE2 Contabo VPS fleet). Update. |
| `docs/reference/architecture/ASPECTS_DEPLOYMENT_READINESS.md` | No GKE prod claims detected on re-read | **HARMLESS** — leave alone |
| `docs/reference/operations/CAPABILITY_MATRIX.md` | No GKE prod claims detected on re-read | **HARMLESS** — leave alone |

The Operator Brief listed four scripts as potentially stale:
- `scripts/bootstrap/bootstrap-cluster-access.sh` → **NOT FOUND** (already deleted)
- `scripts/setup-dns.sh` → **NOT FOUND** (already deleted)
- `scripts/cost-management.sh` → **NOT FOUND** (already deleted)
- `scripts/generate-topology-diagram.sh` → **NOT FOUND** (already deleted)

So the script-side debt has already been paid (or needs confirmation they moved somewhere). No action on scripts this pass.

## Recommended Week-2 Work (per Operator Brief)

Priority order:

1. **`post-deploy-e2e.yml` — split `Verify Production Parked State` out of the post-deploy gate narrative.** Either:
   - Remove the job entirely (GKE is decommissioned; parked-state doesn't apply)
   - Rename the status context so "post-deploy/production-parked-state" does NOT imply runtime/browser truth
   - Guard it with an explicit `if: vars.ENABLE_GKE_PARKED_STATE_GATE == 'true'` + leave the var unset
   - Preferred: remove; GKE is permanently decommissioned per global rules. The parked-state contract is not a thing anymore.

2. **`TEAM_TOPOLOGY_REFERENCE.md` — fix the `prod | gke` claim.** Replace with the true current topology (RKE2 on Contabo VPS fleet). One-line doc edit.

3. **Verify the 5 "PROBABLY INERT" workflows are actually inert.** Either:
   - Force one workflow_dispatch of each
   - Confirm the guard short-circuits AND the rest of the job gracefully skips
   - If any job still emits a "failure" check after its GCP auth step gates off, treat that workflow as ACTIVELY MISLEADING and fix it

4. **`.github/actions/gcp-gke-auth/action.yml` — rename or annotate the failure message.** Currently the step says `Authenticate to GCP and get GKE credentials`. When it fails, operators see that string and assume GKE is broken. Since the action already defaults `skip_gke: true`, the step name should be `Authenticate to GCP (optionally GKE)` and the error message should distinguish "auth failed" from "GKE skipped by design".

5. **Leave `cloud-sql-backup.yml` alone.** It's correctly gated and touches a real surviving GCP service.

## Do NOT Do

- **No mass sed-replace of `GKE`.** Every reference needs the three-way classification above.
- **No edits to historical docs** (anything under `docs/archive/` or prefixed `*_history_*`).
- **No removal of `gcp-gke-auth` action** — Cloud SQL + Artifact Registry + Secret Manager workflows still need GCP auth without GKE.

## Work Items

- `mereka-lms-64a3` (P1): this classification is the plan for Week 2. Implementation PR should be surgical — 1 workflow change + 1 doc edit + 1 optional step-name rename.

## Appendix: One-line summary

**Only `post-deploy-e2e.yml` is actively misleading today. One doc (`TEAM_TOPOLOGY_REFERENCE.md` line 16) says prod is GKE. Everything else is either inert-behind-a-guard or correctly-using-GCP-for-real-services.**
