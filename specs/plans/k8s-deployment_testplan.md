---
spec: k8s-deployment_spec.md
tier: 1
status: draft
last_updated: '2026-02-10'
test_framework: shell_verification (bash scripts + kubectl kustomize)
plan: k8s-deployment_plan.md
---

# Test Plan: Kubernetes Deployment Specification

**Source Spec**: `specs/k8s-deployment_spec.md`
**Plan**: `specs/plans/k8s-deployment_plan.md`

## Test Strategy

This spec governs Kubernetes manifests (YAML) and cluster state. There is no application code to unit-test. The test typesused are:

| Test Type | Description | Requires Cluster |
|-----------|-------------|------------------|
| `shell_verification` | Bash script that parses `kubectl kustomize` rendered output | No |
| `kubectl_check` | Live `kubectl` commands against a runningcluster | Yes |
| `smoke_test` | HTTP requests against deployed services | Yes |
| `ci_workflow` | GitHub Actions workflow step | No |
| `manual_verification` | Human-performed check with documented steps | Varies |

Most ACs can be verified offline by rendering Kustomize overlays and parsing the YAML output. Live cluster checks are needed for runtime state (pod readiness, secret sync, TLS certificates).

---

## Test Matrix

### Namespace and Structure (AC-001, AC-002)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-001 | Local overlay renders without errors; all resources in `mereka-lms` namespace | shell_verification | `scripts/qa/verify-kustomize-render.sh --overlay local` | Requires `kubectl` binary (no cluster) |
| AC-001 | (Negative) Overlay with invalid resource path fails cleanly | shell_verification | `scripts/qa/verify-kustomize-render.sh --overlay local --expect-fail` | Inject bad path |
| AC-002 | Production overlay renders without errors; all resources in `mereka-lms` namespace | shell_verification | `scripts/qa/verify-kustomize-render.sh --overlay production` | Requires `kubectl` binary |

### Deployments (AC-003 through AC-009)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-003 | All Deployments reach Ready state within 10 minutes | kubectl_check | `scripts/qa/verify-k8s-live-cluster.sh --check deployments` | Live GKE or Kind cluster |
| AC-003 | (Negative) If a Deployment image is invalid, it enters ImagePullBackOff | kubectl_check | Manual: change imagetag, verify status | Kind cluster + bad image |
| AC-004 | Production overlay: LMS=2 replicas, LMS-Worker=2 replicas | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check replicas --overlay production` | Parses rendered YAML |
| AC-005 | Local overlay: all Deployments have exactly 1 replica | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check replicas --overlay local` | Parses rendered YAML |
| AC-006 | LMS, CMS, workers reference openedx-secrets, database-secrets, mereka-lms-runtime-secrets via envFrom | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check envfrom` | Parses rendered YAML; checks lms, cms, lms-worker, cms-worker, discovery, ecommerce, credentials, notes, xqueue |
| AC-006 | (Negative) Deployment missing one envFrom secretRef is flagged | shell_verification | Test with intentionally removed secretRef | Synthetic test |
| AC-007 | MySQL Deployment args include `--mysql-native-password=ON` | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check mysql-args` | Parses mysql container args |
| AC-008 | MySQL Deployment has mysqld-exporter sidecar on port 9104 | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check mysql-exporter` | Parses mysql containers|
| AC-009 | Redis Deployment has redis-exporter sidecar on port 9121 | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check redis-exporter` | Parses redis containers|

### Security (AC-010, AC-011, AC-012)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-010 | Application Deployments set runAsUser: 1000, runAsGroup: 1000 | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check security-context` | Checks lms, cms,workers, discovery, ecommerce, credentials, notes, forum (ifpresent) |
| AC-010 | MySQL sets runAsUser: 999, runAsGroup: 999 | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check security-context` | Specific mysql check |
| AC-010 | SMTP sets runAsUser: 100, runAsGroup: 101 | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check security-context` | Specific smtp check |
| AC-011 | All containers with security contexts set allowPrivilegeEscalation: false | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check privilege-escalation` | Scans all Deployments |
| AC-011 | (Negative) Container with allowPrivilegeEscalation: true is flagged | shell_verification | Synthetic mutation test | Inject `true` value |
| AC-012 | No hardcoded secrets in deploy/k8s/ manifests (excluding local dev placeholders) | shell_verification | `scripts/qa/verify-k8s-secrets-hygiene.sh` | Regex scan for passwords, API keys, tokens |
| AC-012 | (Negative) Manifest with plaintext password (non-dev) is flagged | shell_verification | Synthetic test with injected secret | Verify detection |

### Services (AC-013, AC-014)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-013 | No Service shows empty endpoints after Deploymentsare Ready | kubectl_check | `scripts/qa/verify-k8s-live-cluster.sh --check endpoints` | Live cluster; extends `verify-service-endpoints.sh` |
| AC-013 | (Negative) Service with mismatched selector showsempty endpoints | kubectl_check | Manual: modify selector, verify empty | Kind cluster |
| AC-014 | Each Service selector matches its Deployment pod template labels | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check selector-match` | Cross-referencesservices.yml and deployments.yml rendered output |

