# HubSpot and Mux Deployment Guide
_Audience: Operators • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

Use this guide when you need the current operator/reference entry points for HubSpot or Mux-adjacent deployment work.

## Start here

- [`../../reference/operations/CAPABILITY_MATRIX.md`](../../reference/operations/CAPABILITY_MATRIX.md)
- [`../../../specs/proposals/external-registration-hubspot_spec.md`](../../../specs/proposals/external-registration-hubspot_spec.md)
- [`../../../scripts/qa/verify-hubspot-k8s-security.sh`](../../../scripts/qa/verify-hubspot-k8s-security.sh)
- [`../../architecture/video-pipeline-overview.md`](../../architecture/video-pipeline-overview.md)
- [`VIDEO_OPERATIONS_RUNBOOK.md`](VIDEO_OPERATIONS_RUNBOOK.md)
- [`../../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md`](../../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md)

## Mux API Setup

Use this section when validating current Mux credentials, API reachability, or
the operator boundary for video-lane secrets.

### Canonical secret boundary

Current Mux API credentials must come from the governed secret path, not from
ad-hoc shell history:

- Infisical / GCP Secret Manager canonical names:
  - `MEREKA_LMS_MUX_TOKEN_ID`
  - `MEREKA_LMS_MUX_TOKEN_SECRET`
- Runtime/Kubernetes env names:
  - `MUX_TOKEN_ID`
  - `MUX_TOKEN_SECRET`

Do not inline credentials into manifests, docs, or transcripts.

### Where the credentials are consumed

Current Mux-adjacent consumers include:

- migration and verification tooling
- video observability / delivery-minute monitoring
- future/gated direct-upload and protected-playback companions

Credential presence alone does not prove learner playback. It only proves the
API lane is wired.

### Setup / verification flow

1. confirm the secret exists in the canonical secret authority
2. confirm the bridge into the runtime lane is configured correctly
3. run the current verifier set
4. only after the verifiers pass, treat Mux API setup as healthy

Current verification commands:

```bash
./scripts/qa/verify-mux-secrets.sh
./scripts/qa/verify-mux-alert-wiring.sh
./scripts/qa/verify-video-pipeline.sh
```

### API reachability check

If an operator needs to prove the token pair is valid, use a controlled
one-shot API call and avoid writing the token values into the shell transcript.
Prefer verifier scripts first; direct API checks are secondary evidence.

### Decision table

| Symptom | Route |
| --- | --- |
| Mux API token missing or invalid | continue in this guide |
| Learner video playback broken | [VIDEO_OPERATIONS_RUNBOOK.md](VIDEO_OPERATIONS_RUNBOOK.md) |
| Subtitle/text-track issue | [VIDEO_OPERATIONS_RUNBOOK.md](VIDEO_OPERATIONS_RUNBOOK.md) |
| Need to replay historical MCT upload context | [../../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md](../../reference/migrations/mct/VIDEO_MIGRATION_TO_MUX.md) |

### Boundary

This guide owns API setup and secret-path reasoning. It does not own playback
mapping or learner-path proof. Subtitle handling currently stays inside the
video operations runbook until a dedicated current-owner companion is warranted.
