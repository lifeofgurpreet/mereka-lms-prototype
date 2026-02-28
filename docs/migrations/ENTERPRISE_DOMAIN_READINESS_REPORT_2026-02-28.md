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
./scripts/qa/verify-enterprise-service-deployment.sh
```

Result summary:
- `PASS: 6`
- `FAIL: 18`

Observed failure pattern:
- Enterprise deployments exist but are `0/0` ready (scaled down / inactive path).
- Enterprise service endpoints are empty.
- In-cluster enterprise health checks fail due no running pods.

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

1. **Enterprise service plane is not live**
- `enterprise-catalog`, `enterprise-access`, `enterprise-subsidy`, portals/workers are not actively serving.
- This blocks real enterprise customer onboarding beyond foundational records.

2. **Runbook status mismatch**
- `enterprise-services-runbook.md` states services are deployed in production.
- Live verification currently fails readiness for those services.
- The docs/runtime contract needs alignment to avoid false green status.

3. **Migration completion is partially deferred by design**
- Kajabi lesson-plan/lesson-detail fidelity remains intentionally deferred.
- This is acceptable short term, but should remain a tracked migration debt item for enterprise content QA.

## Recommended execution sequence (systematic)

1. **Bring enterprise service plane to active runtime**
- Activate service deployments and workers in prod (not 0/0).
- Verify AC-001..AC-008 path via `verify-enterprise-service-deployment.sh` until green.

2. **Lock runtime truth into release gates**
- Keep `verify-enterprise-runtime-app-wiring.sh` in onboarding/release checks.
- Add/retain enterprise service readiness check in GitOps release verification path.

3. **Align docs with runtime truth**
- Update runbook status language to reflect current state (inactive vs active) until activation completes.
- Keep status labels strict: no “deployed” claim unless AC-001..AC-008 pass in runtime.

4. **Pilot tenant hardening**
- Onboard one pilot tenant end-to-end using `scripts/tenants/onboard-enterprise-tenant.sh`.
- Validate: SSO, catalog scope isolation, license allocation/revocation, learner portal visibility.

5. **Defer-safe migration debt tracking**
- Keep Kajabi lesson-plan/details and MCT pathway/verification gaps as explicit deferred tasks with owners/date.

## Decision summary

- **Foundation is strong** (spec coverage + SSO + tenant wiring).
- **Primary blocker is runtime activation of enterprise service components** (not architecture/spec gaps).
- **Next milestone** should be: enterprise service plane live and verified, then pilot tenant go-live.
