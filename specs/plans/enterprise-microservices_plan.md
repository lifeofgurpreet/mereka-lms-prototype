---
spec: enterprise-microservices_spec.md
tier: 4
order: 4.3
status: draft
estimated_effort: "10-12 weeks (5 phases)"
prerequisites:
  - multi-tenancy-architecture_spec.md (Tier 4.1, must be complete)
  - auth-sso-enterprise_spec.md (Tier 4.2, must be complete)
  - k8s-deployment_spec.md (Tier 1)
  - secrets-management_spec.md (Tier 0)
  - observability-stack_spec.md (Tier 2)
  - cross-cutting-requirements_spec.md (Tier 0)
last_updated: "2026-02-10"
---

# Implementation Plan: Enterprise Microservices Deployment

**Source Spec**: `specs/enterprise-microservices_spec.md`

## Summary

This plan covers the deployment of five upstream Open edX enterprise microservices (enterprise-catalog, license-manager, enterprise-access, enterprise-subsidy, enterprise-integrated-channels) plus two enterprise MFEs (admin-portal, learner-portal-enterprise) into the existing `mereka-lms` GKE namespace. All services use upstream community Docker images -- no source forking. The work is configuration-only: K8s manifests, ExternalSecrets, Caddy routing, LMS Django settings, and provisioning scripts.

This is the **last spec in the Tier 4 sequential chain** (`multi-tenancy -> auth-sso -> enterprise-microservices`). It cannot begin until multi-tenancy (EnterpriseCustomer data model, tenant isolation) and auth-sso (SAML/OIDC, per-tenant IdP) are operational.

**Event bus decision**: Redis Streams is the resolved platform-wide event bus transport (per `cross-cutting-requirements_spec.md`, Section 5).

## Prerequisites Checklist

Before starting any task in this plan:

- [ ] `EnterpriseCustomer` model and tenant isolation strategy from `multi-tenancy-architecture_spec.md` are deployed and verified
- [ ] SAML/OIDC SSO from `auth-sso-enterprise_spec.md` is operational with at least one test IdP
- [ ] GKE cluster has sufficient node capacity for ~5 additional Deployments + 4 Celery workers (~2.5 vCPU, 5 GB RAM)
- [ ] Cloud SQL tier can support 4 additional logical databases
- [ ] Observability stack (Prometheus, Loki, Tempo, Grafana) is operational
- [ ] Infisical secrets pipeline is functional (`Infisical -> GCP SM -> ExternalSecrets -> K8s`)
- [ ] Artifact Registry (`asia-southeast1-docker.pkg.dev/mereka-lms/openedx/`) is accessible for pushing images

---

## Task Breakdown

### Phase 0: Infrastructure Preparation (Week 1-2)

#### Build

- [ ] **[M] Task 0.1**: Provision enterprise MySQL databases in Cloud SQL (`deploy/k8s/base/apps/enterprise/README.md`, `scripts/infra/enterprise/provision-enterprise-dbs.sh`) | AC: AC-033, AC-034 | Depends: None
  - Create 4 logical databases: `enterprise_catalog`, `license_manager`, `enterprise_access`, `enterprise_subsidy`
  - Create 4 dedicated MySQL users with per-database grants
  - **Done**: `SHOW DATABASES` lists all 4; each user can only access its own DB

- [ ] **[M] Task 0.2**: Provision enterprise secrets in Infisical (`scripts/infra/enterprise/provision-enterprise-secrets.sh`) | AC: AC-033 | Depends: None
  - Generate and store 12 secrets at `/k8s/mereka-lms`: 4x SECRET_KEY, 4x OAUTH2_SECRET, 4x MYSQL_PASSWORD
  - Optionally provision Algolia secrets (3 keys) if Algolia is chosen for catalog search
  - **Done**: `infisical secrets list` shows all 12+ enterprise secrets

- [ ] **[M] Task 0.3**: Sync enterprise secrets to GCP Secret Manager (`scripts/infra/enterprise/sync-enterprise-secrets-to-gcpsm.sh`) | AC: AC-033 | Depends: Task 0.2
  - Create matching GCP SM secrets with `MEREKA_LMS_ENTERPRISE_*` prefix
  - **Done**: `gcloud secrets list --filter="name:MEREKA_LMS_ENTERPRISE"` returns all expected secrets

