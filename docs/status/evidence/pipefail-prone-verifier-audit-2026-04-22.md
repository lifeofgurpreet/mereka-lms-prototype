# Pipefail-prone verifier pipeline audit

> Bead `mereka-lms-0z5g.6` AC items 1–2. Generated 2026-04-22 by `docs/status/evidence/pipefail-prone-verifier-audit-2026-04-22.md` scan script.

## Scope

- Files scanned: `scripts/qa/*.sh`, `scripts/ops/*.sh`, `scripts/infra/*.sh`, `scripts/tenants/*.sh` (recursive)
- Pattern: `set -o pipefail` or `set -euo pipefail` combined with any `echo '...' | grep -q...` / `printf '...' | grep -q...` pipeline
- Risk: `grep -q` exits early on first match. With `pipefail`, the `echo` write gets EPIPE → exit 141 → whole pipeline returns 141 → `set -e` kills the script. Seen twice in prod CI (`verify-network-policies` 2026-04-20; krco smoke 2026-04-21).

## Summary — 121 files, 332 hits

| # hits | File | CI lane | Classification |
|---:|---|---|---|
| 13 | `scripts/qa/verify-platform-middleware.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 9 | `scripts/qa/deprecated/verify-footer-slot-evidence-rollback.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 8 | `scripts/qa/verify-domain-url-invariants.sh` | static | **active gate** (REMEDIATE) |
| 8 | `scripts/qa/verify-red-line-contract.sh` | static | **active gate** (REMEDIATE) |
| 8 | `scripts/qa/verify-slo-service-metrics.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 7 | `scripts/qa/verify-mfe-branding.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 7 | `scripts/qa/verify-observability-retention.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 7 | `scripts/qa/verify-ulmo-parity.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 6 | `scripts/qa/verify-analytics-key-elimination.sh` | static | **active gate** (REMEDIATE) |
| 6 | `scripts/qa/verify-binary-pinning-bbi-infra.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 6 | `scripts/qa/verify-brand-pack-schema.sh` | static | **active gate** (REMEDIATE) |
| 6 | `scripts/qa/verify-deployment-contract.sh` | static | **active gate** (REMEDIATE) |
| 6 | `scripts/qa/verify-observability-loki-labels.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 6 | `scripts/qa/verify-selector-hardening.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 6 | `scripts/qa/verify-slo-synthetic-drills.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 6 | `scripts/tenants/validate-tenant-brand-pack.sh` | static | **active gate** (REMEDIATE) |
| 5 | `scripts/qa/verify-ecommerce-worker-health.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 5 | `scripts/qa/verify-purchase-gateway-stripe.sh` | static | **active gate** (REMEDIATE) |
| 5 | `scripts/qa/verify-secrets-isolation.sh` | static | **active gate** (REMEDIATE) |
| 5 | `scripts/tenants/lib/runtime-proof-common.sh` | helper | helper (low risk) |
| 4 | `scripts/ops/rc-check.sh` | helper | helper (low risk) |
| 4 | `scripts/qa/deprecated/verify-gh-actions-cost-dashboard.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 4 | `scripts/qa/inventory_k8s_resources.sh` | helper | helper (low risk) |
| 4 | `scripts/qa/verify-analytics-hardening.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 4 | `scripts/qa/verify-analytics-undefined-regression.sh` | static | **active gate** (REMEDIATE) |
| 4 | `scripts/qa/verify-binary-pinning-pcp.sh` | static | **active gate** (REMEDIATE) |
| 4 | `scripts/qa/verify-design-tokens.sh` | static | **active gate** (REMEDIATE) |
| 4 | `scripts/qa/verify-disaster-recovery.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 4 | `scripts/qa/verify-eso-alerting.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 4 | `scripts/qa/verify-footer-variant-matrix.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 4 | `scripts/qa/verify-gdpr-compliance.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 4 | `scripts/qa/verify-mfe-runtime-contract.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 4 | `scripts/qa/verify-mfe-ulmo-migration.sh` | static | **active gate** (REMEDIATE) |
| 4 | `scripts/qa/verify-rke2-tenant-routes.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 4 | `scripts/qa/verify-workflow-gate-enforcement.sh` | static | **active gate** (REMEDIATE) |
| 3 | `scripts/infra/check-cert-sans.sh` | static | **active gate** (REMEDIATE) |
| 3 | `scripts/qa/deprecated/verify-email-ace-channels.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 3 | `scripts/qa/verify-a11y-regression-lane.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 3 | `scripts/qa/verify-admin-merge-exceptions.sh` | static | **active gate** (REMEDIATE) |
| 3 | `scripts/qa/verify-assessment-audit.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 3 | `scripts/qa/verify-branch-protection.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 3 | `scripts/qa/verify-credentials-issuer.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 3 | `scripts/qa/verify-credentials-readiness.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 3 | `scripts/qa/verify-enterprise-ui-review.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 3 | `scripts/qa/verify-import-dedup.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 3 | `scripts/qa/verify-k8s-deployment-spec.sh` | static | **active gate** (REMEDIATE) |
| 3 | `scripts/qa/verify-multisite-ux-consistency.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 3 | `scripts/qa/verify-tenant-branding-runtime.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 3 | `scripts/qa/verify-video-protection.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 2 | `scripts/qa/audit-analytics-pii.sh` | helper | helper (low risk) |
| 2 | `scripts/qa/no_environment_domains_in_base.sh` | helper | helper (low risk) |
| 2 | `scripts/qa/verify-a11y-contrast-focus.sh` | static | **active gate** (REMEDIATE) |
| 2 | `scripts/qa/verify-analytics-decision-gate.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 2 | `scripts/qa/verify-aspects-deployment-readiness.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 2 | `scripts/qa/verify-aspects-wiring.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 2 | `scripts/qa/verify-caddy-payments-route.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 2 | `scripts/qa/verify-content-libraries-v2-enterprise.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 2 | `scripts/qa/verify-cross-browser-branding-smoke.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 2 | `scripts/qa/verify-css-scoping.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 2 | `scripts/qa/verify-enterprise-mfe-nreum-clean.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 2 | `scripts/qa/verify-kustomize-structure.sh` | static | **active gate** (REMEDIATE) |
| 2 | `scripts/qa/verify-lighthouse-budgets.sh` | static | **active gate** (REMEDIATE) |
| 2 | `scripts/qa/verify-mako-template-syntax.sh` | static | **active gate** (REMEDIATE) |
| 2 | `scripts/qa/verify-multitenant-brand-platform.sh` | static | **active gate** (REMEDIATE) |
| 2 | `scripts/qa/verify-mux-alert-wiring.sh` | static | **active gate** (REMEDIATE) |
| 2 | `scripts/qa/verify-mux-secrets.sh` | static | **active gate** (REMEDIATE) |
| 2 | `scripts/qa/verify-observability-loki-deployment.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 2 | `scripts/qa/verify-security-hardening.sh` | static | **active gate** (REMEDIATE) |
| 2 | `scripts/qa/verify-slo-contracts.sh` | static | **active gate** (REMEDIATE) |
| 2 | `scripts/qa/verify-studio-sso-flow.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 2 | `scripts/qa/verify-vc-ops.sh` | static | **active gate** (REMEDIATE) |
| 2 | `scripts/qa/verify-video-observability.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/infra/create-release.sh` | helper | helper (low risk) |
| 1 | `scripts/infra/ensure-atlas-allowlist-gke-nodes.sh` | helper | helper (low risk) |
| 1 | `scripts/infra/repair-staging-routing.sh` | helper | helper (low risk) |
| 1 | `scripts/infra/seed-mongo-dev.sh` | helper | helper (low risk) |
| 1 | `scripts/infra/sync-production-config.sh` | helper | helper (low risk) |
| 1 | `scripts/qa/comprehensive-test.sh` | helper | helper (low risk) |
| 1 | `scripts/qa/deprecated/verify-email-push-code.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/deprecated/verify-gh-actions-cost-tracking.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/load-test-tenants.sh` | helper | helper (low risk) |
| 1 | `scripts/qa/scan-mux-credentials.sh` | helper | helper (low risk) |
| 1 | `scripts/qa/validate-deploy-contract.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-agent-context-lock.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-analytics-drift-guardrails.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-auth-sso-enterprise.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-container-hardening.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-deployment-critical-coverage.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-deployment-lanes.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-design-token-usage.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-durability-proof.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-enterprise-auth-contract.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-enterprise-observability.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-enterprise-secrets.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-enterprise-sso-readiness.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-forum-moderation.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-k8s-secrets-hygiene.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-kustomize-render.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-lane-identity.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-lms-rke2-validation.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-mfe-analytics-plugin-parity.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-mfe-footer-fallbacks.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-mfe-route-drift.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-mfe-version-pinning.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-mobile-secrets-inventory.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-multi-tenancy-foundation.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-mux-alerts.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-observability-runtime.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-pii-inventory.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-platform-admin-env.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-public-branding.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-release-automation.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-release-readiness.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-rke2-dev-readiness.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-secrets-infisical.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-slo-deployment-gate.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-studio-isolation.sh` | manual/deprecated | manual or deprecated (lower priority) |
| 1 | `scripts/qa/verify-tenant-branding-fallback.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/verify-video-pipeline.sh` | static | **active gate** (REMEDIATE) |
| 1 | `scripts/qa/visual-regression-auth.sh` | helper | helper (low risk) |
| 1 | `scripts/tenants/provision-tenant.sh` | helper | helper (low risk) |

