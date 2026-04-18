# Independent Remote Audit - 2026-04-18

This note records an independent verification pass run directly on `ssh mereka` against the live cluster, the server-side repo checkouts, and the GitHub workflow/artifact trail.

The goal was to test whether the recent "RC-01 through RC-06 are closed" narrative holds up under adversarial inspection, then re-check the system after the claimed RC-07 graduation cycle.

## Scope

Checked directly from `ssh mereka`:

- `~/projects/k8s/mereka-lms`
- `~/projects/bbi-infrastructure`
- `~/projects/k8s/bbi-infrastructure`
- Argo app `mereka-lms-dev` in namespace `argocd`
- Namespace `mereka-lms-dev` on `rke2-nonprod`
- GitHub runs and artifacts for:
  - app build `24590743862`
  - promote run `24591542962`
  - post-deploy gate `24591547989`
- Public runtime surfaces:
  - `https://apps.academyv2.mereka.dev/api/mfe_config/v1`
  - `https://apps.skillourfuture.academyv2.mereka.dev/api/mfe_config/v1`
  - `https://apps.academy.biji-biji.com/api/mfe_config/v1`
  - `https://apps.academyv2.mereka.dev/authn/login`
  - `https://apps.academyv2.mereka.dev/theme/core.min.css`
  - `https://apps.academyv2.mereka.dev/theme/mereka-brand.min.css`

## Verified Truths

### 1. The promoted artifact chain is real

For app commit `102a56a07d3270bb61d7c95b28d6ed0d67919360`:

- app build run `24590743862` completed successfully
- release-bundle artifact exists on GitHub
- promote run `24591542962` completed successfully
- deployment specs and live pod imageIDs agree on:
  - `openedx@sha256:d17ae77f533be1690b969b220b3507c4d9780ef7f477ecd5c47e2b7777b54578`
  - `mfe@sha256:377923c0a2ce22c8e7bac7baf488c80f345a1445e2f7ac47b5c29e5b475b35e1`

This part of the conveyor is not fake.

### 1b. A second artifact also graduated through the conveyor

The later app commit `d0580feefd53580d378e1d9254d5e38dc5dfe066` also made it through build, promotion, Argo, and live web deployment.

Current live deployment specs on `rke2-nonprod` now point at:

- `openedx@sha256:aceac3676a18ad5e238b5106122bd4b5cd1c9a21c94cdd995030d4a1445408ea`
- `mfe@sha256:8314b1538d27ff2da896db6f121e1da96b152f1230a7b3045a4b2abe103a8548`

Current live readiness split:

- `lms`, `cms`, `mfe`: `1/1 Ready`
- `lms-worker`: `0/3 Ready`
- `cms-worker`: `0/2 Ready`

So the conveyor has been proven for a second organic push-to-main, but runtime closure is still asymmetric because the worker probe defect carries forward.

### 2. The saved RC-02 evidence packet matches the GitHub artifact

On the VPS, the following saved files under
`docs/status/active/evidence/rc02-102a56a07d/`
hash-match the files downloaded from the GitHub `release-bundle` artifact for run `24590743862`:

- `release-bundle.json`
- `release-object.json`
- `promotion-dispatch-envelope.json`
- `release-gate-envelope.json`
- `truth-ledger.json`

This is strong evidence that the packet was copied from the real workflow outputs, not hand-written afterward.

### 3. Product-surface tenant isolation is real

These endpoint checks all returned `HTTP 200` and tenant-correct values:

- `apps.academyv2.mereka.dev/api/mfe_config/v1`
  - `LMS_BASE_URL=https://academyv2.mereka.dev`
  - `SITE_NAME=Mereka Academy`
- `apps.skillourfuture.academyv2.mereka.dev/api/mfe_config/v1`
  - `LMS_BASE_URL=https://skillourfuture.academyv2.mereka.dev`
  - `SITE_NAME=Skill Our Future Academy`
