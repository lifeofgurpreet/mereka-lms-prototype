# Post-Deploy Smoke Matrix and Incident Playbook

> **Beads**: mereka-lms-36va.3, mereka-lms-36va.3.1, mereka-lms-36va.4
> **Date**: 2026-02-18
> **Cluster**: gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster

## 1. Enterprise and Ecommerce Service Inventory (AC-OPS-131..135)

### Service Status Map

| Service | Status | GKE | Kind | Port | Health Endpoint |
|---------|--------|-----|------|------|----------------|
| **enterprise-catalog** | Active | Running | Scaled to 0 | 8160 | `/health/` |
| **enterprise-catalog-worker** | Active | Running | Scaled to 0 | — | — |
| **enterprise-subsidy** | Active | Running | Scaled to 0 | 18280 | `/health/` |
| **enterprise-access** | Active | Running | Scaled to 0 | 18270 | `/health/` |
| **enterprise-access-worker** | Active | Running | Scaled to 0 | — | — |
| **enterprise-admin-portal** | Active | Running | Scaled to 0 | 80 | `/` |
| **enterprise-learner-portal** | Active | Running | Scaled to 0 | 80 | `/` |
| **ecommerce** (legacy Oscar) | Deprecated | Running | Running | 8000 | `/health/` |
| **ecommerce-worker** | Deprecated | Running | Running | — | — |
| **payments-gateway** (new) | Dark launch | Running | Scaled to 0 | 8000 | `/health` |
| **license-manager** | Active | Running | — | 8000 | `/health/` |

### Commerce Integration Status (AC-OPS-132)

| Path | Status | Notes |
|------|--------|-------|
| Legacy Oscar ecommerce | **Deprecated** — running for backward compat | Will be removed when Purchase Gateway goes live |
| Purchase Gateway (Stripe) | **Dark launch** (`ENABLE_GATEWAY_FULFILLMENT=false`) | Activate: set real Stripe keys + `=true` |
| Enterprise subsidy | **Active** | Manages learner subsidies, no Celery worker |
| Enterprise catalog | **Active** | Course discovery for enterprise, has Celery worker |
| Enterprise access | **Active** | Policy engine for enterprise learners, has Celery worker |

### Startup Guard (AC-OPS-133)

Legacy ecommerce paths are controlled by:
- `ENABLE_ECOMMERCE` feature flag in LMS settings
- Ecommerce service deployment (can be scaled to 0)
- Caddy routing: ecommerce routes exist in Caddyfile only when service is deployed

When Purchase Gateway replaces ecommerce:
1. Set `ENABLE_GATEWAY_FULFILLMENT=true` in GCP SM
2. Scale ecommerce + ecommerce-worker to 0
3. Remove ecommerce Caddy routes
4. Verify no LMS code paths depend on `ECOMMERCE_SERVICE_URL`

## 2. Post-Deploy Health Matrix (AC-OPS-071, AC-OPS-090)

### Route-Level Checks

| Route | URL (GKE) | URL (Kind) | Expected | Check Command |
|-------|-----------|-----------|----------|---------------|
| LMS home | `https://academyv2.mereka.io` | `http://localhost` | 200 | `curl -sI URL \| head -1` |
| LMS login | `https://academyv2.mereka.io/login` | `http://localhost/login` | 200/302 | `curl -sI URL \| head -1` |
| OIDC redirect | `https://academyv2.mereka.io/auth/login/oidc/` | N/A | 302 → auth0 | `curl -sI URL \| grep Location` |
| Studio | `https://studio.academyv2.mereka.io` | `http://studio.localhost` | 200/302 | `curl -sI URL \| head -1` |
| MFE root | `https://apps.academyv2.mereka.io` | `http://apps.localhost` | 200 | `curl -sI URL \| head -1` |
| MFE config | `https://apps.academyv2.mereka.io/api/mfe_config/v1` | — | 200 JSON | `curl -s URL \| python3 -m json.tool \| head -3` |
| Forum | `https://academyv2.mereka.io/api/discussion/` | — | 200 | `curl -sI URL \| head -1` |
| Ecommerce | `https://ecommerce.academyv2.mereka.io/health/` | — | 200 | `curl -sI URL \| head -1` |
| Credentials | `https://credentials.academyv2.mereka.io/health` | — | 200 | `curl -sI URL \| head -1` |
| Notes | `https://notes.academyv2.mereka.io/heartbeat` | — | 200 | `curl -sI URL \| head -1` |
| Discovery | `https://discovery.academyv2.mereka.io/health/` | — | 200 | `curl -sI URL \| head -1` |
| Alt domain | `https://academy.biji-biji.com` | N/A | 200 | `curl -sI URL \| head -1` |

### Sample Outputs (AC-OPS-091)

**PASS**:
```
$ curl -sI https://academyv2.mereka.io | head -1
HTTP/2 200
```

**WARN** (slow but working):
```
$ curl -sI --max-time 10 https://academyv2.mereka.io | head -1
HTTP/2 200   # took >5s
```

**FAIL**:
```
$ curl -sI https://academyv2.mereka.io | head -1
HTTP/2 502
```

