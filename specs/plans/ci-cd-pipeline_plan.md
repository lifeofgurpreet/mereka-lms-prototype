---
title: "CI/CD Pipeline - Implementation Plan"
source_spec: "specs/ci-cd-pipeline_spec.md"
created: "2026-02-10"
status: "draft"
---

# Implementation Tasks: CI/CD Pipeline

**Source Spec**: `specs/ci-cd-pipeline_spec.md`

**Acceptance Criteria Count**: 28 ACs
**Requirements Count**: 60+ functional requirements across 11workflows
**Edge Cases**: 14 edge cases covering OOM, timeouts, retries, idempotency, rate limits

---

## Task Breakdown by Category

### Build

#### Workflow Standardization & Quality Gates

- [ ] **[S]** Audit all 11 workflow files for action versionpinning compliance (`.github/workflows/`) | Req: Standardization-2 | Depends: None
  - Verify all actions use major tags (`@v4`) or SHA for third-party actions
  - Document any exceptions with justification
  - Update actions that use floating tags

- [ ] **[M]** Add explicit `timeout-minutes` to all jobs lacking them (`.github/workflows/*.yml`) | AC: #1 | Depends: None
  - CI jobs: 10 minutes each
  - Build jobs: openedx 45min, MFE 20min, iOS 90min
  - GitOps update: 5 minutes
  - Scheduled workflows: 15 minutes
  - Document timeout rationale in workflow comments

- [ ] **[S]** Enforce `persist-credentials: false` on checkout actions except where git push required (`.github/workflows/*.yml`) | Req: Security-6 | Depends: None
  - Audit all `actions/checkout@v4` usage
  - Add `persist-credentials: false` unless workflow requiresgit operations
  - Only GitOps workflows should persist credentials

#### CI Workflow Enhancements

- [ ] **[M]** Add `validate-infisical` job conditional execution logic (`if` condition) (`.github/workflows/ci.yml`) | AC:#5 | Depends: None
  - Check for `INFISICAL_TOKEN` and `INFISICAL_PROJECT_ID` secrets
  - Skip job if secrets not configured
  - Log skip reason in job summary

- [ ] **[M]** Implement TruffleHog secret scanning with `--only-verified` flag (`.github/workflows/ci.yml`) | AC: #5 | Depends: None
  - Add TruffleHog action to security-scan job
  - Configure `--only-verified` to reduce false positives
  - Upload findings as artifacts for review
  - Fail build on verified secrets found

- [ ] **[M]** Add monitoring-guardrails artifact upload on success (`.github/workflows/ci.yml`) | AC: #1 | Depends: None
  - Capture output of all monitoring scripts to `monitoring-offline-plan` directory
  - Upload artifact with 90-day retention
  - Include timestamp and run ID in artifact metadata

- [ ] **[S]** Enhance CI job step summaries with structured pass/fail results (`.github/workflows/ci.yml`) | Req: Observability-1 | Depends: None
  - Generate markdown tables with check name, status, duration
  - Use GitHub Step Summary API
  - Include remediation guidance for common failures

#### Build Workflow Improvements

- [ ] **[M]** Add dependency between build jobs and lint job(`.github/workflows/build-tutor-images.yml`) | Req: Build-3 |Depends: None
  - Add `needs: lint` to `build-openedx` and `build-mfe` jobs
  - Ensure lint passes before expensive builds run
  - Document dependency rationale in workflow comments

- [ ] **[M]** Implement image digest resolution and job output exposure (`.github/workflows/build-tutor-images.yml`) | AC:#10 | Depends: None
  - Capture digest from `docker push` output using `docker inspect`
  - Expose as job outputs: `openedx-digest`, `mfe-digest`
  - Log digests to step summary for traceability

- [ ] **[M]** Add MFE branding verification gate before imagepush (`.github/workflows/build-tutor-images.yml`) | AC: #11| Depends: None
  - Run `scripts/qa/verify-mfe-image-branding.sh` after MFE build
  - Check authn `index.html` for branding revision marker
  - Upload verification log as artifact
  - Fail build if branding check fails

- [ ] **[S]** Remove `:latest` tag publishing from build workflows (`.github/workflows/build-tutor-images.yml`) | AC: #13| Depends: None
  - Remove any `docker tag` or `docker push` commands with `:latest`
  - Use only SHA-based tags (full SHA and 8-char short SHA)
  - Document tag immutability policy in workflow comments

