# Verifiable Credential Issuance Failure Runbook

**Spec**: `specs/verifiable-credentials-issuance_spec.md` (CRED-030)
**Alerts**: `VCIssuanceLatencyHigh`, `VCIssuanceFailureSpike`
**Severity**: Critical (learners unable to receive credentials)

---

## Overview

Diagnose and resolve failures in the Verifiable Credential issuance pipeline, including signing errors, event processing failures, and certificate-to-VC transformation issues.

---

## Quick Diagnostic (5-Minute Triage)

```bash
# 1. Check signing error rate
kubectl exec -it deployment/prometheus -n monitoring -- \
  promtool query instant http://localhost:9090 \
  'rate(credentials_vc_signing_errors_total{namespace="mereka-lms"}[5m])'

# 2. Check Credentials Service health
kubectl exec -it -n mereka-lms deployment/credentials -- \
  curl -s http://localhost:8000/health/ | jq

# Expected: {"status": "ok", "signing_key": "available", ...}
# If signing_key: "unavailable" → GO TO SECTION: Signing Key Missing

# 3. Check recent logs for errors
kubectl logs -n mereka-lms -l app.kubernetes.io/name=credentials --tail=100 | grep -i error

# 4. Check Celery worker queue depth
kubectl exec -it deployment/credentials -n mereka-lms -- \
  celery -A credentials inspect active_queues

# 5. Check database connectivity
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py dbshell -c "SELECT 1;"
```

---

## Common Failure Modes

### 1. Signing Key Missing or Invalid

**Symptoms**:
- Health endpoint returns `503` with `"signing_key": "unavailable"`
- Logs show: `SigningKeyNotFound` or `InvalidKeyFormat`

**Diagnosis**:
```bash
# Check if secret exists
kubectl get secret credentials-signing-key -n mereka-lms

# Check secret value (base64-encoded)
kubectl get secret credentials-signing-key -n mereka-lms -o jsonpath='{.data.SIGNING_KEY}' | base64 -d | wc -c

# Expected: 88 bytes for base58-encoded Ed25519 private key (64-byte key + base58 overhead)
```

**Fix**:
```bash
# If secret missing or corrupted, restore from Infisical
infisical secrets get MEREKA_LMS_VC_SIGNING_KEY \
  --domain https://secrets.mereka.io/api \
  --env prod --path / --plain 2>/dev/null

# Update Kubernetes secret
kubectl create secret generic credentials-signing-key \
  --from-literal=SIGNING_KEY="$(infisical secrets get MEREKA_LMS_VC_SIGNING_KEY --plain)" \
  --namespace mereka-lms \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods
kubectl rollout restart deployment/credentials -n mereka-lms
kubectl rollout status deployment/credentials -n mereka-lms --timeout=5m

# Verify health
kubectl exec -it deployment/credentials -n mereka-lms -- \
  curl -s http://localhost:8000/health/ | jq '.signing_key'
# Expected: "available"
```

---

### 2. Certificate Event Not Triggering VC Issuance

**Symptoms**:
- Traditional certificate issued, but no VC created
- `credentials_vc_issued_total` metric not incrementing
- Logs show certificate event but no VC issuance log

**Diagnosis**:
```bash
# Check ENABLE_VERIFIABLE_CREDENTIALS feature flag
kubectl exec -it deployment/lms -n mereka-lms -- \
  python manage.py shell -c "from django.conf import settings; print(settings.FEATURES.get('ENABLE_VERIFIABLE_CREDENTIALS'))"

# Expected: True

# Check if user has opted in to VCs (if opt-in required per CRED-030)
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py shell -c "
from credentials.apps.verifiable_credentials.models import UserCredentialPreference
pref = UserCredentialPreference.objects.filter(user__username='LEARNER_USERNAME').first()
print(f'Opted in: {pref.enable_verifiable_credentials if pref else \"No preference set\"}')
"
```

**Fix**:
```bash
# If feature flag disabled, enable it
kubectl set env deployment/lms -n mereka-lms ENABLE_VERIFIABLE_CREDENTIALS=true
kubectl rollout restart deployment/lms -n mereka-lms

# If user opt-in missing, enable for user
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py enable_vc_for_user --username "LEARNER_USERNAME"

# Manually trigger VC issuance for existing certificate (backfill single credential)
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py issue_vc_for_certificate \
  --certificate-uuid "CERT_UUID"
```

---

### 3. Database Contention / Slow Queries

**Symptoms**:
- `VCIssuanceLatencyHigh` alert firing
- Issuance duration p95 > 30 seconds
- Logs show database query timeouts

**Diagnosis**:
```bash
# Check active database connections
kubectl exec -it deployment/mysql -n mereka-lms -- \
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW PROCESSLIST;"

# Check slow query log (if enabled)
kubectl logs -n mereka-lms deployment/mysql --tail=100 | grep "Query_time"

# Check credentials table size
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py dbshell -c "
SELECT
  table_name,
  ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
FROM information_schema.TABLES
WHERE table_schema = 'credentials'
  AND table_name LIKE '%verifiable_credential%'
ORDER BY (data_length + index_length) DESC;
"
```

