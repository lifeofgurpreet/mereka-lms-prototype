# Deployment Parity and AC Gap Review

_Date: 2026-02-25_

## Executive Summary

I reviewed the repo as a reviewer only (no implementation changes) and focused on what is currently delivered vs what is still planned for non-production parity and release readiness.

- **Where we are strongest:** core LMS/CMS platform and many baseline MFEs are already in repo and tests/speccing exist.
- **Primary blockers for staging/dev parity:** non-production rollout path is not unified in active GitOps flow, and several deployment observability/ops specs are still only partially implemented.
- **Primary recommendation:** treat `rke2-nonprod` as the canonical non-production deployment track, keep `staging` overlay as deprecated historical artifact, and route all new parity work through:
  - `deploy/k8s/overlays/rke2-nonprod`
  - `deploy/k8s/base`
  - `deploy/k8s/overlays/production` as separate release target
  - tracker + AC closure in `ci-cd-pipeline_spec`, `k8s-deployment_spec`, `email-notifications-pipeline_spec`, `analytics-pipeline_spec`.

## What is live in the repo vs only planned

### 1) K8s overlays and GitOps deployment targets

**Live/declarative paths present**
- `deploy/k8s/base`
- `deploy/k8s/overlays/local`
- `deploy/k8s/overlays/rke2-nonprod`
- `deploy/k8s/overlays/production`

**Historical/deprecated path**
- `deploy/k8s/overlays/staging` is marked in-file as deprecated and is explicitly documented as historical only.

**Assessment vs user goal (“dev + staging in parity”)**
- Current structure is moving toward a two-track model:
  - **prod** (production behavior)
  - **rke2-nonprod** (non-prod/dev cluster)
- “Staging” is not an active canonical deployment lane in this repo anymore; it is currently represented as deprecated infrastructure.
- Therefore, parity work should be measured between:
  - `local`/`rke2-nonprod` and
  - `production`
  (not between production and deprecated `overlays/staging`).

### 2) What’s implemented (“done”)

- Baseline MFE set in Tutor/MFE build tooling is broad and includes core modules typically required for platform parity (authn, authoring, account, communications, discussions, gradebook, learner dashboard, learning, ora-grading, profile, learner-record).
- Enterprise microservices are present in repo specs and mostly implemented (high spec coverage from existing reports).
- Aspects Analytics stack components exist under repo directories as source and kustomize assets in `deploy/k8s/base/plugins/aspects`, but they are **not currently wired into the active base kustomization graph**, so they are not deployed as part of the default overlay composition.
- Non-prod dev overlay (`rke2-nonprod`) contains meaningful env/domain/auth wiring and service patches not found in production.
- CI and operations infrastructure contains many gate/audit scripts for parity and rollout checks.

### 3) What is incomplete/not live from tracker/spec perspective

#### Non-production parity gaps
- No single canonical non-prod “staging” overlay in active usage; this lane is not represented as the current deployment target.
- No unified image/pipeline parity lock for all optional services across all lanes (especially Aspects and notifications).
- Several deployment and CI pipeline ACs remain unmapped/untested in runtime-relevant modes.

