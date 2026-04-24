# RKE2 LMS Migration Completion Plan

> **Audience**: Platform Lead, LMS Team, On-Call Engineer
> **Scope**: GKE (production) → RKE2-nonprod staging cutover for Mereka Academy LMS
> **Production URLs**: `academyv2.mereka.io`, `studio.academyv2.mereka.io`, `apps.academyv2.mereka.io`
> **Staging URLs**: `academyv2.mereka.dev`, `studio.academyv2.mereka.dev`, `apps.academyv2.mereka.dev`
> **Related**: `RKE2_LMS_HANDOFF.md`, `RKE2_ROLLOUT_MATRIX.md`

---

## 1. Pre-Migration Checklist

All items must be DONE before starting the DNS cutover procedure.

### 1.1 Platform Readiness (Gates 0–2)

| # | Check | Command | Pass Condition |
|---|-------|---------|----------------|
| P1 | RKE2 cluster nodes Ready | `kubectl --context rke2-nonprod get nodes` | All nodes `Ready` |
| P2 | ArgoCD running | `kubectl --context rke2-nonprod get pods -n argocd` | All pods `Running` |
| P3 | cert-manager running | `kubectl --context rke2-nonprod get pods -n cert-manager` | All pods `Running` |
| P4 | ingress-nginx running | `kubectl --context rke2-nonprod get pods -n ingress-nginx` | All pods `Running` |
| P5 | external-secrets running | `kubectl --context rke2-nonprod get pods -n external-secrets` | All pods `Running` |
| P6 | kyverno running | `kubectl --context rke2-nonprod get pods -n kyverno` | All pods `Running` |
| P7 | Infisical ClusterSecretStore Ready | `kubectl --context rke2-nonprod get clustersecretstore infisical-secret-store` | `READY=True` |

Run the automated check:
```bash
scripts/qa/verify-migration-completion-plan.sh --offline
```

### 1.2 LMS App Readiness (Gate 4)

| # | Check | Command | Pass Condition |
|---|-------|---------|----------------|
| A1 | Core pods Running | `kubectl --context rke2-nonprod get pods -n mereka-lms` | lms, cms, caddy Running |
| A2 | ExternalSecrets synced | `kubectl --context rke2-nonprod get externalsecret -n mereka-lms` | `SecretSynced` for all |
| A3 | No PLACEHOLDER values | `kubectl --context rke2-nonprod get secret openedx-secrets -n mereka-lms -o json \| jq '.data \| to_entries[] \| select(.value == "") \| .key'` | Empty output |
| A4 | Ingress manifests exist | `ls deploy/k8s/overlays/rke2-nonprod/ingress-openedx-*.yaml` | 3 files present |
| A5 | SSL certs issued | `kubectl --context rke2-nonprod get certificate -n mereka-lms` | `READY=True` for all |
| A6 | No CrashLoopBackOff | `kubectl --context rke2-nonprod get pods -n mereka-lms` | 0 pods in crash loop |

### 1.3 Data Readiness (Gate 5)

| # | Check | Pass Condition |
|---|-------|----------------|
| D1 | MySQL migrations complete | `python manage.py lms showmigrations` — no unapplied |
| D2 | CMS migrations complete | `python manage.py cms showmigrations` — no unapplied |
| D3 | MongoDB Atlas staging DB accessible | Forum and modulestore queries succeed |
| D4 | Meilisearch index built | Course search returns results |
| D5 | Superuser account exists | Login to `/admin/` succeeds |

> **Note**: MongoDB remains on Atlas (no migration). MySQL staging data is a scrubbed copy from GKE.

### 1.4 Change Freeze Coordination

- **Freeze window**: No GKE production deployments during cutover (minimum 2-hour window)
- **Notify**: All engineers via Slack `#engineering` before starting
- **Rollback decision deadline**: Commit to rollback within 30 minutes of DNS flip if any rollback criterion is triggered

---

## 2. DNS Cutover Procedure (Cloudflare)

> **STOP**: Complete all Pre-Migration Checklist items before this section.

The staging environment uses `*.mereka.dev` (not `*.mereka.io`). This cutover updates DNS records to point staging domains at the RKE2 node IP.

### 2.1 Current State (Before Cutover)

