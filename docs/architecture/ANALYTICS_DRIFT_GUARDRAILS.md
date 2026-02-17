# Analytics Drift Guardrails

<!-- @covers AC-ADRIFT-001, AC-ADRIFT-002, AC-ADRIFT-003 -->
<!-- @spec: analytics-pipeline_spec.md -->

**Status**: ACTIVE
**Last updated**: 2026-02-17

## Purpose

This contract prevents analytics infrastructure (Aspects/Superset/ClickHouse) from drifting into production deployment without explicit decision gate approval.

**Context**: ADR-017 defers analytics deployment until core platform stability is proven and demand is validated. These guardrails enforce that decision by detecting and blocking accidental analytics infrastructure deployment.

## Guardrail Rules

### Rule 1: No Aspects Images in Production

**Requirement**: Production kustomization MUST NOT reference Aspects container images unless ADR-017 status is "Accepted".

**Forbidden image references**:
- `docker.io/overhangio/openedx-aspects`
- `docker.io/clickhouse/clickhouse-server`
- `docker.io/apache/superset`
- `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/*aspects*`
- `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/*clickhouse*`
- `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/*superset*`

**Scope**:
- `deploy/k8s/overlays/production/kustomization.yaml`
- `deploy/k8s/overlays/production/patches/*.yaml`

**Enforcement**: Verifier script (`verify-analytics-drift-guardrails.sh`) checks production overlay for image references.

### Rule 2: No ClickHouse Persistent Volumes

**Requirement**: Production overlay MUST NOT deploy ClickHouse PersistentVolumeClaims unless decision gate passed.

**Forbidden resources**:
- PVC with name containing `clickhouse`
- PVC with label `app.kubernetes.io/name=clickhouse`
- PVC with storage class used for analytics data

**Scope**:
- `deploy/k8s/base/plugins/aspects/volumes.yml` must NOT be referenced in production kustomization
- `deploy/k8s/overlays/production/kustomization.yaml` resources list must NOT include aspects volumes

**Enforcement**: Verifier checks production kustomization resources list for aspects volume references.

### Rule 3: No Superset Ingress/Routes

**Requirement**: Caddy configuration MUST NOT expose Superset ingress routes unless explicitly enabled via feature flag.

**Forbidden Caddyfile blocks**:
```
analytics.academyv2.mereka.io {
  reverse_proxy superset:8088
}
```

**Allowed pattern** (when deployment approved):
```
# Feature flag check required
(analytics_enabled) {
  @analytics host analytics.academyv2.mereka.io
  handle @analytics {
    reverse_proxy superset:8088
  }
}
```

**Scope**:
- `tutor_env/env/apps/caddy/Caddyfile` (generated file)
- `infrastructure/tutor/patches/` (patch files that modify Caddyfile)

**Enforcement**: Verifier checks Caddyfile for uncommented Superset reverse_proxy directives.

### Rule 4: Analytics Spec Must Be APPROVED

**Requirement**: `specs/analytics-pipeline_spec.md` status field must be "approved" before production deployment.

**Forbidden states**:
- `status: "in_progress"`
- `status: "draft"`
- `status: "pending_review"`

**Allowed states**:
- `status: "approved"`
- `status: "production"` (if implemented and deployed)

**Scope**:
- `specs/analytics-pipeline_spec.md` frontmatter

**Enforcement**: Verifier parses spec frontmatter and checks status field.

### Rule 5: ADR-017 Status Gate

**Requirement**: ADR-017 status must be "Accepted" before analytics deployment to production.

**Forbidden states**:
- `Status: Deferred` (current state)
- `Status: Proposed`
- `Status: Draft`

**Allowed states**:
- `Status: Accepted`
- `Status: Superseded` (if replaced by newer ADR)

**Scope**:
- `docs/adr/017-analytics-target-decision.md` frontmatter

**Enforcement**: Verifier parses ADR frontmatter and checks Status field.

## Drift Detection

