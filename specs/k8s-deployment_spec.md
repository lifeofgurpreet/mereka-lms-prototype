---
title: "Kubernetes Deployment Specification"
type: "feature_spec"
id: "SPEC-K8S-DEPLOYMENT"
status: "approved"
spec_class: "system"
owner: "engineering"
vehicle: "talent_platform"
created: "2026-02-10"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
domain: "platform"
normativity: "normative"
last_updated: "2026-02-10"
version: "1.0.0"
depends_on:
  - "specs/repository-structure_spec.md"
  - "specs/secrets-management_spec.md"
  - "specs/tutor-configuration_spec.md"
supersedes: []
superseded_by: null
verification_sources:
  - "scripts/qa/run-spec-integrity-gates.sh"
  - "scripts/qa/verify-repo-structure.sh"
  - "scripts/qa/spec-tools/spec_verify.py"
interfaces:
  - "deploy/k8s/base"
  - "deploy/k8s/overlays/local"
  - "bbi-infrastructure/apps/mereka-lms/overlays/prod"
tags:
  - "platform.control-plane"
  - "build.gitops-promotion"
  - "tenant.isolation"
  - "auth.oidc"
summary: "Normative deployment contract for Kubernetes-managed Open edX workloads, overlays, secrets, ingress, and operational health expectations."
links:
  related_docs:
    - "docs/guides/admin/K8S_OPERATIONS_GUIDE.md"
    - "docs/ops/runbooks/K8S_DEPLOYMENT_RUNBOOK.md"
    - "docs/ops/runbooks/TROUBLESHOOTING.md"
    - "docs/reference/operations/MONITORING.md"
    - "docs/ops/runbooks/DISASTER_RECOVERY.md"
    - "docs/ops/runbooks/RELEASE_CHECKLIST.md"
  related_specs:
    - "specs/secrets-management_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/multi-site-domains_spec.md"
    - "specs/tutor-configuration_spec.md"
    - "specs/mongodb-atlas-integration_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

> **Deployment boundary (ADR-025)**: For the authoritative classification of which files in
> `deploy/k8s/` stay in this repo vs migrate to `bbi-infrastructure`, see
> `docs/reference/architecture/DEPLOYMENT_CONTRACT.md` and `docs/reference/architecture/RESOURCE_OWNERSHIP_MATRIX.md`.
> Active environments: local (owned here), rke2-nonprod (dev + staging), and
> rke2-prod (production). This repo owns the app package under `deploy/k8s/base/`
> and the local developer overlay under `deploy/k8s/overlays/local/`. GitOps owns
> non-local realization overlays in `bbi-infrastructure`; this repo must not
> require `deploy/k8s/overlays/production` to exist.

# Human Summary

## What we're building

A production-grade Kubernetes deployment of the Open edX learning platform (Tutor 21.0.0, Ulmo). The deployment consists of 17+ workloads spanning the LMS, Studio (CMS), micro-frontends, supporting services (Forum, Discovery, Credentials, Notes, XQueue, Purchase Gateway), infrastructure databases (MySQL, Redis, Meilisearch), an SMTP relay, a Caddy reverse proxy, and an analytics stack (ClickHouse, Superset). The app package is exported from this repo as `deploy/k8s/base/`; environment realization overlays for dev, staging, and production are owned by the GitOps repo. The app-owned local overlay remains under `deploy/k8s/overlays/local/`.

## Why it matters

The Mereka Academy LMS serves learners across Biji-Biji Initiative and SkillOurFuture programs. Deployment errors -- misconfigured selectors, missing secrets, empty endpoints, or resource exhaustion -- directly cause site outages visible to learners and instructors. A well-specified deployment contract prevents configuration drift between environments, ensures secrets are never hardcoded, makes rollout and rollback predictable, and gives on-call engineers clear verification commands.

## Success looks like

- All 17+ Deployments reach Ready state within 10 minutes of applying manifests.
- ExternalSecrets sync from GCP Secret Manager without manual intervention.
- TLS certificates auto-provision via cert-manager for all production domains.
- The app-owned base and local overlay render cleanly in this repo; GitOps-owned
  production overlays render cleanly in the GitOps repo.
- On-call engineers can diagnose site-down conditions using the 5-command diagnostic in under 5 minutes.
- Zero hardcoded secrets in any manifest checked into version control.

# Agent Contract

## Scope

- In scope:
  - Namespace definition and labeling convention
  - All Deployment specifications (replica counts, images, security contexts, resource requests/limits, volume mounts, environment variables)
  - All Service definitions (type, ports, selectors)
  - All PersistentVolumeClaim definitions (access modes, storage sizes)
  - Ingress contract (hosts, TLS, cert-manager annotations) consumed by GitOps-owned overlays
  - ConfigMap generation via Kustomize (Caddy, OpenEdX settings, Redis, plugin settings)
  - ExternalSecrets integration (ClusterSecretStore, refresh intervals, key mappings)
  - Kustomize package structure (base, local overlay, external GitOps environment overlays)
  - Image management (Artifact Registry, tag strategy, Kustomize image overrides)
  - Monitoring resources (ServiceMonitors, PrometheusRules)
  - Logging resources (Promtail DaemonSet)
  - Label and annotation conventions
  - Security contexts and privilege constraints
  - Health check requirements (liveness/readiness probes)
  - Analytics stack (ClickHouse, Superset, Superset Worker under Aspects plugin)
