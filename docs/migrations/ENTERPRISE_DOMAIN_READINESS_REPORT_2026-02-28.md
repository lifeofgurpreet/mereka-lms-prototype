# Enterprise + Future Domain Readiness Report (2026-02-28)
_Audience: Platform Eng + Enterprise Ops • Owner: Migration Squad_

## Scope reviewed

- `specs/enterprise-microservices_spec.md`
- `specs/multi-site-domains_spec.md`
- `specs/auth-sso-enterprise_spec.md`
- `specs/data-migrations-kajabi-mct_spec.md`
- `docs/runbooks/tenant-provisioning-runbook.md`
- `docs/runbooks/enterprise-services-runbook.md`
- `docs/runbooks/auth-sso-enterprise-runbook.md`

## Current evidence snapshot

### 1) Spec coverage (repo-level)

Command:
```bash
source .venv/bin/activate
python3 scripts/qa/spec-tools/spec_coverage_report.py
```

Relevant results:
- `enterprise-microservices`: `37 ACs`, `36 automated`, `1 manual`, `0 unmapped`
- `multi-site-domains`: `9 ACs`, `9 automated`, `0 unmapped`
- `auth-sso-enterprise`: `45 ACs`, `45 automated`, `0 unmapped`
- `data-migrations-kajabi-mct`: `44 ACs`, `41 automated`, `3 manual`, `0 unmapped`

Interpretation:
- Contract coverage is strong on paper; operational runtime still has gaps (below).

### 2) Enterprise service runtime readiness (prod)

Command:
```bash
./scripts/qa/verify-enterprise-service-deployment.sh --env prod
```

Result summary:
- `PASS: 23`
- `FAIL: 1`

Observed failure pattern:
- All enterprise services are reachable with non-empty endpoints and healthy runtime probes.
- External and in-cluster admin/learner enterprise portals return HTTP 200.
- Remaining blocker: some enterprise API deployments (`enterprise-catalog`, `enterprise-access`) are not consistently at full desired steady state during peak scheduling windows, so AC-001 strict readiness can fail even while health endpoints are green.

Context note:
- Running this check without an explicit context can produce misleading results if the active kube context is a local/dev cluster.
- Use `--context` for production assertions to avoid cross-environment drift in reports.

### 5) CI reliability hardening applied

Workflow: `.github/workflows/build-tutor-images.yml`

Implemented:
- Concurrency policy now avoids canceling manual dispatch runs due to push-triggered runs.
- Explicit job timeouts added (`build-openedx`, `build-mfe`).
- Build-step heartbeat output added for long-running `tutor images build` commands.
- Shell-level timeout guards wrapped around `tutor images build openedx|mfe` for deterministic failure signaling.

Why this matters:
- Reduces ambiguous "stuck in progress" behavior during long image builds.
- Ensures long-running builds fail fast and visibly rather than hanging indefinitely.

### 3) Enterprise SSO readiness (prod)

Command:
```bash
./scripts/qa/verify-enterprise-sso-readiness.sh --env prod --mode all
```

Result summary:
- `PASS: 27`
- `FAIL: 0`
- `SKIP: 0`

Interpretation:
- Secrets, package/runtime wiring, and baseline enterprise SSO prerequisites are in place.

### 4) Tenant runtime app wiring (prod)

Command:
```bash
./scripts/qa/verify-enterprise-runtime-app-wiring.sh --env prod
```

Result summary:
- `PASS=8`
- `FAIL=0`
- `SKIP=1` (strict app-set not enforced in standard mode)

Interpretation:
- LMS/CMS runtime custom app wiring for tenancy/enterprise hooks is healthy in production.

## What this means for enterprise scale

### Ready now

- Multi-site domain baseline and tenant mapping machinery are present.
- Enterprise SSO foundations and secret posture are ready.
- Tenant runtime hooks in LMS/CMS are now wired and validated.

### Not ready yet (critical path)

1. **Enterprise service plane is live, but not fully at desired steady state**
- Enterprise services and portals are actively serving in production context.
- Remaining strict readiness issue is concentrated in scheduler-driven replica convergence for `enterprise-catalog`/`enterprise-access` under CPU request pressure.
- This is an SRE/rollout stabilization item, not an architecture absence.

2. **Runbook status mismatch**
- Operational status language needed profile clarity (active vs parked).
- Runbooks were updated to include explicit verification profiles and parked-mode check support.

3. **Migration completion is partially deferred by design**
- Kajabi lesson-plan/lesson-detail fidelity remains intentionally deferred.
- This is acceptable short term, but should remain a tracked migration debt item for enterprise content QA.

### Capacity evidence (runtime)

Command:
```bash
./scripts/qa/audit-enterprise-capacity-pressure.sh --env prod
```

Observed on production context during failed AC-001 steady-state checks:
- Pending enterprise pods report `FailedScheduling ... Insufficient cpu`.
- Node allocated CPU requests are effectively saturated (~99% request allocation on all 3 nodes).

Cluster-wide request distribution snapshot (cpu requests, cores):
- `kube-system`: `1.703`
- `mereka-lms`: `1.491`
- `n8n`: `1.450`
- `reka-slackbot`: `1.350`
- `velero`: `0.900`
- `weaviate`: `0.800`
- remaining namespaces consume the rest.

