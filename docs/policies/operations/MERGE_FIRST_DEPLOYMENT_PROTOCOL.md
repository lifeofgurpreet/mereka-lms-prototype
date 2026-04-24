# Merge-First Deployment Protocol

**Status**: Active
**Last Updated**: 2026-04-21

## Protocol

All changes MUST be merged to `main` via Pull Request before deployment to production. No direct `kubectl apply`, `kubectl patch`, or ArgoCD manual sync from feature branches.

### Why

1. **ArgoCD reverts manual patches**: The GitOps controller syncs from the `infrastructure` repo. Any `kubectl patch` or direct edit gets overwritten on next sync cycle.
2. **Worktree divergence**: Multiple agents working on separate worktrees/branches can produce conflicting changes. Merging to main first ensures a single source of truth.
3. **Audit trail**: PRs provide code review, CI checks, and a permanent record of what changed and why.

## Full Deployment Sequence (AC-MD-001)

The canonical sequence for enterprise UI/branding changes:

```
┌─────────────────────────────────────────────────────────────┐
│  1. ./scripts/infra/tutor-config-save.sh --set KEY=value    │
│  2. ./scripts/infra/verify-tutor-config.sh                  │
│  3. Optional local helper build for parity/debug            │
│  4. git add -> commit -> push -> PR -> merge to main        │
│  5. Build Tutor Images publishes release tags/digests       │
│  6. release-openedx-gitops.sh promotes exact digests        │
│  7. ArgoCD realizes the GitOps change                       │
│  8. ./scripts/qa/verify-post-deploy-smoke.sh --env prod     │
│  9. ./scripts/qa/ops-confidence.sh --env prod               │
└─────────────────────────────────────────────────────────────┘
```

### Step-by-step commands

```bash
# 1. Config save (with safe wrapper)
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set KEY=value

# 2. Verify rendered state
./scripts/infra/verify-tutor-config.sh

# 3. Optional local parity/debug build
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast   # ~30 min
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast       # ~15 min

# 4. PR workflow
git checkout -b feat/<bead-id>-<slug>
git add -A && git commit -m "feat: ..."
git push -u origin feat/<bead-id>-<slug>
gh pr create --title "..." --body "..."
gh pr merge --merge --delete-branch

# 5. Production publish: use the Build Tutor Images workflow result from main.
# 6. Promote exact workflow-emitted tags/digests:
./scripts/infra/release-openedx-gitops.sh \
  --openedx-tag <OPENEDX_TAG> \
  --mfe-tag <MFE_TAG> \
  --openedx-digest sha256:<OPENEDX_DIGEST> \
  --mfe-digest sha256:<MFE_DIGEST> \
  --require-digests --apply --commit --push --verify-runtime

# 7. Wait for ArgoCD sync (~3 min)

# 8-9. Verify
./scripts/qa/verify-post-deploy-smoke.sh --env prod
./scripts/qa/ops-confidence.sh --env prod --evidence-dir var/evidence/release-$(date +%Y%m%d)
```

### Config-only changes (no image rebuild)

For changes that only affect K8s manifests, ConfigMaps, or secrets:

```bash
# Edit files, commit, merge to main
# ArgoCD auto-syncs — no image build needed
# Verify:
./scripts/qa/verify-gitops-drift.sh
./scripts/qa/verify-post-deploy-smoke.sh --env prod
```

## Pre-Deploy Gate (AC-MD-002)

Before any build or deploy, run the worktree freshness check:

```bash
# Prevents builds from stale worktrees
./scripts/infra/check-worktree-freshness.sh --max-behind 5
```

This checks:
- Current branch is `main` (or a recent feature branch)
- No more than 5 commits behind `origin/main`
- No parallel worktrees on `main` (prevents conflicting edits)
- No uncommitted changes in `deploy/`, `infrastructure/`, or `scripts/`

**Gate enforcement**: This script exits non-zero if stale. Image build scripts SHOULD call it as a pre-condition.

### Anti-Patterns

| Anti-Pattern | Why It Fails | Correct Approach |
|-------------|-------------|------------------|
| `kubectl patch` on live cluster | ArgoCD reverts within sync interval | Commit to `infrastructure`, let ArgoCD apply |
| Deploy from feature branch | Other agents may overwrite | Merge to main first, deploy from main |
| Cherry-pick to main without PR | No CI, no review trail | Create PR even for single-commit changes |
| Direct `tutor config save` on cluster | Leaves rendered build context stale and bypasses the canonical prepare flow | Use `tutor-config-save.sh` wrapper locally, commit result |
| Amend published commits | Destroys history, breaks other agents | Create new commit instead |
| Build from stale worktree | Image won't match main | Run `check-worktree-freshness.sh` first |

## Deployment Coordination Matrix (AC-MD-003)

| Role | Owns | Hands off to | Verification |
|------|------|-------------|--------------|
| **Ticket owner** | Bead assignment, AC implementation | Builder after code complete | `br show <id>` — all ACs checked |
| **Builder** | Image build, push to registry | Deployer after push | `docker images` shows new tag |
| **Deployer** | GitOps overlay update, PR, merge | Verifier after ArgoCD sync | `kubectl get pods` — new image running |
| **Verifier** | Post-deploy smoke, evidence capture | Ticket owner for closure | `ops-confidence.sh` → PASS |

### Handoff checkpoints