| Domain | Record Type | Current Value | Points To |
|--------|-------------|---------------|-----------|
| `academyv2.mereka.io` | A | `34.177.83.168` | GKE LB (production) |
| `academyv2.mereka.dev` | A | (to be set) | RKE2 node IP |
| `studio.academyv2.mereka.dev` | CNAME | (to be set) | `academyv2.mereka.dev` |
| `apps.academyv2.mereka.dev` | CNAME | (to be set) | `academyv2.mereka.dev` |

> **Critical**: `academyv2.mereka.io` (production GKE) is NOT touched during this procedure.
> Staging uses the `.mereka.dev` domain. GKE production remains on `.mereka.io`.

### 2.2 Pre-Cutover: Verify RKE2 Node IP

```bash
# Get RKE2 node external IP
kubectl --context rke2-nonprod get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}'

# Or if using a load balancer service
kubectl --context rke2-nonprod get svc -n ingress-nginx -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
```

Record the IP: **RKE2_NODE_IP=`__FILL_IN__`**

### 2.3 Cutover Steps

Perform in order. Each step takes effect within 60 seconds (TTL=60 or Auto).

**Step 1**: Create A record for staging LMS domain

```bash
# Via Cloudflare dashboard: mereka.dev zone
# Type: A
# Name: academyv2
# Value: <RKE2_NODE_IP>
# TTL: Auto
# Proxy: OFF (gray cloud) — required for cert-manager ACME challenges

# Or via API:
curl -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID_MEREKA_DEV}/dns_records" \
  -H "Authorization: Bearer ${CLOUDFLARE_TOKEN_MEREKA_DEV}" \
  -H "Content-Type: application/json" \
  --data '{"type":"A","name":"academyv2","content":"<RKE2_NODE_IP>","ttl":60,"proxied":false}'
```

**Step 2**: Create CNAME for Studio

```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID_MEREKA_DEV}/dns_records" \
  -H "Authorization: Bearer ${CLOUDFLARE_TOKEN_MEREKA_DEV}" \
  -H "Content-Type: application/json" \
  --data '{"type":"CNAME","name":"studio.academyv2","content":"academyv2.mereka.dev","ttl":60,"proxied":false}'
```

**Step 3**: Create CNAME for MFE apps

```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID_MEREKA_DEV}/dns_records" \
  -H "Authorization: Bearer ${CLOUDFLARE_TOKEN_MEREKA_DEV}" \
  -H "Content-Type: application/json" \
  --data '{"type":"CNAME","name":"apps.academyv2","content":"academyv2.mereka.dev","ttl":60,"proxied":false}'
```

**Step 4**: Wait for DNS propagation (60–120 seconds)

```bash
# Poll until resolved
watch -n 5 "dig +short academyv2.mereka.dev"
# Expected: <RKE2_NODE_IP>
```

**Step 5**: Wait for cert-manager to issue SSL certificates (up to 10 minutes)

```bash
kubectl --context rke2-nonprod get certificate -n mereka-lms -w
# Wait until READY=True for all certificates
```

**Step 6**: Run post-cutover verification

```bash
scripts/qa/verify-migration-completion-plan.sh --online
```

### 2.4 DNS Rollback (if needed)

Delete the staging DNS records to stop traffic:

```bash
# List record IDs
curl -s "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID_MEREKA_DEV}/dns_records?name=academyv2.mereka.dev" \
  -H "Authorization: Bearer ${CLOUDFLARE_TOKEN_MEREKA_DEV}" | jq '.result[].id'

# Delete by ID
curl -X DELETE "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID_MEREKA_DEV}/dns_records/<RECORD_ID>" \
  -H "Authorization: Bearer ${CLOUDFLARE_TOKEN_MEREKA_DEV}"
```

DNS rollback takes effect within 60 seconds (TTL). No GKE changes required — production was never touched.

---

## 3. Rollback Criteria and Procedure

### 3.1 Rollback Criteria (Machine-Checkable)

Trigger an immediate rollback if ANY of the following conditions are true within 30 minutes of DNS cutover:

