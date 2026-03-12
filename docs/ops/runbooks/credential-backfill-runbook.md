# Verifiable Credential Backfill Runbook
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

**Spec**: `specs/verifiable-credentials-ops_spec.md` (CRED-050)
**Use Case**: Issue VCs for learners who completed courses/programs before VC feature was enabled
**Frequency**: One-time per course/program when enabling VCs

---

## Overview

The `backfill_credentials` management command issues Verifiable Credentials retroactively for learners who earned certificates before the VC feature was enabled. This ensures all learners have access to portable, verifiable credentials regardless of when they completed their coursework.

**Key Properties**:
- **Idempotent**: Safe to run multiple times (skips already-issued VCs)
- **Rate-limited**: Default 10 credentials/second to prevent overload
- **Dry-run mode**: Preview what would be created without actually creating VCs

---

## Prerequisites

- [ ] kubectl access to production cluster (`mereka-lms` namespace)
- [ ] Course/Program IDs for backfill
- [ ] Estimated learner count (for capacity planning)
- [ ] Approval from platform engineering (for large backfills >1000 learners)

---

## Step 1: Gather Target Courses/Programs

```bash
# List courses with certificates issued before VC feature enabled
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py shell -c "
from credentials.apps.credentials.models import ProgramCertificate, CourseCertificate
from datetime import datetime

vc_enabled_date = datetime(2026, 2, 14)  # Replace with actual VC launch date

# Courses with certificates issued before VC
courses = CourseCertificate.objects.filter(
    created__lt=vc_enabled_date
).values_list('course_id', flat=True).distinct()

print(f'Courses to backfill: {list(courses)[:10]}...')
print(f'Total courses: {len(courses)}')
"

# Count learners per course
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py count_backfill_candidates \
  --course-id "course-v1:MerekaX+EXAMPLE+2025"
```

**Record**:
- Course/Program IDs to backfill
- Learner counts per course
- Total estimated VCs to create

---

## Step 2: Dry-Run Test

**CRITICAL**: Always run with `--dry-run` first to verify scope.

```bash
# Dry-run for single course
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py backfill_credentials \
  --course-id "course-v1:MerekaX+EXAMPLE+2025" \
  --dry-run

# Expected output:
# Dry-run mode: No credentials will be created
# Found 142 learners with certificates but no VC
# Would create 142 VCs for course-v1:MerekaX+EXAMPLE+2025
# Estimated runtime: 14 seconds (at 10 VCs/second)
```

**Verify**:
- [ ] Learner count matches expected value
- [ ] Estimated runtime is reasonable
- [ ] No errors in dry-run output

---

## Step 3: Execute Backfill (Single Course)

```bash
# Run backfill for single course (no dry-run flag)
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py backfill_credentials \
  --course-id "course-v1:MerekaX+EXAMPLE+2025" \
  --rate-limit 10

# Expected output:
# Backfilling VCs for course-v1:MerekaX+EXAMPLE+2025
# [2026-02-14 10:15:32] VC issued: credential_uuid=abc123, learner_id=user-456, tenant=mereka
# [2026-02-14 10:15:32] VC issued: credential_uuid=def456, learner_id=user-789, tenant=mereka
# ...
# Completed: 142 VCs issued, 0 skipped (already exist), 0 errors
# Total runtime: 14.2 seconds
```

**Monitor**:
```bash
# Watch signing error rate during backfill
kubectl exec -it deployment/prometheus -n monitoring -- \
  promtool query instant http://localhost:9090 \
  'rate(credentials_vc_signing_errors_total{namespace="mereka-lms"}[1m])'

# Expected: 0 (no errors)
```

---

## Step 4: Verify Backfilled Credentials

```bash
# Check that VCs were created
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py shell -c "
from credentials.apps.verifiable_credentials.models import IssuedCredential

# Count VCs for the course
count = IssuedCredential.objects.filter(
    achievement_id='course-v1:MerekaX+EXAMPLE+2025'
).count()

print(f'VCs issued for course: {count}')
"

# Verify a sample credential
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py verify_credential \
  --uuid "SAMPLE_CREDENTIAL_UUID"

# Expected: Verification PASS
```

**Spot-Check**:
- [ ] VC count matches dry-run prediction
- [ ] Sample credential verifies successfully
- [ ] Learner Portal shows VC available

---

## Step 5: Run Second Time (Idempotency Check)

```bash
# Run same backfill again (should skip all)
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py backfill_credentials \
  --course-id "course-v1:MerekaX+EXAMPLE+2025" \
  --rate-limit 10

# Expected output:
# Backfilling VCs for course-v1:MerekaX+EXAMPLE+2025
# Completed: 0 VCs issued, 142 skipped (already exist), 0 errors
# Total runtime: 1.3 seconds
```