- [ ] **[M]** Set `NODE_OPTIONS=--max-old-space-size=6144` for MFE builds (`.github/workflows/build-tutor-images.yml`) | Req: Build-9 | Depends: None
  - Add environment variable to MFE build job
  - Document memory requirement in workflow comments
  - Consider adding warning about GitHub runner limits

#### GitOps Deployment Automation

- [ ] **[L]** Implement GitOps update job with digest validation (`.github/workflows/build-tutor-images.yml`) | AC: #14-18| Depends: Image digest resolution
  - Add `update-gitops` job with `needs: [build-openedx, build-mfe]`
  - Execute only when `update_gitops=true`
  - Require `target_environment` != `select-environment`
  - Call `release-openedx-gitops.sh` with `--apply --commit --push --require-digests`
  - Pass `--openedx-digest` and `--mfe-digest` from build joboutputs
  - Validate `GITOPS_PAT` secret presence before cross-repo operations
  - Configure git identity as `github-actions[bot]`

- [ ] **[S]** Block staging environment unless explicitly enabled (`.github/workflows/build-tutor-images.yml`) | AC: #16 |Depends: None
  - Add `if` condition checking `vars.ENABLE_STAGING_ENV == 'true'`
  - Fail with clear error message if staging requested but not enabled
  - Document staging gating in workflow comments

- [ ] **[S]** Add deprecation error for `deploy_to_staging` input (`.github/workflows/build-tutor-images.yml`) | AC: #17 |Depends: None
  - Check if `deploy_to_staging` input is used
  - Fail with message: "deploy_to_staging is deprecated. Useupdate_gitops=true and target_environment=staging instead."
  - Retain input for backward compatibility but make it non-functional

#### iOS Build Pipeline

- [ ] **[M]** Add Ruby gems and CocoaPods caching (`.github/workflows/build-ios-app.yml`) | Req: iOS-8 | Depends: None
  - Use `actions/cache@v4` for `~/.gem` and `Pods/`
  - Cache key based on Gemfile.lock and Podfile.lock
  - Document cache hit/miss in step summary

- [ ] **[S]** Ensure SSH key cleanup in `always()` step (`.github/workflows/build-ios-app.yml`) | Req: iOS-7 | Depends: None
  - Add cleanup step with `if: always()`
  - Remove SSH keys used for Fastlane Match
  - Log cleanup completion

#### Release Policy Checks

- [ ] **[M]** Implement policy checks workflow with all verification scripts (`.github/workflows/policy-checks.yml`) | AC:#20 | Depends: None
  - Run all 10 verification scripts from AC-20
  - Validate script syntax with `bash -n` before execution
  - Capture output to individual log files
  - Upload logs as artifacts
  - Fail workflow if any check fails
  - Generate structured step summary with pass/fail per script

#### Release Evidence Generation

- [ ] **[L]** Implement release evidence workflow with metadata bundle (`.github/workflows/release-evidence.yml`) | AC: #19, #21 | Depends: None
  - Accept required inputs: `openedx_tag`, `mfe_tag`, `target_environment`
  - Resolve image digests from Artifact Registry for providedtags
  - Run all policy check scripts and capture output
  - Execute dry-run of `release-openedx-gitops.sh` (no `--apply --commit --push`)
  - Generate `release-metadata.json` with required fields (AC-21)
  - Upload single artifact bundle: `release-evidence-<env>-<run_number>`
  - Generate step summary with evidence checklist

#### Scheduled Operations Workflows

- [ ] **[M]** Implement GKE authentication with error handling in runtime workflows (`.github/workflows/operations-gates-runtime.yml`) | AC: #22 | Depends: None
  - Use `google-github-actions/auth@v2` with `GCP_SA_KEY`
  - Add conditional logic for transient auth failures (`|| true` for non-strict mode)
  - Upload artifacts with 30-day retention
  - Support configurable environment scope (`prod`/`dev`/`both`)

- [ ] **[S]** Configure observability audit JSON output (`.github/workflows/observability-audit.yml`) | AC: #23 | Depends:None
  - Produce JSON artifacts for local and runtime audits
  - Upload with default (90-day) retention
  - Include audit timestamp and scope in artifact names

- [ ] **[M]** Implement public health check with branding andauth verification (`.github/workflows/public-health-check.yml`) | AC: #24 | Depends: None
  - Run every 30 minutes (schedule: `*/30 * * * *`)
  - Execute branding gates (prod strict + dev)
  - Verify auth surfaces (prod + dev)
  - Fail workflow on any degradation (triggers alert)
  - Upload verification logs as artifacts