```
Ticket Owner → Builder:
  "Code complete on main at HEAD=<sha>. Ready for image build."

Builder → Deployer:
  "Images pushed: openedx:<tag> mfe:<tag>. Update overlay."

Deployer → Verifier:
  "PR merged. ArgoCD sync confirmed. Pods rolling."

Verifier → Ticket Owner:
  "Smoke passed. Evidence at var/evidence/release-<date>/. Close bead."
```

### Single-person workflow

When one person handles all roles:

```bash
# All-in-one: local parity -> PR -> workflow publish -> GitOps promote -> verify
./scripts/infra/check-worktree-freshness.sh    # pre-gate
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
# Merge the PR, wait for Build Tutor Images on main, then promote the exact workflow digests.
./scripts/qa/ops-confidence.sh --env prod --evidence-dir var/evidence/release-$(date +%Y%m%d)
```

## Multi-Agent Coordination

When multiple agents work in parallel:

1. **Single canonical worktree**: All agents use the `mereka-lms` repo root on `main`
2. **Feature branches**: Create short-lived branches (`feat/<bead-id>-<slug>`)
3. **File reservations**: Use Agent Mail `file_reservation_paths` before editing shared files
4. **Sequential merges**: Only one PR merged at a time to avoid conflicts
5. **Checkpoint format**: `CHECKPOINT: path=<pwd> | branch=<branch> | HEAD=<sha> | step=<next>`

### Stale Branch Policy

- Feature branches MUST be deleted after PR merge (use `--delete-branch` flag)
- Local branches merged to main SHOULD be pruned weekly
- Worktrees not updated in 7+ days SHOULD be removed
- Run `scripts/infra/cleanup-stale-branches.sh` to automate

## Fast-Path Incident Triage (AC-MD-004)

When a build, push, or rollout is blocked:

### Build blocked

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| OOM during webpack | Docker < 12GB RAM | Increase Docker memory to 12GB+ |
| `pip install` timeout | Network/PyPI outage | Re-run `prepare-tutor-build-context.sh --target all`, then rebuild |
| `SuspiciousFileOperation` | Missing rendered safe_join patch | Re-run `prepare-tutor-build-context.sh --target openedx` |
| MFE build contract drift | Rendered MFE Dockerfile or tracked snapshot is stale | Re-run `prepare-tutor-build-context.sh --target all` |
| `loremipsum` build failure | `uv pip` missing `pkg_resources` | Build with `-a PIP_COMMAND=pip` |

### Push blocked

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `denied: Permission` | Missing IAM role | `gcloud auth configure-docker asia-southeast1-docker.pkg.dev` |
| `MANIFEST_INVALID` | Image not built for target platform | Build with `--platform linux/amd64` |
| Timeout | Large image (>4GB) | Retry; check network bandwidth |

### Rollout blocked

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Pods `ImagePullBackOff` | Wrong image tag or registry auth | Check `kustomization.yaml` tag matches pushed image |
| Pods `CrashLoopBackOff` | Settings bug in production.py | Check logs: `kubectl logs -n mereka-lms deploy/lms --tail=50` |
| ArgoCD `OutOfSync` | Merge not on tracked branch | Verify PR merged to `main`, not a feature branch |
| ArgoCD `Degraded` | Health check failing | Check liveness probe path; use `/heartbeat` for LMS, `/health/` for enterprise services |

### Escalation

If blocked for >15 minutes:
1. Post in Agent Mail with `importance: urgent`
2. Include: symptom, logs (last 20 lines), attempted fixes
3. Tag platform team lead

## Same-Worktree Evidence Commands (AC-MD-005)

Before any image rebuild, run these commands and capture output as evidence
that the build environment matches the canonical worktree:

```bash
# 1. Worktree freshness (must pass)
./scripts/infra/check-worktree-freshness.sh --max-behind 5

# 2. Pre-flight environment check
./scripts/qa/ops-preflight.sh

# 3. Git state evidence
git log --oneline -5
git diff --stat HEAD
git remote -v
echo "HEAD=$(git rev-parse HEAD)"
echo "BRANCH=$(git branch --show-current)"
echo "WORKTREE=$(git rev-parse --show-toplevel)"

# 4. Image build evidence (capture after build)
docker images --format '{{.Repository}}:{{.Tag}} {{.Size}} {{.CreatedAt}}' | grep openedx
```

### Evidence capture script

```bash
# One-command evidence capture before build
{
  echo "=== Worktree Evidence ==="
  echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "HEAD: $(git rev-parse HEAD)"
  echo "Branch: $(git branch --show-current)"
  echo "Worktree: $(git rev-parse --show-toplevel)"
  echo ""
  echo "=== Freshness Check ==="
  ./scripts/infra/check-worktree-freshness.sh --max-behind 5 2>&1
  echo ""
  echo "=== Pre-Flight ==="
  ./scripts/qa/ops-preflight.sh 2>&1
} > var/evidence/release-$(date +%Y%m%d)/pre-build-evidence.log 2>&1
```

## Related

- `docs/ops/runbooks/BRANDING_RELEASE_RUNBOOK.md` — Production rollout steps
- `docs/ops/runbooks/TENANT_ONBOARDING_PLAYBOOK.md` — Tenant onboarding with pre-deploy checklist
- `scripts/infra/check-worktree-freshness.sh` — Pre-build stale worktree gate
- `scripts/qa/ops-preflight.sh` — Environment pre-flight check
- `scripts/qa/ops-confidence.sh` — Post-deploy confidence bundle
- `scripts/qa/verify-gitops-drift.sh` — Detect drift between source and GitOps overlay
- `AGENTS.md` — Repository agent guidelines
