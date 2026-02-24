# ADR-019: Tutor Upgrade Cadence and EOL Policy

**Status**: Accepted
**Date**: 2026-02-24
**Deciders**: Platform Team

## Context

We run Tutor 18.2.2 (Redwood release track). The latest release track is Ulmo (21.x).

Open edX named releases follow alphabetical naming: Palm → Quince → Redwood → Sumac → Teak → Ulmo. Community support for each named release is typically ~12 months after the next release ships, though exact EOL dates are not formally published and must be monitored via the Open edX forum and GitHub.

Key constraints that make upgrades costly:

- `infrastructure/tutor/apply-patches.sh` is ~1666 lines covering MySQL auth plugin, MFE Node 18 toolchain, MongoDB Atlas SRV support, multi-domain CSRF config, Mereka footer components, webpack memory limits, and build retry logic. Each major Tutor release regenerates templates, requiring a full audit and re-port of these patches.
- No automated compatibility test suite exists (tracked as T067). Manual verification is the only gate.
- Team is 2-3 engineers with limited bandwidth for upgrade spikes.
- Production runs on GKE with custom image builds (30-45 min per image). Rollback requires maintaining last-known-good image tags in Artifact Registry.

Ulmo features we are missing: Reusable LTI Store, new MFE architecture improvements, and upstream security patches post-Redwood EOL.

## Decision

**Stay on Redwood (18.x)** until one of these conditions is met:

1. Redwood EOL is announced by the Open edX community (monitor https://discuss.openedx.org/)
2. A critical security fix is backported only to Ulmo or later
3. A required feature (Purchase Gateway integration, new MFE) is only available on Ulmo+

**Upgrade cadence**: Evaluate quarterly. Execute at most one major version upgrade per quarter.

**Triggers that override the quarterly cadence**:
- CVE rated CVSS ≥ 8.0 with no available Redwood patch
- Upstream dependency (Python, Node, MySQL) drops Redwood support

**Pre-upgrade checklist** (must be complete before any upgrade begins):
- [ ] T067 compatibility test suite exists and passes on current version
- [ ] Full database backup verified restorable (`tutor local do backup-db`)
- [ ] Last-known-good image tags pinned in Artifact Registry
- [ ] `apply-patches.sh` audit complete against new version's template diff
- [ ] Nonprod environment available and tested

## Upgrade Process

When a decision to upgrade is made, follow these steps on a spike branch:

1. **Create spike branch**: `git checkout -b spike/tutor-upgrade-<version>`
2. **Pin new version**: Update `pip install "tutor[full]==<new-version>"` in setup docs and `requirements.txt`
3. **Run `tutor config save`** with new version to generate new templates
4. **Audit `apply-patches.sh`**: Diff old vs new templates to find what changed. Update patch targets accordingly. Expect 2-8 hours of work per major version.
5. **Run compatibility test suite** (T067): Verify all patches apply cleanly, services start, login works, course enrollment works
6. **Build images**: `tutor images build openedx && tutor images build mfe`. Tag with upgrade version.
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
| Redwood | 18.x | ~12 months after Sumac GA (confirm at discuss.openedx.org) |
| Sumac | 19.x | ~12 months after Teak GA |
| Teak | 20.x | ~12 months after Ulmo GA |
| Ulmo | 21.x | Active (latest as of 2026-02) |

**Note**: These dates are estimates. The Open edX community does not publish hard EOL dates. Subscribe to the `openedx-announce` mailing list and monitor https://github.com/openedx/openedx-releases for official announcements.

## Current Version Pin

| Package | Version | Release Track |
|---------|---------|---------------|
| `tutor[full]` | **18.2.2** | Redwood |
| `tutor-mfe` | **18.1.0** | Redwood |

### Where the pin lives

| Location | File | Line reference |
|----------|------|----------------|
| CI — image build | `.github/workflows/build-tutor-images.yml` | ~94, ~270 |
| CI — config verify | `.github/workflows/tutor-config-verify.yml` | ~38, ~102, ~187, ~252 |
| CI — plugin test | `.github/workflows/tutor-plugin-test.yml` | ~34, ~151, ~269 |
| CI — general CI | `.github/workflows/ci.yml` | ~482, ~490 |
| Dev setup script | `scripts/shared/setup-local.sh` | ~48 |
| Onboarding docs | `docs/onboarding/QUICK_START_LOCAL.md` etc. | multiple |

The canonical install command is:
```bash
pip install "tutor[full]==18.2.2" tutor-mfe==18.1.0
```

### Checking for patch releases

```bash
# List all available Tutor patch releases on the 18.x line
pip index versions "tutor[full]" 2>/dev/null | grep -oE '18\.[0-9]+\.[0-9]+'

# Or check PyPI directly
# https://pypi.org/project/tutor/#history

# Similarly for tutor-mfe
pip index versions "tutor-mfe" 2>/dev/null | grep -oE '18\.[0-9]+\.[0-9]+'
```

To verify all repo references are consistent, run:
```bash
./scripts/qa/verify-tutor-version-pin.sh
```

### Known documentation discrepancy

`CLAUDE.md` (the project root instructions file) contains the line:

> **Deployment Tool**: Tutor 21.0.0 (Ulmo)

This is **incorrect**. The actual installed and pinned version is **18.2.2 (Redwood)**. The discrepancy exists because CLAUDE.md was partially updated to reference the latest upstream release without updating the version number. The ground truth is the pip install pins in `.github/workflows/build-tutor-images.yml` and `scripts/shared/setup-local.sh`. Do not update the CLAUDE.md version line without first completing the full upgrade process documented in the "Upgrade Process" section above.

## Consequences

### Positive

- Stable, known-good patch set — no emergency patch rewrites mid-quarter
- Reduced operational risk for a 2-3 person team
- Existing `apply-patches.sh` continues to work without modification
- Predictable upgrade windows aligned to quarterly planning

### Negative

- Missing Ulmo features: Reusable LTI Store, MFE architecture improvements
- Increasing delta between our version and upstream — each deferred upgrade compounds the port effort
- If Redwood EOL arrives before T067 is complete, we may face a forced upgrade without a test suite

### Mitigation

- Quarterly review meeting (calendar event): assess EOL signals, security advisories, and feature gaps
- T067 (compatibility test suite) must be completed within the next quarter to reduce upgrade cost
- If `apply-patches.sh` grows beyond 2000 lines, initiate a simplification pass (convert patches to a proper Tutor plugin) before the next upgrade
