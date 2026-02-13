# Cloud SQL Restore Drill SOP

## Overview

Quarterly drill to verify Cloud SQL backup restoration procedures and validate RTO compliance.

**Target RTO**: 4 hours (per disaster-recovery-business-continuity_spec.md)

**Schedule**: Quarterly (every 3 months)

---

## Pre-Drill Checklist

- [ ] Notify team via Slack #ops channel (24h advance notice)
- [ ] Verify latest backup exists
- [ ] Document current instance state (DB version, size, replica count)
- [ ] Prepare test project/namespace for restoration (NOT production)
- [ ] Confirm Cloud SQL Admin IAM permissions
- [ ] Set drill start timestamp

**Commands**:
```bash
# List available backups
gcloud sql backups list \
  --instance=mereka-lms-mysql \
  --project=mereka-lms-prod

# Verify most recent backup
LATEST_BACKUP=$(gcloud sql backups list \
  --instance=mereka-lms-mysql \
  --project=mereka-lms-prod \
  --limit=1 \
  --format="value(id)")

echo "Latest backup ID: $LATEST_BACKUP"
```

---

## Restore Steps

### 1. Create Restore Target Instance

```bash
# Create new Cloud SQL instance from backup
gcloud sql backups restore $LATEST_BACKUP \
  --backup-instance=mereka-lms-mysql \
  --restore-instance=mereka-lms-mysql-drill-$(date +%Y%m%d) \
  --project=mereka-lms-prod

# Wait for restore to complete (5-15 minutes depending on size)
gcloud sql operations wait \
  --project=mereka-lms-prod \
  $(gcloud sql operations list \
    --instance=mereka-lms-mysql-drill-$(date +%Y%m%d) \
    --filter="status:RUNNING" \
    --format="value(name)" \
    --limit=1)
```

### 2. Verify Instance Status

```bash
# Check instance is running
gcloud sql instances describe mereka-lms-mysql-drill-$(date +%Y%m%d) \
  --project=mereka-lms-prod \
  --format="value(state)"

# Expected: RUNNABLE
```

---

## Post-Restore Validation

### 1. MySQL Connectivity Probe

```bash
# Connect to restored instance
gcloud sql connect mereka-lms-mysql-drill-$(date +%Y%m%d) \
  --user=root \
  --project=mereka-lms-prod

# Inside MySQL shell:
SHOW DATABASES;
SELECT COUNT(*) FROM mysql.user;
\q
```

**Expected**: All databases present, user count matches production.

### 2. Data Integrity Checks

```bash
# Sample data verification (adjust table names as needed)
gcloud sql connect mereka-lms-mysql-drill-$(date +%Y%m%d) \
  --user=root \
  --project=mereka-lms-prod \
  --database=openedx

# Inside MySQL shell:
SELECT COUNT(*) FROM auth_user;
SELECT COUNT(*) FROM student_courseenrollment;
SELECT COUNT(*) FROM certificates_generatedcertificate;
\q
```

**Expected**: Record counts match (or are close to) production snapshot at backup time.

### 3. Schema Validation

```bash
# Verify schema integrity
gcloud sql connect mereka-lms-mysql-drill-$(date +%Y%m%d) \
  --user=root \
  --project=mereka-lms-prod \
  --database=openedx

# Inside MySQL shell:
SHOW TABLES LIKE 'auth_%';
DESCRIBE auth_user;
\q
```

**Expected**: All critical tables present, schema matches production.

---

## Evidence Capture

Document the following for audit trail:

1. **Timestamps**:
   - Drill start: `______________________`
   - Restore initiated: `______________________`
   - Restore completed: `______________________`
   - Validation completed: `______________________`
   - Total duration: `______________________`

2. **Backup Details**:
   - Backup ID: `______________________`
   - Backup timestamp: `______________________`
   - Backup size: `______________________`

3. **Checksums** (optional but recommended):
   ```bash
   # Generate checksum for auth_user table
   mysqldump mereka-lms-mysql-drill-$(date +%Y%m%d) openedx auth_user | sha256sum
   ```
   - Checksum: `______________________`

4. **Pass/Fail**:
   - [ ] Restore completed within RTO (4 hours)
   - [ ] MySQL connectivity successful
   - [ ] Data integrity checks passed
   - [ ] Schema validation passed

---

## Cleanup

```bash
# Delete drill instance after validation
gcloud sql instances delete mereka-lms-mysql-drill-$(date +%Y%m%d) \
  --project=mereka-lms-prod

# Confirm deletion
echo "Drill instance deleted"
```

---

## Quarterly Drill Schedule

- **Q1**: March 1-7
- **Q2**: June 1-7
- **Q3**: September 1-7
- **Q4**: December 1-7

**Next drill**: `______________________`

---

## Escalation

If restore fails or RTO is exceeded:

1. Document failure mode (timeout, corruption, permission issue)
2. Create P0 incident in issue tracker
3. Escalate to SRE team
4. Review backup retention policy and RTO targets

**Contacts**:
- SRE Lead: `______________________`
- Cloud SQL Admin: `______________________`