**Fix**:
```bash
# Add database indexes (if missing)
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py migrate --database=default

# Optimize tables
kubectl exec -it deployment/mysql -n mereka-lms -- \
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" credentials -e "OPTIMIZE TABLE verifiable_credentials_issuedcredential;"

# Increase database connection pool (if needed)
kubectl set env deployment/credentials -n mereka-lms \
  CREDENTIALS_DB_POOL_SIZE=20

# Scale credentials pods horizontally
kubectl scale deployment/credentials -n mereka-lms --replicas=3
```

---

### 4. Celery Worker Failures

**Symptoms**:
- Certificate issued, but VC issuance delayed
- Celery queue depth increasing
- Logs show task retries or failures

**Diagnosis**:
```bash
# Check Celery worker status
kubectl exec -it deployment/credentials-worker -n mereka-lms -- \
  celery -A credentials inspect stats

# Check queue depth
kubectl exec -it deployment/credentials-worker -n mereka-lms -- \
  celery -A credentials inspect active | jq '.[] | length'

# Check failed tasks
kubectl exec -it deployment/redis -n mereka-lms -- \
  redis-cli llen celery:failed
```

**Fix**:
```bash
# Restart Celery workers
kubectl rollout restart deployment/credentials-worker -n mereka-lms

# Scale workers if queue depth high
kubectl scale deployment/credentials-worker -n mereka-lms --replicas=5

# Purge failed tasks (if safe to retry)
kubectl exec -it deployment/credentials-worker -n mereka-lms -- \
  celery -A credentials purge -f
```

---

### 5. DID Document Generation Failure

**Symptoms**:
- VC issued but verification fails
- `credentials_did_document_requests_total{status!="200"}` increasing
- Logs show DID Document endpoint errors

**Diagnosis**:
```bash
# Check DID Document endpoint
curl -s https://credentials.academyv2.mereka.io/.well-known/did.json | jq

# Expected: Valid DID Document with verificationMethod array

# Check DID Document cache
kubectl exec -it deployment/redis -n mereka-lms -- \
  redis-cli GET "did:web:credentials.academyv2.mereka.io"
```

**Fix**:
```bash
# Regenerate DID Document
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py generate_did_document \
  --issuer-url "https://credentials.academyv2.mereka.io"

# Clear Redis cache
kubectl exec -it deployment/redis -n mereka-lms -- \
  redis-cli DEL "did:web:credentials.academyv2.mereka.io"

# Verify endpoint
curl -I https://credentials.academyv2.mereka.io/.well-known/did.json
# Expected: HTTP 200
```

---

## Verification After Fix

```bash
# 1. Verify health endpoint
kubectl exec -it deployment/credentials -n mereka-lms -- \
  curl -s http://localhost:8000/health/ | jq

# 2. Issue test credential
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py issue_test_credential \
  --learner-uuid "TEST_LEARNER" \
  --course-id "course-v1:MerekaX+TEST101+2026"

# 3. Check metrics recovered
kubectl exec -it deployment/prometheus -n monitoring -- \
  promtool query instant http://localhost:9090 \
  'rate(credentials_vc_signing_errors_total{namespace="mereka-lms"}[5m])'
# Expected: 0

# 4. Check Grafana dashboard
# URL: https://grafana.mereka.io/d/credentials-vc
# Panel: "Issuance Overview" should show resumed issuance
```

---

## Escalation

If issue persists after following this runbook:

1. Capture diagnostic bundle:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=credentials --tail=500 > /tmp/credentials-logs.txt
   kubectl describe pod -n mereka-lms -l app.kubernetes.io/name=credentials > /tmp/credentials-pod-describe.txt
   kubectl get events -n mereka-lms --sort-by='.lastTimestamp' > /tmp/credentials-events.txt
   ```

2. Contact platform engineering team with:
   - Alert name and timestamp
   - Diagnostic bundle (logs, pod describe, events)
   - Steps already attempted from this runbook

3. Create incident ticket: `ops-incident-vc-issuance-YYYYMMDD`

---

## Prevention

- **Monitor**: Set up PagerDuty routing for `VCIssuanceFailureSpike` (critical severity)
- **Test**: Run `./scripts/qa/verify-credentials-issuance.sh` before each release
- **Backup**: Ensure signing key backed up in Infisical + GCP Secret Manager
- **Capacity**: Scale Credentials Service and Celery workers based on enrollment growth

---

## References

- CRED-030: Issuance Flow & Event Integration
- CRED-050: Ops & Reliability (this spec)
- Health endpoint: https://credentials.academyv2.mereka.io/health/
- Metrics endpoint: https://credentials.academyv2.mereka.io/metrics
