# Resource Ownership Matrix — deploy/k8s/

**Generated:** 2026-03-06
**Maintainer:** Platform Engineering
**Related:** `docs/concepts/architecture/DEPLOYMENT_BOUNDARY.md`

This table classifies every file under `deploy/k8s/`. "Rendered By" lists which kustomization.yaml
entry points include this file (directly or via a sub-kustomization). Files marked NOT RENDERED are
not included by any kustomization and require action.

## Classification Key

| Code | Meaning |
|---|---|
| APP_RUNTIME | App workload, Service, PVC, app-local NetworkPolicy, app-local PDB/HPA, app ConfigMap/settings |
| APP_RELEASE | Migrations, bootstrap jobs, release hooks, recurring sync CronJobs |
| APP_LOCAL_ONLY | Local developer support only; never promoted to prod environments |
| PLATFORM_SHARED | Cluster RBAC, logging, ARC, Kyverno policies, ClusterSecretStore, ArgoCD config |
| ENVIRONMENT_SPECIFIC | Domain-specific ingresses, provider-specific patches, image digest overlays |
| DEAD_REFERENCE | Not rendered, placeholder, obsolete, or contradictory |

## Action Key

| Code | Meaning |
|---|---|
| KEEP | Stays in app repo; no changes needed |
| KEEP_DOCUMENT | Stays but needs status comment or README update |
| MOVE_INFRA | Move to infrastructure (cluster management repo) |
| QUARANTINE | Move to `_quarantine/` pending decision or migration |
| DELETE | Remove after confirming no live dependency |
| ASSESS | Requires decision before acting |

---

## Kustomization Entry Points and Render Trees

| Entry Point | Overlays It Serves |
|---|---|
| `base/kustomization.yaml` | All overlays via `../../base` |
| `overlays/local/kustomization.yaml` | Kind/local developer cluster |
| `overlays/production/kustomization.yaml` | GKE production (currently frozen/scaled-to-zero) |
| `overlays/rke2-nonprod/kustomization.yaml` | RKE2 dev cluster (active development target) |
| `overlays/staging/kustomization.yaml` | Staging on RKE2 (shares cluster with nonprod) |
| `base/arc/kustomization.yaml` | Applied SEPARATELY; NOT included in any overlay |
| `base/plugins/aspects/kustomization.yaml` | Included by production, rke2-nonprod, staging |

---

## Full File Inventory

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `deploy/k8s/README.md` | — | NOT RENDERED | KEEP | Repo documentation |
| `deploy/k8s/overlays/README.md` | — | NOT RENDERED | KEEP | Overlay documentation |
| `deploy/k8s/patches/README.md` | — | NOT RENDERED | KEEP | Patches documentation |

### base/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/kustomization.yaml` | APP_RUNTIME | self (entry point) | KEEP | Root base kustomization |
| `base/namespace.yml` | APP_RUNTIME | base | KEEP | mereka-lms Namespace |
| `base/deployments.yml` | APP_RUNTIME | base | KEEP | Caddy, LMS, CMS, workers, discovery, notes, smtp, meilisearch, mysql, xqueue deployments |
| `base/services.yml` | APP_RUNTIME | base | KEEP | All ClusterIP Services |
| `base/volumes.yml` | APP_RUNTIME | base | KEEP | PVCs for caddy-data, mysql, meilisearch, smtp-data |

### base/apps/caddy/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/apps/caddy/Caddyfile` | APP_RUNTIME | base (configMapGenerator) | KEEP | Caddy reverse proxy config; generates caddy-config ConfigMap |

### base/apps/cms/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/apps/cms/kustomization.yaml` | APP_RUNTIME | base | KEEP | CMS kustomization |
| `base/apps/cms/hpa.yaml` | APP_RUNTIME | base → apps/cms | KEEP | CMS HPA |

### base/apps/enterprise/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/apps/enterprise/kustomization.yaml` | APP_RUNTIME | base | KEEP | Enterprise kustomization; includes services, workers, mfe |
| `base/apps/enterprise/enterprise-access-deployment.yaml` | APP_RUNTIME | base → apps/enterprise | KEEP | Enterprise Access Deployment |
| `base/apps/enterprise/enterprise-access-service.yaml` | APP_RUNTIME | base → apps/enterprise | KEEP | Enterprise Access Service |
| `base/apps/enterprise/enterprise-catalog-deployment.yaml` | APP_RUNTIME | base → apps/enterprise | KEEP | Enterprise Catalog Deployment |
| `base/apps/enterprise/enterprise-catalog-service.yaml` | APP_RUNTIME | base → apps/enterprise | KEEP | Enterprise Catalog Service |
| `base/apps/enterprise/enterprise-subsidy-deployment.yaml` | APP_RUNTIME | base → apps/enterprise | KEEP | Enterprise Subsidy Deployment |
| `base/apps/enterprise/enterprise-subsidy-service.yaml` | APP_RUNTIME | base → apps/enterprise | KEEP | Enterprise Subsidy Service |
| `base/apps/enterprise/license-manager-deployment.yaml` | APP_RUNTIME | base → apps/enterprise | KEEP | License Manager Deployment |
| `base/apps/enterprise/license-manager-service.yaml` | APP_RUNTIME | base → apps/enterprise | KEEP | License Manager Service |
| `base/apps/enterprise/settings/enterprise-access-config.yml` | APP_RUNTIME | base (configMapGenerator enterprise-access-settings) | KEEP | Enterprise Access YAML config |
| `base/apps/enterprise/settings/enterprise-access-settings.py` | APP_RUNTIME | base (configMapGenerator enterprise-access-settings) | KEEP | Enterprise Access Django settings |
| `base/apps/enterprise/workers/enterprise-access-worker-deployment.yaml` | APP_RUNTIME | base → apps/enterprise | KEEP | Enterprise Access Celery worker |
| `base/apps/enterprise/workers/enterprise-catalog-worker-deployment.yaml` | APP_RUNTIME | base → apps/enterprise | KEEP | Enterprise Catalog Celery worker |

