# Documentation Index by Audience
_Last updated: 2026-02-12 • Owner: Documentation Team_

This index organizes all Mereka Academy Open edX documentation by reader role. Each section provides a **learning path** from basics to advanced topics, plus quick references and contact information.

**Quick Navigation**: [Platform Operators](#-platform-operators) • [SREs](#-site-reliability-engineers-sres) • [Developers](#-developers) • [Enterprise Admins](#-enterprise-administrators) • [Security Auditors](#-security-auditors)

---

## 🎯 Platform Operators
_Deploy, scale, monitor, and maintain the platform day-to-day_

### Learning Path

#### Start Here (First Week)
1. **[Repository Guide](onboarding/REPOSITORY_GUIDE.md)** - Understand repository structure
2. **[K8s Operations Guide](operations/guides/K8S_OPERATIONS_GUIDE.md)** - Core Kubernetes operations
3. **[Quick Reference](QUICK_REFERENCE.md)** - Daily commands and workflows
4. **[Access URLs](operations/ACCESS_URLS.md)** - All system URLs and credentials

#### Foundational (First Month)
5. **[Secrets Management Guide](operations/guides/SECRETS_MANAGEMENT_GUIDE.md)** - Secrets pipeline (Infisical → GCP SM → K8s)
6. **[MongoDB Atlas Guide](operations/guides/MONGODB_ATLAS_GUIDE.md)** - Database operations and monitoring
7. **[Multi-Site Guide](operations/guides/MULTI_SITE_GUIDE.md)** - Multi-domain configuration
8. **[Observability Guide](operations/guides/OBSERVABILITY_GUIDE.md)** - Metrics, logs, traces, alerts
9. **[Admin Login Guide](operations/guides/ADMIN_LOGIN_GUIDE.md)** - User management and access control

#### Advanced Topics
10. **[Enterprise Services Guide](operations/guides/ENTERPRISE_SERVICES_GUIDE.md)** - Deploy and manage B2B microservices
11. **[Deployment Runbook](operations/runbooks/DEPLOYMENT_RUNBOOK.md)** - Production deployment procedures
12. **[Domain Change Runbook](operations/runbooks/DOMAIN_CHANGE_RUNBOOK.md)** - Domain migrations
13. **[Tutor Configuration Runbook](operations/runbooks/TUTOR_CONFIGURATION_RUNBOOK.md)** - Advanced Tutor config
14. **[CI/CD Runbook](operations/runbooks/CI_CD_RUNBOOK.md)** - Build and deployment automation

### Quick References

**Daily Operations**:
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Common commands
- [ACCESS_URLS.md](operations/ACCESS_URLS.md) - All system URLs
- [OBSERVABILITY_QUICKSTART.md](operations/OBSERVABILITY_QUICKSTART.md) - Fast health checks

**Configuration**:
- [TUTOR_CONFIG_SAFETY.md](operations/TUTOR_CONFIG_SAFETY.md) - Safe config changes
- [OPENEDX_HOSTNAMES.md](operations/OPENEDX_HOSTNAMES.md) - Hostname registry
- [CLOUDFLARE_DNS.md](operations/CLOUDFLARE_DNS.md) - DNS management

**Monitoring**:
- [MONITORING.md](operations/MONITORING.md) - Monitoring strategy
- [SLO_DASHBOARDS_SETUP.md](operations/SLO_DASHBOARDS_SETUP.md) - Dashboard setup
- [ALERT_SEVERITY_MATRIX.md](operations/ALERT_SEVERITY_MATRIX.md) - Alert severity levels

### Relevant Runbooks

**Service Management**:
- [FORUM_SERVICE_RUNBOOK.md](operations/runbooks/FORUM_SERVICE_RUNBOOK.md) - Forum operations
- [MONGODB_ATLAS_RUNBOOK.md](operations/runbooks/MONGODB_ATLAS_RUNBOOK.md) - Database operations
- [ANALYTICS_RUNBOOK.md](operations/runbooks/ANALYTICS_RUNBOOK.md) - Analytics platform
- [MULTI_TENANCY_RUNBOOK.md](operations/runbooks/MULTI_TENANCY_RUNBOOK.md) - Tenant provisioning

**Feature Management**:
- [AUTH_SSO_RUNBOOK.md](operations/runbooks/AUTH_SSO_RUNBOOK.md) - SSO configuration
- [BADGES_CREDENTIALS_RUNBOOK.md](operations/runbooks/BADGES_CREDENTIALS_RUNBOOK.md) - Badges/certificates
- [EMAIL_NOTIFICATIONS_RUNBOOK.md](operations/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md) - Email configuration
- [MOBILE_APPS_RUNBOOK.md](operations/runbooks/MOBILE_APPS_RUNBOOK.md) - Mobile app operations

### Contact/Escalation
- **Daily Questions**: Engineering team Slack channel
- **Incidents**: Follow [ONCALL_OBSERVABILITY_PLAYBOOK.md](operations/ONCALL_OBSERVABILITY_PLAYBOOK.md)
- **Change Requests**: Submit via [RELEASE_CHECKLIST.md](operations/RELEASE_CHECKLIST.md)

---

## 🚨 Site Reliability Engineers (SREs)
_Incident response, performance troubleshooting, disaster recovery_

### Learning Path

#### Start Here (On-Call Prep)
1. **[Site Down Runbook](operations/runbooks/site-down.md)** - **CRITICAL**: Site outage diagnostic tree
2. **[On-Call Observability Playbook](operations/ONCALL_OBSERVABILITY_PLAYBOOK.md)** - Incident triage sequence
3. **[Alert Severity Matrix](operations/ALERT_SEVERITY_MATRIX.md)** - Severity levels and routing
4. **[Quick Reference](QUICK_REFERENCE.md)** - Emergency commands

#### Foundational (First Week On-Call)
5. **[Performance Degradation Runbook](operations/runbooks/performance-degradation.md)** - Latency/slowness diagnosis
6. **[Database Issues Runbook](operations/runbooks/database-issues.md)** - MySQL/MongoDB failures
7. **[K8s Operations Guide](operations/guides/K8S_OPERATIONS_GUIDE.md)** - Pod/service troubleshooting
8. **[Observability Guide](operations/guides/OBSERVABILITY_GUIDE.md)** - Logs, metrics, traces
9. **[Disaster Recovery](operations/runbooks/DISASTER_RECOVERY.md)** - Backup/restore procedures

#### Advanced Topics
10. **[Auth Alert Runbook](operations/runbooks/AUTH_ALERT_RUNBOOK.md)** - Authentication incident response
11. **[Velero Backup Audit](operations/VELERO_BACKUP_AUDIT.md)** - Backup verification
12. **[DR Test Results](operations/DR_TEST_RESULTS.md)** - Recovery test outcomes
13. **[Incident Templates](operations/INCIDENT_TEMPLATES.md)** - Postmortem structure
14. **[Alert Tuning SOP](operations/ALERT_TUNING_SOP.md)** - Noise reduction process

### Quick References

**Incident Response**:
- [site-down.md](operations/runbooks/site-down.md) - Site outage (5-10 min resolution)
- [performance-degradation.md](operations/runbooks/performance-degradation.md) - Slow response times
- [database-issues.md](operations/runbooks/database-issues.md) - DB connection failures
- [AUTH_ALERT_RUNBOOK.md](operations/runbooks/AUTH_ALERT_RUNBOOK.md) - Auth failures

**Diagnostics**:
- [TROUBLESHOOTING.md](operations/runbooks/site-down.md) - Common issues checklist
- [OBSERVABILITY_QUICKSTART.md](operations/OBSERVABILITY_QUICKSTART.md) - Fast health audit
- [DEPLOYMENT_VERIFICATION.md](operations/DEPLOYMENT_VERIFICATION.md) - Post-deploy checks

**Recovery**:
- [DISASTER_RECOVERY.md](operations/runbooks/DISASTER_RECOVERY.md) - Restore procedures
- [VELERO_BACKUP_AUDIT.md](operations/VELERO_BACKUP_AUDIT.md) - Backup status
- [COURSE_DATA_RECOVERY.md](operations/COURSE_DATA_RECOVERY.md) - Course data restore

### Relevant Runbooks

**Performance**:
- [performance-degradation.md](operations/runbooks/performance-degradation.md) - Latency diagnosis
- [database-issues.md](operations/runbooks/database-issues.md) - DB performance
- [MONGODB_ATLAS_RUNBOOK.md](operations/runbooks/MONGODB_ATLAS_RUNBOOK.md) - Atlas monitoring

**Availability**:
- [site-down.md](operations/runbooks/site-down.md) - Site outages
- [DISASTER_RECOVERY.md](operations/runbooks/DISASTER_RECOVERY.md) - DR procedures
- [DEPLOYMENT_RUNBOOK.md](operations/runbooks/DEPLOYMENT_RUNBOOK.md) - Safe deployments

**Observability**:
- [ONCALL_OBSERVABILITY_PLAYBOOK.md](operations/ONCALL_OBSERVABILITY_PLAYBOOK.md) - Triage workflow
- [ALERT_TUNING_SOP.md](operations/ALERT_TUNING_SOP.md) - Weekly alert review
- [OBSERVABILITY_OWNERSHIP.md](operations/OBSERVABILITY_OWNERSHIP.md) - Source of truth model

### Architecture Understanding

**System Design**:
- [DATABASE_ARCHITECTURE.md](architecture/DATABASE_ARCHITECTURE.md) - All databases explained
- [MULTISITE_ANALYSIS.md](architecture/MULTISITE_ANALYSIS.md) - Multi-domain architecture
- [PRODUCTION_ARCHITECTURE_REALITY.md](PRODUCTION_ARCHITECTURE_REALITY.md) - Current prod topology

**Service Interactions**:
- [enterprise-services-overview.md](architecture/enterprise-services-overview.md) - B2B services
- [notification-pipeline-overview.md](architecture/notification-pipeline-overview.md) - Email/notifications
- [multi-tenancy-overview.md](architecture/multi-tenancy-overview.md) - Tenant isolation

### Contact/Escalation
- **P0/P1 Incidents**: On-call rotation ([ONCALL_ROTATION.md](operations/ONCALL_ROTATION.md))
- **Escalation**: Platform Engineering lead
- **Postmortems**: Template in [INCIDENT_TEMPLATES.md](operations/INCIDENT_TEMPLATES.md)
- **SLA Reports**: [SLA_REPORTING.md](operations/SLA_REPORTING.md)

---

## 💻 Developers
_Local setup, feature development, testing, contribution_

### Learning Path

#### Start Here (Day 1)
1. **[Quick Start Local](onboarding/QUICK_START_LOCAL.md)** - 5-minute setup
2. **[Agent Setup Checklist](onboarding/AGENT_SETUP_CHECKLIST.md)** - Step-by-step setup
3. **[Repository Guide](onboarding/REPOSITORY_GUIDE.md)** - Find your way around
4. **[Local Development Guide](onboarding/LOCAL_DEVELOPMENT_GUIDE.md)** - Complete reference

#### Foundational (First Week)
5. **[Developer Onboarding](onboarding/DEVELOPER_ONBOARDING.md)** - Full onboarding guide
6. **[Workflow Local](onboarding/WORKFLOW_LOCAL.md)** - Daily commands
7. **[Local Setup](onboarding/LOCAL_SETUP.md)** - Detailed Tutor bootstrap
8. **[Branding Guide](BRANDING.md)** - Theme customization

#### Advanced Topics
9. **[Multi-Developer Workflow](MULTI_DEVELOPER_WORKFLOW.md)** - Team collaboration
10. **[Tutor Plugin Migration Runbook](operations/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md)** - Plugin development
11. **[Repository Structure Runbook](operations/runbooks/REPOSITORY_STRUCTURE_RUNBOOK.md)** - Add new features
12. **[CI/CD Runbook](operations/runbooks/CI_CD_RUNBOOK.md)** - Build pipeline

### Quick References

**Daily Development**:
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Common commands
- [WORKFLOW_LOCAL.md](onboarding/WORKFLOW_LOCAL.md) - Daily workflow
- [LOCAL_ACCESS_INFO.md](operations/LOCAL_ACCESS_INFO.md) - Local URLs/creds

**Testing**:
- [LOCAL_PRODUCTION_PARITY.md](operations/LOCAL_PRODUCTION_PARITY.md) - Parity verification
- [PARITY_ISSUES_FOUND.md](status/PARITY_ISSUES_FOUND.md) - Known parity issues
- [PRODUCTION_VERIFICATION_CHECKLIST.md](PRODUCTION_VERIFICATION_CHECKLIST.md) - Pre-deploy checks

**Troubleshooting**:
- [TROUBLESHOOTING.md](operations/runbooks/site-down.md) - Common issues
- `MFE_LOGIN_FIX.md` (archived at `archive/MFE_LOGIN_FIX.md`) - MFE auth issues
- `MFE_REBUILD_SUCCESS.md` (archived at `archive/MFE_REBUILD_SUCCESS.md`) - MFE rebuild guide

### Relevant Runbooks

**Development**:
- [TUTOR_CONFIGURATION_RUNBOOK.md](operations/runbooks/TUTOR_CONFIGURATION_RUNBOOK.md) - Tutor config
- [TUTOR_PLUGIN_MIGRATION_RUNBOOK.md](operations/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md) - Plugin dev
- [REPOSITORY_STRUCTURE_RUNBOOK.md](operations/runbooks/REPOSITORY_STRUCTURE_RUNBOOK.md) - Repo navigation

**Feature Development**:
- [content-libraries-runbook.md](runbooks/content-libraries-runbook.md) - Content libraries
- [badges-credentials-runbook.md](runbooks/badges-credentials-runbook.md) - Badges/certificates
- [external-registration-runbook.md](runbooks/external-registration-runbook.md) - HubSpot integration
- [purchase-gateway-runbook.md](runbooks/purchase-gateway-runbook.md) - Payment gateway

### Architecture Understanding

**System Overview**:
- [DATABASE_ARCHITECTURE.md](architecture/DATABASE_ARCHITECTURE.md) - Database layer
- [MULTISITE_ANALYSIS.md](architecture/MULTISITE_ANALYSIS.md) - Multi-site setup
- [PRODUCTION_ARCHITECTURE_REALITY.md](PRODUCTION_ARCHITECTURE_REALITY.md) - Current topology

**Service Architecture**:
- [enterprise-services-overview.md](architecture/enterprise-services-overview.md) - B2B microservices
- [purchase-gateway-overview.md](architecture/purchase-gateway-overview.md) - Payment processing
- [multi-tenancy-overview.md](architecture/multi-tenancy-overview.md) - Tenant isolation
- [notification-pipeline-overview.md](architecture/notification-pipeline-overview.md) - Email pipeline
- [proctoring-architecture-overview.md](architecture/proctoring-architecture-overview.md) - Proctoring system

### ADRs (Architecture Decision Records)

**Infrastructure**:
- [001-mongodb-atlas.md](adr/001-mongodb-atlas.md) - Why MongoDB Atlas
- [002-multisite-architecture.md](adr/002-multisite-architecture.md) - Multi-domain approach
- [003-image-build-pipeline.md](adr/003-image-build-pipeline.md) - Image build strategy
- [009-in-cluster-storage.md](adr/009-in-cluster-storage.md) - Storage decisions
- [010-monorepo-architecture.md](adr/010-monorepo-architecture.md) - Monorepo rationale

**Security & Operations**:
- [004-secrets-management.md](adr/004-secrets-management.md) - Secrets pipeline
- [005-domain-migration.md](adr/005-domain-migration.md) - Domain changes
- [006-tutor-plugin-based-configuration.md](adr/006-tutor-plugin-based-configuration.md) - Plugin architecture
- [007-forum-migration-ruby-to-python.md](adr/007-forum-migration-ruby-to-python.md) - Forum v2
- [008-redis-streams-event-bus.md](adr/008-redis-streams-event-bus.md) - Event bus
- [011-convention-based-spec-verification.md](adr/011-convention-based-spec-verification.md) - Test coverage

### Contact/Escalation
- **Technical Questions**: Engineering team Slack
- **Code Review**: Submit PR, tag reviewers
- **Architecture Decisions**: Propose ADR (see [adr/README.md](adr/README.md))
- **Build Issues**: Check [CI_CD_RUNBOOK.md](operations/runbooks/CI_CD_RUNBOOK.md)

---

## 🏢 Enterprise Administrators
_Tenant management, SSO configuration, user provisioning_

### Learning Path

#### Start Here (First Day)
1. **[Admin Login Guide](operations/guides/ADMIN_LOGIN_GUIDE.md)** - Access and permissions
2. **[Access URLs](operations/ACCESS_URLS.md)** - All admin interfaces
3. **[Multi-Site Guide](operations/guides/MULTI_SITE_GUIDE.md)** - Multi-domain setup
4. **[Auth and Permissions](operations/AUTH_AND_PERMISSIONS.md)** - SSO integration

#### Foundational (First Week)
5. **[Enterprise Services Guide](operations/guides/ENTERPRISE_SERVICES_GUIDE.md)** - B2B services overview
6. **[Tenant Provisioning Runbook](runbooks/tenant-provisioning-runbook.md)** - Create new tenants
7. **[Auth SSO Runbook](operations/runbooks/AUTH_SSO_RUNBOOK.md)** - Configure SSO
8. **[Domain Change Runbook](operations/runbooks/DOMAIN_CHANGE_RUNBOOK.md)** - Domain management

#### Advanced Topics
9. **[Enterprise Services Runbook](runbooks/enterprise-services-runbook.md)** - Manage B2B features
10. **[Auth SSO Enterprise Runbook](runbooks/auth-sso-enterprise-runbook.md)** - Enterprise SSO
11. **[Purchase Gateway Runbook](runbooks/purchase-gateway-runbook.md)** - Payment integration
12. **[External Registration Runbook](runbooks/external-registration-runbook.md)** - HubSpot integration

### Quick References

**Admin Access**:
- [ACCESS_URLS.md](operations/ACCESS_URLS.md) - All admin URLs
- [ADMIN_LOGIN_GUIDE.md](operations/guides/ADMIN_LOGIN_GUIDE.md) - Login procedures
- [OPENEDX_HOSTNAMES.md](operations/OPENEDX_HOSTNAMES.md) - Hostname registry

**Configuration**:
- [AUTH_AND_PERMISSIONS.md](operations/AUTH_AND_PERMISSIONS.md) - Permission model
- [MULTISITE.md](operations/MULTISITE.md) - Multi-site config
- [MULTI_SITE_GUIDE.md](operations/guides/MULTI_SITE_GUIDE.md) - Domain setup

**User Management**:
- [COURSE_IMPORT_GUIDE.md](COURSE_IMPORT_GUIDE.md) - Import courses
- [DISCOVERY_QUICKSTART.md](operations/DISCOVERY_QUICKSTART.md) - Course catalog
- [COURSE_CERTIFICATES_UI.md](operations/COURSE_CERTIFICATES_UI.md) - Certificate management

### Relevant Runbooks

**Tenant Management**:
- [tenant-provisioning-runbook.md](runbooks/tenant-provisioning-runbook.md) - Provision tenants
- [MULTI_TENANCY_RUNBOOK.md](operations/runbooks/MULTI_TENANCY_RUNBOOK.md) - Multi-tenant operations

**Authentication**:
- [AUTH_SSO_RUNBOOK.md](operations/runbooks/AUTH_SSO_RUNBOOK.md) - SSO setup
- [auth-sso-enterprise-runbook.md](runbooks/auth-sso-enterprise-runbook.md) - Enterprise SSO
- [RFC_CLAIM_BASED_ROLE_SYNC.md](operations/RFC_CLAIM_BASED_ROLE_SYNC.md) - Role synchronization

**Enterprise Features**:
- [enterprise-services-runbook.md](runbooks/enterprise-services-runbook.md) - B2B services
- [purchase-gateway-runbook.md](runbooks/purchase-gateway-runbook.md) - Payment gateway
- [STRIPE_WEBHOOKS_SETUP.md](operations/STRIPE_WEBHOOKS_SETUP.md) - Payment webhooks

### Architecture Understanding

**Multi-Tenancy**:
- [multi-tenancy-overview.md](architecture/multi-tenancy-overview.md) - Tenant architecture
- [MULTISITE_ANALYSIS.md](architecture/MULTISITE_ANALYSIS.md) - Multi-site design
- [MULTISITE_GOVERNANCE.md](operations/MULTISITE_GOVERNANCE.md) - Governance model

**Enterprise Services**:
- [enterprise-services-overview.md](architecture/enterprise-services-overview.md) - Service architecture
- [purchase-gateway-overview.md](architecture/purchase-gateway-overview.md) - Payment flow
- [badges-credentials-runbook.md](runbooks/badges-credentials-runbook.md) - Credentials system

### Contact/Escalation
- **Tenant Requests**: Submit via tenant provisioning form
- **SSO Issues**: Contact platform team
- **Payment Issues**: Check [purchase-gateway-runbook.md](runbooks/purchase-gateway-runbook.md)
- **User Access Issues**: Follow [ADMIN_LOGIN_GUIDE.md](operations/guides/ADMIN_LOGIN_GUIDE.md)

---

## 🔒 Security Auditors
_Security configs, compliance, audit logs, secrets management_

### Learning Path

#### Start Here (First Audit)
1. **[Secrets Management Guide](operations/guides/SECRETS_MANAGEMENT_GUIDE.md)** - Secrets pipeline
2. **[Auth Hardening Spec](operations/AUTH_HARDENING_SPEC.md)** - Security hardening
3. **[K8s Operations Guide](operations/guides/K8S_OPERATIONS_GUIDE.md)** - Security contexts
4. **[Secrets Snapshot](operations/SECRETS_SNAPSHOT.md)** - Secret inventory

#### Foundational (First Week)
5. **[Data Privacy Compliance Runbook](runbooks/data-privacy-compliance-runbook.md)** - GDPR/PDPA compliance
6. **[Auth and Permissions](operations/AUTH_AND_PERMISSIONS.md)** - Auth model
7. **[In-Cluster Auth Verification](operations/IN_CLUSTER_AUTH_VERIFICATION.md)** - Auth surface checks
8. **[Secret Rotation Checklist](operations/SECRET_ROTATION_CHECKLIST.md)** - Secret rotation

#### Advanced Topics
9. **[Auth Alert Runbook](operations/runbooks/AUTH_ALERT_RUNBOOK.md)** - Auth incident response
10. **[Disaster Recovery](operations/runbooks/DISASTER_RECOVERY.md)** - Backup security
11. **[Velero Backup Audit](operations/VELERO_BACKUP_AUDIT.md)** - Backup verification
12. **[Backup Coverage Matrix](operations/BACKUP_COVERAGE_MATRIX.md)** - Backup scope

### Quick References

**Security Config**:
- [SECRETS_MANAGEMENT_GUIDE.md](operations/guides/SECRETS_MANAGEMENT_GUIDE.md) - Secrets pipeline
- [SECRETS_SNAPSHOT.md](operations/SECRETS_SNAPSHOT.md) - Secret inventory
- [SECRET_ROTATION_CHECKLIST.md](operations/SECRET_ROTATION_CHECKLIST.md) - Rotation procedures
- [INFISICAL_MEREKA_LMS_KEYS.md](operations/INFISICAL_MEREKA_LMS_KEYS.md) - Key registry

**Authentication**:
- [AUTH_HARDENING_SPEC.md](operations/AUTH_HARDENING_SPEC.md) - Hardening spec
- [AUTH_AND_PERMISSIONS.md](operations/AUTH_AND_PERMISSIONS.md) - Permission model
- [IN_CLUSTER_AUTH_VERIFICATION.md](operations/IN_CLUSTER_AUTH_VERIFICATION.md) - Verification
- [RFC_CLAIM_BASED_ROLE_SYNC.md](operations/RFC_CLAIM_BASED_ROLE_SYNC.md) - Role sync

**Compliance**:
- [data-privacy-compliance-runbook.md](runbooks/data-privacy-compliance-runbook.md) - GDPR/PDPA
- [BACKUP_COVERAGE_MATRIX.md](operations/BACKUP_COVERAGE_MATRIX.md) - Backup coverage
- [VELERO_BACKUP_AUDIT.md](operations/VELERO_BACKUP_AUDIT.md) - Backup verification

### Relevant Runbooks

**Security Operations**:
- [AUTH_ALERT_RUNBOOK.md](operations/runbooks/AUTH_ALERT_RUNBOOK.md) - Auth incidents
- [SECRET_ROTATION_CHECKLIST.md](operations/SECRET_ROTATION_CHECKLIST.md) - Secret rotation
- [data-privacy-compliance-runbook.md](runbooks/data-privacy-compliance-runbook.md) - Privacy compliance

**Audit & Compliance**:
- [DISASTER_RECOVERY.md](operations/runbooks/DISASTER_RECOVERY.md) - DR procedures
- [VELERO_BACKUP_AUDIT.md](operations/VELERO_BACKUP_AUDIT.md) - Backup audits
- [DR_TEST_RESULTS.md](operations/DR_TEST_RESULTS.md) - Recovery test results

### Architecture Understanding

**Security Architecture**:
- [ADR 004: Secrets Management](adr/004-secrets-management.md) - Secrets design
- [multi-tenancy-overview.md](architecture/multi-tenancy-overview.md) - Tenant isolation
- [DATABASE_ARCHITECTURE.md](architecture/DATABASE_ARCHITECTURE.md) - Data layer security

**Authentication Flow**:
- [AUTH_AND_PERMISSIONS.md](operations/AUTH_AND_PERMISSIONS.md) - Auth integration
- [auth-sso-enterprise-runbook.md](runbooks/auth-sso-enterprise-runbook.md) - SSO architecture

### Audit Artifacts

**Verification Scripts**:
- `scripts/qa/verify-secrets-sync.sh` - Secrets sync verification
- `scripts/qa/verify-atlas-modulestore-path.sh` - MongoDB Atlas verification
- `scripts/infra/ensure-platform-admins.sh` - Admin access verification
- `scripts/qa/audit-velero.sh` - Backup audit

**Configuration Reviews**:
- [K8S_OPERATIONS_GUIDE.md](operations/guides/K8S_OPERATIONS_GUIDE.md) - K8s security
- [MONGODB_ATLAS_GUIDE.md](operations/guides/MONGODB_ATLAS_GUIDE.md) - Database security
- [OBSERVABILITY_GUIDE.md](operations/guides/OBSERVABILITY_GUIDE.md) - Logging/monitoring

### Contact/Escalation
- **Security Incidents**: Contact security team immediately
- **Compliance Questions**: Compliance officer
- **Audit Requests**: Submit via security team
- **Secret Rotation**: Follow [SECRET_ROTATION_CHECKLIST.md](operations/SECRET_ROTATION_CHECKLIST.md)

---

## 📊 Additional Resources

### Migrations & Data
- **Kajabi Migration**: [migrations/kajabi/](migrations/kajabi/) - Kajabi → Open edX migration
- **MCT Migration**: [migrations/mct/](migrations/mct/) - MCT → Open edX migration
- **Drive + Airtable Video Inventory**: [migrations/drive-airtable/README.md](migrations/drive-airtable/README.md), [migrations/drive-airtable/STATUS.md](migrations/drive-airtable/STATUS.md), [migrations/drive-airtable/REVIEW_QUEUE.md](migrations/drive-airtable/REVIEW_QUEUE.md) - Course-first pipeline for nested Drive video mapping with migration-readiness gates, blocker queues, subtitle review, and Open edX contract tracking. REVIEW_QUEUE.md is the human-review checklist for waiver-pending items and the orphan subtitle.
- **BBI K8s Migration**: [BBI-K8-MIGRATION.md](migrations/BBI-K8-MIGRATION.md) - Infrastructure migration

### Analytics & Reporting
- **Analytics Overview**: [analytics/README.md](analytics/README.md)
- **Aspects Installation**: [analytics/ASPECTS_INSTALLATION.md](analytics/ASPECTS_INSTALLATION.md)
- **Enrollment Comparison**: [analytics/ENROLLMENT_COMPARISON_QUICKSTART.md](analytics/ENROLLMENT_COMPARISON_QUICKSTART.md)

### Branding & Design
- **Branding Guide**: [BRANDING.md](BRANDING.md)
- **Branding Operating Model**: [branding/BRANDING_OPERATING_MODEL.md](branding/BRANDING_OPERATING_MODEL.md)
- **Branding Guardrails**: [branding/BRANDING_GUARDRAILS.md](branding/BRANDING_GUARDRAILS.md)

### Integrations
- **Google OAuth**: [integrations/GOOGLE_OAUTH_SETUP.md](integrations/GOOGLE_OAUTH_SETUP.md)
- **Stripe Webhooks**: [operations/STRIPE_WEBHOOKS_SETUP.md](operations/STRIPE_WEBHOOKS_SETUP.md)

### Status & Planning
- **Next 10 Tasks**: [status/NEXT10_TASKS.md](status/NEXT10_TASKS.md)
- **Operational Status**: [status/OPERATIONAL_STATUS.md](status/OPERATIONAL_STATUS.md)
- **Implementation Roadmap**: [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md)

### Postmortems
- **Postmortem Directory**: [operations/postmortems/](operations/postmortems/)
- **Incident Templates**: [operations/INCIDENT_TEMPLATES.md](operations/INCIDENT_TEMPLATES.md)

---

## 🔗 Cross-Cutting Guides

### For Everyone
- **[Documentation Index](README.md)** - Chronological documentation index
- **[Style Guide](STYLE_GUIDE.md)** - Documentation standards
- **[Repository Guide](onboarding/REPOSITORY_GUIDE.md)** - Find files quickly

### Infrastructure Teams (Ops + SRE)
- **Observability Stack**: [OBSERVABILITY_GUIDE.md](operations/guides/OBSERVABILITY_GUIDE.md)
- **Backup & DR**: [DISASTER_RECOVERY.md](operations/runbooks/DISASTER_RECOVERY.md)
- **Secrets Pipeline**: [SECRETS_MANAGEMENT_GUIDE.md](operations/guides/SECRETS_MANAGEMENT_GUIDE.md)

### Development Teams
- **Local Parity**: [LOCAL_PRODUCTION_PARITY.md](operations/LOCAL_PRODUCTION_PARITY.md)
- **Multi-Dev Workflow**: [MULTI_DEVELOPER_WORKFLOW.md](MULTI_DEVELOPER_WORKFLOW.md)
- **Repository Navigation**: [REPOSITORY_GUIDE.md](onboarding/REPOSITORY_GUIDE.md)

### Enterprise/Security Teams
- **Auth Hardening**: [AUTH_HARDENING_SPEC.md](operations/AUTH_HARDENING_SPEC.md)
- **Data Privacy**: [data-privacy-compliance-runbook.md](runbooks/data-privacy-compliance-runbook.md)
- **Multi-Tenancy**: [multi-tenancy-overview.md](architecture/multi-tenancy-overview.md)

---

## 📞 Getting Help

### Emergency Contacts
- **Site Down (P0)**: Follow [site-down.md](operations/runbooks/site-down.md) → Escalate to on-call SRE
- **Security Incident**: Contact security team immediately
- **Data Loss**: Contact platform engineering lead + follow [DISASTER_RECOVERY.md](operations/runbooks/DISASTER_RECOVERY.md)

### Regular Support
- **Technical Questions**: Engineering team Slack
- **Access Issues**: [ADMIN_LOGIN_GUIDE.md](operations/guides/ADMIN_LOGIN_GUIDE.md)
- **Documentation Issues**: Submit PR or file issue

### Contributing
- **Documentation Updates**: Follow [STYLE_GUIDE.md](STYLE_GUIDE.md)
- **Code Contributions**: See [DEVELOPER_ONBOARDING.md](onboarding/DEVELOPER_ONBOARDING.md)
- **Architecture Proposals**: Submit ADR (see [adr/README.md](adr/README.md))

---

_**Navigation Tip**: Use Ctrl+F to search for specific topics, or follow the learning paths for your role._