- [ ] **[S]** Configure DR evidence bundle with 120-day retention (`.github/workflows/dr-evidence-bundle.yml`) | AC: #26 |Depends: None
  - Schedule: `0 2 1 * *` (1st of month at 02:30 UTC)
  - Run `scripts/qa/build-dr-evidence-bundle.sh`
  - Upload artifact with 120-day retention
  - Generate step summary with bundle contents

- [ ] **[S]** Gate Cloud SQL backup workflow behind repository variable (`.github/workflows/cloud-sql-backup.yml`) | AC: #| Depends: None
  - Add `if: vars.ENABLE_CLOUD_SQL_BACKUPS == 'true'` to alljobs
  - Document gating reason in workflow comments
  - Log skip message if disabled

#### Branch Protection & Merge Gates

- [ ] **[S]** Configure branch protection rules for main branch (GitHub repository settings) | AC: #7, #8 | Depends: CI workflow
  - Require pull request reviews
  - Require all CI status checks to pass
  - Require linear history (no merge commits)
  - Disable force pushes
  - Allow admin bypass for emergency hotfixes only
  - Document protection rules in `docs/operations/RELEASE_CHECKLIST.md`

#### Artifact Management

- [ ] **[S]** Configure artifact retention policies (`.github/workflows/*.yml`) | Req: Artifact-2 | Depends: None
  - CI artifacts: default (90 days)
  - Operations gates: 30 days (set `retention-days: 30`)
  - DR evidence: 120 days (set `retention-days: 120`)
  - Release evidence: default (90 days)
  - Document retention rationale in workflow comments

- [ ] **[M]** Implement Artifact Registry lifecycle policy for non-production images (GCP Console or Terraform) | Req: Artifact-3 | Depends: None
  - Clean up images after 90 days for non-production tags
  - Preserve images with production tags indefinitely
  - Tag production images with `prod-<sha>` prefix for lifecycle filtering
  - Document policy in `docs/operations/IMAGE_LIFECYCLE.md`

#### Rollback Mechanism

- [ ] **[M]** Document rollback procedure in release checklist (`docs/operations/RELEASE_CHECKLIST.md` section 7) | AC: #2| Depends: None
  - Step-by-step rollback instructions
  - How to identify last 5 successful production deployments
  - Command to re-run `release-openedx-gitops.sh` with priortags
  - Expected rollback completion time (10 minutes)
  - Verification steps after rollback

- [ ] **[S]** Create script to list last N successful production releases (`scripts/releases/list-recent-releases.sh`) | Req: Rollback-5 | Depends: None
  - Query GitHub API for successful `release-evidence.yml` runs
  - Extract tags and digests from `release-metadata.json` artifacts
  - Output last 5 releases in table format
  - Support `--count` flag to change number of releases

#### Notification & Alerting

- [ ] **[M]** Implement workflow failure notification mechanism (`.github/workflows/*.yml`) | AC: #24 | Depends: None
  - Add Slack webhook notification step (conditional on failure) to workflows on main branch
  - Include workflow name, run URL, failure reason in notification
  - High priority for `public-health-check.yml` failures
  - Document notification configuration in `docs/operations/CI_CD_ALERTING.md`

- [ ] **[S]** Add actionable remediation guidance to step summaries (`.github/workflows/*.yml`) | Req: Notification-3 | Depends: None
  - For common failures (OOM, timeout, auth, secret issues),provide copy-paste fix commands
  - Link to troubleshooting docs
  - Include relevant log excerpts in summary

#### Cost Optimization

- [ ] **[M]** Add pip dependency caching to CI workflow (`.github/workflows/ci.yml`) | Req: Cost-3 | Depends: None
  - Use `actions/cache@v4` for pip cache directory
  - Cache key based on Python version and requirements files
  - Document cache effectiveness in workflow comments

- [ ] **[S]** Audit scheduled workflow frequency against GitHub Actions quota (manual analysis) | Req: Cost-5 | Depends: None
  - Calculate estimated monthly minutes for all scheduled workflows
  - Compare against GitHub Actions quota (2,000 free, 3,000 Team)
  - Propose frequency reductions if quota exceeded
  - Document analysis in `docs/operations/CI_CD_COST_ANALYSIS.md`

