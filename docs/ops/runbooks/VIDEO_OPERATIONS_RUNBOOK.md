# Video Operations Runbook
_Audience: Platform operators and migration owners • Owner: Platform Team • Last verified: 2026-04-10 • Status: canonical_

Use this runbook for current operational procedures around Mux-backed video
delivery on Mereka LMS.

This is the current owner for video-operations guidance. It complements, but
does not replace:

- [../../architecture/video-pipeline-overview.md](../../architecture/video-pipeline-overview.md)
- [HUBSPOT_MUX_DEPLOYMENT_GUIDE.md](HUBSPOT_MUX_DEPLOYMENT_GUIDE.md)
- [../../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md](../../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md)
- [../../../specs/video-pipeline-delivery_spec.md](../../../specs/video-pipeline-delivery_spec.md)

## Current Status

As of 2026-04-10:

- Mux-backed playback for the migrated MCT catalog is a real platform surface
- the historical MCT upload and package-rebuild flow is complete
- subtitle attachment exists for the migrated subset, and current subtitle
  handling remains part of this runbook
- Studio direct upload, signed playback, and richer video analytics remain
  planned/gated rather than universally enabled operator workflows

Do not claim a full author-upload or protected-playback operating model unless
those gated features are explicitly enabled and runtime-verified.

## When To Use This Runbook

Use this runbook when you need to:

- verify whether a course unit is wired to Mux-backed playback correctly
- troubleshoot missing, errored, or stale Mux assets
- confirm the mapping between lesson content and Mux playback IDs
- decide whether an issue belongs to migration history, current playback
  operations, or subtitle-specific handling inside the current owner doc

Use the MCT migration reference when replaying or auditing the original bulk
upload.

## Preconditions

Before changing anything in the video lane:

1. Confirm the active lane and host surfaces in [../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md).
2. Confirm the current runtime verification chain in [POST_DEPLOY_GATE.md](POST_DEPLOY_GATE.md).
3. Confirm whether the issue is with historical MCT migration data or a current playback symptom.
4. Retrieve Mux credentials only from the approved secret source, never from ad-hoc local shell history.

## Current Playback Contract

The current canonical playback shape is:

- Open edX Video XBlock
- Mux HLS endpoint: `https://stream.mux.com/{PLAYBACK_ID}.m3u8`
- thumbnail endpoint: `https://image.mux.com/{PLAYBACK_ID}/thumbnail.jpg`

Current learner-facing proof is successful playback in a course unit. A Mux
asset that exists in the dashboard but is not wired to the learner path is not
enough.

## Operational Procedures

### 1. Verify an existing playback issue

Use this path first when a learner or operator reports broken playback.

1. identify the tenant, course, subsection/unit, and expected lesson title
2. confirm the course content references a Mux playback ID instead of a stale
   source URL
3. confirm the playback ID resolves and the asset is ready
4. confirm the learner path still loads the unit without player/rendering
   regression
5. if needed, switch to subtitle, monitoring, or migration-history companions

### 2. Repair or replace a mapped asset

Use this path when the asset exists but is wrong, missing, or needs controlled
  replacement.

1. capture the current lesson identifier, playback ID, and any asset ID
2. determine whether the lesson belongs to the historical MCT migration set
3. if historical replay is required, use the migration reference and preserve
   the mapping context
4. if this is current operator work, preserve before/after evidence and update
   the course wiring only after the replacement asset is ready
5. re-run learner-path verification after the replacement

### 3. Review video observability or cost state

Use this path when the symptom is cost spike, delivery-minute drift, or alert
state rather than learner playback.

1. verify current monitoring and alerting expectations
2. distinguish “video plays but monitoring is wrong” from “video itself is
   broken”
3. do not claim end-to-end observability just because playback works

## Operator Checklist

When a video issue is reported:

1. Confirm the failing course, unit, and tenant.
2. Confirm whether the course came from the completed MCT migration or from a
   newer authoring path.
3. Inspect the course content for a Mux playback ID rather than a stale source
   URL.
