# OBS-053..057 manifest readiness snapshot

Repo: /home/gurpreet/projects/k8s/mereka-lms
Date: 2026-02-27T02:26:47Z

## Monitoring kustomization includes
7:  - name: mux-delivery-monitor-script
11:  - servicemonitor-caddy.yaml
12:  - servicemonitor-credentials.yaml
13:  - servicemonitor-purchase-gateway.yaml
14:  - servicemonitor-lms.yaml
15:  - servicemonitor-cms.yaml
16:  - servicemonitor-discovery.yaml
17:  - servicemonitor-ecommerce.yaml
18:  - servicemonitor-forum.yaml
19:  - servicemonitor-mysql.yaml
20:  - servicemonitor-mfe.yaml
21:  - servicemonitor-redis.yaml
22:  - servicemonitor-enterprise.yaml
23:  - servicemonitor-xqueue.yaml
24:  - prometheusrule-caddy.yaml
25:  - prometheusrule-credentials.yaml
26:  - prometheusrule-email.yaml
27:  - prometheusrule-libraries.yaml
28:  - prometheusrule-lms.yaml
29:  - prometheusrule-ora2.yaml
30:  - prometheusrule-enterprise.yaml
31:  - prometheusrule-services.yaml
32:  - prometheusrule-xqueue.yaml
33:  - prometheusrule-tenant-isolation.yaml
34:  - prometheusrule-velero.yaml
35:  - prometheusrule-slo.yaml
36:  - prometheusrule-auth.yaml
37:  - slo-burn-rate-rules.yaml
39:  - servicemonitor-mux.yaml
40:  - prometheusrule-video.yaml
41:  - prometheusrule-externalsecrets.yaml

- servicemonitor-caddy.yaml: present
- servicemonitor-mfe.yaml: present
- servicemonitor-forum.yaml: present
- servicemonitor-discovery.yaml: present
- servicemonitor-ecommerce.yaml: present
- servicemonitor-credentials.yaml: present
- servicemonitor-purchase-gateway.yaml: present
- servicemonitor-xqueue.yaml: present
- servicemonitor-mux.yaml: present
- prometheusrule-caddy.yaml: present
- prometheusrule-services.yaml: present
- prometheusrule-slo.yaml: present
- prometheusrule-video.yaml: present
- prometheusrule-ora2.yaml: present

## Runtime checker assertions now tracked

## Runtime assertion pairs exercised by verify-observability-runtime.sh
- caddy: monitor `caddy-metrics`, rule `caddy-alerts`
- mfe: monitor `mfe-metrics`, rule `services-alerts`
- forum: monitor `forum-metrics`
- discovery: monitor `discovery-metrics`
- ecommerce: monitor `ecommerce-metrics`
- credentials: monitor `credentials-metrics`
- purchase-gateway: monitor `purchase-gateway-metrics`
- slo: rule `slo-recording-rules`
- video: rule `video-alerts`
- ora2: rule `ora2-operations`
- dev/kind/local only: monitor `xqueue-metrics`, monitor `mux-delivery-monitor`

## Remaining work (for full closure)
1. Execute `run-observability-first-class.sh --mode runtime --strict` per lane and capture evidence artifacts.
2. If any checks fail, patch manifests/labels/namespaces, sync environment, and rerun only the failing lane.
3. Close OBS-053..057 only after evidence identity parity in `observability-first-class-runtime-evidence-index.json` and component wiring evidence files are present and passing.
