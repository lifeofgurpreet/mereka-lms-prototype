# Release Bundle Contract

`build-tutor-images.yml` now emits a canonical signed `release-bundle` artifact:
- `var/ci/release-bundle.json`
- `var/ci/release-bundle.sig`
- `var/ci/release-bundle.pem`
for deterministic build provenance records.
The same workflow also emits `build-provenance` (`var/ci/build-provenance.json`) after GitOps update with the resulting infra commit SHA.
`update-gitops` now hard-fails if downloaded `release-bundle` artifact does not match workflow commit SHA, target environment, bundle ID, and both image digests.

## Contract

- Schema: `infrastructure/ci/release-bundle.schema.json`
- Generator: `scripts/infra/generate-release-bundle.sh`
- Validator: `scripts/qa/verify-release-bundle.sh`
- Build provenance validator: `scripts/qa/verify-build-provenance.sh`
- PCP projection renderer: `scripts/release/render_control_plane_release_bundle_projection.py`
- PCP projection verifier: `scripts/qa/verify-control-plane-release-bundle-projection.sh`

The bundle captures:

- immutable image digests (`openedx`, `mfe`)
- source identity (`repository`, `commit_sha`, workflow run metadata)
- artifact references (`sbom-*`, `slsa-provenance`, `trivy-*`)
- promotion target environment
- release-to-gitops linkage (`release_bundle_id` + resulting `infrastructure` commit)
- signature material for blob verification (`.sig` + `.pem`) issued by GitHub OIDC identity

## Local Verification

```bash
./scripts/infra/generate-release-bundle.sh \
  --output var/ci/release-bundle.json \
  --repo Biji-Biji-Initiative/mereka-lms \
  --commit-sha "$(git rev-parse HEAD)" \
  --workflow .github/workflows/build-tutor-images.yml \
  --run-id 1 \
  --run-attempt 1 \
  --target-environment dev \
  --openedx-image example/openedx \
  --openedx-digest sha256:1111111111111111111111111111111111111111111111111111111111111111 \
  --mfe-image example/mfe \
  --mfe-digest sha256:2222222222222222222222222222222222222222222222222222222222222222

./scripts/qa/verify-release-bundle.sh var/ci/release-bundle.json

# Optional: verify signature if cosign + signature artifacts are present
./scripts/qa/verify-release-bundle.sh var/ci/release-bundle.json \
  --signature var/ci/release-bundle.sig \
  --certificate var/ci/release-bundle.pem \
  --certificate-identity "https://github.com/Biji-Biji-Initiative/mereka-lms/.github/workflows/build-tutor-images.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

## Control-plane projection

The app-local release bundle is not yet identical to the canonical
platform-control-plane release-bundle contract. Instead, this repo can render a
truthful partial PCP projection:

```bash
python3 scripts/release/render_control_plane_release_bundle_projection.py \
  --release-bundle-json var/ci/release-bundle.json \
  --output var/ci/control-plane-release-bundle-projection.json

bash scripts/qa/verify-control-plane-release-bundle-projection.sh \
  var/ci/release-bundle.json
```

That projection derives the canonical fields already knowable at build time and
records the remaining unresolved PCP-required fields explicitly. As of this
tranche, those unresolved fields are:

- `config_digest`
- `evidence_pack_ref`
- `rollback_target`

They must be bound later during promotion/realization rather than guessed in the
app build.
