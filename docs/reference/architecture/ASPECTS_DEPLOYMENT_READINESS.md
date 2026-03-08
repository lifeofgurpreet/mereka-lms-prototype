# Aspects Deployment Readiness Contract

**Status**: READY FOR DEPLOYMENT DECISION
**Last Updated**: 2026-02-17
**Owner**: Platform Engineering
**Related**: [ADR-017: Analytics Target Decision](../../adr/017-analytics-target-decision.md)

---

## Purpose

This document establishes the deployment readiness contract for Open edX Aspects analytics platform. It defines prerequisites, deployment steps, rollback procedures, and cost estimates required before enabling Aspects in production.

**Current Status**: Aspects infrastructure is **DEFERRED** per ADR-017. Plugin is installed locally, K8s manifests exist, but services are **NOT DEPLOYED** in any environment.

**Decision Gate**: This contract becomes active only when ADR-017 status changes from "Deferred" to "Accepted" based on the revisit conditions defined therein.

---

## Prerequisites Checklist

Before enabling Aspects, the following conditions MUST be satisfied:

### 1. Decision Gate Approval

- [ ] **ADR-017 status changed to "Accepted"**: Core platform stable for 3+ consecutive months (no critical incidents)
- [ ] **Course creator demand validated**: At least 3 course creators have explicitly requested learning analytics features
- [ ] **Team capacity confirmed**: Team has allocated bandwidth for ClickHouse/Superset operations (3-5 hours/month)
- [ ] **Analytics spec approved**: `specs/analytics-pipeline_spec.md` status changed from "in_progress" to "approved"
- [ ] **Use cases documented**: At least 3 demonstrated use cases that justify the operational overhead

### 2. Infrastructure Readiness

- [ ] **ClickHouse storage provisioned**:
  - PVC created with at least 100Gi initial capacity
  - Storage class supports dynamic provisioning (GKE standard-rwo)
  - Retention policy configured (default: 90 days hot, 1 year cold archive)
  - Backup policy defined (daily GCS snapshots)

- [ ] **GKE cluster capacity verified**:
  - At least 4 CPU cores available (ClickHouse: 2, Superset: 1, Ralph: 0.5, Worker: 0.5)
  - At least 8GB RAM available (ClickHouse: 4GB, Superset: 2GB, Ralph: 1GB, Worker: 1GB)
  - Node pool can scale to accommodate analytics workload
  - No resource pressure on existing services (LMS, CMS, workers)

- [ ] **Network configuration ready**:
  - DNS record created for Superset dashboard (`analytics.mereka.io` or `aspects-superset.academyv2.mereka.io`)
  - Ingress/Caddy routes configured (if exposing externally)
  - Firewall rules allow internal pod-to-pod communication (ClickHouse, Redis)

### 3. Secrets Management

- [ ] **Superset credentials in GCP Secret Manager**:
  - `MEREKA_LMS_SUPERSET_ADMIN_PASSWORD` (strong password, 20+ characters)
  - `MEREKA_LMS_SUPERSET_SECRET_KEY` (cryptographic key for session signing)

- [ ] **ExternalSecret configured**:
  - `deploy/k8s/base/plugins/aspects/secrets.yml` references GCP SM
  - ClusterSecretStore `gcp-secret-manager` has access to secrets
  - Test secret sync: `kubectl get secret aspects-superset-credentials -n mereka-lms`

### 4. Event Pipeline Configuration

- [ ] **Ralph installed and configured**:
  - Ralph event processor deployment ready
  - Event routing backends configured in LMS/CMS settings
  - xAPI endpoint configured to point to Ralph service
  - Event batch size tuned (default: `ASPECTS_EVENT_BATCH_SIZE=100`)

- [ ] **Event types validated**:
  - Confirm LMS generates tracking events for enrolled, viewed, completed, progressed
  - Test event emission in local environment first
  - Verify event schema matches xAPI 1.0.3 format

### 5. Monitoring and Observability

- [ ] **Prometheus ServiceMonitors created**:
  - ClickHouse metrics exposed (port 8001 or 9363)
  - Superset metrics exposed (if available)
  - Ralph pipeline metrics exposed

