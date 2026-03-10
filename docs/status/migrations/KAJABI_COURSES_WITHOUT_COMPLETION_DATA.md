# Kajabi Courses Without Completion Data

**Status**: Decision Made
**Date**: 2026-02-13
**Decision Owner**: Platform Team

## Context

During the Kajabi to Open edX migration, four courses were imported successfully but lack completion tag data in the Kajabi export. This means we have no historical certificate or completion records for learners who completed these courses in Kajabi.

## Affected Courses

| Course | Code | Notes |
|--------|------|-------|
| Digital Presence | DP | No completion tags in Kajabi export |
| Design Thinking | DT | No completion tags in Kajabi export |
| AI Courses | AI | No completion tags in Kajabi export |
| PKMU | PKMU | No completion tags in Kajabi export |

## Options Considered

### Option 1: Accept No Historical Certificates
- **Pro**: Simplest approach, no data fabrication
- **Con**: Users who completed in Kajabi won't have certificates in Open edX

### Option 2: Find Completion Data from Another Source
- **Pro**: Could restore historical completions
- **Con**: No alternative source available; Kajabi export is the canonical source

### Option 3: Fresh Start - Only Issue Certificates for New Completions
- **Pro**: Clean, verifiable data going forward
- **Pro**: Aligns with platform migration best practices
- **Con**: Users lose historical completion records

## Decision

**Accept Option 3: Fresh Start**

Only issue certificates for new completions in Open edX. Historical completions in Kajabi will not be migrated for these four courses.

## Rationale

1. **Data Integrity**: We cannot fabricate completion data that doesn't exist
2. **Minimal Impact**: These are newer courses with relatively few completions in Kajabi
3. **Clean Foundation**: Starting fresh ensures all certificate data is verifiable
4. **Platform Migration Standard**: Common practice to reset completion tracking during platform migrations

## Impact Assessment

- **User Impact**: Minimal - these courses had limited enrollment in Kajabi
- **Certificate Impact**: No historical certificates issued for these four courses
- **Going Forward**: All completions in Open edX will receive proper certificates

## Implementation Notes

- Course content is fully imported and available in Open edX
- Completion tracking and certificate issuance works normally for new enrollments
- No technical blockers for issuing certificates going forward

## Related Documentation

- Kajabi migration guide: `docs/migrations/BBI-K8-MIGRATION.md`
- Certificate configuration: `docs/guides/admin/COURSE_CERTIFICATES_UI.md`