| ID | Criterion | Detection Command | Threshold |
|----|-----------|-------------------|-----------|
| R1 | LMS homepage returns non-2xx/3xx | `curl -s -o /dev/null -w "%{http_code}" https://academyv2.mereka.dev/` | HTTP code outside 200–302 |
| R2 | Studio homepage unavailable | `curl -s -o /dev/null -w "%{http_code}" https://studio.academyv2.mereka.dev/` | HTTP code outside 200–302 |
| R3 | MFE login page unavailable | `curl -s -o /dev/null -w "%{http_code}" https://apps.academyv2.mereka.dev/authn/login` | HTTP code outside 200–302 |
| R4 | SSL certificate invalid | `curl -s -o /dev/null -w "%{http_code}" https://academyv2.mereka.dev/` (strict TLS, no `-k`) | `000` (TLS handshake failure) |
| R5 | Core pods not Running | `kubectl --context rke2-nonprod get pods -n mereka-lms --field-selector=status.phase!=Running` | Any lms/cms/caddy pod not Running after 15 min |
| R6 | LMS heartbeat failing | `curl -s https://academyv2.mereka.dev/heartbeat` | Non-200 response |
| R7 | DB connection errors in logs | `kubectl --context rke2-nonprod logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 \| grep -i OperationalError` | Any match |
| R8 | Auth flow broken | Manual check: OIDC redirect via Authentik completes and session cookie is set | Session cookie absent |

The automated check covers R1–R6:
```bash
scripts/qa/verify-migration-completion-plan.sh --online
# Exit code 1 = at least one rollback criterion triggered
```

### 3.2 Rollback Decision Matrix

```
Criterion triggered within 30 min?
  YES → Immediate rollback (Section 3.3)
  NO  → Continue monitoring per Section 5 (Post-Cutover Verification)

Can criterion be fixed in < 5 minutes?
  YES → Fix first, re-verify, then continue
  NO  → Immediate rollback
```

### 3.3 Rollback Procedure

**Time to rollback: < 5 minutes**

**Step 1**: Remove staging DNS records (Section 2.4) — takes effect in 60 seconds.

**Step 2**: Confirm production GKE is unaffected:

```bash
curl -sI https://academyv2.mereka.io | head -1
# Expected: HTTP/2 200 or HTTP/2 302
```

**Step 3**: Notify team:

```
ROLLBACK INITIATED — [timestamp]
Reason: [which criterion triggered]
DNS records removed from mereka.dev zone
GKE production unaffected (academyv2.mereka.io responding normally)
Staging investigation underway
```

**Step 4**: Investigate root cause before re-attempting:

```bash
# Pod state
kubectl --context rke2-nonprod get pods -n mereka-lms

# Recent events
kubectl --context rke2-nonprod get events -n mereka-lms --sort-by='.lastTimestamp' | tail -20

# LMS logs
kubectl --context rke2-nonprod logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100
```

### 3.4 Re-Attempt Criteria

Before re-attempting DNS cutover after a rollback:

- [ ] Root cause identified and fixed (committed to git, ArgoCD synced)
- [ ] All Pre-Migration Checklist items re-verified (Section 1)
- [ ] `scripts/qa/verify-migration-completion-plan.sh --offline` passes
- [ ] 24-hour cooling period if the same criterion triggered twice

---

## 4. Post-Cutover Verification Steps

Run within 30 minutes of successful DNS cutover.

### 4.1 Automated Checks

```bash
# Full online verification
scripts/qa/verify-migration-completion-plan.sh --online

# Expected: PASS summary with 0 FAILs
```

### 4.2 Manual Verification Matrix

| Check | How to Verify | Expected |
|-------|---------------|----------|
| LMS homepage loads | Browser: `https://academyv2.mereka.dev/` | Mereka branding visible, no 5xx |
| Login flow works | Click "Sign In", complete OIDC via Authentik | Redirected to dashboard |
| Studio accessible | Browser: `https://studio.academyv2.mereka.dev/` | Course list visible after login |
| MFE authn works | `https://apps.academyv2.mereka.dev/authn/login` | Login form loads |
| Forum renders | Browse to a course forum thread | Posts visible |
| Purchase Gateway health | `curl https://academyv2.mereka.dev/api/purchase-gateway/health/` | `{"status": "ok"}` |
| Admin panel | `https://academyv2.mereka.dev/admin/` → login | Django admin loads |
| Course content | Enroll in a test course, view a unit | XBlocks render |

### 4.3 Observability Checks

```bash
# Check Prometheus scraping LMS metrics
kubectl --context rke2-nonprod exec -n monitoring deploy/prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/targets?state=active' \
  | python3 -m json.tool | grep -c '"mereka-lms"' || true

# Check no alert rules firing
kubectl --context rke2-nonprod exec -n monitoring deploy/prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/alerts' | python3 -m json.tool
```

### 4.4 24-Hour Stability Window

Monitor for 24 hours post-cutover:

