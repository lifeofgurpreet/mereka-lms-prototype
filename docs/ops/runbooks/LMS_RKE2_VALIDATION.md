# LMS RKE2 Nonprod Validation Runbook

<!-- Last updated: 2026-02-24 -->

This runbook covers pre-cutover validation, smoke testing, and the go/no-go gate
for the LMS on the `rke2-nonprod` cluster (`academyv2.mereka.dev`).

---

## Domains (rke2-nonprod)

| Service | Domain |
|---------|--------|
| LMS | `https://academyv2.mereka.dev` |
| Studio | `https://studio.academyv2.mereka.dev` |
| MFE | `https://apps.academyv2.mereka.dev` |
| Discovery | `https://discovery.academyv2.mereka.dev` |
| Notes | `https://notes.academyv2.mereka.dev` |
| Credentials | `https://credentials.academyv2.mereka.dev` |
| Forum | `https://forum.academyv2.mereka.dev` |

---

## Pre-Cutover Checklist

Run through this before declaring the cluster ready for traffic.

### Manual Prerequisites (one-time cluster setup)

These must be done manually before the overlay is applied. They cannot be expressed
as Kustomize resources because they depend on cluster-level secrets and provider
configuration.

- [ ] `ClusterSecretStore infisical-secret-store` created and in `Ready` state
  ```bash
  kubectl --context rke2-nonprod get clustersecretstore infisical-secret-store
  # Expected: READY=True
  ```

- [ ] Docker registry pull secret `artifact-registry-key` exists in `mereka-lms` namespace
  ```bash
  kubectl --context rke2-nonprod get secret artifact-registry-key -n mereka-lms
  # Type: kubernetes.io/dockerconfigjson
  ```

- [ ] Default ServiceAccount patched with imagePullSecret
  ```bash
  kubectl --context rke2-nonprod get serviceaccount default -n mereka-lms \
    -o jsonpath='{.imagePullSecrets}'
  # Expected: [{"name":"artifact-registry-key"}]
  ```

- [ ] cert-manager and ingress-nginx installed on cluster
  ```bash
  kubectl --context rke2-nonprod get pods -n cert-manager
  kubectl --context rke2-nonprod get pods -n ingress-nginx
  ```

- [ ] DNS records for `*.academyv2.mereka.dev` point to rke2-nonprod ingress IP
  ```bash
  dig academyv2.mereka.dev +short
  # Should return the RKE2 node IP (154.26.132.35)
  ```

### Automated Pre-Cutover Checks

```bash
# 1. Static manifest validation (no cluster required)
scripts/qa/verify-lms-rke2-validation.sh --offline

# 2. RKE2-specific blocker checks (secret store, image pull, quota)
scripts/qa/verify-rke2-deployment-readiness.sh --offline

# 3. Full readiness gate (offline + live; exits 1 on any FAIL)
scripts/qa/verify-lms-rke2-validation.sh --readiness-gate
```

---

## Smoke Test Commands

### Quick 5-Command Diagnostic (cluster down)

```bash
# 1. Are pods running?
kubectl --context rke2-nonprod get pods -n mereka-lms

# 2. Are endpoints populated?
kubectl --context rke2-nonprod get endpoints -n mereka-lms
# Empty <none> = no traffic can reach the service

# 3. Is caddy service up?
kubectl --context rke2-nonprod get svc caddy -n mereka-lms

# 4. Are ExternalSecrets synced?
kubectl --context rke2-nonprod get externalsecret -n mereka-lms

# 5. Recent LMS logs
kubectl --context rke2-nonprod logs -n mereka-lms \
  -l app.kubernetes.io/name=lms --tail=50
```

### HTTP Smoke Matrix

```bash
# LMS homepage (expect 200/302)
curl -sI https://academyv2.mereka.dev/ | head -1

# Studio (expect 200/302)
curl -sI https://studio.academyv2.mereka.dev/ | head -1

# MFE login (expect 200)
curl -sI https://apps.academyv2.mereka.dev/authn/login | head -1

# LMS API health
curl -s https://academyv2.mereka.dev/heartbeat
# Expected: {"OK": true} or similar JSON

# SSL validity check
curl -v --max-time 10 https://academyv2.mereka.dev/ 2>&1 | grep -E 'SSL|certificate|expire'
```