- `apps.academy.biji-biji.com/api/mfe_config/v1`
  - `LMS_BASE_URL=https://academy.biji-biji.com`
  - `SITE_NAME=Biji-Biji Academy`

The public login page and theme CSS endpoints also returned `HTTP 200`.

### 4. The worker readiness issue is real

Live state:

- `lms-worker` ready replicas: `0/3`
- `cms-worker` ready replicas: `0/2`
- both worker deployments run the new readiness probe:
  - `celery -A <lms|cms> inspect ping -t 15`

At the same time, worker logs show Celery reaching `ready` and the pods are using the correct promoted image digest.

This is not a fake defect, but it is separate from the post-deploy workflow failure.

## Gaps and Contradictions

### 1. The VPS repo checkouts are not clean canonical mirrors

`~/projects/k8s/mereka-lms` was not on `main` during inspection:

- current branch: `fix/release-object-defensive-help-and-rc05-addendum-20260418`
- local `main`: `330fd0f98...`
- `origin/main`: `9211c5479...`

`~/projects/bbi-infrastructure` local `main` is behind `origin/main`:

- local `main`: `2b94a4c5...`
- `origin/main`: `8e80444f...`

Implication:
server-side repo state can support evidence review, but it is not a trustworthy "canonical checkout" without first checking branch and fetch state.

This remained true after the later graduation cycle:

- `mereka-lms` still had untracked status and evidence docs on the feature-branch checkout
- `bbi-infrastructure` local `main` still lagged `origin/main`
- neither checkout should be treated as self-canonical just because it lives on the VPS

### 2. The agent report conflated deployed revision and current repo head

Live Argo state at audit time:

- sync status: `Synced`
- health status: `Progressing`
- operation phase: `Succeeded`
- synced revision: `d7a69665d7072063511a1eea17a247b940eeb74a`

This is not the same as current `bbi-infrastructure origin/main` (`8e80444f...`).

The image chain can still be correct, but "currently deployed revision" and "current repo head" are separate facts and must not be flattened into one field.

### 3. RC-02 is evidenced, but not fully reproducible from the VPS checkout alone

A clean rerun of:

`bash scripts/qa/verify-release-object.sh docs/status/active/evidence/rc02-102a56a07d/release-object.json`

failed on the VPS because the required
`platform-control-plane/contracts/release-object-projection-schema.yaml`
was not discoverable from any of the default locations, and no matching schema file was found anywhere under ``~``.

Implication:

- the saved packet is real
- but the verifier cannot currently be rerun independently on the VPS without restoring or wiring the control-plane contract checkout

This is a reproducibility gap, not a fabricated-evidence gap.

### 4. The failed post-deploy workflow is not a dev runtime failure

The failed run `24591547989` did **not** fail in end-to-end browser testing.

Actual failure path:

- workflow: `post-deploy-e2e.yml`
- failing job: `Verify Production Parked State`
- failing step: `Authenticate to GCP and get GKE credentials`
- `E2E Critical Path Tests` job was skipped

The repo's own runbook and workflow text make clear that this workflow currently mixes:

- automatic production parked-state verification
- optional staging/browser proof

Implication:

- this failure should not be used as evidence that the current dev artifact is runtime-broken
- it is workflow/control-plane debt unless separately tied to a live runtime defect

### 5. There are still active GitHub workflows and docs wired to stale GKE/GCP assumptions

There is a large amount of historical GKE/GCP material in the repos, but some of it is still active enough to generate misleading operator signal.

Active workflow surfaces in `mereka-lms` that still route through `.github/actions/gcp-gke-auth` or `GKE_*` variables:

- `.github/workflows/post-deploy-e2e.yml`
- `.github/workflows/argocd-drift-check.yml`
- `.github/workflows/operations-gates-runtime.yml`
- `.github/workflows/daily-infrastructure-audit.yml`
- `.github/workflows/mfe-slot-runtime-gates.yml`
- `.github/workflows/dr-evidence-bundle.yml`
- `.github/workflows/cloud-sql-backup.yml` (explicitly marked legacy, but still present as a workflow)