- [ ] **PrometheusRules defined**:
  - ClickHouse disk usage alert (warning: 75%, critical: 85%)
  - Event processing lag alert (critical: >10 minutes)
  - Superset query timeout alert (p95 >5 seconds)
  - ClickHouse down alert (no metrics for 5 minutes)

- [ ] **Grafana dashboards prepared**:
  - ClickHouse disk usage and query performance
  - Event pipeline lag and throughput
  - Superset user activity and query patterns

### 6. Documentation and Runbooks

- [ ] **Operational runbooks created**:
  - How to investigate event lag
  - How to optimize ClickHouse queries
  - How to reset Superset admin password
  - How to scale ClickHouse replicas
  - How to export data for GDPR deletion requests

- [ ] **User documentation ready**:
  - Instructor guide: "How to Access Course Analytics"
  - Admin guide: "Superset Dashboard Overview"
  - FAQ: Common analytics questions

---

## Deployment Steps

Execute these steps in order when prerequisites are satisfied:

### Phase 1: Image Build (Local Validation)

**Estimated Time**: 30-45 minutes

1. **Activate Tutor environment**:
   ```bash
   cd /home/gurpreet/projects/k8s/mereka-lms
   source .venv/bin/activate
   export TUTOR_ROOT="$(pwd)/tutor_env"
   ```

2. **Build Aspects images locally** (test build):
   ```bash
   tutor images build aspects aspects-superset
   ```
   **Expected Output**: Two images built successfully without errors

3. **Test local deployment** (optional but recommended):
   ```bash
   tutor local init
   tutor local start -d
   tutor local dc ps | grep aspects
   ```
   **Expected Output**: clickhouse, superset, superset-worker, ralph containers running

4. **Verify local Superset access**:
   ```bash
   curl -I http://aspects-superset.localhost
   ```
   **Expected Output**: HTTP 200 OK

5. **Stop local environment** (cleanup):
   ```bash
   tutor local stop
   ```

### Phase 2: Production Image Build and Push

**Estimated Time**: 45-60 minutes

1. **Build production images** (with optimizations):
   ```bash
   tutor images build aspects aspects-superset --no-cache
   ```

2. **Tag images with git SHA**:
   ```bash
   GIT_SHA=$(git rev-parse --short HEAD)
   docker tag overhangio/openedx-aspects:latest \
     ghcr.io/biji-biji-initiative/mereka-lms/openedx-aspects:$GIT_SHA
   docker tag overhangio/openedx-aspects-superset:latest \
     ghcr.io/biji-biji-initiative/mereka-lms/openedx-aspects-superset:$GIT_SHA
   ```

3. **Push images to Artifact Registry**:
   ```bash
   docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx-aspects:$GIT_SHA
   docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx-aspects-superset:$GIT_SHA
   ```

4. **Update production kustomization**:
   ```yaml
   # deploy/k8s/overlays/production/kustomization.yaml
   images:
     - name: overhangio/openedx-aspects
       newName: ghcr.io/biji-biji-initiative/mereka-lms/openedx-aspects
       newTag: <GIT_SHA>
     - name: overhangio/openedx-aspects-superset
       newName: ghcr.io/biji-biji-initiative/mereka-lms/openedx-aspects-superset
       newTag: <GIT_SHA>
   ```

### Phase 3: Kubernetes Deployment

**Estimated Time**: 15-30 minutes

1. **Enable Aspects plugin in production config**:
   ```bash
   # In tutor_env/config.yml (production overlay)
   # Ensure 'aspects' is in PLUGINS list
   tutor config save
   ./infrastructure/tutor/apply-patches.sh
   ```

2. **Generate K8s manifests**:
   ```bash
   tutor k8s init --limit=aspects
   ```
   **Expected Output**: ClickHouse schema initialized, Superset database initialized

3. **Apply K8s manifests** (if not using ArgoCD):
   ```bash
   kubectl apply -k deploy/k8s/overlays/production/
   ```

4. **Verify pod startup**:
   ```bash
   kubectl get pods -n mereka-lms | grep aspects
   ```
   **Expected Output**: clickhouse, superset, superset-worker, ralph pods in Running state (may take 3-5 minutes)