### Cert Expiry

```bash
echo | openssl s_client -connect academyv2.mereka.dev:443 \
  -servername academyv2.mereka.dev 2>/dev/null \
  | openssl x509 -noout -enddate
```

---

## Routing Verification Matrix

| Source | Via | Backend | Expected |
|--------|-----|---------|----------|
| Browser → LMS | Cloudflare DNS → RKE2 node:443 | nginx-ingress → caddy:80 → lms:8000 | HTTP 200 |
| Browser → Studio | DNS → RKE2 node:443 | nginx-ingress → caddy:80 → cms:8000 | HTTP 200/302 |
| Browser → MFE | DNS → RKE2 node:443 | nginx-ingress → caddy:80 → mfe:8002 | HTTP 200 |
| LMS → DB (MySQL) | in-cluster ClusterIP | mysql:3306 | TCP connect |
| LMS → DB (MongoDB) | Atlas SRV | cluster-mereka-lms.2pjex4s.mongodb.net | TCP connect |
| LMS → Redis | in-cluster ClusterIP | redis:6379 | TCP connect |
| LMS → Forum | in-process (Forum v2) | N/A — same pod | N/A |
| ExternalSecret → Secrets | infisical-secret-store | Infisical API | SecretSynced |

### Verify Ingress Routing

```bash
# Confirm ingress controller is on the right node
kubectl --context rke2-nonprod get pods -n ingress-nginx -o wide

# Confirm ingress rules
kubectl --context rke2-nonprod get ingress -n mereka-lms

# Inspect a specific ingress
kubectl --context rke2-nonprod describe ingress openedx-lms -n mereka-lms

# Trace response origin (identifies where the response came from)
curl -svI https://academyv2.mereka.dev/ 2>&1 | grep -iE 'server:|via:|x-powered-by'
```

### Verify Caddy Routing Inside the Pod

```bash
# Get the running caddy pod
CADDY_POD=$(kubectl --context rke2-nonprod get pods -n mereka-lms \
  -l app.kubernetes.io/name=caddy \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}')

# Check which Caddyfile is loaded
kubectl --context rke2-nonprod exec -n mereka-lms "$CADDY_POD" -- \
  cat /etc/caddy/Caddyfile | head -40
```

---

## Evidence Collection Procedure

Run this before cutover to capture a verifiable snapshot of cluster state.

```bash
TIMESTAMP=$(date +%Y%m%dT%H%M)
EVIDENCE_DIR="docs/archive/evidence/operations/rke2/${TIMESTAMP}-lms-validation"
mkdir -p "$EVIDENCE_DIR"

# 1. Validation script output
scripts/qa/verify-lms-rke2-validation.sh --readiness-gate \
  > "${EVIDENCE_DIR}/readiness-gate.txt" 2>&1 \
  && echo "Gate: PASS" || echo "Gate: FAIL"

# 2. Pod state
kubectl --context rke2-nonprod get pods -n mereka-lms -o wide \
  > "${EVIDENCE_DIR}/pods.txt"

# 3. Endpoint state
kubectl --context rke2-nonprod get endpoints -n mereka-lms \
  > "${EVIDENCE_DIR}/endpoints.txt"

# 4. ExternalSecret sync status
kubectl --context rke2-nonprod get externalsecret -n mereka-lms \
  > "${EVIDENCE_DIR}/externalsecrets.txt"

# 5. Ingress state
kubectl --context rke2-nonprod get ingress -n mereka-lms \
  > "${EVIDENCE_DIR}/ingress.txt"

# 6. HTTP smoke results
{
  echo "LMS:    $(curl -s -o /dev/null -w "%{http_code}" https://academyv2.mereka.dev/)"
  echo "Studio: $(curl -s -o /dev/null -w "%{http_code}" https://studio.academyv2.mereka.dev/)"
  echo "MFE:    $(curl -s -o /dev/null -w "%{http_code}" https://apps.academyv2.mereka.dev/authn/login)"
} > "${EVIDENCE_DIR}/http-smoke.txt"

# 7. Cert expiry
echo | openssl s_client -connect academyv2.mereka.dev:443 \
  -servername academyv2.mereka.dev 2>/dev/null \
  | openssl x509 -noout -enddate \
  > "${EVIDENCE_DIR}/ssl-cert.txt"

echo "Evidence written to $EVIDENCE_DIR"
ls -lh "$EVIDENCE_DIR"
```