- [ ] **[S]** Document cost optimization recommendations (`docs/operations/CI_CD_COST_OPTIMIZATION.md`) | Req: Cost-1 to Cost-6 | Depends: None
  - Runner selection guidance (ubuntu-latest vs self-hosted)
  - Caching strategies for different workflows
  - Scheduled workflow frequency tuning
  - Path filters for build triggers
  - When to use `--no-cache` vs incremental builds

### Test

#### Workflow Validation Tests

- [ ] **[M]** Create workflow syntax validation script (`scripts/qa/validate-workflow-syntax.sh`) | AC: #1 | Depends: None
  - Use `actionlint` or `act --dryrun` to validate workflow YAML
  - Check for required fields, valid triggers, action versionpinning
  - Run in CI as pre-merge gate
  - Document validation rules

- [ ] **[M]** Create workflow contract tests (`tests/workflows/test_ci_workflow_contract.py`) | AC: #1-8 | Depends: None
  - Parse CI workflow YAML
  - Assert all required jobs present (spec-lint, lint, validate-k8s, security-scan, etc.)
  - Assert timeout-minutes set on all jobs
  - Assert action versions pinned
  - Assert `persist-credentials: false` except GitOps workflows

- [ ] **[M]** Create build workflow contract tests (`tests/workflows/test_build_workflow_contract.py`) | AC: #9-13 | Depends: None
  - Parse build workflow YAML
  - Assert `needs: lint` dependency on build jobs
  - Assert digest resolution logic present
  - Assert no `:latest` tag publishing
  - Assert MFE branding verification before push

- [ ] **[M]** Create GitOps workflow contract tests (`tests/workflows/test_gitops_workflow_contract.py`) | AC: #14-18 | Depends: None
  - Parse build workflow YAML
  - Assert `update-gitops` job requires both builds
  - Assert `target_environment` validation logic
  - Assert staging gating behind `ENABLE_STAGING_ENV`
  - Assert `deploy_to_staging` deprecation error
  - Assert digest flags passed to release script

#### Integration Tests

- [ ] **[L]** Create CI workflow end-to-end test (local Kindcluster) (`tests/integration/test_ci_e2e.sh`) | AC: #1-8 | Depends: None
  - Trigger CI workflow via `act` or GitHub API
  - Verify all 12 jobs execute
  - Verify pass/fail propagation
  - Verify artifacts uploaded
  - Test with intentional failures to verify merge blocking

- [ ] **[M]** Create build workflow integration test (mock registry) (`tests/integration/test_build_workflow_e2e.sh`) | AC: #9-13 | Depends: None
  - Use local Docker registry as mock Artifact Registry
  - Trigger build workflow
  - Verify images tagged with SHA
  - Verify digests resolved
  - Verify MFE branding check runs

- [ ] **[M]** Create GitOps update integration test (mock bbi-infrastructure) (`tests/integration/test_gitops_update_e2e.sh`) | AC: #14-18 | Depends: None
  - Use test repository as mock `bbi-infrastructure`
  - Trigger GitOps update with valid inputs
  - Verify commit created in mock repo
  - Verify digest validation enforced
  - Test failure cases (missing digests, invalid environment)

#### Security Tests

- [ ] **[M]** Create secret masking verification test (`tests/security/test_secret_masking.sh`) | AC: #28 | Depends: None
  - Trigger workflow that uses secrets
  - Parse workflow logs
  - Assert no secret values appear in logs
  - Test with various secret types (GCP SA key, PAT, API tokens)

- [ ] **[M]** Create pre-commit hook secret detection test (`tests/security/test_precommit_hook.sh`) | AC: #27 | Depends:None
  - Create test files with hardcoded secrets
  - Attempt commit
  - Verify commit rejected
  - Test various secret patterns (passwords, keys, tokens, connection strings)

#### Observability Tests

- [ ] **[M]** Create workflow metrics extraction test (`tests/observability/test_workflow_metrics.py`) | Req: Observability-1 | Depends: None
  - Query GitHub API for workflow runs
  - Extract duration, success rate, failure reasons
  - Verify metrics meet NFRs (CI <15min, build <45min)
  - Generate report for cost analysis

- [ ] **[M]** Create artifact validation test (`tests/observability/test_artifact_generation.py`) | Req: Observability-3 |Depends: None
  - Trigger workflows that produce artifacts
  - Download artifacts via GitHub API
  - Verify structure, contents, metadata
  - Verify retention settings

#### Rollback Tests

- [ ] **[M]** Create rollback procedure test (`tests/rollback/test_rollback_procedure.sh`) | AC: #21 | Depends: Rollback documentation
  - Simulate production deployment with specific tags
  - Execute rollback procedure from docs
  - Verify rollback completes within 10 minutes
  - Verify prior tags applied to GitOps repo
  - Verify pods converge to prior version