## Detail — per-file hit lines

### `scripts/qa/verify-platform-middleware.sh` (manual/deprecated, 13 hits)

```
319: if echo "$COOKIE_HEADER" | grep -qi "domain=\.${DOMAIN}"; then
321: elif echo "$COOKIE_HEADER" | grep -qi "domain="; then
336: if [ -n "$BIJI_COOKIE" ] && echo "$BIJI_COOKIE" | grep -qi "domain=\.biji-biji\.com"; then
350: if [ -n "$ADMIN_COOKIE" ] && echo "$ADMIN_COOKIE" | grep -qi "domain=\.${DOMAIN}"; then
364: if [ -n "$SECURE_COOKIE" ] && echo "$SECURE_COOKIE" | grep -qi "secure"; then
434: if [ -n "$RESP_URL" ] && echo "$RESP_URL" | grep -q '^https://'; then
436: elif [ -n "$RESP_URL" ] && echo "$RESP_URL" | grep -q '^http://'; then
536: if echo "$PROVIDER_NAME" | grep -qi "Mereka"; then
538: elif echo "$PROVIDER_NAME" | grep -qi "Authentik"; then
601: if echo "$METRICS_BODY" | grep -q 'django_http_requests_total_by_method'; then
723: if echo "$CORS_RESP" | grep -qi "access-control-allow-origin.*${MFE_DOMAIN}"; then
725: elif echo "$CORS_RESP" | grep -qi "access-control-allow-origin"; then
768: if echo "$SSO_LOCATION" | grep -qi '/auth/login/oidc/'; then
```

### `scripts/qa/deprecated/verify-footer-slot-evidence-rollback.sh` (manual/deprecated, 9 hits)

```
68: if echo "$inventory_content" | grep -qi "footer"; then
74: if echo "$inventory_content" | grep -qi "header logo"; then
80: if echo "$inventory_content" | grep -qi "sidebar"; then
86: if echo "$inventory_content" | grep -qi "authn"; then
92: if echo "$inventory_content" | grep -qi "slot-based" && echo "$inventory_content" | grep -qi "CSS-on
143: if echo "$exceptions_content" | grep -qi "exception"; then
150: if echo "$exceptions_content" | grep -qiE "(EX-0[1-9]|Exception Inventory|Risk Summary Matrix)"; the
214: if echo "$legacy_content" | grep -qi "rollback"; then
220: if echo "$legacy_content" | grep -q "git revert"; then
```

### `scripts/qa/verify-domain-url-invariants.sh` (static, 8 hits)

```
349: if echo "$block" | grep -qE '"https:"'; then
382: if echo "$img_src" | grep -qE '\bhttps:\b'; then
390: if echo "$connect_src" | grep -qP '(?<!/)\bhttps:\s' 2>/dev/null || \
391: echo "$connect_src" | grep -qP "connect-src 'self' https:;" 2>/dev/null; then
399: if echo "$frame_src" | grep -qP '(?<!/)\bhttps:\s' 2>/dev/null || \
400: echo "$frame_src" | grep -qP "frame-src 'self' https:;" 2>/dev/null; then
417: if echo "$csp_connect_block" | grep -qF "_auth_url"; then
423: if echo "$csp_frame_block" | grep -qF "_auth_url"; then
```

### `scripts/qa/verify-red-line-contract.sh` (static, 8 hits)

```
155: if echo "$openedx_cache_from_block" | grep -q 'type=gha'; then
158: if echo "$openedx_cache_from_block" | grep -q 'type=registry'; then
161: if echo "$openedx_cache_from_block" | grep -q '# transitional'; then
167: if echo "$mfe_cache_from_block" | grep -q 'type=gha'; then
170: if echo "$mfe_cache_from_block" | grep -q 'type=registry'; then
173: if echo "$mfe_cache_from_block" | grep -q '# transitional'; then
279: if echo "$line" | grep -qE '(benchmark_class|warm|cold)[[:space:]]*=[[:space:]]*(warm|cold|"warm"|"c
282: if echo "$line" | grep -qiE '(metric|label|emit|push|prometheus|pushgateway)'; then
```

