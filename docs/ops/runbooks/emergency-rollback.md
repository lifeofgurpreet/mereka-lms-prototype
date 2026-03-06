# Emergency Rollback Runbook
_Audience: Platform Eng + SRE + DevOps • Owner: Engineering Lead • Last updated: 2026-02-12_

This runbook provides procedures for emergency rollback of failed deployments on Mereka Academy (academyv2.mereka.io). It covers when to rollback, decision criteria, procedures for GitOps and database rollbacks, and post-rollback verification.

> **Spec**: `specs/disaster-recovery-business-continuity_spec.md`
> **Related**: `docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md`, `docs/ops/runbooks/DISASTER_RECOVERY.md`

---

## Table of Contents

1. [When to Rollback](#when-to-rollback)
2. [Rollback Decision Tree](#rollback-decision-tree)
3. [GitOps Rollback (Kubernetes)](#gitops-rollback-kubernetes)
4. [Database Migration Rollback](#database-migration-rollback)
5. [Data Consistency Verification](#data-consistency-verification)
6. [Communication Templates](#communication-templates)
7. [Post-Rollback Analysis](#post-rollback-analysis)

---

## When to Rollback

### Immediate Rollback Triggers (No Discussion Required)

Execute immediate rollback if ANY of the following occur within 30 minutes of deployment:

- **LMS or Studio returns 5xx errors** to >10% of requests (check Prometheus `http_requests_total{status=~"5.."}`).
- **Database corruption detected**: Enrollment counts drop by >5%, user authentication fails for >5% of login attempts.
- **Critical path broken**: User registration, course enrollment, or video playback fails consistently.
- **Security incident**: Credentials leaked, unauthorized access detected, XSS/SQL injection confirmed.
- **Data loss detected**: Missing courses, user data, or grades (verify with data integrity checks).
- **Cascading failures**: Multiple services failing simultaneously (LMS + CMS + MFE).

**Approval**: Platform engineering lead or on-call SRE can authorize immediate rollback without escalation.

---

### Discussion Required (Not Immediate)

The following issues require investigation before rollback decision:

- **Performance degradation** (<10% slowdown): May be resolvable with scaling or cache warmup.
- **Isolated feature failure**: Single MFE or non-critical plugin broken (can be feature-flagged off).
- **Cosmetic issues**: Branding or theming issues (fix-forward with hotfix preferred).
- **Warning-level errors**: Non-critical logs or metrics anomalies without user impact.
- **Known degradation**: Issues documented in deployment notes as expected/temporary.

**Process**: Convene a 15-minute sync with engineering lead, SRE, and QA. Assess:
- Impact radius (% users affected)
- Workaround availability
- Fix-forward vs rollback timeline
- Risk of further damage

**Decision threshold**: If issue is not resolved or worsening after 30 minutes, proceed with rollback.

---

## Rollback Decision Tree

```
┌─────────────────────────────────────────────┐
│  Deployment Completed                       │
│  (within last 4 hours)                      │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ Is LMS/Studio/MFE    │ YES ──┐
        │ returning 5xx errors?│       │
        └──────────┬───────────┘       │
                   │ NO                 │
                   ▼                    │
        ┌──────────────────────┐       │
        │ Data loss or         │ YES ──┤
        │ corruption detected? │       │
        └──────────┬───────────┘       │
                   │ NO                 │
                   ▼                    │
        ┌──────────────────────┐       │
        │ Security incident    │ YES ──┤
        │ confirmed?           │       │
        └──────────┬───────────┘       │
                   │ NO                 │
                   ▼                    │
        ┌──────────────────────┐       │
        │ >10% of users        │ YES ──┤
        │ affected by failure? │       │
        └──────────┬───────────┘       │
                   │ NO                 ▼
                   │           ┌────────────────────┐
                   │           │ IMMEDIATE ROLLBACK │
                   │           │ Skip to Section 3  │
                   │           └────────────────────┘
                   ▼
        ┌──────────────────────┐
        │ Convene 15-min sync  │
        │ - Eng Lead           │
        │ - SRE                │
        │ - QA                 │
        └──────────┬───────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ Can we fix forward   │ YES ──┐
        │ in <30 minutes?      │       │
        └──────────┬───────────┘       │
                   │ NO                 │
                   ▼                    ▼
        ┌──────────────────────┐   ┌────────────────┐
        │ ROLLBACK             │   │ FIX FORWARD    │
        │ Skip to Section 3    │   │ Monitor closely│
        └──────────────────────┘   └────────────────┘
```

**Key timing considerations**:
- **<30 minutes post-deploy**: Rollback is fast and safe (no data migration concerns).
- **30 min - 4 hours**: Rollback is still safe; check for in-flight transactions.
- **>4 hours**: Assess data created under new deployment; may need data migration plan.
- **>24 hours**: Rollback discouraged; fix-forward preferred to avoid data consistency issues.

---

## GitOps Rollback (Kubernetes)

### Overview

Mereka Academy uses **GitOps** with Kustomize overlays and ArgoCD-style deployment. Images are tagged by git SHA and deployed via `deploy/k8s/overlays/production/kustomization.yaml`. Rollback means reverting to a previous image tag.

### Prerequisites

- `kubectl` access to `mereka-lms` namespace in production GKE cluster
- Git access to `Biji-Biji-Initiative/mereka-lms` repository
- Access to Artifact Registry (`ghcr.io/biji-biji-initiative/mereka-lms`)

### Procedure: Rollback to Previous Image Tag

**Time to complete**: 5-10 minutes

1. **Identify the current deployment**:
   ```bash
   kubectl get deployment lms -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```

   Example output:
   ```
   ghcr.io/biji-biji-initiative/mereka-lms/openedx:20260210-v21-mfe-only-b988d63
   ```

2. **Find the previous stable image**:
   ```bash
   # Check git history for kustomization.yaml changes
   cd deploy/k8s/overlays/production
   git log --oneline -20 kustomization.yaml

   # Or check Artifact Registry for recent tags
   gcloud artifacts docker images list \
     ghcr.io/biji-biji-initiative/mereka-lms/openedx \
     --include-tags --limit=10 --sort-by=~UPDATE_TIME
   ```

   Identify the previous tag (e.g., `20260208-mfe-discussions-pass4-c17df16`).

3. **Create pre-rollback backup** (CRITICAL):
   ```bash
   velero backup create pre-rollback-$(date +%Y%m%d-%H%M) \
     --include-namespaces mereka-lms --wait
   ```

   Verify backup completed:
   ```bash
   velero backup describe pre-rollback-$(date +%Y%m%d-%H%M) | grep "Phase:"
   # Must show: Phase: Completed
   ```

4. **Update kustomization.yaml with previous image tag**:
   ```bash
   cd deploy/k8s/overlays/production

   # Edit kustomization.yaml
   vim kustomization.yaml
   ```

   Change:
   ```yaml
   images:
     - name: docker.io/overhangio/openedx
       newName: ghcr.io/biji-biji-initiative/mereka-lms/openedx
       newTag: 20260208-mfe-discussions-pass4-c17df16  # <- Previous stable tag
   ```

5. **Apply the rollback**:
   ```bash
   kubectl apply -k deploy/k8s/overlays/production
   ```

6. **Monitor the rollout**:
   ```bash
   # Watch pods restart with previous image
   kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms -w

   # Check rollout status
   kubectl rollout status deployment/lms -n mereka-lms --timeout=300s
   kubectl rollout status deployment/cms -n mereka-lms --timeout=300s
   kubectl rollout status deployment/lms-worker -n mereka-lms --timeout=300s
   ```

7. **Verify endpoints respond**:
   ```bash
   curl -I https://academyv2.mereka.io
   curl -I https://studio.academyv2.mereka.io
   curl -I https://apps.academyv2.mereka.io/authn/login
   ```

   All should return `200` or `302` (not 5xx).

8. **Commit the rollback**:
   ```bash
   git add kustomization.yaml
   git commit -m "rollback: revert to stable image 20260208-mfe-discussions-pass4-c17df16

   Rollback from failed deployment b988d63 due to [REASON].

   Verified via pre-rollback backup and endpoint health checks.

   Co-Authored-By: Claude <noreply@anthropic.com>"
   git push origin main
   ```

---

### Alternative: Kubectl Rollout Undo (Quick Emergency Only)

If you need immediate rollback and cannot edit kustomization.yaml:

```bash
# Rollback LMS to previous revision
kubectl rollout undo deployment/lms -n mereka-lms

# Rollback CMS
kubectl rollout undo deployment/cms -n mereka-lms

# Rollback workers
kubectl rollout undo deployment/lms-worker -n mereka-lms
kubectl rollout undo deployment/cms-worker -n mereka-lms
```

**CRITICAL**: This is a **temporary fix only**. You MUST follow up with a Git commit to `kustomization.yaml` or the next ArgoCD sync will re-deploy the broken image.

---

### Rollback MFE (Micro-Frontends)

MFEs are deployed separately. If the issue is MFE-specific:

```bash
# Check current MFE image
kubectl get deployment mfe -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].image}'

# Update kustomization.yaml with previous MFE tag
cd deploy/k8s/overlays/production
vim kustomization.yaml

# Change:
images:
  - name: docker.io/overhangio/openedx-mfe
    newName: ghcr.io/biji-biji-initiative/mereka-lms/mfe
    newTag: <previous-mfe-tag>

# Apply
kubectl apply -k deploy/k8s/overlays/production
kubectl rollout status deployment/mfe -n mereka-lms --timeout=300s
```

---

## Database Migration Rollback

### Overview

Open edX uses Django migrations for MySQL schema changes. Rollback must be coordinated with code rollback to prevent schema mismatches.

### Risk Assessment

**Low risk** (safe to rollback):
- Additive changes only (new tables, columns with defaults)
- Data migrations that are idempotent (can run multiple times)
- No foreign key constraint changes

**Medium risk** (requires data migration):
- Column renames or type changes
- Data transformations (e.g., splitting or merging fields)
- New NOT NULL columns without defaults

**High risk** (may require manual intervention):
- Dropping columns or tables
- Foreign key constraint changes
- Data loss scenarios (e.g., deleted records)

---

### Procedure: Rollback with Django Migrations

**Time to complete**: 15-30 minutes

1. **Identify the migration state**:
   ```bash
   # Connect to LMS pod
   kubectl exec -n mereka-lms deploy/lms -it -- bash

   # Check latest applied migrations
   python manage.py lms showmigrations | tail -50
   ```

   Note the last migration before deployment (e.g., `0042_add_user_profile_field`).

2. **Determine the rollback target**:
   ```bash
   # From your local repo, check migrations in the previous release
   git show <previous-sha>:lms/djangoapps/*/migrations/
   ```

   Identify the migration to revert to (e.g., `0041_remove_legacy_field`).

3. **Run the migration rollback**:
   ```bash
   # Inside LMS pod
   python manage.py lms migrate <app_name> <migration_number>

   # Example:
   python manage.py lms migrate student 0041
   ```

   For CMS:
   ```bash
   kubectl exec -n mereka-lms deploy/cms -it -- bash
   python manage.py cms migrate <app_name> <migration_number>
   ```

4. **Verify database state**:
   ```bash
   # Inside LMS pod
   python manage.py lms showmigrations | grep "0041\|0042"
   # Should show 0041 with [X] and 0042 with [ ] (not applied)
   ```

5. **Test critical paths**:
   ```bash
   # From outside the cluster
   curl -s https://academyv2.mereka.io/api/user/v1/me \
     -H "Authorization: Bearer <test-token>"
   ```

---

### Procedure: Rollback Without Migration (Data Restore)

If migrations are irreversible or too risky, restore database from backup:

1. **Stop application pods** (prevent writes during restore):
   ```bash
   kubectl scale deployment/lms -n mereka-lms --replicas=0
   kubectl scale deployment/cms -n mereka-lms --replicas=0
   kubectl scale deployment/lms-worker -n mereka-lms --replicas=0
   kubectl scale deployment/cms-worker -n mereka-lms --replicas=0
   ```

2. **Restore MySQL PVC from Velero**:
   ```bash
   # Find latest backup before deployment
   velero backup get --selector velero.io/schedule-name=velero-local-hourly-critical-databases \
     -o json | jq -r '[.items[] | select(.status.phase=="Completed")] | sort_by(.status.completionTimestamp) | .[-2] | .metadata.name'

   BACKUP_NAME="<backup-name-from-above>"

   # Delete existing MySQL PVC
   kubectl delete pvc mysql -n mereka-lms

   # Restore from backup
   velero restore create mysql-rollback-$(date +%s) \
     --from-backup "$BACKUP_NAME" \
     --include-resources persistentvolumeclaims,persistentvolumes \
     --include-namespaces mereka-lms \
     --selector "app=mysql"

   # Wait for restore
   velero restore describe mysql-rollback-<id>
   ```

3. **Verify PVC is bound**:
   ```bash
   kubectl get pvc mysql -n mereka-lms
   # Status must be: Bound
   ```

4. **Scale application pods back up**:
   ```bash
   kubectl scale deployment/lms -n mereka-lms --replicas=2
   kubectl scale deployment/cms -n mereka-lms --replicas=1
   kubectl scale deployment/lms-worker -n mereka-lms --replicas=2
   kubectl scale deployment/cms-worker -n mereka-lms --replicas=1
   ```

5. **Verify database connectivity**:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- \
     python -c "from django.db import connection; connection.cursor().execute('SELECT 1'); print('OK')"
   ```

---

### MongoDB Atlas Rollback

If the issue involves MongoDB (modulestore or forum) corruption:

1. **Check Atlas backup schedule**:
   ```bash
   atlas backups snapshots list cluster-mereka-lms --projectId <PROJECT_ID>
   ```

2. **Restore from snapshot** (requires Atlas UI or API):
   - Log in to MongoDB Atlas
   - Navigate to `cluster-mereka-lms` → Backups
   - Select snapshot from before deployment
   - Restore to a new temporary cluster (test first)
   - Verify data integrity
   - Point `MONGODB_HOST` to restored cluster
   - Update `openedx-secrets` in K8s

3. **Alternatively: Restore from Velero backup** (if forum was in-cluster previously):
   ```bash
   # Follow same process as MySQL PVC restore
   velero restore create mongodb-rollback-$(date +%s) \
     --from-backup "$BACKUP_NAME" \
     --include-namespaces mereka-lms \
     --selector "app=mongodb"
   ```

**Note**: Current production uses **MongoDB Atlas**, so legacy in-cluster restore is not applicable unless reverting to pre-Atlas state.

---

## Data Consistency Verification

After any rollback, verify data integrity before declaring success.

### Procedure

1. **MySQL user count** (should match pre-deployment baseline ±5%):
   ```bash
   kubectl exec -n mereka-lms deploy/mysql -- \
     mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -Nse "SELECT COUNT(*) FROM openedx.auth_user"
   ```

   Compare to pre-deployment count (check monitoring dashboards or logs).

2. **MongoDB course count** (must be non-zero):
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- \
     python -c "from xmodule.modulestore.django import modulestore; print(sum(1 for _ in modulestore().get_courses()))"
   ```

   Expected: >0 courses (typically 5-50 for Mereka Academy).

3. **Enrollment integrity check**:
   ```bash
   kubectl exec -n mereka-lms deploy/mysql -- \
     mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -Nse \
       "SELECT COUNT(*) FROM openedx.student_courseenrollment WHERE is_active=1"
   ```

   Compare to pre-deployment count.

4. **Grade records check**:
   ```bash
   kubectl exec -n mereka-lms deploy/mysql -- \
     mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -Nse \
       "SELECT COUNT(*) FROM openedx.grades_persistentcoursegrade"
   ```

5. **Spot-check user login**:
   ```bash
   # Test with a known user account
   curl -X POST https://academyv2.mereka.io/user_api/v1/account/login_session/ \
     -d "email=test@example.com&password=testpass" \
     -c cookies.txt

   # Verify session cookie received
   cat cookies.txt | grep sessionid
   ```

6. **Full health check**:
   ```bash
   ./scripts/qa/public-health-check.sh prod
   ```

   All endpoints must return success.

7. **Microsite verification** (if applicable):
   ```bash
   curl -I https://academy.biji-biji.com
   curl -I https://skillourfuture.academy.mereka.io
   ```

---

### Data Loss Threshold

**Acceptable**:
- Up to 1 hour of data loss (Tier 1 RPO for MySQL)
- Cache/session data loss (Redis ephemeral)
- Search index rebuild (Elasticsearch)

**Unacceptable** (escalate to engineering leadership):
- User registrations lost (>5 users)
- Enrollment data missing (>10 enrollments)
- Grade records lost (any)
- Course content missing (any course)

If data loss exceeds acceptable threshold, **do not proceed**. Escalate to disaster recovery team and consult `docs/ops/runbooks/DISASTER_RECOVERY.md`.

---

## Communication Templates

### Template: Rollback Initiated (Internal)

**Audience**: Engineering team, SRE, QA
**Channel**: Slack #eng-alerts, #platform-ops

```
🚨 ROLLBACK IN PROGRESS

**Deployment**: [Deployment ID or git SHA]
**Reason**: [Brief description of failure - e.g., "LMS returning 500 errors"]
**Initiated by**: [Your name]
**Initiated at**: [Timestamp UTC]
**Current status**: Rolling back to previous image [previous SHA or tag]
**Estimated completion**: [Time - typically 5-10 minutes]

**Actions in progress**:
- ✅ Pre-rollback backup created
- 🔄 Reverting kustomization.yaml
- ⏳ Waiting for pods to restart

**Next update**: [Time - e.g., "in 5 minutes or upon completion"]
```

---

### Template: Rollback Complete (Internal)

**Audience**: Engineering team, SRE, QA
**Channel**: Slack #eng-alerts, #platform-ops

```
✅ ROLLBACK COMPLETE

**Deployment**: [Deployment ID or git SHA]
**Rolled back to**: [Previous stable SHA or tag]
**Completed at**: [Timestamp UTC]
**Total downtime**: [Duration - e.g., "8 minutes"]

**Verification results**:
- ✅ LMS responding with 200
- ✅ Studio responding with 200
- ✅ MFE authn responding with 200
- ✅ Data integrity checks passed
- ✅ User count: [count] (within 5% of baseline)
- ✅ Course count: [count] (no courses lost)

**Next steps**:
- Root cause analysis scheduled for [Date/Time]
- Post-mortem document: [Link to Google Doc or Confluence]
- Fix-forward plan TBD

**Git commit**: [Link to rollback commit]
```

---

### Template: Stakeholder Notification (External)

**Audience**: Non-technical stakeholders, management, clients
**Channel**: Email, Slack #general, status page

```
Subject: Mereka Academy - Service Restoration Complete

Dear [Stakeholders],

We experienced a brief service disruption on Mereka Academy (academyv2.mereka.io) today between [start time] and [end time] UTC (approximately [duration] minutes).

**What happened**:
A recent deployment caused [high-level description - e.g., "intermittent errors for users accessing courses"]. Our monitoring systems detected the issue within [X minutes], and we immediately initiated a rollback to the previous stable version.

**Current status**:
✅ Service is fully restored and operating normally.
✅ All user data is intact (no data loss).
✅ We have verified that enrollments, grades, and course content are unaffected.

**Impact**:
- [X]% of users may have experienced [brief description of user-facing impact].
- No long-term impact expected.

**Next steps**:
Our engineering team is conducting a root cause analysis to prevent similar issues in the future. We will share findings and preventive measures in our weekly engineering update.

If you experience any continued issues, please contact techadmin@biji-biji.com.

Thank you for your patience.

Best regards,
Mereka Academy Engineering Team
```

---

## Post-Rollback Analysis

### Immediate Actions (Within 1 Hour)

1. **Capture logs from failed deployment**:
   ```bash
   # LMS logs
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --since=2h > /tmp/lms-failed-deploy.log

   # CMS logs
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=cms --since=2h > /tmp/cms-failed-deploy.log

   # Worker logs
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms-worker --since=2h > /tmp/worker-failed-deploy.log
   ```

2. **Export Prometheus metrics**:
   ```bash
   # Query error rate during deployment window
   curl -G 'https://prometheus.mereka.dev/api/v1/query' \
     --data-urlencode 'query=sum(rate(http_requests_total{status=~"5..",namespace="mereka-lms"}[5m]))' \
     > /tmp/prometheus-error-rate.json
   ```

3. **Create incident ticket**:
   - Title: `[INCIDENT] Rollback required for deployment [SHA]`
   - Severity: P1 (Critical) or P2 (High)
   - Labels: `incident`, `rollback`, `production`
   - Attach logs and metrics

4. **Tag the failed image** (prevent accidental re-deploy):
   ```bash
   gcloud artifacts docker tags add \
     ghcr.io/biji-biji-initiative/mereka-lms/openedx:<failed-sha> \
     ghcr.io/biji-biji-initiative/mereka-lms/openedx:<failed-sha>-ROLLBACK-REQUIRED
   ```

---

### Post-Mortem Checklist (Within 5 Business Days)

Use this checklist for the post-mortem document:

- [ ] **Incident summary**: What failed, when, and impact radius
- [ ] **Timeline**: Detailed minute-by-minute timeline from deployment to rollback completion
- [ ] **Root cause**: Technical reason for failure (with code references if applicable)
- [ ] **Detection**: How was the issue detected? (Monitoring, user report, manual testing?)
- [ ] **Response**: What went well? What could be faster?
- [ ] **Rollback process**: Did rollback proceed smoothly? Any blockers?
- [ ] **Data impact**: Was any data lost or corrupted? Quantify.
- [ ] **User impact**: How many users affected? What was their experience?
- [ ] **Preventive measures**: What changes prevent recurrence?
  - Code fixes
  - Test coverage additions
  - CI/CD improvements
  - Monitoring improvements
- [ ] **Process improvements**: What runbook or process changes are needed?
- [ ] **Blameless review**: Focus on systems, not individuals

**Template**: Use the post-mortem template at `docs/operations/POST_MORTEM_TEMPLATE.md`.

---

### Long-Term Improvements

After 3+ rollback incidents, consider these architectural improvements:

1. **Blue-Green Deployments**:
   - Deploy new version alongside old version
   - Route small % of traffic to new version (canary)
   - Full cutover only after validation
   - Instant rollback = route traffic back to old version

2. **Feature Flags**:
   - Deploy code with new features disabled
   - Enable features incrementally via configuration
   - Disable features without re-deploy if issues arise

3. **Database Migration Strategy**:
   - Use backward-compatible migrations (expand/contract pattern)
   - Deploy code first, then run migrations
   - Migrations should be no-ops or additive only

4. **Enhanced Smoke Tests**:
   - Run comprehensive smoke tests in staging before production
   - Automate critical user journeys (registration, enrollment, video playback)
   - Block deployment if smoke tests fail

5. **Automated Rollback**:
   - Monitor error rates post-deployment
   - Auto-rollback if error rate exceeds threshold (e.g., >5% 5xx errors for >5 minutes)
   - Requires: Robust monitoring, GitOps automation, confidence in rollback safety

---

## Quick Reference

### Rollback Commands Cheat Sheet

```bash
# Pre-rollback backup (ALWAYS DO THIS FIRST)
velero backup create pre-rollback-$(date +%Y%m%d-%H%M) --include-namespaces mereka-lms --wait

# Quick rollback (kubectl)
kubectl rollout undo deployment/lms -n mereka-lms
kubectl rollout undo deployment/cms -n mereka-lms

# GitOps rollback (preferred)
cd deploy/k8s/overlays/production
vim kustomization.yaml  # Change image tags
kubectl apply -k .
kubectl rollout status deployment/lms -n mereka-lms --timeout=300s

# Check rollout history
kubectl rollout history deployment/lms -n mereka-lms

# Health check
./scripts/qa/public-health-check.sh prod

# Data integrity
kubectl exec -n mereka-lms deploy/mysql -- mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -Nse "SELECT COUNT(*) FROM openedx.auth_user"
```

---

## Escalation Path

| Issue | Contact | Response Time |
|-------|---------|---------------|
| Rollback fails to complete | SRE on-call + Engineering Lead | Immediate |
| Data loss detected | Engineering Lead + CTO | Immediate |
| Database restore required | SRE + DBA (if available) | <30 minutes |
| Multi-hour downtime | Engineering Lead + CTO + CEO | Immediate |
| Legal/compliance impact | CTO + Legal | <2 hours |

**Emergency contacts**: See `docs/operations/ONCALL_ROTATION.md` for on-call details and team contact handoff.

---

## Related Documentation

- **Deployment**: `docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md`
- **Disaster Recovery**: `docs/ops/runbooks/DISASTER_RECOVERY.md`
- **Site Down**: `docs/ops/runbooks/site-down.md`
- **Database Issues**: `docs/ops/runbooks/database-issues.md`
- **DR Spec**: `specs/disaster-recovery-business-continuity_spec.md`
- **K8s Deployment Spec**: `specs/k8s-deployment_spec.md`

---

**Last reviewed**: 2026-02-12
**Next review due**: 2026-05-12 (quarterly)
**Owner**: Engineering Lead
**Reviewers**: SRE Team, Platform Engineering