### Observability

- [ ] **[M]** Create CI/CD metrics dashboard (`infrastructure/observability/dashboards/ci-cd-dashboard.json`) | Req: Observability-4 | Depends: None
  - Workflow duration by type (CI, build, scheduled)
  - Success rate by workflow
  - Failure reasons breakdown
  - GitHub Actions quota usage
  - Deployment frequency (DORA metric)
  - Mean time to recovery (MTTR)

- [ ] **[M]** Configure Alertmanager alerts for CI/CD (`infrastructure/observability/alerts/ci-cd-alerts.yml`) | Req: Observability-3 | Depends: None
  - Critical: `public-health-check.yml` failure (production degradation)
  - Critical: Build failures on main branch
  - Warning: `operations-gates-runtime.yml` failures in strict mode
  - Warning: DR evidence bundle failure
  - Warning: GitHub Actions quota >80% consumed

- [ ] **[S]** Implement workflow step summary generation helper (`scripts/ci/generate-workflow-summary.sh`) | Req: Observability-1 | Depends: None
  - Generate markdown tables from script outputs
  - Format pass/fail results
  - Add timestamps and durations
  - Include remediation links
  - Output to `$GITHUB_STEP_SUMMARY`

### Docs

- [ ] **[M]** Write CI/CD pipeline runbook (`docs/operations/CI_CD_RUNBOOK.md`) | Depends: All implementations
  - Overview of 11 workflows and their purposes
  - How to trigger manual workflows
  - How to interpret workflow failures
  - Common failure scenarios and fixes
  - Emergency bypass procedures
  - Rollback procedures

- [ ] **[M]** Update release checklist with CI/CD integration(`docs/operations/RELEASE_CHECKLIST.md`) | AC: #21 | Depends: None
  - Pre-release: run policy checks, generate release evidence
  - Release: trigger build workflow with GitOps update
  - Post-release: verify deployment, check observability
  - Rollback: procedure with time estimates
  - Link to CI/CD runbook for detailed troubleshooting

- [ ] **[S]** Document branch protection rules (`docs/operations/BRANCH_PROTECTION.md`) | AC: #7, #8 | Depends: Branch protection setup
  - Current protection rules for main branch
  - Rationale for each rule
  - Emergency hotfix bypass procedure
  - How to update protection rules

- [ ] **[S]** Document CI/CD cost optimization strategies (`docs/operations/CI_CD_COST_OPTIMIZATION.md`) | Req: Cost-1 toCost-6 | Depends: Cost analysis
  - GitHub Actions quota tracking
  - Scheduled workflow frequency tuning
  - Caching strategies
  - Runner selection (hosted vs self-hosted)
  - Build optimization (incremental vs clean)

- [ ] **[S]** Document image lifecycle policy (`docs/operations/IMAGE_LIFECYCLE.md`) | Req: Artifact-3 | Depends: ArtifactRegistry lifecycle setup
  - Tag naming conventions
  - Retention policy for production vs non-production images
  - How to query image history
  - Cleanup procedures

- [ ] **[S]** Document notification and alerting setup (`docs/operations/CI_CD_ALERTING.md`) | Req: Notification-1 to Notification-4 | Depends: Notification setup
  - Slack webhook configuration
  - Alert channels and severity levels
  - On-call escalation for critical alerts
  - How to silence alerts during maintenance

### Rollout

- [ ] **[S]** Phase 1: Add timeout and action pinning to allworkflows | Depends: Workflow standardization tasks
  - Apply timeout-minutes to all jobs
  - Audit and update action versions
  - Deploy via PR, merge to main
  - Monitor workflow runs for 1 week

- [ ] **[M]** Phase 2: Enable branch protection rules | AC: #7, #8 | Depends: Phase 1
  - Configure protection rules in GitHub settings
  - Test merge blocking with intentional CI failure
  - Document emergency bypass procedure
  - Communicate changes to team

- [ ] **[M]** Phase 3: Add secret scanning and security enhancements | AC: #5, #27, #28 | Depends: Phase 2
  - Add TruffleHog to CI workflow
  - Distribute pre-commit hook setup instructions to team
  - Run security audit on existing codebase
  - Fix any detected secrets before enforcing

