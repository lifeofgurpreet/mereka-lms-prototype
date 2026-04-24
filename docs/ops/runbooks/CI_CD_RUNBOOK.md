# CI/CD Pipeline Runbook
_Audience: Platform Eng + DevOps • Owner: Engineering Lead • Last updated: 2026-04-09_

This runbook covers manual verification procedures for CI/CD pipeline components that cannot be fully automated in CI due to requiring active GitHub Actions runners, repository secrets, or live infrastructure.

It is a CI verification surface, not the canonical release-identity contract.
For the governed release path, read
[`../../reference/operations/RELEASE_PROCESS.md`](../../reference/operations/RELEASE_PROCESS.md)
first.

> **Spec**: `specs/ci-cd-pipeline_spec.md`
> **Testmap**: `specs/testmaps/ci-cd-pipeline_spec.testmap.yml`

## Prerequisites

- GitHub repository admin access with Actions enabled
- Repository secrets configured (GHCR token path, cluster/runtime credentials, etc.)
- Access to the current production cluster lane for deployment verification
- Access to Grafana/Prometheus for observability verification

## Current Operator Split

Keep these surfaces separate:

- CI workflow behavior and failure interpretation: this runbook
- release-object identity and promotion contract:
  [../../reference/operations/RELEASE_PROCESS.md](../../reference/operations/RELEASE_PROCESS.md)
- rollout execution sequence:
  [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) and
  [RELEASE_EXECUTE_RUNBOOK.md](RELEASE_EXECUTE_RUNBOOK.md)
- branch-protection policy:
  [../../policies/operations/BRANCH_PROTECTION.md](../../policies/operations/BRANCH_PROTECTION.md)
- usage/quota optimization:
  [../../reference/operations/GITHUB_ACTIONS_COST_MONITORING.md](../../reference/operations/GITHUB_ACTIONS_COST_MONITORING.md)

---

## Quality Gates Verification

Docs-only caveat:
- required branch-protection contexts now stay attached for docs-only and
  workflow-only PRs
- `ci.yml` computes `docs_only=true` and `tutor_required=false` to keep heavy
  Tutor work off unrelated changes without detaching the workflow itself
- `dependency-review.yml` and `iac-scan.yml` also stay attached for docs-only
  PRs so required checks still report
- use workflow-contract verifiers and branch-protection verification when
  testing docs-only control-plane changes

### Procedure
1. Trigger a PR with intentional lint/test failures
2. Verify the CI workflow catches failures and blocks merge
3. Verify status checks are required in branch protection rules

### Acceptance
- PR with failing tests cannot be merged
- Status checks are listed as required in GitHub branch protection
- Failed checks produce clear, actionable error messages

### Common failure classes

| Symptom | Route |
| --- | --- |
| required checks missing from merge gate | branch-protection policy |
| workflow did not trigger for expected change | workflow trigger/path-filter audit |
| check ran but artifact/evidence output is wrong | keep in CI/runbook lane |

---

## Image Build Verification

### Procedure
1. Trigger the image build workflow via `workflow_dispatch` or push to main
2. Monitor the build in GitHub Actions UI
3. Verify images are pushed to GHCR:
   ```bash
   crane ls ghcr.io/biji-biji-initiative/mereka-lms/openedx | head
   crane ls ghcr.io/biji-biji-initiative/mereka-lms/mfe | head
   ```
4. Download and inspect the workflow-emitted release artifacts:
   - `release-bundle` (signed bundle carrying `release-bundle.json`, `release-object.json`, `truth-ledger.json`, signature, certificate)
   - `build-provenance` (separate provenance/gate artifact)
   - optional supplementary `release-evidence` bundle when that separate workflow is run
5. Verify image tags match the commit SHA
6. Verify multi-stage build completes (openedx, mfe stages)

