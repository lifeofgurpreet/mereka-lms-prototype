# Deployment Verification Framework

<!-- Last verified: 2026-02-13 -->

## Overview

Every K8s deployment now has **automated verification** to catch issues before they become outages.

## Architecture

### 1. Hook (Automatic)
**File**: your local post-deploy hook script (for example `~/.claude/hooks/post_k8s_deploy.py`)

**Triggers**: Automatically after any `kubectl apply` or `kustomize` command

**What it does**:
- Detects K8s deployment commands
- Runs verification script
- Reports issues but doesn't block deployment

### 2. Verification Script
**File**: `scripts/infra/verify-deployment.sh`

**Checks**:
- ✅ Pod status (no CreateContainerConfigError, CrashLoopBackOff)
- ✅ Deployment readiness (all replicas ready)
- ✅ Recent logs (no errors/exceptions)
- ✅ Secret existence (required keys present)
- ✅ Endpoint health (HTTP 200/302)

**Usage**:
```bash
./scripts/infra/verify-deployment.sh [namespace]

# Default namespace: mereka-lms
./scripts/infra/verify-deployment.sh

# Other namespace
./scripts/infra/verify-deployment.sh reka-slackbot
```

### 3. Updated Skills

**k8s-operations**: Mereka LMS deployments
- Added mandatory verification step
- Documents hook behavior
- Clear workflow: apply → rollout → verify

**reka-slackbot-deployment**: Reka Slackbot deployments
- Added step 8: Post-Deployment Verification
- Pod checks, log checks, endpoint checks

## Workflow

### Manual Deployment
```bash
# 1. Apply changes
kubectl apply -k deploy/k8s/overlays/production/

# 2. Check rollout
kubectl rollout status deployment/lms -n mereka-lms

# 3. Verify (automatic via hook, or manual)
./scripts/infra/verify-deployment.sh mereka-lms
```

### Automatic (via Hook)
```bash
# Just run kubectl apply - hook handles verification
kubectl apply -k deploy/k8s/overlays/production/

# Hook output will show:
# 🔍 Running post-deployment verification for namespace: mereka-lms
# ==> Checking pod status...
# ✓ All pods running
# ==> Checking deployments...
# ✓ All deployments ready
# ...
```

## Verification Checklist

**Passing criteria**:
- [ ] All pods in `Running` or `Succeeded` state
- [ ] All deployments show `READY` replicas = `DESIRED` replicas
- [ ] No errors in recent logs (last 5 minutes)
- [ ] Required secrets exist (`openedx-secrets`, etc.)
- [ ] Endpoints respond with HTTP 200 or 302

**Failing indicators**:
- ❌ Pods in `CreateContainerConfigError`, `CrashLoopBackOff`, `Error`
- ❌ Deployments show `0/1` or `1/2` ready
- ❌ Errors/exceptions in logs
- ❌ Missing secrets
- ❌ Endpoints return HTTP 500, 503, 000 (timeout)

## Hook Configuration

**Location**: your local agent settings file (for example `~/.claude/settings.json`)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/post_k8s_deploy.py"
          }
        ]
      }
    ]
  }
}
```

## Troubleshooting

### Hook not running
```bash
# Check hook exists and is executable
ls -l ~/.claude/hooks/post_k8s_deploy.py
chmod +x ~/.claude/hooks/post_k8s_deploy.py

# Check settings.json has hook configured
grep -A 10 "PostToolUse" ~/.claude/settings.json
```

### Verification script not found
```bash
# Check script exists in repo
ls -l scripts/infra/verify-deployment.sh

# Make sure you're in repo root
cd <repo-root>
```

### False positives

- CronJob pods in `Error` or `Failed` state are expected (they run periodically)
- Use `--field-selector=status.phase!=Running,status.phase!=Succeeded` to filter

## Related Documentation

- Local agent hook configuration (if you use automatic post-tool verification)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
