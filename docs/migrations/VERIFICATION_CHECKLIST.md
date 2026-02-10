# Data Migration Verification Checklist
_Audience: Platform Eng + Data Team • Owner: Engineering Lead • Last updated: 2026-02-10_

This checklist covers manual verification procedures for Kajabi and MCT data migrations.

> **Spec**: `specs/data-migrations-kajabi-mct_spec.md`
> **Testmap**: `specs/testmaps/data-migrations-kajabi-mct_testmap.yaml`

## Prerequisites

- Access to production GKE cluster
- LMS admin credentials
- Studio admin credentials
- Access to source platform data (Kajabi exports, MCT API exports)

---

## Pod Restart Recovery

### Procedure
1. Start a migration import job
2. While import is in progress, kill the pod:
   ```bash
   kubectl delete pod -n mereka-lms -l job-name=<migration-job> --force
   ```
3. Verify the job controller recreates the pod
4. Verify migration resumes from checkpoint (not from scratch)
5. Verify imported data integrity after resume

### Acceptance
- Pod restart does not cause data corruption
- Migration resumes from last checkpoint
- No duplicate records created after restart
- Final data count matches expected total

---

## MCT Program Certificates

### Procedure
1. Log in to LMS admin (Discovery admin if applicable)
2. Navigate to Programs section
3. Verify MCT programs are created with correct:
   - Program title
   - Course membership
   - Certificate configuration
4. Check Credentials service for certificate templates:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
   from openedx.core.djangoapps.programs.models import ProgramsApiConfig
   print(ProgramsApiConfig.current())
   "
   ```
5. Verify a test certificate can be generated for a completed program

### Acceptance
- All MCT programs exist in LMS with correct course associations
- Certificate templates are configured for each program
- Test certificate generates with correct student name and program title
- Certificate verification URL works

---

## Studio Course Spot-Check

### Procedure
1. Select 10 representative courses from the migration:
   - 3 Kajabi courses (different content types)
   - 3 MCT courses (different complexity levels)
   - 4 mixed courses (with video, text, quizzes)
2. For each course, verify in Studio:
   - Course structure (sections, subsections, units) matches source
   - Text content renders correctly (no broken HTML)
   - Video embeds are functional
   - Quiz questions and answers are correct
   - Images and attachments load
3. Document any discrepancies

### Acceptance
- All 10 sampled courses have correct structure
- No broken HTML or missing content
- Video embeds point to valid URLs
- Quiz content matches source platform
- Discrepancy rate < 2% of content blocks

---

## User Login Spot-Check

### Procedure
1. Select 10 migrated users (mix of Kajabi and MCT origins)
2. For each user, verify:
   - User can log in (password reset if needed)
   - Dashboard shows correct course enrollments
   - Course progress is preserved (if applicable)
   - Profile data matches source platform
3. Verify admin user accounts have correct permissions

### Acceptance
- All 10 sampled users can authenticate
- Course enrollments match source platform records
- Profile data (name, email) is correct
- No users have unintended admin/staff permissions

---

## Full Rollback Test

### Procedure
1. **In a staging/test environment only** (never production without approval):
2. Take a Velero backup before starting:
   ```bash
   velero backup create pre-rollback-test --include-namespaces mereka-lms
   ```
3. Execute rollback:
   - Restore MySQL from pre-migration backup
   - Restore MongoDB from pre-migration snapshot
   - Redeploy LMS with pre-migration configuration
4. Verify system health after rollback:
   - All services start
   - Users can log in
   - Courses load
   - No migration artifacts remain
5. After verification, restore to post-migration state

### Acceptance
- Rollback completes within RTO (4 hours)
- No data corruption from the rollback process
- System is fully functional after rollback
- Rollback steps are documented and reproducible
