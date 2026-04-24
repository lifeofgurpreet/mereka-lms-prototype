# Phantom Metric Audit — prod PrometheusRules (2026-04-21)

## What this is

A phantom metric is a metric name referenced in a PrometheusRule `expr` that
does NOT exist in the live Prometheus `__name__` inventory. Rules referencing
phantom metrics cannot fire — they are dead detection logic.

**Origin.** Discovered while investigating the silent Velero BSL Unavailable
incident (bead `mereka-lms-krco`) on 2026-04-21. That alert used
`velero_backup_storage_location_available` — a non-existent metric — and so ran
dead for weeks while production DR posture degraded. This audit sweeps the
entire estate for that failure class.

## Method

1. `kubectl --context rke2-prod get prometheusrules -A -o json` → 796 rule entries across 74 objects
2. `GET http://monitoring-kube-prometheus-prometheus:9090/api/v1/label/__name__/values` → 2774 live metric names
3. Parse each `expr` via PromQL-aware tokenizer (strips label selectors, label-list modifiers, functions, aggregation operators)
4. Recording-rule outputs (99 names) treated as virtual metrics
5. For each phantom: closest-match via trigram Jaccard, family-prefix search

## Summary

- **796** rule entries (alert + recording) across **74** PrometheusRule objects
- **157** rule entries reference ≥1 phantom metric
- **101** unique phantom metric names

### Phantom rule entries by namespace

| Namespace | Phantom rule entries |
|---|---|
| `monitoring` | 79 |
| `mereka-lms` | 64 |
| `agent-e` | 6 |
| `team-analytics` | 5 |
| `weaviate` | 2 |
| `velero` | 1 |

### Classification of unique phantom names

| Kind | Count | Interpretation |
|---|---|---|
| `LIKELY_TYPO` | 14 | Close match exists; probably a typo or renamed metric. **Highest-risk** — alert author expected it to fire. |
| `FAMILY_EXISTS` | 37 | Metric family exists but this specific variant is absent. Often means exporter collector disabled or upstream renamed. |
| `NO_TRACE` | 50 | Zero footprint; app not instrumented, or exporter not scraped. Speculative alert. |

## Repo ownership split

**mereka-lms repo owns:** alerts in `mereka-lms` namespace (this repo).
**bbi-infrastructure owns:** alerts in `monitoring`, `velero`, `agent-e`, `weaviate`, `team-analytics`, `calcom-prod`.

## Phantom rules — mereka-lms (this repo)

64 phantom rule entries.

### `mereka-lms/aspects-alerts` (4)

- **ClickHousePodDown** (severity=critical, team=—)
    - phantom `kube_deployment_status_available_replicas` `LIKELY_TYPO` → try `kube_deployment_status_replicas_available`
- **SupersetPodDown** (severity=critical, team=—)
    - phantom `kube_deployment_status_available_replicas` `LIKELY_TYPO` → try `kube_deployment_status_replicas_available`
- **RalphPodDown** (severity=critical, team=—)
    - phantom `kube_deployment_status_available_replicas` `LIKELY_TYPO` → try `kube_deployment_status_replicas_available`
- **SupersetWorkerDown** (severity=warning, team=—)
    - phantom `kube_deployment_status_available_replicas` `LIKELY_TYPO` → try `kube_deployment_status_replicas_available`

### `mereka-lms/auth-alerts` (1)

- **SessionStoreUnavailable** (severity=critical, team=—)
    - phantom `redis_up` `NO_TRACE`

### `mereka-lms/caddy-alerts` (2)

- **CaddyHighErrorRate** (severity=critical, team=—)
    - phantom `caddy_http_requests_total` `NO_TRACE`
- **CaddyHighLatency** (severity=warning, team=—)
    - phantom `caddy_http_request_duration_seconds_bucket` `LIKELY_TYPO` → try `grafana_http_request_duration_seconds_bucket`

### `mereka-lms/credentials-alerts` (6)

- **VCIssuanceLatencyHigh** (severity=warning, team=—)
    - phantom `credentials_vc_issuance_duration_seconds_bucket` `NO_TRACE`
