# Migration Dry Run Results (2026-02-03)

## Summary

- **MCT**: Dry run succeeded (export plan validated).
- **Kajabi**: Dry run skipped (required manifest + tarballs missing).

## Commands Executed

```bash
./scripts/migrations/run-dry-run.sh
```

## MCT Dry Run Output (Excerpt)

```
Base URL: learn.skillourfuture.org
API Version: v1
Resources: users, courses, enrollments
[DRY RUN] Would authenticate with MCT API...
[users] Would export from v1: https://learn.skillourfuture.org/api/v1/Reports/Users
[courses] Would export from v1: https://learn.skillourfuture.org/api/v1/Courses
[enrollments] Would export from v1: https://learn.skillourfuture.org/api/v1/Reports/Course/{courseId}/Learners
```

## Kajabi Dry Run Prerequisites

Expected artifacts (any one of the following locations):

- `scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv`
- `var/migrations/kajabi/course_packages/course_packages_manifest.csv`

Re-run after artifacts exist:

```bash
./scripts/migrations/run-dry-run.sh
```