---

## Go/No-Go Criteria

### GO (all must be true)

- [ ] `verify-lms-rke2-validation.sh --readiness-gate` exits 0 (0 FAILs)
- [ ] `verify-rke2-deployment-readiness.sh --live` exits 0
- [ ] All core pods Running: `lms`, `cms`, `caddy`
- [ ] All core endpoints populated (no `<none>`)
- [ ] All ExternalSecrets report `SecretSynced`
- [ ] LMS homepage returns HTTP 200 or 302
- [ ] Studio returns HTTP 200 or 302
- [ ] MFE login page returns HTTP 200
- [ ] SSL certificate valid with >= 14 days remaining
- [ ] No CrashLoopBackOff pods
- [ ] No DB connection errors in recent LMS logs

### NO-GO (any of these block cutover)

- [ ] Any FAIL in readiness gate script
- [ ] CrashLoopBackOff on lms, cms, or caddy
- [ ] Empty endpoints for lms, cms, or caddy services
- [ ] ExternalSecret not in SecretSynced state
- [ ] LMS homepage returns 5xx or timeout
- [ ] SSL certificate expired or invalid
- [ ] DB connection errors in LMS logs (OperationalError, connection refused)

---

## Common Failure Remediation

### Pods stuck in ImagePullBackOff

```bash
# Check pull secret
kubectl --context rke2-nonprod get secret artifact-registry-key -n mereka-lms

# Re-create pull secret if missing
kubectl --context rke2-nonprod create secret docker-registry artifact-registry-key \
  -n mereka-lms \
  --docker-server=asia-southeast1-docker.pkg.dev \
  --docker-username=_json_key \
  --docker-password="$(cat /path/to/gcp-sa-key.json)" \
  --docker-email=ci@mereka.io

# Patch default ServiceAccount
kubectl --context rke2-nonprod patch serviceaccount default -n mereka-lms \
  -p '{"imagePullSecrets": [{"name": "artifact-registry-key"}]}'
```

### ExternalSecrets not syncing

```bash
# Check ClusterSecretStore health
kubectl --context rke2-nonprod describe clustersecretstore infisical-secret-store

# Force ExternalSecret refresh
kubectl --context rke2-nonprod annotate externalsecret openedx-secrets -n mereka-lms \
  force-sync=$(date +%s) --overwrite
```

### Empty endpoints (site down)

```bash
# Check service selector matches pod labels
kubectl --context rke2-nonprod get svc lms -n mereka-lms -o yaml | grep selector -A5
kubectl --context rke2-nonprod get pods -n mereka-lms -l app.kubernetes.io/name=lms

# Run the selector fix script (GKE-centric but logic applies)
scripts/infra/fix-service-selectors.sh
```

### SSL certificate not provisioning

```bash
# Check cert-manager Certificate resource
kubectl --context rke2-nonprod get certificate -n mereka-lms
kubectl --context rke2-nonprod describe certificate openedx-lms-tls -n mereka-lms

# Check CertificateRequest and Order
kubectl --context rke2-nonprod get certificaterequest -n mereka-lms
kubectl --context rke2-nonprod get order -n mereka-lms

# Verify Let's Encrypt ClusterIssuer is Ready
kubectl --context rke2-nonprod get clusterissuer letsencrypt-prod
```

---

## Related

- `scripts/qa/verify-rke2-deployment-readiness.sh` — Blocker-specific checks (B1-B4)
- `scripts/qa/verify-rke2-dev-readiness.sh` — Dev environment prereq validation
- `scripts/qa/verify-k8s-deployment-spec.sh` — Manifest static analysis
- `docs/ops/runbooks/TROUBLESHOOTING.md` — General LMS troubleshooting
- `deploy/k8s/overlays/rke2-nonprod/` — RKE2 nonprod Kustomize overlay
- `specs/k8s-deployment_spec.md` — K8s deployment specification
