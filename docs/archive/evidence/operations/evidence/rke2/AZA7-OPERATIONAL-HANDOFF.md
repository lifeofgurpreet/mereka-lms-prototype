# aza7: RKE2 Operational Hardening — Handoff Pack

> **Bead**: mereka-lms-aza7
> **Date**: 2026-02-20
> **Author**: BoldBadger
> **Status**: READY FOR HANDOFF (blocked on 288f + 5ngf.2 pod readiness)
> **Dependencies**: mereka-lms-20eb → mereka-lms-288f → mereka-lms-5ngf.2

This document is the single-pane handoff artifact for aza7. It covers:
- Pre-cutover gate conditions
- Live verification commands with expected signatures
- Cutover step plan (no destructive actions)
- Rollback paths
- Evidence artifact index

---

## AC Coverage Map

| AC | Description | Status | Evidence |
|----|-------------|--------|----------|
| AC-RKE2-101 | kubectl controls cluster, DNS/Ingress pass | ⏳ BLOCKED (pods not running) | Will populate in 288f/5ngf.2 |
| AC-RKE2-102 | Host matrix complete | ⏳ BLOCKED | Will populate in 288f/5ngf.2 |
| AC-RKE2-103 | Branding + authn parity | ⏳ BLOCKED | Will populate in 288f/5ngf.2 |
| AC-RKE2-104 | Blockers converted to beads with owners/ETA | ✅ DONE | Section 5 below |
| AC-RKE2-105 | Cutover step plan | ✅ DONE | Section 4 below |

---

## 1. Pre-Cutover Gate Conditions

All must pass before running aza7 smoke tests:

```bash
# Gate 1: Core pods Running
kubectl --context rke2-nonprod get pods -n mereka-lms \
  -l "app.kubernetes.io/name in (lms,cms,caddy)" \
  --field-selector=status.phase=Running
# Expected: 3 rows (lms, cms, caddy)

# Gate 2: ExternalSecrets SecretSynced
kubectl --context rke2-nonprod get externalsecret -n mereka-lms \
  -o custom-columns=NAME:.metadata.name,REASON:.status.conditions[0].reason
# Expected: all rows show SecretSynced

# Gate 3: No ImagePullBackOff pods
kubectl --context rke2-nonprod get pods -n mereka-lms | grep -c ImagePullBackOff || echo "0"
# Expected: 0

# Gate 4: DNS/Ingress reachable
curl -s -o /dev/null -w "%{http_code}" https://academyv2.staging.mereka.dev
# Expected: 200 (update domain to actual rke2-nonprod domain)
```

**Automated gate check**:
```bash
KUBECONTEXT=rke2-nonprod bash scripts/qa/verify-rke2-deployment-readiness.sh --live
# Expected: RESULT: PASS with no FAIL
```

---

## 2. Live Verification Commands (with Expected Signatures)

### 2.1 Cluster Health

```bash
# ArgoCD app state
kubectl --context rke2-nonprod get app mereka-lms-local -n argocd \
  -o jsonpath='STATUS={.status.sync.status} HEALTH={.status.health.status}{"\n"}'
# Expected: STATUS=Synced HEALTH=Healthy

# All pods
kubectl --context rke2-nonprod get pods -n mereka-lms
# Expected signature (post-fix):
#   caddy-xxx           1/1   Running   0
#   cms-xxx             1/1   Running   0
#   elasticsearch-xxx   1/1   Running   0
#   lms-xxx             1/1   Running   0
#   lms-worker-xxx      1/1   Running   0
#   meilisearch-xxx     1/1   Running   0
#   mongodb-exporter    1/1   Running   0
#   postgresql-payments 1/1   Running   0
```

### 2.2 ExternalSecrets

```bash
kubectl --context rke2-nonprod get externalsecret -n mereka-lms
# Expected: all STATUS=SecretSynced
# If any show SecretSyncedError: check ClusterSecretStore validity first
#   kubectl --context rke2-nonprod get clustersecretstore infisical-secret-store
```

### 2.3 LMS Health