- Out of scope:
  - Terraform/IaC for GKE cluster provisioning (separate infra spec)
  - CI/CD pipeline definition (see `specs/ci-cd-pipeline_spec.md`)
  - Application-level configuration (Django settings content, uWSGI tuning parameters)
  - MongoDB Atlas cluster management (see `specs/mongodb-atlas-integration_spec.md`)
  - DNS record management in Cloudflare
  - Helm chart packaging (this project uses raw Kustomize)

## Non-goals

- Horizontal Pod Autoscaler (HPA) -- current traffic levels do not justify autoscaling; production uses fixed replica counts
- Service Mesh (Istio/Linkerd) -- unnecessary complexity for current scale
- Multi-cluster federation -- single GKE cluster is sufficient
- NetworkPolicies -- GKE Autopilot manages network isolation; adding explicit policies is a future hardening item
- PodDisruptionBudgets -- deferred until replica counts exceed 2 for any workload
- Resource Quotas at namespace level -- single-team ownership eliminates noisy-neighbor risk
- Windows node support -- all workloads are Linux containers
- GPU workloads -- no ML inference in the LMS deployment

## Assumptions

- GKE Autopilot cluster is provisioned and reachable via `kubectl`
- cert-manager and the NGINX Ingress Controller are installed cluster-wide
- ExternalSecrets Operator is installed with a configured `gcp-secret-manager` ClusterSecretStore
- Prometheus Operator (kube-prometheus-stack) is installed for ServiceMonitor and PrometheusRule support
- Loki is reachable from within the cluster for log ingestion by Promtail
- Container images are pre-built and pushed to `ghcr.io/biji-biji-initiative/mereka-lms/`
- MongoDB Atlas is externally accessible and connection strings are stored in GCP Secret Manager

## Requirements

### Functional

#### Namespace

- All Open edX resources MUST be deployed to the `mereka-lms` namespace.
- The namespace MUST be defined as a Kustomize resource in `deploy/k8s/base/namespace.yml`.
- The namespace MUST carry the label `app.kubernetes.io/component: namespace`.

#### Deployments

- The following Deployments MUST exist in the base layer:

  | Deployment | Image | Container Port | Replicas (local) | Replicas (prod) |
  |---|---|---|---|---|
  | caddy | caddy:2.7.4 | 80, 443 | 1 | 1 |
  | lms | overhangio/openedx | 8000 | 1 | 2 |
  | cms | overhangio/openedx | 8000 | 1 | 1 |
  | lms-worker | overhangio/openedx | -- | 1 | 2 |
  | cms-worker | overhangio/openedx | -- | 1 | 1 |
  | elasticsearch | elasticsearch:7.17.13 | 9200 | 1 | 1 |
  | mysql | mysql:8.4.0 | 3306 | 1 | 1 |
  | redis | redis:7.2.4 | 6379 | 1 | 1 |
  | smtp | devture/exim-relay:4.96-r1-0 | 8025 | 1 | 1 |
  | discovery | overhangio/openedx-discovery:18.0.0 | 8000 | 1 | 1 |
  | ecommerce | overhangio/openedx-ecommerce:18.0.1 | 8000 | 1 | 1 |
  | ecommerce-worker | overhangio/openedx-ecommerce-worker:18.0.1 | 8000 | 1 | 1 |
  | credentials | overhangio/openedx-credentials:18.0.0 | 8000 | 1 | 1 |
  | forum | overhangio/openedx-forum:18.1.1 | 4567 | 1 | 1 |
  | mfe | overhangio/openedx-mfe | 8002 | 1 | 1 |
  | notes | overhangio/openedx-notes:18.0.0 | 8000 | 1 | 1 |
  | xqueue | overhangio/openedx-xqueue:18.0.0 | 8000 | 1 | 1 |

- Each Deployment MUST carry standard Kubernetes labels: `app.kubernetes.io/name`, `app.kubernetes.io/instance: mereka-lms`, `app.kubernetes.io/managed-by: tutor`, `app.kubernetes.io/part-of: mereka-lms`.
- The LMS, CMS, LMS-Worker, CMS-Worker, Discovery, Ecommerce, Credentials, Notes, and XQueue Deployments MUST include `envFrom` referencing `openedx-secrets` and `database-secrets`.
- Worker Deployments (lms-worker, cms-worker) MUST configure Celery with `--max-tasks-per-child=100`, `--prefetch-multiplier=1`, `--without-gossip`, and `--without-mingle`.
- The mysql Deployment MUST start with `--mysql-native-password=ON` for authentication compatibility.
- The mysql Deployment MUST include a `mysqld-exporter` sidecar container for Prometheus metrics on port 9104.
- The redis Deployment MUST include a `redis-exporter` sidecar container for Prometheus metrics on port 9121.

#### Security Contexts

- All application Deployments (LMS, CMS, workers, Discovery, Ecommerce, Credentials, Notes, Forum) MUST set `securityContext.runAsUser: 1000` and `runAsGroup: 1000`.
- The mysql Deployment MUST set `securityContext.runAsUser: 999` and `runAsGroup: 999`.
- The smtp Deployment MUST set `securityContext.runAsUser: 100` and `runAsGroup: 101`.
- All containers MUST set `securityContext.allowPrivilegeEscalation: false` where a security context is defined.
- Stateful Deployments (elasticsearch, mysql, redis) MUST set `fsGroup` and `fsGroupChangePolicy: "OnRootMismatch"` for volume permissions.