### base/apps/enterprise/mfe/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/apps/enterprise/mfe/kustomization.yaml` | APP_RUNTIME | base → apps/enterprise → mfe | KEEP | Enterprise MFE sub-kustomization |
| `base/apps/enterprise/mfe/admin-portal-deployment.yaml` | APP_RUNTIME | base → apps/enterprise → mfe | KEEP | Admin portal MFE Deployment |
| `base/apps/enterprise/mfe/admin-portal-service.yaml` | APP_RUNTIME | base → apps/enterprise → mfe | KEEP | Admin portal MFE Service |
| `base/apps/enterprise/mfe/learner-portal-deployment.yaml` | APP_RUNTIME | base → apps/enterprise → mfe | KEEP | Learner portal MFE Deployment |
| `base/apps/enterprise/mfe/learner-portal-service.yaml` | APP_RUNTIME | base → apps/enterprise → mfe | KEEP | Learner portal MFE Service |
| `base/apps/enterprise/mfe/admin-portal-Caddyfile` | APP_RUNTIME | base → apps/enterprise → mfe (configMapGenerator) | KEEP | Admin portal Caddy config |
| `base/apps/enterprise/mfe/learner-portal-Caddyfile` | APP_RUNTIME | base → apps/enterprise → mfe (configMapGenerator) | KEEP | Learner portal Caddy config |
| `base/apps/enterprise/mfe/enterprise-mfe-env.js` | APP_RUNTIME | base → apps/enterprise → mfe (configMapGenerator) | KEEP | Default tenant MFE env config |
| `base/apps/enterprise/mfe/biji-biji-mfe-env.js` | APP_RUNTIME | NOT RENDERED directly | KEEP_DOCUMENT | Reference only; per-tenant config delivered via SiteConfiguration at runtime (ADR-024) |
| `base/apps/enterprise/mfe/skillourfuture-mfe-env.js` | APP_RUNTIME | NOT RENDERED directly | KEEP_DOCUMENT | Reference only; per-tenant config delivered via SiteConfiguration at runtime (ADR-024) |

### base/apps/hubspot-webhook/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/apps/hubspot-webhook/kustomization.yaml` | DEAD_REFERENCE | NOT RENDERED | QUARANTINE | Not included in base/kustomization.yaml |
| `base/apps/hubspot-webhook/deployment.yaml` | DEAD_REFERENCE | NOT RENDERED | QUARANTINE | Uses `placeholder/hubspot-webhook:latest` image; Firebase Cloud Function is the live implementation |
| `base/apps/hubspot-webhook/service.yaml` | DEAD_REFERENCE | NOT RENDERED | QUARANTINE | Service for placeholder deployment |

### base/apps/lms/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/apps/lms/kustomization.yaml` | APP_RUNTIME | base | KEEP | LMS kustomization |
| `base/apps/lms/hpa.yaml` | APP_RUNTIME | base → apps/lms | KEEP | LMS HPA |

### base/apps/multi-tenancy/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/apps/multi-tenancy/kustomization.yaml` | APP_RUNTIME | base | KEEP | Multi-tenancy kustomization |
| `base/apps/multi-tenancy/configmap-tenants.yaml` | APP_RUNTIME | base → apps/multi-tenancy | KEEP | Tenant registry ConfigMap |

### base/apps/openedx/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/apps/openedx/config/cms.env.yml` | APP_RUNTIME | base (configMapGenerator openedx-config) | KEEP | CMS env config YAML |
| `base/apps/openedx/config/lms.env.yml` | APP_RUNTIME | base (configMapGenerator openedx-config) | KEEP | LMS env config YAML |
| `base/apps/openedx/settings/cms/__init__.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-cms) | KEEP | CMS settings init |
| `base/apps/openedx/settings/cms/development.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-cms) | KEEP | CMS dev settings |
| `base/apps/openedx/settings/cms/production.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-cms) | KEEP | CMS production settings |
| `base/apps/openedx/settings/cms/test.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-cms) | KEEP | CMS test settings |
| `base/apps/openedx/settings/cms/mereka_forwarded_headers.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-cms) | KEEP | CMS forwarded headers module |
| `base/apps/openedx/settings/cms/mereka_multisite.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-cms) | KEEP | CMS multisite module |
| `base/apps/openedx/settings/cms/mereka_platform_admin.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-cms) | KEEP | CMS platform admin module |
| `base/apps/openedx/settings/lms/__init__.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-lms) | KEEP | LMS settings init |
| `base/apps/openedx/settings/lms/development.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-lms) | KEEP | LMS dev settings |
| `base/apps/openedx/settings/lms/production.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-lms) | KEEP | LMS production settings |
| `base/apps/openedx/settings/lms/test.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-lms) | KEEP | LMS test settings |
| `base/apps/openedx/settings/lms/mereka_enterprise_channels.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-lms) | KEEP | LMS enterprise channels module |
| `base/apps/openedx/settings/lms/mereka_forwarded_headers.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-lms) | KEEP | LMS forwarded headers module |
| `base/apps/openedx/settings/lms/mereka_jwt_session.py` | APP_RUNTIME | NOT RENDERED | ASSESS | Not in base kustomization.yaml configMapGenerator list; may be dead or manually deployed |
| `base/apps/openedx/settings/lms/mereka_multisite.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-lms) | KEEP | LMS multisite module |
| `base/apps/openedx/settings/lms/mereka_platform_admin.py` | APP_RUNTIME | base (configMapGenerator openedx-settings-lms) | KEEP | LMS platform admin module |
| `base/apps/openedx/theme/head-extra.html` | APP_RUNTIME | base (configMapGenerator openedx-theme-head-extra) | KEEP | Theme head-extra HTML template |
| `base/apps/openedx/uwsgi.ini` | APP_RUNTIME | base (configMapGenerator openedx-uwsgi-config) | KEEP | uWSGI config |