The verifier (`scripts/qa/verify-analytics-drift-guardrails.sh`) detects the following drift conditions:

### 1. Image Drift
**Detection method**: Grep production kustomization `images:` section for analytics-related image names.

**Pass condition**: Zero matches for `aspects`, `clickhouse`, `superset` in image references.

**Failure condition**: Any analytics image found in production kustomization.

### 2. PVC Drift
**Detection method**: Check if `deploy/k8s/base/plugins/aspects/volumes.yml` is referenced in production resources.

**Pass condition**: Aspects volumes NOT in production kustomization resources list.

**Failure condition**: Aspects volumes referenced in production kustomization.

### 3. Pod Drift
**Detection method**: Query production cluster for aspects-related pods.

**Command**:
```bash
kubectl get pods -n mereka-lms -l app.kubernetes.io/part-of=aspects
```

**Pass condition**: No resources found (exit code 0 but empty output).

**Failure condition**: Any aspects pods exist in production namespace.

### 4. Route Drift
**Detection method**: Parse Caddyfile for uncommented Superset reverse_proxy directives.

**Pass condition**: No active Superset routes (all commented out or behind disabled feature flag).

**Failure condition**: Active Superset route found in Caddyfile.

### 5. Decision Gate Drift
**Detection method**: Parse ADR and spec status fields.

**Pass conditions**:
- ADR-017 Status: "Deferred" OR "Accepted"
- Spec status: "in_progress" AND ADR Status: "Deferred" (deployment NOT happening)
- Spec status: "approved" AND ADR Status: "Accepted" (deployment approved)

**Failure conditions**:
- Spec status: "approved" BUT ADR Status: "Deferred" (spec approved but decision still deferred)
- Spec status: "in_progress" BUT analytics images/pods/routes exist (deployment without approval)

## Decision Closure Procedure

When analytics deployment is approved, follow these steps to formally close the decision gate:

### Phase 1: Decision Approval

1. **Validate revisit conditions** (all must be met):
   - [ ] Core platform stable for 3+ consecutive months (check incident log)
   - [ ] Course creators have explicitly requested learning analytics features (check support tickets)
   - [ ] Team has capacity for ClickHouse/Superset operations (staffing review)
   - [ ] Analytics spec reaches APPROVED status (spec review meeting)
   - [ ] Demonstrated use cases justify operational overhead (business case doc)

2. **Update ADR-017**:
   ```bash
   # Edit docs/adr/017-analytics-target-decision.md
   # Change:
   #   Status: Deferred
   # To:
   #   Status: Accepted
   # Add Decision Date: YYYY-MM-DD
   # Add Approval Justification: (bullet points addressing each revisit condition)
   ```

3. **Update analytics spec status**:
   ```bash
   # Edit specs/analytics-pipeline_spec.md frontmatter
   # Change:
   #   status: "in_progress"
   # To:
   #   status: "approved"
   ```

4. **Run drift guardrails verifier** (should PASS with new statuses):
   ```bash
   ./scripts/qa/verify-analytics-drift-guardrails.sh
   # Expected: All decision gate checks PASS
   ```

### Phase 2: Infrastructure Preparation

5. **Build Aspects images** (30-45 minutes):
   ```bash
   source .venv/bin/activate
   export TUTOR_ROOT="$(pwd)/tutor_env"
   tutor images build aspects aspects-superset
   ```

6. **Push images to Artifact Registry**:
   ```bash
   tutor images push aspects aspects-superset \
     --repository asia-southeast1-docker.pkg.dev/mereka-lms/openedx
   ```

7. **Update production kustomization**:
   ```yaml
   # In deploy/k8s/overlays/production/kustomization.yaml
   images:
     - name: docker.io/clickhouse/clickhouse-server
       newName: asia-southeast1-docker.pkg.dev/mereka-lms/openedx/clickhouse
       newTag: 23.8-alpine  # Pin specific version
     - name: docker.io/apache/superset
       newName: asia-southeast1-docker.pkg.dev/mereka-lms/openedx/superset
       newTag: 3.1.0  # Pin specific version
   ```

