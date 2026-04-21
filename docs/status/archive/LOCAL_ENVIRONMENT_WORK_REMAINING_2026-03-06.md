# Local Environment Work Remaining
_Audience: Developers • Owner: Ops Domain Owner • Last verified: 2026-03-06 • Status: active_

This is a dated local-environment backlog snapshot. It is preserved as active status, not as a quick reference card.

## Current Status

**Infrastructure**
- All 24 containers running successfully
- LMS accessible at `http://localhost` via Caddy
- Studio accessible at `http://studio.localhost`
- MFEs accessible at `http://apps.localhost`
- Config fixed to use local Docker services instead of cloud IPs
- Branding configured with the current Mereka Academy defaults

## Immediate Local Tasks

### 1. User management and admin setup
**Status:** In progress  
**Priority:** High

- Create the local admin user
- Verify admin panel access
- Test forum integration with a real course
- Keep `docs/ops/quickref/access-urls.md` aligned with the current local entrypoints

### 2. Branding verification and QA
**Status:** Pending  
**Priority:** Medium

- Verify MFE environment copy and branding
- Run smoke checks on the MFEs
- Capture screenshots into evidence surfaces, not guide roots
- Rebuild the MFE image if branding assets changed
- Verify LMS/Studio branding and core learning flows
- Run cross-browser, accessibility, and basic performance checks

### 3. Data migration testing
**Status:** Pending  
**Priority:** Low

- Test Kajabi import scripts locally with sample data
- Test MCT import scripts locally with sample data
- Verify course structure, enrollment, grading, and credential flows

## Recommended Workflow

1. Create the local admin user and verify admin access.
2. Test basic course creation, enrollment, and forum flows.
3. Complete branding verification and evidence capture.
4. Move to migration testing only after core local functionality is stable.

## Success Criteria

The local environment is considered ready when:
- Admin access works
- Studio can create courses
- LMS can enroll and render courses
- Forum integration works
- Branding is verified on the key pages
- No critical errors remain in the main logs

## Canonical Follow-On Docs

- Full setup: [`../../guides/onboarding/LOCAL_SETUP.md`](../../guides/onboarding/LOCAL_SETUP.md)
- Daily workflow: [`../../guides/onboarding/WORKFLOW_LOCAL.md`](../../guides/onboarding/WORKFLOW_LOCAL.md)
- Local URLs and entrypoints: [`../../ops/quickref/access-urls.md`](../../ops/quickref/access-urls.md)