### `scripts/qa/verify-slo-service-metrics.sh` (manual/deprecated, 8 hits)

```
369: if echo "$LMS_AVAIL" | grep -q '"status":"success"' 2>/dev/null; then
394: if echo "$CMS_LATENCY" | grep -q '"status":"success"' 2>/dev/null; then
420: if echo "$AVAIL" | grep -q '"status":"success"' 2>/dev/null; then
432: if echo "$BUDGET" | grep -q '"status":"success"' 2>/dev/null; then
448: if echo "$RULES_JSON" | grep -q 'SLOBudgetExhausted' 2>/dev/null; then
455: if echo "$RULES_JSON" | grep -q 'SLOBudgetCritical' 2>/dev/null; then
462: if echo "$RULES_JSON" | grep -q 'SLOBudgetLow' 2>/dev/null; then
479: if echo "$ERROR_BUDGET_RATIO" | grep -q '"status":"success"' 2>/dev/null; then
```

### `scripts/qa/verify-mfe-branding.sh` (manual/deprecated, 7 hits)

```
207: if echo "$response" | grep -qP '<div id="root"'; then
209: elif echo "$response" | grep -qP '<div id="app"'; then
216: if echo "$response" | grep -qiP "page.not.found|<title>[^<]{0,30}404|>404<|error.404"; then
271: if echo "$response" | grep -qi "mereka"; then
273: elif echo "$response" | grep -q "brand-theme-core\|brand-theme-variants"; then
275: elif echo "$response" | grep -q "PARAGON_THEME.*brand"; then
277: elif echo "$response" | grep -q 'id="root"'; then
```

### `scripts/qa/verify-observability-retention.sh` (manual/deprecated, 7 hits)

```
108: if echo "$loki_config" | grep -qE "(retention_period.*30d|retention_period.*720h)"; then
110: elif echo "$loki_config" | grep -q "retention_period"; then
123: if echo "$loki_config" | grep -q "compactor"; then
174: if echo "$tempo_config" | grep -qE "(retention.*7d|retention.*168h)"; then
176: elif echo "$tempo_config" | grep -q "retention"; then
211: if echo "$prom_args" | grep -qE "(storage.tsdb.retention.time.*30d|storage.tsdb.retention.time.*720h
213: elif echo "$prom_args" | grep -q "storage.tsdb.retention.time"; then
```

### `scripts/qa/verify-ulmo-parity.sh` (manual/deprecated, 7 hits)

```
100: elif echo "$OPENEDX_TAG" | grep -qE "^21\."; then
110: elif echo "$MFE_BASE_TAG" | grep -qE "^21\."; then
118: if echo "$DISCOVERY_TAG" | grep -qE "^21\."; then
438: if echo "$NODE_BASE" | grep -qE "node:(18|20|22|24)"; then
566: elif echo "$OPENEDX_VER" | grep -q "ulmo"; then
568: elif echo "$OPENEDX_VER" | grep -q "redwood"; then
640: if echo "$LMS_IMAGE" | grep -q "ghcr.io/biji-biji-initiative/mereka-lms/openedx:"; then
```

### `scripts/qa/verify-analytics-key-elimination.sh` (static, 6 hits)

```
140: if echo "$SEGMENT_LINE" | grep -qF '""'; then
249: if echo "$EXTRACTION_LINES" | grep -q '\.lower()'; then
340: if echo "$ADMIN_BODY" | grep -qi 'undefined_license_key'; then
351: if echo "$AUTHN_BODY" | grep -qi 'undefined_license_key'; then
362: if echo "$DASHBOARD_BODY" | grep -qi 'undefined_license_key'; then
373: if echo "$LMS_HOME" | grep -qiE 'undefined_license_key|your_segment_key_here|change_me'; then
```

### `scripts/qa/verify-binary-pinning-bbi-infra.sh` (manual/deprecated, 6 hits)

```
142: if echo "$content" | grep -qiE 'yq.*(latest|LATEST)'; then
166: if echo "$content" | grep -qiE 'kubectl.*(latest|LATEST|stable\.txt)'; then
190: if echo "$content" | grep -qiE 'helm.*(latest|LATEST)'; then
214: if echo "$content" | grep -qiE 'kustomize.*(latest|LATEST)'; then
244: if echo "$file_content" | grep -qiE '(curl|wget).*(-o |--output |> )'; then
247: if echo "$file_content" | grep -qiE '(sha256sum|shasum|openssl dgst)'; then
```

### `scripts/qa/verify-brand-pack-schema.sh` (static, 6 hits)

```
221: if echo "$config_slug" | grep -qE '^[a-z0-9-]+$'; then
236: if echo "$color_value" | grep -qE '^#[0-9A-Fa-f]{6}$'; then
281: if echo "$link_url" | grep -qE '^https://'; then
294: if echo "$footer_text" | grep -qE '<[^>]+>'; then
310: if echo "$contact_email" | grep -qE '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
320: if echo "$domain" | grep -qE '^([a-z0-9-]+\.)+[a-z]{2,}$'; then
```

### `scripts/qa/verify-deployment-contract.sh` (static, 6 hits)

```
102: if ! echo "$contract_workloads" | grep -qx "$dep"; then
112: if ! echo "$rendered_deployments" | grep -qx "$wl"; then
141: if ! echo "$contract_es" | grep -qx "$es"; then
149: if ! echo "$rendered_es" | grep -qx "$es"; then
176: if ! echo "$contract_cms" | grep -qx "$cm"; then
184: if ! echo "$kustomization_cms" | grep -qx "$cm"; then
```

### `scripts/qa/verify-observability-loki-labels.sh` (manual/deprecated, 6 hits)

```
128: if echo "$promtail_config" | grep -qE "(app|service|app_kubernetes_io_name)"; then
135: if echo "$promtail_config" | grep -qE "(env|environment)"; then
142: if echo "$promtail_config" | grep -q "cluster"; then
149: if echo "$promtail_config" | grep -qE "(namespace|namespace_name)"; then
157: if echo "$promtail_config" | grep -qE "(hostname|pod|pod_name|instance)"; then
164: if echo "$promtail_config" | grep -qE "(severity|level)"; then
```

### `scripts/qa/verify-selector-hardening.sh` (manual/deprecated, 6 hits)

