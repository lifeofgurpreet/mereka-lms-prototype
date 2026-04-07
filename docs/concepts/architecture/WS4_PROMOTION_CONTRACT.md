# WS4: Release-Object-Driven Promotion Contract

> Status: DESIGN — not yet implemented
> Owner: Agent 1 V2 (producer side) + Agent 2 (consumer side)
> Tracker: B-011, B-012, B-013, B-014, B-015

## Current State (Manual)

```
App repo build → release-bundle.json + release-object.json (CI artifact)
                   ↓ (MANUAL: human downloads artifact, runs promote workflow)
Infra repo → promote.sh → updates kustomization.yaml → ArgoCD syncs
```

## Target State (Automated)

```
App repo build (main push)
  → build images
  → generate release-bundle.json + release-object.json + truth-ledger.json
  → sign bundle (cosign)
  → upload as CI artifact
  → trigger infra promote workflow via repository_dispatch
                   ↓ (AUTOMATIC)
Infra repo promote-image.yml
  → receives release_object payload
  → extracts image digests from release_object.images[]
  → runs promote.sh for mereka-lms --from-env dev
  → commits kustomization.yaml changes
  → ArgoCD syncs
  → post-deploy proof runs and binds to release_id
```

## Producer Contract (App Repo — DONE)

The app build (`build-tutor-images.yml`) already produces:
- `var/ci/release-bundle.json` — signed bundle with image digests
- `var/ci/release-object.json` — canonical release object
- `var/ci/truth-ledger.json` — truth ledger (PR #1394)
- Uploaded as `release-bundle` artifact (90-day retention)

### Release Object Fields Consumed by Infra

```json
{
  "release_id": "v2026.04.07-abc123",
  "source_commit": "abc123...",
  "images": [
    {"name": "openedx", "registry": "ghcr.io/...", "tag": "abc123", "digest": "sha256:..."},
    {"name": "mfe", "registry": "ghcr.io/...", "tag": "abc123", "digest": "sha256:..."}
  ],
  "evidence_bundle": {
    "ci_run_id": "12345",
    "static_validation": "pass",
    "security_scan": "pass"
  }
}
```

## Consumer Contract (Infra Repo — TO BUILD)

The infra `promote-image.yml` already accepts `release_evidence` input.

### What's Missing

1. **Automatic trigger**: App build must send `repository_dispatch` to infra repo after release bundle is generated
2. **Dev auto-promotion**: The dispatch should target `dev` environment automatically (no human approval needed)
3. **Staging/prod gates**: Require manual approval or additional evidence before promoting beyond dev
4. **Post-deploy proof binding**: After ArgoCD syncs, run acceptance lanes and bind results to the same `release_id`

### Implementation Plan

#### Step 1: Add repository_dispatch to app build
In `build-tutor-images.yml`, after the release-bundle job:
```yaml
- name: Trigger dev promotion
  if: success()
  uses: peter-evans/repository-dispatch@v3
  with:
    token: ${{ secrets.INFRA_DISPATCH_TOKEN }}
    repository: Biji-Biji-Initiative/bbi-infrastructure
    event-type: promote-mereka-lms
    client-payload: |
      {
        "release_object": ${{ steps.bundle.outputs.release_object_json }},
        "release_id": "${{ steps.bundle.outputs.release_object_id }}",
        "target_environment": "dev"
      }
```

#### Step 2: Add repository_dispatch handler to infra promote workflow
```yaml
on:
  repository_dispatch:
    types: [promote-mereka-lms]
```

#### Step 3: Post-deploy proof binding
After ArgoCD syncs, the acceptance lanes run with `--release-object-json` to bind proof to the release ID.

## Secrets Required

- `INFRA_DISPATCH_TOKEN`: GitHub PAT with `repo` scope on bbi-infrastructure (for cross-repo dispatch)

## Risks

- Cross-repo dispatch requires a PAT, not the default GITHUB_TOKEN
- Auto-promotion to dev means any main-push that builds images goes live on dev automatically
- Must NOT auto-promote to staging/prod without explicit gate
