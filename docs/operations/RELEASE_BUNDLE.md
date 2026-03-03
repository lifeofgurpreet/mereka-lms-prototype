# Release Bundle Contract

`build-tutor-images.yml` now emits a canonical `release-bundle` artifact (`var/ci/release-bundle.json`) for deterministic promotion records.
The same workflow also emits `promotion-record` (`var/ci/promotion-record.json`) after GitOps update with the resulting infra commit SHA.

## Contract

- Schema: `infrastructure/ci/release-bundle.schema.json`
- Generator: `scripts/infra/generate-release-bundle.sh`
- Validator: `scripts/qa/verify-release-bundle.sh`

The bundle captures:

- immutable image digests (`openedx`, `mfe`)
- source identity (`repository`, `commit_sha`, workflow run metadata)
- artifact references (`sbom-*`, `slsa-provenance`, `trivy-*`)
- promotion target environment
- release-to-gitops linkage (`release_bundle_id` + resulting `bbi-infrastructure` commit)

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
```
