# Mereka LMS Observability Enhancement Plan

**Project**: mereka-lms (SLO & Monitoring Improvements)
**Version**: 1.0 (Focus: Centralized Grafana Integration)
**Date**: 2026-02-04
**Status**: Proposal - Awaiting Independent Review
**Author**: Claude Sonnet 4
**Reviewers**: TBD

---

## Executive Summary

**Objective**: Enhance the existing solid observability foundation with strategic SLO integration, MFE synthetic monitoring, and optimized dual-layer architecture.

**Context**: Initiated during "bead 2d9" (task mereka-lms-2d9: OAuth2 client verification) discussions, this comprehensive observability improvement plan focuses on integrating with the centralized monitoring system at https://grafana.mereka.dev.

## Current Architecture Assessment

**Strengths (Excellent Foundation)**:
- ✅ **Dual-layer monitoring**: GCP Cloud Monitoring + VPS Grafana stack
- ✅ **Comprehensive coverage**: 10 uptime checks, 6 alert policies, 4 dashboards
- ✅ **BBI standards compliance**: Dashboard UID `bbi-app-mereka-lms`, proper folder structure
- ✅ **SLO framework**: 99.5% availability target (Tier 2), error budget tracking
- ✅ **Cross-platform integration**: Centralized Grafana at https://grafana.mereka.dev
- ✅ **Automation ready**: `scripts/infra/apply-monitoring-configs.sh` deployment

**Identified Enhancement Opportunities**:
- 🔶 **MFE synthetic monitoring**: Missing user journey checks (`/authn/login`, `/account/*`)
- 🔶 **Cross-env connectivity**: VPS → GKE datasource needs verification
- 🔶 **SLO burn rate alerting**: Not implemented in centralized system
- 🔶 **Alert coordination**: Potential overlap between GCP and VPS alerts
- 🔶 **Advanced error budget**: Missing burn rate tracking and predictive alerts

### Current State Score: B+ (8.5/10)
**Excellent foundation with strategic enhancement opportunities**

## Implementation Strategy: PHASED ENHANCEMENT

| Phase | Focus | Duration | Priority | Impact |
|-------|-------|----------|----------|---------|
| **Phase 1** | MFE Synthetic + Service Fixes | Week 1 | HIGH | User experience monitoring |
| **Phase 2** | Cross-Environment Integration | Week 2 | HIGH | Unified monitoring view |
| **Phase 3** | SLO Enhancement | Week 3 | MEDIUM | Proactive error budget management |
| **Phase 4** | Advanced Features | Week 4-5 | MEDIUM | Strategic capabilities |

**Execution Approach**: Build incrementally on solid foundation, maintain existing monitoring during enhancement

---

## Phase 1: MFE Synthetic Monitoring & Infrastructure Fixes (Week 1)

**Objective**: Implement comprehensive MFE user journey monitoring and fix existing service issues

### Priority 1.1: Fix K8s Service Selector Issues
**Duration**: 1 hour | **Risk**: Low | **Impact**: Critical

**Problem**: Service selector mismatches causing empty endpoints (site down)

**Implementation**:
```bash
# 1. Run diagnostic and fix
./scripts/infra/fix-service-selectors.sh

# 2. Verify all endpoints have targets
kubectl get endpoints -n mereka-lms
# Should show targets, not <none>

# 3. Test connectivity
curl -I https://academyv2.mereka.io
```

### Priority 1.2: MFE User Journey Synthetic Monitoring
**Duration**: 3-4 hours | **Risk**: Low | **Impact**: High

**Implementation**:
```bash
# 1. Create new uptime configs for MFE user journeys
infrastructure/monitoring/uptime/prod-mfe-login.json
infrastructure/monitoring/uptime/prod-mfe-account.json
infrastructure/monitoring/uptime/prod-mfe-course-catalog.json
```

**MFE Endpoints to Monitor**:
- `apps.academyv2.mereka.io/authn/login` - Authentication flow
- `apps.academyv2.mereka.io/account/` - User account dashboard
- `apps.academyv2.mereka.io/learner-dashboard` - Course dashboard
- `apps.academyv2.mereka.io/search` - Course catalog