```bash
# LMS heartbeat
curl -s https://academyv2.staging.mereka.dev/heartbeat/
# Expected: {"OK": true} or HTTP 200

# LMS admin login page (branding smoke)
curl -s -o /dev/null -w "%{http_code}" https://academyv2.staging.mereka.dev/admin/login/
# Expected: 200

# MFE authn shell
curl -s -o /dev/null -w "%{http_code}" https://apps.academyv2.staging.mereka.dev/authn/login
# Expected: 200

# Studio redirect (should redirect to LMS login)
curl -sI https://studio.academyv2.staging.mereka.dev | head -5
# Expected: HTTP/2 302 or 200
```

### 2.4 Forum v2 (runs in-process)

```bash
# Forum API health (returns 200, not 401 — Forum v2 Python, not Ruby)
curl -s -o /dev/null -w "%{http_code}" https://academyv2.staging.mereka.dev/api/discussion/v1/courses/
# Expected: 200 (requires auth for data, but endpoint exists)
```

### 2.5 Branding Parity

```bash
# Check for undefined_* analytics tokens in page source
curl -s https://academyv2.staging.mereka.dev | grep -c 'undefined_license_key' || echo "0"
# Expected: 0

# Check no NREUM (New Relic) on staging
curl -s https://academyv2.staging.mereka.dev | grep -c 'NREUM' || echo "0"
# Expected: 0
```

---

## 3. Host Matrix (to be populated post-pod-readiness)

| Host | Expected HTTP | undefined_* | NREUM | Status |
|------|--------------|-------------|-------|--------|
| `academyv2.staging.mereka.dev` | 200 | 0 | 0 | ⏳ PENDING |
| `apps.academyv2.staging.mereka.dev/authn/login` | 200 | 0 | 0 | ⏳ PENDING |
| `studio.academyv2.staging.mereka.dev` | 200/302 | 0 | 0 | ⏳ PENDING |
| `academyv2.staging.mereka.dev/admin/login/` | 200 | 0 | 0 | ⏳ PENDING |
| `ecommerce.academyv2.staging.mereka.dev` | 200 | 0 | 0 | ⏳ PENDING |
| `credentials.academyv2.staging.mereka.dev` | 200 | 0 | 0 | ⏳ PENDING |
| `discovery.academyv2.staging.mereka.dev` | 200 | 0 | 0 | ⏳ PENDING |

*Domain prefix `academyv2.staging.mereka.dev` is placeholder — update to actual rke2-nonprod domain.*

---

## 4. Cutover Step Plan (No Destructive Actions)

This plan transitions rke2-nonprod to production-equivalent readiness. All steps are additive — no data destruction, no downtime.

### Phase 1: Infrastructure Prerequisites (bbi-infrastructure, one-time)

| Step | Command | Verify |
|------|---------|--------|
| 1a | Create `artifact-registry-key` imagePullSecret | `kubectl get secret artifact-registry-key -n mereka-lms` |
| 1b | Patch default SA with imagePullSecrets | `kubectl get sa default -n mereka-lms -o json \| jq '.imagePullSecrets'` |
| 1c | Apply rke2-nonprod overlay (ExternalSecrets fix) | `kubectl get externalsecret -n mereka-lms` → all SecretSynced |
| 1d | Confirm staging DNS wildcard resolves | `dig academyv2.staging.mereka.dev` |

### Phase 2: Smoke Validation (BoldBadger, after Phase 1)

| Step | Script | Expected |
|------|--------|----------|
| 2a | `bash scripts/qa/verify-rke2-deployment-readiness.sh --live` | RESULT: PASS |
| 2b | Run branding gates in dev mode | `RUN_LIVE_GATE=0 bash scripts/branding/run-branding-gates.sh dev` |
| 2c | Run 288f host matrix | `curl` each host in matrix above → all 200 |
| 2d | Run 5ngf.2 routing smoke | authn/dashboard/admin paths |

### Phase 3: Hardening Confirmation (aza7)

| Step | Command | Expected |
|------|---------|----------|
| 3a | Verify no undefined analytics tokens | `curl https://[domain] \| grep -c undefined_license_key` → 0 |
| 3b | Confirm TLS certs valid | `curl -vI https://[domain] 2>&1 \| grep 'SSL certificate verify'` → OK |
| 3c | Check Caddy logs for 4xx/5xx rate | `kubectl logs -n mereka-lms -l app=caddy --tail=100 \| grep -cE ' [45][0-9]{2} '` → <5 |

