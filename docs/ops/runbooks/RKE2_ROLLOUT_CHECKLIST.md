# RKE2 BoldBadger Rollout Checklist

> **Cluster**: `rke2-nonprod` (154.26.132.35, single-node RKE2 v1.34.3+rke2r3)
> **Namespace**: `mereka-lms`
> **Rollout name**: BoldBadger — final hardening to treat RKE2-nonprod as a production-ready lane
> **Depends on**: T009 (PDBs/HPAs done), T013 (migration plan approved)
> **Verification script**: `scripts/qa/verify-rke2-rollout-readiness.sh`
> **Last updated**: 2026-02-24

Use this checklist before declaring the RKE2-nonprod lane production-ready. Each section
has a sign-off gate that must be completed before proceeding. The automated script covers
most checks; items marked **[manual]** require human judgment.

---

## How to Use

1. Run the automated check first (offline):
   ```bash
   ./scripts/qa/verify-rke2-rollout-readiness.sh --offline
   ```
2. Fix any FAILs.
3. Run the online check against the live cluster:
   ```bash
   ./scripts/qa/verify-rke2-rollout-readiness.sh --online --context rke2-nonprod
   ```
4. Work through the manual items in each section.
5. Record sign-off at the bottom of this file.

---

## Section 1: Security Hardening

### 1.1 Container Isolation Policies (Kyverno)

- [ ] `deploy/k8s/base/policies/require-non-root.yaml` deployed and in **Audit** mode
- [ ] `deploy/k8s/base/policies/require-seccomp.yaml` deployed and in **Audit** mode
- [ ] `deploy/k8s/base/policies/disallow-privileged.yaml` deployed and in **Audit** mode
- [ ] `deploy/k8s/base/policies/restrict-capabilities.yaml` deployed and in **Audit** mode
- [ ] **[manual]** Review Kyverno policy report for any violations:
  ```bash
  kubectl --context rke2-nonprod get policyreport -n mereka-lms -o yaml | grep -A5 'result: fail'
  ```
- [ ] **[manual]** Decide escalation path: move policies from `Audit` → `Enforce` after all pods pass audit

### 1.2 Pod Security Contexts

- [ ] LMS deployment sets `runAsNonRoot: true` in container securityContext
- [ ] CMS deployment sets `runAsNonRoot: true` in container securityContext
- [ ] Caddy deployment sets `runAsNonRoot: true` in container securityContext
- [ ] **[manual]** Verify no pod runs as UID 0:
  ```bash
  kubectl --context rke2-nonprod get pods -n mereka-lms -o json | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
for pod in data['items']:
    uid = pod.get('spec', {}).get('securityContext', {}).get('runAsUser', 'unset')
    print(pod['metadata']['name'], 'uid:', uid)
"
  ```

### 1.3 Network Policies

- [ ] **[manual]** Confirm ingress-only policy exists for LMS/CMS (or document the exception):
  ```bash
  kubectl --context rke2-nonprod get networkpolicy -n mereka-lms
  ```
  > Note: RKE2-nonprod uses Canal CNI. NetworkPolicies are supported.
  > If no NetworkPolicies exist, document in `docs/policies/operations/SECURITY_EXCEPTIONS.md`.

### 1.4 Secrets Hygiene

- [ ] No hardcoded secrets in any committed file (`scripts/qa/verify-no-hardcoded-secrets.sh`)
- [ ] All secrets sourced from Infisical via ExternalSecrets (no `kubectl create secret` with literal values)
- [ ] `openedx-secrets` has >= 40 keys and contains no PLACEHOLDER values:
  ```bash
  kubectl --context rke2-nonprod get secret openedx-secrets -n mereka-lms \
    -o json | python3 -c "import sys,json; d=json.load(sys.stdin)['data']; \
    [print(k) for k,v in d.items() if v in ('UEXBQ0VIT0xERVI=','')]"
  ```
- [ ] **[manual]** Rotate any secrets that have been in plaintext in git history

### 1.5 Image Supply Chain

- [ ] All production images tagged with immutable SHA (not `latest`):
  ```bash
  ./scripts/qa/verify-no-latest-prod-tags.sh
  ```
- [ ] Images sourced from `ghcr.io/biji-biji-initiative/mereka-lms/` (not Docker Hub)
- [ ] `dev-image-puller` imagePullSecret exists and is attached to default ServiceAccount

**Gate 1 Sign-off**: `[ ]` Security hardening complete — reviewer: _____ date: _____

---

