---
title: Repository Structure Specification
type: feature_spec
status: draft
owner: engineering
vehicle: talent_platform
last_updated: '2026-02-08'
---

# Repository Structure Specification

**Status**: Active
**Last Updated**: 2026-02-03

## Overview

This spec defines the directory structure for the Mereka LMS repository.

## MUST Requirements

### Root Directory
The root MUST contain only these markdown files:
- README.md - Project overview
- CLAUDE.md - AI agent instructions
- AGENTS.md - Repository guidelines
- CONTRIBUTING.md - Contributor guide
- MIGRATION_CHECKLIST.md - Active migration tracking

All other markdown files MUST be in docs/ or docs/archive/.

### Directory Structure

```
/
├── deploy/                    # Deployment manifests
│   └── k8s/
│       ├── base/              # Base Kustomize resources
│       │   ├── secrets/       # ExternalSecrets (NOT static secrets)
│       │   ├── apps/          # App-specific configs
│       │   └── plugins/       # Plugin configs
│       └── overlays/          # Environment-specific overlays
│           ├── local/
│           ├── staging/       # Legacy (reference only)
│           └── production/
│
├── scripts/                   # All executable scripts
│   ├── shared/                # Shared utilities (config.sh, setup-local.sh)
│   ├── infra/                 # Infrastructure scripts
│   ├── migrations/            # Data migration scripts
│   ├── analytics/             # Analytics scripts
│   ├── qa/                    # QA and testing scripts
│   └── branding/              # Theme/branding scripts
│
├── infrastructure/            # Infrastructure-as-code
│   ├── tutor/                 # Tutor configs, patches, themes
│   ├── cloudflare/            # DNS records
│   ├── terraform/             # Terraform configs
│   └── monitoring/            # Monitoring configs
│
├── docs/                      # Documentation
│   ├── adr/                   # Architecture Decision Records
│   ├── onboarding/            # Setup guides
│   ├── operations/            # Runbooks
│   ├── migrations/            # Migration playbooks
│   ├── architecture/          # System design
│   └── archive/               # Historical docs
│
├── services/                  # Microservices
└── var/                       # Runtime artifacts (gitignored)
```

### Deprecated Directories
These directories MUST NOT contain scripts (only README.md allowed):
- /tools/ - MOVED to /scripts/
- /ops/ - MOVED to /infrastructure/ and /scripts/

## SHOULD Requirements
- Scripts SHOULD source scripts/shared/config.sh for common variables
- K8s manifests SHOULD use overlays for environment-specific config
- Documentation SHOULD link to relevant specs

## Verification

```bash
# Check deprecated directories are empty (except README)
ls tools/  # MUST only show README.md
ls ops/    # MUST only show README.md

# Check required directories exist
ls scripts/shared/config.sh    # MUST exist
ls deploy/k8s/overlays/        # MUST have local + production (staging is legacy)
ls docs/adr/                   # MUST have ADRs

# Check root markdown files
ls *.md | wc -l                # MUST be 5
```


## Scope

_Defines the boundaries of this specification._

## Non-goals

_Explicitly out of scope for this specification._

## Requirements

- This section requires review to add MUST/SHOULD/MAY requirements.

## Acceptance Criteria

- [ ] Acceptance criteria to be defined.

## Edge Cases

_Edge cases to be documented._

## Observability

_Logging, metrics, and alerting requirements to be defined._

## Rollout & Rollback

_Rollout strategy and rollback procedures to be defined._

## Open Questions

_No open questions at this time._