**Deployment**:
```bash
# Apply new synthetic checks
./scripts/infra/apply-monitoring-configs.sh plan
./scripts/infra/apply-monitoring-configs.sh apply

# Verify in GCP Console
gcloud monitoring uptime list-configs --filter="displayName:mfe"
```

### Priority 1.3: Enhanced MFE Alerting
**Duration**: 1 hour | **Risk**: Low | **Impact**: Medium

**Implementation**:
```yaml
# Add to infrastructure/monitoring/alerts/mfe-user-journey.json
{
  "displayName": "MFE Login Flow Failure",
  "conditions": [{
    "displayName": "Login endpoint failing",
    "conditionThreshold": {
      "filter": "resource.type=\"uptime_url\" resource.label.\"check_id\"=\"mfe-login-check\"",
      "comparison": "COMPARISON_LESS_THAN",
      "thresholdValue": 0.9
    }
  }]
}
```

### Verification Phase 1
```bash
# 1. Check all endpoints healthy
kubectl get endpoints -n mereka-lms | grep -v '<none>'

# 2. Verify MFE synthetic checks
gcloud monitoring uptime list-configs | grep mfe

# 3. Test MFE user journeys
curl -I https://apps.academyv2.mereka.io/authn/login
curl -I https://apps.academyv2.mereka.io/account/

# 4. Check alerting
gcloud monitoring policies list --filter="displayName:MFE"
```

---

## Phase 2: Cross-Environment Integration (Week 2)

**Objective**: Verify and optimize connectivity between VPS Grafana and GKE monitoring infrastructure

### Priority 2.1: Verify GKE → VPS Grafana Connectivity
**Duration**: 3-4 hours | **Risk**: Medium | **Impact**: High

**Implementation**:
```bash
# 1. Test Prometheus connectivity from VPS to GKE
# From /home/gurpreet/projects/observability/
curl -s "http://prometheus.mereka.io:9090/api/v1/query?query=up"

# 2. Add GKE Prometheus as datasource in VPS Grafana
# Alternative: Federation approach
```

**Grafana Datasource Config**:
```yaml
# Add to observability/datasources/gke-prometheus.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gke-prometheus-datasource
  labels:
    grafana_datasource: "1"
data:
  gke-prometheus.yaml: |
    apiVersion: 1
    datasources:
    - name: GKE Prometheus
      type: prometheus
      url: http://prometheus-server.monitoring.svc.cluster.local:9090
      isDefault: false
```

### Priority 2.2: Enhanced LMS Dashboard Integration
**Duration**: 2-3 hours | **Risk**: Low | **Impact**: Medium

**Current Dashboard**: `bbi-app-mereka-lms` (28.8KB, 10+ panels, BBI standards compliant)

**Enhancement Plan**:
```json
// Add to /home/gurpreet/projects/observability/dashboards/03-applications/bbi-mereka-lms.json
{
  "panels": [
    {
      "title": "MFE User Journeys",
      "datasource": "GKE Prometheus",
      "targets": [
        {"expr": "probe_success{job=\"mfe-synthetic\"}"}
      ]
    },
    {
      "title": "Cross-Environment SLO",
      "datasource": "GKE Prometheus",
      "targets": [
        {"expr": "avg_over_time(probe_success{instance=~\".*mereka.io.*\"}[5m])"}
      ]
    }
  ]
}
```

### Priority 2.3: Alert Deduplication Strategy
**Duration**: 2 hours | **Risk**: Low | **Impact**: Medium

**Current Alert Sources**:
- **GCP**: 6 alert policies (pod restarts, 5xx rates, cert expiry)
- **VPS**: `applications.yaml` (MerekaLMS*, MerekaCMS*, MerekaCaddy*)

**Deduplication Matrix**:
| Alert Type | Primary (Keep) | Secondary (Modify) | Action |
|------------|----------------|-------------------|---------|
| Service Down | VPS | GCP → Disable | VPS has better context |
| High Latency | GCP | VPS → Route to dev team | GCP has load balancer metrics |
| Cert Expiry | GCP | VPS → Info only | GCP manages certs |
| Error Spikes | VPS | GCP → Correlate | VPS has better PromQL |

**Implementation**:
```bash
# Disable redundant GCP alerts
gcloud monitoring policies list --filter="displayName:LMS" --format="value(name)" | \
  xargs -I {} gcloud monitoring policies update {} --no-enabled

# Update VPS alert routing
kubectl apply -f observability/alerts/applications.yaml
```