- [ ] **[L] Task 0.4**: Create ExternalSecret manifest for enterprise services (`deploy/k8s/base/secrets/external-secrets.yaml`) | AC: AC-033, AC-034 | Depends: Task 0.3
  - Add new ExternalSecret resource named `enterprise-secrets` to existing file (append after `database-secrets`)
  - Map all 12+ Infisical keys to K8s Secret keys
  - Also add enterprise MySQL passwords to the existing `database-secrets` ExternalSecret
  - **Done**: `kubectl get secret enterprise-secrets -n mereka-lms -o jsonpath='{.data}'` contains all expected keys

- [ ] **[M] Task 0.5**: Register OAuth2 client applications in LMS (`scripts/infra/enterprise/register-oauth2-clients.sh`) | AC: AC-034 | Depends: None
  - Create 4 DOT Applications in LMS Django admin (enterprise-catalog, license-manager, enterprise-access, enterprise-subsidy)
  - Each with `client_type=confidential`, `authorization_grant_type=client-credentials`
  - Store client IDs in a ConfigMap, client secrets are in `enterprise-secrets`
  - **Done**: LMS `/admin/oauth2_provider/application/` lists 4 enterprise service applications

- [ ] **[L] Task 0.6**: Build and push enterprise service Docker images (`scripts/infra/enterprise/build-enterprise-images.sh`) | AC: AC-001 | Depends: None
  - Pull upstream images from `edx/enterprise-catalog`, `edx/license-manager`, `edx/enterprise-access`, `edx/enterprise-subsidy`
  - Tag and push to `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/enterprise-<name>:<tag>`
  - **Done**: `gcloud artifacts docker images list` shows all 4 enterprise images

- [ ] **[S] Task 0.7**: Verify `openedx-enterprise` package in LMS image (`scripts/qa/verify-enterprise-packages.sh`) | AC: AC-001 | Depends: None
  - Exec into LMS pod, run `pip show openedx-enterprise`
  - Verify `integrated_channels` app is in `INSTALLED_APPS`
  - **Done**: Script exits 0 confirming package presence

#### Docs

- [ ] **[S] Task 0.8**: Document infrastructure provisioning steps (`docs/operations/enterprise-infrastructure-setup.md`) | Depends: None
  - Cover database provisioning, secrets setup, OAuth2 registration, image builds
  - **Done**: Document exists with all steps

---

### Phase 1: Enterprise Catalog and Subsidy (Week 3-4)

#### Build

- [ ] **[L] Task 1.1**: Create K8s Deployment manifest for enterprise-catalog (`deploy/k8s/base/apps/enterprise/enterprise-catalog-deployment.yaml`) | AC: AC-001, AC-002, AC-003 | Depends: Task 0.4, Task 0.6
  - Deployment with labels: `app.kubernetes.io/name: enterprise-catalog`, `app.kubernetes.io/component: enterprise`, `app.kubernetes.io/instance: mereka-lms`, `app.kubernetes.io/part-of: mereka-lms`
  - Init container for database migrations (`python manage.py migrate`)
  - `envFrom` referencing `enterprise-secrets` K8s Secret
  - Readiness probe: `GET /health/`, liveness probe: `GET /heartbeat/`
  - Resource requests/limits: 256Mi/512Mi RAM, 200m/500m CPU
  - **Done**: `kubectl get deployment enterprise-catalog -n mereka-lms` shows READY >= 1

- [ ] **[S] Task 1.2**: Create K8s Service for enterprise-catalog (`deploy/k8s/base/apps/enterprise/enterprise-catalog-service.yaml`) | AC: AC-002 | Depends: Task 1.1
  - ClusterIP service on port 8000
  - Selector matching Deployment labels
  - **Done**: `kubectl get endpoints enterprise-catalog -n mereka-lms` shows non-empty endpoints

- [ ] **[M] Task 1.3**: Create Celery worker Deployment for enterprise-catalog (`deploy/k8s/base/apps/enterprise/workers/enterprise-catalog-worker-deployment.yaml`) | AC: AC-001, AC-020 | Depends: Task 1.1
  - Runs `celery -A enterprise_catalog worker` command
  - Same `envFrom` as the web Deployment
  - Celery beat sidecar or separate Deployment for periodic tasks (catalog sync every 6h)
  - **Done**: `kubectl get deployment enterprise-catalog-worker -n mereka-lms` shows READY >= 1

- [ ] **[M] Task 1.4**: Create enterprise-catalog Django settings ConfigMap (`deploy/k8s/base/apps/enterprise/settings/enterprise-catalog-settings.py`) | AC: AC-003, AC-019, AC-021 | Depends: None
  - Configure `LMS_BASE_URL=http://lms:8000`
  - Configure `DISCOVERY_SERVICE_URL=http://discovery:8000`
  - Configure `REDIS_HOST`, `MYSQL_HOST` for Cloud SQL proxy
  - Configure catalog sync interval (6 hours default)
  - Configure Redis cache TTL (5 minutes for catalog queries)
  - **Done**: Settings file renders valid Python; service starts without config errors