### base/apps/permissions/ (DELETED 2026-03-07)

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| ~~`base/apps/permissions/setowners.sh`~~ | DELETED | — | DONE | Deleted 2026-03-07 (Phase 2 quarantine). Directory removed. |

### base/apps/preview-redirect/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/apps/preview-redirect/kustomization.yaml` | APP_RUNTIME | base | KEEP | Preview redirect kustomization |
| `base/apps/preview-redirect/configmap.yaml` | APP_RUNTIME | base → apps/preview-redirect | KEEP | Preview redirect ConfigMap |
| `base/apps/preview-redirect/deployment.yaml` | APP_RUNTIME | base → apps/preview-redirect | KEEP | Preview redirect Deployment |
| `base/apps/preview-redirect/service.yaml` | APP_RUNTIME | base → apps/preview-redirect | KEEP | Preview redirect Service |

### base/apps/redis/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/apps/redis/redis.conf` | APP_RUNTIME | base (configMapGenerator redis-config) | KEEP | Redis config; generates redis-config ConfigMap |

### base/apps/xqueue-graders/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/apps/xqueue-graders/deployment.yaml` | DEAD_REFERENCE | NOT RENDERED | ASSESS | Not in base/kustomization.yaml; xqueue set to count: 0 in all overlays; uses `imagePullPolicy: Always` with `:latest` tag |
| `base/apps/xqueue-graders/hpa.yaml` | DEAD_REFERENCE | NOT RENDERED | ASSESS | Companion to xqueue-graders deployment |
| `base/apps/xqueue-graders/networkpolicy.yaml` | DEAD_REFERENCE | NOT RENDERED | ASSESS | NetworkPolicy for xqueue-graders |
| `base/apps/xqueue-graders/prometheusrule.yaml` | DEAD_REFERENCE | NOT RENDERED | ASSESS | PrometheusRule for xqueue-graders |
| `base/apps/xqueue-graders/sandbox-policy.yaml` | DEAD_REFERENCE | NOT RENDERED | ASSESS | Kyverno sandbox policy for xqueue-graders |
| `base/apps/xqueue-graders/servicemonitor.yaml` | DEAD_REFERENCE | NOT RENDERED | ASSESS | ServiceMonitor for xqueue-graders |

### base/arc/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/arc/kustomization.yaml` | PLATFORM_SHARED | NOT RENDERED by overlays (applied separately) | MOVE_INFRA | ARC controller entry point; applied via `kubectl apply -k deploy/k8s/base/arc/` |
| `base/arc/namespace.yaml` | PLATFORM_SHARED | base/arc (applied separately) | MOVE_INFRA | arc-systems and arc-runners Namespaces |
| `base/arc/dind-daemon-config.yaml` | PLATFORM_SHARED | base/arc (applied separately) | MOVE_INFRA | Docker-in-Docker ConfigMap for heavy runners |
| `base/arc/helm-values.yaml` | PLATFORM_SHARED | base/arc (applied separately) | MOVE_INFRA | Helm values for ARC controller chart |
| `base/arc/runner-scale-set-standard.yaml` | PLATFORM_SHARED | base/arc (applied separately) | MOVE_INFRA | Standard runner ScaleSet (2CPU/4GB) |
| `base/arc/runner-scale-set-heavy.yaml` | PLATFORM_SHARED | base/arc (applied separately) | MOVE_INFRA | Heavy builder runner ScaleSet (4CPU/12GB + DinD) + PVC claims |

### base/jobs/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/jobs/discovery-sync-cronjob.yaml` | APP_RELEASE | base | KEEP | Discovery catalog sync CronJob (runs every 6h) |

### base/logging/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/logging/README.md` | — | NOT RENDERED | MOVE_INFRA | Logging documentation |
| `base/logging/TESTING.md` | — | NOT RENDERED | MOVE_INFRA | Logging test documentation |
| `base/logging/kustomization.yaml` | PLATFORM_SHARED | base | MOVE_INFRA | Promtail kustomization; creates cluster-scoped ClusterRole/ClusterRoleBinding |
| `base/logging/promtail-rbac.yaml` | PLATFORM_SHARED | base → logging | MOVE_INFRA | ClusterRole + ClusterRoleBinding for Promtail; cluster-scoped |
| `base/logging/promtail-configmap.yaml` | PLATFORM_SHARED | base → logging | MOVE_INFRA | Promtail scrape config ConfigMap |
| `base/logging/promtail-daemonset.yaml` | PLATFORM_SHARED | base → logging | MOVE_INFRA | Promtail DaemonSet; runs on all nodes, not just mereka-lms |
| `base/logging/promtail-service.yaml` | PLATFORM_SHARED | base → logging | MOVE_INFRA | Promtail Service |

