# SLSA Provenance Reference
_Audience: Platform Operators • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

This reference records how build provenance is represented for release images in this repo.

## Current source of truth

- Build provenance is emitted by `.github/workflows/build-tutor-images.yml`.
- The workflow uses `cosign attest` with predicate type `slsaprovenance`.
- The supporting generator is `scripts/infra/generate-build-provenance.sh`.
- Offline policy verification is enforced by `scripts/qa/verify-slsa-provenance.sh`.

## What operators should expect

- provenance artifacts tied to built Open edX and MFE images
- `id-token: write` permission on the provenance job
- pinned `sigstore/cosign-installer` usage in workflow definitions
- provenance JSON that includes `materials` and `subject`

## Operational boundary

- This file is reference, not a deployment runbook.
- For release execution, use [`../../ops/runbooks/RELEASE_EXECUTE_RUNBOOK.md`](../../ops/runbooks/RELEASE_EXECUTE_RUNBOOK.md).
- For release proof decisions, use [`RELEASE_EVIDENCE.md`](RELEASE_EVIDENCE.md) and [`RELEASE_BUNDLE.md`](RELEASE_BUNDLE.md).

## Verification

- `bash scripts/qa/verify-slsa-provenance.sh`
- `bash scripts/infra/generate-build-provenance.sh --help`