### Acceptance
- Images appear in GHCR with correct SHA tags
- `release-bundle`, `truth-ledger`, and `build-provenance` align to the same build run
- the bundled `release-object.json` inside `release-bundle` matches the same run identity
- any `release-evidence` bundle is treated as attached audit material, not primary release identity
- Build completes within expected time (openedx: <45 min, mfe: <20 min)
- Build logs show no warnings about missing dependencies

### Boundary

Do not treat a successful image build as a completed release. Build proof,
promotion proof, and runtime proof remain separate.

---

## GitOps Deployment Verification

### Procedure
1. After image build, verify the workflow emitted the release bundle and
   provenance artifacts, with `release-object.json` and `truth-ledger.json`
   present inside `release-bundle`
2. Verify the governed promotion path uses those workflow artifacts, not ad hoc tag joins
3. Verify the deployment workflow applies changes to the cluster:
   ```bash
   kubectl get pods -n mereka-lms -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
   ```
4. Confirm rollout completes successfully:
   ```bash
   kubectl rollout status deployment/lms -n mereka-lms --timeout=300s
   ```

### Acceptance
- Pod images match the latest built SHA
- Promotion command references the workflow-emitted bundled `release-object.json`
- Rollout completes without errors
- All pods reach Running state with ready containers

---

## Release Process Verification

### Procedure
1. Create a release tag following semver convention
2. Verify the GitHub release metadata workflow triggers automatically
3. Verify release notes are generated
4. Verify release artifacts (images) are tagged with the release version
5. Verify the governed promotion path consumes the workflow-emitted
   `release-object.json` when `--require-digests` is used for production

### Acceptance
- Release tag triggers the GitHub release metadata workflow
- Release notes contain commit summaries since last release
- Images are tagged with both SHA and release version
- the GitHub release metadata workflow is treated as bookkeeping, not the
  source of release-object identity

Reference:
- [../../reference/operations/RELEASE_PROCESS.md](../../reference/operations/RELEASE_PROCESS.md)
- [../../reference/operations/RELEASE_EVIDENCE.md](../../reference/operations/RELEASE_EVIDENCE.md)

---

## Scheduled Operations Verification

### Procedure
1. Check GitHub Actions scheduled workflows (cron triggers)
2. Verify scheduled workflows that are intentionally enabled run on schedule
3. Verify DR evidence bundle workflow runs monthly

### Acceptance
- Scheduled workflows appear in Actions history at expected times
- No scheduled workflow has failed silently (check for notification gaps)
- Legacy backup artifacts exist only if the gated `cloud-sql-backup.yml` workflow is intentionally enabled via `ENABLE_CLOUD_SQL_BACKUPS=true`

### Cost note

Scheduled workflows are one of the primary quota drivers. When a scheduled lane
is changed, verify the expected frequency still matches the cost-monitoring
guidance instead of treating cron changes as free.

---

## iOS Build Verification

### Procedure
1. Trigger the current iOS/TestFlight workflow (`ios-testflight.yml`) via tag or `workflow_dispatch`
2. Verify Xcode build completes on the macOS runner
3. Verify the IPA/TestFlight upload lane completes
4. Treat `build-ios-app.yml` as deprecated reference material only

### Acceptance
- `ios-testflight.yml` completes successfully when the lane is exercised
- The deprecated `build-ios-app.yml` workflow is not treated as the active CI front door

---

## SSO Canary Verification

### Procedure
1. Verify the SSO canary check runs on its scheduled cadence and by manual dispatch
2. Confirm the default scheduled scope targets staging unless an explicit env override is requested
3. Verify it catches authenticated OIDC/session misconfigurations before operators rely on the lane

### Acceptance
- SSO canary runs every 6 hours and via `workflow_dispatch`
- Scheduled runs default to the staging scope; dev/prod coverage is opt-in via workflow inputs/secrets
- Canary failure is an operational signal and proof artifact, not a branch-protection gate on every PR/push
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

## Emergency Boundary

Do not use “emergency bypass” to mean “skip release identity or runtime proof.”
The only acceptable shortcut is a consciously recorded exception with explicit
follow-up back to the governed release path.
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