#### Services

- The following Services MUST exist in the base layer:

  | Service | Type | Port(s) | Selector |
  |---|---|---|---|
  | caddy | ClusterIP | 80 (http), 443 (https) | app.kubernetes.io/name: caddy |
  | lms | ClusterIP | 8000 (http) | app.kubernetes.io/name: lms |
  | cms | ClusterIP | 8000 (http) | app.kubernetes.io/name: cms |
  | elasticsearch | ClusterIP | 9200 | app.kubernetes.io/name: elasticsearch |
  | mysql | ClusterIP | 3306 (mysql), 9104 (metrics) | app.kubernetes.io/name: mysql |
  | redis | ClusterIP | 6379 (redis), 9121 (metrics) | app.kubernetes.io/name: redis |
  | smtp | ClusterIP | 8025 | app.kubernetes.io/name: smtp |
  | discovery | NodePort | 8000 | app.kubernetes.io/name: discovery |
  | ecommerce | NodePort | 8000 | app.kubernetes.io/name: ecommerce |
  | credentials | NodePort | 8000 | app.kubernetes.io/name: credentials |
  | forum | NodePort | 4567 | app.kubernetes.io/name: forum |
  | mfe | NodePort | 8002 | app.kubernetes.io/name: mfe |
  | notes | ClusterIP | 8000 | app.kubernetes.io/name: notes |
  | xqueue | NodePort | 8000 | app.kubernetes.io/name: xqueue |

- Service selectors MUST match the labels on their corresponding Deployment pod templates.
- Core infrastructure Services (caddy, lms, cms, mysql, redis, elasticsearch, smtp) MUST use `ClusterIP` type.
- Plugin Services exposed through Caddy (discovery, ecommerce, credentials, forum, mfe, xqueue) SHOULD use `NodePort` type.

#### Persistent Volumes

- The following PersistentVolumeClaims MUST exist in the base layer:

  | PVC Name | Access Mode | Storage Size | Used By |
  |---|---|---|---|
  | caddy | ReadWriteOnce | 1Gi | caddy (TLS certificates, config data) |
  | elasticsearch | ReadWriteOnce | 2Gi | elasticsearch (index data) |
  | mysql | ReadWriteOnce | 5Gi | mysql (database files) |
  | redis | ReadWriteOnce | 1Gi | redis (AOF/RDB persistence) |

- All PVCs MUST use `ReadWriteOnce` access mode.
- PVCs MUST carry the label `app.kubernetes.io/component: volume`.
- Stateful Deployments using PVCs (elasticsearch, mysql, redis) MUST use `strategy.type: Recreate` to prevent multi-attach errors.

#### Ingress

- The GitOps production overlay MUST define three Ingress resources:

  | Ingress | Hosts | Backend Service | TLS Secret |
  |---|---|---|---|
  | openedx-lms | academyv2.mereka.io, preview.academyv2.mereka.io, skillourfuture.academy.mereka.io, academy.biji-biji.com, discovery.academyv2.mereka.io, ecommerce.academyv2.mereka.io, notes.academyv2.mereka.io, credentials.academyv2.mereka.io | caddy:80 | openedx-lms-tls |
  | openedx-studio | studio.academyv2.mereka.io, studio.academy.biji-biji.com | caddy:80 | openedx-studio-tls |
  | openedx-mfe | apps.academyv2.mereka.io, apps.academy.biji-biji.com | caddy:80 | openedx-mfe-tls |

- All Ingress resources MUST use `ingressClassName: nginx`.
- All Ingress resources MUST carry the annotation `cert-manager.io/cluster-issuer: letsencrypt-prod`.
- All Ingress resources MUST carry the annotation `nginx.ingress.kubernetes.io/ssl-redirect: "true"`.
- All Ingress resources MUST carry the annotation `nginx.ingress.kubernetes.io/proxy-body-size: 100m` to support large file uploads.
- Each Ingress MUST define a `tls` block with all hosts and the corresponding TLS secret name.

#### ConfigMaps

- The base Kustomize layer MUST generate ConfigMaps via `configMapGenerator` for:
  - `caddy-config` (Caddyfile)
  - `openedx-settings-lms` (LMS Python settings including `mereka_platform_admin.py`, `mereka_forwarded_headers.py`, `mereka_multisite.py`)
  - `openedx-settings-cms` (CMS Python settings including `mereka_platform_admin.py`, `mereka_forwarded_headers.py`, `mereka_multisite.py`)
  - `openedx-config` (LMS/CMS environment YAML files)
  - `openedx-uwsgi-config` (uwsgi.ini)
  - `openedx-theme-head-extra` (branding HTML injection)
  - `redis-config` (redis.conf)
  - `discovery-settings`, `credentials-settings`, `ecommerce-settings`, `ecommerce-worker-settings`
  - `mfe-caddy-config`, `notes-settings`, `xqueue-settings`
- Each ConfigMap MUST carry the label `app.kubernetes.io/name` matching its parent application.

#### Secrets Integration