The shared composite action is internally annotated as "GKE decommissioned" and will skip cluster credential fetching when `gke_cluster` is empty, but the calling workflows still expose:

- step names like `Authenticate to GCP and get GKE credentials`
- `GKE_CLUSTER_PROJECT`, `GKE_CLUSTER_LOCATION`, `GKE_CLUSTER_NAME`
- failure modes that still read like cluster/runtime failures to operators

Active non-historical docs or scripts that still encode stale control-plane assumptions include:

- `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md` still says `prod | gke`
- `docs/reference/architecture/ASPECTS_DEPLOYMENT_READINESS.md` still assumes GKE storage, capacity, and GCP Secret Manager specifics
- `docs/reference/operations/CAPABILITY_MATRIX.md` still describes secrets as `Infisical -> GCP SM -> K8s`
- `scripts/bootstrap/bootstrap-cluster-access.sh` still treats a legacy GKE context as part of normal bootstrap verification
- `scripts/setup-dns.sh`, `scripts/cost-management.sh`, and `scripts/generate-topology-diagram.sh` still describe or emit GKE-era operational models

### 6. The stale parent overlay digest is real debt but not the active authority

In `bbi-infrastructure`:

- `apps/mereka-lms/overlays/dev/kustomization.yaml` still pins old `openedx` digest `sha256:87c04e6d...`
- `apps/mereka-lms/overlays/profiles/dev/kustomization.yaml` pins the live digest `sha256:d17ae77f...`

Argo app source path is `apps/mereka-lms/overlays/profiles/dev`, and the live deployment spec/pods match the profile override.

Implication:

- the stale parent overlay is real configuration debt
- but it was not the authority path for the live deployment inspected here

## Current Status Reading

### Closed enough for the web-serving conveyor path

- RC-01 source/build truth for `102a56a07d`
- RC-03 promotion dispatch for the audited artifacts
- RC-04 deployment image realization at the digest level for both the earlier and later artifact
- RC-06 public product-surface tenant routing and CSS presence
- RC-07 organic graduation proof for the later `d0580feef...` artifact on the web-serving path

### Not honestly closed

- RC-02 reproducibility on the VPS
  - evidence exists
  - verifier rerun depends on missing platform-control-plane schema checkout
- RC-05 runtime readiness
  - workers remain `0/N Ready`
  - even though they appear functionally alive
- operator/control-plane truth
  - active workflows and active docs still encode GKE/GCP-era assumptions strongly enough to mislead
- VPS canonicality
  - server checkouts are still not safe to treat as the source of truth without preflight

## Immediate Recommendations

1. Normalize the VPS checkouts before using them as canonical operator ground truth.
At minimum:
- fetch both repos
- align the intended branch
- record branch + local head + origin head before any conclusion

2. Restore or document the required `platform-control-plane` contract checkout on `ssh mereka`.
This turns the RC-02 packet from "saved and believable" into "independently reproducible."

3. Split the worker readiness defect from the post-deploy workflow defect.
Do not let the GKE parked-state failure masquerade as dev runtime truth.

4. Audit and reclassify every active GKE/GCP-touching workflow and operator doc into one of:
- still required for the real system
- stale but harmless
- stale and actively misleading

5. Remove the stale `images:` block from `apps/mereka-lms/overlays/dev/kustomization.yaml` when convenient.
This is not today's blocker, but it is unnecessary second-authority debt.

## Bottom Line

The recent work is less glamorous than the strongest narrative claimed, but it is not fake.

What is real:

- the promoted artifact
- the digest chain
- the saved RC-02 packet
- the tenant-correct product surface
- the web-serving graduation path for a second artifact

What is still weak:

- clean reproducibility of RC-02 on the VPS
- runtime closure for worker readiness
- the post-deploy gate's signal quality
- trustworthiness of the VPS repo checkouts as canonical mirrors
- active workflow and documentation surfaces that still teach the wrong control-plane model
