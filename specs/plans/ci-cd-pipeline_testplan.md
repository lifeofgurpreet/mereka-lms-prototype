---
title: "CI/CD Pipeline - Test Plan"
source_spec: "specs/ci-cd-pipeline_spec.md"
created: "2026-02-10"
status: "draft"
---

# Test Plan: CI/CD Pipeline

**Source Spec**: `specs/ci-cd-pipeline_spec.md`

**Test Framework**: Shell scripts (bash), Python (pytest), GitHub Actions (act for local workflow testing)

**Acceptance Criteria**: 28 ACs mapped to test cases (AC-001 through AC-028, AC-INT-001 through AC-INT-004)
**Edge Cases**: 14 edge cases with negative tests

---

## Test Coverage Matrix

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| **Quality Gates (CI Workflow)** |
| 1 | PR opened against main triggers CI with all 12 jobs | e2e | `tests/workflows/test_ci_trigger.sh` | GitHub API or act|
| 1 | All CI jobs report commit status checks | integration |`tests/workflows/test_ci_status_checks.sh` | GitHub API |
| 2 | Spec with missing frontmatter fails spec-lint job | unit | `tests/workflows/test_spec_lint.sh` | Invalid spec file fixture |
| 2 | Spec-lint error message identifies non-conforming spec| unit | `tests/workflows/test_spec_lint_errors.sh` | Invalidspec file fixture |
| 3 | Python file with ruff violation fails lint job | unit |`tests/workflows/test_lint_python.sh` | Python file with lint errors |
| 4 | Invalid Kubernetes YAML fails validate-k8s job | unit |`tests/workflows/test_validate_k8s.sh` | Invalid K8s manifest fixture |
| 5 | Verified secret detected by TruffleHog fails security-scan job | integration | `tests/workflows/test_trufflechog.sh`| File with hardcoded secret |
| 5 | Security finding reported in workflow output | integration | `tests/workflows/test_security_findings.sh` | File withhardcoded secret |
| 6 | Production overlay referencing `:latest` tag fails prod-tag-guard job | unit | `tests/workflows/test_prod_tag_guard.sh` | Kustomize overlay with :latest |
| 7 | All CI jobs pass, PR approved enables merge button | e2e | `tests/workflows/test_merge_gate_pass.sh` | GitHub API, mock PR |
| 8 | Any CI job fails, merge button disabled | e2e | `tests/workflows/test_merge_gate_block.sh` | GitHub API, mock PR with failure |
| **Image Build** |
| 9 | Push to main modifying infrastructure/tutor/** triggersbuild workflow | integration | `tests/workflows/test_build_trigger.sh` | Git push simulation |
| 9 | Both openedx and MFE images built, tagged with SHA andshort SHA | integration | `tests/workflows/test_image_tagging.sh` | Mock Docker registry |
| 9 | Images pushed to ghcr.io/biji-biji-initiative/mereka-lms/ | integration | `tests/workflows/test_image_registry.sh` | Mock Artifact Registry |
| 10 | OpenEdX image push returns resolved digest (sha256:...) in job output | integration | `tests/workflows/test_digest_resolution.sh` | Mock Docker registry |
| 11 | MFE branding verification validates authn index.html revision marker | unit | `tests/workflows/test_mfe_branding_check.sh` | Mock MFE build output |
| 11 | MFE branding check failure fails build before push | integration | `tests/workflows/test_mfe_branding_fail.sh` | MFE without branding marker |
| 12 | Manual dispatch with image_tag=v1.2.3 tags image as openedx:v1.2.3 and openedx:<short-sha> | integration | `tests/workflows/test_custom_tag.sh` | Mock workflow dispatch |
| 13 | Build workflow does not publish :latest tag to Artifact Registry | unit | `tests/workflows/test_no_latest_tag.sh` |Parse workflow YAML, check docker commands |
| **GitOps Deployment** |
| 14 | update_gitops=true, target_environment=production, both builds succeed invokes release script with digests | integration | `tests/workflows/test_gitops_update_success.sh` | Mock bbi-infrastructure repo |
| 14 | Release script called with --apply --commit --push --require-digests flags | integration | `tests/workflows/test_gitops_flags.sh` | Mock release script |
| 15 | update_gitops=true, target_environment=select-environment fails with error | unit | `tests/workflows/test_gitops_no_default_env.sh` | Mock workflow dispatch |
| 16 | update_gitops=true, target_environment=staging, ENABLE_STAGING_ENV not set fails with message | unit | `tests/workflows/test_staging_gated.sh` | Mock workflow dispatch |
| 17 | deploy_to_staging=true fails with deprecation error |unit | `tests/workflows/test_deploy_staging_deprecated.sh` |Mock workflow dispatch |
| 18 | update_gitops=true but build_openedx=false fails requiring both builds | unit | `tests/workflows/test_gitops_requires_builds.sh` | Mock workflow dispatch |
| **Release Process** |
| 19 | Release evidence workflow with valid tags uploads artifact bundle | integration | `tests/workflows/test_release_evidence.sh` | Mock Artifact Registry |
| 19 | Release evidence bundle contains: policy logs, dry-runplan, digests, metadata.json | integration | `tests/workflows/test_evidence_bundle_contents.sh` | Download artifact via GitHub API |
| 20 | Policy checks workflow runs all 10 verification scripts | integration | `tests/workflows/test_policy_checks.sh` | Mock workflow dispatch |
| 20 | All policy checks pass, workflow succeeds | integration | `tests/workflows/test_policy_checks_pass.sh` | Mock workflow dispatch |
| 21 | Rollback with prior known-good tags completes withoutbuilding images | integration | `tests/workflows/test_rollback_no_build.sh` | Mock release script, prior tags |
| 21 | Rollback pods converge within 10 minutes | e2e | `tests/workflows/test_rollback_convergence.sh` | Live GKE or Kindcluster |
| **Scheduled Operations** |
| 22 | operations-gates-runtime runs on schedule, GKE auth succeeds, gates execute, artifacts uploaded | integration | `tests/workflows/test_ops_gates_scheduled.sh` | Mock GKE, schedule trigger |
| 22 | Artifacts uploaded with 30-day retention | unit | `tests/workflows/test_ops_gates_retention.sh` | Parse workflow YAML |
| 23 | observability-audit runs daily, produces JSON artifacts for local and runtime audits | integration | `tests/workflows/test_observability_audit.sh` | Mock workflow dispatch |
| 24 | public-health-check runs every 30 minutes, verifies branding and auth surfaces | integration | `tests/workflows/test_health_check_scheduled.sh` | Mock health check scripts |
| 24 | Health check failure triggers alert | integration | `tests/workflows/test_health_check_alert.sh` | Intentional failure, check notification |
| 26 | DR evidence bundle runs monthly, uploads artifact with120-day retention | integration | `tests/workflows/test_dr_evidence_scheduled.sh` | Mock schedule trigger |
| 27 | cloud-sql-backup only executes when ENABLE_CLOUD_SQL_BACKUPS=true | unit | `tests/workflows/test_cloud_sql_gated.sh` | Parse workflow YAML, check if condition |
| **iOS Build** |
| 25 | iOS workflow manual dispatch completes, signed IPA uploaded to TestFlight | e2e | `tests/workflows/test_ios_build.sh` | Mock App Store Connect API |
| 26 | iOS workflow cleanup step removes SSH keys regardlessof build outcome | integration | `tests/workflows/test_ios_ssh_cleanup.sh` | Mock workflow failure, check cleanup |
| **Security** |
| 27 | Pre-commit hook rejects commit with hardcoded secret pattern | unit | `tests/workflows/test_precommit_hook.sh` | Test file with secret |
| 28 | Workflow logs do not contain secret values (GitHub Actions masking) | integration | `tests/workflows/test_secret_masking.sh` | Workflow using secrets, parse logs |
| **Edge Cases** |
| EC-OOM-1 | OpenEdX build OOMs, fails clearly with memory error | integration | `tests/workflows/test_openedx_oom.sh` | Docker memory limit, trigger build |
| EC-OOM-1 | Step summary suggests building locally or usingself-hosted runners | integration | `tests/workflows/test_oom_remediation.sh` | Parse step summary on OOM failure |
| EC-OOM-2 | MFE build OOMs, error distinguishable from otherfailures | integration | `tests/workflows/test_mfe_oom.sh` |Docker memory limit, trigger build |
| EC-Network-1 | Docker push failure due to network issue fails build (no partial push) | integration | `tests/workflows/test_docker_push_failure.sh` | Mock network timeout |
| EC-Network-2 | Re-running workflow after push failure is idempotent | integration | `tests/workflows/test_build_idempotency.sh` | Mock registry, retry push |
| EC-Cache-1 | Stale Tutor cache with --no-cache produces correct build | integration | `tests/workflows/test_tutor_no_cache.sh` | Mock stale cache, trigger build |
| EC-GitOps-1 | GitOps PAT expired fails before git operations with clear error | unit | `tests/workflows/test_gitops_pat_expired.sh` | Mock expired PAT |
| EC-GitOps-2 | bbi-infrastructure merge conflict fails push(no force push) | integration | `tests/workflows/test_gitops_conflict.sh` | Mock concurrent change in GitOps repo |
| EC-GitOps-3 | Digest mismatch (build vs registry) fails release script | integration | `tests/workflows/test_digest_mismatch.sh` | Mock mismatched digests |
| EC-GitOps-4 | Partial build success (openedx builds, MFE fails) prevents GitOps update | integration | `tests/workflows/test_partial_build_blocks_gitops.sh` | Mock MFE build failure|
| EC-Schedule-1 | GKE auth failure in scheduled workflow (strict=false) skips checks with warnings | integration | `tests/workflows/test_schedule_auth_failure_soft.sh` | Mock GKE authfailure |
| EC-Schedule-2 | GKE auth failure in scheduled workflow (strict=true) fails workflow | integration | `tests/workflows/test_schedule_auth_failure_strict.sh` | Mock GKE auth failure |
| EC-Rate-1 | GitHub API rate limit hit during scheduled workflow fails gracefully | integration | `tests/workflows/test_rate_limit_graceful.sh` | Mock API rate limit response |
| EC-Retry-1 | Failed workflow manual re-run succeeds | integration | `tests/workflows/test_workflow_retry.sh` | GitHub API, re-run workflow |

---

## Test Execution Strategy

### Unit Tests
- Run with `bash tests/workflows/test_*.sh` or `pytest tests/workflows/`
- Mock all external dependencies (GitHub API, Docker registry, GKE)
- Fast execution (<10 minutes for full unit suite)
- Parse workflow YAML files to verify structure and logic

### Integration Tests
- Use `act` (nektos/act) to run workflows locally with Docker
- Use mock registries (local Docker registry) and mock GitOpsrepo
- Execution time: 30-60 minutes for full integration suite
- Require Docker and Kind cluster

### E2E Tests
- Trigger workflows via GitHub API or `gh workflow run`
- Use test GCP project and test Artifact Registry
- Use test GitOps repository (not bbi-infrastructure)
- Execution time: 60-120 minutes for full E2E suite
- Run nightly in CI

### Manual Tests
- Verify branch protection rules in GitHub UI
- Trigger manual dispatch workflows (release evidence, policychecks)
- Verify notifications received (Slack webhook, email)
- Check cost reports (GitHub Actions usage)

---

## Test Data Requirements

### Fixtures
- Valid and invalid spec files (for spec-lint tests)
- Python files with lint violations (for lint tests)
- Invalid Kubernetes manifests (for validate-k8s tests)
- Files with hardcoded secrets (for security-scan tests)
- Kustomize overlays with `:latest` tags (for prod-tag-guardtests)
- MFE build outputs with/without branding markers (for branding tests)

### Test Secrets
- Test GCP service account key (for GKE auth tests)
- Test GitHub PAT (for GitOps tests)
- Test Artifact Registry credentials (for image push tests)
- Test Slack webhook URL (for notification tests)

### Mock Services
- Mock Docker registry (for image push/pull tests)
- Mock Artifact Registry (for digest resolution tests)
- Mock GitOps repository (for GitOps update tests)
- Mock GitHub API (for workflow trigger and status tests)
- Mock GKE API (for operations gate tests)

---

## Negative Test Cases

| Negative Scenario | Test Case | Type | File |
|-------------------|-----------|------|------|
| Invalid spec structure | Spec with missing frontmatter fails spec-lint | unit | `tests/workflows/test_spec_lint_invalid.sh` |
| Python lint violation | Ruff violation fails lint job | unit | `tests/workflows/test_lint_python_fail.sh` |
| Invalid K8s manifest | Kubeconform validation fails | unit| `tests/workflows/test_validate_k8s_fail.sh` |
| Hardcoded secret detected | TruffleHog fails security-scan| integration | `tests/workflows/test_secret_detected.sh` |
| Production :latest tag | Prod-tag-guard blocks merge | unit| `tests/workflows/test_prod_latest_blocked.sh` |
| GitOps without digests | GitOps update fails without both builds | unit | `tests/workflows/test_gitops_no_digests.sh` |
| Expired GitOps PAT | GitOps update fails with clear error |unit | `tests/workflows/test_gitops_pat_invalid.sh` |
| Build OOM | OpenEdX build fails with memory error | integration | `tests/workflows/test_build_oom.sh` |
| Network push failure | Docker push fails, no partial push |integration | `tests/workflows/test_push_network_fail.sh` |
| Staging gated | Staging deployment fails without flag | unit | `tests/workflows/test_staging_blocked.sh` |
| GKE auth failure (strict) | Scheduled workflow fails on auth error | integration | `tests/workflows/test_gke_auth_fail_strict.sh` |
| API rate limit | Scheduled workflow handles rate limit | integration | `tests/workflows/test_api_rate_limit.sh` |

---

## Performance Test Cases

| Performance Requirement | Test Case | Type | File | Target|
|------------------------|-----------|------|------|--------|
| CI job completion time | Measure individual CI job duration| integration | `tests/workflows/test_ci_job_duration.sh` |<10min per job |
| Full CI workflow completion | Measure parallel CI workflowduration | integration | `tests/workflows/test_ci_total_duration.sh` | <15min total |
| OpenEdX build time | Measure openedx image build duration |integration | `tests/workflows/test_openedx_build_time.sh` |<45min |
| MFE build time | Measure MFE image build duration | integration | `tests/workflows/test_mfe_build_time.sh` | <20min |
| iOS build time | Measure iOS build duration | e2e | `tests/workflows/test_ios_build_time.sh` | <90min (enforced timeout)|
| GitOps update time | Measure GitOps update (excluding build) | integration | `tests/workflows/test_gitops_update_time.sh` | <5min |

---

## Observability Verification

| Metric/Log/Alert | Verification Test | Type | File |
|------------------|-------------------|------|------|
| Workflow step summary generated | Verify markdown in $GITHUB_STEP_SUMMARY | integration | `tests/workflows/test_step_summary.sh` |
| Build logs contain image tags and digests | Parse build joblogs | integration | `tests/workflows/test_build_logs.sh` |
| GitOps logs contain commit SHA and environment | Parse GitOps job logs | integration | `tests/workflows/test_gitops_logs.sh` |
| Artifacts uploaded with correct retention | Query GitHub API for artifacts | integration | `tests/workflows/test_artifact_retention.sh` |
| Failed steps include stderr in output | Trigger failure, parse step output | integration | `tests/workflows/test_failure_logs.sh` |
| Health check failure triggers notification | Intentional failure, verify Slack message | e2e | `tests/workflows/test_health_check_alert.sh` |

---

## CI/CD Integration

### Pre-merge (Pull Request)
- Run unit tests: `bash tests/workflows/test_*.sh`
- Run workflow contract validation: `pytest tests/workflows/`
- Validate workflow syntax: `scripts/qa/validate-workflow-syntax.sh`

### Post-merge (Main Branch)
- Run integration tests: `act --workflows .github/workflows/ci.yml`
- Verify branch protection enforcement
- Check workflow success metrics

### Nightly
- Run E2E tests with live GitHub API
- Trigger all workflows via `gh workflow run`
- Verify artifacts, logs, notifications
- Check cost reports

---

## Test Environment Setup

### Local Development
- Install `act` (nektos/act) for local workflow execution
- Docker Desktop or Podman for container operations
- Kind cluster for K8s manifest testing
- Mock Docker registry: `docker run -d -p 5000:5000 registry:2`

### CI Environment (GitHub Actions)
- Use GitHub-hosted runners (ubuntu-latest, macos-latest)
- Test GCP project for Artifact Registry
- Test GitHub repository for GitOps operations
- Test Slack webhook for notifications

### Test Secrets (GitHub Secrets)
- `TEST_GCP_SA_KEY`: Service account key for test project
- `TEST_GITOPS_PAT`: Personal access token for test GitOps repo
- `TEST_SLACK_WEBHOOK`: Webhook URL for test Slack channel
- `TEST_INFISICAL_TOKEN`: Infisical token for secret validation tests

---

## Success Criteria

- [ ] All 28 acceptance criteria have at least one passing test case
- [ ] All 14 edge cases have negative test coverage
- [ ] All performance tests meet targets (CI <15min, build <45min)
- [ ] Workflow contract tests validate all 11 workflows
- [ ] Security tests confirm secret masking and pre-commit hook work
- [ ] Observability tests verify metrics, logs, alerts function
- [ ] Rollback test confirms <10min rollback time
- [ ] Integration tests run via `act` locally without errors
- [ ] E2E tests run nightly via GitHub Actions successfully
- [ ] Cost analysis tests track GitHub Actions quota usage

---

## Test Ownership

- **Unit Tests**: DevOps engineers implementing workflow changes
- **Integration Tests**: DevOps engineers + QA engineers
- **E2E Tests**: QA engineers + Release engineers
- **Performance Tests**: DevOps engineers + SRE
- **Security Tests**: Security engineers
- **Observability Tests**: SRE/DevOps engineers

---

## Rollback Test Cases

| Rollback Scenario | Test Case | Type | File |
|-------------------|-----------|------|------|
| Rollback to prior production release | Execute rollback procedure from docs | e2e | `tests/workflows/test_production_rollback.sh` |
| Rollback uses prior tags, no new build | Verify no build triggered on rollback | integration | `tests/workflows/test_rollback_no_rebuild.sh` |
| Rollback completes within 10 minutes | Measure rollback time end-to-end | e2e | `tests/workflows/test_rollback_time.sh`|
| Workflow YAML revert | Revert workflow change, verify updated workflow used | integration | `tests/workflows/test_workflow_revert.sh` |

---

## Open Questions for Testing

1. **Mock vs live GitHub API**: Use `act` for local testing or trigger live workflows? Trade-off: speed vs realism.
2. **Test Artifact Registry**: Use local Docker registry or test GCP project? Trade-off: cost vs production parity.
3. **Notification testing**: Mock Slack webhook or send to test channel? Trade-off: isolation vs verification.
4. **Cost tracking**: How to automate GitHub Actions quota monitoring? Options: GitHub API, billing alerts, manual checks.
5. **Self-hosted runner testing**: If self-hosted runner added, how to test runner-specific behavior?

---

**Source Spec**: `specs/ci-cd-pipeline_spec.md`