5. **Check pod logs** (troubleshoot if not running):
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=clickhouse --tail=50
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=superset --tail=50
   ```

### Phase 4: Configuration and Validation

**Estimated Time**: 10-20 minutes

1. **Configure ClickHouse retention policy**:
   ```sql
   -- Connect to ClickHouse pod
   kubectl exec -it -n mereka-lms <clickhouse-pod> -- clickhouse-client

   -- Set TTL for 90-day retention
   ALTER TABLE xapi_events_all MODIFY TTL event_date + INTERVAL 90 DAY;
   ```

2. **Verify event flow** (may take 5-10 minutes for first events):
   ```bash
   kubectl exec -it -n mereka-lms <clickhouse-pod> -- clickhouse-client \
     --query "SELECT count() FROM xapi_events_all"
   ```
   **Expected Output**: Non-zero count after some learner activity

3. **Verify Superset access**:
   ```bash
   curl -I https://analytics.mereka.io
   ```
   **Expected Output**: HTTP 200 OK or redirect to login

4. **Test Superset login**:
   - Navigate to `https://analytics.mereka.io`
   - Login with admin credentials from GCP Secret Manager
   - Verify pre-built dashboards are visible

5. **Test LMS integration**:
   - Login to LMS as instructor
   - Navigate to Course → Instructor Dashboard
   - Verify "Reports" or "Analytics" link appears
   - Click link and confirm Superset embeds correctly

### Phase 5: Monitoring Setup

**Estimated Time**: 10-15 minutes

1. **Apply PrometheusRules**:
   ```bash
   kubectl apply -f deploy/k8s/base/plugins/aspects/prometheusrule.yml
   ```

2. **Verify ServiceMonitors**:
   ```bash
   kubectl get servicemonitor -n mereka-lms | grep aspects
   ```
   **Expected Output**: ServiceMonitors for clickhouse, superset, ralph

3. **Import Grafana dashboards**:
   - Navigate to Grafana
   - Import dashboards from `infrastructure/monitoring/grafana-dashboards/aspects-*.json`
   - Verify metrics populate (ClickHouse disk, event lag)

4. **Test alerting** (optional):
   - Simulate disk pressure or event lag
   - Verify Alertmanager receives alerts
   - Verify alert routes to correct notification channels

---

## Kubernetes Manifest Inventory

The following K8s manifests exist in `deploy/k8s/base/plugins/aspects/`:

| File | Purpose | Key Resources |
|------|---------|---------------|
| `kustomization.yaml` | Kustomize manifest list | Namespace, labels, resource list |
| `configmaps.yml` | Aspects configuration | ClickHouse config, Superset config, Ralph config |
| `secrets.yml` | ExternalSecrets mapping | Superset admin password, secret key, ClickHouse password |
| `volumes.yml` | PersistentVolumeClaims | ClickHouse data storage (100Gi), Superset metadata |
| `deployments.yml` | Pod deployments | clickhouse, superset, superset-worker, ralph |
| `services.yml` | Internal services | clickhouse (9000), superset (8088), ralph (8100) |
| `jobs.yml` | Initialization jobs | ClickHouse schema init, Superset DB init |
| `sync-job.yml` | Data sync CronJob | Event sync from Open edX to ClickHouse |
| `ingress.yml` | External access | Superset dashboard ingress (if exposed) |

**Status**: Manifests exist but are **NOT applied** to production cluster. Kustomization overlay does NOT reference aspects plugin.

**Verification**:
```bash
# Confirm not deployed
kubectl get pods -n mereka-lms | grep aspects
# Expected: No resources found

# Confirm manifests exist
ls deploy/k8s/base/plugins/aspects/
# Expected: 9 YAML files listed above
```

---

## Image Build Requirements

### Aspects Image (`openedx-aspects`)

**Components**:
- Ralph (event processing pipeline)
- Event routing backends
- xAPI transformation logic
- Python dependencies for event processing

**Build Command**:
```bash
tutor images build aspects
```

**Build Time**: 15-20 minutes
**Image Size**: ~800MB (estimated)
**Base Image**: python:3.11-slim

### Aspects Superset Image (`openedx-aspects-superset`)

