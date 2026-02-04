# ADR-003: Image Build Pipeline

**Status**: Accepted
**Date**: 2026-02-03
**Deciders**: Platform Team

## Context

Open edX requires custom Docker images with:
- Platform code (LMS, CMS)
- Custom themes
- Plugin configurations
- MFE (Micro-Frontend) builds

We needed a reliable image build and distribution pipeline.

## Decision

We use **Tutor-based builds** with images pushed to **GCP Artifact Registry**.

## Consequences

### Positive
- Tutor handles complex Open edX build configuration
- Artifact Registry integrates natively with GKE
- Regional storage (asia-southeast1) for low latency
- Built-in vulnerability scanning
- Immutable image tags for reproducibility

### Negative
- Build times are long (30-45 min for full rebuild)
- Requires significant memory (12GB+ for MFE builds)
- Tutor abstraction can be opaque

## Alternatives Considered

### Docker Hub
- Familiar, widely used
- **Rejected because**: Egress from GKE to Docker Hub adds latency and cost

### GitHub Container Registry (GHCR)
- Free for public images
- Good GitHub Actions integration
- **Rejected because**: Cross-cloud egress, less integration with GKE

## Implementation Notes

- Registry: `asia-southeast1-docker.pkg.dev/mereka-lms/openedx`
- Image tags: `dev`, `production`, or git SHA (`staging` tag is deprecated/unused)
- Build script: `scripts/branding/deploy-branded-image.sh`
- Memory requirement: Docker Desktop needs 12GB+ RAM for webpack builds