Interpretation:
- AC-001 strict desired-replica failures are currently capacity/scheduler-driven.
- Enterprise runtime is available and healthy for serving traffic, but not guaranteed to satisfy full desired replicas under current aggregate request pressure.

## Recommended execution sequence (systematic)

1. **Stabilize enterprise API rollout to full desired readiness**
- Resolve why `enterprise-catalog`/`enterprise-access` intermittently remain below desired replicas in prod context.
- Re-run AC-001..AC-008 check with explicit production context until full green.

2. **Lock runtime truth into release gates**
- Keep `verify-enterprise-runtime-app-wiring.sh` in onboarding/release checks.
- Add/retain enterprise service readiness check in GitOps release verification path.

3. **Align docs with runtime truth**
- Keep profile-aware status wording (`active` vs `parked`) and context-aware verification commands.
- Keep status labels strict: no “fully ready” claim unless AC-001..AC-008 pass in runtime.

4. **Pilot tenant hardening**
- Onboard one pilot tenant end-to-end using `scripts/tenants/onboard-enterprise-tenant.sh`.
- Validate: SSO, catalog scope isolation, license allocation/revocation, learner portal visibility.

5. **Defer-safe migration debt tracking**
- Keep Kajabi lesson-plan/details and MCT pathway/verification gaps as explicit deferred tasks with owners/date.

## First Enterprise Client Migration Plan (execution tracks)

### Track A: Runtime capacity stabilization (release-blocking)

Goal:
- Keep `enterprise-catalog` and `enterprise-access` at full desired replicas during normal load windows.

Actions:
- Keep lower init-container CPU requests (already patched) and roll through GitOps.
- Validate with:
  - `./scripts/qa/verify-enterprise-service-deployment.sh --env prod`
  - `./scripts/qa/audit-enterprise-capacity-pressure.sh --env prod`
- Add cluster-level right-sizing decision (node pool scale-up vs namespace request rebalance) based on repeated scheduler evidence.

Exit criteria:
- `verify-enterprise-service-deployment.sh --env prod` is green for AC-001..AC-008 in at least 3 consecutive checks across peak windows.

### Track B: Tenant onboarding path hardening (pilot tenant)

Goal:
- Prove one complete tenant onboarding path without code hotfixes.

Actions:
- Execute onboarding via `scripts/tenants/onboard-enterprise-tenant.sh` (pilot tenant).
- Validate each layer:
  - Domain/Site mapping: `specs/multi-site-domains_spec.md` contract checks
  - SSO readiness: `./scripts/qa/verify-enterprise-sso-readiness.sh --env prod --mode all --tenant <slug>`
  - Runtime app wiring: `./scripts/qa/verify-enterprise-runtime-app-wiring.sh --env prod`
  - Service readiness: `./scripts/qa/verify-enterprise-service-deployment.sh --env prod`
- Capture evidence artifacts under `var/` and link in tenant runbook.

Exit criteria:
- Pilot tenant can authenticate, view only tenant-scoped catalog content, receive/lose license access correctly, and access enterprise portals without manual DB fixes.

### Track C: Data migration fitness for enterprise learners

Goal:
- Confirm existing Kajabi/MCT migrated learners are enterprise-ready for onboarding waves.

Actions:
- Re-validate migration spec posture:
  - `data-migrations-kajabi-mct`: `44 ACs`, `41 automated`, `3 manual`, `0 unmapped`
- Run targeted QA sample for enterprise pilot learners:
  - account active state
  - enrollment integrity
  - completion visibility in enterprise reporting paths
- Keep deferred Kajabi lesson-plan/details explicitly out of release gate for now, but track as migration debt item with due date.

Exit criteria:
- No blocker-level learner integrity defects in pilot cohort; deferred Kajabi lesson metadata remains documented with owner/date.

### Track D: Operational guardrails and truth maintenance

Goal:
- Prevent regressions between "looks healthy" and true enterprise go-live readiness.

Actions:
- Keep `--env prod` usage mandatory in runbooks and reporting commands.
- Retain profile-aware checks (`active` vs `parked`) in enterprise runbooks.
- Ensure CI/GitOps release path includes enterprise runtime checks after image bumps.

Exit criteria:
- Release artifacts and runbooks consistently reflect runtime truth; no ambiguous "ready" claims without passing prod-context gates.

## Definition of done for “enterprise-ready for new domain/client”

1. Enterprise service deployment verifier passes fully (`--env prod`, no FAIL).
2. Enterprise SSO readiness passes fully (`--env prod --mode all`).
3. Runtime app wiring passes fully (`--env prod`).
4. Pilot tenant onboarding completes end-to-end with evidence links.
5. Capacity audit no longer reports scheduler-induced pending enterprise pods during verification windows.
6. Deferred Kajabi lesson-plan/details remains explicitly tracked and excluded from current go-live gate by policy (not by omission).

## Decision summary

- **Foundation is strong** (spec coverage + SSO + tenant wiring).
- **Primary blocker is enterprise API steady-state convergence under strict AC-001 readiness**.
- **Next milestone** should be: full AC-001..AC-008 green in explicit prod context, then pilot tenant go-live.