- **VCIssuanceFailureSpike** (severity=critical, team=—)
    - phantom `credentials_vc_signing_errors_total` `NO_TRACE`
- **VCClaimTokenExpiryHigh** (severity=warning, team=—)
    - phantom `credentials_vc_claim_tokens_generated_total` `NO_TRACE`
    - phantom `credentials_vc_claim_tokens_expired_total` `NO_TRACE`
- **VCVerificationEndpointDown** (severity=critical, team=—)
    - phantom `credentials_vc_verification_requests_total` `NO_TRACE`
- **VCDIDDocumentUnavailable** (severity=critical, team=—)
    - phantom `credentials_did_document_requests_total` `NO_TRACE`
- **VCSigningKeyExpiringSoon** (severity=warning, team=—)
    - phantom `credentials_vc_signing_key_created_timestamp` `NO_TRACE`

### `mereka-lms/enterprise-alerts` (8)

- **EnterpriseCatalogMemoryHigh** (severity=warning, team=—)
    - phantom `container_spec_memory_limit_bytes` `FAMILY_EXISTS`
- **EnterpriseCatalogCPUHigh** (severity=warning, team=—)
    - phantom `container_spec_cpu_period` `FAMILY_EXISTS`
    - phantom `container_spec_cpu_quota` `FAMILY_EXISTS`
- **EnterpriseAccessMemoryHigh** (severity=warning, team=—)
    - phantom `container_spec_memory_limit_bytes` `FAMILY_EXISTS`
- **EnterpriseAccessCPUHigh** (severity=warning, team=—)
    - phantom `container_spec_cpu_period` `FAMILY_EXISTS`
    - phantom `container_spec_cpu_quota` `FAMILY_EXISTS`
- **EnterpriseSubsidyMemoryHigh** (severity=warning, team=—)
    - phantom `container_spec_memory_limit_bytes` `FAMILY_EXISTS`
- **EnterpriseSubsidyCPUHigh** (severity=warning, team=—)
    - phantom `container_spec_cpu_period` `FAMILY_EXISTS`
    - phantom `container_spec_cpu_quota` `FAMILY_EXISTS`
- **LicenseManagerMemoryHigh** (severity=warning, team=—)
    - phantom `container_spec_memory_limit_bytes` `FAMILY_EXISTS`
- **LicenseManagerCPUHigh** (severity=warning, team=—)
    - phantom `container_spec_cpu_period` `FAMILY_EXISTS`
    - phantom `container_spec_cpu_quota` `FAMILY_EXISTS`

### `mereka-lms/externalsecret-alerts` (2)

- **ExternalSecretSyncFailure** (severity=critical, team=—)
    - phantom `externalsecret_status_condition` `NO_TRACE`
- **ExternalSecretStaleSync** (severity=warning, team=—)
    - phantom `externalsecret_status_condition` `NO_TRACE`

### `mereka-lms/library-alerts` (5)

- **ContentLibraryCrossTenantDenialSpike** (severity=critical, team=—)
    - phantom `content_library_cross_tenant_denial_total` `NO_TRACE`
- **ContentLibraryPublishFailureSpike** (severity=critical, team=—)
    - phantom `content_library_publish_total` `NO_TRACE`
- **ContentLibrarySearchIndexLag** (severity=warning, team=—)
    - phantom `content_library_search_index_lag_seconds` `NO_TRACE`
- **ContentLibraryAPILatencyHigh** (severity=warning, team=—)
    - phantom `content_library_api_latency_seconds_bucket` `NO_TRACE`
- **ContentLibraryExportLarge** (severity=info, team=—)
    - phantom `content_library_export_size_bytes` `NO_TRACE`

### `mereka-lms/lms-alerts` (8)

- **LMSPodMemoryHigh** (severity=warning, team=—)
    - phantom `container_spec_memory_limit_bytes` `FAMILY_EXISTS`