```
85: if echo "$file" | grep -qE "test|spec|mock|fixture"; then
94: if echo "$line" | grep -qE '^\s*(//|/\*|\*)'; then
135: if echo "$line" | grep -qE '^\s*(//|/\*|\*)'; then
140: if echo "$line" | grep -qE '^\s*(--[a-zA-Z0-9_-]+|\$[a-zA-Z0-9_-]+)\s*:\s*#[0-9a-fA-F]{3,8}\b'; then
145: if echo "$line" | grep -qE 'var\(--mereka-|var\(--color-|\$color-|\$mereka-'; then
152: if echo "$line" | grep -qF "$exc"; then
```

### `scripts/qa/verify-slo-synthetic-drills.sh` (manual/deprecated, 6 hits)

```
182: if echo "$missed_drill_alert" | grep -q 'severity.*P2' 2>/dev/null; then
189: if echo "$missed_drill_alert" | grep -q '5m' 2>/dev/null; then
282: if echo "$DRILL_SUCCESS" | grep -q '"status":"success"' 2>/dev/null; then
294: if echo "$DRILL_LATENCY" | grep -q '"status":"success"' 2>/dev/null; then
308: if echo "$RULES_JSON" | grep -q 'Alert Delivery Pipeline Failure' 2>/dev/null || \
309: echo "$RULES_JSON" | grep -q 'AlertDeliveryPipelineFailure' 2>/dev/null; then
```

### `scripts/tenants/validate-tenant-brand-pack.sh` (static, 6 hits)

```
222: if echo "$config_slug" | grep -qE '^[a-z0-9-]+$'; then
236: if echo "$color_value" | grep -qE '^#[0-9A-Fa-f]{6}$'; then
277: if echo "$link_url" | grep -qE '^https://'; then
289: if echo "$footer_text" | grep -qE '<[^>]+>'; then
305: if echo "$contact_email" | grep -qE '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
315: if echo "$domain" | grep -qE '^([a-z0-9-]+\.)+[a-z]{2,}$'; then
```

### `scripts/qa/verify-ecommerce-worker-health.sh` (manual/deprecated, 5 hits)

```
307: if echo "$WORKER_PODS" | grep -q "CrashLoopBackOff"; then
311: elif echo "$WORKER_PODS" | grep -q "Running"; then
313: elif echo "$WORKER_PODS" | grep -q "Error"; then
385: elif echo "$ECOM_PODS" | grep -q "Running"; then
406: elif echo "$PG_PODS" | grep -q "Running"; then
```

### `scripts/qa/verify-purchase-gateway-stripe.sh` (static, 5 hits)

```
376: if echo "$HEALTH_RESP" | grep -q '"status"'; then
382: if echo "$HEALTH_RESP" | grep -q '"database".*"ok"'; then
388: if echo "$HEALTH_RESP" | grep -q '"redis".*"ok"'; then
394: if echo "$HEALTH_RESP" | grep -q '"stripe".*"ok"'; then
403: if echo "$READY_RESP" | grep -q '"status".*"ready"'; then
```

### `scripts/qa/verify-secrets-isolation.sh` (static, 5 hits)

```
208: if echo "$patch_stores" | grep -qx "${RKE2_PROD_STORE}"; then
222: if echo "$patch_stores" | grep -qx "${RKE2_DEV_STORE}"; then
254: if echo "$rke2_stores" | grep -qx "${RKE2_PROD_STORE}"; then
262: if echo "$rke2_stores" | grep -qx "${RKE2_DEV_STORE}"; then
290: if echo "$prod_stores" | grep -qx "${PROD_STORE}"; then
```

### `scripts/tenants/lib/runtime-proof-common.sh` (helper, 5 hits)

```
192: if echo "$tag" | grep -q "$BANNED_COMMIT"; then
224: if echo "$MODULE_CHECK" | grep -q "^PRESENT"; then
227: elif echo "$MODULE_CHECK" | grep -q "^ABSENT"; then
410: if echo "$LMS_URL" | grep -q "$lms"; then
416: if echo "$MFE_URL" | grep -q "$mfe"; then
```

### `scripts/ops/rc-check.sh` (helper, 4 hits)

```
167: if echo "$out" | grep -q "sync=Synced"; then
189: if echo "$out" | grep -qE '@sha256:|:[a-f0-9]{7,40}$'; then
272: if echo "$out" | grep -q "^ERROR db.exists:"; then
274: elif echo "$out" | grep -q "^ERROR"; then
```

### `scripts/qa/deprecated/verify-gh-actions-cost-dashboard.sh` (manual/deprecated, 4 hits)

```
102: if echo "$PANELS_JSON" | grep -qi "budget\|spend\|gauge"; then
108: if echo "$PANELS_JSON" | grep -qi "daily\|trend\|time.*series"; then
114: if echo "$PANELS_JSON" | grep -qi "top\|expensive\|workflow"; then
120: if echo "$PANELS_JSON" | grep -qi "forecast\|projected"; then
```

### `scripts/qa/inventory_k8s_resources.sh` (helper, 4 hits)

```
212: if ! echo "${existing}" | grep -qw "${ep_name}"; then
278: if echo "${rendered_by}" | grep -qw "base"; then
293: if echo "${rendered_by}" | grep -qw "${ep_name}"; then
294: if ! echo "${rendered_by}" | grep -qw "base"; then
```

### `scripts/qa/verify-analytics-hardening.sh` (manual/deprecated, 4 hits)

```
87: if echo "$SEGMENT_ASSIGN_LINES" | grep -q '\.lower()\|\.casefold()'; then
116: if echo "$FOOTER_ASSIGN" | grep -q '\.lower()'; then
154: if echo "$SEGMENT_LINE" | grep -qF '""'; then
201: if echo "$MFE_FOOTER_SECTION" | grep -qE 'analytics\.js|segment\.com|cdn\.segment\.com|analytics\.lo
```

### `scripts/qa/verify-analytics-undefined-regression.sh` (static, 4 hits)

```
135: if echo "$SEGMENT_LINE" | grep -qF '""'; then
274: if echo "$ADMIN_BODY" | grep -qi 'undefined_license_key'; then
285: if echo "$AUTHN_BODY" | grep -qi 'undefined_license_key'; then
296: if echo "$DASHBOARD_BODY" | grep -qi 'undefined_license_key'; then
```

### `scripts/qa/verify-binary-pinning-pcp.sh` (static, 4 hits)

```
136: if echo "${line_content}" | grep -qE '(-H.*application/json|--data.*\{|-d.*\{|Content-Type|/health|/
141: if ! echo "${line_content}" | grep -qE '(-o[[:space:]]|-O[[:space:]]|--output[[:space:]]|-O$|-O[[:sp
143: if ! echo "${line_content}" | grep -qE '\| *(ba)?sh'; then
153: if echo "${context_block}" | grep -qiE '(sha256sum|shasum|sha512sum|md5sum|cosign verify|EXPECTED_SH
```