- LMS, CMS, and worker Deployments MUST reference three secrets via `envFrom`:
  - `openedx-secrets` (application keys, JWT keys, MongoDB credentials, API keys)
  - `database-secrets` (MySQL passwords)
  - `mereka-lms-runtime-secrets` (runtime-injected secrets)
- The system MUST use ExternalSecrets Operator (not static Secret manifests) for production secrets.
- ExternalSecrets MUST reference the `gcp-secret-manager` ClusterSecretStore.
- ExternalSecrets MUST set `refreshInterval: 1h`.
- ExternalSecrets MUST set `target.deletionPolicy: Retain` to prevent secret loss on ExternalSecret deletion.
- All GCP Secret Manager keys MUST follow the `MEREKA_LMS_` prefix convention.
- The local overlay MUST provide dev-safe secret patches (plaintext values for development only, never production credentials).

#### Kustomize Overlays

- The directory structure MUST be:
  ```
  deploy/k8s/
    base/          -- shared resources, configMapGenerator, image defaults
    overlays/
      local/       -- Kind/Minikube dev environment
  ```
- Non-local environment overlays MUST live in the GitOps repo, currently
  `bbi-infrastructure/apps/mereka-lms/overlays/{dev,staging,prod}/`.
- The base `kustomization.yaml` MUST define:
  - `namespace: mereka-lms`
  - `commonAnnotations` with `app.kubernetes.io/version` matching the Tutor release
  - `labels` with `includeSelectors: false` (to prevent immutability errors)
  - `images` overrides for openedx and openedx-mfe
- The local overlay MUST:
  - Set all Deployment replicas to 1
  - Include dev secret patches
  - Include a `ClusterIssuer` for local cert-manager
  - Provide a `secretGenerator` for `ses-smtp-credentials` with dev placeholder values
- The GitOps production overlay MUST:
  - Set LMS replicas to 2 and LMS-Worker replicas to 2
  - Set CMS and CMS-Worker replicas to 1
  - Use specific image tags (date-prefixed SHA format: `YYYYMMDD-description-shortsha`)
  - Include production Ingress resources
  - Patch out legacy resources (e.g., `remove-legacy-mongodb-service.yaml`)
- The app-owned local overlay and GitOps-owned environment overlays MUST render without errors via `kubectl kustomize`.

#### Image Management

- Production images MUST be stored in `ghcr.io/biji-biji-initiative/mereka-lms/`.
- Production image tags MUST follow the format `YYYYMMDD-<description>-<7-char-git-sha>`.
- Production images MUST NOT use the `latest` tag.
- Local overlay images SHOULD align with production tags and be pre-loaded into Kind nodes.
- Image overrides MUST be defined in the Kustomize `images` field, not inline in Deployment manifests.

#### Monitoring Resources

- The base layer MUST include ServiceMonitors for: lms, cms, mysql, redis.
- ServiceMonitors MUST scrape at 30-second intervals with 10-second timeouts.
- The base layer MUST include a `PrometheusRule` resource defining alert rules for:
  - Pod availability (LMSPodDown, CMSPodDown, MySQLPodDown, RedisPodDown, ElasticsearchPodDown)
  - Pod restarts (LMSPodRestarting)
  - Memory pressure (LMSPodMemoryHigh at >85%, LMSPodMemoryCritical at >95%, CMSPodMemoryHigh)
  - CPU saturation (LMSPodCPUHigh at >85%)
  - Disk usage (LMSPodDiskSpaceHigh at >85%)
  - Database health (MySQLHighConnectionUtilization at >85%, MySQLSlowQueriesSpike, RedisRejectedConnectionsSpike, RedisEvictionsSpike)
  - Workload stability (OpenEdxCriticalDeploymentUnavailable, OpenEdxPodsPendingTooLong at >15m, OpenEdxCrashLoopingContainers)
  - Synthetic/backup jobs (OpenEdxSyntheticOrBackupJobFailures)

#### Logging

- The base layer MUST include a Promtail DaemonSet for log collection.
- Promtail MUST run on all nodes (including control-plane) via tolerations.
- Promtail MUST mount `/var/log` and `/var/lib/docker/containers` as read-only host paths.
- Promtail MUST define both liveness and readiness probes on its `/ready` endpoint.
- Promtail MUST set resource requests (cpu: 50m, memory: 64Mi) and limits (cpu: 200m, memory: 128Mi).

#### Observability CronJobs

- Production MUST maintain synthetic verification CronJobs in the `mereka-lms` namespace:
  - `auth-verify-prod` (authentication flow verification)
  - `cert-verify-prod` (TLS certificate validity verification)
- Production MUST maintain Velero verification CronJobs in the `velero` namespace:
  - `backup-verification`
  - `restore-test`

#### Analytics Stack (Aspects Plugin)

- The Aspects plugin MUST deploy ClickHouse, Superset, and Superset-Worker as Deployments.
- ClickHouse MUST define liveness and readiness probes on the `/ping` endpoint (port 8123).
- Superset MUST define liveness and readiness probes on the `/health` endpoint (port 8088).
- ClickHouse MUST set resource requests (memory: 2Gi, cpu: 500m) and limits (memory: 4Gi, cpu: 2).
- Superset MUST set resource requests (memory: 1Gi, cpu: 250m) and limits (memory: 2Gi, cpu: 1).
- Aspects Deployments MUST use a separate label set (`app.kubernetes.io/part-of: aspects`) to distinguish from core workloads.