| Hour | Check |
|------|-------|
| +1h | Re-run `verify-migration-completion-plan.sh --online` |
| +4h | Check error rate in Loki: `{app="lms"} |= "ERROR"` |
| +8h | Verify Velero backup completed for PVCs |
| +24h | Review Prometheus dashboards for anomalies |

---

## 5. On-Call Schedule Template

### 5.1 Cutover Window Roles

| Role | Person | Responsibility | Contact |
|------|--------|---------------|---------|
| Platform Lead (IC) | `__FILL_IN__` | Go/no-go, rollback authority | Slack DM |
| LMS Engineer | `__FILL_IN__` | App-layer verification, DB checks | Slack DM |
| Platform Engineer | `__FILL_IN__` | kubectl operations, ArgoCD | Slack DM |
| Network/DNS | `__FILL_IN__` | Cloudflare changes, cert-manager | Slack DM |
| Observer | `__FILL_IN__` | External monitoring, status page | Slack DM |

### 5.2 Recommended Cutover Window

- **Day**: Tuesday or Wednesday (avoid Monday/Friday)
- **Time**: 10:00 SGT (UTC+8) — low traffic period for Southeast Asian learners
- **Duration**: 2-hour window maximum
- **Participants**: All roles in a shared call/huddle for the first 30 minutes

### 5.3 Communication Channels

```
Pre-cutover announcement (T-24h):
  Channel: #engineering
  Message: "Staging cutover scheduled for [date/time]. Freeze: no production deploys [window]."

Cutover start (T=0):
  Channel: #engineering
  Message: "Staging cutover starting. DNS flip in progress."

Post-cutover status (T+30m):
  Channel: #engineering
  Message: "Cutover [COMPLETE/ROLLED BACK]. [Details]."
```

### 5.4 Post-Cutover On-Call Rotation

For the 24-hour stability window after cutover:

| Shift | Hours (SGT) | Primary | Escalation |
|-------|-------------|---------|------------|
| Daytime | 09:00–18:00 | LMS Engineer | Platform Lead |
| Evening | 18:00–00:00 | Platform Engineer | Platform Lead |
| Night | 00:00–09:00 | PagerDuty auto-page | Platform Lead |

**Alert threshold for night shift page**: Any rollback criterion (R1–R8) sustained for > 5 minutes.

---

## 6. Architecture Notes

### What Is Migrated

| Component | Status | Notes |
|-----------|--------|-------|
| LMS (Open edX) | Migrated to RKE2 | Staging instance, separate from GKE production |
| CMS (Studio) | Migrated to RKE2 | Staging instance |
| MFEs | Migrated to RKE2 | Authn, Learning MFE, etc. |
| MySQL | In-cluster on RKE2 | Scrubbed copy of production data |
| Redis | In-cluster on RKE2 | Fresh (ephemeral cache, no restore needed) |
| Meilisearch | In-cluster on RKE2 | Index rebuilt from LMS after deploy |
| Purchase Gateway | Migrated to RKE2 | FastAPI + PostgreSQL (dark launch) |
| Forum v2 | In-process with LMS | No separate deployment needed |

### What Stays on GKE Production

| Component | Notes |
|-----------|-------|
| `academyv2.mereka.io` | GKE production — unchanged during this migration |
| MongoDB Atlas | Shared between GKE and RKE2 staging (separate Atlas DB for staging) |
| Authentik SSO | Shared (`auth0.mereka.io`) — both clusters use same Authentik instance |
| GCP Secret Manager | `bbi-k8` project — staging reads from Infisical instead |

### Secret Store Differences

| Cluster | Secret Store | Notes |
|---------|-------------|-------|
| GKE Production | `gcp-secret-manager` ClusterSecretStore | ESO → GCP SM (`bbi-k8` project) |
| RKE2 Staging | `infisical-secret-store` ClusterSecretStore | ESO → Infisical directly |

---

## 7. Related Documents

| Document | Path |
|----------|------|
| Cross-repo handoff | `reports/2026/closures/RKE2_LMS_HANDOFF.md` |
| Gate-by-gate rollout matrix | `docs/status/migrations/RKE2_ROLLOUT_MATRIX.md` |
| DNS management | `docs/archive/reports/CLOUDFLARE` |
| Troubleshooting | `docs/ops/runbooks/TROUBLESHOOTING.md` |
| Post-deploy smoke | `docs/ops/runbooks/POSTDEPLOY_SMOKE_AND_INCIDENT.md` |
| Canonical deploy contract | `docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md` |
| Verification script | `scripts/qa/verify-migration-completion-plan.sh` |
