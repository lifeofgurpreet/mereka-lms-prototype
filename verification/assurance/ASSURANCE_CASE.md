# Assurance Case: Mereka Academy Platform

> A structured claim-argument-evidence ledger demonstrating that the platform
> meets its reliability, security, and data integrity obligations.

## How to Read This Document

Each **Claim** states a top-level assurance goal. Under each claim, **Arguments**
explain why the claim holds. Each argument is supported by **Evidence** — concrete
artifacts (specs, tests, monitoring) that prove the argument.

Status: `supported` = evidence exists and passes, `partial` = some evidence exists,
`unsupported` = evidence needed.

---

## C-001: Platform Reliability

**Claim**: The Mereka Academy platform maintains 99.5% uptime SLO for learner-facing services.

### Arguments

| ID | Argument | Status | Evidence |
|----|----------|--------|----------|
| A-001-1 | K8s deployments have health checks and auto-restart | supported | `specs/k8s-deployment_spec.md` AC-K8S-001 to AC-K8S-005, liveness/readiness probes in `deploy/k8s/base/` |
| A-001-2 | SLO targets are defined and monitored | supported | `specs/slo-sla-service-level-management_spec.md`, Grafana SLO dashboards |
| A-001-3 | Alerting fires within 5 minutes of threshold breach | partial | `specs/observability-stack_spec.md`, `deploy/k8s/base/monitoring/prometheusrule-lms.yaml` |
| A-001-4 | Disaster recovery restores service within 4h RTO | partial | `specs/disaster-recovery-business-continuity_spec.md`, Velero backup CronJobs |
| A-001-5 | Service selector mismatches are auto-detected | supported | `scripts/infra/fix-service-selectors.sh`, endpoint monitoring |

---

## C-002: Data Integrity

**Claim**: Learner data (enrollments, grades, certificates) is never lost or corrupted during normal operations, migrations, or failures.

### Arguments

| ID | Argument | Status | Evidence |
|----|----------|--------|----------|
| A-002-1 | Database backups run daily with PITR | supported | MongoDB Atlas continuous backup, `specs/disaster-recovery-business-continuity_spec.md` |
| A-002-2 | Migrations verify zero data loss | supported | `specs/data-migrations-kajabi-mct_spec.md` AC-001 to AC-010, verification scripts |
| A-002-3 | Schema changes are backwards-compatible | partial | Django migration framework, `specs/cross-cutting-requirements_spec.md` Section 4 |
| A-002-4 | GDPR deletion preserves audit trail | partial | `specs/data-privacy-gdpr-compliance_spec.md` AC-031 to AC-034 |
| A-002-5 | Multi-tenant data isolation is enforced | supported | `specs/multi-tenancy-architecture_spec.md` AC-MTA-003 to AC-MTA-005 |

---

## C-003: Security Posture

**Claim**: The platform protects against OWASP Top 10 vulnerabilities and maintains secure credential management.

### Arguments

| ID | Argument | Status | Evidence |
|----|----------|--------|----------|
| A-003-1 | Secrets are never hardcoded | supported | `specs/secrets-management_spec.md`, pre-commit hook `.githooks/pre-commit`, `scripts/qa/scan-secrets-fast.sh` |
| A-003-2 | Authentication uses industry-standard protocols | supported | `specs/auth-sso-enterprise_spec.md`, Authentik OIDC + PKCE |
| A-003-3 | CSRF and XSS protections are active | supported | Django middleware, `CSRF_TRUSTED_ORIGINS` in production settings |
| A-003-4 | Network access is restricted by namespace | partial | K8s NetworkPolicies (planned), `specs/k8s-deployment_spec.md` |
| A-003-5 | XQueue sandbox isolates student code | partial | `specs/advanced-assessment-xqueue_spec.md` AC-021 to AC-025 |

---

## C-004: Operational Observability

**Claim**: All production services are monitored with metrics, logs, and alerts that enable rapid incident response.

### Arguments

| ID | Argument | Status | Evidence |
|----|----------|--------|----------|
| A-004-1 | Prometheus metrics exported from all services | supported | `specs/observability-stack_spec.md`, db exporters, `scripts/qa/audit-db-exporter-telemetry.sh` |
| A-004-2 | Structured logs shipped to Loki | partial | Promtail + Loki deployment, `infrastructure/monitoring/` |
| A-004-3 | Distributed tracing via Tempo | partial | `specs/observability-stack_spec.md`, 10% sampling configured |
| A-004-4 | Alert routing delivers to correct channels | supported | `scripts/qa/verify-alert-routing.sh`, Slack + PagerDuty |
| A-004-5 | Dashboards cover all critical services | supported | `scripts/qa/audit-grafana-dashboard.sh`, dashboard contract |

---

## C-005: Compliance

**Claim**: The platform meets GDPR and Malaysia PDPA requirements for personal data processing.

### Arguments

| ID | Argument | Status | Evidence |
|----|----------|--------|----------|
| A-005-1 | Consent management framework defined | partial | `specs/data-privacy-gdpr-compliance_spec.md` AC-008 to AC-012 |
| A-005-2 | Right to erasure pipeline specified | partial | `specs/data-privacy-gdpr-compliance_spec.md` AC-031 to AC-034 |
| A-005-3 | Data retention policies defined | partial | `specs/data-privacy-gdpr-compliance_spec.md` AC-013 to AC-015 |
| A-005-4 | PII inventory maintained | unsupported | Planned: `docs/policies/operations/PII_DATA_INVENTORY.md` |
| A-005-5 | Processor DPAs tracked | unsupported | Planned: legal/operational prerequisite |

---

## Evidence Gap Summary

| Status | Count | Action |
|--------|-------|--------|
| supported | 14 | Maintain and verify in CI |
| partial | 9 | Complete implementation, add automated verification |
| unsupported | 2 | Prioritize for next sprint |

---

*Last updated: 2026-02-13*