**Verify**:
- [ ] Zero new VCs created
- [ ] All 142 learners skipped (already have VCs)
- [ ] No errors

---

## Bulk Backfill (Multiple Courses)

For backfilling many courses at once:

```bash
# Create backfill manifest
cat > /tmp/backfill-manifest.txt <<EOF
course-v1:MerekaX+INTRO101+2025
course-v1:MerekaX+ADV201+2025
course-v1:MerekaX+SPEC301+2025
EOF

# Run backfill loop with progress tracking
kubectl exec -it deployment/credentials -n mereka-lms -- bash <<'SCRIPT'
while read course_id; do
  echo "=== Backfilling: $course_id ==="
  python manage.py backfill_credentials \
    --course-id "$course_id" \
    --rate-limit 10 \
    2>&1 | tee -a /tmp/backfill-log.txt
  echo
done < /tmp/backfill-manifest.txt

echo "=== Backfill Summary ==="
grep "Completed:" /tmp/backfill-log.txt
SCRIPT
```

**Alternative: Tenant-Wide Backfill**
```bash
# Backfill all courses for a specific tenant
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py backfill_credentials \
  --tenant-uuid "ENTERPRISE_UUID" \
  --rate-limit 5

# Slower rate limit for large tenant backfills
```

---

## Program Credentials Backfill

For program completion credentials:

```bash
# Dry-run program backfill
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py backfill_credentials \
  --program-uuid "PROGRAM_UUID" \
  --dry-run

# Execute program backfill
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py backfill_credentials \
  --program-uuid "PROGRAM_UUID" \
  --rate-limit 10
```

---

## Rate Limiting Guidance

| Scenario | Recommended Rate | Reason |
|----------|------------------|--------|
| Single course (<500 learners) | 10/sec (default) | Minimal impact on signing service |
| Large course (500-5000 learners) | 5/sec | Prevent database contention |
| Tenant-wide backfill (>5000 learners) | 2/sec | Sustained load, run during off-peak hours |
| Emergency backfill (production incident) | 1/sec | Conservative, allows monitoring |

**Adjust rate limit**:
```bash
--rate-limit 5  # 5 credentials per second
```

---

## Monitoring During Backfill

```bash
# Open Grafana dashboard
# URL: https://grafana.mereka.io/d/credentials-vc

# Watch panels:
# 1. "Issuance Overview" → VCs issued spike during backfill
# 2. "Issuance Latency" → p95 should stay <30s
# 3. "Signing Health" → Error rate should be 0

# Check CPU/memory usage
kubectl top pod -n mereka-lms -l app.kubernetes.io/name=credentials

# If resources high, scale pods
kubectl scale deployment/credentials -n mereka-lms --replicas=3
```

---

## Troubleshooting

### Backfill command not found
```bash
# Verify management command exists
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py help | grep backfill

# If missing, check Credentials Service version
# backfill_credentials added in credentials:21.1.0+
```

### High error rate during backfill
```bash
# Pause backfill (Ctrl+C)
# Check recent errors
kubectl logs -n mereka-lms -l app.kubernetes.io/name=credentials --tail=50 | grep ERROR

# Common causes:
# - Signing key unavailable: See credential-issuance-failure-runbook.md
# - Database lock contention: Lower --rate-limit
# - Memory pressure: Scale pods horizontally
```

### Backfill incomplete (fewer VCs than expected)
```bash
# Check for learners without certificates
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py audit_missing_credentials \
  --course-id "course-v1:MerekaX+EXAMPLE+2025"

# This reports learners with passing grades but no certificate
# (separate issue from backfill; investigate certificate generation)
```

---

## Post-Backfill Checklist

- [ ] Dry-run completed successfully before execution
- [ ] Actual backfill completed with 0 errors
- [ ] Idempotency verified (second run skipped all learners)
- [ ] Sample credentials verified successfully
- [ ] Grafana metrics show no degradation
- [ ] Backfill logged in operations log

---

## Scheduling Large Backfills

For backfills >10,000 learners:

1. **Schedule during off-peak hours**: 02:00-06:00 UTC (low traffic)
2. **Use Kubernetes CronJob** instead of manual execution
3. **Email notifications** on completion/failure

Example CronJob:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: vc-backfill-batch-2026-02
  namespace: mereka-lms
spec:
  schedule: "0 3 * * *"  # 03:00 UTC daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backfill
            image: ghcr.io/biji-biji-initiative/mereka-lms/credentials:21.1.0
            command:
            - python
            - manage.py
            - backfill_credentials
            - --tenant-uuid
            - "ENTERPRISE_UUID"
            - --rate-limit
            - "2"
          restartPolicy: OnFailure
```

---

## References

- CRED-050: Ops & Reliability (backfill command spec)
- CRED-030: Issuance Flow (credential creation logic)
- CRED-010: Credential Types (course vs program credentials)