### Persistent Volumes (AC-015, AC-016)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-015 | PVCs: caddy 1Gi, elasticsearch 2Gi, mysql 5Gi, redis 1Gi with ReadWriteOnce | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check pvcs` | Parses volumes.yml |
| AC-015 | (Negative) PVC with wrong access mode is flagged |shell_verification | Synthetic mutation test | Inject ReadWriteMany |
| AC-016 | Stateful Deployments (elasticsearch, mysql, redis)use strategy Recreate | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check strategy` | Parses deployment strategy |

### Ingress and TLS (AC-017 through AC-020)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-017 | Production overlay has three Ingresses: openedx-lms, openedx-studio, openedx-mfe | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check ingress-count` | Parses production rendered output |
| AC-018 | Ingress annotations: cert-manager cluster-issuer,ssl-redirect, proxy-body-size | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check ingress-annotations` | Checks all three Ingresses |
| AC-019 | LMS Ingress hosts include all required domains | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh--check ingress-hosts` | Verifies each host from spec |
| AC-020 | TLS certificates issued for all declared hosts | kubectl_check | `scripts/qa/verify-k8s-live-cluster.sh --checktls-certs` | Live cluster; checks Certificate resources |
| AC-020 | (Negative) Expired or failing certificate triggerscert-verify-prod alert | kubectl_check | Manual: check Certificate status for challenges | Live cluster |

### Secrets (AC-021 through AC-023)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-021 | ExternalSecrets show STATUS=SecretSynced | kubectl_check | `scripts/qa/verify-k8s-live-cluster.sh --check externalsecrets` | Live cluster |
| AC-021 | (Negative) Invalid ClusterSecretStore causes SecretSyncedError (secrets retained) | kubectl_check | Manual: corrupt store ref, verify Retain behavior | Requires cluster access |
| AC-022 | ExternalSecret spec: refreshInterval=1h, secretStoreRef=gcp-secret-manager, deletionPolicy=Retain | shell_verification | `scripts/qa/verify-k8s-externalsecrets.sh` | Parsesexternal-secrets.yaml |
| AC-023 | All remoteRef keys follow MEREKA_LMS_ prefix | shell_verification | `scripts/qa/verify-k8s-externalsecrets.sh --check prefix` | Regex check on remoteRef.key values |

### ConfigMaps (AC-024)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-024 | At least 13 ConfigMaps generated in base rendering| shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check configmaps` | Counts ConfigMap resources in rendered output |
| AC-024 | (Negative) Missing configMapGenerator entry reduces count below 13 | shell_verification | Synthetic: remove entry, verify count drops | Mutation test |

### Images (AC-025, AC-026)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-025 | No production image uses `latest` tag | shell_verification | `scripts/qa/verify-k8s-images.sh --check no-latest` | Parses production rendered output |
| AC-025 | (Negative) Image with `latest` tag is flagged | shell_verification | Synthetic: inject latest tag | Mutation test |
| AC-026 | OpenEdX images point to ghcr.io/biji-biji-initiative/mereka-lms/ with date-SHA tags | shell_verification | `scripts/qa/verify-k8s-images.sh --check registry-path`| Regex for YYYYMMDD-description-SHA format |