### `scripts/qa/verify-design-tokens.sh` (static, 4 hits)

```
92: if [[ -z "$heading_val" ]] || ! echo "$heading_val" | grep -qi "lato"; then
95: if [[ -z "$body_val" ]] || ! echo "$body_val" | grep -qi "poppins"; then
188: if echo "$commit" | grep -qE '^[0-9a-f]{40}$'; then
202: if echo "$sha" | grep -qE '^[0-9a-f]{64}$'; then
```

### `scripts/qa/verify-disaster-recovery.sh` (manual/deprecated, 4 hits)

```
265: if echo "$log" | grep -qi "bound"; then
451: if echo "$rules" | grep -qi "VeleroBackup"; then
653: if [[ -n "$output" ]] && ! echo "$output" | grep -qi "error"; then
684: if echo "$location" | grep -qi "MULTI_REGIONAL\|multi-region\|^US$\|^EU$\|^ASIA$"; then
```

### `scripts/qa/verify-eso-alerting.sh` (manual/deprecated, 4 hits)

```
62: if echo "$content" | grep -q "alert: ${alert_name}"; then
73: if echo "$content" | grep -q 'severity: warning'; then
79: if echo "$content" | grep -q 'severity: info'; then
89: if echo "$kust_content" | grep -q 'prometheusrule-externalsecrets.yaml'; then
```

### `scripts/qa/verify-footer-variant-matrix.sh` (manual/deprecated, 4 hits)

```
67: if echo "$VARIANTS_BLOCK" | grep -q "brand:"; then
74: if echo "$VARIANTS_BLOCK" | grep -q "copyrightHolder:"; then
81: if echo "$VARIANTS_BLOCK" | grep -q "whatsapp:"; then
90: if echo "$VARIANTS_BLOCK" | grep -qE ": null|: undefined"; then
```

### `scripts/qa/verify-gdpr-compliance.sh` (manual/deprecated, 4 hits)

```
394: if echo "$lms_html" | grep -qiE "cookie.consent|cookieConsent|cookie-consent|CookieBanner|cc_cookie|
401: if echo "$lms_html" | grep -qiE "privacy.policy|/privacy\"|privacy-policy"; then
461: if echo "$headers" | grep -qi "strict-transport-security"; then
468: if echo "$headers" | grep -qi "x-content-type-options"; then
```

### `scripts/qa/verify-mfe-runtime-contract.sh` (manual/deprecated, 4 hits)

```
462: if echo "$prefixed_env_ct" | grep -qi "html"; then
491: if echo "$authoring_config_ct" | grep -qi "application/json"; then
512: if echo "$logo_ct" | grep -qi "image/svg"; then
527: if echo "$core_ct" | grep -qi "text/css"; then
```

### `scripts/qa/verify-mfe-ulmo-migration.sh` (static, 4 hits)

```
93: if echo "$CONFIG_VER" | grep -q "redwood"; then
95: elif echo "$CONFIG_VER" | grep -q "ulmo"; then
180: if echo "$BASE_IMAGE" | grep -qE "node:(18|20|22|24)"; then
399: if echo "$MFE_IMAGE" | grep -qE "nightly|latest"; then
```

### `scripts/qa/verify-rke2-tenant-routes.sh` (manual/deprecated, 4 hits)

```
131: if echo "$status" | grep -qE "^(${expected})$"; then
151: if echo "$status" | grep -qE "^(${expected})$"; then
719: if echo "$redir_status" | grep -qE "^(301|302|308)$"; then
865: if echo "$options_status" | grep -qE "^(200|204|401|403)$"; then
```

### `scripts/qa/verify-workflow-gate-enforcement.sh` (static, 4 hits)

```
101: if echo "$BUNDLE_NEEDS" | grep -q "$dep"; then
108: if echo "$BUNDLE_NEEDS" | grep -q 'scan-openedx-image\|scan-mfe-image'; then
116: if echo "$DISPATCH_NEEDS" | grep -q "$dep"; then
134: if echo "$context" | grep -qi 'non-blocking\|informational\|tracked\|debt\|optional\|desirable\|may 
```

### `scripts/infra/check-cert-sans.sh` (static, 3 hits)

```
68: if echo "$subject" | grep -qi "Kubernetes Ingress Controller Fake Certificate"; then
75: if echo "$sans" | grep -q "DNS:${host}"; then
81: if [[ "$host" != "$wildcard_suffix" ]] && echo "$sans" | grep -q "DNS:\\*\\.${wildcard_suffix}"; the
```

### `scripts/qa/deprecated/verify-email-ace-channels.sh` (manual/deprecated, 3 hits)

```
47: if echo "$CHANNELS_CONFIG" | grep -q "django_email"; then
51: if echo "$CHANNELS_CONFIG" | grep -q "push"; then
55: if echo "$CHANNELS_CONFIG" | grep -q "in_app"; then
```

### `scripts/qa/verify-a11y-regression-lane.sh` (manual/deprecated, 3 hits)

```
203: if echo "$FOCUS_RULES" | grep -q 'outline:\s*none\|outline:\s*0'; then
206: if echo "$FOCUS_RULES" | grep -q 'box-shadow:\s*none'; then
232: if echo "$FOCUS_TOKEN_VALUE" | grep -q 'transparent'; then
```

### `scripts/qa/verify-admin-merge-exceptions.sh` (static, 3 hits)

```
90: if echo "$entry_check" | grep -q "^EMPTY$"; then
92: elif echo "$entry_check" | grep -q "^MISSING:"; then
96: elif echo "$entry_check" | grep -qE "^(INVALID|DUPLICATE):"; then
```

### `scripts/qa/verify-assessment-audit.sh` (manual/deprecated, 3 hits)

```
117: if echo "$XQUEUE_STATUS" | grep -q "queue"; then
133: if echo "$XQUEUE_STATUS" | grep -q "queue"; then
209: if echo "$XQUEUE_GRADERS" | grep -q "None"; then
```

### `scripts/qa/verify-branch-protection.sh` (manual/deprecated, 3 hits)

```
143: if echo "${PROTECTION_JSON}" | grep -q "Branch not protected"; then
148: if echo "${PROTECTION_JSON}" | grep -q "Not Found"; then
209: if echo "${CONFIGURED}" | grep -qF "${check}"; then
```

### `scripts/qa/verify-credentials-issuer.sh` (manual/deprecated, 3 hits)