8. **Create ClickHouse secrets** (in GCP Secret Manager):
   ```bash
   # Generate secure passwords
   CLICKHOUSE_PASSWORD=$(openssl rand -base64 32)
   SUPERSET_SECRET_KEY=$(openssl rand -hex 32)

   # Store in GCP SM
   printf '%s' "$CLICKHOUSE_PASSWORD" | \
     gcloud secrets create MEREKA_LMS_CLICKHOUSE_PASSWORD \
       --project=bbi-k8 --data-file=-

   printf '%s' "$SUPERSET_SECRET_KEY" | \
     gcloud secrets create MEREKA_LMS_SUPERSET_SECRET_KEY \
       --project=bbi-k8 --data-file=-
   ```

9. **Update ExternalSecrets mapping**:
   ```yaml
   # In deploy/k8s/base/secrets/external-secrets.yaml
   - secretKey: clickhouse-password
     remoteRef:
       key: MEREKA_LMS_CLICKHOUSE_PASSWORD
   - secretKey: superset-secret-key
     remoteRef:
       key: MEREKA_LMS_SUPERSET_SECRET_KEY
   ```

### Phase 3: Deployment

10. **Deploy to production** (staged rollout):
    ```bash
    # Deploy ClickHouse first (data layer)
    kubectl apply -f deploy/k8s/base/plugins/aspects/volumes.yml
    kubectl apply -f deploy/k8s/base/plugins/aspects/deployments.yml -l app.kubernetes.io/name=clickhouse
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=clickhouse -n mereka-lms --timeout=300s

    # Initialize ClickHouse schema
    kubectl apply -f deploy/k8s/base/plugins/aspects/jobs.yml -l job-name=clickhouse-init

    # Deploy Superset (visualization layer)
    kubectl apply -f deploy/k8s/base/plugins/aspects/deployments.yml -l app.kubernetes.io/name=superset
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=superset -n mereka-lms --timeout=300s

    # Initialize Superset (create admin user, load dashboards)
    kubectl apply -f deploy/k8s/base/plugins/aspects/jobs.yml -l job-name=superset-init
    ```

11. **Enable Superset ingress** (in Caddy):
    ```bash
    # Apply patch to add Superset route to Caddyfile
    # See docs/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md for full Caddy config
    tutor local restart caddy
    ```

12. **Smoke test**:
    ```bash
    # Verify ClickHouse has data
    kubectl exec -n mereka-lms deploy/clickhouse -- \
      clickhouse-client --query "SELECT count() FROM xapi_events_all"

    # Verify Superset accessible
    curl -I https://analytics.academyv2.mereka.io
    # Expected: HTTP 200 (login page)
    ```

### Phase 4: Verification

13. **Run drift guardrails verifier** (should PASS with deployment active):
    ```bash
    ./scripts/qa/verify-analytics-drift-guardrails.sh
    # Expected: All checks PASS (decision approved, deployment detected, specs aligned)
    ```

14. **Update capability matrix**:
    ```bash
    # Edit docs/operations/CAPABILITY_MATRIX.md
    # Change Aspects row:
    #   Status: DEFERRED → PRODUCTION
    #   Notes: Add deployment date, version info
    ```

15. **Update analytics README**:
    ```bash
    # Edit docs/analytics/README.md
    # Remove deferral notice
    # Add production access URLs
    # Add operational runbook links
    ```

### Phase 5: Handoff

16. **Document operational procedures**:
    - Follow `docs/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md` for ongoing operations
    - Set up monitoring alerts (event lag, query performance, disk usage)
    - Schedule first dashboard review meeting with course creators