### Non-Functional Requirements

#### Availability

- Production LMS MUST maintain >= 99.5% uptime measured monthly (approximately 3.6 hours maximum downtime per month).
- All critical Deployments (lms, cms, caddy, mysql, redis) MUST reach Ready state within 10 minutes of manifest application.
- ExternalSecrets MUST reach `SecretSynced` status within 5 minutes of initial creation.

#### Resource Budgets

- LMS and CMS containers MUST request at least 2Gi memory.
- Prometheus exporter sidecars (mysqld-exporter, redis-exporter) MUST request no more than cpu: 25m, memory: 64Mi and limit at cpu: 200m, memory: 256Mi.
- Elasticsearch MUST allocate 1GB heap via `ES_JAVA_OPTS: "-Xms1g -Xmx1g"`.
- Total PVC storage across base workloads MUST NOT exceed 10Gi (currently 9Gi: caddy 1Gi + elasticsearch 2Gi + mysql 5Gi + redis 1Gi).

#### Performance

- Caddy SHOULD serve a 200 response on the LMS root path within 2 seconds under normal load.
- Kustomize rendering (`kubectl kustomize`) for any overlay MUST complete in under 30 seconds.

#### Security

- No Deployment manifest MUST contain hardcoded secret values (passwords, API keys, tokens).
- All secrets MUST flow through the pipeline: Infisical -> GCP Secret Manager -> ExternalSecrets -> K8s Secrets -> envFrom.
- All containers with defined security contexts MUST set `allowPrivilegeEscalation: false`.
- The `SMTP_PASSWORD` and `SMTP_USERNAME` MUST be injected via secretKeyRef, never as plaintext env values (except in local dev overlay placeholders).

#### Labeling Standards

- All resources MUST carry `app.kubernetes.io/instance: mereka-lms` and `app.kubernetes.io/part-of: mereka-lms`.
- The Kustomize `labels` configuration MUST set `includeSelectors: false` to prevent selector mutation and immutability errors.
- The base `commonAnnotations` MUST include `app.kubernetes.io/version` set to the current Tutor release version.

## Cross-Spec Integration Criteria

### Secrets Management Integration (Tier 1 → Tier 2)
- [ ] AC-INT-001: Given `secrets-management_spec.md` ExternalSecrets are deployed, when K8s deployments reference `openedx-secrets` and `database-secrets`, then all pods reach Running state with no missing environment variable errors in logs.
- [ ] AC-INT-002: Given ExternalSecrets reach `SecretSynced` status, when LMS pods start, then `kubectl exec lms-pod -- env | grep OPENEDX_SECRET_KEY` returns a non-empty value matching the GCP Secret Manager source.
- [ ] AC-INT-003: Given a secret is rotated in Infisical and synced to GCP SM, when ExternalSecrets refresh (within 1h) and pods restart, then new pods use the rotated value without manual K8s Secret edits.

### Tutor Configuration Integration (Tier 1 → Tier 2)
- [ ] AC-INT-004: Given `tutor-configuration_spec.md` patches are applied, when K8s manifests reference MySQL, then MySQL Deployment includes `--mysql-native-password=ON` flag and LMS connects without authentication errors.
- [ ] AC-INT-005: Given Tutor config includes multi-site domains (academy.biji-biji.com, skillourfuture.academy.mereka.io), when LMS production settings are inspected in the running pod, then `ALLOWED_HOSTS` contains all three domains.

## Acceptance Criteria

### Namespace and Structure
- [ ] AC-001: Given the base Kustomize directory, when `kubectl kustomize deploy/k8s/overlays/local` is run, then it renders without errors and all resources are in namespace `mereka-lms`.
- [ ] AC-002: Given the GitOps production overlay, when `kubectl kustomize bbi-infrastructure/apps/mereka-lms/overlays/prod` is run from the GitOps checkout, then it renders without errors and all resources are in namespace `mereka-lms`.

### Deployments
- [ ] AC-003: Given a fresh cluster, when production manifests are applied, then all 17 base Deployments reach Ready state within 10 minutes.
- [ ] AC-004: Given the GitOps production overlay, when LMS Deployment replicas are inspected, then LMS has 2 replicas and LMS-Worker has 2 replicas.
- [ ] AC-005: Given the local overlay, when Deployment replicas are inspected, then core Open edX workloads (`lms`, `cms`, `lms-worker`, `cms-worker`) have 1 replica and intentionally disabled optional local workloads have 0 replicas.
- [ ] AC-006: Given any LMS, CMS, or worker Deployment, when its envFrom is inspected, then it references `openedx-secrets`, `database-secrets`, and `mereka-lms-runtime-secrets`.
- [ ] AC-007: Given the mysql Deployment, when its container args are inspected, then `--mysql-native-password=ON` is present.
- [ ] AC-008: Given the mysql Deployment, when its containers are inspected, then a `mysqld-exporter` sidecar exists exposing port 9104.
- [ ] AC-009: Given the redis Deployment, when its containers are inspected, then a `redis-exporter` sidecar exists exposing port 9121.

