# Analytics Decision Gate: Aspects/Superset Deployment

**Status**: ACCEPTED (as of 2026-02-25)
**Last Review**: 2026-02-17
**Next Review**: 2026-05-17 (90 days)
**Owner**: Platform Team
**Related ADR**: [ADR-017: Analytics Target Decision](../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md)
**Related Spec**: [specs/analytics-pipeline_spec.md](../../../specs/analytics-pipeline_spec.md)

---

## Executive Summary

The platform has **deferred** deployment of Aspects (Open edX native analytics) and Superset dashboards indefinitely. This decision gate document tracks the conditions under which we should revisit this decision and provides a framework for evaluating whether to keep the deferral or proceed with deployment.

**Current Recommendation**: **PROCEED** (owner override 2026-02-25)

---

## Current Status

### Aspects Plugin State

| Component | Status | Details |
|-----------|--------|---------|
| **Plugin Installation** | Installed (local only) | `tutor-contrib-aspects` in `.venv` |
| **Configuration** | Template ready | `infrastructure/tutor/config.example.yml` has Aspects config |
| **Docker Images** | Not built | Neither local nor production images exist |
| **Local Deployment** | Not deployed | Services not running (`tutor local dc ps \| grep aspects` = empty) |
| **Production Deployment** | Not deployed | No pods in cluster (`kubectl get pods -n mereka-lms \| grep aspects` = empty) |
| **K8s Manifests** | Exist but inactive | `deploy/k8s/base/plugins/aspects/*.yml` exist but NOT in kustomization |
| **Analytics Spec** | In progress | `specs/analytics-pipeline_spec.md` status: "in_progress" |

### Infrastructure Already Available

The platform has the following infrastructure components ready but NOT deployed:

1. **ClickHouse manifests**: Database deployment, service, PVC (columnar storage for events)
2. **Ralph manifests**: Event processing pipeline deployment
3. **Superset manifests**: Dashboard deployment + worker + service
4. **Configuration templates**: All Tutor config variables documented
5. **Documentation**: Installation guide, quickstart, comparison docs in `docs/concepts/analytics/`

### Operational Monitoring vs Learning Analytics

**Important distinction**:

| Type | Status | Purpose | Stack |
|------|--------|---------|-------|
| **Operational Monitoring** | ✅ DEPLOYED | Platform reliability, performance, uptime | Prometheus, Grafana, Alertmanager |
| **Learning Analytics** | ❌ NOT DEPLOYED | Course engagement, completion rates, learner behavior | Aspects, ClickHouse, Superset |

The platform **already has** comprehensive operational monitoring. This decision gate is about **learning analytics only**.

---

## Revisit Conditions (from ADR-017)

### Decision Matrix

| # | Condition | Status | Evidence | Last Checked |
|---|-----------|--------|----------|--------------|
| 1 | Core platform stable 3+ months (no critical incidents) | ⚠️ PARTIAL | Platform operational but <3 months uptime since major changes | 2026-02-17 |
| 2 | Course creators request learning analytics | ❌ NOT MET | No explicit requests logged | 2026-02-17 |
| 3 | Team capacity for ClickHouse/Superset ops | ❌ NOT MET | Team focused on core features, no analytics ops bandwidth | 2026-02-17 |
| 4 | Analytics spec reaches APPROVED | ❌ NOT MET | Status: "in_progress" | 2026-02-17 |
| 5 | Demonstrated use cases justify overhead | ❌ NOT MET | No validated use cases | 2026-02-17 |

**Legend**: ✅ MET | ⚠️ PARTIAL | ❌ NOT MET

### Condition Details

#### 1. Platform Stability (⚠️ PARTIAL)

**Requirement**: 3+ consecutive months with zero critical incidents

**Current State**:
- Production cluster operational
- Monitoring stack (Prometheus/Grafana) deployed
- No formal incident tracking log for 3-month stability assessment
- Recent major infrastructure work (multi-tenancy, enterprise SSO foundation, purchase gateway)

**What would satisfy this**:
- Run `docs/status/active/NEXT10_TASKS.md` incident-tracking section updates for 90 days
- Zero P0 (site down) or P1 (critical feature broken) incidents
- SLO compliance at 99.5%+ for 90 days

**Check command**:
```bash
# Future: Query incident log
grep -c "severity: critical" docs/status/active/NEXT10_TASKS.md  # Should be 0
```

#### 2. Course Creator Demand (❌ NOT MET)

**Requirement**: Explicit requests from course creators for learning analytics features

**Current State**:
- No formal feature request log
- No documented requests for analytics dashboards
- Interim solution (LMS built-in Instructor Dashboard) may be sufficient

**What would satisfy this**:
- 3+ course creators request cohort analysis, engagement funnels, or completion trend dashboards
- Documented in `docs/status/active/NEXT10_TASKS.md`

**Validation**:
```bash
# Future: Check feature request log
grep -c "analytics\|dashboard\|engagement" docs/status/active/NEXT10_TASKS.md
```