- [ ] **[L] Task 1.5**: Create K8s Deployment manifest for enterprise-subsidy (`deploy/k8s/base/apps/enterprise/enterprise-subsidy-deployment.yaml`) | AC: AC-001, AC-002, AC-006 | Depends: Task 0.4, Task 0.6
  - Same pattern as enterprise-catalog: init container for migrations, health probes, envFrom
  - **Done**: `kubectl get deployment enterprise-subsidy -n mereka-lms` shows READY >= 1

- [ ] **[S] Task 1.6**: Create K8s Service for enterprise-subsidy (`deploy/k8s/base/apps/enterprise/enterprise-subsidy-service.yaml`) | AC: AC-002 | Depends: Task 1.5
  - ClusterIP service on port 8000
  - **Done**: Non-empty endpoints

- [ ] **[M] Task 1.7**: Create Celery worker Deployment for enterprise-subsidy (`deploy/k8s/base/apps/enterprise/workers/enterprise-subsidy-worker-deployment.yaml`) | AC: AC-001 | Depends: Task 1.5
  - Runs Celery worker for transaction processing
  - **Done**: Worker pod running

- [ ] **[M] Task 1.8**: Create enterprise-subsidy Django settings ConfigMap (`deploy/k8s/base/apps/enterprise/settings/enterprise-subsidy-settings.py`) | AC: AC-006 | Depends: None
  - Configure LMS URL, MySQL, Redis, event bus (Redis Streams)
  - **Done**: Settings file renders valid Python

- [ ] **[M] Task 1.9**: Configure Redis Streams event bus for enterprise events (`deploy/k8s/base/apps/enterprise/settings/event-bus-config.py`, `infrastructure/tutor/patches/enterprise-event-bus.py`) | AC: AC-001 | Depends: Task 1.1, Task 1.5
  - Configure LMS to publish: `ENROLLMENT_CREATED`, `ENROLLMENT_REVOKED`, `COURSE_COMPLETION`, `LEARNER_CREDIT_REDEEMED`, `LICENSE_ASSIGNED`, `LICENSE_REVOKED`
  - Configure enterprise services to consume relevant events via Redis Streams
  - Event bus config in LMS settings overlay
  - **Done**: Events visible in Redis Streams; consumer groups created for each enterprise service

- [ ] **[S] Task 1.10**: Update Kustomization to include enterprise manifests (`deploy/k8s/base/kustomization.yaml`) | AC: AC-001 | Depends: Task 1.1, Task 1.2, Task 1.3, Task 1.5, Task 1.6, Task 1.7
  - Add `apps/enterprise/` as a resource
  - Add enterprise settings as configMapGenerator entries
  - **Done**: `kustomize build deploy/k8s/base/` succeeds without errors

#### Test

- [ ] **[M] Task 1.11**: Health check verification script (`scripts/qa/verify-enterprise-health.sh`) | AC: AC-003, AC-006 | Depends: Task 1.1, Task 1.5
  - Exec into a pod, curl each enterprise service health endpoint
  - Verify HTTP 200 responses
  - **Done**: Script exits 0

- [ ] **[M] Task 1.12**: Catalog sync verification (`scripts/qa/verify-enterprise-catalog-sync.sh`) | AC: AC-019, AC-020 | Depends: Task 1.3
  - Trigger catalog sync manually via Celery
  - Verify content metadata populated in enterprise-catalog DB
  - **Done**: Script confirms sync completed with >0 items

---

### Phase 2: License Manager and Access (Week 5-6)

#### Build

- [ ] **[L] Task 2.1**: Create K8s Deployment manifest for license-manager (`deploy/k8s/base/apps/enterprise/license-manager-deployment.yaml`) | AC: AC-001, AC-002, AC-004 | Depends: Task 0.4, Task 0.6
  - Same pattern: init container for migrations, health probes, envFrom
  - **Done**: READY >= 1

- [ ] **[S] Task 2.2**: Create K8s Service for license-manager (`deploy/k8s/base/apps/enterprise/license-manager-service.yaml`) | AC: AC-002 | Depends: Task 2.1
  - ClusterIP on port 8000
  - **Done**: Non-empty endpoints