### Security
- [ ] AC-010: Given any application Deployment (lms, cms, workers, discovery, ecommerce, credentials, notes, forum), when its security context is inspected, then `runAsUser: 1000` and `runAsGroup: 1000` are set.
- [ ] AC-011: Given any container with a defined security context, when `allowPrivilegeEscalation` is inspected, then it is `false`.
- [ ] AC-012: Given all manifests in `deploy/k8s/`, when scanned for hardcoded passwords or API keys, then zero matches are found (excluding local dev overlay placeholder values).

### Services
- [ ] AC-013: Given the base Services, when `kubectl get endpoints -n mereka-lms` is run after Deployments are Ready, then no Service shows `<none>` for endpoints.
- [ ] AC-014: Given each Service, when its selector is compared to the corresponding Deployment's pod template labels, then selectors match and endpoints are populated.

### Persistent Volumes
- [ ] AC-015: Given the base PVCs, when they are applied, then caddy (1Gi), elasticsearch (2Gi), mysql (5Gi), and redis (1Gi) PVCs are created with ReadWriteOnce access mode.
- [ ] AC-016: Given stateful Deployments (elasticsearch, mysql, redis), when their strategy is inspected, then `type: Recreate` is set.

### Ingress and TLS
- [ ] AC-017: Given the GitOps production overlay, when Ingress resources are inspected, then three Ingresses exist: openedx-lms, openedx-studio, openedx-mfe.
- [ ] AC-018: Given any production Ingress, when its annotations are inspected, then `cert-manager.io/cluster-issuer: letsencrypt-prod`, `nginx.ingress.kubernetes.io/ssl-redirect: "true"`, and `nginx.ingress.kubernetes.io/proxy-body-size: 100m` are present.
- [ ] AC-019: Given the openedx-lms Ingress, when its hosts are inspected, then it includes: academyv2.mereka.io, preview.academyv2.mereka.io, academy.biji-biji.com, discovery.academyv2.mereka.io, ecommerce.academyv2.mereka.io, notes.academyv2.mereka.io, credentials.academyv2.mereka.io.
- [ ] AC-020: Given production TLS, when certificates are inspected after Ingress creation, then cert-manager has issued valid certificates for all declared hosts.

### Secrets
- [ ] AC-021: Given the ExternalSecrets, when `kubectl get externalsecrets -n mereka-lms` is run, then `openedx-secrets` and `database-secrets` show `STATUS=SecretSynced`.
- [ ] AC-022: Given any ExternalSecret, when its spec is inspected, then `refreshInterval: 1h`, `secretStoreRef.name: gcp-secret-manager`, and `target.deletionPolicy: Retain` are set.
- [ ] AC-023: Given the openedx-secrets ExternalSecret, when its data mappings are inspected, then all remote keys follow the `MEREKA_LMS_` prefix convention.

### ConfigMaps
- [ ] AC-024: Given the base Kustomize rendering, when ConfigMaps are inspected, then at least 13 ConfigMaps are generated (caddy-config, openedx-settings-lms, openedx-settings-cms, openedx-config, openedx-uwsgi-config, openedx-theme-head-extra, redis-config, discovery-settings, credentials-settings, ecommerce-settings, ecommerce-worker-settings, mfe-caddy-config, notes-settings, xqueue-settings).

### Images
- [ ] AC-025: Given the GitOps production overlay, when image tags are inspected, then no image uses the `latest` tag.
- [ ] AC-026: Given the GitOps production overlay, when openedx image references are inspected, then they point to `ghcr.io/biji-biji-initiative/mereka-lms/` with date-prefixed SHA tags.

### Monitoring
- [ ] AC-027: Given the base monitoring resources, when they are applied, then ServiceMonitors for lms, cms, mysql, and redis exist with 30-second scrape intervals.
- [ ] AC-028: Given the PrometheusRule, when its alert rules are inspected, then rules exist for: LMSPodDown, CMSPodDown, MySQLPodDown, RedisPodDown, OpenEdxCriticalDeploymentUnavailable, and OpenEdxCrashLoopingContainers.

### Logging
- [ ] AC-029: Given the Promtail DaemonSet, when it is applied, then a Promtail pod runs on every node in the cluster.
- [ ] AC-030: Given the Promtail DaemonSet, when its resource limits are inspected, then requests are cpu: 50m, memory: 64Mi and limits are cpu: 200m, memory: 128Mi.

### Observability CronJobs
- [ ] AC-031: Given the production cluster, when CronJobs are listed, then `auth-verify-prod` and `cert-verify-prod` exist in `mereka-lms` namespace, and `backup-verification` and `restore-test` exist in `velero` namespace.

### Analytics Stack
- [ ] AC-032: Given the Aspects plugin, when its Deployments are inspected, then ClickHouse, Superset, and Superset-Worker exist with health probes and resource limits defined.

## Edge Cases

### Pod Scheduling Failures
- If a node lacks sufficient resources, pods remain `Pending`. The `OpenEdxPodsPendingTooLong` alert fires after 15 minutes. Resolution: check `kubectl describe pod` for scheduling events, scale node pool, or reduce resource requests.

### Service Selector Mismatches
- After pod restarts or Kustomize label mutations, Service selectors may not match pod labels, resulting in empty endpoints (`<none>`). This is the most common cause of site-down incidents. Resolution: run `scripts/infra/fix-service-selectors.sh`. Prevention: Kustomize `labels.includeSelectors: false` prevents automated selector injection.

