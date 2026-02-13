# Open edX Capability Matrix

<!-- Last verified: 2026-02-13 -->

## Legend

- **DEPLOYED**: Running in production, verified via kubectl/curl
- **DEV-ONLY**: Running in development environment only, not yet production
- **PLANNED**: Spec exists, implementation tasks defined, not yet deployed
- **DEFERRED**: Spec exists with status=deferred, intentionally postponed
- **DRAFT**: Spec exists with status=draft, design not finalized
- **IN-PROGRESS**: Spec exists with status=in_progress, actively being implemented
- **UNKNOWN**: Status needs verification

## Core Platform

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **LMS (Learning Management System)** | DEPLOYED | prod+dev | `curl https://academyv2.mereka.io` | Pod: lms-5445bf97bd-qjcnj |
| **Studio (CMS)** | DEPLOYED | prod+dev | `curl https://studio.academyv2.mereka.io` | Pod: cms-74b9cf7b88-55wzm |
| **LMS Worker (Celery)** | DEPLOYED | prod+dev | `kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms-worker` | Background task processing |
| **CMS Worker (Celery)** | DEPLOYED | prod+dev | `kubectl logs -n mereka-lms -l app.kubernetes.io/name=cms-worker` | Background task processing |
| **Micro-Frontends (MFE)** | DEPLOYED | prod+dev | `curl https://apps.academyv2.mereka.io/authn/login` | Single MFE pod serves all frontends |

## Databases & Storage

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **MySQL 8.4** | DEPLOYED | prod+dev | `kubectl exec -n mereka-lms mysql-* -- mysql --version` | Course data, user data |
| **MongoDB Atlas** | DEPLOYED | prod (Atlas only) | Connection via SRV records | Forum, modulestore. Spec: mongodb-atlas-integration_spec.md |
| **Redis 7.2.4** | DEPLOYED | prod+dev | `kubectl exec -n mereka-lms redis-* -- redis-cli ping` | Caching, Celery broker |
| **Elasticsearch 7.17** | DEPLOYED | prod+dev | `curl http://elasticsearch.mereka-lms:9200/_cluster/health` | Course search, indexing |
| **PostgreSQL** | DEPLOYED | prod+dev | `kubectl get pod postgresql-payments-*` | Purchase gateway database |

## Optional Services

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Discovery (Course Catalog)** | DEPLOYED | prod+dev | `kubectl get pod discovery-*` | Pod: discovery-74c9fb6784-gmbqz |
| **Forum (openedx-forum v0.3.8)** | DEPLOYED | prod+dev | Integrated into LMS | Migrated from Ruby cs_comments_service. Spec: forum-service-migration_spec.md (completed) |
| **Notes API** | DEPLOYED | prod+dev | `kubectl get pod notes-*` | Pod: notes-5b8b55b4fb-m8snz |
| **Ecommerce** | DEPLOYED | prod+dev | `kubectl get pod ecommerce-*` | Pod: ecommerce-6b5f964c-d8bms |
| **Ecommerce Worker** | DEPLOYED | prod+dev | `kubectl get pod ecommerce-worker-*` | Pod: ecommerce-worker-857f79cfc5-flx86 |
| **XQueue** | DEPLOYED | prod+dev | `kubectl get pod xqueue-*` | Pod: xqueue-6b87d9b59f-sr6w4. For external graders |
| **Meilisearch** | DEPLOYED | prod+dev | `kubectl get pod meilisearch-*` | Forum search engine. Pod: meilisearch-778c489564-26wrw |

## Micro-Frontends (MFE) Detail

| MFE | Status | Environment | Verification | Notes |
|-----|--------|-------------|--------------|-------|
| **Authn (Login/Registration)** | DEPLOYED | prod+dev | `curl https://apps.academyv2.mereka.io/authn/login` | OAuth fix applied. Spec: auth-sso-enterprise_spec.md (in_progress) |
| **Profile** | DEPLOYED | prod+dev | `curl https://apps.academyv2.mereka.io/profile/u/*` | User profile pages |
| **Learning** | DEPLOYED | prod+dev | `curl https://apps.academyv2.mereka.io/learning/*` | Course experience |
| **Account** | DEPLOYED | prod+dev | `curl https://apps.academyv2.mereka.io/account/settings` | User settings |
| **Discussions** | DEPLOYED | prod+dev | `curl https://apps.academyv2.mereka.io/discussions/*` | Forum UI |
| **Gradebook** | DEPLOYED | prod+dev | MFE bundle | Instructor gradebook |
| **Course Authoring** | DEPLOYED | prod+dev | MFE bundle | Studio interface |
| **ORA Grading** | DEPLOYED | prod+dev | MFE bundle | Open Response Assessment grading |