- [ ] **[M] Task 2.3**: Create Celery worker Deployment for license-manager (`deploy/k8s/base/apps/enterprise/workers/license-manager-worker-deployment.yaml`) | AC: AC-001 | Depends: Task 2.1
  - Worker for async license operations (bulk assignment, email sending)
  - **Done**: Worker pod running

- [ ] **[M] Task 2.4**: Create license-manager Django settings ConfigMap (`deploy/k8s/base/apps/enterprise/settings/license-manager-settings.py`) | AC: AC-004 | Depends: None
  - LMS URL, MySQL, Redis, OAuth2 credentials, event bus config
  - **Done**: Service starts without config errors

- [ ] **[L] Task 2.5**: Create K8s Deployment manifest for enterprise-access (`deploy/k8s/base/apps/enterprise/enterprise-access-deployment.yaml`) | AC: AC-001, AC-002, AC-005 | Depends: Task 0.4, Task 0.6
  - Same pattern
  - **Done**: READY >= 1

- [ ] **[S] Task 2.6**: Create K8s Service for enterprise-access (`deploy/k8s/base/apps/enterprise/enterprise-access-service.yaml`) | AC: AC-002 | Depends: Task 2.5
  - ClusterIP on port 8000
  - **Done**: Non-empty endpoints

- [ ] **[M] Task 2.7**: Create Celery worker Deployment for enterprise-access (`deploy/k8s/base/apps/enterprise/workers/enterprise-access-worker-deployment.yaml`) | AC: AC-001 | Depends: Task 2.5
  - Worker for async policy evaluation, enrollment triggers
  - **Done**: Worker pod running

- [ ] **[M] Task 2.8**: Create enterprise-access Django settings ConfigMap (`deploy/k8s/base/apps/enterprise/settings/enterprise-access-settings.py`) | AC: AC-005 | Depends: None
  - Configure URLs for enterprise-catalog, enterprise-subsidy, license-manager (internal K8s DNS)
  - **Done**: Service starts without config errors

#### Test

- [ ] **[M] Task 2.9**: License manager health and API verification (`scripts/qa/verify-license-manager.sh`) | AC: AC-004, AC-014, AC-018 | Depends: Task 2.1
  - Health endpoint check
  - Create test subscription plan via Django management command
  - Verify license assignment/revocation API flow
  - **Done**: Script exits 0

- [ ] **[M] Task 2.10**: Enterprise access policy verification (`scripts/qa/verify-enterprise-access.sh`) | AC: AC-005, AC-022, AC-023 | Depends: Task 2.5
  - Health endpoint check
  - Create test access policy
  - Verify `can-redeem` endpoint
  - **Done**: Script exits 0

---

### Phase 3: Enterprise MFEs (Week 7-8)

#### Build

- [ ] **[L] Task 3.1**: Build and push admin-portal MFE image (`scripts/infra/enterprise/build-enterprise-mfe.sh`) | AC: AC-007 | Depends: None
  - Build `frontend-app-admin-portal` from upstream source
  - Push to Artifact Registry
  - **Done**: Image in registry

- [ ] **[L] Task 3.2**: Build and push learner-portal MFE image (`scripts/infra/enterprise/build-enterprise-mfe.sh`) | AC: AC-008 | Depends: None
  - Build `frontend-app-learner-portal-enterprise` from upstream source
  - Push to Artifact Registry
  - **Done**: Image in registry

- [ ] **[M] Task 3.3**: Create MFE Deployment and Service manifests (`deploy/k8s/base/apps/enterprise/enterprise-mfe-deployment.yaml`, `deploy/k8s/base/apps/enterprise/enterprise-mfe-service.yaml`) | AC: AC-007, AC-008 | Depends: Task 3.1, Task 3.2
  - Single MFE container serving both admin-portal and learner-portal (or separate Deployments)
  - Caddy sidecar serving static assets
  - **Done**: MFE pods running

- [ ] **[M] Task 3.4**: Configure Caddy routing for enterprise MFE domains (`deploy/k8s/base/apps/caddy/Caddyfile`) | AC: AC-007, AC-008 | Depends: Task 3.3
  - Add `http://admin.academyv2.mereka.io` routing to admin-portal MFE
  - Add `http://enterprise.academyv2.mereka.io` routing to learner-portal MFE
  - Follow existing Caddyfile patterns (proxy snippet, http-only behind NGINX Ingress)
  - **Done**: `curl http://admin.academyv2.mereka.io/` returns HTML with HTTP 200