### ExternalSecret Sync Failures
- If the GCP Secret Manager ClusterSecretStore becomes unreachable (credentials expired, API disabled), ExternalSecrets enter `SecretSyncedError` state. Existing K8s Secrets are retained (`deletionPolicy: Retain`) so running pods are unaffected. New pods cannot start if secrets are missing. Resolution: verify ClusterSecretStore credentials, check `kubectl describe externalsecret`.

### PVC Binding Failures
- PVCs may remain `Pending` if no StorageClass default is set or the storage provisioner is unhealthy. Stateful Deployments using `Recreate` strategy will block until PVCs bind. Resolution: check `kubectl get pvc -n mereka-lms` and `kubectl describe pvc`.

### Image Pull Failures
- If Artifact Registry credentials expire or image tags are incorrect, pods enter `ImagePullBackOff`. Resolution: verify `imagePullSecrets`, check image exists in registry with `gcloud artifacts docker images list`.

### TLS Certificate Renewal Failures
- cert-manager auto-renews certificates before expiry. If ACME challenges fail (DNS misconfiguration, rate limits), certificates expire. The `cert-verify-prod` CronJob detects this. Resolution: check `kubectl describe certificate`, verify DNS records, check Let's Encrypt rate limit status.

### MySQL Authentication Plugin Errors
- Open edX requires `mysql_native_password` authentication. If the `--mysql-native-password=ON` flag is missing from the mysql Deployment, all database connections fail with authentication errors. Resolution: verify mysql container args include the flag.

### CrashLoopBackOff
- Containers that repeatedly crash (missing config, OOM, unresolvable dependencies) enter CrashLoopBackOff. The `OpenEdxCrashLoopingContainers` alert fires after 10 minutes. Resolution: check `kubectl logs` and `kubectl describe pod` for the crash reason.

### Partial Deployment (Some Services Down)
- Kustomize applies all resources atomically, but individual Deployments may fail while others succeed. This can leave the platform in a partially functional state (e.g., LMS up but Forum down). Resolution: check all Deployment statuses after applying, not just the first one.

### Volume Data Corruption
- If a stateful pod (mysql, redis, elasticsearch) is forcefully terminated during a write, data files may become corrupt. Resolution: for mysql, run `mysqlcheck --all-databases`; for elasticsearch, check cluster health; for redis, verify AOF integrity.

### Celery Worker Starvation
- If worker pods run out of memory processing large tasks, they are OOM-killed. With `--max-tasks-per-child=100`, workers restart after 100 tasks to prevent memory leaks. If the problem persists, increase memory requests.

## Observability

### Logs
- All container logs MUST be collected by Promtail and forwarded to Loki.
- Promtail MUST label logs with `namespace`, `pod`, `container`, and `node`.
- Application logs (LMS, CMS) SHOULD be structured (JSON) when possible for query efficiency.

### Metrics
- Pod-level metrics (CPU, memory, network, restarts) MUST be collected by Prometheus via kubelet/cAdvisor.
- Application-level metrics MUST be scraped via ServiceMonitors from `/metrics` endpoints on LMS and CMS.
- Database metrics MUST be scraped from mysqld-exporter (port 9104) and redis-exporter (port 9121).
- Key metrics to track:
  - `kube_deployment_status_replicas_unavailable` (per deployment)
  - `container_memory_working_set_bytes` (per container)
  - `container_cpu_usage_seconds_total` (per container)
  - `kube_pod_container_status_restarts_total` (per pod)
  - `mysql_global_status_threads_connected` / `mysql_global_variables_max_connections`
  - `redis_rejected_connections_total`
  - `redis_evicted_keys_total`

### Alerts
- Critical alerts (severity: critical, fire within 5 minutes):
  - LMSPodDown, CMSPodDown, MySQLPodDown, RedisPodDown
  - LMSPodMemoryCritical (>95% memory)
  - OpenEdxCriticalDeploymentUnavailable (any core deployment)
  - OpenEdxCrashLoopingContainers
  - MySQLExporterDown, RedisExporterDown
- Warning alerts (severity: warning, fire within 10-15 minutes):
  - LMSPodRestarting, LMSPodMemoryHigh (>85%), LMSPodCPUHigh (>85%)
  - CMSPodMemoryHigh, LMSPodDiskSpaceHigh (>85%)
  - MySQLHighConnectionUtilization (>85%), MySQLSlowQueriesSpike
  - RedisRejectedConnectionsSpike, RedisEvictionsSpike
  - ElasticsearchPodDown, MongoDBPodDown
  - OpenEdxPodsPendingTooLong (>15 minutes)
  - OpenEdxSyntheticOrBackupJobFailures

### Dashboards
- A Grafana dashboard SHOULD exist showing: deployment replica status, pod restarts, memory/CPU usage per workload, MySQL connection utilization, Redis memory and evictions.
- Dashboard JSON definitions SHOULD be stored in `infrastructure/monitoring/` and kept valid and deployable.

## Rollout & Rollback

### Rollout Plan

1. **Image Build**: Build and push new images to Artifact Registry with date-SHA tags.
2. **Manifest Update**: Update image tags in the GitOps production overlay `kustomization.yaml`.
3. **Dry Run**: From the GitOps checkout, run `kubectl kustomize apps/mereka-lms/overlays/prod` to verify rendering.
4. **Apply**: Promote through the release/GitOps path; do not apply an app-repo production overlay.
5. **Verify Deployments**: Wait for all Deployments to reach Ready state:
   ```bash
   kubectl rollout status deployment/lms -n mereka-lms --timeout=300s
   kubectl rollout status deployment/cms -n mereka-lms --timeout=300s
   ```