### base/monitoring/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/monitoring/README.md` | — | NOT RENDERED | KEEP | Monitoring documentation |
| `base/monitoring/IMPLEMENTATION_STATUS.md` | — | NOT RENDERED | KEEP | Monitoring implementation status |
| `base/monitoring/kustomization.yaml` | APP_RUNTIME | base | KEEP | Monitoring kustomization |
| `base/monitoring/servicemonitor-caddy.yaml` | APP_RUNTIME | base → monitoring | KEEP | Caddy ServiceMonitor |
| `base/monitoring/servicemonitor-cms.yaml` | APP_RUNTIME | base → monitoring | KEEP | CMS ServiceMonitor |
| `base/monitoring/servicemonitor-credentials.yaml` | APP_RUNTIME | base → monitoring | KEEP | Credentials ServiceMonitor |
| `base/monitoring/servicemonitor-discovery.yaml` | APP_RUNTIME | base → monitoring | KEEP | Discovery ServiceMonitor |
| `base/monitoring/servicemonitor-enterprise.yaml` | APP_RUNTIME | base → monitoring | KEEP | Enterprise services ServiceMonitor |
| `base/monitoring/servicemonitor-forum.yaml` | APP_RUNTIME | base → monitoring | KEEP | Forum ServiceMonitor |
| `base/monitoring/servicemonitor-lms.yaml` | APP_RUNTIME | base → monitoring | KEEP | LMS ServiceMonitor |
| `base/monitoring/servicemonitor-mfe.yaml` | APP_RUNTIME | base → monitoring | KEEP | MFE ServiceMonitor |
| `base/monitoring/servicemonitor-mux.yaml` | APP_RUNTIME | base → monitoring | KEEP | Mux video exporter ServiceMonitor |
| `base/monitoring/servicemonitor-mysql.yaml` | APP_RUNTIME | base → monitoring | KEEP | MySQL ServiceMonitor |
| `base/monitoring/servicemonitor-notes.yaml` | APP_RUNTIME | base → monitoring | KEEP | Notes ServiceMonitor |
| `base/monitoring/servicemonitor-purchase-gateway.yaml` | APP_RUNTIME | base → monitoring | KEEP | Purchase gateway ServiceMonitor |
| `base/monitoring/servicemonitor-redis.yaml` | APP_RUNTIME | base → monitoring | KEEP | Redis ServiceMonitor |
| `base/monitoring/servicemonitor-xqueue.yaml` | APP_RUNTIME | base → monitoring | KEEP | XQueue ServiceMonitor |
| `base/monitoring/prometheusrule-auth.yaml` | APP_RUNTIME | base → monitoring | KEEP | Auth PrometheusRule |
| `base/monitoring/prometheusrule-caddy.yaml` | APP_RUNTIME | base → monitoring | KEEP | Caddy PrometheusRule |
| `base/monitoring/prometheusrule-credentials.yaml` | APP_RUNTIME | base → monitoring | KEEP | Credentials PrometheusRule |
| `base/monitoring/prometheusrule-email.yaml` | APP_RUNTIME | base → monitoring | KEEP | Email pipeline PrometheusRule |
| `base/monitoring/prometheusrule-enterprise.yaml` | APP_RUNTIME | base → monitoring | KEEP | Enterprise PrometheusRule |
| `base/monitoring/prometheusrule-externalsecrets.yaml` | APP_RUNTIME | base → monitoring | KEEP | External Secrets PrometheusRule |
| `base/monitoring/prometheusrule-libraries.yaml` | APP_RUNTIME | base → monitoring | KEEP | Libraries PrometheusRule |
| `base/monitoring/prometheusrule-lms.yaml` | APP_RUNTIME | base → monitoring | KEEP | LMS PrometheusRule |
| `base/monitoring/prometheusrule-ora2.yaml` | APP_RUNTIME | base → monitoring | KEEP | ORA2 PrometheusRule |
| `base/monitoring/prometheusrule-services.yaml` | APP_RUNTIME | base → monitoring | KEEP | Services PrometheusRule |
| `base/monitoring/prometheusrule-slo.yaml` | APP_RUNTIME | base → monitoring | KEEP | SLO recording rules |
| `base/monitoring/prometheusrule-tenant-isolation.yaml` | APP_RUNTIME | base → monitoring | KEEP | Tenant isolation PrometheusRule |
| `base/monitoring/prometheusrule-velero.yaml` | APP_RUNTIME | base → monitoring | KEEP | Velero PrometheusRule |
| `base/monitoring/prometheusrule-video.yaml` | APP_RUNTIME | base → monitoring | KEEP | Video pipeline PrometheusRule |
| `base/monitoring/prometheusrule-xqueue.yaml` | APP_RUNTIME | base → monitoring | KEEP | XQueue PrometheusRule |
| `base/monitoring/slo-burn-rate-rules.yaml` | APP_RUNTIME | base → monitoring | KEEP | SLO burn rate recording rules |
| `base/monitoring/hpa-enterprise.yaml` | APP_RUNTIME | base → monitoring | KEEP | Enterprise services HPA definitions |
| `base/monitoring/mux-exporter.yaml` | APP_RUNTIME | base → monitoring | KEEP | Mux video metrics exporter Deployment+Service |
| `base/monitoring/mux_delivery_monitor.py` | APP_RUNTIME | base → monitoring (configMapGenerator) | KEEP | Mux delivery monitor Python script |
| `base/monitoring/grafana-dashboard-ora2.json` | APP_RUNTIME | NOT RENDERED directly | KEEP_DOCUMENT | Grafana dashboard JSON; not a K8s manifest; should be provisioned via Grafana sidecar or documented |
| `base/monitoring/cronjob-library-export.yaml` | APP_RELEASE | NOT RENDERED | ASSESS | Library export CronJob; not in monitoring/kustomization.yaml |
| `base/monitoring/cronjob-tenant-isolation.yaml` | APP_RELEASE | NOT RENDERED | ASSESS | Tenant isolation audit CronJob; not in monitoring/kustomization.yaml |
| `base/monitoring/verify.sh` | — | NOT RENDERED | KEEP_DOCUMENT | Verification script; belongs under scripts/qa/ not deploy/k8s/ |

