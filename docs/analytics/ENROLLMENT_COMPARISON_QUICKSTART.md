# Enrollment Comparison Quick Start
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-10-01_

Quick guide to compare enrollments between Kajabi and Open edX.

## Prerequisites

- Kajabi exports completed (`exports/kajabi/` populated)
- Open edX instance running
- Course packages imported into Open edX

## Quick Run

```bash
# 1. Export certificate eligibility from Kajabi
export KAJABI_CLIENT_ID="your_id"
export KAJABI_CLIENT_SECRET="your_secret"
node tools/kajabi-export-certificates.mjs

# 2. Export enrollments from Open edX
./tools/openedx-export-enrollments.sh exports/openedx/enrollments.csv

# 3. Compare enrollments
python tools/compare-enrollments-kajabi-openedx.py \
  --kajabi-enrollments scripts/migrations/kajabi/output/enrollments.csv \
  --kajabi-users scripts/migrations/kajabi/output/users.csv \
  --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
  --openedx-enrollments exports/openedx/enrollments.csv \
  --course-manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --output-dir scripts/migrations/kajabi/output/comparison
```

## Output Files

- `scripts/migrations/kajabi/output/comparison/enrollment_comparison.csv` - Detailed per-course comparison
- `scripts/migrations/kajabi/output/comparison/summary.txt` - Summary statistics

## Interpreting Results

### Enrollment Comparison CSV

Look for:
- **Discrepancy column**: Positive = more in Kajabi, Negative = more in Open edX
- **missing_in_openedx**: Users enrolled in Kajabi but not Open edX
- **certificate_eligible**: Users eligible for certificates in Kajabi

### Action Items

1. **If discrepancy > 0**: Re-import missing enrollments
2. **If certificate_eligible > 0**: Generate certificates for eligible users
3. **If missing_emails listed**: Check if users exist in Open edX with different emails

## Certificate Migration

Since Kajabi API doesn't expose certificates:

1. **Manual export from Kajabi UI**:
   - Analytics → Certificates → Export
   - Match with `certificate_eligibility.ndjson` by email + course_id

2. **Generate in Open edX**:
   ```bash
   # For each course with certificate-eligible users
   tutor local run lms ./manage.py lms generate_certificates \
     --course-id course-v1:ORG+NUMBER+RUN \
     --settings=tutor.production
   ```

See [`docs/migrations/kajabi/KAJABI_CERTIFICATE_MIGRATION.md`](../migrations/kajabi/KAJABI_CERTIFICATE_MIGRATION.md) for detailed instructions.
