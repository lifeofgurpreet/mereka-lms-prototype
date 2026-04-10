# Release Identity Chain Map

_Owner: Agent 2 | Last verified: 2026-04-10T00:00:00Z | Status: active_

## How Release ID Flows (or Fails to Flow)

```
push to main
  │
  ▼
build-tutor-images.yml
  │
  ├─ generate-release-bundle.sh
  │   → var/ci/release-bundle.json
  │   → bundle_id: rb-<sha7>-<timestamp>Z
  │   → signed with cosign (.sig, .pem)
  │
  ├─ generate_release_object.py
  │   → var/ci/release-object.json
  │   → release_id: ro-rb-<sha7>-<timestamp>Z (derived from bundle_id)
  │   → schema_version: "release-object/v1"
  │   → images.openedx.digest, images.mfe.digest
  │   → build.release_bundle_id = bundle_id
  │
  ├─ generate_truth_ledger.py
  │   → var/ci/truth-ledger.json
  │   → release_truth.release_id = release_object.release_id
  │
  ├─ Upload artifact: release-bundle
  │   (release-bundle.json, release-object.json, truth-ledger.json, .sig, .pem)
  │
  └─ Dispatch to bbi-infrastructure (push-to-main only)
      → POST /repos/.../dispatches
      → event_type: promote-mereka-lms-dev
      → client_payload: {
            release_bundle_id: bundle_id,
            validation_evidence: "ci-build-pass:<run_id>",
            release_object: <full release-object.json>,
            build_provenance: { run_url, artifact_uri, build_commit_sha }
          }
          │
          ▼
    bbi-infrastructure: promote-dev-image.yml
      │
      ├─ Validates release_bundle_id format
      ├─ Validates release_object schema
      ├─ Validates build_provenance
      ├─ Persists release-object sidecar
      ├─ Updates dev overlay image tags + digests
      ├─ Creates promotion PR
      ├─ Generates dev-promotion-record.json
      │   → release_object_id = release_object.release_id
      │   → release_bundle_id = bundle_id
      │   → source.commit_sha, source.images.openedx.digest, source.images.mfe.digest
      └─ Uploads dev-promotion-evidence artifact
              │
              ▼
        ArgoCD reconciles mereka-lms-dev
              │
              ▼
        Agent 1: verify-realized-image-identity.sh
          → Compares running pod digests to release_object.images.*.digest
          → INV-002 gate: runtime proof only meaningful if images match
```

## Where Release ID Is Born

- **Generator**: `scripts/release/generate_release_object.py` line 47
- **Format**: `ro-{bundle_id}` where bundle_id = `rb-<sha7>-<timestamp>Z`
- **Example**: `ro-rb-abcdef1-20260409T120000Z`

## Where Release ID Is Transformed

- **Truth ledger**: `release_truth.release_id` copies from release-object (no transformation)
- **Dispatch payload**: `release_object.release_id` passed through (no transformation)
- **Promotion record**: `release_object_id` copies from release-object (no transformation)

## Where Release ID Is Duplicated

| Location | Field | Source | Risk |
|----------|-------|--------|------|
| `config/release-object-schema.yaml` | Declarative schema | Hand-maintained | Schema version was drifted ("1.0" vs "release-object/v1") — FIXED in PR #1489 |
| `generate_release_object.py` | `schema_version` | Hardcoded | Canonical producer |
| `promote-dev-image.yml` | Validates `schema_version` | Hardcoded | Canonical consumer |
| PCP `release-object-authority-contract.yaml` | Cross-repo governance | PCP | Should be the single authority — not yet enforced |

## Where Release ID Could Be Lost

1. **MFE build failure** — if MFE doesn't build, release-bundle step skips, no dispatch fires
2. **Runner crash** — if runner OOMs during build, entire pipeline stops
3. **Dispatch auth failure** — if App token doesn't work (PROVED WORKING via canary)
4. **Receiver validation failure** — if payload shape drifts (PROVED WORKING via canary)

## What Should Move to Platform-Control-Plane

| Candidate | Current Location | PCP Contract | Priority |
|-----------|-----------------|--------------|----------|
| Release-object schema | `config/release-object-schema.yaml` | `contracts/release-object-authority-contract.yaml` | HIGH — already drifted once |
| Dispatch payload contract | Implicit in workflow YAML | None yet | HIGH — prevent future drift |
| Lane identity | `config/lane-identity.yaml` + `scripts/lib/lane-normalize.sh` | `contracts/lane-identity-contract.yaml` | MEDIUM |