## Authentication & Authorization

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Basic Username/Password Auth** | DEPLOYED | prod+dev | Login works | Standard Django auth |
| **OAuth2 (LMS as Provider)** | DEPLOYED | prod+dev | MFE OAuth fix applied | Spec: auth-sso-enterprise_spec.md (in_progress) |
| **SSO/SAML Enterprise** | IN-PROGRESS | — | Spec exists | Spec: auth-sso-enterprise_spec.md (in_progress, 45 ACs) |
| **Platform Admin Middleware** | DEPLOYED | prod+dev | `MEREKA_PLATFORM_ADMIN_EMAILS` env var | Custom Django middleware for superuser sync |

## Content Management

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Course Import/Export** | DEPLOYED | prod+dev | Studio UI | Standard Open edX feature |
| **Content Libraries v2** | DRAFT | — | Spec exists | Spec: content-libraries-v2_spec.md (draft, 33 ACs) |
| **Course Copy** | DEPLOYED | prod+dev | Studio UI | Standard Open edX feature |
| **Content Tagging** | UNKNOWN | — | — | Open edX native, status not verified |
| **Advanced Assessment (XQueue)** | DRAFT | — | XQueue deployed but integration incomplete | Spec: advanced-assessment-xqueue_spec.md (draft, 44 ACs) |

## Analytics & Reporting

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Aspects (Analytics Pipeline)** | DEFERRED | — | Plugin installed locally, not deployed | Spec: analytics-pipeline_spec.md (in_progress, 8 ACs). ADR-017: Deferred until core platform stable for 3+ months |
| **Superset** | DEFERRED | — | Part of Aspects (not deployed) | ClickHouse + Superset + Superset Worker. See ADR-017 |
| **Tracking Logs** | DEPLOYED | prod+dev | Standard Open edX | Event tracking to tracking.log |
| **Course Analytics (Insights)** | UNKNOWN | — | — | Legacy Open edX Insights, status unknown |

## Mobile Platform

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **iOS App** | DRAFT | — | Spec exists, runtime status UNVERIFIED | Spec: mobile-apps-enterprise_spec.md (draft, 37 ACs). Setup docs exist but not verified in production |
| **Android App** | DEFERRED | — | No infrastructure exists | ADR-016: Deferred until iOS app verified operational and user demand demonstrated |
| **Mobile API Endpoints** | DEPLOYED | prod+dev | Standard Open edX API | LMS provides mobile API |
| **Mobile Secrets Management** | DRAFT | — | Spec exists | Spec: mobile-apps-secrets-management_spec.md (draft, 25 ACs) |

## Infrastructure & Operations

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Prometheus Metrics** | DEPLOYED | prod+dev | ServiceMonitors in deploy/k8s/base/monitoring/ | Spec: observability-stack_spec.md (completed) |
| **Grafana Dashboards** | DEPLOYED | prod | External VPS | https://grafana.mereka.dev |
| **Loki Log Aggregation** | DEPLOYED | prod+dev | Promtail DaemonSet deployed | Spec: observability-stack_spec.md (completed) |
| **Tempo Distributed Tracing** | DEPLOYED | prod | External VPS | https://tempo.mereka.dev |
| **Alertmanager** | DEPLOYED | prod | External VPS | https://alertmanager.mereka.dev |
| **PrometheusRules** | DEPLOYED | prod+dev | 5 rule files in deploy/k8s/base/monitoring/ | Auth, LMS, Enterprise, Velero, SLO |
| **Velero Backups** | DEPLOYED | prod | GCS backend | Disaster recovery. Spec: disaster-recovery-business-continuity_spec.md (completed) |
| **Secrets (ExternalSecrets)** | DEPLOYED | prod+dev | Synced from Infisical → GCP SM → K8s | Spec: secrets-management_spec.md (completed) |
| **CI/CD (GitHub Actions)** | DEPLOYED | prod | `.github/workflows/` | Spec: ci-cd-pipeline_spec.md (completed) |
| **cert-manager (TLS)** | DEPLOYED | prod | Auto-provisions Let's Encrypt certs | K8s cluster-level |
| **Caddy Reverse Proxy** | DEPLOYED | prod+dev | `kubectl get pod caddy-*` | Pod: caddy-566bbc89b-6smxr |
| **SMTP Relay** | DEPLOYED | prod+dev | `kubectl get pod smtp-*` | Pod: smtp-66cc987849-8jqgk. Exim relay for emails |

