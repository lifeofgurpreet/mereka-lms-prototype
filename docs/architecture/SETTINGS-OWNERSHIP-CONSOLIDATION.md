# Settings Ownership Consolidation

Date: 2026-03-16
Status: OWNERSHIP_MODEL_CHOSEN_AND_MIGRATION_STARTED

## Prior Guardrails and Why They Failed

### What already existed

| Artifact | Purpose | Status |
|----------|---------|--------|
| ADR-027 (RFC) | Defines ownership lanes between repos | Proposed, never executed |
| REPO_BOUNDARIES.md | Documents the dual-settings problem | Active policy, no CI gate |
| DEPLOYMENT_CONTRACT.md | Defines allowed/forbidden patterns | Draft, no enforcement |
| RESOURCE_OWNERSHIP_MATRIX.md | File-by-file classification | Generated once, not maintained |
| verify-gitops-drift.sh | Checks image tag drift | Active but checks tags, NOT settings |
| verify-overlay-ownership.sh | Checks deprecation markers | Active but checks structure, NOT content |
| verify-settings-ownership.sh | Checks MFE_CONFIG key conflicts | Just landed (PR #1850) |

### Why regression was still possible

The system had **structural boundary awareness** but **no semantic
drift detection**. Specifically:

1. **ADR-027 was never executed.** It correctly identified the problem
   (app repo contains overlays it shouldn't; infra contains app logic
   it shouldn't) but remained in RFC status with no CI enforcement.

2. **Guardrails targeted the wrong layer.** `verify-gitops-drift.sh`
   checked image tags and kustomization structure, not Python settings
   content. A developer could change a Django setting in the infra
   overlay and no CI would catch the contradiction with the app repo.

3. **The overlay files are not "patches" — they are full forks.**
   The infra overlay `production-staging.py` files are 1000+ line
   complete Django settings modules that duplicate and override the
   app repo's `production.py`. Any change to the app repo's settings
   is invisible to the overlay fork unless manually propagated.

4. **No vendor-sync enforcement.** The vendored base copy in infra
   could fall behind the app repo indefinitely. PR #1824 was a
   manual one-time sync, not an automated process.

5. **The "patched settings" name was misleading.** ConfigMaps named
   `openedx-settings-lms-patched` suggest small surgical patches,
   but they contain complete 1000-line Django settings modules that
   replace the base entirely. This naming confusion allowed the
   scope creep to go unquestioned.

### Exact failure mode

The Studio URL incident: infra overlay `production-staging.py` set
`COURSE_AUTHORING_MICROFRONTEND_URL = "/course-authoring"` while
app repo `production.py` correctly set `/authoring`. No guardrail
compared these values. The overlay won at runtime. Studio broke.

## Ownership Decision: OPTION A — APP-OWNED SETTINGS

### Rationale

| Criterion | Option A (App-Owned) | Option B (Infra-Owned) |
|-----------|---------------------|----------------------|
| Correctness | App team reviews Django logic | Infra team reviews Django logic |
| CI/testability | App CI can lint/test settings | Infra CI lacks Django test infra |
| Drift risk | One canonical source | Vendored copies drift |
| Incident class | Prevented by design | Requires manual sync |
| GitOps fit | App builds images + settings; infra wires them | Infra owns both wiring AND logic |
| Migration complexity | Move settings to app; reduce overlays | Move tests to infra; duplicate tooling |

**Decision: Option A.** mereka-lms owns all Django/application settings
logic. bbi-infrastructure owns environment wiring only.

### Boundary Definition

**Application behavior (mereka-lms owns)**:
- All Django settings logic
- Route/URL construction logic
- Theme/branding defaults
- Feature flags and policy decisions
- JWT/OIDC/auth configuration logic
- Multisite/tenancy behavior
- Plugin/custom-app registration
- MFE_CONFIG defaults

**Environment wiring (bbi-infrastructure owns)**:
- Hostnames and domain names
- Secret references (not the logic that uses them)
- Ingress/TLS/DNS
- Resource sizing and replica counts
- Image tags and digests
- Cluster-specific service URLs
- ConfigMap/Secret mounting mechanics

**Transitional (to be eliminated)**:
- Overlay Python settings forks (production-staging.py etc.)
  These 1000+ line forks mix app behavior with env values.
  Target: decompose into app-owned base + thin env-value injection.

## Diverged File Resolution

| File | App Repo | Infra Vendored | Diff | Canonical | Next Action |
|------|----------|----------------|------|-----------|-------------|
| lms/production.py | 1887 lines | In sync | 0 | App repo | Maintain sync |
| cms/production.py | 730 lines | In sync | 0 | App repo | Maintain sync |
| lms/mereka_multisite.py | Current | Stale (240 diff lines) | Diverged | App repo | Vendor-sync infra |
| cms/mereka_multisite.py | Current | Stale (36 diff lines) | Diverged | App repo | Vendor-sync infra |

## Enforcement Landed

### verify-vendored-settings-drift.sh

Checks that the 9 tracked Django settings files in the infra
vendored copy match the app repo source. Fails with exact diff
line count for each diverged file.

Current result: 7 PASS, 2 FAIL (multisite files diverged).

This script should be added to CI in bbi-infrastructure to
block PRs that don't include a vendor-sync when the base
settings change.

## Migration Plan

### Wave 0: Anti-Drift (THIS LANE — DONE)
- verify-vendored-settings-drift.sh landed
- verify-settings-rollout-hash.sh landed (PR #1850)
- verify-settings-ownership.sh landed (PR #1850)
- Scope: detect and prevent further divergence
- Risk: low (read-only checks)
- Acceptance: all 3 verifiers pass on current state

### Wave 1: Sync Diverged Files (NEXT)
- Vendor-sync mereka_multisite.py (LMS + CMS) to infra
- Scope: 2 files
- Risk: low (multisite behavior already correct in app repo)
- Prerequisite: Wave 0 complete
- Acceptance: verify-vendored-settings-drift.sh → 0 FAIL

### Wave 2: Decompose Overlay Forks
- Split production-staging.py into:
  - env-values.yaml (hostnames, URLs) — stays in infra
  - app-behavior imports from base — consumed from app repo
- Scope: 4 overlay fork files (dev, staging, prod LMS; dev CMS)
- Risk: medium (runtime behavior depends on these)
- Prerequisite: Wave 1 complete, overlay structure documented
- Acceptance: overlay files < 200 lines each, contain only env values

### Wave 3: Plugin/Service Settings
- Move credentials/discovery/notes/xqueue settings to app repo
- Remove infra-side duplicates
- Scope: ~12 files
- Risk: low (satellite services, not core LMS/CMS)
- Prerequisite: Wave 2 complete
- Acceptance: verify-vendored-settings-drift.sh covers all families

### Wave 4: Close ADR-027
- Remove deprecated overlays from app repo
- Formalize the boundary in an accepted ADR
- Remove legacy vendored base from infra (consume via submodule or artifact)
- Scope: structural cleanup
- Risk: medium (requires coordinated change)
- Prerequisite: Waves 0-3 complete
- Acceptance: ADR accepted, no Django settings files in infra overlays