## Section 2: Operational Hardening

### 2.1 PodDisruptionBudgets

- [ ] PDB exists for `lms` (minAvailable: 1)
- [ ] PDB exists for `cms` (minAvailable: 1)
- [ ] PDB exists for `caddy` (minAvailable: 1)
- [ ] PDB exists for `redis` (minAvailable: 1)
- [ ] PDB exists for `mysql` (minAvailable: 1)
- [ ] Verify in cluster:
  ```bash
  kubectl --context rke2-nonprod get pdb -n mereka-lms
  ```

### 2.2 HorizontalPodAutoscalers

- [ ] HPA exists for `lms` (min: 1, max: 3, CPU: 70%)
- [ ] HPA exists for `cms` (min: 1, max: 2, CPU: 70%)
- [ ] HPA exists for `lms-worker` (min: 1, max: 3, CPU: 80%)
- [ ] HPA exists for `cms-worker` (min: 1, max: 2, CPU: 80%)
- [ ] Verify in cluster:
  ```bash
  kubectl --context rke2-nonprod get hpa -n mereka-lms
  ```

### 2.3 Resource Requests and Limits

- [ ] LMS deployment has both `requests` and `limits` for CPU and memory
- [ ] CMS deployment has both `requests` and `limits` for CPU and memory
- [ ] **[manual]** Verify no pod is OOMKilled:
  ```bash
  kubectl --context rke2-nonprod get pods -n mereka-lms -o json | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
for pod in data['items']:
    for cs in pod.get('status', {}).get('containerStatuses', []):
        if cs.get('lastState', {}).get('terminated', {}).get('reason') == 'OOMKilled':
            print('OOMKilled:', pod['metadata']['name'], cs['name'])
"
  ```

### 2.4 Rollout Strategy

- [ ] `single-node-recreate-strategy.yaml` patch applied in rke2-nonprod overlay
  (single-node cluster cannot do RollingUpdate with minAvailable=1)
- [ ] Verify patch in overlay:
  ```bash
  grep -r 'Recreate\|strategy' deploy/k8s/overlays/rke2-nonprod/
  ```

### 2.5 Purchase Gateway (Oscar Replacement)

- [ ] Oscar ecommerce service scaled to 0 replicas in rke2-nonprod overlay
- [ ] Purchase Gateway deployment manifest exists in `deploy/k8s/base/`
- [ ] Purchase Gateway health check passes:
  ```bash
  kubectl --context rke2-nonprod exec -n mereka-lms deploy/purchase-gateway -- \
    curl -s http://localhost:8000/health | python3 -c "import sys,json; d=json.load(sys.stdin); print(d)"
  ```
- [ ] `ENABLE_GATEWAY_FULFILLMENT` env var confirmed in deployment (default: `false` for dark launch)
- [ ] **[manual]** Verify Oscar deprecation inventory complete: `docs/reference/operations/ECOMMERCE_DEPRECATION_INVENTORY.md`

### 2.6 Forum v2 (In-Process)

- [ ] Confirm no separate Ruby forum container in `deploy/k8s/base/`:
  ```bash
  grep -r 'forum\|ruby' deploy/k8s/base/ --include="*.yaml" | grep -v prometheus | grep -v '#'
  ```
- [ ] Forum health check passes via LMS pod:
  ```bash
  kubectl --context rke2-nonprod exec -n mereka-lms deploy/lms -- \
    curl -s http://localhost:8000/api/discussion/v2/courses/ | head -c 200
  ```

**Gate 2 Sign-off**: `[ ]` Operational hardening complete — reviewer: _____ date: _____

---

## Section 3: Monitoring and Alerting Readiness

### 3.1 ServiceMonitors

- [ ] `servicemonitor-lms.yaml` applied in cluster
- [ ] `servicemonitor-cms.yaml` applied in cluster
- [ ] `servicemonitor-mysql.yaml` applied in cluster
- [ ] `servicemonitor-redis.yaml` applied in cluster
- [ ] **[manual]** Confirm Prometheus is scraping LMS metrics endpoint:
  ```bash
  # Port-forward to Prometheus
  kubectl --context rke2-nonprod port-forward -n monitoring svc/prometheus-operated 9090:9090 &
  # Then visit http://localhost:9090/targets and verify mereka-lms targets are UP
  ```

### 3.2 PrometheusRules and Alerting