---

## Phase 3: SLO Enhancement & Error Budget Management (Week 3)

**Objective**: Implement advanced SLO tracking and proactive error budget management

### Priority 3.1: SLO Burn Rate Alerting
**Duration**: 4-5 hours | **Risk**: Medium | **Impact**: High

**Current SLO**: 99.5% availability (Tier 2) with 3.6 hours monthly error budget

**Implementation**:
```yaml
# Add to /home/gurpreet/projects/observability/alerts/applications.yaml
- alert: MerekaLMSErrorBudgetFastBurn
  expr: |
    (
      1 - avg_over_time(probe_success{instance=~".*academyv2.mereka.io.*"}[1h])
    ) > (14.4 * (1 - 0.995))  # 14.4x burn rate
  for: 2m
  labels:
    severity: critical
    service: mereka-lms
    team: platform
    burn_rate: fast
  annotations:
    summary: "Mereka LMS error budget burning too fast"
    description: "Error budget will be exhausted in < 6 hours at current rate"
    runbook_url: "https://github.com/gurpreet/mereka-lms/blob/main/docs/runbooks/slo-burn-rate.md"

- alert: MerekaLMSErrorBudgetSlowBurn
  expr: |
    (
      1 - avg_over_time(probe_success{instance=~".*academyv2.mereka.io.*"}[6h])
    ) > (3 * (1 - 0.995))  # 3x burn rate
  for: 15m
  labels:
    severity: warning
    service: mereka-lms
    team: platform
    burn_rate: slow
```

### Priority 3.2: Error Budget Dashboard Enhancement
**Duration**: 2-3 hours | **Risk**: Low | **Impact**: Medium

**Enhanced SLO Panels**:
```json
// Add to bbi-mereka-lms.json
{
  "panels": [
    {
      "title": "Error Budget Remaining (30d)",
      "type": "stat",
      "targets": [{
        "expr": "100 - (100 * (1 - avg_over_time(probe_success{instance=~\".*academyv2.mereka.io.*\"}[30d])) / (1 - 0.995))",
        "legendFormat": "Budget %"
      }],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "thresholds": {
            "steps": [
              {"color": "red", "value": 0},
              {"color": "yellow", "value": 25},
              {"color": "green", "value": 50}
            ]
          }
        }
      }
    },
    {
      "title": "SLO Burn Rate Trends",
      "type": "timeseries",
      "targets": [
        {
          "expr": "(1 - rate(probe_success{instance=~\".*academyv2.mereka.io.*\"}[1h])) / (1 - 0.995)",
          "legendFormat": "1h Burn Rate"
        },
        {
          "expr": "(1 - rate(probe_success{instance=~\".*academyv2.mereka.io.*\"}[6h])) / (1 - 0.995)",
          "legendFormat": "6h Burn Rate"
        }
      ]
    }
  ]
}
```

### Priority 3.3: Automated Error Budget Enforcement
**Duration**: 1-2 hours | **Risk**: Low | **Impact**: High

**Integration with deployment pipeline**:
```bash
# Add to CI/CD pipeline (GitHub Actions or similar)
#!/bin/bash
# check-error-budget.sh

ERROR_BUDGET=$(curl -s "http://prometheus.mereka.dev/api/v1/query?query=mereka_lms:error_budget_remaining" | jq -r '.data.result[0].value[1]')

if (( $(echo "$ERROR_BUDGET < 0.1" | bc -l) )); then
    echo "❌ Error budget critical ($ERROR_BUDGET%) - blocking risky deployments"
    echo "Visit: https://grafana.mereka.dev/d/bbi-app-mereka-lms"
    exit 1
fi

echo "✅ Error budget healthy ($ERROR_BUDGET%) - deployment allowed"
```

---

## Phase 4: Advanced Observability Features (Week 4-5)

**Objective**: Implement advanced synthetic monitoring and distributed tracing capabilities

### Priority 4.1: Playwright-Based User Journey Testing
**Duration**: 6-8 hours | **Risk**: Medium | **Impact**: High

