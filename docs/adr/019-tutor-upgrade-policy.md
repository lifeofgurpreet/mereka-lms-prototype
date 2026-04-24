---
id: ADR-019
title: Tutor Upgrade Cadence and EOL Policy
decision_status: accepted
decision_type: foundation
rollout_state: active
owner: platform-team
created: '2026-02-24'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on: []
read_next:
- ADR-021
- ADR-028
governs:
- build.release-line
- platform.upgrade-policy
does_not_govern: []
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions:
- scripts/qa/verify-tutor-version-governance.sh
- scripts/qa/verify-repo-structure.sh
expiry_date: null
removal_condition: null
---
<!-- markdownlint-disable -->

# ADR-019: Tutor Upgrade Cadence and EOL Policy

**Status**: Accepted (Updated 2026-04-21)
**Date**: 2026-02-24 (original), 2026-03-03 (updated)
**Deciders**: Platform Team

## Context

We run **Tutor 21.0.4 (Ulmo)** with explicit first-party plugin pins. The canonical version pin lives in `requirements-tutor.txt` and all workflows/scripts consume that pin.

Open edX named releases follow alphabetical naming: Palm → Quince → Redwood → Sumac → Teak → Ulmo. Community support for each named release is typically ~12 months after the next release ships, though exact EOL dates are not formally published and must be monitored via the Open edX forum and GitHub.

Key constraints that make upgrades costly:

- `infrastructure/tutor/apply-patches.sh` and `infrastructure/tutor/plugins/mereka_lms.py` cover MySQL auth plugin, MongoDB Atlas SRV support, multi-domain CSRF config, Mereka footer components, webpack memory limits, theme compilation, and build retry logic. Each major Tutor release regenerates templates, requiring a full audit and re-port of these patches.
- No automated compatibility test suite exists (tracked as T067). Manual verification is the only gate.
- Team is 2-3 engineers with limited bandwidth for upgrade spikes.
- Production runs on GKE with custom image builds (30-45 min per image). Rollback requires maintaining last-known-good image tags in GHCR and GitOps overlays.

### History

The original decision (2026-02-24) was to stay on Redwood (18.x) until an EOL trigger forced the upgrade. The upgrade to Ulmo was completed on 2026-03-03 as part of the CI/build pipeline overhaul (see ADR-021). The policy below now governs future upgrades from Ulmo onward.

## Decision

**Stay on the current release line (Ulmo 21.x)** until one of these conditions is met:

1. Ulmo EOL is announced by the Open edX community (monitor https://discuss.openedx.org/)
2. A critical security fix is backported only to a later release
3. A required feature is only available on a newer release

**Upgrade cadence**: Evaluate quarterly. Execute at most one major version upgrade per quarter.

**Triggers that override the quarterly cadence**:
- CVE rated CVSS ≥ 8.0 with no available patch on the current release
- Upstream dependency (Python, Node, MySQL) drops support for the current release

**Pre-upgrade checklist** (must be complete before any upgrade begins):
- [ ] T067 compatibility test suite exists and passes on current version
- [ ] Full database backup verified restorable (`tutor local do backup-db`)
- [ ] Last-known-good image tags pinned in GHCR and GitOps overlays
- [ ] `apply-patches.sh` and `mereka_lms.py` audit complete against new version's template diff
- [ ] Nonprod environment available and tested

## Upgrade Process

When a decision to upgrade is made, follow these steps on a spike branch:

1. **Create spike branch**: `git checkout -b spike/tutor-upgrade-<version>`
2. **Pin new version**: Update `requirements-tutor.txt` (single source of truth for all version pins)
3. **Run `tutor config save`** with new version to generate new templates
4. **Audit patches**: Diff old vs new templates to find what changed. Update `apply-patches.sh` and `mereka_lms.py` patch targets accordingly. Expect 2-8 hours of work per major version.
5. **Run compatibility test suite** (T067): Verify all patches apply cleanly, services start, login works, course enrollment works
6. **Build images**: `./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast` and `./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast`. Tag with upgrade version.
7. **Test in nonprod**: Full smoke test against nonprod cluster. Verify LMS, Studio, MFE, Forum, Discovery
8. **Cut release**: Merge spike branch, tag release, deploy to prod
9. **Rollback plan active**: Keep previous image tags live for 48 hours post-deploy. Document rollback command:
   ```bash
   # Rollback to last-known-good images
   kubectl set image deployment/lms lms=<registry>/openedx:<previous-tag> -n mereka-lms
   kubectl set image deployment/cms cms=<registry>/openedx:<previous-tag> -n mereka-lms
   ```

## EOL Dates

| Release | Version | Estimated Support End |
|---------|---------|----------------------|
| Redwood | 18.x | EOL (superseded by Sumac) |
| Sumac | 19.x | ~12 months after Teak GA |
| Teak | 20.x | ~12 months after Ulmo GA |
| Ulmo | 21.x | **Active (current, latest as of 2026-04)** |

**Note**: These dates are estimates. The Open edX community does not publish hard EOL dates. Subscribe to the `openedx-announce` mailing list and monitor https://github.com/openedx/openedx-releases for official announcements.

## Current Version Pin

| Package | Version | Release Track |
|---------|---------|---------------|
| `tutor` | **21.0.4** | Ulmo |
| `tutor-mfe` | **21.0.0** | Ulmo |
| `tutor-indigo` | **Retired** | Replaced by repo-owned Mereka theme/plugin path |

### Where the pin lives

The **single source of truth** is `requirements-tutor.txt` in the repo root. All install commands reference this file:

```bash
pip install -r requirements-tutor.txt
```

Files that consume this pin:
- `.github/workflows/build-tutor-images.yml` — CI image builds
- `.github/workflows/ci.yml` — CI config validation
- `scripts/shared/setup-local.sh` — local dev setup
- `docs/guides/onboarding/*.md` — onboarding guides

### Checking for patch releases

```bash
# List all available Tutor patch releases on the 21.x line
pip index versions tutor 2>/dev/null | grep -oE '21\.[0-9]+\.[0-9]+'

# Or check PyPI directly
# https://pypi.org/project/tutor/#history
```

To verify all repo references are consistent, run:
```bash
./scripts/qa/verify-tutor-version-pin.sh
```

## Scope

This ADR governs the decision boundary described by ADR-019.

## Non-goals

This document does not replace broader platform standards, runbooks, or implementation evidence.

## Verification

- `scripts/qa/verify-tutor-version-governance.sh`
- `scripts/qa/verify-repo-structure.sh`

## Consequences

### Positive

- On the latest community-supported release — receiving upstream security patches and features
- Plugin API (Tutor 21) enables `PLUGIN_SLOTS` for frontend customization — no more Dockerfile surgery for MFE components
- Stable, known-good patch set — no emergency patch rewrites mid-quarter
- Predictable upgrade windows aligned to quarterly planning
- Single source of truth (`requirements-tutor.txt`) prevents version drift across docs/CI/scripts

### Negative

- Increasing delta between our version and upstream over time — each deferred upgrade compounds the port effort
- If the next release EOL arrives before T067 is complete, we may face a forced upgrade without a test suite

### Mitigation

- Quarterly review meeting (calendar event): assess EOL signals, security advisories, and feature gaps
- T067 (compatibility test suite) must be completed within the next quarter to reduce upgrade cost
- Continue migrating Dockerfile surgery patches to Tutor plugin hooks (ADR-021) to reduce per-upgrade audit burden
