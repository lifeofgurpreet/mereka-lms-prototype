# Analytics & Reporting
_Audience: Platform Eng + Data • Owner: Analytics Guild • Last verified: 2025-11-09_

Use this folder whenever you need to instrument, deploy, or interpret analytics across Mereka Academy. Start with the installation + quickstart docs if you are standing up Aspects, then branch into the comparative studies and utility guides below.

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`ASPECTS_INSTALLATION.md`](ASPECTS_INSTALLATION.md) | Step-by-step Aspects deployment on Tutor (services, env vars, health checks). | 2025-07-25 |
| [`ASPECTS_QUICKSTART.md`](ASPECTS_QUICKSTART.md) | Post-install validation checklist plus smoke tests for Superset + ClickHouse. | 2025-07-25 |
| [`ASPECTS_ACCESS.md`](ASPECTS_ACCESS.md) | Credential provisioning, RBAC, and secure sharing for Superset/Aspects. | 2025-07-25 |
| [`ASPECTS_ANALYTICS.md`](ASPECTS_ANALYTICS.md) | How we interpret the shipped dashboards and which metrics matter. | 2025-07-25 |
| [`ASPECTS_VS_PANORAMA.md`](ASPECTS_VS_PANORAMA.md) | Decision record comparing Aspects and Panorama for reporting needs. | 2025-07-25 |
| [`ASPECTS_K8S_DEPLOYMENT.md`](ASPECTS_K8S_DEPLOYMENT.md) | Resource tuning and deployment guide for Aspects on GKE Autopilot. | 2025-11-09 |
| [`PANORAMA_ANALYTICS.md`](PANORAMA_ANALYTICS.md) | Panorama-specific setup plus dashboard coverage. | 2025-07-25 |
| [`OPENEDX_ANALYTICS.md`](OPENEDX_ANALYTICS.md) | Built-in LMS analytics hooks, exports, and where to find raw data. | 2025-07-25 |
| [`ENROLLMENT_COMPARISON_QUICKSTART.md`](ENROLLMENT_COMPARISON_QUICKSTART.md) | Script-driven checklist for reconciling Kajabi vs Open edX enrollments. | 2025-10-01 |

**Related folders:**
- `docs/migrations/kajabi/` for the import/export runbooks that feed analytics.
- `tools/` for Python/Node helpers such as `scripts/analytics/openedx-analytics.py` when you need raw extracts.