### Monitoring (AC-027, AC-028)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-027 | ServiceMonitors exist for lms, cms, mysql, redis with 30s scrape interval | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check servicemonitors` | Parsesmonitoring/*.yaml |
| AC-028 | PrometheusRule has alerts: LMSPodDown, CMSPodDown,MySQLPodDown, RedisPodDown, OpenEdxCriticalDeploymentUnavailable, OpenEdxCrashLoopingContainers | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check alertrules` |Parses prometheusrule-lms.yaml |
| AC-028 | (Negative) Missing alert rule name is detected | shell_verification | Synthetic: remove one rule | Mutation test |

### Logging (AC-029, AC-030)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-029 | Promtail DaemonSet runs on every node | kubectl_check | `scripts/qa/verify-k8s-live-cluster.sh --check promtail` | Compares pod count to node count |
| AC-029 | Promtail has tolerations for NoSchedule and NoExecute | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check promtail-tolerations` | Parses promtail-daemonset.yaml |
| AC-030 | Promtail resources: requests cpu=50m mem=64Mi, limits cpu=200m mem=128Mi | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check promtail-resources` | Parses promtail-daemonset.yaml |

### Observability CronJobs (AC-031)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-031 | CronJobs auth-verify-prod and cert-verify-prod exist in mereka-lms namespace | kubectl_check | `scripts/qa/verify-k8s-live-cluster.sh --check cronjobs` | Live cluster |
| AC-031 | CronJobs backup-verification and restore-test exist in velero namespace | kubectl_check | `scripts/qa/verify-k8s-live-cluster.sh --check cronjobs-velero` | Live cluster |

### Analytics Stack (AC-032)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-032 | ClickHouse, Superset, Superset-Worker Deploymentsexist with health probes | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check aspects` | Parses plugins/aspects/deployments.yml |
| AC-032 | ClickHouse has /ping liveness/readiness probes onport 8123 | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check aspects-probes` | Specific probe check|
| AC-032 | Superset has /health probes on port 8088 | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check aspects-probes` | Specific probe check |
| AC-032 | ClickHouse resources: requests mem=2Gi cpu=500m, limits mem=4Gi cpu=2 | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check aspects-resources` | Specificresource check |
| AC-032 | Aspects Deployments carry `app.kubernetes.io/part-of: aspects` | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check aspects-labels` | Label check |

---

## Edge Case Tests

These correspond to the Edge Cases section of the spec. Theyare primarily runtime scenarios verified by monitoring alertsor manual procedures.

| Edge Case | Test Case | Type | File / Command | Notes |
|-----------|-----------|------|----------------|-------|
| EC-01: Pod scheduling failures | OpenEdxPodsPendingTooLongalert fires after 15m of Pending | monitoring | PrometheusRule `prometheusrule-lms.yaml` | Verified by AC-028 alert presence |
| EC-02: Service selector mismatches | Selector match check catches mismatch (e.g., notes label bug) | shell_verification| `scripts/qa/verify-k8s-deployment-spec.sh --check selector-match` | Also: `scripts/infra/fix-service-selectors.sh` exists |
| EC-03: ExternalSecret sync failures | deletionPolicy: Retain verified; existing secrets preserved | shell_verification |`scripts/qa/verify-k8s-externalsecrets.sh` | Checked by AC-0|
| EC-04: PVC binding failures | PVC access mode and storageClass checked | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check pvcs` | Runtime: kubectl get pvc |
| EC-05: Image pull failures | Image registry path and tag format verified | shell_verification | `scripts/qa/verify-k8s-images.sh` | Runtime: manual check |
| EC-06: TLS certificate renewal | cert-verify-prod CronJob exists | kubectl_check | `scripts/qa/verify-k8s-live-cluster.sh --check cronjobs` | AC-031 |
| EC-07: MySQL auth plugin | `--mysql-native-password=ON` verified in args | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check mysql-args` | AC-007 |
| EC-08: CrashLoopBackOff | OpenEdxCrashLoopingContainers alert exists | shell_verification | PrometheusRule check | AC-02|
| EC-09: Partial deployment | All Deployment statuses checkedpost-apply, not just first | kubectl_check | `scripts/qa/verify-k8s-live-cluster.sh --check deployments` | AC-003 |
| EC-10: Volume data corruption | Manual procedure documentedin troubleshooting | manual_verification | `docs/ops/runbooks/TROUBLESHOOTING.md` | D-03 adds entries |
| EC-11: Celery worker starvation | --max-tasks-per-child=100in worker args | shell_verification | `scripts/qa/verify-k8s-deployment-spec.sh --check worker-args` | Implicit in workerDeployment check |

---

## CI Integration

The following checks should be added to the CI pipeline (`.github/workflows/ci.yml`):

```yaml
- name: Verify Kustomize Rendering
  run: |
    scripts/qa/verify-kustomize-render.sh --overlay local
    scripts/qa/verify-kustomize-render.sh --overlay production

- name: Verify K8s Deployment Spec Compliance
  run: scripts/qa/verify-k8s-deployment-spec.sh

- name: Verify No Hardcoded Secrets
  run: scripts/qa/verify-k8s-secrets-hygiene.sh

- name: Verify Image Tags
  run: scripts/qa/verify-k8s-images.sh

- name: Verify ExternalSecrets Spec
  run: scripts/qa/verify-k8s-externalsecrets.sh
```

---

## Self-Check

- [x] Every AC (001-032) has at least one test case
- [x] Edge cases from spec have negative/monitoring test cases
- [x] Test type appropriate for each case (shell_verificationfor offline, kubectl_check for live)
- [x] File paths specified for all verification scripts
- [x] Fixtures/notes column explains what is needed for eachtest
- [x] Source spec linked in header
