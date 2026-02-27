# Badges & Credentials Runbook
_Audience: Platform Eng + Academic Operations • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers operational procedures for badges and credentials management.

> **Status**: Badges and credentials are **not yet implemented** (Tier 5). This runbook documents target-state procedures.
> **Spec**: `specs/verifiable-credentials-ops_spec.md`
> **Testmap**: `specs/testmaps/verifiable-credentials-ops_spec.testmap.yml`

## Prerequisites

- LMS admin access
- Credentials service deployed and configured
- Badgr or Open Badges provider account (if external)

---

## Badge Issuing Verification

### Procedure
1. Configure a badge class in LMS admin:
   - Set badge image, criteria, and issuer
   - Associate badge with a course completion event
2. Enroll a test user in the course
3. Complete all course requirements as the test user
4. Verify badge is automatically issued:
   - Badge appears on user's profile page
   - Badge assertion is valid Open Badges 2.0
   - Badge image renders correctly
5. Verify badge email notification is sent (if configured)

### Acceptance
- Badge is issued automatically upon course completion
- Badge assertion validates against Open Badges 2.0 spec
- Badge image displays correctly on profile
- Badge is viewable by other users on the public profile

---

## Credential Template Testing

### Procedure
1. Create a credential template in the Credentials service:
   - Set template design (logo, text, colors)
   - Configure signatories
2. Generate a test credential for a completed course
3. Verify credential renders correctly:
   - Student name is correct
   - Course name and date are accurate
   - Signatories appear with correct titles
4. Test LinkedIn integration:
   - Click "Add to LinkedIn Profile" button
   - Verify credential appears on LinkedIn

### Acceptance
- Credential template renders without layout issues
- All dynamic fields (name, course, date) populate correctly
- PDF download produces a valid, printable document
- LinkedIn sharing URL opens correct LinkedIn add-profile-section page

---

## Badge Revocation Testing

### Procedure
1. Identify a test user with an issued badge
2. Revoke the badge via LMS admin:
   - Navigate to badge assertion
   - Click revoke, provide reason
3. Verify badge is removed from user's profile
4. Verify badge assertion returns "revoked" status
5. Verify revocation is logged for audit

### Acceptance
- Revoked badge no longer appears on user profile
- Badge assertion endpoint returns revoked status
- Revocation reason is recorded in audit log
- Revocation cannot be undone (new badge must be issued)