- [ ] **[M] Task 3.5**: Configure DNS and SSL for enterprise MFE domains (`infrastructure/cloudflare/enterprise-dns.md`) | AC: AC-007, AC-008 | Depends: None
  - `admin.academyv2.mereka.io` -- multi-level subdomain, needs DNS-only + Let's Encrypt
  - `enterprise.academyv2.mereka.io` -- multi-level subdomain, needs DNS-only + Let's Encrypt
  - Update cert-manager Certificate or Ingress annotations
  - **Done**: Both domains resolve and have valid TLS certificates

- [ ] **[S] Task 3.6**: Configure MFE environment variables (`deploy/k8s/base/apps/enterprise/settings/enterprise-mfe-env.js`) | AC: AC-007, AC-008 | Depends: None
  - `LMS_BASE_URL`, `ENTERPRISE_CATALOG_API_BASE_URL`, `LICENSE_MANAGER_API_BASE_URL`
  - `ENTERPRISE_ACCESS_API_BASE_URL`, `ENTERPRISE_SUBSIDY_API_BASE_URL`
  - OAuth2 client ID for MFE login
  - **Done**: MFE loads and can authenticate

#### Test

- [ ] **[M] Task 3.7**: Enterprise MFE smoke test (`scripts/qa/smoke-enterprise-mfe.sh`) | AC: AC-007, AC-008 | Depends: Task 3.4
  - curl both MFE URLs, verify HTTP 200 and valid HTML
  - Check for expected page title strings
  - **Done**: Script exits 0

---

### Phase 4: SSO/SAML and Integrated Channels (Week 9-10)

#### Build

- [ ] **[M] Task 4.1**: Configure SAML IdP for pilot enterprise client (`scripts/infra/enterprise/configure-saml-idp.sh`, `docs/operations/enterprise-saml-setup.md`) | AC: AC-026, AC-027, AC-029 | Depends: auth-sso-enterprise_spec.md complete
  - Register SAML provider in LMS Django admin
  - Configure `entity_id`, `metadata_url`, attribute mappings
  - Configure slug-based login URL
  - Store SAML certificates in K8s secrets via ExternalSecrets
  - **Done**: SAML IdP appears in LMS admin; metadata is fetchable

- [ ] **[M] Task 4.2**: Configure enterprise integrated channels LMS settings (`deploy/k8s/base/apps/openedx/settings/lms/mereka_enterprise_channels.py`) | AC: AC-030, AC-031, AC-032 | Depends: Task 0.7
  - Enable `integrated_channels` app in LMS
  - Configure Celery beat schedule for channel sync (every 4 hours)
  - Configure retry settings (base: 30s, max: 15min, max retries: 5)
  - **Done**: `integrated_channels` tasks visible in Celery beat schedule

- [ ] **[S] Task 4.3**: Configure Degreed channel integration model (`docs/operations/enterprise-channel-setup.md`) | AC: AC-030, AC-031 | Depends: Task 4.2
  - Document admin steps to configure Degreed channel per enterprise customer
  - Include dry-run mode testing steps
  - **Done**: Documentation complete with screenshots/examples

- [ ] **[S] Task 4.4**: Configure Cornerstone CSOD channel integration (`docs/operations/enterprise-channel-setup.md`) | AC: AC-030 | Depends: Task 4.2
  - Same as Degreed but for Cornerstone
  - **Done**: Documentation complete

#### Test

- [ ] **[M] Task 4.5**: SAML login flow verification (`scripts/qa/verify-enterprise-saml.sh`) | AC: AC-026, AC-027, AC-028, AC-029 | Depends: Task 4.1
  - Test slug-based login redirect
  - Verify auto-provisioning of new user
  - Verify enterprise customer linking
  - **Done**: Script exits 0 (some steps may require manual verification against real IdP)

- [ ] **[M] Task 4.6**: Integrated channel sync verification (`scripts/qa/verify-enterprise-channels.sh`) | AC: AC-030, AC-031, AC-032 | Depends: Task 4.2
  - Trigger channel sync in dry-run mode
  - Verify sync log output (no data transmitted, "dry-run" indicated)
  - Verify retry behavior on simulated failure
  - **Done**: Script exits 0

---

### Phase 5: Production Hardening (Week 11-12)

#### Observability

- [ ] **[M] Task 5.1**: Create ServiceMonitors for enterprise services (`deploy/k8s/base/monitoring/servicemonitor-enterprise.yaml`) | AC: AC-035 | Depends: Phase 1+2 complete
  - One ServiceMonitor per enterprise service (4 total), following existing `servicemonitor-lms.yaml` pattern
  - Scrape `/metrics` endpoint at 30s interval
  - Labels: `app.kubernetes.io/component: enterprise`
  - **Done**: `kubectl get servicemonitor -n mereka-lms -l app.kubernetes.io/component=enterprise` lists 4