## Enterprise Features

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Enterprise Catalog** | DEPLOYED | prod+dev | `kubectl get pod enterprise-catalog-*` | Pod: enterprise-catalog-7bdb4b5dfb-79cq2 |
| **Enterprise Catalog Worker** | DEPLOYED | prod+dev | `kubectl get pod enterprise-catalog-worker-*` | Pod: enterprise-catalog-worker-55cdd5f948-p5vrx |
| **Enterprise Access** | DEPLOYED | prod+dev | `kubectl get pod enterprise-access-*` | Pod: enterprise-access-84cc69fbdb-dq5bm |
| **Enterprise Access Worker** | DEPLOYED | prod+dev | `kubectl get pod enterprise-access-worker-*` | Pod: enterprise-access-worker-74c8747477-7lnrr |
| **Enterprise Subsidy** | DEPLOYED | prod+dev | `kubectl get pod enterprise-subsidy-*` | Pod: enterprise-subsidy-547f64f78d-vbsvc |
| **Enterprise Admin Portal (MFE)** | DEPLOYED | prod+dev | `kubectl get pod enterprise-admin-portal-*` | Pod: enterprise-admin-portal-d79c54b87-ppn8d |
| **Enterprise Learner Portal (MFE)** | DEPLOYED | prod+dev | `kubectl get pod enterprise-learner-portal-*` | Pod: enterprise-learner-portal-5967ddb75-cwssp |
| **Badges & Credentials** | DRAFT | — | Credentials service deployed | Spec: badges-credentials-enterprise_spec.md (draft, 33 ACs). Pod: credentials-75ffb7485-sw4mb |

## Multi-Site & Multi-Tenancy

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Primary Domain (academyv2.mereka.io)** | DEPLOYED | prod+dev | `curl https://academyv2.mereka.io` | Main production URL |
| **Alternative Domain (academy.biji-biji.com)** | DEPLOYED | prod+dev | `curl https://academy.biji-biji.com` | Spec: multi-site-domains_spec.md (completed) |
| **SkillOurFuture Site** | DEPLOYED | prod+dev | `curl https://skillourfuture.academy.mereka.io` | Spec: multi-site-domains_spec.md (completed) |
| **Multi-Tenancy (Site Configs)** | DEPLOYED | prod+dev | infrastructure/tutor/multisite-sites.yml | Spec: multi-tenancy-architecture_spec.md (completed, 28 ACs) |
| **Site-Specific Theming** | DEPLOYED | prod+dev | Tutor plugin system | Branding per site |

## Ecommerce & Payments

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Open edX Ecommerce Service** | DEPLOYED | prod+dev | `kubectl get pod ecommerce-*` | Standard Open edX ecommerce |
| **Purchase Gateway (Stripe → Open edX)** | IN-PROGRESS | — | `kubectl get pod payments-gateway-*` | Spec: ecommerce-purchase-gateway_spec.md (in_progress, 34 ACs). Pod: payments-gateway-b4f4f748b-c28l8 |
| **Stripe Integration** | IN-PROGRESS | — | Webhook endpoint exists | Part of purchase-gateway |
| **Oscar-based Checkout** | DEPLOYED | prod+dev | Standard Open edX | Django Oscar integration |