#### Deployment/Observability gaps (highest impact)
- `ci-cd-pipeline_spec` coverage is incomplete (`86.0%`, with 6 AC gaps tied to environment/runner/deploy integration in docs.
- `k8s-deployment_spec` coverage is incomplete (`86.5%`, with 5 unmapped ACs).
- These uncovered ACs should block “parity claim” language until closed.

#### Functionality gaps that affect production-like parity
- `analytics-pipeline_spec` low coverage (`40%`, includes Aspects deployment/instrumentation gaps).
- `email-notifications-pipeline_spec` remains largely unimplemented (`40%`, 27 unmapped ACs).

## Tracker alignment (as found)

I checked the local tracker DB (`.beads/beads.db`) to map current active work items:

- Snapshot counts: `open=2`, `in_progress=12`, `deferred=3`, `closed=599`.
- Relevant in-progress work appears to include deployment and non-prod rollout activities (examples seen in query extract):
  - `5ngf` / `5ngf.2` / `3bm2` / `288f` / `1jsy` / `aza7` / `2s47`

> Note: The local CLI tooling was not fully available in this environment for direct `br` command operations, so the canonical source used was the local `.beads` database read. If you want, I can produce a second pass that converts these IDs into a cleaned “handoff matrix” (AC-by-ticket-by-owner) using whichever tracker export you prefer.

## AC/Spec gap summary (repo evidence)

### Critical gap specs

- `specs/analytics-pipeline_spec.md`
  - Coverage remains at 40%
  - Missing deployment of the Aspects analytics stack in runtime composition
  - AC IDs still open in this area are likely deployment/runtime guard and visibility coverage items

- `specs/email-notifications-pipeline_spec.md`
  - Coverage remains at 40%
  - Major gap area: email pipeline end-to-end (pipeline + delivery + operational checks)

- `specs/enterprise-microservices_spec.md`
  - Near-complete (97.3%), but still has one unmapped AC

- `specs/ci-cd-pipeline_spec.md`
  - Coverage at 86%; remaining gaps are deployment and integration ACs in pipeline/runtime execution

- `specs/k8s-deployment_spec.md`
  - Coverage at 86.5%; remaining ACs are mostly deploy/rollout robustness checks

## High-confidence findings mapped to user ask (“production/dev/staging parity”)

1. **“Staging” is not a live canonical overlay in current GitOps state**
   - The file exists but is marked deprecated; parity should be measured against the active non-prod lane.

2. **You do not have functional parity today between non-prod and prod across all capability classes**
   - Especially around analytics (Aspects) and notifications.

3. **Runtime checks are present, but AC coverage indicates deployment readiness is incomplete**
   - `ci-cd-pipeline_spec` and `k8s-deployment_spec` remaining ACs are exactly the type that affects “release-ready across environments.”

4. **Some production-like services are intentionally constrained in local/dev overlays (e.g., enterprise/payments scale decisions)**
   - That is valid for non-prod behavior, but differences should be explicitly tracked as intentional variance or removed when parity target changes.

## Recommended next implementer plan (handoff)

### Track 1: Canonical non-prod lane definition
- Confirm and document canonical non-prod in code: keep `rke2-nonprod` as active non-prod target.
- Remove ambiguity around deprecated staging references in docs and helper scripts.
- Ensure all env-specific manifests reference this model consistently.

### Track 2: Close AC gaps before claiming parity
- Complete remaining ACs in:
  - `ci-cd-pipeline_spec`
  - `k8s-deployment_spec`
- These should be implemented first since they gate safe rollout confidence.

### Track 3: Aspects analytics deployment parity
- Wire `plugins/aspects` into base/overlay composition where intended by spec.
- Validate MFE + backend + telemetry path + monitoring alerts are running in non-prod and prod.
- Re-run AC coverage and observability checks.

### Track 4: Notifications parity
- Finish `email-notifications-pipeline_spec` ACs required for runtime and non-prod coverage.
- Verify alerts, retries, dead-letter/error handling, and delivery proof points.

### Track 5: Release evidence artifact
- Keep this parity pass as a tracker-driven document: one ticket per uncovered AC + one ticket for each env-variance decision (e.g., intentional replica/resource differences).
- Add explicit acceptance criteria and closure criteria before release.

## Proposed tracker work item format (for implementer)

- Create one umbrella parent per spec:
  - `Deploy parity: ci-cd-pipeline_spec remaining ACs`
  - `Deploy parity: k8s-deployment_spec remaining ACs`
  - `Analytics parity: Aspects runtime deployment and parity checks`
  - `Notifications parity: email notifications pipeline complete`

- Create child issues for each AC gap with:
  - AC id
  - exact failing check/report
  - target env (`local`, `rke2-nonprod`, `production`)
  - expected post-change evidence (script + artifact path)

## Implementation safety notes

- No direct secrets or runtime destructive operations were attempted.
- No file edits besides this review artifact.

