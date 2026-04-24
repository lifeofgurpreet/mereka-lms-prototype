# Troubleshooting Router
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

Use this as the generic troubleshooting entry point when a spec, guide, or policy needs a stable first stop.

## Start here

- [`site-down.md`](site-down.md) for outages and immediate service loss
- [`performance-degradation.md`](performance-degradation.md) for latency or throughput issues
- [`database-issues.md`](database-issues.md) for MySQL, MongoDB, and persistence failures
- [`INCIDENT_RESPONSE.md`](INCIDENT_RESPONSE.md) for broader incident management
- [`ARGOCD_HEALTH_TROUBLESHOOTING.md`](ARGOCD_HEALTH_TROUBLESHOOTING.md) for GitOps or rollout drift
- [`XQUEUE_HEALTH_RUNBOOK.md`](XQUEUE_HEALTH_RUNBOOK.md) for ORA2, timed-exam, XQueue-adjacent, and launch-readiness assessment routing
- [`../../reference/operations/AUTH_AND_PERMISSIONS.md`](../../reference/operations/AUTH_AND_PERMISSIONS.md) and [`architecture/MFE_OAUTH_FIX_DEPLOYMENT.md`](architecture/MFE_OAUTH_FIX_DEPLOYMENT.md) for middleware ordering, forwarded-header, OAuth-provider, and metrics regressions

## Tutor Configuration and Patch Drift

Use this lane when Tutor config changes appear to render cleanly but runtime or
build behavior disagrees.

### Common symptoms

- MFE image build starts failing after a config or plugin change
- rendered config brings back cloud service addresses in local sandbox
- MySQL auth regressions reappear after regeneration
- Caddy, nginx, or MFE patches disappear after `tutor config save`

### Investigation

```bash
./scripts/infra/verify-tutor-config.sh
./scripts/qa/verify-tutor-patches.sh
./scripts/qa/verify-tutor-config-path-contract.sh
./scripts/qa/verify-tutor-config-safety.sh
grep -F 'insteadOf "ssh://git@github.com/"' tutor_env/env/plugins/mfe/build/mfe/Dockerfile
grep -F 'insteadOf "git@github.com:"' tutor_env/env/plugins/mfe/build/mfe/Dockerfile
grep -E 'gcc|g\\+\\+|python3-distutils' tutor_env/env/plugins/mfe/build/mfe/Dockerfile
```

### Recovery

1. Re-render through the governed wrapper:
   ```bash
   ./scripts/infra/tutor-config-save.sh
   ```
2. Rerun the verifier set above.
3. Restart affected services only after the verifier set is clean.
4. If the drift came from plugin lifecycle or patch ownership confusion, review:
   - [`TUTOR_CONFIGURATION_RUNBOOK.md`](TUTOR_CONFIGURATION_RUNBOOK.md)
   - [`TUTOR_PLUGIN_MIGRATION_RUNBOOK.md`](TUTOR_PLUGIN_MIGRATION_RUNBOOK.md)
   - [`TUTOR_CONFIG_CI.md`](../../reference/operations/TUTOR_CONFIG_CI.md)

### Emergency note

Do not bypass the wrapper or verifiers as a normal fix path. If an emergency
requires a temporary manual step, record the deviation and reconcile source
truth immediately afterward.

## Content Libraries v2

Use this lane when Content Libraries v2 behavior is failing in Studio,
authoring, search, or course-reference flows.

### Common symptoms

- library not visible in Studio or authoring views
- component renders in the library editor but not in the destination course
- sync from library fails or reports missing content
- search returns no expected library/component results
- a tenant receives cross-org access denial or unexpected visibility
- publish operations stall, fail, or time out

### Investigation

1. Confirm the architecture and operator boundaries:
   - [`content-libraries-overview.md`](../../concepts/architecture/content-libraries-overview.md)
   - [`CONTENT_LIBRARIES_V2_MIGRATION.md`](CONTENT_LIBRARIES_V2_MIGRATION.md)
   - [`LIBRARIES_GCS_SETUP.md`](../../reference/operations/LIBRARIES_GCS_SETUP.md)
