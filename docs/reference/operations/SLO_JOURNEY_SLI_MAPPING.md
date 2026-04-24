# SLO Journey-to-SLI Mapping (Mereka LMS)

Version: 1
Last updated: 2026-02-25

This document defines the Tier-1 user journeys that are currently in scope for observability work and binds each one to:

- owning service
- journey tier
- owning SLI metric
- concrete recording query used by PrometheusRule definitions

## Scope

This mapping is part of observability first-classing for production, dev, and non-production stacks. Journey-level SLIs are additive to existing service-level SLIs and are intended for:

- business-critical operator runbooks
- future journey-level alerting and burn-rate checks
- dashboard drill-downs by user path

All filters below must remain valid against the same metric families used by existing service SLIs in this repo.

## Tier-1 Journey Mapping

| Journey ID | Journey | Owner service | Journey tier | Canonical SLI (recording name) | Filter contract |
|---|---|---|---|---|---|
| `journey_lms_login` | LMS sign-in and authentication handoff | lms | 1 | `mereka:http_requests:availability_ratio_{5m,30m,1h,6h}` | `job="lms-metrics",status=~"5..",view=~".*auth.*|.*login.*|.*oidc.*|.*sso.*"` |
| `journey_lms_course_access` | Learner course launch and chapter navigation | lms | 1 | `mereka:http_requests:availability_ratio_{5m,30m,1h,6h}` | `job="lms-metrics",status=~"5..",view=~".*/courses/.*/courseware.*|.*/learn/.*/info/?.*|.*/api/courseware/.*"` |
| `journey_cms_authoring` | Content authoring and courseware edits in Studio | cms | 1 | `mereka:http_requests:availability_ratio_{5m,30m,1h,6h}` | `job="cms-metrics",status=~"5..",view=~".*/course/.*/(settings|course_outline|updates|xblock|edit|group_configurations).*|.*/account/.*/dashboard.*"` |
| `journey_purchase_checkout` | Checkout start + payment API write path | purchase-gateway | 1 | `mereka:http_requests:availability_ratio_{5m,30m,1h,6h}` | `job="purchase-gateway-metrics",status_code=~"5..",handler=~".*/payments/.*|.*/checkout/.*|.*/orders/.*"` |
| `journey_purchase_webhook` | Gateway webhook/event intake and reconciliation | purchase-gateway | 1 | `mereka:http_requests:availability_ratio_{5m,30m,1h,6h}` | `job="purchase-gateway-metrics",status_code=~"5..",handler=~".*/webhook.*|.*/stripe/.*|.*/events/.*"` |

## Journey SLO Rules of Record

- `tier` remains the owning service tier for alert inheritance (`1` for all rows in this table).
- `journey` is the new Prometheus label used for slicing/aggregating journey metrics.
- `journey_tier` is currently pinned to `"1"` for all mappings in this table.
- Journey queries use the same 4xx-exclusion denominator pattern as service SLIs.

## Current Rule Location

- `deploy/k8s/base/monitoring/slo-burn-rate-rules.yaml` (recording rules; journey labels added)
- `docs/qa/OBSERVABILITY_NEXT50_TRACKER_MEREKA_LMS.md` task entries `OBS-016` and `OBS-017`

## Validation Notes

1. Query these series by journey label in runtime checks or dashboards:
   - `mereka:http_requests:availability_ratio_5m{journey="journey_lms_login"}`
   - `mereka:http_requests:availability_ratio_30m{journey="journey_purchase_checkout"}`
2. Burn-rate companion series must use the same journey label set (to be used by journey-specific burn alerting in the next phase).