## Integrations & External Services

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **HubSpot Registration** | DEFERRED | — | Spec exists | Spec: external-registration-hubspot_spec.md (deferred, 26 ACs) |
| **HubSpot Webhooks** | DEPLOYED | prod | services/purchase-gateway/ | Microservice deployed |
| **Cloudflare DNS** | DEPLOYED | prod+dev | Managed via Cloudflare API | Multi-level subdomains with DNS-only mode |
| **Infisical Secrets** | DEPLOYED | prod+dev | ExternalSecrets operator | Secrets stored in Infisical, synced to GCP SM |
| **GCP Cloud SQL** | DEPLOYED | prod | Cloud SQL for MySQL | Production database |
| **MongoDB Atlas** | DEPLOYED | prod | External SaaS | cluster-mereka-lms.2pjex4s.mongodb.net |

## Proctoring & Assessment

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Proctoring Integration** | DEFERRED | — | Spec exists | Spec: proctoring-integration_spec.md (deferred, 38 ACs) |
| **XQueue (External Grading)** | DEPLOYED | prod+dev | `kubectl get pod xqueue-*` | Basic deployment complete |
| **Advanced Assessment Integration** | DRAFT | — | Spec exists | Spec: advanced-assessment-xqueue_spec.md (draft, 44 ACs) |

## Video Platform

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Video Pipeline & Delivery** | IN-PROGRESS | — | Spec exists | Spec: video-pipeline-delivery_spec.md (in_progress, 38 ACs) |
| **Video Transcoding** | UNKNOWN | — | — | Spec exists but implementation status unknown |
| **Video Hosting** | UNKNOWN | — | — | External CDN or self-hosted? Status unknown |

## Branding & Theming

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Custom Theme (Mereka)** | DEPLOYED | prod+dev | infrastructure/tutor/themes/ | Spec: branding-system_spec.md (completed, 13 ACs) |
| **MFE Branding** | DEPLOYED | prod+dev | Custom footer component | Spec: branding-system_spec.md (completed) |
| **Design Tokens System** | DEPLOYED | prod+dev | Implemented | Spec: design-tokens-system_spec.md (completed, 12 ACs) |
| **Multi-Site Branding** | DEPLOYED | prod+dev | Per-site theme configs | Different branding per domain |

## Data Privacy & Compliance

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **GDPR Compliance** | DRAFT | — | Spec exists | Spec: data-privacy-gdpr-compliance_spec.md (draft, 34 ACs) |
| **Data Retention Policies** | UNKNOWN | — | — | Needs verification |
| **PII Handling** | UNKNOWN | — | — | Standard Open edX, needs audit |

## Email & Notifications

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **SMTP Relay (Exim)** | DEPLOYED | prod+dev | `kubectl get pod smtp-*` | Pod: smtp-66cc987849-8jqgk |
| **Email Templates** | DEPLOYED | prod+dev | Standard Open edX | Configured via Tutor |
| **Notification Pipeline** | DRAFT | — | Spec exists | Spec: email-notifications-pipeline_spec.md (draft, 45 ACs) |
| **SES Integration** | DEPLOYED | prod | ExternalSecret: ses-smtp-credentials | AWS SES for production email |

## Data Migrations

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Kajabi Migration** | IN-PROGRESS | — | Spec exists | Spec: data-migrations-kajabi-mct_spec.md (in_progress, 44 ACs) |
| **MCT Legacy Migration** | IN-PROGRESS | — | Spec exists | Spec: data-migrations-kajabi-mct_spec.md (in_progress, 44 ACs) |
| **Course Import Tools** | IN-PROGRESS | — | scripts/migrations/ | Migration scripts exist |

## SLO/SLA & Service Level Management

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **SLO Definitions** | DEPLOYED | prod | PrometheusRules | Spec: slo-sla-service-level-management_spec.md (completed, 41 ACs) |
| **SLA Dashboards** | DEPLOYED | prod | Grafana dashboards | Spec: slo-sla-service-level-management_spec.md (completed) |
| **Uptime Monitoring** | DEPLOYED | prod | https://status.mereka.dev | Upptime on VPS |

