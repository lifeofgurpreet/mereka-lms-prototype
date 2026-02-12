# CI/CD Pipeline Runbook
_Audience: Platform Eng + DevOps • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers manual verification procedures for CI/CD pipeline components that cannot be fully automated in CI due to requiring active GitHub Actions runners, repository secrets, or live infrastructure.

> **Spec**: `specs/ci-cd-pipeline_spec.md`
> **Testmap**: `specs/testmaps/ci-cd-pipeline_testmap.yaml`

## Prerequisites

- GitHub repository admin access with Actions enabled
- Repository secrets configured (GAR credentials, GCP service account, etc.)
- Access to production GKE cluster for deployment verification
- Access to Grafana/Prometheus for observability verification

---

## Quality Gates Verification

### Procedure
1. Trigger a PR with intentional lint/test failures
2. Verify the CI workflow catches failures and blocks merge
3. Verify status checks are required in branch protection rules

### Acceptance
- PR with failing tests cannot be merged
- Status checks are listed as required in GitHub branch protection
- Failed checks produce clear, actionable error messages

---

## Image Build Verification

### Procedure
1. Trigger the image build workflow via `workflow_dispatch` or push to main
2. Monitor the build in GitHub Actions UI
3. Verify images are pushed to Artifact Registry:
   ```bash
   gcloud artifacts docker images list \
     asia-southeast1-docker.pkg.dev/mereka-lms/openedx \
     --include-tags --limit=5
   ```
4. Verify image tags match the commit SHA
5. Verify multi-stage build completes (openedx, mfe stages)

### Acceptance
- Images appear in Artifact Registry with correct SHA tags
- Build completes within expected time (openedx: <45 min, mfe: <20 min)
- Build logs show no warnings about missing dependencies

---

## GitOps Deployment Verification

### Procedure
1. After image build, verify kustomization.yaml is updated with new image tag
2. Verify the deployment workflow applies changes to the cluster:
   ```bash
   kubectl get pods -n mereka-lms -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
   ```
3. Confirm rollout completes successfully:
   ```bash
   kubectl rollout status deployment/lms -n mereka-lms --timeout=300s
   ```

### Acceptance
- Pod images match the latest built SHA
- Rollout completes without errors
- All pods reach Running state with ready containers

---

## Release Process Verification

### Procedure
1. Create a release tag following semver convention
2. Verify the release workflow triggers automatically
3. Verify release notes are generated
4. Verify release artifacts (images) are tagged with the release version

### Acceptance
- Release tag triggers the release workflow
- Release notes contain commit summaries since last release
- Images are tagged with both SHA and release version

---

## Scheduled Operations Verification

### Procedure
1. Check GitHub Actions scheduled workflows (cron triggers)
2. Verify backup workflows run on schedule
3. Verify DR evidence bundle workflow runs monthly

### Acceptance
- Scheduled workflows appear in Actions history at expected times
- No scheduled workflow has failed silently (check for notification gaps)
- Backup artifacts exist for the expected schedule

---

## iOS Build Verification

### Procedure
1. Trigger the iOS build workflow (when implemented)
2. Verify Xcode build completes on macOS runner
3. Verify IPA artifact is produced

### Acceptance
- iOS build workflow completes successfully
- Build artifact is produced and downloadable

---

## SSO Canary Verification

### Procedure
1. Verify the SSO canary check runs in CI
2. Confirm it validates Authentik OIDC discovery endpoint
3. Verify it catches SSO misconfigurations before deployment

### Acceptance
- SSO canary runs on every PR and push to main
- Canary failure blocks deployment
- Canary produces clear error messages for SSO issues

---

## Tutor Configuration Verification

### Procedure
1. Verify CI runs `verify-tutor-config.sh` on PRs touching `infrastructure/tutor/`
2. Verify patch application is validated
3. Confirm plugin compatibility checks pass

### Acceptance
- Tutor config changes trigger verification in CI
- Missing patches are caught before merge
- Plugin conflicts produce clear error messages

---

## Tutor Plugin Testing

### Procedure
1. Verify CI tests Tutor plugin installation and configuration
2. Verify plugin hooks are validated
3. Confirm plugin-generated templates are syntactically correct

### Acceptance
- Plugin installation succeeds in CI
- Plugin hooks produce expected configuration changes
- Template generation produces valid YAML/Python

---

## Plugin Integration Testing

### Procedure
1. Trigger a full CI build that includes plugin + patch integration
2. Verify patches are applied after plugin configuration
3. Inspect build logs for plugin+patches integration

### Acceptance
- Full build with plugins completes successfully
- Patches are applied correctly after plugin configuration
- No conflicts between plugin output and patch expectations

---

## PR Failure Comment Verification

### Procedure
1. Create a PR with a failing plugin test
2. Verify the CI bot posts a troubleshooting comment on the PR
3. Verify the comment includes actionable remediation steps

### Acceptance
- Bot comment appears within 5 minutes of failure
- Comment includes specific failure reason and fix suggestions
- Comment links to relevant documentation

---

## Edge Case Handling

### OOM Conditions
1. Trigger a build in a resource-constrained environment
2. Verify OOM is detected and reported (not silent failure)
3. Verify `NODE_OPTIONS=--max-old-space-size=6144` is set

### Network Failures
1. Simulate network partition during image push
2. Verify retry logic activates
3. Verify partial artifacts are cleaned up

### PAT Expiration
1. Verify workflow detects expiring GitHub PATs
2. Verify notification is sent before expiration
3. Verify workflow fails gracefully (not silently) on expired PAT

### API Rate Limits
1. Monitor GitHub API usage during heavy CI periods
2. Verify rate limit handling includes backoff
3. Verify no workflow fails silently due to rate limits

### Workflow Retry
1. Verify failed workflows can be retried from the GitHub UI
2. Verify retry produces consistent results
3. Verify retry state is clean (no stale artifacts)

---

## Performance Testing

### Build Time Benchmarks
- openedx image: target < 45 minutes
- mfe image: target < 20 minutes
- CI quality gates: target < 10 minutes

### Procedure
1. Record build times over a 2-week period
2. Identify outliers and investigate root causes
3. Verify caching is effective (compare cached vs uncached builds)

### Acceptance
- 95th percentile build times are within target
- Cache hit rate > 80% for repeated builds
- No build takes more than 2x the target time

---

## Reliability Testing

### Procedure
1. Analyze GitHub Actions workflow history for the past 30 days
2. Calculate success rate per workflow
3. Verify reproducibility: build same commit multiple times and compare image digests

### Acceptance
- Workflow success rate > 95% (excluding intentional failures)
- Same commit produces identical image digests across builds
- No flaky tests in the workflow

---

## Observability Verification

### Procedure
1. Access Grafana CI/CD dashboard
2. Verify metrics are being collected:
   - Build duration per workflow
   - Build success/failure rate
   - Image push latency
   - Deployment rollout duration
3. Verify alerts are configured for:
   - Build failures on main branch
   - Deployment rollout failures
   - Image push failures

### Acceptance
- Grafana dashboard loads with recent data
- All listed metrics have data points for the past 24 hours
- Alert rules exist and have fired test notifications
