# ADR-017: Analytics Target Decision (Aspects/Superset Deployment)

**Status**: Accepted
**Date**: 2026-02-13
**Deciders**: Platform Team

<!-- Last verified: 2026-02-25 -->

## Context

The platform requires analytics capabilities for learning insights (enrollments, completions, engagement, etc.). Two primary options exist:

1. **Aspects** (Open edX native analytics):
   - Open-source, free
   - Uses ClickHouse (data warehouse) + Superset (visualization)
   - Includes Ralph (event processing)
   - Plugin available in Tutor: `tutor-contrib-aspects`
   - Current status: Plugin installed locally, **NOT deployed to production**

2. **Built-in LMS analytics** (Insights):
   - Native Open edX feature
   - Course-level analytics available in Instructor Dashboard
   - Minimal infrastructure overhead
   - Limited compared to Aspects but functional

**Current state**:
- Aspects plugin installed in local `.venv` only
- Configuration added to `infrastructure/tutor/config.example.yml`
- Docker images **NOT BUILT** (neither local nor production)
- Services **NOT DEPLOYED** (neither local nor production)
- Kubernetes manifests exist in `deploy/k8s/base/plugins/aspects/` but not applied
- Analytics spec (`specs/analytics-pipeline_spec.md`) status: "in_progress"
- No production analytics components running

**Infrastructure monitoring vs Learning analytics**:
- **Operational monitoring** (Prometheus/Grafana): DEPLOYED and operational
  - Monitors: CPU, memory, request rates, error rates, pod health
  - Purpose: Platform reliability and performance
- **Learning analytics** (Aspects/Superset): NOT DEPLOYED
  - Would monitor: Enrollments, completions, engagement, course effectiveness
  - Purpose: Educational insights and course design decisions

**Aspects infrastructure requirements**:
- ClickHouse (columnar database for events)
- Ralph (event processing pipeline)
- Superset + Superset Worker (visualization)
- Estimated operational overhead: 3-5 hours/month (upgrades, schema evolution, query optimization)
- Storage costs: ~$50/month for 90-day retention with compression
- Compute costs: Additional pods in GKE cluster

## Decision

Aspects is the **target analytics architecture**, but deployment is **deferred** until readiness gates are met.  
Current policy is no production Aspects deployment until the conditions below are satisfied.

**Rationale**:
- Core platform requires stabilization before adding analytics stack
- Aspects introduces significant operational complexity (ClickHouse ops, Ralph pipeline, Superset upgrades)
- Infrastructure monitoring (Prometheus/Grafana) already provides operational visibility
- LMS built-in analytics (Insights) can serve course-level needs in the interim
- No immediate course creator demand for advanced learning analytics
- Analytics spec is "in_progress" - feature not production-ready
- Team bandwidth better spent on core LMS features and stability

**Interim solution**:
- Use LMS built-in analytics (Instructor Dashboard → Reports)
- Use Prometheus/Grafana for operational metrics
- Use manual exports if specific learning analytics needed

**Revisit conditions**:
1. Core platform stable for 3+ consecutive months (no critical incidents)
2. Course creators explicitly request learning analytics features
3. Team has capacity for ClickHouse/Superset operations
4. Analytics spec reaches APPROVED status
5. Demonstrated use cases justify the operational overhead

## Consequences

### Positive
- Focus resources on core LMS stability
- Avoid premature operational burden (ClickHouse backups, schema migrations, query optimization)
- Reduce attack surface (fewer services exposed)
- Lower infrastructure costs (~$50-100/month savings)
- Defer decision until actual demand is validated

### Negative
- Course creators lack advanced analytics (cohort analysis, engagement funnels, etc.)
- Platform administrators cannot track platform-wide enrollment trends in dashboards
- No historical event data warehouse (events not stored long-term)
- May delay data-driven course design decisions

### Immediate Actions
1. **Document deferral status**:
   - [x] Update `docs/concepts/analytics/README.md` with deferral notice (already includes deployment status warning)
   - [ ] Update `docs/reference/operations/CAPABILITY_MATRIX.md`: Change Aspects from "IN-PROGRESS" to "DEFERRED"
   - [ ] Update `specs/analytics-pipeline_spec.md`: Add deferral notice at top

