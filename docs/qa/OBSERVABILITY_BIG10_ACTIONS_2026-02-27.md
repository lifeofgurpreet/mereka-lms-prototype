# Observability Big-10 Execution Set (Mereka LMS) — 2026-02-27

## Context snapshot
- Strict runtime evidence (latest check window): `pass 4 / fail 5 / skip 0`
- Hard fail class: `AC-OVR-016` (`/metrics` non-Prometheus responses)
  - LMS now returns 400/500 variants during in-pod probes depending on host and DB state.
  - CMS deployment was crash-looping with `Missing required environment variable: XQUEUE_PASSWORD`.

Recent evidence confirms two classes of `/metrics` failure:
1) probe-host mismatch (`DisallowedHost`) when host header is `localhost`;
2) application runtime data path failure (`django_site` table missing) once host is accepted.

Hard blocker: CMS must accept `XQUEUE_PASSWORD` in runtime and LMS/CMS must expose `/metrics` after readiness + migration recovery.
- Parser risk: `AC-OVR-026` message contamination in strict compliance output
- Wiring evidence risk: caddy/mfe target + rule matches currently `0`

## The next 10 large actions (ordered)

1. **Close LMS `/metrics` route contract in strict nonprod lane (P0)**
   - Do: run strict first-class command in nonprod/dev profile
   - Must prove: `observability-metrics-lms-runtime.md` shows `status_code: 200`, `help_count > 0`, `type_count > 0`, `numeric_sample_count > 0`
   - AC target: `AC-OVR-016` + `OBS-EXT-061`

2. **Close CMS `/metrics` route contract in strict nonprod lane (P0)**
   - Do: same lane command; ensure `openedx_prometheus.urls` is mounted and route returns scrape payload
   - Must prove: `observability-metrics-cms-runtime.md` with valid exposition markers
   - AC target: `AC-OVR-016` + `OBS-EXT-063`

3. **Publish deterministic metrics-path contract in runtime manifests (P0)**
   - Do: verify `ROOT_URLCONF_OVERRIDES` + `openedx_prometheus.urls` and `/metrics` normalization in built images
   - Must prove: no path divergence (`/metrics` vs `/metrics/`) and strict AC evidence for both pods
   - AC target: `OBS-EXT-062`

4. **Hard-stop first-class pipeline on strict JSON-only output (P1)**
   - Do: set strict JSON-only mode for the strict compliance command and keep parser output clean
   - Must prove: no AC-OVR-026/025 log mixing in `observability-compliance-runtime.json`
   - AC target: `AC-OVR-025`, `AC-OVR-029` (`OBS-EXT-069`)

5. **Repair caddy metrics observability closure (P0)**
   - Do: validate/repair `caddy-metrics` target and `caddy-alerts` rule group in active lane
   - Must prove: `observability-caddy-prometheus-wiring-runtime.md` `target_matches > 0`, `rule_group_matches > 0`
   - AC target: `OBS-EXT-064` / `OBS-053`

6. **Repair MFE metrics observability closure (P0)**
   - Do: validate/repair `mfe-metrics` + `services-alerts`
   - Must prove: `observability-mfe-prometheus-wiring-runtime.md` target and rule matches > 0
   - AC target: `OBS-EXT-065` / `OBS-054`

7. **Close commerce/forum surface ServiceMonitor coverage (P1)**
   - Do: forum/discovery/ecommerce/credentials/purchase-gateway monitor coverage checks
   - Must prove: each expected ServiceMonitor appears in Prometheus active targets and runtime verification evidence
   - AC target: `OBS-EXT-066` / `OBS-055`

8. **Close rule-set coverage for SLO/video/ORA2 (P1)**
   - Do: ensure `slo-recording-rules`, `video-alerts`, `ora2-operations` present in `/api/v1/rules`
   - Must prove: corresponding `observability-*-rules-prometheus-wiring-runtime.md` show matching rule groups
   - AC target: `OBS-EXT-067` / `OBS-056`

9. **Close dev-only monitor scope checks (P1)**
   - Do: confirm `xqueue-metrics` and `mux-delivery-monitor` behavior by lane
   - Must prove: present in dev evidence files, absent where explicitly non-dev
   - AC target: `OBS-EXT-068` / `OBS-057`

10. **Publish GA exception log + release handoff (P0/P1)**
    - Do: finalize `OBS-060` with explicit exceptions, owners, and closure criteria while remaining gaps exist
    - Must prove: handoff issue set references every open child ticket with evidence paths and decision date
    - AC target: `OBS-070`

## Hard gates before proceeding to next wave
- No nonprod lane progression until both LMS/CMS `/metrics` strict payload checks are green.
- Evidence identity must be stable across all artifacts: `env=<lane>;profile=nonprod|prod;context=<k8s_context>;project=<project>`.
- Each wave must produce `var/ci/observability-first-class-runtime-evidence-index.json`.
