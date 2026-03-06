# Observability Compliance Evidence

- generated_at: 2026-03-03T04:11:32Z
- mode: runtime
- strict: 1
- environment_label: nonprod
- dispatch_profile: nonprod
- app_namespace: mereka-lms
- k8s_context: rke2-nonprod
- gcp_project: mereka-lms
- evidence_identity: env=nonprod;profile=nonprod;context=rke2-nonprod;project=mereka-lms

## Summary

- pass: 5
- fail: 4
- skip: 0
- total: 9

## Failed Checks

- AC-OVR-016: LMS /metrics returned 404 (expected 200)
- AC-OVR-016: LMS /metrics payload unavailable or invalid for Prometheus exposition validation
- AC-OVR-016: CMS /metrics returned 404 (expected 200)
- AC-OVR-016: CMS /metrics payload unavailable or invalid for Prometheus exposition validation