**Components**:
- Apache Superset (visualization)
- Pre-built dashboards
- Open edX SSO integration
- Python dependencies for visualization

**Build Command**:
```bash
tutor images build aspects-superset
```

**Build Time**: 20-30 minutes
**Image Size**: ~1.2GB (estimated)
**Base Image**: apache/superset:latest

**Build Requirements**:
- Docker Desktop ≥12GB RAM
- 10GB free disk space
- Node.js 18+ (for Superset frontend builds)

---

## Monitoring Requirements

### Critical Metrics

| Metric | Source | Alert Threshold | Action |
|--------|--------|-----------------|--------|
| ClickHouse disk usage | Prometheus | Warning: 75%, Critical: 85% | Increase PVC size or purge old data |
| Event processing lag | Ralph metrics | Critical: >10 minutes | Check Ralph logs, restart Ralph pods |
| Superset query latency (p95) | Superset metrics | Warning: >5 seconds | Optimize queries, add indexes |
| ClickHouse availability | Prometheus | Critical: No metrics for 5 minutes | Check pod status, restart if needed |
| Event throughput | Ralph metrics | Info: <100 events/minute (baseline) | Normal fluctuation, no action |

### Dashboards

**ClickHouse Performance**:
- Disk usage over time
- Query latency (p50, p95, p99)
- Active connections
- Row insertion rate

**Event Pipeline Health**:
- Events processed per minute
- Processing lag (event timestamp vs storage timestamp)
- Error rate
- Queue depth

**Superset Usage**:
- Active users
- Dashboard views
- Query execution time
- Failed queries

### Log Aggregation

**ClickHouse Logs**:
```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=clickhouse --tail=100 -f
```

**Superset Logs**:
```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=superset --tail=100 -f
```

**Ralph Logs**:
```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=ralph --tail=100 -f
```

---

## Rollback Procedure

If issues arise after deployment, execute these steps to disable Aspects:

### Immediate Rollback (Emergency)

**Estimated Time**: 5 minutes

1. **Scale down Aspects pods**:
   ```bash
   kubectl scale deployment -n mereka-lms clickhouse --replicas=0
   kubectl scale deployment -n mereka-lms superset --replicas=0
   kubectl scale deployment -n mereka-lms superset-worker --replicas=0
   kubectl scale deployment -n mereka-lms ralph --replicas=0
   ```

2. **Verify pods stopped**:
   ```bash
   kubectl get pods -n mereka-lms | grep aspects
   ```
   **Expected Output**: No running pods

3. **Disable event routing** (prevents event backlog):
   ```bash
   # In tutor_env/config.yml
   # Comment out or remove Aspects event routing config
   tutor config save
   tutor k8s restart lms cms
   ```

### Full Rollback (Permanent)

**Estimated Time**: 10-15 minutes

1. **Execute immediate rollback steps** (above)

2. **Remove Aspects from plugins**:
   ```bash
   # In tutor_env/config.yml
   # Remove 'aspects' from PLUGINS list
   tutor config save
   ./infrastructure/tutor/apply-patches.sh
   ```

3. **Delete K8s resources**:
   ```bash
   kubectl delete -k deploy/k8s/base/plugins/aspects/
   ```

4. **Delete PVCs** (optional, if not preserving data):
   ```bash
   kubectl delete pvc -n mereka-lms clickhouse-data
   kubectl delete pvc -n mereka-lms superset-data
   ```

5. **Remove image references** from production kustomization:
   ```yaml
   # Remove aspects image entries from:
   # deploy/k8s/overlays/production/kustomization.yaml
   ```

6. **Verify cleanup**:
   ```bash
   kubectl get all -n mereka-lms | grep aspects
   ```
   **Expected Output**: No resources found

### Post-Rollback Actions

- [ ] Update ADR-017 with rollback reason
- [ ] Document issues encountered in post-mortem
- [ ] Review prerequisites and address gaps
- [ ] Re-evaluate deployment timeline

---

## Cost Estimate

### Infrastructure Costs (Monthly)