#### 3. Team Capacity (❌ NOT MET)

**Requirement**: Team has bandwidth for ClickHouse operations, Superset upgrades, schema evolution

**Operational Overhead Estimate**:
- **Initial deployment**: 8-12 hours (image builds, schema init, verification)
- **Ongoing maintenance**: 3-5 hours/month
  - ClickHouse schema evolution (as LMS changes)
  - Superset security updates
  - Query optimization
  - Backup verification
  - Disk usage monitoring

**Current State**:
- Team focused on core LMS features (multi-tenancy, enterprise SSO, purchase gateway)
- No dedicated data engineer or analytics specialist
- Operational monitoring (Prometheus/Grafana) already consumes ops bandwidth

**What would satisfy this**:
- Dedicated 5 hours/month allocated for analytics ops
- OR hire data engineer/analytics specialist
- OR analytics becomes higher priority than current roadmap items

#### 4. Spec Approval (❌ NOT MET)

**Requirement**: `specs/analytics-pipeline_spec.md` status changes from "in_progress" to "approved"

**Current State**:
- Spec exists and is comprehensive (100+ lines)
- Status: "in_progress"
- No formal approval process documented

**Check command**:
```bash
grep '^status:' specs/analytics-pipeline_spec.md  # Should be "approved"
```

#### 5. Validated Use Cases (❌ NOT MET)

**Requirement**: Concrete, validated use cases that justify the operational overhead

**Potential Use Cases** (not yet validated):
- Instructors need to identify struggling learners early (engagement drop-offs)
- Platform admins need enrollment trend dashboards for capacity planning
- Course designers need A/B testing data (which content variations perform better)
- Institutional reporting (completion rates by cohort, time-to-completion)

**Current State**:
- All use cases are hypothetical
- No evidence that LMS built-in analytics are insufficient
- No manual workarounds currently in place that analytics would replace

**What would satisfy this**:
- Document 3+ use cases with real user stories
- Show evidence that current tools (Instructor Dashboard, manual CSV exports) cannot meet the need
- Quantify time savings or decision quality improvements

---

## Cost Analysis

### Infrastructure Costs (GCP/GKE)

**Estimated Monthly Costs** (if deployed):

| Component | Resources | Monthly Cost (USD) |
|-----------|-----------|-------------------|
| **ClickHouse Pod** | 2 CPU, 4Gi RAM | ~$50 |
| **Superset Pod** | 1 CPU, 2Gi RAM | ~$25 |
| **Superset Worker Pod** | 0.5 CPU, 1Gi RAM | ~$12 |
| **Ralph Pod** | 0.5 CPU, 512Mi RAM | ~$8 |
| **Storage (ClickHouse PVC)** | 50Gi SSD (90-day retention) | ~$10 |
| **Backup Storage (GCS)** | ~20GB/month | ~$0.50 |
| **Load Balancer (if separate ingress)** | N/A (shares existing Caddy) | $0 |
| **Total** | | **~$105/month** |

**Current Savings**: $105/month by keeping deferred

### Operational Costs

| Activity | Frequency | Time per Instance | Annual Hours |
|----------|-----------|-------------------|--------------|
| Schema evolution (LMS upgrades) | Quarterly | 2 hours | 8 hours |
| Superset security updates | Monthly | 1 hour | 12 hours |
| Query optimization | As needed | 2 hours | 6 hours |
| Backup verification | Monthly | 0.5 hours | 6 hours |
| Dashboard creation/maintenance | On demand | Variable | 10 hours |
| Troubleshooting (disk full, slow queries) | Ad-hoc | Variable | 8 hours |
| **Total** | | | **50 hours/year** |

**Cost at $100/hour**: $5,000/year in engineering time

### Comparison: Manual Analytics Workaround

**Current approach** (LMS built-in analytics + manual exports):
- Time cost: ~2 hours/month for manual CSV exports and analysis
- Annual: 24 hours/year (~$2,400 at $100/hour)

**Break-even analysis**: Aspects deployment makes sense if analytics requests exceed 50+ hours/year of manual work (~4 hours/month).

---

## Infrastructure Readiness

### What's Already in Place

✅ Plugin installed (`tutor-contrib-aspects` in local `.venv`)
✅ Configuration templates (`infrastructure/tutor/config.example.yml`)
✅ Kubernetes manifests (`deploy/k8s/base/plugins/aspects/`)
✅ Documentation (`docs/concepts/analytics/*.md`)
✅ Deployment procedure documented (ADR-017 § Implementation Notes)

### What's Missing

❌ Docker images (not built)
❌ ClickHouse schema initialization (requires `tutor k8s init`)
❌ Production secrets (ClickHouse admin password, Superset secret key)
❌ Retention policy implementation (TTL configuration)
❌ Backup automation (ClickHouse → GCS)
❌ Monitoring/alerting for analytics stack (disk usage, query timeouts, event processing lag)
❌ Runbook for common issues (ClickHouse disk full, Superset query timeout, Ralph pipeline stuck)