4. Confirm the playback ID resolves and the asset is ready.
5. If the problem is subtitle-specific, keep the investigation in this runbook
   and preserve subtitle-specific evidence explicitly.
6. If the problem is a historical migration replay need, switch to the MCT
   migration reference.

## Troubleshooting Routes

### 1. Video does not load in the unit

Check:

- the Video XBlock points at a Mux playback URL, not a stale Azure/CDN source
- the playback ID exists and resolves
- the learner path still passes the post-deploy video proof

If the issue is a current runtime regression, treat it as a runtime-proof issue
first, not as a migration-history issue.

### 2. Mux asset exists but content is wrong

Check:

- lesson-to-playback mapping artifact
- whether the title or source URL was repaired historically
- whether the course package needs to be rebuilt or the Studio content updated

Use the migration reference if this is one of the original MCT assets; otherwise
keep the investigation in the current video lane.

### 3. Mux asset is errored or missing

Check:

- approved Mux token source
- source URL validity
- whether the asset belongs to the historical migration run or a new operator
  action

For historical replay, use the MCT migration reference. For a current mutation
or replacement flow, preserve evidence and treat the re-upload as controlled
operator work.

### 4. Cost or delivery-minutes concern

Treat this as observability/policy work as well as video work. Use the
monitoring and CI/verification canon before claiming the cost lane is
instrumented end to end.

### 5. Studio upload or new author-upload expectation

Treat this as a gated capability check, not as assumed current behavior.

Check:

- whether direct-upload support is actually enabled in the target lane
- whether the issue is a planned future capability versus a regression in the
  already-migrated playback surface
- whether the request belongs in current operator action or roadmap/spec scope

Do not route a missing future-state feature through migration-history playback
troubleshooting.

## Incident Playbooks

### Mux asset error

1. capture the course/unit, playback ID, and any asset ID
2. confirm whether the asset is `ready`, `preparing`, or errored
3. decide whether this is historical replay or current operator replacement
4. preserve evidence before any re-upload or mapping mutation
5. verify the learner path again after recovery

### CDN or playback degradation

1. confirm the issue is broad playback degradation, not one bad asset
2. validate Mux playback URL resolution and learner-path rendering
3. check whether the symptom is tenant-specific, course-specific, or broad
4. if the issue is actually monitoring/alerting only, keep it in the
   observability lane instead of declaring playback down

### Cost spike or delivery-minute drift

1. confirm the alert/data source
2. separate increased learner traffic from instrumentation errors
3. preserve the current month trend and any alert evidence
4. if emergency cost action is required, record the temporary boundary and link
   it back to source truth immediately after

## Diagnostic Commands

Use these commands as the current quick operator set:

```bash
./scripts/qa/verify-video-pipeline.sh
./scripts/migrations/mct/verify_mux_upload.sh
./scripts/migrations/mct/verify_video_mapping.sh
./scripts/qa/verify-video-observability.sh
./scripts/qa/verify-mux-alert-wiring.sh
```

Add lane-specific checks only after this base set identifies which boundary is
failing.

## Emergency Boundary

Do not advertise a blind “rollback to Azure CDN” path as if it were a routine
current operation. Historical source continuity exists, but emergency fallback
must be treated as controlled incident work with explicit evidence and source
commit follow-through, not as a normal runbook toggle.

## Evidence Expectations

Any material video-lane operation should leave:

- source lesson or unit identifier
- playback ID and, when needed, asset ID
- before/after content evidence
- Mux-side readiness or error evidence
- operator transcript or controlled workflow link
- whether the issue was playback, subtitle, monitoring, or gated-future
  capability debt

## Related

- Architecture model: [../../architecture/video-pipeline-overview.md](../../architecture/video-pipeline-overview.md)
- Mux setup companion: [HUBSPOT_MUX_DEPLOYMENT_GUIDE.md](HUBSPOT_MUX_DEPLOYMENT_GUIDE.md)
- Historical migration reference: [../../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md](../../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md)
- Runtime gate: [POST_DEPLOY_GATE.md](POST_DEPLOY_GATE.md)