- [ ] `prometheusrule-lms.yaml` applied (LMS error rate, availability)
- [ ] `prometheusrule-slo.yaml` applied (SLO recording rules)
- [ ] `prometheusrule-velero.yaml` applied (backup failure alerts)
- [ ] **[manual]** Verify no rules are in error state:
  ```bash
  kubectl --context rke2-nonprod port-forward -n monitoring svc/prometheus-operated 9090:9090 &
  # Visit http://localhost:9090/rules and check for errors
  ```
- [ ] **[manual]** Fire a synthetic alert to confirm AlertManager routing:
  ```bash
  ./scripts/qa/synthetic-alert-drill.sh
  ```

### 3.3 Alert Routing

- [ ] AlertManager config includes a receiver for critical alerts
- [ ] **[manual]** Review `docs/reference/operations/ALERT_SEVERITY_MATRIX.md` — all severity levels mapped to receivers
- [ ] **[manual]** Confirm on-call rotation is current: `docs/policies/operations/ONCALL_ROTATION.md`

### 3.4 SLO Dashboards

- [ ] SLO recording rules are generating data (error budget > 0%):
  ```bash
  # In Prometheus UI:
  # Query: slo:lms_availability:ratio_rate5m
  ```
- [ ] Grafana dashboard for LMS SLOs is accessible
- [ ] **[manual]** Error budget burn rate does not exceed 5x for the past 1 hour

**Gate 3 Sign-off**: `[ ]` Monitoring and alerting ready — reviewer: _____ date: _____

---

## Section 4: Backup and Disaster Recovery

### 4.1 Velero Backup Schedules

- [ ] Velero schedule exists for `mereka-lms` PVCs:
  ```bash
  kubectl --context rke2-nonprod get schedule -n velero
  ```
- [ ] Last backup succeeded (check within 25 hours):
  ```bash
  kubectl --context rke2-nonprod get backup -n velero --sort-by=.metadata.creationTimestamp | tail -5
  ```
- [ ] Backup age < 24 hours:
  ```bash
  kubectl --context rke2-nonprod get backup -n velero -o json | \
    python3 -c "
import sys, json
from datetime import datetime, timezone
data = json.load(sys.stdin)
for b in sorted(data.get('items', []), key=lambda x: x['metadata']['creationTimestamp'])[-3:]:
    ts = b['metadata']['creationTimestamp']
    age = (datetime.now(timezone.utc) - datetime.fromisoformat(ts.replace('Z','+00:00'))).total_seconds() / 3600
    print(b['metadata']['name'], f'{age:.1f}h ago', b['status'].get('phase',''))
"
  ```

### 4.2 Backup Coverage

- [ ] MySQL PVC is included in backup scope
- [ ] Redis PVC is included in backup scope (or deemed ephemeral — document decision)
- [ ] **[manual]** Verify backup coverage matrix is current: `docs/reference/operations/BACKUP_COVERAGE_MATRIX.md`

### 4.3 Restore Drill

- [ ] **[manual]** Restore drill has been run within the last 30 days
  - Evidence: `docs/status/readiness/DR_TEST_RESULTS.md`
  - Run drill: `./scripts/qa/verify-restore-drill.sh`
- [ ] **[manual]** RTO (Recovery Time Objective) measured and within SLA:
  - Target: < 2 hours for full LMS restore
  - Actual (from last drill): _____ minutes
- [ ] MongoDB Atlas point-in-time recovery tested:
  - Atlas Console → Backup → Test Restore (select staging DB, not production)

### 4.4 Atlas Backup

- [ ] MongoDB Atlas automated backups are enabled for `cluster-mereka-lms`
- [ ] Verify in Atlas Console: Backup → Continuous Cloud Backup → Active
- [ ] **[manual]** Confirm Atlas backup retention meets data policy (>= 7 days)

**Gate 4 Sign-off**: `[ ]` Backup and DR verified — reviewer: _____ date: _____

---

## Section 5: Log Aggregation

### 5.1 Loki Pipeline

- [ ] Promtail DaemonSet is running on all cluster nodes:
  ```bash
  kubectl --context rke2-nonprod get daemonset -n monitoring promtail
  ```
- [ ] LMS logs are appearing in Loki:
  ```bash
  # Via logcli or Grafana Explore:
  # {namespace="mereka-lms", app="lms"} | json
  ```
- [ ] No log gaps > 5 minutes in the last 24 hours

### 5.2 Structured Logging

- [ ] LMS/CMS log output is JSON-formatted (verify with `kubectl logs`)
- [ ] PII fields are not present in logs (`scripts/qa/verify-observability-pii-filtering.sh`)