17. **Commit decision closure**:
    ```bash
    git add docs/adr/017-analytics-target-decision.md
    git add specs/analytics-pipeline_spec.md
    git add deploy/k8s/overlays/production/kustomization.yaml
    git add deploy/k8s/base/secrets/external-secrets.yaml
    git add docs/operations/CAPABILITY_MATRIX.md
    git commit -m "feat(analytics): Deploy Aspects/Superset (ADR-017 approved)

    - Update ADR-017 status: Deferred → Accepted
    - Update analytics spec status: in_progress → approved
    - Deploy ClickHouse, Superset, and dashboards
    - Enable analytics ingress route
    - Update capability matrix

    Revisit conditions met:
    - Core platform stable for 3+ months
    - Course creator demand validated
    - Team capacity confirmed
    - Analytics spec approved

    @covers AC-ADRIFT-003

    Co-Authored-By: Claude <noreply@anthropic.com>"
    git push
    ```

## Verification Commands

### Quick Drift Check
```bash
# Run full guardrails suite
./scripts/qa/verify-analytics-drift-guardrails.sh

# Expected output (current state, deployment deferred):
# ✓ PASS: ADR-017 status is Deferred (deployment gate closed)
# ✓ PASS: Analytics spec status is in_progress (not approved for production)
# ✓ PASS: No aspects images in production kustomization
# ✓ PASS: No aspects volumes in production kustomization
# ✓ PASS: No Superset routes in Caddyfile
# ✓ PASS: Decision gate alignment verified (Deferred + in_progress = no deployment)
```

### Individual Checks
```bash
# Check ADR status
grep "^**Status**:" docs/adr/017-analytics-target-decision.md

# Check spec status
yq eval '.status' specs/analytics-pipeline_spec.md

# Check production images
grep -E "aspects|clickhouse|superset" deploy/k8s/overlays/production/kustomization.yaml

# Check live cluster (requires kubectl access)
kubectl get pods -n mereka-lms -l app.kubernetes.io/part-of=aspects
```

## Failure Scenarios

### Scenario 1: Accidental Image Deployment

**Symptom**: Verifier reports analytics images in production kustomization.

**Root cause**: Developer copy-pasted local kustomization to production overlay.

**Remediation**:
1. Revert production kustomization: `git revert <commit-sha>`
2. Remove analytics images from kustomization
3. Run verifier: `./scripts/qa/verify-analytics-drift-guardrails.sh`
4. Push fix: `git push`

### Scenario 2: Live Pods Without Approval

**Symptom**: Verifier reports aspects pods running but ADR still "Deferred".

**Root cause**: Manual kubectl apply bypassed kustomization drift guard.

**Remediation**:
1. Delete pods: `kubectl delete pods -n mereka-lms -l app.kubernetes.io/part-of=aspects`
2. Delete deployments: `kubectl delete deployments -n mereka-lms -l app.kubernetes.io/part-of=aspects`
3. Delete PVCs: `kubectl delete pvc -n mereka-lms -l app.kubernetes.io/part-of=aspects`
4. Verify cleanup: `kubectl get all,pvc -n mereka-lms -l app.kubernetes.io/part-of=aspects`
5. Run verifier: `./scripts/qa/verify-analytics-drift-guardrails.sh`

### Scenario 3: Spec Approved But ADR Deferred

**Symptom**: Verifier reports spec status "approved" but ADR-017 status "Deferred".

**Root cause**: Spec review merged before decision gate review.

**Remediation**:
1. Revert spec status change: Edit `specs/analytics-pipeline_spec.md`, change `status: approved` → `status: in_progress`
2. OR fast-track ADR review if revisit conditions met
3. Run verifier: `./scripts/qa/verify-analytics-drift-guardrails.sh`

## Related Documentation

- ADR-017: Analytics Target Decision (`docs/adr/017-analytics-target-decision.md`)
- Analytics spec: `specs/analytics-pipeline_spec.md`
- Superset deployment runbook: `docs/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md`
- Capability matrix: `docs/operations/CAPABILITY_MATRIX.md`

---

**Contract enforcement**: This contract is enforced by `scripts/qa/verify-analytics-drift-guardrails.sh` (CI gate in `.github/workflows/ci.yml`).