```
117: if echo "$CONTEXTS" | grep -q "https://www.w3.org/ns/did/v1"; then
123: if echo "$CONTEXTS" | grep -q "https://w3id.org/security/suites/ed25519-2020/v1"; then
338: if echo "$CACHE_HEADER" | grep -qi "max-age"; then
```

### `scripts/qa/verify-credentials-readiness.sh` (manual/deprecated, 3 hits)

```
559: if echo "$HEALTH_STATUS" | grep -qi '"overall_status"[[:space:]]*:[[:space:]]*"OK"\|ok\|healthy'; th
573: if echo "$ZONEINFO_RESULT" | grep -qx 'OK'; then
611: if [[ "$DID_MODE" == "OK" ]] && echo "$DID_BODY" | grep -q '"id".*did:web:'; then
```

### `scripts/qa/verify-enterprise-ui-review.sh` (manual/deprecated, 3 hits)

```
94: if echo "$LMS_URL_LINE" | grep -q "http://localhost"; then
100: if echo "$STUDIO_URL_LINE" | grep -q "http://studio.localhost"; then
119: if echo "$IMAGE_LINE" | grep -q "$MEREKA_REGISTRY"; then
```

### `scripts/qa/verify-import-dedup.sh` (manual/deprecated, 3 hits)

```
81: if echo "$result" | grep -q "PASS"; then
101: if echo "$result" | grep -q "PASS"; then
121: if echo "$result" | grep -q "PASS"; then
```

### `scripts/qa/verify-k8s-deployment-spec.sh` (static, 3 hits)

```
167: if echo "$secret_names" | grep -q "^${secret}$"; then
314: if echo "$deploy_priv_esc" | grep -q "true"; then
363: if echo "$deployment_labels" | grep -q "^${selector_app}$"; then
```

### `scripts/qa/verify-multisite-ux-consistency.sh` (manual/deprecated, 3 hits)

```
133: if echo "$MFE_CONFIG_BLOCK" | grep -qE '"https://(academyv2\.mereka\.io|apps\.academyv2\.mereka\.io)
140: if echo "$MFE_CONFIG_BLOCK" | grep -q 'MEREKA_LMS_BASE_URL\|MEREKA_MFE_BASE_URL'; then
260: if echo "$ENV_CONFIG_JS" | grep -q 'window\.location\.hostname'; then
```

### `scripts/qa/verify-tenant-branding-runtime.sh` (manual/deprecated, 3 hits)

```
248: if echo "$logo_url" | grep -qi "openedx"; then
261: if echo "$lms_base_url" | grep -q "$domain"; then
272: if echo "$response" | grep -qE '"(PRIMARY_COLOR|SECONDARY_COLOR|ACCENT_COLOR|TEXT_ON_PRIMARY)"'; the
```

### `scripts/qa/verify-video-protection.sh` (manual/deprecated, 3 hits)

```
136: if echo "$URL" | grep -q "token="; then
211: if echo "$URL" | grep -q "token="; then
293: if echo "$ERROR_MSG" | grep -qi "enroll"; then
```

### `scripts/qa/audit-analytics-pii.sh` (helper, 2 hits)

```
115: if ! echo "$context" | grep -qE "(hash|anonymize|pseudonym|md5|sha|encrypt)"; then
164: if ! echo "$query_context" | grep -qE "(hash|md5|sha|anonymize|CONCAT|SUBSTR)"; then
```

### `scripts/qa/no_environment_domains_in_base.sh` (helper, 2 hits)

```
83: if echo "$file_path" | grep -qE "$ALLOWED_GREP"; then
88: if [[ "$file_path" == *.py ]] && echo "$line_content" | grep -q 'os\.environ\.get('; then
```

### `scripts/qa/verify-a11y-contrast-focus.sh` (static, 2 hits)

```
252: if ! echo "$CONTEXT" | grep -qE 'box-shadow|:focus-visible|outline-offset|ring'; then
273: if echo "$CONTEXT" | grep -qE ':focus|:focus-visible|:focus-within'; then
```

### `scripts/qa/verify-analytics-decision-gate.sh` (manual/deprecated, 2 hits)

```
182: if echo "$adr_check" | grep -qi "Accepted"; then
187: if echo "$kustomize_content" | grep -q 'plugins/aspects'; then
```

### `scripts/qa/verify-aspects-deployment-readiness.sh` (manual/deprecated, 2 hits)

```
196: if echo "$ADR_STATUS" | grep -qi "Deferred\|Accepted"; then
241: if echo "$adr_check" | grep -qi "Accepted"; then
```

### `scripts/qa/verify-aspects-wiring.sh` (manual/deprecated, 2 hits)

```
370: elif echo "${ingress_host}" | grep -q "mereka.dev"; then
372: elif echo "${ingress_host}" | grep -q "mereka.io"; then
```

### `scripts/qa/verify-caddy-payments-route.sh` (manual/deprecated, 2 hits)

```
103: if echo "$PROD_BLOCK" | grep -q 'handle /payments/\*'; then
109: if echo "$PROD_BLOCK" | grep -q 'payments-gateway:8080'; then
```

### `scripts/qa/verify-content-libraries-v2-enterprise.sh` (manual/deprecated, 2 hits)

```
360: if echo "$cms_pods" | grep -q "Running"; then
385: if echo "$lms_pods" | grep -q "Running"; then
```

### `scripts/qa/verify-cross-browser-branding-smoke.sh` (manual/deprecated, 2 hits)

```
189: if echo "$authn_html" | grep -Eq 'paragon-theme-core\.[a-z0-9]+\.css' \
190: && echo "$authn_html" | grep -Eq 'brand-theme-core\.[a-z0-9]+\.css'; then
```

### `scripts/qa/verify-css-scoping.sh` (manual/deprecated, 2 hits)

```
479: if echo "$line" | grep -qE '^\s*h[1-6]\s*[,{]' && ! echo "$line" | grep -qE '^\s*\.'; then
514: if echo "$fname" | grep -q 'mfe'; then
```

### `scripts/qa/verify-enterprise-mfe-nreum-clean.sh` (manual/deprecated, 2 hits)

```
58: if echo "$ADMIN_HTML" | grep -q 'undefined_license_key'; then
66: if echo "$ADMIN_HTML" | grep -q 'NREUM'; then
```

### `scripts/qa/verify-kustomize-structure.sh` (static, 2 hits)

```
212: if echo "${patches}" | grep -qF "${relative}"; then
259: if echo "${tag_line}" | grep -qiE '^\s*newTag:\s*["'"'"']?latest["'"'"']?\s*$'; then
```

### `scripts/qa/verify-lighthouse-budgets.sh` (static, 2 hits)