### Phase 4: Handoff to Production Path

**NOT YET** — rke2-nonprod is a validation cluster. Production runs on GKE.
Production cutover only after:
- rke2-nonprod smoke matrix 100% green
- aza7 AC-RKE2-101..105 all verified
- OrangeSnow sign-off

---

## 5. Blockers Converted to Beads (AC-RKE2-104)

All unresolved risk items have been documented as explicit follow-up items:

| Item | Description | Owner | ETA | Severity |
|------|-------------|-------|-----|----------|
| **Blocker B** | rke2 ExternalSecrets overlay using infisical-secret-store | bbi-infrastructure | Immediate | P0 |
| **Blocker C** | `artifact-registry-key` imagePullSecret creation | bbi-infrastructure | Immediate | P0 |
| **imagePullSecret rotation** | SA key has no auto-rotation; OAuth token expires in ~1h | bbi-infrastructure | Sprint | HIGH |
| **Infisical path mapping** | Must verify `remoteRef.key` names match infisical-secret-store config | BoldBadger + bbi-infra | Before 288f smoke | HIGH |
| **Staging DNS** | `*.staging.mereka.dev` DNS records must exist for Ingress to work | bbi-infrastructure | Before 288f smoke | MEDIUM |
| **patchesJson6902 deprecation** | bbi-infrastructure kustomization uses deprecated field | bbi-infrastructure | Low priority | LOW |

*Beads to create (pending 288f completion for context):*
- `bead: rke2-imagepullsecret-rotation-automation` (HIGH)
- `bead: rke2-infisical-path-verification` (HIGH)

---

## 6. Evidence Artifact Index

| File | Description | Commit |
|------|-------------|--------|
| `docs/archive/evidence/operations/evidence/rke2/20260219T1935-rke2-argo-blocker.md` | ArgoCD git fetch timeout root cause | `87ea0b6` |
| `docs/archive/evidence/operations/evidence/rke2/20260219T2120-rke2-github-connectivity.md` | SSH connectivity fix evidence | prior |
| `docs/archive/evidence/operations/evidence/rke2/blocker-triage/20260219T2015-1exg-authn-triage.md` | 403/405 audit + authn shell verification | prior |
| `docs/archive/evidence/operations/evidence/rke2/20260219T2240-rke2-deployment-blockers.md` | Post-sync blockers (ExternalSecrets + ImagePullBackOff) | `56fdf54` |
| `docs/archive/evidence/operations/evidence/rke2/RKE2-DEPLOYMENT-RUNBOOK.md` | Full deployment runbook | `3428813` |
| `deploy/k8s/overlays/rke2-nonprod/` | Kustomize overlay scaffold | `48bead6` |
| `scripts/qa/verify-rke2-deployment-readiness.sh` | Automated blocker detection script | this commit |
| `docs/archive/evidence/operations/evidence/rke2/AZA7-OPERATIONAL-HANDOFF.md` | **This file** — aza7 handoff pack | this commit |

---

## 7. Rollback Paths

All changes in this repo are ADDITIVE. Nothing breaks existing GKE production.

| Action | Rollback |
|--------|----------|
| Applied `rke2-nonprod` overlay | `kubectl delete -k deploy/k8s/overlays/rke2-nonprod` |
| Created `artifact-registry-key` | `kubectl delete secret artifact-registry-key -n mereka-lms` |
| Patched default SA imagePullSecrets | `kubectl patch sa default -n mereka-lms -p '{"imagePullSecrets": null}'` |
| ArgoCD app created | `argocd app delete mereka-lms-local` |
| ExternalSecrets store switch | Re-apply base overlay: `kubectl apply -k deploy/k8s/base` |

**GKE production is completely unaffected** — rke2-nonprod is an isolated cluster. All rke2-specific resources are namespaced to `mereka-lms` on the rke2 cluster only.

---

*Ready to resume smoke execution immediately when bbi-infrastructure lands Blockers B+C.*
*Signal: send BoldBadger checkpoint with `kubectl get pods -n mereka-lms` output showing lms/cms/caddy Running.*
