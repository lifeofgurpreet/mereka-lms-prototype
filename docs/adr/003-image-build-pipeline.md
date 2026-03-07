# ADR-003: Image Build Pipeline

**Status**: Accepted
**Date**: 2026-02-03
**Deciders**: Platform Team

<!-- Last verified: 2026-02-13 -->

## Context

Open edX requires custom Docker images with:
- Platform code (LMS, CMS)
- Custom themes
- Plugin configurations
- MFE (Micro-Frontend) builds

We needed a reliable image build and distribution pipeline.

## Decision

We use **Tutor-based builds** with images pushed to **GHCR** (`ghcr.io/biji-biji-initiative/mereka-lms`).
GitOps overlays pin runtime image tags/digests as the deployment source of truth.

## Consequences

### Positive
- Tutor handles complex Open edX build configuration
- GHCR integrates directly with GitHub-native CI release flow
- Digest pinning in GitOps overlays supports deterministic rollouts
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
- **Selected**: aligns with current CI/CD pipeline and release contracts.

## Implementation Notes

- Registry: `ghcr.io/biji-biji-initiative/mereka-lms`
- Image tags: `dev`, `production`, or git SHA (legacy `staging` tag is deprecated/unused)
- Build/release path: `scripts/infra/release-openedx-gitops.sh`
- Memory requirement: Docker Desktop needs 12GB+ RAM for webpack builds