**Advanced Synthetic Tests**:
```yaml
# Add to observability/synthetic/lms-user-journey.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: lms-synthetic-tests
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: playwright
            image: mcr.microsoft.com/playwright:latest
            command: ["node", "/scripts/lms-comprehensive-test.js"]
            env:
            - name: LMS_BASE_URL
              value: "https://academyv2.mereka.io"
            - name: MFE_BASE_URL
              value: "https://apps.academyv2.mereka.io"
```

**Test Scenarios**:
```javascript
// lms-comprehensive-test.js
const scenarios = [
  {
    name: "student_enrollment_flow",
    steps: [
      "Navigate to MFE login",
      "Complete authentication",
      "Browse course catalog",
      "Enroll in course",
      "Access first lesson"
    ]
  },
  {
    name: "instructor_workflow",
    steps: [
      "Login to Studio",
      "Create course outline",
      "Add content via MFE",
      "Publish course"
    ]
  }
];
```

### Priority 4.2: Distributed Tracing Integration
**Duration**: 8-10 hours | **Risk**: High | **Impact**: Medium

**OpenTelemetry Configuration**:
```python
# Add to LMS/CMS Django settings
INSTALLED_APPS += [
    'opentelemetry.instrumentation.django',
    'opentelemetry.instrumentation.requests',
    'opentelemetry.instrumentation.mysql',
]

# Export to VPS Tempo instance
OPENTELEMETRY_ENDPOINT = "https://tempo.mereka.dev:4318"
OPENTELEMETRY_SAMPLING_RATIO = 0.01  # Start conservative
```

**Trace-to-Metrics Recording Rules**:
```yaml
# Add to observability/recording-rules/trace-metrics.yaml
groups:
- name: trace_sli
  interval: 30s
  rules:
  - record: lms:request_duration:p99
    expr: histogram_quantile(0.99, sum(rate(traces_duration_seconds_bucket{service="lms"}[5m])) by (le))
  - record: lms:error_rate_from_traces
    expr: sum(rate(traces_total{service="lms", status="error"}[5m])) / sum(rate(traces_total{service="lms"}[5m]))
```

### Priority 4.3: Business Metrics Integration
**Duration**: 3-4 hours | **Risk**: Low | **Impact**: Medium

**Course Enrollment Metrics**:
```python
# Add to LMS Django views
from prometheus_client import Counter, Histogram

ENROLLMENT_COUNTER = Counter('lms_course_enrollments_total', 'Course enrollments', ['course_id'])
LOGIN_DURATION = Histogram('lms_login_duration_seconds', 'Login flow duration')

def enroll_student(request, course_id):
    ENROLLMENT_COUNTER.labels(course_id=course_id).inc()
    # ... existing logic
```

**Business Dashboard Panels**:
```json
{
  "title": "Business Impact",
  "panels": [
    {
      "title": "Student Enrollment Rate",
      "targets": [{"expr": "rate(lms_course_enrollments_total[5m])"}]
    },
    {
      "title": "Revenue Impact (Est.)",
      "targets": [{"expr": "rate(lms_course_enrollments_total[5m]) * 150"}]
    }
  ]
}
```

---

## Critical Files for Implementation

### Essential Files for Observability Enhancement

**Primary Implementation Files**:
1. `/home/gurpreet/projects/k8s/mereka-lms/scripts/infra/apply-monitoring-configs.sh`
   - Core automation for deploying monitoring configurations
   - Required for all new uptime checks and alert policies

2. `/home/gurpreet/projects/observability/dashboards/03-applications/bbi-mereka-lms.json`
   - Main LMS dashboard (28.8KB, 10+ panels)
   - Needs SLO burn rate panels and error budget tracking

3. `/home/gurpreet/projects/observability/alerts/applications.yaml`
   - Central alerting rules for cross-platform coordination
   - Critical for SLO burn rate detection and alert deduplication

4. `/home/gurpreet/projects/k8s/mereka-lms/infrastructure/monitoring/uptime/prod-apps-https.json`
   - Pattern template for new MFE synthetic checks
   - Base configuration for user journey monitoring

5. `/home/gurpreet/projects/observability/STANDARDS.md`
   - BBI observability standards (authoritative v1.0)
   - Essential for compliance with UID naming, folder structure