2. **Keep plugin configuration intact**:
   - Plugin remains installed in local `.venv` for future use
   - Configuration remains in `infrastructure/tutor/config.example.yml`
   - Kubernetes manifests remain in `deploy/k8s/base/plugins/aspects/`
   - No cleanup required - just don't deploy

3. **Document interim analytics approach**:
   - [ ] Create `docs/concepts/analytics/ASPECTS_ANALYTICS.md` documenting built-in LMS analytics usage

## Alternatives Considered

### Deploy Aspects immediately
- **Rejected because**: Core platform not stable enough
- **Rejected because**: No demonstrated demand from course creators
- **Rejected because**: Operational overhead not justified
- **Rejected because**: Analytics spec still in-progress (not production-ready)

### Deploy Panorama instead
- **Rejected because**: Commercial solution, significant cost
- **Rejected because**: Same operational complexity concerns as Aspects
- **Rejected because**: No demand validation
- See `docs/concepts/analytics/ASPECTS_VS_PANORAMA.md` for detailed comparison

### Build custom analytics
- **Rejected because**: Reinventing wheel - Aspects provides this
- **Rejected because**: Higher development cost than using Aspects

### Use Google Analytics/external SaaS
- **Rejected because**: Cannot track learning-specific events (enrollments, completions, problem attempts)
- **Rejected because**: Privacy concerns with third-party tracking

## Implementation Notes

### Current State Verification
```bash
# Local environment
tutor local dc ps | grep aspects
# Expected: No output (services not running)

# Production environment
kubectl get pods -n mereka-lms | grep aspects
# Expected: No resources found (not deployed)
```

### Future Deployment Procedure (when approved)
When analytics deployment is approved:

1. **Build images** (30-45 minutes):
   ```bash
   source .venv/bin/activate
   export TUTOR_ROOT="$(pwd)/tutor_env"
   tutor images build aspects aspects-superset
   ```

2. **Deploy to production**:
   ```bash
   tutor images push all --repository ghcr.io/biji-biji-initiative/mereka-lms
   tutor k8s init  # Initialize ClickHouse schema
   tutor k8s start
   ```

3. **Verify deployment**:
   ```bash
   kubectl get pods -n mereka-lms | grep aspects
   # Expected: clickhouse, superset, superset-worker, ralph pods running
   ```

4. **Configure retention policies**:
   - Default: 90 days hot (ClickHouse)
   - Archive: 1 year cold (GCS Parquet export)
   - Implement via ClickHouse TTL: `ALTER TABLE xapi_events_all MODIFY TTL event_date + INTERVAL 90 DAY`

### Resources to Review Before Deployment
- `docs/concepts/analytics/ASPECTS_INSTALLATION.md` (step-by-step deployment)
- `docs/concepts/analytics/ASPECTS_QUICKSTART.md` (post-install validation)
- `specs/analytics-pipeline_spec.md` (requirements and acceptance criteria)
- Open edX Aspects documentation: https://docs.openedx.org/projects/openedx-aspects/

### Monitoring Requirements (if deployed)
If Aspects is deployed in the future, ensure:
- ClickHouse disk usage alerts at 75% (warning) and 85% (critical)
- Event processing lag alerts if >10 minutes
- Superset query timeout monitoring
- ClickHouse backup verification (daily GCS backups)

## Related
- ADR-016: Android app support decision (similar deferral pattern)
- `specs/analytics-pipeline_spec.md` (analytics requirements)
- `docs/concepts/analytics/ASPECTS_INSTALLATION.md` (deployment guide)
- `docs/concepts/analytics/ASPECTS_VS_PANORAMA.md` (comparison with commercial alternative)
- `docs/reference/operations/CAPABILITY_MATRIX.md` (capability tracking)
- `docs/runbooks/operations/ASPECTS_WIRING_CHECKLIST.md` (deployment checklist)