### base/network-policies/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/network-policies/kustomization.yaml` | APP_RUNTIME | base | KEEP | Network policies kustomization |
| `base/network-policies/default-deny.yaml` | APP_RUNTIME | base → network-policies | KEEP | Default deny NetworkPolicy for mereka-lms namespace |
| `base/network-policies/allow-dns.yaml` | APP_RUNTIME | base → network-policies | KEEP | Allow DNS egress NetworkPolicy |
| `base/network-policies/allow-namespace-internal.yaml` | APP_RUNTIME | base → network-policies | KEEP | Allow intra-namespace traffic |
| `base/network-policies/allow-caddy-external.yaml` | APP_RUNTIME | base → network-policies | KEEP | Allow Caddy ingress from outside |
| `base/network-policies/allow-external-egress.yaml` | APP_RUNTIME | base → network-policies | KEEP | Allow external egress NetworkPolicy |

### base/operational/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/operational/kustomization.yaml` | APP_RUNTIME | base | KEEP | Operational resources kustomization |
| `base/operational/pdb.yaml` | APP_RUNTIME | base → operational | KEEP | PodDisruptionBudgets for LMS, CMS, workers |
| `base/operational/hpa-baselines.yaml` | APP_RUNTIME | base → operational | KEEP | HPA baseline definitions |

### base/patches/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/patches/container-hardening.yaml` | APP_RUNTIME | base (patches) | KEEP | securityContext hardening for core deployments (LMS, CMS, workers, Caddy, Redis, MySQL, etc.) |
| `base/patches/container-hardening-enterprise.yaml` | APP_RUNTIME | base (patches) | KEEP | securityContext hardening for enterprise services and portals |
| `base/patches/credentials-zoneinfo.yaml` | APP_RUNTIME | base (patches) | KEEP | ZoneInfo fix for credentials service container |

### base/plugins/aspects/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/plugins/aspects/kustomization.yaml` | APP_RUNTIME | production, rke2-nonprod, staging (as extra resource) | KEEP | Aspects analytics stack kustomization |
| `base/plugins/aspects/README.md` | — | NOT RENDERED | KEEP | Aspects documentation |
| `base/plugins/aspects/configmaps.yml` | APP_RUNTIME | production/rke2-nonprod/staging → aspects | KEEP | Aspects ConfigMaps |
| `base/plugins/aspects/deployments.yml` | APP_RUNTIME | production/rke2-nonprod/staging → aspects | KEEP | ClickHouse, Superset deployments |
| `base/plugins/aspects/ingress.yml` | ENVIRONMENT_SPECIFIC | production/rke2-nonprod/staging → aspects | KEEP_DOCUMENT | Aspects ingress; contains environment-specific domain references patched per-overlay |
| `base/plugins/aspects/jobs.yml` | APP_RELEASE | production/rke2-nonprod/staging → aspects | KEEP | Aspects init/sync jobs |
| `base/plugins/aspects/prometheusrule.yml` | APP_RUNTIME | production/rke2-nonprod/staging → aspects | KEEP | Aspects PrometheusRules |
| `base/plugins/aspects/secrets.yml` | APP_RUNTIME | production/rke2-nonprod/staging → aspects | KEEP | Aspects ExternalSecrets |
| `base/plugins/aspects/services.yml` | APP_RUNTIME | production/rke2-nonprod/staging → aspects | KEEP | Aspects Services |
| `base/plugins/aspects/sync-job.yml` | APP_RELEASE | production/rke2-nonprod/staging → aspects | KEEP | Aspects data sync job |
| `base/plugins/aspects/volumes.yml` | APP_RUNTIME | production/rke2-nonprod/staging → aspects | KEEP | Aspects PVCs |

### base/plugins/credentials/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/plugins/credentials/apps/credentials/settings/__init__.py` | APP_RUNTIME | base (configMapGenerator credentials-settings) | KEEP | Credentials settings init |
| `base/plugins/credentials/apps/credentials/settings/development.py` | APP_RUNTIME | base (configMapGenerator credentials-settings) | KEEP | Credentials dev settings |
| `base/plugins/credentials/apps/credentials/settings/production.py` | APP_RUNTIME | base (configMapGenerator credentials-settings) | KEEP | Credentials production settings |
| `base/plugins/credentials/apps/credentials/settings/mereka_platform_admin.py` | APP_RUNTIME | base (configMapGenerator credentials-settings) | KEEP | Credentials platform admin settings |

### base/plugins/discovery/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/plugins/discovery/apps/settings/tutor/__init__.py` | APP_RUNTIME | NOT RENDERED (not in configMapGenerator) | ASSESS | Init file; base kustomization only includes production.py and mereka_platform_admin.py for discovery-settings |
| `base/plugins/discovery/apps/settings/tutor/development.py` | APP_RUNTIME | NOT RENDERED (not in configMapGenerator) | ASSESS | Dev settings; not in configMapGenerator list |
| `base/plugins/discovery/apps/settings/tutor/mereka_platform_admin.py` | APP_RUNTIME | base (configMapGenerator discovery-settings) | KEEP | Discovery platform admin settings |
| `base/plugins/discovery/apps/settings/tutor/production.py` | APP_RUNTIME | base (configMapGenerator discovery-settings) | KEEP | Discovery production settings |

### base/plugins/mfe/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/plugins/mfe/apps/mfe/Caddyfile` | APP_RUNTIME | base (configMapGenerator mfe-caddy-config) | KEEP | MFE Caddy config; generates mfe-caddy-config ConfigMap |
| `base/plugins/mfe/apps/mfe/webpack.dev-tutor.config.js` | APP_RUNTIME | NOT RENDERED | KEEP_DOCUMENT | MFE dev webpack config; used during Tutor local dev builds, not a K8s manifest |

### base/plugins/notes/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/plugins/notes/apps/settings/tutor.py` | APP_RUNTIME | base (configMapGenerator notes-settings) | KEEP | Notes service settings |

### base/plugins/xqueue/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/plugins/xqueue/apps/settings/tutor.py` | APP_RUNTIME | base (configMapGenerator xqueue-settings) | KEEP | XQueue service settings |