**Compute (GKE)**:
- ClickHouse: 2 CPU, 4GB RAM → ~$40/month (n1-standard-2)
- Superset: 1 CPU, 2GB RAM → ~$20/month (n1-standard-1 shared)
- Superset Worker: 0.5 CPU, 1GB RAM → ~$10/month (n1-standard-1 shared)
- Ralph: 0.5 CPU, 1GB RAM → ~$10/month (n1-standard-1 shared)

**Subtotal Compute**: ~$80/month

**Storage (GCS + Persistent Disks)**:
- ClickHouse PVC (100Gi SSD): ~$17/month (GCP persistent disk)
- ClickHouse archive (GCS, 500GB): ~$10/month (nearline storage)
- Superset metadata (10Gi): ~$2/month

**Subtotal Storage**: ~$29/month

**Network**:
- Egress (minimal, internal): ~$5/month
- LoadBalancer (if separate ingress): ~$0 (using existing Caddy)

**Subtotal Network**: ~$5/month

**Total Estimated Cost**: **~$114/month** (with compression and 90-day hot retention)

### Cost Optimization Strategies

1. **Use preemptible nodes** for non-critical workloads (Ralph, Worker) → Save ~30%
2. **Compress historical data** (>7 days) → Save ~50% storage
3. **Export to GCS cold storage** after 90 days → $4/TB/month (vs $20/TB for disk)
4. **Right-size resources** after observing actual usage → Potential 20% savings

**Optimized Total**: **~$70-80/month**

---

## Success Criteria

After deployment, the following conditions confirm successful enablement:

- [ ] All Aspects pods in Running state for 24+ hours without restarts
- [ ] ClickHouse storing events (verify with `SELECT count() FROM xapi_events_all`)
- [ ] Superset dashboards accessible to staff users
- [ ] LMS Instructor Dashboard shows "Reports" link
- [ ] Event processing lag <2 minutes (p50), <10 minutes (p95)
- [ ] ClickHouse query latency <2 seconds (p50), <5 seconds (p95)
- [ ] No PII in events (verified by sampling 1000 random events)
- [ ] Monitoring alerts configured and firing correctly (test with simulated incident)
- [ ] Operational runbooks tested (execute each runbook once)
- [ ] Zero security vulnerabilities in Aspects images (scan with trivy or similar)

---

## Related Documentation

- [ADR-017: Analytics Target Decision](../../adr/017-analytics-target-decision.md) - Deferral decision and revisit conditions
- [Analytics Pipeline Spec](../../../specs/analytics-pipeline_spec.md) - Requirements and acceptance criteria
- [Aspects Installation Guide](../analytics/ASPECTS_INSTALLATION.md) - Step-by-step deployment
- [Aspects Quickstart](../analytics/ASPECTS_QUICKSTART.md) - Post-install validation
- [Aspects vs Panorama Comparison](../analytics/ASPECTS_VS_PANORAMA.md) - Alternative analysis
- [Open edX Aspects Documentation](https://docs.openedx.org/projects/openedx-aspects/) - Official upstream docs

---

## Maintenance and Operations

### Routine Maintenance (Monthly)

- [ ] Review ClickHouse disk usage trends
- [ ] Optimize slow Superset queries (identify via logs)
- [ ] Review event processing lag patterns
- [ ] Check for Aspects/Superset security updates
- [ ] Verify backup integrity (restore test)

### Upgrades

**Aspects Plugin**:
1. Check for new `tutor-contrib-aspects` releases
2. Test upgrade in local environment first
3. Review changelog for breaking changes
4. Rebuild images with new version
5. Deploy to production during maintenance window

**ClickHouse**:
1. Review ClickHouse release notes
2. Test schema migrations in staging
3. Backup data before upgrade
4. Deploy with zero-downtime strategy (if clustered)

**Superset**:
1. Review Superset release notes
2. Test dashboard compatibility
3. Export dashboards before upgrade
4. Rebuild images with new Superset version

### Capacity Planning

**Trigger for scaling**:
- ClickHouse disk >70% full → Increase PVC or purge old data
- Event lag consistently >5 minutes → Scale Ralph replicas
- Superset query latency consistently >3 seconds → Add read replicas or optimize queries

---

**Contract Version**: 1.0
**Last Reviewed**: 2026-02-17
**Next Review**: Upon ADR-017 approval or 6 months from last review