```
138: if echo "$RAW_CONTENT" | grep -q "interaction-to-next-paint"; then
144: if echo "$RAW_CONTENT" | grep -qi '"first-input-delay"\|"fid"'; then
```

### `scripts/qa/verify-mako-template-syntax.sh` (static, 2 hits)

```
70: if echo "$imports" | grep -qE 'import.*gettext.*as _|from.*import.*_'; then
86: if ! echo "$imports" | grep -q "$func"; then
```

### `scripts/qa/verify-multitenant-brand-platform.sh` (static, 2 hits)

```
501: if [[ -n "$logo_url" ]] && ! echo "$logo_url" | grep -qi "openedx"; then
503: elif echo "$logo_url" | grep -qi "openedx"; then
```

### `scripts/qa/verify-mux-alert-wiring.sh` (static, 2 hits)

```
377: if echo "${rule_yaml}" | grep -q "${alert}" 2>/dev/null; then
478: if echo "${am_config}" | grep -qiE 'video|mux|component' 2>/dev/null; then
```

### `scripts/qa/verify-mux-secrets.sh` (static, 2 hits)

```
126: if echo "${keys}" | grep -q "MUX_TOKEN_ID"; then
131: if echo "${keys}" | grep -q "MUX_TOKEN_SECRET"; then
```

### `scripts/qa/verify-observability-loki-deployment.sh` (manual/deprecated, 2 hits)

```
122: if echo "$promtail_config" | grep -q "$APP_NS" || echo "$promtail_config" | grep -q "namespace_name"
161: if echo "$promtail_logs" | grep -qi "error"; then
```

### `scripts/qa/verify-security-hardening.sh` (static, 2 hits)

```
168: if echo "$_img_src_block" | grep -qF '"https:"'; then
178: if echo "$_media_src_block" | grep -qF '"https:"'; then
```

### `scripts/qa/verify-slo-contracts.sh` (static, 2 hits)

```
221: if echo "$RULES_JSON" | grep -q "$rule"; then
230: if echo "$RULES_JSON" | grep -q "$alert"; then
```

### `scripts/qa/verify-studio-sso-flow.sh` (manual/deprecated, 2 hits)

```
36: if echo "$redirect" | grep -qE "$expect_pattern"; then
83: if echo "$OIDC_URL" | grep -qE "${AUTHENTIK_DOMAIN//./\\.}/application/o/authorize"; then
```

### `scripts/qa/verify-vc-ops.sh` (static, 2 hits)

```
56: if echo "$METRICS" | grep -q "credentials_vc_issued_total"; then
62: if echo "$METRICS" | grep -q "credentials_vc_issuance_duration_seconds"; then
```

### `scripts/qa/verify-video-observability.sh` (manual/deprecated, 2 hits)

```
290: if echo "$estimated_cost" | grep -q "^PASS$"; then
292: elif echo "$estimated_cost" | grep -q "^FAIL$"; then
```

### `scripts/infra/create-release.sh` (helper, 1 hits)

```
48: if ! echo "${VERSION}" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
```

### `scripts/infra/ensure-atlas-allowlist-gke-nodes.sh` (helper, 1 hits)

```
104: if echo "$allowed_ips" | grep -qF "$ip"; then
```

### `scripts/infra/repair-staging-routing.sh` (helper, 1 hits)

```
32: if echo "$port_lines" | grep -q '^443:443:'; then
```

### `scripts/infra/seed-mongo-dev.sh` (helper, 1 hits)

```
78: if echo "$MONGODB_CONNECTION_STRING" | grep -qiE 'cluster-mereka-lms\.2pjex4s'; then
```

### `scripts/infra/sync-production-config.sh` (helper, 1 hits)

```
96: if echo "$MFE_CONFIG" | grep -q "BASE_URL"; then
```

### `scripts/qa/comprehensive-test.sh` (helper, 1 hits)

```
113: if echo "$MFE_CONFIG" | grep -q "BASE_URL"; then
```

### `scripts/qa/deprecated/verify-email-push-code.sh` (manual/deprecated, 1 hits)

```
64: if echo "$BATCH_CONFIG" | grep -q "500"; then
```

### `scripts/qa/deprecated/verify-gh-actions-cost-tracking.sh` (manual/deprecated, 1 hits)

```
269: if echo "$VALIDATE_COSTS" | grep -q "^✗"; then
```

### `scripts/qa/load-test-tenants.sh` (helper, 1 hits)

```
93: if echo "$TENANT_SLUG" | grep -qE '^[a-z0-9][a-z0-9_-]*$'; then
```

### `scripts/qa/scan-mux-credentials.sh` (helper, 1 hits)

```
134: if echo "${line}" | grep -qE "${allowed}"; then
```

### `scripts/qa/validate-deploy-contract.sh` (static, 1 hits)

```
236: if echo "$rendered_base" | grep -qE "^kind:[[:space:]]+${kind}$"; then
```

### `scripts/qa/verify-agent-context-lock.sh` (manual/deprecated, 1 hits)

```
81: if echo "${REMOTE_URL}" | grep -qiE "(Biji-Biji-Initiative/mereka-lms|biji-biji-initiative/mereka-lm
```

### `scripts/qa/verify-analytics-drift-guardrails.sh` (manual/deprecated, 1 hits)

```
127: elif echo "$ASPECTS_PODS" | grep -q "No resources found"; then
```

### `scripts/qa/verify-auth-sso-enterprise.sh` (manual/deprecated, 1 hits)

```
405: if echo "$PIPELINE_CONTENT" | grep -qi 'is_staff\|is_superuser\|set_staff\|grant_staff'; then
```

### `scripts/qa/verify-container-hardening.sh` (manual/deprecated, 1 hits)

```
178: if echo "$patched_names" | grep -qxF "$name"; then
```

### `scripts/qa/verify-deployment-critical-coverage.sh` (static, 1 hits)

```
62: if echo "$LINT_OUT" | grep -q "^PASS"; then
```

### `scripts/qa/verify-deployment-lanes.sh` (manual/deprecated, 1 hits)

```
173: if echo "$script_name" | grep -qE "$EXCLUSION_PATTERN"; then
```

### `scripts/qa/verify-design-token-usage.sh` (static, 1 hits)

```
139: if echo "$lower_line" | grep -qiE "${lower_allowed}[^0-9a-fA-F]|${lower_allowed}$"; then
```

### `scripts/qa/verify-durability-proof.sh` (manual/deprecated, 1 hits)

```
378: if echo "${post_pods}" | grep -qw "${target_pod}"; then
```

### `scripts/qa/verify-enterprise-auth-contract.sh` (static, 1 hits)

```
152: if echo "$cookie_name" | grep -q "sessionid"; then
```