### base/policies/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/policies/kustomization.yaml` | PLATFORM_SHARED | base | MOVE_INFRA | Kyverno ClusterPolicies kustomization; creates cluster-scoped ClusterPolicy resources |
| `base/policies/require-non-root.yaml` | PLATFORM_SHARED | base → policies | MOVE_INFRA | Kyverno ClusterPolicy: require runAsNonRoot |
| `base/policies/disallow-privileged.yaml` | PLATFORM_SHARED | base → policies | MOVE_INFRA | Kyverno ClusterPolicy: disallow privileged containers |
| `base/policies/require-seccomp.yaml` | PLATFORM_SHARED | base → policies | MOVE_INFRA | Kyverno ClusterPolicy: require seccomp profile |
| `base/policies/restrict-capabilities.yaml` | PLATFORM_SHARED | base → policies | MOVE_INFRA | Kyverno ClusterPolicy: restrict Linux capabilities |

### base/secrets/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `base/secrets/kustomization.yaml` | APP_RUNTIME | base | KEEP | Secrets kustomization |
| `base/secrets/cluster-secret-store.yaml` | PLATFORM_SHARED | base → secrets | MOVE_INFRA | ClusterSecretStore for GCP Secret Manager (bbi-k8 project); cluster-scoped; one per cluster |
| `base/secrets/external-secrets.yaml` | APP_RUNTIME | base → secrets | KEEP | ExternalSecrets for openedx-secrets, database-secrets, enterprise-secrets, aspects-secrets |
| `base/secrets/openedx-secrets.yaml` | APP_LOCAL_ONLY | NOT RENDERED (commented out in kustomization) | KEEP_DOCUMENT | Static secrets template for local dev only; do not re-enable without review |
| `base/secrets/SECRET_CLASSIFICATION.yaml` | — | NOT RENDERED | KEEP | Secret lifecycle classification registry; 81 unique secret keys documented |

---

### overlays/local/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `overlays/local/kustomization.yaml` | APP_LOCAL_ONLY | self (entry point) | KEEP | Local Kind overlay kustomization |
| `overlays/local/clusterissuer-letsencrypt-prod.yaml` | APP_LOCAL_ONLY | overlays/local | KEEP | cert-manager ClusterIssuer for local Let's Encrypt; LOCAL ONLY |
| `overlays/local/enterprise-mfe-env.js` | APP_LOCAL_ONLY | overlays/local (configMapGenerator replace) | KEEP | Local dev enterprise MFE env config |
| `overlays/local/ingress-openedx-lms.yaml` | APP_LOCAL_ONLY | overlays/local | KEEP | Local LMS Ingress |
| `overlays/local/ingress-openedx-mfe.yaml` | APP_LOCAL_ONLY | overlays/local | KEEP | Local MFE Ingress |
| `overlays/local/ingress-openedx-studio.yaml` | APP_LOCAL_ONLY | overlays/local | KEEP | Local Studio Ingress |
| `overlays/local/patches/clustersecretstore-gcp.yaml` | APP_LOCAL_ONLY | overlays/local (patches) | KEEP | Patches ClusterSecretStore to use secretRef instead of Workload Identity (no WI on Kind) |
| `overlays/local/patches/cms-memory-limits.yaml` | APP_LOCAL_ONLY | overlays/local (patches) | KEEP | CMS memory limit overrides for local dev |
| `overlays/local/patches/database-secrets-dev.yaml` | APP_LOCAL_ONLY | overlays/local (patches) | KEEP | Dev database secret literals |
| `overlays/local/patches/domain-env.yaml` | APP_LOCAL_ONLY | overlays/local (patches) | KEEP | Local domain env var overrides |
| `overlays/local/patches/meilisearch-security-context.yaml` | APP_LOCAL_ONLY | overlays/local (patches) | KEEP | Meilisearch security context patch for Kind |
| `overlays/local/patches/openedx-secrets-dev.yaml` | APP_LOCAL_ONLY | overlays/local (patches) | KEEP | Dev OpenEdX secret literals |

### overlays/production/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `overlays/production/kustomization.yaml` | ENVIRONMENT_SPECIFIC | self (entry point) | MOVE_INFRA | GKE production overlay; frozen (scaled to 0). Currently duplicated between app repo and infrastructure |
| `overlays/production/ingress-openedx-lms.yaml` | ENVIRONMENT_SPECIFIC | overlays/production | MOVE_INFRA | Production LMS Ingress (academyv2.mereka.io, academy.biji-biji.com) |
| `overlays/production/ingress-openedx-mfe.yaml` | ENVIRONMENT_SPECIFIC | overlays/production | MOVE_INFRA | Production MFE Ingress (apps.academyv2.mereka.io) |
| `overlays/production/ingress-openedx-mfeconfig-compat.yaml` | ENVIRONMENT_SPECIFIC | overlays/production | MOVE_INFRA | Production MFE config compatibility Ingress |
| `overlays/production/ingress-openedx-studio.yaml` | ENVIRONMENT_SPECIFIC | overlays/production | MOVE_INFRA | Production Studio Ingress (studio.academyv2.mereka.io) |
| `overlays/production/ingress-enterprise-admin.yaml` | ENVIRONMENT_SPECIFIC | overlays/production | MOVE_INFRA | Production Enterprise Admin portal Ingress |
| `overlays/production/ingress-enterprise-learner.yaml` | ENVIRONMENT_SPECIFIC | overlays/production | MOVE_INFRA | Production Enterprise Learner portal Ingress |
| `overlays/production/ingress-credentials.yaml` | ENVIRONMENT_SPECIFIC | overlays/production | MOVE_INFRA | Production Credentials Ingress |
| `overlays/production/ingress-notes.yaml` | ENVIRONMENT_SPECIFIC | overlays/production | MOVE_INFRA | Production Notes Ingress |
| `overlays/production/patches/remove-legacy-mongodb-service.yaml` | ENVIRONMENT_SPECIFIC | overlays/production (patches) | MOVE_INFRA | Removes stub MongoDB Service (Atlas-only) |
| `overlays/production/patches/resource-limits.yaml` | ENVIRONMENT_SPECIFIC | overlays/production (patches) | MOVE_INFRA | Production resource limit overrides |