### Deployment Effort Estimate

If decision changes to PROCEED:

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| **Image Build** | `tutor images build aspects aspects-superset` | 30-45 min |
| **Secrets Setup** | Generate passwords, create GCP secrets, sync to K8s | 1 hour |
| **Schema Init** | `tutor k8s init` (ClickHouse schema + Superset DB) | 30 min |
| **Deploy** | `tutor k8s start`, verify pods running | 15 min |
| **Retention Config** | Set ClickHouse TTL (90 days) | 30 min |
| **Backup Setup** | Configure GCS daily backups | 1 hour |
| **Monitoring** | Add Prometheus alerts, Grafana dashboards | 2 hours |
| **Smoke Test** | Generate test events, verify dashboards load | 1 hour |
| **Documentation** | Update runbooks, operational guides | 2 hours |
| **Total** | | **8-10 hours** |

---

## Interim Solution

**While analytics remains deferred**, the platform provides:

1. **LMS Built-in Analytics** (Instructor Dashboard → Reports):
   - Enrollment counts
   - Completion rates (per course)
   - Grade distributions
   - Problem answer distributions
   - Daily engagement (page views, video plays)

2. **Manual Exports** (if needed):
   - Django admin can export user/enrollment CSVs
   - Instructor Dashboard allows CSV download of grade reports

3. **Operational Monitoring** (Prometheus/Grafana):
   - HTTP request rates
   - Error rates
   - Pod resource usage
   - Service uptime

**Documentation**: See `docs/concepts/analytics/README.md` for current capabilities

---

## Decision Framework

### When to Revisit

This decision should be **reviewed every 90 days** OR immediately if:

1. ✅ **Trigger event**: Course creator files explicit analytics feature request
2. ✅ **Trigger event**: Platform incident log shows 90+ days stability
3. ✅ **Trigger event**: Analytics spec approved
4. ✅ **Trigger event**: New team member with analytics ops experience hired
5. ✅ **Scheduled review**: 90 days since last review (next: 2026-05-17)

### Decision Criteria

**Proceed with deployment if**:
- ≥ 3 of 5 conditions are MET
- AND condition #3 (team capacity) is MET or PARTIAL
- AND condition #4 (spec approved) is MET

**Keep deferred if**:
- < 3 conditions are MET
- OR condition #3 (team capacity) is NOT MET
- OR condition #5 (validated use cases) is NOT MET

---

## Verification

This document has an automated verification script:

```bash
./scripts/qa/verify-analytics-decision-gate.sh
```

**What it checks**:
- ✅ This decision gate document exists
- ✅ ADR-017 exists and has correct status ("Deferred" or "Accepted")
- ✅ ADR-017 has "Last verified" comment with date
- ⚠️ ADR-017 last verified date is within 90 days (WARN if stale)
- ✅ Aspects plugin NOT deployed to production (no pods expected)
- ✅ K8s manifests exist but not in active kustomization
- ✅ Decision matrix table present in this document
- ✅ All 5 revisit conditions documented

**CI Integration**: This script runs on every PR via `.github/workflows/ci.yml`

---

## Acceptance Criteria

This document satisfies the following acceptance criteria:

- **AC-ADGATE-001**: Decision gate documents all revisit conditions with current status
  - Evidence: Decision Matrix table (line 56) lists all 5 conditions with status/evidence/date

- **AC-ADGATE-002**: Verifier checks ADR status, infrastructure readiness, and condition assessment
  - Evidence: Verification script `scripts/qa/verify-analytics-decision-gate.sh` implements all checks

- **AC-ADGATE-003**: CI gate prevents stale decision (alerts if >90 days since last review)
  - Evidence: Verifier warns if ADR-017 "Last verified" comment is >90 days old
  - Evidence: CI workflow runs verifier on every PR

---

## Related Documentation

- **ADR**: [ADR-017: Analytics Target Decision](../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md)
- **Spec**: [specs/analytics-pipeline_spec.md](../../../specs/analytics-pipeline_spec.md)
- **Target-state deployment**: [docs/concepts/analytics/ASPECTS_TARGET_STATE.md](../../concepts/analytics/ASPECTS_TARGET_STATE.md)
- **Comparison**: [docs/concepts/analytics/ANALYTICS_TOOL_COMPARISON.md](../../concepts/analytics/ANALYTICS_TOOL_COMPARISON.md)
- **Current Capabilities**: [docs/concepts/analytics/README.md](../../concepts/analytics/README.md)

---

## Change Log

| Date | Reviewer | Status | Notes |
|------|----------|--------|-------|
| 2026-02-13 | Platform Team | DEFERRED | Initial deferral (ADR-017) |
| 2026-02-17 | Platform Team | KEEP DEFERRED | All 5 conditions NOT MET; next review 2026-05-17 |
| 2026-02-25 | Platform Owner | ACCEPTED | Owner override — deployment approved regardless of gate conditions |
