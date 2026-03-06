# Observability Coverage Matrix

- generated_at: 2026-03-03T04:11:40Z
- mode: runtime
- strict: true
- identity: env=nonprod;profile=nonprod;context=rke2-nonprod;app_ns=mereka-lms;monitoring_ns=monitoring
- mode_required_runtime: true

## Summary

|Status|Count|
|---|---:|
|pass|74|
|fail|7|
|skip|0|
|total|81|

## repo Checks

### Pass

- service-monitor-file: servicemonitor-lms.yaml
- service-monitor-in-kustomization: servicemonitor-lms.yaml
- service-monitor-file: servicemonitor-cms.yaml
- service-monitor-in-kustomization: servicemonitor-cms.yaml
- service-monitor-file: servicemonitor-mysql.yaml
- service-monitor-in-kustomization: servicemonitor-mysql.yaml
- service-monitor-file: servicemonitor-redis.yaml
- service-monitor-in-kustomization: servicemonitor-redis.yaml
- service-monitor-file: servicemonitor-enterprise.yaml
- service-monitor-in-kustomization: servicemonitor-enterprise.yaml
- service-monitor-file: servicemonitor-xqueue.yaml
- service-monitor-in-kustomization: servicemonitor-xqueue.yaml
- service-monitor-file: servicemonitor-mux.yaml
- service-monitor-in-kustomization: servicemonitor-mux.yaml
- service-monitor-file: servicemonitor-caddy.yaml
- service-monitor-in-kustomization: servicemonitor-caddy.yaml
- service-monitor-file: servicemonitor-mfe.yaml
- service-monitor-in-kustomization: servicemonitor-mfe.yaml
- service-monitor-file: servicemonitor-forum.yaml
- service-monitor-in-kustomization: servicemonitor-forum.yaml
- service-monitor-file: servicemonitor-discovery.yaml
- service-monitor-in-kustomization: servicemonitor-discovery.yaml
- service-monitor-file: servicemonitor-ecommerce.yaml
- service-monitor-in-kustomization: servicemonitor-ecommerce.yaml
- service-monitor-file: servicemonitor-credentials.yaml
- service-monitor-in-kustomization: servicemonitor-credentials.yaml
- service-monitor-file: servicemonitor-purchase-gateway.yaml
- service-monitor-in-kustomization: servicemonitor-purchase-gateway.yaml
- prometheusrule-file: prometheusrule-lms.yaml
- prometheusrule-in-kustomization: prometheusrule-lms.yaml
- prometheusrule-file: prometheusrule-enterprise.yaml
- prometheusrule-in-kustomization: prometheusrule-enterprise.yaml
- prometheusrule-file: prometheusrule-velero.yaml
- prometheusrule-in-kustomization: prometheusrule-velero.yaml
- prometheusrule-file: prometheusrule-slo.yaml
- prometheusrule-in-kustomization: prometheusrule-slo.yaml
- prometheusrule-file: prometheusrule-auth.yaml
- prometheusrule-in-kustomization: prometheusrule-auth.yaml
- prometheusrule-file: prometheusrule-caddy.yaml
- prometheusrule-in-kustomization: prometheusrule-caddy.yaml
- prometheusrule-file: prometheusrule-services.yaml
- prometheusrule-in-kustomization: prometheusrule-services.yaml
- prometheusrule-file: prometheusrule-video.yaml
- prometheusrule-in-kustomization: prometheusrule-video.yaml
- prometheusrule-file: prometheusrule-email.yaml
- prometheusrule-in-kustomization: prometheusrule-email.yaml
- prometheusrule-file: prometheusrule-libraries.yaml
- prometheusrule-in-kustomization: prometheusrule-libraries.yaml
- prometheusrule-file: prometheusrule-ora2.yaml
- prometheusrule-in-kustomization: prometheusrule-ora2.yaml
- prometheusrule-file: prometheusrule-credentials.yaml
- prometheusrule-in-kustomization: prometheusrule-credentials.yaml
- prometheusrule-extra: prometheusrule-externalsecrets.yaml
- prometheusrule-extra: prometheusrule-tenant-isolation.yaml
- prometheusrule-extra: prometheusrule-xqueue.yaml

### Fail


### Skip


## runtime Checks

### Pass

- service-monitor-live: lms-metrics
- service-monitor-live: cms-metrics
- service-monitor-live: mysql-metrics
- service-monitor-live: redis-metrics
- service-monitor-live: enterprise-catalog-metrics
- service-monitor-live: xqueue-metrics
- service-monitor-live: mux-delivery-monitor
- prometheusrule-live: lms-alerts
- prometheusrule-live: enterprise-alerts
- prometheusrule-live: velero-alerts
- prometheusrule-live: slo-recording-rules
- prometheusrule-live: auth-alerts
- prometheusrule-live: caddy-alerts
- prometheusrule-live: services-alerts
- prometheusrule-live: video-alerts
- prometheusrule-live: email-alerts
- prometheusrule-live: library-alerts
- prometheusrule-live: ora2-operations
- prometheusrule-live: credentials-alerts

### Fail

- service-monitor-live: caddy-metrics
- service-monitor-live: mfe-metrics
- service-monitor-live: forum-metrics
- service-monitor-live: discovery-metrics
- service-monitor-live: ecommerce-metrics
- service-monitor-live: credentials-metrics
- service-monitor-live: purchase-gateway-metrics

### Skip


## Overall Failures

- runtime/service-monitor-live: caddy-metrics
- runtime/service-monitor-live: mfe-metrics
- runtime/service-monitor-live: forum-metrics
- runtime/service-monitor-live: discovery-metrics
- runtime/service-monitor-live: ecommerce-metrics
- runtime/service-monitor-live: credentials-metrics
- runtime/service-monitor-live: purchase-gateway-metrics