**Supporting Configuration Files**:
- `/home/gurpreet/projects/observability/datasources/` - GKE Prometheus connectivity
- `/home/gurpreet/projects/k8s/mereka-lms/infrastructure/monitoring/alerts/mfe-user-journey.json` - New MFE alerting
- `/home/gurpreet/projects/observability/recording-rules/slo-rules.yaml` - SLO calculations

---

## Success Criteria & Verification

### Phase 1 Complete When:
- [ ] All K8s service endpoints show targets (no `<none>`)
- [ ] MFE user journey synthetic checks operational
- [ ] 100% uptime check coverage for critical MFE endpoints
- [ ] Sub-5-minute detection of MFE failures
- [ ] GCP Console shows all new uptime configs

### Phase 2 Complete When:
- [ ] VPS Grafana successfully queries GKE Prometheus metrics
- [ ] Enhanced `bbi-app-mereka-lms` dashboard displays cross-environment data
- [ ] Alert deduplication reduces noise by >50%
- [ ] Cross-environment queries respond in <5 seconds
- [ ] All VPS alerts properly routed to correct teams

### Phase 3 Complete When:
- [ ] SLO burn rate alerts functional for fast (1h) and slow (6h) burn
- [ ] Error budget dashboard shows real-time budget consumption
- [ ] Automated error budget enforcement blocks risky deployments
- [ ] Error budget tracking prevents SLO violations proactively
- [ ] Business stakeholders have SLO visibility

### Phase 4 Complete When:
- [ ] Playwright user journey tests run every 5 minutes
- [ ] Distributed tracing captures end-to-end requests
- [ ] Business metrics correlate technical health with enrollment impact
- [ ] Advanced synthetics catch regressions before users report them
- [ ] Zero manual investigation for common failure patterns

---

## Comprehensive Verification Checklist

**After Phase 1**:
```bash
# Infrastructure health
kubectl get endpoints -n mereka-lms | grep -c '<none>'  # Should be 0
curl -I https://apps.academyv2.mereka.io/authn/login    # Should be 200

# Synthetic monitoring
gcloud monitoring uptime list-configs --filter="displayName:mfe" | wc -l  # Should be 3+
```

**After Phase 2**:
```bash
# Cross-environment connectivity
curl -s "http://prometheus.mereka.dev/api/v1/query?query=up{job=\"lms\"}"  # Should return data

# Dashboard integration
# Visit: https://grafana.mereka.dev/d/bbi-app-mereka-lms
# Verify: New panels show GKE metrics
```

**After Phase 3**:
```bash
# SLO tracking
curl -s "http://prometheus.mereka.dev/api/v1/query?query=mereka_lms:error_budget_remaining" | jq '.data.result[0].value[1]'  # Should be 0.0-1.0

# Burn rate alerts
# Test: Temporarily cause failures and verify alerts fire within 2 minutes
```

**After Phase 4**:
```bash
# Advanced synthetic tests
kubectl get cronjobs -n observability | grep lms-synthetic  # Should exist

# Distributed tracing
curl -s "https://grafana.mereka.dev/api/ds/query" -d '{"queries":[{"datasource":"Tempo","queryType":"","refId":"A","query":"{service=\"lms\"}"}]}'  # Should return traces
```

---

## Risk Assessment & Mitigation

### Medium Risks
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| VPS → GKE connectivity fails | 30% | High | Federation fallback, external endpoint monitoring |
| Alert storm during implementation | 40% | Medium | Phased rollout, disable before enable pattern |
| Performance impact from tracing | 20% | Medium | Start with 1% sampling, monitor resource usage |

### Low Risks
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Synthetic checks cause load | 10% | Low | Rate limit checks, use realistic user patterns |
| Dashboard query performance | 15% | Low | Pre-computed recording rules, query optimization |

### Critical Success Factors
1. **Maintain existing monitoring** - Never disable working alerts during transition
2. **BBI standards compliance** - Follow STANDARDS.md for all new artifacts
3. **Incremental rollout** - Test each phase on staging before production
4. **Clear rollback procedures** - Document and test reversion steps

---

## Integration with Existing Systems

### BBI Standards Compliance
✅ **UID Naming**: `bbi-app-mereka-lms` follows `bbi-<layer>-<service>` pattern
✅ **Folder Assignment**: Applications folder (existing)
✅ **Required Tags**: `["bbi", "app", "mereka-lms"]`
✅ **Alert Naming**: `MerekaLMS*`, `MerekaCMS*` patterns
✅ **Severity Levels**: critical/warning/info hierarchy