- [ ] **[M]** Phase 4: Implement GitOps automation with digest validation | AC: #14-18 | Depends: Phase 3
  - Deploy GitOps update job
  - Test with non-production environment first
  - Document usage in release checklist
  - Train team on manual dispatch workflow

- [ ] **[M]** Phase 5: Enable observability and alerting | Req: Observability-1 to Observability-4 | Depends: Phase 4
  - Deploy CI/CD dashboard
  - Configure Alertmanager alerts
  - Test alert routing with intentional failures
  - Document on-call procedures

- [ ] **[S]** Phase 6: Optimize costs and scheduled workflows| Req: Cost-1 to Cost-6 | Depends: Phase 5
  - Analyze quota usage after 1 month of Phase 5
  - Implement caching optimizations
  - Tune scheduled workflow frequencies if needed
  - Document cost tracking procedures

---

## Dependencies Summary

### Critical Path
1. Workflow standardization (timeouts, action pinning) → Branch protection → Security enhancements → GitOps automation → Observability → Cost optimization

### Parallel Tracks
- **Workflows**: CI enhancements, build improvements, GitOpsautomation can proceed in parallel
- **Documentation**: Runbooks and guides can proceed alongside implementation
- **Testing**: Workflow contract tests can proceed as workflows are updated
- **Observability**: Dashboard and alerts can be developed inparallel with workflow changes

### Gating Tasks for Each Phase
- **Phase 1**: Timeout addition + Action pinning + Contract tests
- **Phase 2**: Branch protection config + CI workflow stability
- **Phase 3**: Secret scanning + Pre-commit hook + Security audit
- **Phase 4**: GitOps job + Digest resolution + Integration tests
- **Phase 5**: Dashboard + Alerts + Step summaries
- **Phase 6**: Cost analysis + Caching + Frequency tuning

---

## Complexity Estimates

- **S (Small)**: <2 hours - Configuration changes, simple scripts, documentation updates
- **M (Medium)**: 2-8 hours - Workflow modifications, testing, integration with existing systems
- **L (Large)**: >8 hours - Complex workflows (GitOps, release evidence), E2E tests, multi-workflow coordination

---

## Risk Mitigation

1. **Risk**: GitHub Actions quota exhaustion due to frequentscheduled workflows
   - **Mitigation**: Track usage monthly, tune frequencies, implement caching
   - **Task**: Cost analysis and optimization tasks

2. **Risk**: OOM during OpenEdX builds on GitHub-hosted runners
   - **Mitigation**: Document memory limits, provide self-hosted runner guidance
   - **Task**: Build workflow improvements with memory configuration

3. **Risk**: GitOps PAT expiration causing deployment failures
   - **Mitigation**: Pre-flight validation of PAT, clear error messages
   - **Task**: GitOps update job with secret validation

4. **Risk**: Branch protection blocking emergency hotfixes
   - **Mitigation**: Admin bypass procedure documented, clearescalation path
   - **Task**: Branch protection documentation with emergencyprocedures

5. **Risk**: False positive secret detection blocking legitimate commits
   - **Mitigation**: TruffleHog `--only-verified` flag, pattern refinement
   - **Task**: Secret scanning implementation with verified-only mode

---

## Open Questions to Resolve Before Implementation

1. **Self-hosted runners**: Should we provision self-hosted runner for OpenEdX builds? Cost vs reliability tradeoff. → Need infrastructure team input
2. **Notification channel**: Slack webhook vs PagerDuty vs GitHub email? → Need team preference
3. **Scheduled workflow frequencies**: Current 30-min healthchecks may exceed quota. Reduce to hourly? → Need cost analysis first
4. **Terraform plan in CI**: Should CI validate Terraform changes? Requires broader GCP permissions. → Need security review
5. **Container image signing**: Add cosign/Sigstore for supply chain security? → Need security team input
6. **Dependency scanning**: Dependabot vs Renovate for automated updates? → Need team preference

---

## Self-Check (Before Implementation Begins)

- [ ] Every acceptance criterion (1-28) has at least one build task
- [ ] Every acceptance criterion has at least one test task
- [ ] Edge cases from spec have corresponding test tasks
- [ ] File paths specified for each task
- [ ] Dependencies identified (or marked "None")
- [ ] Complexity estimated (S/M/L) for each task
- [ ] Observability tasks cover metrics, alerts, dashboards
- [ ] Rollout tasks include phased deployment, verification
- [ ] Docs tasks include runbook, release checklist, cost optimization guide
- [ ] Source spec linked: `specs/ci-cd-pipeline_spec.md`