### overlays/rke2-nonprod/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `overlays/rke2-nonprod/kustomization.yaml` | ENVIRONMENT_SPECIFIC | self (entry point) | MOVE_INFRA | RKE2 dev overlay kustomization; active development target |
| `overlays/rke2-nonprod/enterprise-mfe-env.js` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod (configMapGenerator replace) | MOVE_INFRA | RKE2 dev enterprise MFE env config (*.mereka.dev domains) |
| `overlays/rke2-nonprod/ingress-openedx-lms.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod | MOVE_INFRA | Dev LMS Ingress (academyv2.mereka.dev) |
| `overlays/rke2-nonprod/ingress-openedx-mfe.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod | MOVE_INFRA | Dev MFE Ingress |
| `overlays/rke2-nonprod/ingress-openedx-mfeconfig-compat.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod | MOVE_INFRA | Dev MFE config compat Ingress |
| `overlays/rke2-nonprod/ingress-openedx-studio.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod | MOVE_INFRA | Dev Studio Ingress |
| `overlays/rke2-nonprod/ingress-enterprise-admin.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod | MOVE_INFRA | Dev Enterprise Admin portal Ingress |
| `overlays/rke2-nonprod/ingress-enterprise-learner.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod | MOVE_INFRA | Dev Enterprise Learner portal Ingress |
| `overlays/rke2-nonprod/ingress-credentials.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod | MOVE_INFRA | Dev Credentials Ingress |
| `overlays/rke2-nonprod/ingress-notes.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod | MOVE_INFRA | Dev Notes Ingress |
| `overlays/rke2-nonprod/config/cms.env.yml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod (configMapGenerator merge) | MOVE_INFRA | Dev CMS env overrides |
| `overlays/rke2-nonprod/config/lms.env.yml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod (configMapGenerator merge) | MOVE_INFRA | Dev LMS env overrides |
| `overlays/rke2-nonprod/patches/arc-storage-class.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod (patches) | MOVE_INFRA | ARC PVC storage class patch for RKE2 |
| `overlays/rke2-nonprod/patches/aspects-container-hardening.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod (patches) | MOVE_INFRA | Aspects container hardening patch for RKE2 |
| `overlays/rke2-nonprod/patches/aspects-ingress-dev.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod (patches) | MOVE_INFRA | Aspects ingress overrides for dev |
| `overlays/rke2-nonprod/patches/aspects-storage-class.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod (patches) | MOVE_INFRA | Aspects storage class patch for RKE2 |
| `overlays/rke2-nonprod/patches/domain-env.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod (patches) | MOVE_INFRA | Dev domain env var overrides (*.mereka.dev) |
| `overlays/rke2-nonprod/patches/enterprise-catalog-worker-nonprod.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod (patches) | MOVE_INFRA | Enterprise catalog worker Recreate strategy + probe hardening |
| `overlays/rke2-nonprod/patches/externalsecrets-infisical.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod (patches) | MOVE_INFRA | Switches ExternalSecrets from gcp-secret-manager to infisical-secret-store |
| `overlays/rke2-nonprod/patches/payments-gateway-secrets-infisical.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod (patches, targeted) | MOVE_INFRA | Payments gateway ExternalSecret switched to Infisical + dev Stripe keys |
| `overlays/rke2-nonprod/patches/remove-legacy-mongodb-service.yaml` | ENVIRONMENT_SPECIFIC | overlays/rke2-nonprod (patches) | MOVE_INFRA | Removes stub MongoDB Service (Atlas-only) |

### overlays/staging/

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `overlays/staging/kustomization.yaml` | ENVIRONMENT_SPECIFIC | self (entry point) | ASSESS | Staging overlay; shares RKE2 cluster with rke2-nonprod; no independent cluster; consider consolidating into rke2-nonprod with a namespace differentiator |
| `overlays/staging/enterprise-mfe-env.js` | ENVIRONMENT_SPECIFIC | overlays/staging (configMapGenerator replace) | ASSESS | Staging enterprise MFE env config |
| `overlays/staging/ingress-openedx-lms.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging | ASSESS | Staging LMS Ingress (staging.academyv2.mereka.io) |
| `overlays/staging/ingress-openedx-mfe.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging | ASSESS | Staging MFE Ingress |
| `overlays/staging/ingress-openedx-studio.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging | ASSESS | Staging Studio Ingress |
| `overlays/staging/ingress-enterprise-admin.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging | ASSESS | Staging Enterprise Admin portal Ingress |
| `overlays/staging/ingress-enterprise-learner.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging | ASSESS | Staging Enterprise Learner portal Ingress |
| `overlays/staging/ingress-credentials.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging | ASSESS | Staging Credentials Ingress |
| `overlays/staging/ingress-notes.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging | ASSESS | Staging Notes Ingress |
| `overlays/staging/config/cms.env.yml` | ENVIRONMENT_SPECIFIC | overlays/staging (configMapGenerator merge) | ASSESS | Staging CMS env overrides |
| `overlays/staging/config/lms.env.yml` | ENVIRONMENT_SPECIFIC | overlays/staging (configMapGenerator merge) | ASSESS | Staging LMS env overrides |
| `overlays/staging/patches/aspects-container-hardening.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging (patches) | ASSESS | Staging Aspects hardening patch |
| `overlays/staging/patches/aspects-ingress-staging.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging (patches) | ASSESS | Staging Aspects ingress overrides |
| `overlays/staging/patches/aspects-storage-class.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging (patches) | ASSESS | Staging Aspects storage class |
| `overlays/staging/patches/domain-env.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging (patches) | ASSESS | Staging domain env var overrides |
| `overlays/staging/patches/enterprise-catalog-worker-nonprod.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging (patches) | ASSESS | Staging enterprise catalog worker patch |
| `overlays/staging/patches/externalsecrets-infisical.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging (patches) | ASSESS | Staging ExternalSecrets → Infisical |
| `overlays/staging/patches/payments-gateway-secrets-infisical.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging (patches) | ASSESS | Staging payments gateway secrets |
| `overlays/staging/patches/remove-legacy-mongodb-service.yaml` | ENVIRONMENT_SPECIFIC | overlays/staging (patches) | ASSESS | Remove stub MongoDB Service |