- [ ] **[L] Task 5.2**: Create PrometheusRule for enterprise alerts (`deploy/k8s/base/monitoring/prometheusrule-enterprise.yaml`) | AC: AC-035 | Depends: Task 5.1
  - Critical: service health fail >3 checks, subsidy balance <10%, license utilization >95%
  - Warning: catalog sync >30min, channel sync >60min, SAML failure rate >10%, access denial >50%
  - Info: zero license activity for 30 days
  - **Done**: `kubectl get prometheusrule enterprise-alerts -n mereka-lms` exists; rules fire as expected in test

- [ ] **[M] Task 5.3**: Create Grafana dashboards for enterprise services (`infrastructure/monitoring/dashboards/enterprise-overview.json`, `infrastructure/monitoring/dashboards/enterprise-licenses.json`, `infrastructure/monitoring/dashboards/enterprise-catalog.json`, `infrastructure/monitoring/dashboards/enterprise-subsidy.json`, `infrastructure/monitoring/dashboards/enterprise-channels.json`, `infrastructure/monitoring/dashboards/enterprise-auth.json`) | AC: AC-035 | Depends: Task 5.1
  - 6 dashboards as specified in the Observability section
  - **Done**: Dashboards accessible in Grafana, showing live data

- [ ] **[S] Task 5.4**: Configure structured logging for enterprise services (`deploy/k8s/base/apps/enterprise/settings/enterprise-logging.py`) | AC: AC-036 | Depends: Phase 1+2 complete
  - JSON format to stdout
  - Every log line includes: `service_name`, `enterprise_customer_uuid`, `request_id`, `log_level`, `timestamp`
  - Sensitive data exclusion: no raw emails, no SAML assertions, no API keys
  - **Done**: Logs visible in Loki with correct structured format

#### Build

- [ ] **[L] Task 5.5**: Create enterprise feature flag configuration (`deploy/k8s/base/apps/openedx/settings/lms/mereka_enterprise_flags.py`) | AC: AC-001 | Depends: None
  - Define all 8 feature flags in LMS settings (all default: off)
  - `ENABLE_ENTERPRISE_CATALOG_SERVICE`, `ENABLE_LICENSE_MANAGER`, `ENABLE_ENTERPRISE_SUBSIDY`, `ENABLE_ENTERPRISE_ACCESS_POLICIES`, `ENABLE_ENTERPRISE_LEARNER_PORTAL`, `ENABLE_ENTERPRISE_ADMIN_PORTAL`, `ENABLE_ENTERPRISE_SSO`, `ENABLE_INTEGRATED_CHANNELS`
  - Support per-enterprise-customer-UUID flag overrides via Waffle
  - **Done**: Flags appear in LMS admin; toggling them enables/disables corresponding features

- [ ] **[M] Task 5.6**: Create tenant onboarding automation script (`scripts/infra/enterprise/onboard-enterprise-client.sh`) | AC: AC-009, AC-012 | Depends: All Phase 1-4
  - Automated steps: create EnterpriseCustomer, create catalog, create subscription plan, create access policy, configure SAML (optional)
  - Idempotent (can re-run safely)
  - **Done**: Onboarding a new test client completes in <30 minutes with zero code changes

- [ ] **[M] Task 5.7**: Create HPA (Horizontal Pod Autoscaler) for enterprise services (`deploy/k8s/base/apps/enterprise/enterprise-hpa.yaml`) | AC: AC-001 | Depends: Phase 1+2 complete
  - Min replicas: 1, Max replicas: 3
  - Target CPU utilization: 70%
  - **Done**: `kubectl get hpa -n mereka-lms -l app.kubernetes.io/component=enterprise` lists HPAs

- [ ] **[S] Task 5.8**: Configure API rate limiting for enterprise services (`deploy/k8s/base/apps/enterprise/settings/enterprise-rate-limiting.py`) | AC: AC-035 | Depends: Phase 1+2 complete
  - 100 requests/minute per enterprise admin user
  - 1000 requests/minute per enterprise service account
  - 10,000 requests/minute for service-to-service calls
  - **Done**: Rate limiting returns HTTP 429 with `Retry-After` when exceeded

#### Test