## 3. Incident Playbook — Failed Rollout Under 15 Minutes (AC-OPS-072, AC-OPS-092)

### Minute 0-2: Detect

```bash
CTX="gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster"
NS="mereka-lms"

# Quick health
curl -sI https://academyv2.mereka.io | head -1
kubectl --context $CTX get pods -n $NS | grep -vE "Running|Completed"
kubectl --context $CTX get endpoints -n $NS caddy
```

### Minute 2-5: Classify

| Symptom | Classification | Next Step |
|---------|---------------|-----------|
| All pods Running but 502 | Routing/ingress issue | Check endpoints + Caddy |
| Pods CrashLoopBackOff | Config/code issue | Check logs → revert |
| Pods Pending | Resource/scheduling | Check node capacity |
| ImagePullBackOff | Registry/auth issue | Re-auth docker + check tag |
| ArgoCD OutOfSync | Git ref mismatch | Check base ref SHA |

### Minute 5-10: Fix or Revert

**Option A: Quick fix** (config issue identified):
```bash
# Fix the config and push
vim deploy/k8s/...
git add . && git commit -m "fix: <issue>" && git push
# ArgoCD auto-syncs in ~2 min
```

**Option B: Revert** (unknown issue):
```bash
# Revert last release commit in both repos
git -C /home/gurpreet/projects/k8s/mereka-lms revert HEAD && git push
git -C /home/gurpreet/projects/k8s/infrastructure revert HEAD && git push
# ArgoCD auto-syncs to previous state in ~2 min
```

### Minute 10-15: Verify Recovery

```bash
# Wait for pods to stabilize
kubectl --context $CTX rollout status deployment/lms -n $NS --timeout=120s
kubectl --context $CTX rollout status deployment/cms -n $NS --timeout=120s
kubectl --context $CTX rollout status deployment/mfe -n $NS --timeout=120s

# Verify routes
curl -sI https://academyv2.mereka.io | head -1
curl -sI https://studio.academyv2.mereka.io | head -1
curl -sI https://apps.academyv2.mereka.io | head -1
```

## 4. Failure Mode → Runbook Mapping (AC-OPS-092)

| Failure Mode | Runbook | Rollback Action |
|-------------|---------|-----------------|
| Site down (502/503) | `ops/runbooks/site-down.md` | Revert git + check endpoints |
| CMS OOM | `docs/evidence/operations/KIND_CLUSTER_RECOVERY_EVIDENCE.md` | Increase memory limit |
| Auth loop | `ops/runbooks/AUTH_SSO_RUNBOOK.md` | Check SESSION_COOKIE_* settings |
| DB connection refused | `ops/runbooks/database-issues.md` | Check MySQL pod + secrets |
| MFE blank page | `FRONTEND_REGRESSION_CHECKLIST.md` | Check MFE image tag + config API |
| Enterprise 403 | `docs/ops/runbooks/ENTERPRISE_SERVICES_RUNBOOK.md` | Check image pull + service account |
| XQueue backlog | `ops/runbooks/XQUEUE_HEALTH_RUNBOOK.md` | Check consumer logs |
| SSL cert expired | `ops/runbooks/DOMAIN_CHANGE_RUNBOOK.md` | Check cert-manager + Cloudflare |
| Meilisearch denied | `docs/evidence/operations/KIND_CLUSTER_RECOVERY_EVIDENCE.md` | Add `runAsNonRoot: true` |

## 5. Owner Signoff Template (AC-OPS-073)

```markdown
## Release Signoff: [TAG]

| Check | Result | Signed |
|-------|--------|--------|
| Preflight (`--check-only`) | PASS/FAIL | [ ] |
| Dry-run (`--dry-run`) | PASS/FAIL | [ ] |
| Build completed | PASS/SKIP (cache) | [ ] |
| Images pushed to AR | PASS/FAIL | [ ] |
| GitOps updated (both repos) | PASS/FAIL | [ ] |
| ArgoCD synced | PASS/FAIL | [ ] |
| Route health (LMS/CMS/MFE) | PASS/FAIL | [ ] |
| Auth flow verified | PASS/FAIL | [ ] |
| Branding verified | PASS/FAIL | [ ] |

**Signed by**: _______________
**Date**: _______________
```

## 6. Evidence Retention (AC-OPS-093)

| Artifact | Retention | Location |
|----------|-----------|----------|
| Release PR | Permanent | GitHub PRs |
| Dry-run logs | 30 days | `var/release-logs/` (gitignored) |
| Incident reports | Permanent | `docs/archive/evidence/operations/` |
| Pod status snapshots | 30 days | PR comments |
| ArgoCD sync status | 7 days | ArgoCD UI history |

## Related

- `docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md` — Build/tag/push flow
- `docs/ops/runbooks/RELEASE_EXECUTE_RUNBOOK.md` — Step-by-step release
- `docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md` — Parity proof commands
- `docs/reference/operations/ECOMMERCE_DEPRECATION_INVENTORY.md` — Legacy ecommerce removal
- `docs/ops/runbooks/ENTERPRISE_SERVICES_RUNBOOK.md` — Enterprise service operations