### Centralized Monitoring Architecture
```
VPS Observability Stack (/home/gurpreet/projects/observability/)
├── dashboards/03-applications/bbi-mereka-lms.json ← Enhanced
├── alerts/applications.yaml ← SLO burn rate alerts added
├── datasources/ ← GKE Prometheus connectivity
├── recording-rules/slo-rules.yaml ← New SLO calculations
└── deploy/overlays/vps/ ← Deployment automation
```

### Deployment Commands
```bash
# Apply enhanced observability
cd /home/gurpreet/projects/observability
kubectl apply -k deploy/overlays/vps

# Deploy LMS monitoring configs
cd /home/gurpreet/projects/k8s/mereka-lms
./scripts/infra/apply-monitoring-configs.sh apply

# Verify integration
curl -s "https://grafana.mereka.dev/api/health" | jq .
kubectl get prometheusrules -n observability | grep mereka
```

---

## Implementation Timeline

| Week | Phase | Key Deliverables | Risk Level | Effort |
|------|-------|------------------|------------|---------|
| **Week 1** | MFE Synthetic + Fixes | Service selectors fixed, MFE monitoring live | Low | 6-8 hours |
| **Week 2** | Cross-Environment | VPS-GKE integration, alert deduplication | Medium | 7-10 hours |
| **Week 3** | SLO Enhancement | Burn rate alerts, error budget dashboards | Medium | 7-10 hours |
| **Week 4-5** | Advanced Features | Distributed tracing, business metrics | High | 17-22 hours |

**Total Effort**: 37-50 hours over 4-5 weeks

**Dependencies**: Network access VPS↔GKE, Django settings modification rights, CI/CD pipeline access

---

## Related Context: Bead 2d9

**Task**: `mereka-lms-2d9` (OAuth2 Client Verification for Ecommerce)
**Status**: Open (P3)
**Owner**: gurpreet
**Context**: While this observability plan was initiated in the context of "bead 2d9", the OAuth2 client verification task itself is separate from these monitoring improvements but represents the type of systematic quality assurance that benefits from enhanced observability.

---

## Next Steps After Approval

### Week 1 Priorities
1. **Immediate**: Fix service selector mismatches (K8s endpoints issue)
2. **Day 1**: Deploy MFE synthetic monitoring (3 new uptime checks)
3. **Day 3**: Verify GCP Console shows new monitoring configs
4. **Day 5**: Validate alert policies trigger correctly

### Stakeholder Communication
- **Platform Team**: Technical implementation details and rollout schedule
- **Business Team**: SLO dashboard location and error budget interpretation
- **On-Call Team**: New alert routing and runbook locations
- **Security Team**: Monitoring coverage for compliance requirements

### Success Metrics Dashboard
Create executive summary showing:
- **Before/After**: MTTR improvement, alert accuracy, coverage gaps filled
- **Business Impact**: Correlation between uptime and student engagement
- **Cost Efficiency**: Monitoring infrastructure cost per service monitored
- **Team Productivity**: Reduced context switching between monitoring tools

---

## Approval and Review

**For Independent Review, Please Assess**:

1. **Technical Soundness**: Are the proposed solutions technically feasible and well-architected?
2. **Risk Management**: Are the identified risks appropriate and mitigations adequate?
3. **Resource Requirements**: Are the time estimates and effort allocations realistic?
4. **Business Value**: Do the improvements justify the implementation effort?
5. **Operational Impact**: Will this enhance or burden day-to-day operations?
6. **Standards Compliance**: Does the plan align with existing BBI observability standards?

**Questions for Reviewers**:

- Are there any missing considerations or alternative approaches?
- Should any phases be prioritized differently?
- Are there additional risks or mitigation strategies to consider?
- What additional verification steps would you recommend?
- How should success be measured beyond the technical metrics listed?

---

**Plan Version**: 1.0
**Document Created**: 2026-02-04
**Next Review Date**: Upon approval decision
**Document Location**: `/home/gurpreet/projects/k8s/mereka-lms/docs/operations/OBSERVABILITY_ENHANCEMENT_PLAN.md`