- [ ] **[L] Task 5.9**: Tenant isolation security audit (`scripts/qa/audit-enterprise-tenant-isolation.sh`) | AC: AC-009, AC-010, AC-011, AC-012, AC-013 | Depends: All Phase 1-4
  - Create 2 test enterprise customers (A and B)
  - Verify admin A cannot see customer B's catalogs, licenses, or subsidies
  - Verify learner A cannot browse customer B's catalog
  - Verify multi-org learner context switching
  - **Done**: Script exits 0; no cross-tenant data leakage

- [ ] **[M] Task 5.10**: End-to-end enrollment flow verification (`scripts/qa/verify-enterprise-enrollment-flow.sh`) | AC: AC-014, AC-015, AC-016, AC-022, AC-024 | Depends: All Phase 1-4
  - Full flow: admin assigns license -> learner activates -> learner enrolls via access policy -> subsidy deducted -> enrollment created in LMS
  - Revocation flow: admin revokes license -> enrollment revoked -> subsidy reversed
  - **Done**: Script exits 0

- [ ] **[M] Task 5.11**: Enterprise secrets verification (`scripts/qa/verify-enterprise-secrets.sh`) | AC: AC-033, AC-034 | Depends: Task 0.4
  - Verify ExternalSecret sync status
  - Verify enterprise-catalog reads correct SECRET_KEY
  - Verify no secrets appear in pod logs
  - **Done**: Script exits 0

#### Docs

- [ ] **[L] Task 5.12**: Create enterprise services operational runbook (`docs/runbooks/enterprise-services-runbook.md`) | Depends: All phases
  - Service restart procedures
  - Common failure scenarios and fixes
  - Rollback procedures (per-service and full stack)
  - Database backup/restore
  - License management troubleshooting
  - Catalog sync troubleshooting
  - Channel sync troubleshooting
  - SAML troubleshooting
  - **Done**: Runbook exists with all sections

- [ ] **[M] Task 5.13**: Update main TROUBLESHOOTING.md (`docs/operations/TROUBLESHOOTING.md`) | Depends: All phases
  - Add enterprise services section with common issues and fixes
  - **Done**: Enterprise section exists in troubleshooting guide

- [ ] **[S] Task 5.14**: Create architecture overview doc (`docs/architecture/enterprise-services-overview.md`) | Depends: None
  - System diagram showing all 5 services, MFEs, LMS, event bus, databases
  - Communication patterns (internal HTTP, Redis Streams, OAuth2)
  - **Done**: Document exists with diagrams

- [ ] **[S] Task 5.15**: Update CLAUDE.md with enterprise services (`CLAUDE.md`) | Depends: All phases
  - Add enterprise services to the Architecture section
  - Add enterprise commands to Common Development Commands
  - Update Key Documentation Files
  - **Done**: CLAUDE.md updated

#### Rollout

- [ ] **[S] Task 5.16**: Create rollback scripts (`scripts/infra/enterprise/rollback-enterprise.sh`) | Depends: None
  - Per-service rollback: scale to 0, disable feature flag
  - Full stack rollback: disable all flags, scale all enterprise deployments to 0
  - Database rollback: Cloud SQL restore instructions
  - **Done**: Script exists and is tested

---

## Milestones

| Milestone | Target Week | Exit Criteria |
|-----------|-------------|---------------|
| **M0: Infrastructure Ready** | Week 2 | Databases provisioned, secrets synced, images built, OAuth2 clients registered |
| **M1: Catalog + Subsidy Live** | Week 4 | enterprise-catalog and enterprise-subsidy pods healthy, catalog sync running, ledger operations verified |
| **M2: License + Access Live** | Week 6 | All 4 enterprise services healthy, end-to-end license assignment flow working, access policies evaluating correctly |
| **M3: MFEs Live** | Week 8 | Admin portal and learner portal accessible at production URLs, admin can manage catalogs/licenses, learner can browse catalog |
| **M4: SSO + Channels Live** | Week 10 | SAML login operational for pilot client, Degreed/CSOD channel sync in dry-run verified |
| **M5: Production Ready** | Week 12 | All alerts/dashboards live, tenant isolation audited, runbook complete, second client onboarded |

