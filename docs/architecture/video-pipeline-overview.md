# Video Pipeline Overview

_Status: detailed-reference_

Use this document for the stable system model of video ingestion, delivery, and
playback on Mereka LMS.

This is the architecture-root overview for the video lane. It is reference
guidance for the stable boundary, not a current front door, and it defines the
intended component boundaries and current truth without pretending every
future-state capability is already live.

Read with these companions:

- [../ops/runbooks/VIDEO_OPERATIONS_RUNBOOK.md](../ops/runbooks/VIDEO_OPERATIONS_RUNBOOK.md)
- [../ops/runbooks/HUBSPOT_MUX_DEPLOYMENT_GUIDE.md](../ops/runbooks/HUBSPOT_MUX_DEPLOYMENT_GUIDE.md)
- [../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md](../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md)
- [../../specs/video-pipeline-delivery_spec.md](../../specs/video-pipeline-delivery_spec.md)

## Current Boundary

As of 2026-04-10:

- Mux-backed playback is a real platform surface for migrated MCT content
- the MCT migration to Mux is completed historical fact, not a pending rollout
- Studio-side direct upload, signed playback for restricted content, and richer
  analytics remain planned/gated capabilities
- this document is the stable system model for the video lane, not proof that
  every optional feature in the spec is enabled today

Do not use this document alone as proof that signed playback, subtitle
workflows, or Studio upload are active in the current lane.

## Stable Model

The video lane has five layers:

1. source video ingestion and migration tooling
2. Mux asset creation and playback-identifier ownership
3. Open edX Video XBlock playback wiring
4. subtitle and text-track attachment
5. verification, monitoring, and future access-control extensions

## System View

The current durable system model is:

1. migration or operator tooling identifies source media and canonical lesson
   identity
2. Mux ingests the source, creates the asset, and issues one or more playback
   IDs
3. Open edX content wiring stores the learner-facing playback reference in the
   course unit
4. the learner path streams HLS from Mux through the Video XBlock
5. companion lanes handle subtitles, observability, future protected playback,
   and historical replay evidence

This is not a single monolith. The stable boundary is between:

- source ingestion and repair tooling
- Mux asset and playback ownership
- Open edX content wiring
- learner playback proof
- analytics, cost, and future protection extensions

## Component View

| Layer | Responsibility |
| --- | --- |
| Source tooling | extract source URLs, preserve lesson identity, upload or re-upload assets |
| Mux | transcode assets, issue playback IDs, provide thumbnails and streaming endpoints |
| Open edX content packages | render Mux-backed Video XBlocks inside course units |
| Subtitle workflow | attach and validate language tracks against the correct asset |
| Monitoring and policy | verify playback, track delivery/cost signals, gate future protected-playback work |

## Integration Points

The current video lane crosses these external or companion contracts:

| Surface | Role |
| --- | --- |
| Mux Video API | asset creation, status, playback IDs, thumbnails, subtitle/text-track attachment |
| Open edX Video XBlock | learner-facing player surface and course-unit binding |
| migration/build tooling | preserves lesson identity and writes the playback mapping back into course content |
| subtitle workflow | language-track attachment and repair for migrated or newly repaired assets |
| verification lane | proves playback wiring, observability, and future protected-playback behavior separately |
| observability lane | delivery-minutes, alerts, and future QoS/engagement instrumentation |

## Data Flow

The current stable flow is:

1. source lesson/video metadata is exported or prepared
2. upload tooling creates or updates Mux assets
3. playback IDs are mapped back to course content
4. course packages or Studio configuration reference the Mux HLS endpoint
5. learners receive HLS playback through the Video XBlock

The current operational split is:

- migration history and replay stay with the MCT reference surfaces
- current playback and incident response stay with the active runbooks
- cost, alerting, and observability stay with monitoring/verifier canon
- future restricted-playback work stays gated until runtime proof exists

The current canonical HLS shape remains:

`https://stream.mux.com/{PLAYBACK_ID}.m3u8`

## Core Boundaries

### Migration History vs Current Operations

The MCT migration reference is durable background and replay guidance:

- [../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md](../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md)

Current operational ownership for the video lane belongs in the active runbook
surfaces under `docs/ops/runbooks/**`, not in migration-history notes.

### Playback ID vs Asset ID

Client-facing playback must use Mux playback IDs, not internal asset IDs.

- playback IDs belong in Open edX content and learner-facing HTML
- asset IDs stay in operator tooling, mappings, or troubleshooting context

### Open Playback vs Restricted Playback

The current lane proves open playback for the migrated course set. Signed
playback for restricted content is part of the target architecture, but it
should not be claimed as realized until the LMS enrollment gate, token
generation, and runtime proof all exist together.

### Playback Rendering vs Analytics

Playback success and analytics completeness are separate truths.

- a learner-visible successful HLS session proves playback wiring
- delivery-minutes and alerting prove observability/cost instrumentation
- xAPI and richer Mux Data quality signals remain companion lanes until they
  are implemented and runtime-verified

Do not collapse those into one “video is done” claim.

### Subtitle Management

Subtitles are a first-class companion surface, not a footnote on migration.

Current subtitle handling stays inside
[../ops/runbooks/VIDEO_OPERATIONS_RUNBOOK.md](../ops/runbooks/VIDEO_OPERATIONS_RUNBOOK.md)
until there is a durable standalone subtitle companion with a stable owner and
live consumer set.

## Verification Boundary

The current meaningful proof surface for the video lane is:

- video playback loads successfully inside the course unit
- the learner path does not regress page load or playback rendering
- the unit points at a valid playback ID instead of a stale source URL

Companion proof lanes exist for:

- subtitle attachment and language exposure
- delivery-minute alerting and monitoring
- future signed-playback behavior
- future richer analytics / xAPI emission

That proof belongs in the post-deploy/runtime verification chain, not in this
architecture overview.

## Future-State Extensions

The following belong to the target-state video model but are still planned or
gated:

- Studio direct uploads through Mux
- signed playback for restricted courses
- richer Mux Data quality-of-service analytics
- dedicated subtitle lifecycle automation for new author uploads

## Related

- Operations: [../ops/runbooks/VIDEO_OPERATIONS_RUNBOOK.md](../ops/runbooks/VIDEO_OPERATIONS_RUNBOOK.md)
- Mux setup companion: [../ops/runbooks/HUBSPOT_MUX_DEPLOYMENT_GUIDE.md](../ops/runbooks/HUBSPOT_MUX_DEPLOYMENT_GUIDE.md)
- Historical migration reference: [../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md](../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md)