- **LMSPodMemoryCritical** (severity=critical, team=—)
    - phantom `container_spec_memory_limit_bytes` `FAMILY_EXISTS`
- **LMSPodCPUHigh** (severity=warning, team=—)
    - phantom `container_spec_cpu_period` `FAMILY_EXISTS`
    - phantom `container_spec_cpu_quota` `FAMILY_EXISTS`
- **CMSPodMemoryHigh** (severity=warning, team=—)
    - phantom `container_spec_memory_limit_bytes` `FAMILY_EXISTS`
- **MySQLHighConnectionUtilization** (severity=warning, team=—)
    - phantom `mysql_global_status_threads_connected` `NO_TRACE`
    - phantom `mysql_global_variables_max_connections` `NO_TRACE`
- **MySQLSlowQueriesSpike** (severity=warning, team=—)
    - phantom `mysql_global_status_slow_queries` `NO_TRACE`
- **RedisRejectedConnectionsSpike** (severity=warning, team=—)
    - phantom `redis_rejected_connections_total` `NO_TRACE`
- **RedisEvictionsSpike** (severity=warning, team=—)
    - phantom `redis_evicted_keys_total` `NO_TRACE`

### `mereka-lms/services-alerts` (1)

- **PurchaseGatewayHighErrorRate** (severity=critical, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`

### `mereka-lms/slo-burn-rate-rules` (20)

- **mereka:http_requests:availability_ratio_5m** (severity=—, team=—)
    - phantom `caddy_http_requests_total` `NO_TRACE`
- **mereka:http_requests:availability_ratio_30m** (severity=—, team=—)
    - phantom `caddy_http_requests_total` `NO_TRACE`
- **mereka:http_requests:availability_ratio_1h** (severity=—, team=—)
    - phantom `caddy_http_requests_total` `NO_TRACE`
- **mereka:http_requests:availability_ratio_6h** (severity=—, team=—)
    - phantom `caddy_http_requests_total` `NO_TRACE`
- **mereka:http_requests:availability_ratio_5m** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:http_requests:availability_ratio_30m** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:http_requests:availability_ratio_1h** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:http_requests:availability_ratio_6h** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:http_requests:availability_ratio_5m** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:http_requests:availability_ratio_30m** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:http_requests:availability_ratio_1h** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:http_requests:availability_ratio_6h** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:http_requests:availability_ratio_5m** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:http_requests:availability_ratio_30m** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:http_requests:availability_ratio_1h** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:http_requests:availability_ratio_6h** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:slo:error_budget_remaining_ratio** (severity=—, team=—)
    - phantom `caddy_http_requests_total` `NO_TRACE`
- **mereka:slo:error_budget_remaining_ratio** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:slo:journey_error_budget_remaining_ratio** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **mereka:slo:journey_error_budget_remaining_ratio** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`

### `mereka-lms/video-alerts` (7)

- **MuxDeliveryMinutesWarning** (severity=warning, team=—)
    - phantom `video_delivery_minutes_monthly` `NO_TRACE`
- **MuxDeliveryMinutesCritical** (severity=critical, team=—)
    - phantom `video_delivery_minutes_monthly` `NO_TRACE`
- **MuxStorageCostHigh** (severity=warning, team=—)
    - phantom `mux_storage_cost_usd_monthly` `NO_TRACE`
- **MuxTranscodeSuccessRateLow** (severity=warning, team=—)
    - phantom `video_transcode_success_rate` `NO_TRACE`
- **MuxProcessingQueueBacklog** (severity=warning, team=—)
    - phantom `mux_asset_processing_queue_depth` `NO_TRACE`
- **MuxErroredAssetsGrowing** (severity=warning, team=—)
    - phantom `mux_asset_total` `NO_TRACE`
- **MuxPollStale** (severity=warning, team=—)
    - phantom `mux_poll_last_success_timestamp` `NO_TRACE`

## Phantom rules — bbi-infrastructure

93 phantom rule entries.

### `agent-e/agent-e-prod` (6)

- **AgentEApiHighErrorRate** (severity=warning, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **AgentECostCapApproaching** (severity=warning, team=—)
    - phantom `agente_llm_cost_usd_total` `FAMILY_EXISTS`
- **AgentECostCapExceeded** (severity=critical, team=—)
    - phantom `agente_cost_cap_exceeded_total` `FAMILY_EXISTS`
- **AgentERunBudgetCapExceeded** (severity=warning, team=—)
    - phantom `agente_cost_cap_exceeded_total` `FAMILY_EXISTS`
- **AgentEDbPoolSaturationHigh** (severity=warning, team=—)
    - phantom `agente_db_pool_size` `FAMILY_EXISTS`
    - phantom `agente_db_pool_in_use` `FAMILY_EXISTS`
- **AgentEDbAcquireWaitHigh** (severity=warning, team=—)
    - phantom `agente_db_pool_acquire_wait_seconds_bucket` `FAMILY_EXISTS`

### `monitoring/app-baseline-alerts` (1)

- **AppHighMemoryUsage** (severity=warning, team=—)
    - phantom `container_spec_memory_limit_bytes` `FAMILY_EXISTS`

### `monitoring/authentik-inventory-alerts` (3)

- **AuthentikBackupSizeRegressionWarning** (severity=warning, team=platform)
    - phantom `authentik_inventory:backup_size_bytes:avg7d` `FAMILY_EXISTS`
    - phantom `authentik_inventory_backup_size_bytes` `FAMILY_EXISTS`
- **AuthentikBackupSizeRegressionCritical** (severity=critical, team=platform)
    - phantom `authentik_inventory:backup_size_bytes:avg7d` `FAMILY_EXISTS`
    - phantom `authentik_inventory_backup_size_bytes` `FAMILY_EXISTS`
- **AuthentikOrphanApplications** (severity=warning, team=platform)
    - phantom `authentik_inventory_orphan_application_count` `FAMILY_EXISTS`

### `monitoring/bbi-comprehensive-alerts` (14)

- **PostgresHighConnections** (severity=warning, team=platform)
    - phantom `pg_stat_activity_count` `NO_TRACE`
- **PostgresSlowQueries** (severity=warning, team=platform)
    - phantom `pg_stat_statements_seconds_total` `NO_TRACE`
    - phantom `pg_stat_statements_calls_total` `NO_TRACE`
- **CertificateExpiringSoon** (severity=warning, team=platform)
    - phantom `certmanager_certificate_expiration_timestamp_seconds` `NO_TRACE`
- **CertificateExpiredOrExpiring** (severity=critical, team=platform)
    - phantom `certmanager_certificate_expiration_timestamp_seconds` `NO_TRACE`
- **CertManagerNotReady** (severity=warning, team=platform)
    - phantom `certmanager_certificate_ready_status` `NO_TRACE`
- **PM2AppCrashed** (severity=critical, team=platform)
    - phantom `pm2_process_status` `NO_TRACE`
- **PM2AppHighRestarts** (severity=warning, team=platform)
    - phantom `pm2_process_restart_count` `NO_TRACE`
- **PM2AppHighMemory** (severity=warning, team=platform)
    - phantom `pm2_process_memory_bytes` `NO_TRACE`
- **SLOFastBurn** (severity=critical, team=platform)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **SLOSlowBurn** (severity=warning, team=platform)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **ArgoCDAppOutOfSync** (severity=warning, team=platform)
    - phantom `argocd_app_info` `NO_TRACE`
- **ExternalSecretSyncFailed** (severity=warning, team=platform)
    - phantom `externalsecret_status_condition` `NO_TRACE`
- **CertificateRenewalOverdue** (severity=critical, team=platform)
    - phantom `certmanager_certificate_expiration_timestamp_seconds` `NO_TRACE`
    - phantom `certmanager_certificate_ready_status` `NO_TRACE`
- **KyvernoPolicyViolation** (severity=warning, team=platform)
    - phantom `kyverno_policy_results_total` `NO_TRACE`

### `monitoring/climate-exchange-default-alerts` (1)

- **ClimateExchangeCertExpiringSoon** (severity=warning, team=—)
    - phantom `certmanager_certificate_expiration_timestamp_seconds` `NO_TRACE`

### `monitoring/climate-exchange-slo-rules` (14)

- **slo:sli_error:ratio_rate5m** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **slo:sli_error:ratio_rate30m** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **slo:sli_error:ratio_rate1h** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **slo:sli_error:ratio_rate2h** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **slo:sli_error:ratio_rate6h** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **slo:sli_error:ratio_rate1d** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **slo:sli_error:ratio_rate3d** (severity=—, team=—)
    - phantom `http_requests_total` `LIKELY_TYPO` → try `requests_total`
- **slo:sli_error:ratio_rate5m** (severity=—, team=—)
    - phantom `http_request_duration_seconds_bucket` `LIKELY_TYPO` → try `request_duration_seconds_bucket`
    - phantom `http_request_duration_seconds_count` `LIKELY_TYPO` → try `request_duration_seconds_count`
- **slo:sli_error:ratio_rate30m** (severity=—, team=—)
    - phantom `http_request_duration_seconds_bucket` `LIKELY_TYPO` → try `request_duration_seconds_bucket`
    - phantom `http_request_duration_seconds_count` `LIKELY_TYPO` → try `request_duration_seconds_count`
- **slo:sli_error:ratio_rate1h** (severity=—, team=—)
    - phantom `http_request_duration_seconds_bucket` `LIKELY_TYPO` → try `request_duration_seconds_bucket`
    - phantom `http_request_duration_seconds_count` `LIKELY_TYPO` → try `request_duration_seconds_count`
- **slo:sli_error:ratio_rate2h** (severity=—, team=—)
    - phantom `http_request_duration_seconds_bucket` `LIKELY_TYPO` → try `request_duration_seconds_bucket`
    - phantom `http_request_duration_seconds_count` `LIKELY_TYPO` → try `request_duration_seconds_count`
- **slo:sli_error:ratio_rate6h** (severity=—, team=—)
    - phantom `http_request_duration_seconds_bucket` `LIKELY_TYPO` → try `request_duration_seconds_bucket`
    - phantom `http_request_duration_seconds_count` `LIKELY_TYPO` → try `request_duration_seconds_count`
- **slo:sli_error:ratio_rate1d** (severity=—, team=—)
    - phantom `http_request_duration_seconds_bucket` `LIKELY_TYPO` → try `request_duration_seconds_bucket`
    - phantom `http_request_duration_seconds_count` `LIKELY_TYPO` → try `request_duration_seconds_count`
- **slo:sli_error:ratio_rate3d** (severity=—, team=—)
    - phantom `http_request_duration_seconds_bucket` `LIKELY_TYPO` → try `request_duration_seconds_bucket`
    - phantom `http_request_duration_seconds_count` `LIKELY_TYPO` → try `request_duration_seconds_count`

### `monitoring/monitoring-kube-prometheus-alertmanager.rules` (1)

- **AlertmanagerMembersInconsistent** (severity=critical, team=—)
    - phantom `alertmanager_cluster_members` `FAMILY_EXISTS`

### `monitoring/monitoring-kube-prometheus-etcd` (1)

- **etcdGRPCRequestsSlow** (severity=critical, team=—)
    - phantom `grpc_server_handling_seconds_bucket` `FAMILY_EXISTS`

### `monitoring/monitoring-kube-prometheus-k8s.rules.container-memory-swap` (1)

- **node_namespace_pod_container:container_memory_swap** (severity=—, team=—)
    - phantom `container_memory_swap` `LIKELY_TYPO` → try `container_memory_rss`

### `monitoring/monitoring-kube-prometheus-kube-scheduler.rules` (9)

- **cluster_quantile:scheduler_scheduling_attempt_duration_seconds:histogram_quantile** (severity=—, team=—)
    - phantom `scheduler_scheduling_attempt_duration_seconds_bucket` `NO_TRACE`
- **cluster_quantile:scheduler_scheduling_algorithm_duration_seconds:histogram_quantile** (severity=—, team=—)
    - phantom `scheduler_scheduling_algorithm_duration_seconds_bucket` `NO_TRACE`
- **cluster_quantile:scheduler_pod_scheduling_sli_duration_seconds:histogram_quantile** (severity=—, team=—)
    - phantom `scheduler_pod_scheduling_sli_duration_seconds_bucket` `NO_TRACE`
- **cluster_quantile:scheduler_scheduling_attempt_duration_seconds:histogram_quantile** (severity=—, team=—)
    - phantom `scheduler_scheduling_attempt_duration_seconds_bucket` `NO_TRACE`
- **cluster_quantile:scheduler_scheduling_algorithm_duration_seconds:histogram_quantile** (severity=—, team=—)
    - phantom `scheduler_scheduling_algorithm_duration_seconds_bucket` `NO_TRACE`
- **cluster_quantile:scheduler_pod_scheduling_sli_duration_seconds:histogram_quantile** (severity=—, team=—)
    - phantom `scheduler_pod_scheduling_sli_duration_seconds_bucket` `NO_TRACE`
- **cluster_quantile:scheduler_scheduling_attempt_duration_seconds:histogram_quantile** (severity=—, team=—)
    - phantom `scheduler_scheduling_attempt_duration_seconds_bucket` `NO_TRACE`
- **cluster_quantile:scheduler_scheduling_algorithm_duration_seconds:histogram_quantile** (severity=—, team=—)
    - phantom `scheduler_scheduling_algorithm_duration_seconds_bucket` `NO_TRACE`
- **cluster_quantile:scheduler_pod_scheduling_sli_duration_seconds:histogram_quantile** (severity=—, team=—)
    - phantom `scheduler_pod_scheduling_sli_duration_seconds_bucket` `NO_TRACE`

### `monitoring/monitoring-kube-prometheus-kube-state-metrics` (4)

- **KubeStateMetricsListErrors** (severity=critical, team=—)
    - phantom `kube_state_metrics_list_total` `FAMILY_EXISTS`
- **KubeStateMetricsWatchErrors** (severity=critical, team=—)
    - phantom `kube_state_metrics_watch_total` `FAMILY_EXISTS`
- **KubeStateMetricsShardingMismatch** (severity=critical, team=—)
    - phantom `kube_state_metrics_total_shards` `FAMILY_EXISTS`
- **KubeStateMetricsShardsMissing** (severity=critical, team=—)
    - phantom `kube_state_metrics_shard_ordinal` `FAMILY_EXISTS`
    - phantom `kube_state_metrics_total_shards` `FAMILY_EXISTS`

### `monitoring/monitoring-kube-prometheus-kubernetes-storage` (4)

- **KubePersistentVolumeFillingUp** (severity=critical, team=—)
    - phantom `kube_persistentvolumeclaim_labels` `LIKELY_TYPO` → try `kube_persistentvolumeclaim_info`
- **KubePersistentVolumeFillingUp** (severity=warning, team=—)
    - phantom `kube_persistentvolumeclaim_labels` `LIKELY_TYPO` → try `kube_persistentvolumeclaim_info`
- **KubePersistentVolumeInodesFillingUp** (severity=critical, team=—)
    - phantom `kube_persistentvolumeclaim_labels` `LIKELY_TYPO` → try `kube_persistentvolumeclaim_info`
- **KubePersistentVolumeInodesFillingUp** (severity=warning, team=—)
    - phantom `kube_persistentvolumeclaim_labels` `LIKELY_TYPO` → try `kube_persistentvolumeclaim_info`

### `monitoring/monitoring-kube-prometheus-kubernetes-system-apiserver` (1)

- **KubeAggregatedAPIErrors** (severity=warning, team=—)
    - phantom `aggregator_unavailable_apiservice_total` `FAMILY_EXISTS`

### `monitoring/monitoring-kube-prometheus-kubernetes-system-kubelet` (8)

- **KubeNodeUnreachable** (severity=warning, team=—)
    - phantom `kube_node_spec_taint` `FAMILY_EXISTS`
- **KubeNodeEviction** (severity=info, team=—)
    - phantom `kubelet_evictions` `FAMILY_EXISTS`
- **KubeletClientCertificateExpiration** (severity=warning, team=—)
    - phantom `kubelet_certificate_manager_client_ttl_seconds` `FAMILY_EXISTS`
- **KubeletClientCertificateExpiration** (severity=critical, team=—)
    - phantom `kubelet_certificate_manager_client_ttl_seconds` `FAMILY_EXISTS`
- **KubeletServerCertificateExpiration** (severity=warning, team=—)
    - phantom `kubelet_certificate_manager_server_ttl_seconds` `FAMILY_EXISTS`
- **KubeletServerCertificateExpiration** (severity=critical, team=—)
    - phantom `kubelet_certificate_manager_server_ttl_seconds` `FAMILY_EXISTS`
- **KubeletClientCertificateRenewalErrors** (severity=warning, team=—)
    - phantom `kubelet_certificate_manager_client_expiration_renew_errors` `FAMILY_EXISTS`
- **KubeletServerCertificateRenewalErrors** (severity=warning, team=—)
    - phantom `kubelet_server_expiration_renew_errors` `FAMILY_EXISTS`

### `monitoring/monitoring-kube-prometheus-node-exporter` (5)

- **NodeRAIDDegraded** (severity=critical, team=—)
    - phantom `node_md_disks_required` `FAMILY_EXISTS`
    - phantom `node_md_disks` `FAMILY_EXISTS`
- **NodeRAIDDiskFailure** (severity=warning, team=—)
    - phantom `node_md_disks` `FAMILY_EXISTS`
- **NodeSystemdServiceFailed** (severity=warning, team=—)
    - phantom `node_systemd_unit_state` `FAMILY_EXISTS`
- **NodeSystemdServiceCrashlooping** (severity=warning, team=—)
    - phantom `node_systemd_service_restart_total` `FAMILY_EXISTS`
- **NodeBondingDegraded** (severity=warning, team=—)
    - phantom `node_bonding_slaves` `FAMILY_EXISTS`
    - phantom `node_bonding_active` `FAMILY_EXISTS`

### `monitoring/monitoring-kube-prometheus-node.rules` (1)

- **node:node_num_cpu:sum** (severity=—, team=—)
    - phantom `node_namespace_pod:kube_pod_info` `LIKELY_TYPO` → try `node_namespace_pod:kube_pod_info:`

### `monitoring/monitoring-kube-prometheus-prometheus` (4)

- **PrometheusSDRefreshFailure** (severity=warning, team=—)
    - phantom `prometheus_sd_refresh_failures_total` `LIKELY_TYPO` → try `prometheus_sd_http_failures_total`
- **PrometheusRemoteStorageFailures** (severity=critical, team=—)
    - phantom `prometheus_remote_storage_samples_total` `LIKELY_TYPO` → try `prometheus_remote_storage_samples_in_total`
    - phantom `prometheus_remote_storage_failed_samples_total` `LIKELY_TYPO` → try `prometheus_remote_storage_samples_in_total`
    - phantom `prometheus_remote_storage_succeeded_samples_total` `FAMILY_EXISTS`
    - phantom `prometheus_remote_storage_samples_failed_total` `LIKELY_TYPO` → try `prometheus_remote_storage_samples_in_total`
- **PrometheusRemoteWriteBehind** (severity=critical, team=—)
    - phantom `prometheus_remote_storage_queue_highest_sent_timestamp_seconds` `FAMILY_EXISTS`
    - phantom `prometheus_remote_storage_queue_highest_timestamp_seconds` `LIKELY_TYPO` → try `prometheus_remote_storage_highest_timestamp_in_seconds`
- **PrometheusRemoteWriteDesiredShards** (severity=warning, team=—)
    - phantom `prometheus_remote_storage_shards_max` `FAMILY_EXISTS`
    - phantom `prometheus_remote_storage_shards_desired` `FAMILY_EXISTS`

### `monitoring/observability-self-monitoring` (1)

- **ExternalSecretSyncFailingRate** (severity=warning, team=platform-dr)
    - phantom `externalsecrets_sync_calls_error` `NO_TRACE`

### `monitoring/postgres-dr-alerts` (3)

- **PostgresConnectionsNearLimit** (severity=warning, team=platform-dr)
    - phantom `pg_settings_max_connections` `NO_TRACE`
    - phantom `pg_stat_database_numbackends` `NO_TRACE`
- **PostgresReplicationLagHigh** (severity=warning, team=platform-dr)
    - phantom `pg_stat_replication_lag_seconds` `NO_TRACE`
- **PostgresWalArchivingFailed** (severity=critical, team=platform-dr)
    - phantom `pg_stat_archiver_failed_count` `NO_TRACE`

### `monitoring/storage-dr-rules` (3)

- **LonghornBackupTargetEmpty** (severity=critical, team=platform-dr)
    - phantom `longhorn_setting` `NO_TRACE`
- **LonghornBackupTargetMetricMissing** (severity=warning, team=platform-dr)
    - phantom `longhorn_setting` `NO_TRACE`
- **VeleroBSLUnavailable** (severity=critical, team=platform-dr)
    - phantom `velero_backup_storage_location_available` `FAMILY_EXISTS`

### `team-analytics/team-analytics-silent-failures` (5)

- **PipelineScheduleStuck** (severity=critical, team=platform-eng)
    - phantom `pipeline_run_started_total` `FAMILY_EXISTS`
- **UpsertBatchSilentDrop** (severity=critical, team=platform-eng)
    - phantom `upsert_batch_total` `NO_TRACE`
- **EnrichmentBacklogGrowing** (severity=warning, team=platform-eng)
    - phantom `enrichment_backlog_rows` `NO_TRACE`
- **ActivityTimeoutRateHigh** (severity=warning, team=platform-eng)
    - phantom `temporal_activity_execution_total` `NO_TRACE`
    - phantom `temporal_activity_execution_failed_total` `NO_TRACE`
- **ApiCostAnomaly** (severity=warning, team=platform-eng)
    - phantom `github_api_calls_total` `NO_TRACE`

### `velero/velero-dr-alerts` (1)

- **VeleroBackupZeroBytes** (severity=warning, team=platform-dr)
    - phantom `velero_backup_total_items` `LIKELY_TYPO` → try `velero_backup_items_total`

### `weaviate/weaviate-alerts` (2)

- **WeaviateHighQueryLatency** (severity=warning, team=—)
    - phantom `weaviate_query_dimensions_bucket` `FAMILY_EXISTS`
- **WeaviateHighMemoryUsage** (severity=warning, team=—)
    - phantom `container_spec_memory_limit_bytes` `FAMILY_EXISTS`

## Recommended next actions

1. **LIKELY_TYPO (13)** — fix directly. These are rule authoring bugs. Each is a silent-detection incident waiting to happen.
2. **FAMILY_EXISTS (38)** — audit exporter configs. Either the variant no longer exists (upstream rename) or a collector is disabled.
3. **NO_TRACE (50)** — classify as "speculative, kept for future instrumentation" or "broken, drop it". Add a `speculative: "true"` label on rules we intentionally ship before instrumentation to make the difference machine-checkable.

## Prevention

Add a CI gate that runs this audit against the rendered rule set + a sample live Prometheus inventory. Any rule entry whose expression references a phantom metric AND lacks a `speculative=true` label fails the build.

## Artifacts

- `/tmp/prom-audit/rules.json` — raw PrometheusRules dump from prod 2026-04-21
- `/tmp/prom-audit/metric-names.json` — Prometheus `__name__` inventory snapshot
- `/tmp/prom-audit/phantoms.jsonl` — machine-readable phantom entries
- `/tmp/prom-audit/extract.py` + `classify.py` + `gen-report.py` — generator scripts (to be promoted into `scripts/qa/` in a follow-up)