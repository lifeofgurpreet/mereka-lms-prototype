# SLSA Build Provenance

## Overview

The `build-tutor-images.yml` workflow generates SLSA-style build provenance for every OCI image pushed to Artifact Registry. Provenance is attached as a cosign attestation (keyless, via Sigstore OIDC) and uploaded as a workflow artifact.

**Images covered:**
- `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx`
- `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/mfe`

## How It Works

1. The `slsa-provenance` job runs after `build-openedx` and `build-mfe` complete.
2. For each image, a JSON predicate is generated containing:
   - `buildType` (workflow URL)
   - `builder.id` (GitHub Actions run URL)
   - `invocation.configSource` (repo, ref, commit SHA)
   - `materials` (source repo + commit)
   - `subject` (image name + digest)
3. `cosign attest --type slsaprovenance` attaches the predicate to the image in Artifact Registry using keyless signing (GitHub OIDC identity).
4. The raw JSON is uploaded as a `slsa-provenance` workflow artifact (90-day retention).

## Verifying Attestations

### Automated (CI)

The verification script runs offline checks by default:

```bash
./scripts/qa/verify-slsa-provenance.sh
```

### Manual (with cosign)

```bash
# Install cosign
# https://docs.sigstore.dev/cosign/system_config/installation/

# Verify an image attestation
cosign verify-attestation \
  --type slsaprovenance \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp 'https://github.com/Biji-Biji-Initiative/mereka-lms/' \
  asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx@sha256:<DIGEST>
```

### Online checks (requires registry access + cosign)

```bash
./scripts/qa/verify-slsa-provenance.sh --online
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `cosign attest` fails with 403 | Missing `id-token: write` permission | Check `slsa-provenance` job permissions |
| `cosign attest` fails with auth error | GCP SA key not configured | Verify `GCP_SA_KEY` secret is set |
| Attestation not found on image | Job skipped (build failed) | Check build job status; provenance only runs on success |
| `verify-attestation` rejects signature | Wrong OIDC issuer or identity | Use the exact issuer/identity patterns shown above |

## Security Properties

- **Keyless signing**: No long-lived signing keys. Identity comes from GitHub Actions OIDC token.
- **Tamper evidence**: Attestation is stored in the OCI registry alongside the image. Modifying the image invalidates the attestation.
- **Auditability**: Provenance JSON is also preserved as a workflow artifact for offline inspection.
- **SLSA Level**: This provides SLSA Build L1 guarantees (build process documented, provenance generated automatically).
