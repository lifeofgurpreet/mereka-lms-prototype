# ExternalSecrets Alerting Runbook
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

## Alerts

### ExternalSecretSyncFailure (severity: warning)

**Condition**: An ExternalSecret in `mereka-lms` namespace has not been Ready for >10 minutes.

**Impact**: The K8s Secret is not being updated. Pods using stale secret values will continue to work, but any secret rotation in Infisical/GCP SM will not propagate.

**Diagnosis**:
```bash
# Check ExternalSecret status
kubectl get externalsecret -n mereka-lms
kubectl describe externalsecret <name> -n mereka-lms

# Check ESO operator logs
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=50

# Verify ClusterSecretStore health
kubectl get clustersecretstore gcp-secret-manager -o yaml
```

**Resolution**:
1. Check if the GCP Secret Manager secret exists: `gcloud secrets list --filter="name:MEREKA_LMS_" --project=bbi-k8`
2. Verify workload identity binding: `kubectl get sa -n external-secrets -o yaml`
3. If a specific remote ref is missing, add it in GCP SM first, then ESO will reconcile on next refresh
4. Force reconciliation: `kubectl annotate externalsecret <name> -n mereka-lms force-sync=$(date +%s)`

### ExternalSecretStaleSync (severity: info)

**Condition**: An ExternalSecret's last successful sync is older than 2x the refresh interval (>2h with default 1h interval).

**Impact**: Low immediate impact. Indicates the ESO controller is backlogged or intermittently failing. Secrets will eventually sync when the controller catches up.

**Diagnosis**:
```bash
# Check ESO controller pod health
kubectl get pods -n external-secrets
kubectl top pods -n external-secrets

# Check for resource pressure
kubectl describe pod -n external-secrets -l app.kubernetes.io/name=external-secrets
```

**Resolution**:
1. If ESO pods are OOMKilled, increase memory limits
2. If pods are healthy but not reconciling, restart the controller: `kubectl rollout restart deployment -n external-secrets external-secrets`
3. Monitor for recovery over the next refresh cycle (1h)

## ExternalSecrets in mereka-lms

| Name | Target Secret | Refresh Interval | Key Count |
|------|--------------|-------------------|-----------|
| `openedx-secrets` | `openedx-secrets` | 1h | ~40 keys |
| `database-secrets` | `database-secrets` | 1h | 7 keys |
| `enterprise-sso-secrets` | `enterprise-sso-secrets` | 1h | 4 keys |

## Verification

```bash
# Offline checks (file structure)
./scripts/qa/verify-eso-alerting.sh

# Online checks (cluster state)
./scripts/qa/verify-eso-alerting.sh --online
```