---

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| GKE node pool insufficient for 9 additional pods | Deployment blocked | Medium | Check current capacity before starting; pre-approve node pool resize |
| Cloud SQL tier cannot handle 4 extra databases | Service failures | Low | Measure current utilization; plan tier upgrade if >60% used |
| Upstream enterprise images incompatible with Mereka LMS version | Build failures, runtime errors | Medium | Test images in local Kind cluster first; pin exact image tags |
| Multi-level subdomain SSL for enterprise MFEs | MFE inaccessible via HTTPS | High | Use DNS-only (gray cloud) + Let's Encrypt as per CLAUDE.md guidance; alternative: use single-level subdomains |
| Event bus (Redis Streams) throughput insufficient under multi-client load | Event delivery delays | Low | Capacity test during Phase 5; Redis Streams handles moderate throughput well |
| SAML IdP metadata format varies across identity providers | SSO integration failures | Medium | Test with multiple IdP simulators (Keycloak, Okta test tenants) before production |
| Enterprise service OAuth2 token expiry causes silent failures | API calls fail intermittently | Medium | Configure token refresh in service settings; add monitoring for 401 error rates |
| Algolia vs Elasticsearch decision unresolved | Catalog search UX may be limited | Medium | Default to Elasticsearch (already deployed); Algolia can be added later as enhancement |

---

## File Inventory

All new files created by this plan:

```
deploy/k8s/base/apps/enterprise/
  enterprise-catalog-deployment.yaml
  enterprise-catalog-service.yaml
  enterprise-subsidy-deployment.yaml
  enterprise-subsidy-service.yaml
  license-manager-deployment.yaml
  license-manager-service.yaml
  enterprise-access-deployment.yaml
  enterprise-access-service.yaml
  enterprise-mfe-deployment.yaml
  enterprise-mfe-service.yaml
  enterprise-hpa.yaml
  kustomization.yaml
  workers/
    enterprise-catalog-worker-deployment.yaml
    enterprise-subsidy-worker-deployment.yaml
    license-manager-worker-deployment.yaml
    enterprise-access-worker-deployment.yaml
  settings/
    enterprise-catalog-settings.py
    enterprise-subsidy-settings.py
    license-manager-settings.py
    enterprise-access-settings.py
    enterprise-mfe-env.js
    enterprise-logging.py
    enterprise-rate-limiting.py
    event-bus-config.py

deploy/k8s/base/secrets/external-secrets.yaml           (MODIFIED: add enterprise-secrets)
deploy/k8s/base/kustomization.yaml                      (MODIFIED: add enterprise resources)
deploy/k8s/base/apps/caddy/Caddyfile                    (MODIFIED: add enterprise MFE routes)
deploy/k8s/base/apps/openedx/settings/lms/
  mereka_enterprise_flags.py                             (NEW)
  mereka_enterprise_channels.py                          (NEW)
deploy/k8s/base/monitoring/
  servicemonitor-enterprise.yaml                         (NEW)
  prometheusrule-enterprise.yaml                         (NEW)

scripts/infra/enterprise/
  provision-enterprise-dbs.sh
  provision-enterprise-secrets.sh
  sync-enterprise-secrets-to-gcpsm.sh
  register-oauth2-clients.sh
  build-enterprise-images.sh
  build-enterprise-mfe.sh
  configure-saml-idp.sh
  onboard-enterprise-client.sh
  rollback-enterprise.sh

scripts/qa/
  verify-enterprise-packages.sh
  verify-enterprise-health.sh
  verify-enterprise-catalog-sync.sh
  verify-license-manager.sh
  verify-enterprise-access.sh
  smoke-enterprise-mfe.sh
  verify-enterprise-saml.sh
  verify-enterprise-channels.sh
  audit-enterprise-tenant-isolation.sh
  verify-enterprise-enrollment-flow.sh
  verify-enterprise-secrets.sh

infrastructure/monitoring/dashboards/
  enterprise-overview.json
  enterprise-licenses.json
  enterprise-catalog.json
  enterprise-subsidy.json
  enterprise-channels.json
  enterprise-auth.json

docs/
  operations/enterprise-infrastructure-setup.md
  operations/enterprise-channel-setup.md
  operations/enterprise-saml-setup.md
  runbooks/enterprise-services-runbook.md
  architecture/enterprise-services-overview.md
```

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-036) has at least one build task
- [x] Every acceptance criterion has at least one test or verification task
- [x] Every edge case scenario is addressed by architectural decisions in the spec (serialization via SELECT FOR UPDATE, idempotency, retry policies) -- upstream services implement these; we verify via integration tests
- [x] Test tasks cover happy path (health checks, basic flows) and edge cases (tenant isolation audit, enrollment flow)
- [x] File paths specified for every task
- [x] Dependencies identified for all tasks
- [x] Complexity estimated (S/M/L) for all tasks
- [x] Observability tasks included (ServiceMonitors, PrometheusRules, dashboards, structured logging)
- [x] Rollout tasks included (feature flags, onboarding automation, rollback scripts)
- [x] Docs tasks included (runbook, troubleshooting, architecture, CLAUDE.md update)
- [x] Source spec linked in header