6. **Verify Endpoints**: Confirm no Service has empty endpoints:
   ```bash
   kubectl get endpoints -n mereka-lms
   ```
7. **Smoke Test**: Run `scripts/qa/audit-observability.sh --mode local` and verify LMS responds:
   ```bash
   curl -I https://academyv2.mereka.io
   ```
8. **Monitor**: Watch alerts for 15 minutes after rollout for regressions.

### Backward Compatibility

- Kustomize image overrides apply only to matching image references; non-matching Deployments are unaffected.
- ExternalSecrets `deletionPolicy: Retain` ensures secrets persist even if the ExternalSecret resource is accidentally deleted.
- PVC data persists across Deployment restarts and reapplies.

### Rollback Steps

1. **Identify**: Check which Deployment is failing via `kubectl get pods -n mereka-lms` and alerts.
2. **Revert Image Tag**: Change the image tag in the GitOps production overlay back to the previous known-good tag.
3. **Apply Rollback**: Promote the reverted GitOps overlay through the release/GitOps path.
4. **Alternatively (per-Deployment)**: Use `kubectl rollout undo deployment/<name> -n mereka-lms` for a single workload.
5. **Verify**: Confirm all pods are Running and endpoints are populated.
6. **Post-mortem**: Document the failure in a bead and update manifests to prevent recurrence.

### Emergency Procedures

- **Full site down**: Run the 5-command diagnostic from `docs/operations/K8S_OPERATIONS_GUIDE.md`. Most commonly caused by empty endpoints; fix with `scripts/infra/fix-service-selectors.sh`.
- **Single service down**: Restart the specific Deployment: `kubectl rollout restart deployment/<name> -n mereka-lms`.
- **Secret corruption**: ExternalSecrets will re-sync within 1 hour. To force immediate sync: `kubectl annotate externalsecret <name> -n mereka-lms force-sync=$(date +%s)`.

## Verification

```bash
# 1. Namespace exists
kubectl get ns mereka-lms  # MUST exist

# 2. All Deployments are Ready
kubectl get deployments -n mereka-lms
# All MUST show READY = desired/desired

# 3. No empty endpoints
kubectl get endpoints -n mereka-lms
# No Service MUST show <none>

# 4. ExternalSecrets synced
kubectl get externalsecrets -n mereka-lms -o wide
# MUST show: openedx-secrets and database-secrets with STATUS=SecretSynced

# 5. Deployment envFrom references secrets
kubectl get deploy lms -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].envFrom}'
# MUST include secretRef to openedx-secrets, database-secrets, mereka-lms-runtime-secrets

# 6. App-owned Kustomize surfaces render cleanly
kubectl kustomize deploy/k8s/overlays/local 2>&1 | head -5      # MUST not error
# In the GitOps checkout, the production overlay MUST also render:
# kubectl kustomize apps/mereka-lms/overlays/prod 2>&1 | head -5

# 7. No hardcoded secrets in manifests
grep -rn "password\|secret_key\|api_key" deploy/k8s/base/ --include="*.yml" --include="*.yaml" | grep -v "secretKeyRef\|secretRef\|remoteRef\|SecretStore\|ExternalSecret\|secretName\|Secret\|secretGenerator" | grep -v "#"
# MUST return empty (no hardcoded values)

# 8. Production images use specific tags (not latest; run in GitOps checkout)
kubectl kustomize apps/mereka-lms/overlays/prod | grep "image:" | grep -c "latest"
# MUST return 0

# 9. Monitoring resources exist
kubectl get servicemonitors -n mereka-lms
# MUST show: lms-metrics, cms-metrics, mysql-metrics, redis-metrics

# 10. PrometheusRules exist
kubectl get prometheusrules -n mereka-lms
# MUST show: lms-alerts

# 11. Promtail running on all nodes
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=promtail -o wide
# MUST show one pod per node

# 12. Observability template integrity
./scripts/qa/audit-observability.sh --mode local
# MUST return OK
```

## Open Questions

- Should we add PodDisruptionBudgets for LMS (which runs 2 replicas in production) to ensure at least 1 replica survives voluntary disruptions (e.g., node upgrades)?
- Should we introduce Horizontal Pod Autoscaler for LMS when traffic patterns become clearer? What metrics and thresholds would trigger scaling?
- Should the mongodb Service (ClusterIP) in the base layer be removed entirely, since production uses MongoDB Atlas directly? (Currently patched out in production via `remove-legacy-mongodb-service.yaml`.)
- What is the target RTO/RPO for MySQL data loss? This affects whether we should move to Cloud SQL or continue with in-cluster MySQL + Velero backups.
- Should NetworkPolicies be introduced to restrict pod-to-pod communication (e.g., prevent MFE from directly accessing MySQL)?
- Should the xqueue, notes, and forum Services be changed from NodePort to ClusterIP since Caddy proxies all external traffic?
- What are the concrete memory and CPU limits (not just requests) for LMS and CMS containers? Currently only `requests.memory: 2Gi` is set with no upper limit.
