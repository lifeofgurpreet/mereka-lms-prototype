# Team Scaling Guide
_Onboarding New Team Members • Last updated: 2026-02-12 • Owner: People Operations_

This guide helps new team members ramp up quickly on the Mereka Academy Open edX platform based on their role.

**Quick Navigation**: [Platform Operators](#-platform-operators-onboarding) • [SREs](#-sre-onboarding) • [Developers](#-developer-onboarding) • [Enterprise Admins](#-enterprise-administrator-onboarding) • [Communication](#-communication-channels) • [Common Mistakes](#-common-mistakes-to-avoid)

---

## Overview

### Documentation Navigation

**Start here**: [INDEX_BY_AUDIENCE.md](../INDEX_BY_AUDIENCE.md) - Your role-specific learning path

**Finding information quickly**:
- Use `Ctrl+F` to search the index by topic or document name
- Each role has a learning path: Start Here → Foundational → Advanced
- Quick references provide daily command cheat sheets
- Runbooks provide step-by-step procedures for specific tasks

**Repository navigation**:
- [REPOSITORY_GUIDE.md](REPOSITORY_GUIDE.md) - Find files by purpose
- [QUICK_REFERENCE.md](../../ops/quickref/QUICK_REFERENCE.md) - Bookmark this for daily commands
- [README.md](README.md) - Chronological documentation index

---

## Platform Operators Onboarding

_Role: Deploy, scale, monitor, and maintain the platform day-to-day_

### First Week Checklist

#### Day 1: Access and Orientation
- [ ] **Access**: Gain access to GCP project, Kubernetes clusters, Cloudflare, Infisical
- [ ] **Read**: [Repository Guide](REPOSITORY_GUIDE.md) - Understand file structure
- [ ] **Read**: [K8s Operations Guide](../admin/K8S_OPERATIONS_GUIDE.md) - Core operations
- [ ] **Bookmark**: [Quick Reference](../../ops/quickref/QUICK_REFERENCE.md) - Daily commands
- [ ] **Access**: [All system URLs](../../ops/quickref/access-urls.md) - LMS, Studio, observability
- [ ] **Setup**: Clone repository, configure `kubectl` contexts
- [ ] **Test**: Verify you can read-only query production cluster

#### Day 2-3: Secrets and Configuration
- [ ] **Read**: [Secrets Management Guide](../admin/SECRETS_MANAGEMENT_GUIDE.md)
- [ ] **Understand**: Infisical → GCP Secret Manager → ExternalSecrets → K8s pipeline
- [ ] **Read**: [Multi-Site Guide](../admin/MULTI_SITE_GUIDE.md) - Multi-domain setup
- [ ] **Practice**: Retrieve a secret (read-only) via Infisical CLI
- [ ] **Practice**: View ExternalSecret status in cluster

#### Day 4-5: Databases and Observability
- [ ] **Read**: [MongoDB Atlas Guide](../admin/MONGODB_ATLAS_GUIDE.md)
- [ ] **Read**: [Observability Guide](../admin/OBSERVABILITY_GUIDE.md)
- [ ] **Access**: Grafana dashboards (`https://grafana.mereka.io`)
- [ ] **Access**: MongoDB Atlas console
- [ ] **Practice**: Query metrics in Grafana
- [ ] **Practice**: Check Atlas connection limits and performance

### First Month Plan

#### Week 2: User Management
- [ ] **Read**: [Admin Login Guide](../admin/ADMIN_LOGIN_GUIDE.md)
- [ ] **Practice**: Create test user in dev environment
- [ ] **Practice**: Grant platform admin permissions

#### Week 3: Enterprise Services
- [ ] **Read**: [Enterprise Services Guide](../admin/ENTERPRISE_SERVICES_GUIDE.md)
- [ ] **Understand**: B2B microservices (catalog, subsidy, access)
- [ ] **Practice**: Deploy enterprise service to dev

#### Week 4: Production Operations
- [ ] **Shadow**: Production deployment with senior operator
- [ ] **Shadow**: Incident response (on-call rotation)
- [ ] **Read**: [Deployment Runbook](../../ops/runbooks/DEPLOYMENT_RUNBOOK.md)
- [ ] **Practice**: Execute deployment to dev

### Common Workflows

#### Daily Health Check
```bash
# Check cluster status
kubectl get pods -n mereka-lms

# Check service endpoints (critical)
kubectl get endpoints -n mereka-lms

# Quick health check
./scripts/qa/public-health-check.sh prod
```

#### Deploy New Service
1. Update manifests in `deploy/k8s/overlays/production/`
2. Commit and push to `mereka-lms` repo
3. Update GitOps pinned ref in `BBI-K8` repo
4. Monitor ArgoCD sync
5. Verify endpoints: `kubectl get endpoints -n mereka-lms`
6. Run smoke tests: `./scripts/qa/public-health-check.sh prod`

#### Scale Deployment
```bash
# Scale replicas
kubectl scale deployment lms -n mereka-lms --replicas=3

# Verify rollout
kubectl rollout status deployment/lms -n mereka-lms
```

#### Update Secrets
```bash
# Add/update in Infisical (source of truth)
cd /home/gurpreet/projects/k8s/reka-slackbot
infisical secrets set MEREKA_LMS_NEW_SECRET="value" \
  --domain https://secrets.mereka.io/api --env prod --path /

# Sync to GCP Secret Manager
gcloud secrets create MEREKA_LMS_NEW_SECRET --data-file=- <<< "value"

# Update ExternalSecret mapping
vim deploy/k8s/base/secrets/external-secrets.yaml

# Apply and verify
kubectl apply -f deploy/k8s/base/secrets/external-secrets.yaml
kubectl get externalsecret -n mereka-lms
```

### Tools and Access Requirements

**Required Access**:
- GCP project `mereka-lms` (viewer role minimum)
- GKE cluster `bbi-k8-cluster` (kubectl access)
- Cloudflare account (DNS management)
- Infisical workspace (secrets read access)
- Grafana (viewer role minimum)
- MongoDB Atlas (read-only access minimum)

**CLI Tools** (install locally):
- `kubectl` - Kubernetes CLI
- `gcloud` - Google Cloud CLI
- `infisical` - Secrets management
- `argocd` - GitOps CLI (optional)

### Escalation Paths

| Issue Type | First Contact | Escalation |
|------------|---------------|------------|
| Service down | On-call SRE | Platform Engineering Lead |
| Secret access | Platform Admin | Security Team |
| Deployment blocked | Senior Operator | Platform Engineering Lead |
| Atlas performance | Senior Operator | MongoDB Atlas Support |
| GCP quota/billing | GCP Admin | Finance Team |

---

## SRE Onboarding

_Role: Incident response, performance troubleshooting, disaster recovery_

### On-Call Prep Checklist (Week 1)

#### Day 1: Critical Runbooks
- [ ] **Read**: [Site Down Runbook](../../ops/runbooks/site-down.md) - **CRITICAL**
- [ ] **Read**: [On-Call Observability Playbook](../../ops/runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md)
- [ ] **Read**: [Alert Severity Matrix](../../reference/operations/ALERT_SEVERITY_MATRIX.md)
- [ ] **Bookmark**: [Quick Reference](../../ops/quickref/QUICK_REFERENCE.md)
- [ ] **Access**: All production systems (GCP, GKE, Grafana, Atlas, Infisical)
- [ ] **Test**: Verify you can access production cluster read-only

#### Day 2-3: Performance and Database Issues
- [ ] **Read**: [Performance Degradation Runbook](../../ops/runbooks/performance-degradation.md)
- [ ] **Read**: [Database Issues Runbook](../../ops/runbooks/database-issues.md)
- [ ] **Read**: [K8s Operations Guide](../admin/K8S_OPERATIONS_GUIDE.md)
- [ ] **Practice**: Run diagnostic commands on dev cluster

#### Day 4-5: Observability and Recovery
- [ ] **Read**: [Observability Guide](../admin/OBSERVABILITY_GUIDE.md)
- [ ] **Read**: [Disaster Recovery Runbook](../../ops/runbooks/DISASTER_RECOVERY.md)
- [ ] **Access**: Grafana dashboards - learn all 4 core dashboards
- [ ] **Practice**: Retrieve metrics, query logs, trace requests

### First Month Plan

#### Week 2: Auth and Alerting
- [ ] **Read**: [Auth Alert Runbook](../../ops/runbooks/AUTH_ALERT_RUNBOOK.md)
- [ ] **Read**: [Velero Backup Audit](../../ops/runbooks/VELERO_BACKUP_AUDIT.md)
- [ ] **Read**: [Alert Tuning SOP](../../ops/runbooks/ALERT_TUNING_SOP.md)
- [ ] **Shadow**: Senior SRE during incident
- [ ] **Practice**: Simulate incident response on dev

#### Week 3: Architecture Understanding
- [ ] **Read**: [Database Architecture](../../reference/operations/PRODUCTION_INFRASTRUCTURE_PLAN.md)
- [ ] **Read**: [Multisite Analysis](../../concepts/architecture/multi-tenancy-overview.md)
- [ ] **Read**: [Production Architecture Reality](../../reference/operations/PRODUCTION_INFRASTRUCTURE_PLAN.md)
- [ ] **Understand**: All service interactions and dependencies

#### Week 4: On-Call Readiness
- [ ] **Shadow**: Full on-call shift with senior SRE
- [ ] **Practice**: Execute all common incident responses on dev
- [ ] **Review**: Postmortems from last 3 months (`docs/status/incidents/`)
- [ ] **Ready**: Begin on-call rotation (paired with senior SRE)

### Common Workflows

#### Site Down Incident Response (5-10 min resolution)
```bash
# Step 1: Check pods (10 seconds)
kubectl get pods -n mereka-lms

# Step 2: Check endpoints (10 seconds)
# CRITICAL: Empty endpoints (<none>) = #1 cause
kubectl get endpoints -n mereka-lms

# Step 3: Check service selectors (20 seconds)
kubectl get svc -n mereka-lms -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.selector}{"\n"}{end}'

# Step 4: Fix selector mismatch (2 minutes)
./scripts/infra/fix-service-selectors.sh

# Step 5: Verify resolution
kubectl get endpoints -n mereka-lms
curl -I https://academyv2.mereka.io
```

See [Site Down Runbook](../../ops/runbooks/site-down.md) for full decision tree.

#### Performance Degradation Response
```bash
# Check metrics
kubectl top pods -n mereka-lms
kubectl top nodes

# Check logs for errors
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 | grep -i error

# Check database connections
kubectl exec -n mereka-lms deploy/lms -- python -c "import socket; s = socket.socket(); result = s.connect_ex(('mysql', 3306)); print('MySQL reachable' if result == 0 else 'MySQL NOT reachable'); s.close()"

# Check Redis
kubectl exec -n mereka-lms deploy/redis -- redis-cli ping
```

See [Performance Degradation Runbook](../../ops/runbooks/performance-degradation.md) for full procedures.

#### Backup Verification
```bash
# Run Velero audit
./scripts/qa/audit-velero.sh

# Verify backup freshness
kubectl get backup -n velero

# Check backup pipeline
./scripts/qa/audit-velero-alert-pipeline.sh
```

See [Disaster Recovery Runbook](../../ops/runbooks/DISASTER_RECOVERY.md) for restore procedures.

### Tools and Access Requirements

**Required Access** (emergency credentials):
- GCP project `mereka-lms` (editor role for incident response)
- GKE cluster `bbi-k8-cluster` (admin access)
- Grafana (admin role)
- MongoDB Atlas (admin access)
- Infisical (read access to all production secrets)
- PagerDuty or equivalent (on-call alerts)

**CLI Tools**:
- `kubectl` with production context configured
- `gcloud` with production project configured
- `infisical` CLI
- `jq`, `yq` for JSON/YAML processing
- `curl`, `openssl` for endpoint testing

### Escalation Paths

| Severity | Response Time | First Action | Escalation |
|----------|---------------|--------------|------------|
| P0 (Site down) | 5 min | On-call SRE | Platform Engineering Lead after 15 min |
| P1 (Degraded) | 15 min | On-call SRE | Platform Engineering Lead after 30 min |
| P2 (Minor) | 1 hour | On-call SRE | Ticket for next business day |
| P3 (Cosmetic) | Next business day | Ticket queue | None |

**Emergency Contacts**:
- Platform Engineering Lead: [Contact via PagerDuty]
- Security Team: [Contact via PagerDuty for security incidents]
- MongoDB Atlas Support: [Support ticket + urgency flag]

---

## Developer Onboarding

_Role: Feature development, bug fixes, local setup, testing_

### First Day Checklist

#### Setup (5-60 minutes)
- [ ] **Clone**: `git clone https://github.com/organization/mereka-lms.git`
- [ ] **Read**: [Quick Start Local](QUICK_START_LOCAL.md) - 5-minute overview
- [ ] **Read**: [Agent Setup Checklist](AGENT_SETUP_CHECKLIST.md) - Step-by-step
- [ ] **Setup**: Run `./scripts/shared/setup-local.sh` (automated, ~45-60 min first time)
- [ ] **Verify**: Run `./scripts/qa/verify-setup.sh`
- [ ] **Access**: http://localhost, http://apps.localhost/authn/login
- [ ] **Login**: Username `admin`, password `admin123`

#### Orientation
- [ ] **Read**: [Repository Guide](REPOSITORY_GUIDE.md) - Find your way around
- [ ] **Bookmark**: [Quick Reference](../../ops/quickref/QUICK_REFERENCE.md) - Daily commands
- [ ] **Bookmark**: [Local Development Guide](LOCAL_DEVELOPMENT_GUIDE.md) - Complete reference
- [ ] **Explore**: Browse LMS, Studio, create test course

### First Week Plan

#### Day 2-3: Development Environment
- [ ] **Read**: [Developer Onboarding](DEVELOPER_ONBOARDING.md) - Full guide
- [ ] **Read**: [Workflow Local](WORKFLOW_LOCAL.md) - Daily workflow
- [ ] **Read**: [Branding Guide](../branding/BRANDING.md) - Theme customization
- [ ] **Practice**: Make a small change, rebuild, verify
- [ ] **Practice**: Run tests: `./scripts/qa/comprehensive-test.sh`

#### Day 4-5: Architecture and Testing
- [ ] **Read**: [Database Architecture](../../reference/operations/PRODUCTION_INFRASTRUCTURE_PLAN.md)
- [ ] **Read**: [Production Architecture Reality](../../reference/operations/PRODUCTION_INFRASTRUCTURE_PLAN.md)
- [ ] **Read**: [Local Production Parity](../../ops/quickref/local-production-parity.md)
- [ ] **Practice**: Verify parity: `./scripts/qa/check-parity.sh`

### First Month Plan

#### Week 2: Feature Development
- [ ] **Pick**: Small bug fix or feature from backlog
- [ ] **Read**: Relevant spec in `specs/` directory
- [ ] **Develop**: Implement locally, write tests
- [ ] **Review**: Submit PR, address feedback

#### Week 3: Team Collaboration
- [ ] **Read**: [Multi-Developer Workflow](./MULTI_DEVELOPER_WORKFLOW.md)
- [ ] **Practice**: Resolve merge conflicts, rebase
- [ ] **Shadow**: Code review session with senior developer

#### Week 4: Production Readiness
- [ ] **Read**: [CI/CD Runbook](../../ops/runbooks/CI_CD_RUNBOOK.md)
- [ ] **Read**: [Deployment Runbook](../../ops/runbooks/DEPLOYMENT_RUNBOOK.md)
- [ ] **Shadow**: Production deployment
- [ ] **Ready**: Ship your first feature to production

### Common Workflows

#### Daily Development
```bash
# Start services
cd /path/to/mereka.academy
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor local start -d

# After config changes
tutor config save --set KEY=value
./infrastructure/tutor/apply-patches.sh  # CRITICAL!
tutor local restart

# Run tests before committing
./scripts/qa/comprehensive-test.sh

# Stop services
tutor local stop
```

#### Build Custom Image
```bash
# Ensure TUTOR_ROOT is set
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"

# Build Open edX (LMS/CMS) - takes 30-45 min
tutor images build openedx

# Build MFEs - takes 15-20 min
tutor images build mfe

# Rebuild after theme changes
./scripts/branding/setup-mfe-branding.sh
tutor images build mfe
```

#### Troubleshoot Local Issues
```bash
# Check logs
tutor local logs --tail=50 lms

# Fix admin login issues
./scripts/qa/fix-admin-login.sh

# Fix config with cloud IPs
./scripts/qa/fix-parity.sh

# Full diagnostic
./scripts/qa/comprehensive-test.sh
```

### Tools and Access Requirements

**Required Tools** (local machine):
- Docker Desktop (12 GB+ RAM, 2-4 GB swap)
- Python 3.12+
- Git
- Code editor (VS Code recommended)

**Optional Access** (for integration testing):
- Dev Kubernetes cluster (kind or GKE dev)
- Infisical (read access to dev secrets)

### Escalation Paths

| Issue Type | First Contact | Escalation |
|------------|---------------|------------|
| Local setup fails | Check [TROUBLESHOOTING.md](../../ops/runbooks/site-down.md) | Engineering team Slack |
| Build issues | Check [CI/CD Runbook](../../ops/runbooks/CI_CD_RUNBOOK.md) | Senior Developer |
| Architecture questions | Propose ADR (see [adr/README.md](../../adr/README.md)) | Architecture Review Board |
| Merge conflicts | Senior Developer | Team Lead |

---

## Enterprise Administrator Onboarding

_Role: Tenant management, SSO configuration, user provisioning, domain management_

### First Day Checklist

#### Access and Orientation
- [ ] **Access**: LMS admin panel, Studio, Authentik (SSO)
- [ ] **Read**: [Admin Login Guide](../admin/ADMIN_LOGIN_GUIDE.md)
- [ ] **Access**: All admin URLs from [Access URLs](../../ops/quickref/access-urls.md)
- [ ] **Login**: Test login to LMS and Studio
- [ ] **Explore**: Admin panel, user management

#### Configuration Basics
- [ ] **Read**: [Multi-Site Guide](../admin/MULTI_SITE_GUIDE.md)
- [ ] **Read**: [Auth and Permissions](../../reference/operations/AUTH_AND_PERMISSIONS.md)
- [ ] **Understand**: Multi-domain setup (academyv2.mereka.io, academy.biji-biji.com, etc.)

### First Week Plan

#### Day 2-3: User and Domain Management
- [ ] **Practice**: Create test user in dev
- [ ] **Practice**: Grant staff permissions
- [ ] **Practice**: Create test organization
- [ ] **Read**: [Domain Change Runbook](../../ops/runbooks/DOMAIN_CHANGE_RUNBOOK.md)

#### Day 4-5: Enterprise Services
- [ ] **Read**: [Enterprise Services Guide](../admin/ENTERPRISE_SERVICES_GUIDE.md)
- [ ] **Understand**: B2B services (catalog, subsidy, access)
- [ ] **Practice**: Query catalog API

### First Month Plan

#### Week 2: Tenant Provisioning
- [ ] **Read**: [Tenant Provisioning Runbook](../../archive/superseded/runbooks/tenant-provisioning-runbook.md)
- [ ] **Shadow**: Senior admin provisioning new tenant
- [ ] **Practice**: Provision test tenant in dev

#### Week 3: SSO and Authentication
- [ ] **Read**: [Auth SSO Runbook](../../ops/runbooks/AUTH_SSO_RUNBOOK.md)
- [ ] **Read**: [Auth SSO Enterprise Runbook](../../archive/superseded/runbooks/auth-sso-enterprise-runbook.md)
- [ ] **Understand**: Authentik OIDC integration
- [ ] **Practice**: Configure SSO for test tenant

#### Week 4: Payment and Integrations
- [ ] **Read**: [Purchase Gateway Runbook](../../archive/superseded/runbooks/purchase-gateway-runbook.md)
- [ ] **Read**: [External Registration Runbook](../../archive/superseded/runbooks/external-registration-runbook.md)
- [ ] **Understand**: Stripe webhooks, HubSpot integration
- [ ] **Ready**: Manage production tenants

### Common Workflows

#### Provision New Tenant
```bash
# Create tenant configuration
./scripts/tenants/provision-tenant.sh \
  --name "Acme Corp" \
  --domain "acme.academy.mereka.io" \
  --admin-email "admin@acme.com"

# Verify tenant setup
kubectl get tenantconfig -n mereka-lms
curl -I https://acme.academy.mereka.io
```

See [Tenant Provisioning Runbook](../../archive/superseded/runbooks/tenant-provisioning-runbook.md) for full procedure.

#### Configure SSO for Tenant
1. Create OIDC provider in Authentik
2. Generate SAML keypair: `./scripts/tenants/generate-saml-keypair.sh`
3. Add SAML cert/key to Infisical
4. Update ExternalSecret mapping
5. Configure provider in Django admin
6. Test SSO flow

See [Auth SSO Runbook](../../ops/runbooks/AUTH_SSO_RUNBOOK.md) for full procedure.

#### Import Courses
1. Export course from old LMS
2. Upload to Studio
3. Import course
4. Verify course structure
5. Test enrollment

See [Course Import Guide](./COURSE_IMPORT_GUIDE.md) for full procedure.

#### Manage User Permissions
```bash
# Grant platform admin (script approach)
./scripts/infra/ensure-platform-admins.sh

# Or via Django shell
kubectl exec -n mereka-lms deploy/lms -- /bin/bash -c \
  "cd /openedx/edx-platform && ./manage.py lms shell -c \
  \"from django.contrib.auth import get_user_model; \
  u = get_user_model().objects.get(email='user@example.com'); \
  u.is_staff = True; u.is_superuser = True; u.save(); \
  print('User is now admin')\""
```

### Tools and Access Requirements

**Required Access**:
- LMS Django admin panel (superuser account)
- Studio (staff account)
- Authentik admin panel (SSO configuration)
- Cloudflare DNS (domain management, via Platform Ops)
- Stripe dashboard (payment verification, via Finance)

**Optional Access**:
- MongoDB Atlas (read-only, for debugging)
- Grafana (viewer role, for monitoring)

### Escalation Paths

| Issue Type | First Contact | Escalation |
|------------|---------------|------------|
| Tenant provisioning | Platform Operations | Platform Engineering Lead |
| SSO not working | Check [Auth SSO Runbook](../../ops/runbooks/AUTH_SSO_RUNBOOK.md) | Platform Team |
| Payment issues | Check [Purchase Gateway Runbook](../../archive/superseded/runbooks/purchase-gateway-runbook.md) | Finance Team + Platform |
| User access issues | Follow [Admin Login Guide](../admin/ADMIN_LOGIN_GUIDE.md) | Platform Operations |

---

## Communication Channels

### Daily Operations

**Slack Channels** (adjust to your team's setup):
- `#mereka-lms-ops` - Daily operations, deployments, incidents
- `#mereka-lms-dev` - Development discussions, code reviews
- `#mereka-lms-alerts` - Automated alerts (Grafana, PagerDuty)
- `#mereka-lms-incidents` - Active incident coordination

### Incident Coordination

**During P0/P1 Incidents**:
1. **Incident Lead**: On-call SRE declares incident in `#mereka-lms-incidents`
2. **War Room**: Create dedicated Slack huddle or Zoom call
3. **Updates**: Post status updates every 15 minutes
4. **Resolution**: Post postmortem action items
5. **Follow-up**: Complete postmortem within 48 hours

**Postmortem Template**: See [Incident Templates](../../ops/runbooks/INCIDENT_TEMPLATES.md)

### Code Review

**Pull Request Flow**:
1. Open PR with descriptive title (conventional commits)
2. Tag relevant reviewers
3. Address feedback promptly
4. Request re-review after changes
5. Merge after approval + CI passes

**Review SLAs**:
- Small PRs (<100 lines): 24 hours
- Medium PRs (<500 lines): 48 hours
- Large PRs (500+ lines): 3-5 days (consider splitting)

### Architecture Decisions

**Proposing ADR**:
1. Copy template from `specs/templates/spec-template.md`
2. Fill in context, decision, consequences
3. Submit PR with ADR
4. Tag architecture reviewers
5. Iterate based on feedback
6. Merge after consensus

See [adr/README.md](../../adr/README.md) for full process.

---

## Common Mistakes to Avoid

### All Roles

1. **Never commit secrets** to Git
   - Use Infisical for all secrets
   - Pre-commit hook will catch most, but be vigilant
   - `tutor_env/config.yml` is gitignored for a reason

2. **Never run Tutor commands without `TUTOR_ROOT`**
   - Always: `export TUTOR_ROOT="$(pwd)/tutor_env"`
   - Forgetting this creates configs in wrong directory

3. **Never skip `apply-patches.sh` after `tutor config save`**
   - Patches fix MySQL auth, MFE Node version, domains
   - Use wrapper: `./scripts/infra/tutor-config-save.sh`
   - Verify: `./scripts/infra/verify-tutor-config.sh`

4. **Never work in production without testing locally first**
   - Always develop locally
   - Test in dev cluster
   - Deploy to staging
   - Only then deploy to production

5. **Never assume empty endpoints are normal**
   - Empty endpoints = site will be down
   - Always check: `kubectl get endpoints -n mereka-lms`
   - Fix immediately: `./scripts/infra/fix-service-selectors.sh`

### Platform Operators

1. **Never update secrets without syncing to GCP Secret Manager**
   - Source of truth: Infisical
   - Must sync to GCP SM for ExternalSecrets to work

2. **Never deploy without verifying endpoints after restart**
   - Pod restarts can cause selector mismatches
   - Check endpoints before declaring success

3. **Never modify production manifests directly**
   - All changes via Git (GitOps)
   - Emergency hotfixes must be committed after

### SREs

1. **Never restart Caddy before backend services**
   - Safe order: LMS/CMS → Nginx → Caddy
   - Restarting Caddy first causes outage

2. **Never skip the 5-command diagnostic**
   - See [Site Down Runbook](../../ops/runbooks/site-down.md)
   - 70% of incidents are selector mismatches
   - 5 commands, 2 minutes to isolate

3. **Never declare incident resolved without smoke tests**
   - Run: `./scripts/qa/public-health-check.sh prod`
   - Verify all endpoints accessible

### Developers

1. **Never downgrade package versions to fix issues**
   - Research compatibility solutions instead
   - Document why newer versions are needed (ADR)
   - See `~/.claude/rules/version-safety.md`

2. **Never edit generated files in `tutor_env/`**
   - Changes lost on next `tutor config save`
   - Use patches in `infrastructure/tutor/apply-patches.sh`

3. **Never assume local matches production**
   - Verify parity: `./scripts/qa/check-parity.sh`
   - Common issue: Cloud IPs in local config

### Enterprise Admins

1. **Never create users without profiles**
   - Use LMS registration flow or `createsuperuser`
   - Manual user creation can skip profile creation

2. **Never assume SSO works without testing**
   - Test full login flow after configuration
   - Verify redirect URIs are correct
   - Check Authentik logs for errors

3. **Never change domain without following runbook**
   - DNS changes require cert updates
   - Follow [Domain Change Runbook](../../ops/runbooks/DOMAIN_CHANGE_RUNBOOK.md)

---

## 30-Day Ramp-Up Plan

### Week 1: Access and Orientation

**All Roles**:
- Complete access setup (GCP, GKE, Grafana, etc.)
- Read role-specific "Start Here" docs from [INDEX_BY_AUDIENCE.md](../INDEX_BY_AUDIENCE.md)
- Set up local environment (if applicable)
- Shadow senior team member

**Goals**:
- [ ] All access working
- [ ] Read all "Start Here" documentation
- [ ] Understand system topology
- [ ] Meet team members

### Week 2: Foundational Knowledge

**All Roles**:
- Complete "Foundational" docs from [INDEX_BY_AUDIENCE.md](../INDEX_BY_AUDIENCE.md)
- Practice common workflows in dev environment
- Shadow incident response (SREs) or deployment (Ops/Dev)

**Goals**:
- [ ] Understand architecture
- [ ] Execute read-only operations
- [ ] Explain system to someone else

### Week 3: Hands-On Practice

**Platform Operators**:
- Deploy service to dev cluster
- Update secret in dev
- Scale deployment

**SREs**:
- Simulate incident response on dev
- Run backup verification
- Review recent postmortems

**Developers**:
- Fix small bug or implement small feature
- Submit first PR
- Pass code review

**Enterprise Admins**:
- Provision test tenant
- Configure SSO for test org
- Import test course

**Goals**:
- [ ] Execute write operations in dev
- [ ] Understand failure modes
- [ ] Receive feedback on work

### Week 4: Production Readiness

**Platform Operators**:
- Shadow production deployment
- Execute deployment to production (with supervision)

**SREs**:
- Shadow on-call shift
- Begin on-call rotation (paired with senior SRE)

**Developers**:
- Ship first feature to production
- Participate in deployment

**Enterprise Admins**:
- Manage production tenant (supervised)
- Configure production SSO

**Goals**:
- [ ] Operate in production (supervised)
- [ ] Understand rollback procedures
- [ ] Know escalation paths

---

## Resources

### Essential Documentation

**Everyone**:
- [INDEX_BY_AUDIENCE.md](../INDEX_BY_AUDIENCE.md) - Start here for your role
- [QUICK_REFERENCE.md](../../ops/quickref/QUICK_REFERENCE.md) - Daily commands
- [REPOSITORY_GUIDE.md](REPOSITORY_GUIDE.md) - Find files

**SREs**:
- [Site Down Runbook](../../ops/runbooks/site-down.md) - CRITICAL
- [On-Call Observability Playbook](../../ops/runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md)
- [Incident Templates](../../ops/runbooks/INCIDENT_TEMPLATES.md)

**Developers**:
- [Developer Onboarding](DEVELOPER_ONBOARDING.md)
- [Local Development Guide](LOCAL_DEVELOPMENT_GUIDE.md)
- [Multi-Developer Workflow](./MULTI_DEVELOPER_WORKFLOW.md)

**Operators/Admins**:
- [K8s Operations Guide](../admin/K8S_OPERATIONS_GUIDE.md)
- [Secrets Management Guide](../admin/SECRETS_MANAGEMENT_GUIDE.md)
- [Admin Login Guide](../admin/ADMIN_LOGIN_GUIDE.md)

### Training Sessions

**Recommended Schedule**:
- **Week 1**: System architecture overview (2 hours)
- **Week 2**: Role-specific deep dive (2 hours)
- **Week 3**: Incident response simulation (1 hour)
- **Week 4**: Production shadowing (ongoing)

### Office Hours

**Weekly Sessions**:
- **Platform Operations**: Tuesdays 10:00 AM - Questions about deployments, configs
- **Development**: Wednesdays 2:00 PM - Code reviews, architecture discussions
- **SRE**: Thursdays 3:00 PM - Incident review, postmortem discussions

---

## Getting Help

### Quick Questions

1. **Check documentation first**: [INDEX_BY_AUDIENCE.md](../INDEX_BY_AUDIENCE.md)
2. **Search Slack**: Often someone has asked before
3. **Ask in team channel**: `#mereka-lms-ops` or `#mereka-lms-dev`

### Stuck on Setup

1. **Re-run setup script**: `./scripts/shared/setup-local.sh`
2. **Check logs**: `tutor local logs --tail=50 <service>`
3. **Run diagnostics**: `./scripts/qa/verify-setup.sh`
4. **Check**: [Troubleshooting](../../ops/runbooks/site-down.md)
5. **Ask**: Engineering team Slack with error output

### Stuck on Incident

1. **Follow runbook**: [Site Down](../../ops/runbooks/site-down.md) or [Performance Degradation](../../ops/runbooks/performance-degradation.md)
2. **Run diagnostics**: 5-command diagnostic from Site Down runbook
3. **Escalate**: If >15 minutes for P0, escalate to Platform Lead

### Need Architectural Guidance

1. **Check ADRs**: [adr/](../../adr/) directory
2. **Check specs**: `specs/` directory
3. **Propose ADR**: If new decision needed
4. **Ask**: Architecture review board

---

## Success Criteria

By the end of 30 days, you should be able to:

**All Roles**:
- [ ] Navigate documentation to find answers independently
- [ ] Explain system architecture to a new hire
- [ ] Identify when to escalate vs. resolve independently

**Platform Operators**:
- [ ] Deploy service to production (supervised initially)
- [ ] Update secrets safely
- [ ] Diagnose common infrastructure issues

**SREs**:
- [ ] Respond to P0/P1 incidents independently
- [ ] Use all 4 core Grafana dashboards
- [ ] Execute disaster recovery procedures

**Developers**:
- [ ] Ship features to production
- [ ] Debug local environment issues
- [ ] Write tests and pass code review

**Enterprise Admins**:
- [ ] Provision new tenants
- [ ] Configure SSO independently
- [ ] Manage user permissions

---

## Feedback and Continuous Improvement

This guide is a living document. Please provide feedback:

- **What was unclear?** Submit PR to improve
- **What was missing?** Add sections
- **What worked well?** Share in team retrospective

**Review Schedule**: Quarterly review by People Operations + Platform Team

---

_Welcome to the team!_ 🎉
_Questions? Ask in Slack or during office hours._