### `scripts/qa/verify-enterprise-observability.sh` (manual/deprecated, 1 hits)

```
139: if echo "$LOG_SAMPLE" | grep -q '{.*".*":'; then
```

### `scripts/qa/verify-enterprise-secrets.sh` (manual/deprecated, 1 hits)

```
53: if echo "$SECRET_DATA" | grep -q "\"$key\""; then
```

### `scripts/qa/verify-enterprise-sso-readiness.sh` (manual/deprecated, 1 hits)

```
311: if echo "$SECRET_KEYS" | grep -qw "$key"; then
```

### `scripts/qa/verify-forum-moderation.sh` (manual/deprecated, 1 hits)

```
467: if echo "$indexes_resp" | grep -q '"results"'; then
```

### `scripts/qa/verify-k8s-secrets-hygiene.sh` (static, 1 hits)

```
147: if echo "$match" | grep -qi "$exempt"; then
```

### `scripts/qa/verify-kustomize-render.sh` (static, 1 hits)

```
156: if echo "${render_output}" | grep -q '^---$' && ! echo "${render_output}" | grep -qv '^---$'; then
```

### `scripts/qa/verify-lane-identity.sh` (static, 1 hits)

```
130: if echo "$identity_services" | grep -qx "$svc"; then
```

### `scripts/qa/verify-lms-rke2-validation.sh` (manual/deprecated, 1 hits)

```
633: if echo "$health_body" | grep -qi '"OK"\|"status": "OK"\|status.*ok'; then
```

### `scripts/qa/verify-mfe-analytics-plugin-parity.sh` (static, 1 hits)

```
61: if echo "$SEGMENT_LINE" | grep -qF '""'; then
```

### `scripts/qa/verify-mfe-footer-fallbacks.sh` (static, 1 hits)

```
186: if echo "$LINE" | grep -q "FTRX-EXC-"; then
```

### `scripts/qa/verify-mfe-route-drift.sh` (static, 1 hits)

```
71: if echo "$line" | grep -qP 'root \* /openedx/dist/'; then
```

### `scripts/qa/verify-mfe-version-pinning.sh` (manual/deprecated, 1 hits)

```
111: if echo "$runtime_image" | grep -q ':latest'; then
```

### `scripts/qa/verify-mobile-secrets-inventory.sh` (static, 1 hits)

```
101: if echo "$SECRET_LIST" | grep -q "^${secret}"; then
```

### `scripts/qa/verify-multi-tenancy-foundation.sh` (manual/deprecated, 1 hits)

```
239: if echo "$COOKIE_HEADERS" | grep -iq "set-cookie"; then
```

### `scripts/qa/verify-mux-alerts.sh` (manual/deprecated, 1 hits)

```
213: if echo "${rule_yaml}" | grep -qiE 'video.delivery|mux.*delivery|delivery.*minutes' 2>/dev/null; the
```

### `scripts/qa/verify-observability-runtime.sh` (manual/deprecated, 1 hits)

```
786: if [[ $rc -ne 0 ]] && echo "$output" | grep -q "${missing_sm} NOT listed in kustomization.yaml"; the
```

### `scripts/qa/verify-pii-inventory.sh` (manual/deprecated, 1 hits)

```
70: if echo "$nearby" | grep -qiE "(retention|days|years|lifetime)"; then
```

### `scripts/qa/verify-platform-admin-env.sh` (manual/deprecated, 1 hits)

```
90: if ! echo ",$current_norm," | grep -qi ",${req},"; then
```

### `scripts/qa/verify-public-branding.sh` (manual/deprecated, 1 hits)

```
485: if ! echo "$logo_url" | grep -qE "/static/(mereka/)?images/logo" && [[ "$logo_url" != "$theming_effe
```

### `scripts/qa/verify-release-automation.sh` (static, 1 hits)

```
235: if echo "${subject}" | grep -qE "${CONV_PATTERN}"; then
```

### `scripts/qa/verify-release-readiness.sh` (manual/deprecated, 1 hits)

```
118: if echo "$ARGO_STATUS" | grep -q "Synced" 2>/dev/null; then
```

### `scripts/qa/verify-rke2-dev-readiness.sh` (manual/deprecated, 1 hits)

```
242: elif echo "$argo_path" | grep -q "profiles/dev"; then
```

### `scripts/qa/verify-secrets-infisical.sh` (manual/deprecated, 1 hits)

```
213: if echo "$atlas_keys" | grep -q "^${key}$"; then
```

### `scripts/qa/verify-slo-deployment-gate.sh` (static, 1 hits)

```
144: if echo "$OUTPUT" | grep -qi 'skip'; then
```

### `scripts/qa/verify-studio-isolation.sh` (manual/deprecated, 1 hits)

```
86: if echo "$block" | grep -q 'proxy "cms:8000"'; then
```

### `scripts/qa/verify-tenant-branding-fallback.sh` (static, 1 hits)

```
301: if echo "$DUP_OUT" | grep -q "^WARN:"; then
```

### `scripts/qa/verify-video-pipeline.sh` (static, 1 hits)

```
330: if echo "${secret_data}" | grep -qi "mux"; then
```

### `scripts/qa/visual-regression-auth.sh` (helper, 1 hits)

```
348: if echo "$final_url" | grep -qE '/login(\?|$)|/signin(\?|$)'; then
```

### `scripts/tenants/provision-tenant.sh` (helper, 1 hits)

```
105: if ! echo "$SLUG" | grep -qE '^[a-z0-9][a-z0-9_-]*$'; then
```

## Remediation patterns

The safe rewrites, in order of preference:

1. **here-string** (no pipe at all):
   ```bash
   # before
   if echo "$var" | grep -q 'pattern'; then ...
   # after
   if grep -q 'pattern' <<<"$var"; then ...
   ```
2. **bash regex match** (zero fork):
   ```bash
   if [[ "$var" =~ pattern ]]; then ...
   ```
3. **guarded pipe** (least invasive when the pipe stays):
   ```bash
   echo "$var" | grep -q 'pattern' || status=$?
   # or wrap the pipeline with set +o pipefail / set -o pipefail around it.
   ```

## Next actions

- [ ] Priority 1 — open a narrow PR rewriting `echo | grep -q` to here-strings in all `static` (active gate) files flagged above. Each rewrite is 1-line and fully behavior-preserving.
- [ ] Priority 2 — same for `runtime` files after static is clean.
- [ ] Priority 3 — add a governance check that refuses new `echo '...' | grep -q...` in `scripts/qa/verify-*.sh` once a `set -o pipefail` is also present. Gate on the static inventory only so deprecated scripts don't cause drift.
- [ ] Parent bead: update `mereka-lms-0z5g` tracker once static lane is green.