### patches/ (top-level, NOT sub-kustomization)

| File | Classification | Rendered By | Action | Notes |
|---|---|---|---|---|
| `patches/README.md` | — | NOT RENDERED | KEEP | Patches documentation |
| `patches/argocd-configmap-ignore.yaml` | PLATFORM_SHARED | NOT RENDERED (manual apply only) | MOVE_INFRA | ArgoCD Application ignoreDifferences patch; belongs in ArgoCD Application manifest in infrastructure |
| ~~`patches/caddy-staging-fix.yaml`~~ | DELETED | — | DONE | Deleted 2026-03-07 (Phase 2 quarantine) |
| ~~`patches/smtp-ses-relay.yaml`~~ | DELETED | — | DONE | Deleted 2026-03-07 (Phase 2 quarantine) |

---

## Summary Statistics

| Classification | Count | Action |
|---|---|---|
| APP_RUNTIME | 110 | Keep in app repo |
| APP_RELEASE | 5 | Keep in app repo |
| APP_LOCAL_ONLY | 13 | Keep in app repo |
| PLATFORM_SHARED | 15 | Move to infrastructure repo |
| ENVIRONMENT_SPECIFIC | 47 | Move to infrastructure |
| DEAD_REFERENCE | 12 | Quarantine or delete (2 deleted 2026-03-07) |

**Total files classified:** 204 (excluding docs-only files)

## NOT RENDERED Files Summary

These files exist under `deploy/k8s/` but are not included in any kustomization render path and require action:

| File | Classification | Reason Not Rendered | Recommended Action |
|---|---|---|---|
| `base/apps/hubspot-webhook/**` (3 files) | DEAD_REFERENCE | Not in base/kustomization.yaml | Quarantine |
| `base/apps/xqueue-graders/**` (6 files) | DEAD_REFERENCE | Not in base/kustomization.yaml | Assess |
| ~~`base/apps/permissions/setowners.sh`~~ | DELETED | Deleted 2026-03-07 | Done |
| `base/apps/openedx/settings/lms/mereka_jwt_session.py` | APP_RUNTIME | Not in configMapGenerator list | Assess — add to configMapGenerator or delete |
| `base/plugins/discovery/apps/settings/tutor/__init__.py` | APP_RUNTIME | Not in configMapGenerator | Assess |
| `base/plugins/discovery/apps/settings/tutor/development.py` | APP_RUNTIME | Not in configMapGenerator | Assess |
| `base/monitoring/cronjob-library-export.yaml` | APP_RELEASE | In monitoring/kustomization.yaml | Done |
| `base/monitoring/cronjob-tenant-isolation.yaml` | APP_RELEASE | In monitoring/kustomization.yaml | Done |
| `base/monitoring/verify.sh` | — | Not a K8s manifest | Move to scripts/qa/ |
| `base/monitoring/grafana-dashboard-ora2.json` | APP_RUNTIME | Not a K8s manifest | Provision via Grafana sidecar ConfigMap or document |
| `base/arc/**` (6 files) | PLATFORM_SHARED | Applied separately by design | Move to infra repo |
| `patches/argocd-configmap-ignore.yaml` | PLATFORM_SHARED | Manual apply | Move to infra repo |
| ~~`patches/caddy-staging-fix.yaml`~~ | DELETED | Deleted 2026-03-07 | Done |
| ~~`patches/smtp-ses-relay.yaml`~~ | DELETED | Deleted 2026-03-07 | Done |
| `base/secrets/openedx-secrets.yaml` | APP_LOCAL_ONLY | Commented out in kustomization | Document status |
| `base/apps/enterprise/mfe/biji-biji-mfe-env.js` | APP_RUNTIME | ADR-024: per-tenant delivered at runtime | Document as reference only |
| `base/apps/enterprise/mfe/skillourfuture-mfe-env.js` | APP_RUNTIME | ADR-024: per-tenant delivered at runtime | Document as reference only |

## Cluster-Scoped Resources (require cluster-admin to apply)

| File | Kind | Name |
|---|---|---|
| `base/logging/promtail-rbac.yaml` | ClusterRole | promtail-mereka-lms |
| `base/logging/promtail-rbac.yaml` | ClusterRoleBinding | promtail-mereka-lms |
| `base/policies/require-non-root.yaml` | ClusterPolicy | require-non-root-mereka-lms |
| `base/policies/disallow-privileged.yaml` | ClusterPolicy | disallow-privileged-mereka-lms |
| `base/policies/require-seccomp.yaml` | ClusterPolicy | require-seccomp-mereka-lms |
| `base/policies/restrict-capabilities.yaml` | ClusterPolicy | restrict-capabilities-mereka-lms |
| `base/secrets/cluster-secret-store.yaml` | ClusterSecretStore | gcp-secret-manager |
| `overlays/local/clusterissuer-letsencrypt-prod.yaml` | ClusterIssuer | letsencrypt-prod |
| `base/arc/namespace.yaml` | Namespace | arc-systems, arc-runners |
| `patches/argocd-configmap-ignore.yaml` | Application (argocd) | mereka-lms |