### 5.3 Log Retention

- [ ] Loki retention policy is set (default: 30 days):
  ```bash
  kubectl --context rke2-nonprod get configmap -n monitoring loki-config -o yaml | grep retention
  ```
- [ ] **[manual]** Retention aligns with data retention policy: `docs/policies/operations/ANALYTICS_DATA_RETENTION.md`

**Gate 5 Sign-off**: `[ ]` Log aggregation confirmed — reviewer: _____ date: _____

---

## Section 6: Runbook Completeness

### 6.1 Required Runbooks

- [ ] `docs/ops/runbooks/TROUBLESHOOTING.md` — current and covers RKE2-specific issues
- [ ] `docs/ops/runbooks/RKE2_DEV_READINESS.md` — covers bootstrap procedure
- [ ] `docs/status/migrations/RKE2_ROLLOUT_MATRIX.md` — gate-by-gate rollout steps
- [ ] `docs/policies/operations/MAINTENANCE_WINDOWS.md` — scheduled maintenance process
- [ ] `docs/ops/runbooks/INCIDENT_TEMPLATES.md` — incident response templates
- [ ] `docs/policies/operations/ONCALL_ROTATION.md` — current on-call contacts
- [ ] `docs/reference/operations/BACKUP_COVERAGE_MATRIX.md` — what is backed up and where

### 6.2 Runbook Quality

- [ ] **[manual]** Walk through `TROUBLESHOOTING.md` site-down scenario (5-command diagnostic)
- [ ] **[manual]** Verify all commands in runbooks are tested against `rke2-nonprod` context
- [ ] **[manual]** Confirm contact information in `ONCALL_ROTATION.md` is up to date

### 6.3 Ecommerce Deprecation Docs

- [ ] `docs/reference/operations/ECOMMERCE_DEPRECATION_INVENTORY.md` — Oscar removal status documented
- [ ] `docs/ops/runbooks/LEGACY_ECOMMERCE_REMOVAL_CHECKLIST.md` — removal steps tracked

**Gate 6 Sign-off**: `[ ]` Runbooks complete and current — reviewer: _____ date: _____

---

## Section 7: Final Verification Run

Run the full verification suite before final sign-off:

```bash
# 1. Offline manifest checks
./scripts/qa/verify-rke2-rollout-readiness.sh --offline

# 2. Operational hardening (PDBs/HPAs)
./scripts/qa/verify-operational-hardening.sh --offline

# 3. Container security
./scripts/qa/verify-container-hardening.sh

# 4. Pod security policies
./scripts/qa/verify-pod-security-policies.sh

# 5. Secrets hygiene
./scripts/qa/verify-no-hardcoded-secrets.sh
./scripts/qa/verify-k8s-secrets-hygiene.sh

# 6. Observability
./scripts/qa/verify-observability-contracts.sh

# 7. Velero
./scripts/qa/audit-velero.sh

# 8. Online (requires cluster access)
./scripts/qa/verify-rke2-rollout-readiness.sh --online --context rke2-nonprod
./scripts/qa/verify-operational-hardening.sh --online
```

All scripts must exit 0 before the rollout is cleared.

---

## Final Sign-Off Gates

| Gate | Description | Status | Reviewer | Date |
|------|-------------|--------|----------|------|
| 1 | Security hardening | `[ ]` | | |
| 2 | Operational hardening | `[ ]` | | |
| 3 | Monitoring and alerting | `[ ]` | | |
| 4 | Backup and DR | `[ ]` | | |
| 5 | Log aggregation | `[ ]` | | |
| 6 | Runbook completeness | `[ ]` | | |
| 7 | Final verification run | `[ ]` | | |

**BoldBadger rollout approved**: `[ ]`

Platform lead sign-off: _______________  Date: _______________

Security reviewer sign-off: _____________  Date: _______________

---

## Related Documents

- `docs/ops/runbooks/RKE2_DEV_READINESS.md` — bootstrap procedure
- `docs/status/migrations/RKE2_ROLLOUT_MATRIX.md` — gate-by-gate steps with rollback signals
- `reports/2026/closures/RKE2_LMS_HANDOFF.md` — cross-repo touchpoint (infrastructure)
- `docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md` — environment deltas
- `scripts/qa/verify-rke2-rollout-readiness.sh` — automated verification (this checklist)
- `scripts/qa/verify-rke2-deployment-readiness.sh` — deployment blocker detection
- `scripts/qa/verify-rke2-dev-readiness.sh` — dev cluster bootstrap checks