2. Check the specific failure class:
   - Library not visible in Studio:
     - verify organization membership and library ownership scope
     - verify `CONTENT_LIBRARIES_V2_ENABLED` is not disabled for the target lane
   - Component not rendering in course:
     - verify the component was published, not only saved as draft
     - verify the target course has accepted or synced the published state
     - verify the referenced XBlock type is actually installed in the lane
   - Sync from library fails:
     - verify the library key exists in the expected organization scope
     - verify the acting user still has library read/use permission
   - Search not returning results:
     - verify `CONTENT_LIBRARIES_SEARCH_ENABLED`
     - verify the issue is discoverability, not missing published content
     - verify whether a re-index is the required follow-up
   - Cross-tenant access denial:
     - verify the user belongs to the correct organization / enterprise boundary
     - verify this is a legitimate isolation denial, not a bad library assignment
   - Publish operation times out:
     - verify Blockstore / GCS backing is healthy
     - verify database connectivity and publish-path error logs

### Recovery

1. Fix the owning problem first:
   - permissions / org scope
   - unpublished draft state
   - missing sync / reference adoption
   - search-index lag
   - Blockstore or database health
2. Re-test from the correct surface:
   - Studio visibility
   - authoring API/library view
   - destination course reference
3. If recovery requires backup or restore, switch to:
   - [`CONTENT_LIBRARIES_V2_MIGRATION.md`](CONTENT_LIBRARIES_V2_MIGRATION.md)

### Boundary

Do not treat search lag as content loss, and do not treat draft visibility as
learner-visible published truth. Content Libraries v2 troubleshooting must keep
publish state, storage health, tenant isolation, and course-reference adoption
as separate checks.

## Video Playback and Mux

Use this lane when learner video playback, Mux asset readiness, subtitle
attachment, or video observability is the likely boundary.

### Common symptoms

- video unit renders but playback never starts
- course still points at a stale source URL instead of a Mux playback ID
- Mux asset exists but the wrong lesson is playing
- subtitles are missing even though playback works
- delivery-minute or alerting checks drift while playback still appears healthy

### 5-command diagnostic flow

```bash
./scripts/qa/verify-video-pipeline.sh
./scripts/migrations/mct/verify_mux_upload.sh
./scripts/migrations/mct/verify_video_mapping.sh
./scripts/qa/verify-video-observability.sh
./scripts/qa/verify-mux-alert-wiring.sh
```

### Router

- learner playback broken:
  - [HUBSPOT_MUX_DEPLOYMENT_GUIDE.md](HUBSPOT_MUX_DEPLOYMENT_GUIDE.md)
- subtitle/text-track issue only:
  - [HUBSPOT_MUX_DEPLOYMENT_GUIDE.md](HUBSPOT_MUX_DEPLOYMENT_GUIDE.md)
- Mux API secret or alert wiring issue:
  - [HUBSPOT_MUX_DEPLOYMENT_GUIDE.md](HUBSPOT_MUX_DEPLOYMENT_GUIDE.md)
- need historical MCT replay context:
  - [../../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md](../../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md)

### Boundary

Do not collapse playback proof, subtitle correctness, and observability/cost
state into one verdict. A course can have healthy playback while monitoring is
wrong, and a ready Mux asset does not prove the learner path is wired
correctly.

## Mobile Apps

Use this lane when the paused mobile surface is being reactivated or when a
resumed device/build/distribution path shows a concrete problem.

### Common symptoms

- iOS workflow builds fail or TestFlight upload is rejected
- app signs in but lands in the wrong tenant context
- push registration never succeeds after login
- branding payload is stale or falls back unexpectedly
- course access works on web but fails in the app

### Router

- workflow/signing/TestFlight contract issue:
  - [../../reference/operations/IOS_CI_CD_REFERENCE.md](../../reference/operations/IOS_CI_CD_REFERENCE.md)
- secret inventory / Firebase / APNs / Play setup issue:
  - [../../reference/operations/MOBILE_SECRETS_MANAGEMENT.md](../../reference/operations/MOBILE_SECRETS_MANAGEMENT.md)
- release/reactivation procedure question:
  - [MOBILE_DEPLOYMENT.md](MOBILE_DEPLOYMENT.md)
- runtime device verification:
  - [MOBILE_APPS_RUNBOOK.md](MOBILE_APPS_RUNBOOK.md)

### Boundary

Do not treat the existence of a maintained workflow or secret inventory as
runtime proof. The mobile lane is paused by default; troubleshooting must keep
workflow, build, distribution, and runtime truth separate.