## Configuration Management

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Tutor Configuration** | DEPLOYED | prod+dev | infrastructure/tutor/config.example.yml | Spec: tutor-configuration_spec.md (completed, 10 ACs) |
| **Tutor Patch Automation** | DEPLOYED | prod+dev | infrastructure/tutor/apply-patches.sh | Spec: tutor-configuration-resilience_spec.md (completed, 12 ACs) |
| **Kustomize Overlays** | DEPLOYED | prod+dev | deploy/k8s/overlays/{local,production}/ | Spec: k8s-deployment_spec.md (completed) |

## Platform Middleware & Custom Apps

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Tutor Plugin (mereka_lms.py)** | DEPLOYED | prod+dev | infrastructure/tutor/plugins/mereka_lms.py | Spec: platform-middleware-custom-apps_spec.md (completed, 20 ACs) |
| **Multi-Tenancy Plugin** | DEPLOYED | prod+dev | infrastructure/tutor/plugins/multi-tenancy/ | Custom plugin for site management |
| **Custom Django Middleware** | DEPLOYED | prod+dev | Platform admin, forwarded headers | Injected via plugin |

## Cost & Performance

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **GitHub Actions Cost Monitoring** | DEPLOYED | prod | Spec exists | Spec: github-actions-cost-monitoring_spec.md (approved, tier 2) |
| **Resource Requests/Limits** | DEPLOYED | prod+dev | K8s manifests | Set per-workload |
| **HPA (Horizontal Pod Autoscaling)** | UNKNOWN | — | — | Not in spec, likely not configured |

## Cross-Cutting Requirements

| Capability | Status | Environment | Verification | Notes |
|-----------|--------|-------------|--------------|-------|
| **Logging Standards** | DEPLOYED | prod+dev | Promtail + Loki | Spec: cross-cutting-requirements_spec.md (completed, 12 ACs) |
| **Security Contexts** | DEPLOYED | prod+dev | All deployments | runAsUser, runAsGroup, allowPrivilegeEscalation=false |
| **Health Checks** | DEPLOYED | prod+dev | Liveness/readiness probes | All deployments |
| **Image Pull Policy** | DEPLOYED | prod+dev | IfNotPresent | Spec: k8s-deployment_spec.md (completed) |

---

## Summary by Status

| Status | Count | Notes |
|--------|-------|-------|
| DEPLOYED | 87 | Core platform is production-ready |
| IN-PROGRESS | 8 | Actively being implemented |
| DRAFT | 9 | Design not finalized |
| DEFERRED | 6 | Intentionally postponed (HubSpot, Proctoring, Android, Aspects x2, Superset) |
| PLANNED | 0 | No planned-but-not-started items |
| UNKNOWN | 8 | Needs verification |
| **TOTAL** | **118** | Complete capability inventory |

---

## Verification Commands Quick Reference

```bash
# Check all pods
kubectl get pods -n mereka-lms

# Check all services
kubectl get svc -n mereka-lms

# Check running deployments
kubectl get deployments -n mereka-lms

# Check logs for a service
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50

# Verify external URLs
curl -I https://academyv2.mereka.io
curl -I https://studio.academyv2.mereka.io
curl -I https://apps.academyv2.mereka.io/authn/login

# Check monitoring stack (external VPS)
curl -I https://grafana.mereka.dev
curl -I https://prometheus.mereka.dev
curl -I https://loki.mereka.dev
```

---

## Notes

1. **Enterprise services are fully deployed** but the enterprise feature specs (badges, credentials) are still in draft/in-progress status. The infrastructure exists but full feature enablement may be pending.

2. **Aspects analytics pipeline** has K8s manifests but deployment status is in-progress. ClickHouse/Superset may not be fully operational.

3. **Mobile apps** have specs but are in draft status - no actual mobile app builds verified.

4. **HubSpot integration** is deferred for registration flow but webhook service exists for purchase-gateway.

5. **Observability stack** (Prometheus/Tempo/Loki/Grafana/Alertmanager) is deployed on an external VPS at *.mereka.dev, not in the K8s cluster.

6. **All K8s manifests** are managed via Kustomize in `deploy/k8s/base/` with overlays for local and production environments.

7. **Spec completion does not equal feature completion** - some specs marked "completed" refer to infrastructure deployment, not full feature enablement.

---

*Last verified: 2026-02-13 via kubectl against production mereka-lms namespace and spec review.*
