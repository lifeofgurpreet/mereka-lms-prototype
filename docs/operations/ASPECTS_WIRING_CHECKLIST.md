# Aspects Analytics Wiring Checklist

> **Owner**: platform-engineering
> **Last Updated**: 2026-02-25
> **Depends on**: `docs/operations/ASPECTS_ANALYTICS_SETUP.md` (component overview)
> **Deployment flow**: dev (rke2-nonprod / *.mereka.dev) → prod (GKE / *.mereka.io)
> **Status**: WIRED — manifests connected to kustomization graph, operator actions pending

---

## Overview

This checklist is for the operator who wires `deploy/k8s/base/plugins/aspects/` into the active
kustomization graph. It covers both the dev (rke2-nonprod) and prod (GKE) environments.

**Do not proceed to prod until the dev environment has been stable for at least 2 weeks and
CTO sign-off is obtained.**

Completion of each step can be verified by running:
```bash
./scripts/qa/verify-aspects-wiring.sh
```

---

## Phase 1 — Dev (rke2-nonprod / *.mereka.dev)

### Pre-flight Checks

Before starting, confirm these platform invariants:

- [ ] `kubectl get nodes` — rke2-nonprod cluster is reachable and nodes are Ready
- [ ] `kubectl get clusterssecretstore infisical-secret-store` — ClusterSecretStore is Valid/Ready
- [ ] `kubectl get ns mereka-lms` — target namespace exists
- [ ] `kubectl get storageclass` — note the available storage class name (NOT `standard-rwo`, which is GKE-specific)
  ```bash
  kubectl get storageclass
  # Common rke2 options: local-path, longhorn, nfs-client
  # Record the name — you'll need it in step 1.3
  ```
- [ ] `kubectl get secret artifact-registry-key -n mereka-lms` — image pull secret exists
- [ ] DNS `analytics.academyv2.mereka.dev` is resolvable (or ready to be created in Cloudflare)
- [ ] MySQL pod is running: `kubectl get pod -n mereka-lms -l app.kubernetes.io/name=mysql`
- [ ] Redis pod is running: `kubectl get pod -n mereka-lms -l app.kubernetes.io/name=redis`

---

### Step 1.1 — Provision Secrets in Infisical

**Run from**: `/home/gurpreet/projects/k8s/reka-slackbot` (has `.infisical.json`)

Generate secret values:
```bash
CLICKHOUSE_PASSWORD="$(openssl rand -base64 24)"
SUPERSET_SECRET_KEY="$(openssl rand -hex 32)"
SUPERSET_DB_PASSWORD="$(openssl rand -base64 24)"

echo "CLICKHOUSE_PASSWORD: ${CLICKHOUSE_PASSWORD}"
echo "SUPERSET_SECRET_KEY: ${SUPERSET_SECRET_KEY}"
echo "SUPERSET_DB_PASSWORD: ${SUPERSET_DB_PASSWORD}"
```

Store in Infisical (prod env, root path — matches existing pattern):
```bash
cd /home/gurpreet/projects/k8s/reka-slackbot

infisical secrets set MEREKA_LMS_ASPECTS_CLICKHOUSE_PASSWORD="${CLICKHOUSE_PASSWORD}" \
  --domain https://secrets.mereka.io/api --env prod --path /

infisical secrets set MEREKA_LMS_ASPECTS_SUPERSET_SECRET_KEY="${SUPERSET_SECRET_KEY}" \
  --domain https://secrets.mereka.io/api --env prod --path /

infisical secrets set MEREKA_LMS_ASPECTS_SUPERSET_DB_PASSWORD="${SUPERSET_DB_PASSWORD}" \
  --domain https://secrets.mereka.io/api --env prod --path /
```

Verification:
```bash
infisical secrets get MEREKA_LMS_ASPECTS_CLICKHOUSE_PASSWORD \
  --domain https://secrets.mereka.io/api --env prod --path / --plain 2>/dev/null
# Should print the value you set
```

- [ ] `MEREKA_LMS_ASPECTS_CLICKHOUSE_PASSWORD` set in Infisical
- [ ] `MEREKA_LMS_ASPECTS_SUPERSET_SECRET_KEY` set in Infisical
- [ ] `MEREKA_LMS_ASPECTS_SUPERSET_DB_PASSWORD` set in Infisical

---

### Step 1.2 — Create GCP Secret Manager Entries

Secrets must also be in GCP Secret Manager (`bbi-k8` project) for the production overlay.
Infisical → GCP SM sync may not cover new secrets automatically — create them explicitly.

```bash
printf '%s' "${CLICKHOUSE_PASSWORD}" | gcloud secrets create MEREKA_LMS_ASPECTS_CLICKHOUSE_PASSWORD \
  --project=bbi-k8 --data-file=-
printf '%s' "${CLICKHOUSE_PASSWORD}" | gcloud secrets versions add MEREKA_LMS_ASPECTS_CLICKHOUSE_PASSWORD \
  --project=bbi-k8 --data-file=-

printf '%s' "${SUPERSET_SECRET_KEY}" | gcloud secrets create MEREKA_LMS_ASPECTS_SUPERSET_SECRET_KEY \
  --project=bbi-k8 --data-file=-
printf '%s' "${SUPERSET_SECRET_KEY}" | gcloud secrets versions add MEREKA_LMS_ASPECTS_SUPERSET_SECRET_KEY \
  --project=bbi-k8 --data-file=-

printf '%s' "${SUPERSET_DB_PASSWORD}" | gcloud secrets create MEREKA_LMS_ASPECTS_SUPERSET_DB_PASSWORD \
  --project=bbi-k8 --data-file=-
printf '%s' "${SUPERSET_DB_PASSWORD}" | gcloud secrets versions add MEREKA_LMS_ASPECTS_SUPERSET_DB_PASSWORD \
  --project=bbi-k8 --data-file=-
```

Grant access to the external-secrets service account:
```bash
for secret in MEREKA_LMS_ASPECTS_CLICKHOUSE_PASSWORD MEREKA_LMS_ASPECTS_SUPERSET_SECRET_KEY MEREKA_LMS_ASPECTS_SUPERSET_DB_PASSWORD; do
  gcloud secrets add-iam-policy-binding "${secret}" \
    --project=bbi-k8 \
    --member="serviceAccount:external-secrets-gcp@bbi-k8.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
done
```

- [ ] `MEREKA_LMS_ASPECTS_CLICKHOUSE_PASSWORD` created in GCP SM (`bbi-k8`)
- [ ] `MEREKA_LMS_ASPECTS_SUPERSET_SECRET_KEY` created in GCP SM (`bbi-k8`)
- [ ] `MEREKA_LMS_ASPECTS_SUPERSET_DB_PASSWORD` created in GCP SM (`bbi-k8`)
- [ ] IAM binding granted to `external-secrets-gcp@bbi-k8.iam.gserviceaccount.com`

---

### Step 1.3 — Create ExternalSecret for aspects-secrets

Add an ExternalSecret resource to `deploy/k8s/base/secrets/external-secrets.yaml` that maps
the three GCP SM secrets to the `aspects-secrets` K8s Secret used by Aspects deployments.

Append this block to `deploy/k8s/base/secrets/external-secrets.yaml`:

```yaml
---
# ExternalSecret for Aspects analytics (ClickHouse + Superset)
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: aspects-secrets
  namespace: mereka-lms
  labels:
    app.kubernetes.io/name: aspects-secrets
    app.kubernetes.io/part-of: aspects
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: gcp-secret-manager
  target:
    name: aspects-secrets
    creationPolicy: Owner
    deletionPolicy: Retain
  data:
    - secretKey: clickhouse-password
      remoteRef:
        key: MEREKA_LMS_ASPECTS_CLICKHOUSE_PASSWORD
    - secretKey: superset-secret-key
      remoteRef:
        key: MEREKA_LMS_ASPECTS_SUPERSET_SECRET_KEY
    - secretKey: superset-db-password
      remoteRef:
        key: MEREKA_LMS_ASPECTS_SUPERSET_DB_PASSWORD
```

Also add the corresponding Infisical override to
`deploy/k8s/overlays/rke2-nonprod/patches/externalsecrets-infisical.yaml` (mirrors existing
ExternalSecrets in that file — same keys, `infisical-secret-store` as the storeRef).

- [ ] ExternalSecret `aspects-secrets` added to `deploy/k8s/base/secrets/external-secrets.yaml`
- [ ] Infisical override added to `deploy/k8s/overlays/rke2-nonprod/patches/externalsecrets-infisical.yaml`
- [ ] Changes committed and pushed to git

---

### Step 1.4 — Determine rke2-nonprod Storage Class

The base manifest uses `storageClassName: standard-rwo` which is GKE-specific.
rke2-nonprod requires a different storage class.

```bash
kubectl get storageclass
# Identify the default storage class (marked with "(default)")
```

Create a patch file at `deploy/k8s/overlays/rke2-nonprod/patches/aspects-storage-class.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: clickhouse-data
spec:
  storageClassName: local-path  # Replace with actual rke2 storage class name
```

- [ ] Storage class name identified from `kubectl get storageclass`
- [ ] `deploy/k8s/overlays/rke2-nonprod/patches/aspects-storage-class.yaml` created

---

### Step 1.5 — Create DNS Record for Dev Analytics Domain

In Cloudflare dashboard (or via CLI), create a DNS record for the dev analytics subdomain:

- **Type**: A (or CNAME if using load balancer hostname)
- **Name**: `analytics.academyv2.mereka.dev`
- **Value**: rke2-nonprod ingress controller IP (same IP used by other `*.academyv2.mereka.dev` entries)
- **Proxy**: DNS-only (gray cloud) — Cloudflare Free SSL does NOT cover `*.academyv2.mereka.dev`
  (multi-level subdomain); cert-manager + Let's Encrypt handles TLS

Verify the record resolves:
```bash
dig analytics.academyv2.mereka.dev +short
```

- [ ] DNS record `analytics.academyv2.mereka.dev` created in Cloudflare (DNS-only)
- [ ] Record resolves to rke2-nonprod ingress IP

---

### Step 1.6 — Create Dev Ingress Overlay Patch

Create `deploy/k8s/overlays/rke2-nonprod/patches/aspects-ingress-dev.yaml` with the dev hostname:
```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: superset
  namespace: mereka-lms
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: 50m
spec:
  ingressClassName: nginx
  rules:
    - host: analytics.academyv2.mereka.dev
      http:
        paths:
          - backend:
              service:
                name: superset
                port:
                  number: 8088
            path: /
            pathType: Prefix
  tls:
    - hosts:
        - analytics.academyv2.mereka.dev
      secretName: superset-tls-dev
```

- [ ] `deploy/k8s/overlays/rke2-nonprod/patches/aspects-ingress-dev.yaml` created

---

### Step 1.7 — Wire Aspects into the rke2-nonprod Overlay Kustomization

Edit `deploy/k8s/overlays/rke2-nonprod/kustomization.yaml`:

1. Add `../../base/plugins/aspects` to the `resources` list
2. Add `ingress-aspects-superset.yaml` to the `resources` list
3. Add the storage class patch to `patches`

```yaml
resources:
  - ../../base
  - ../../base/plugins/aspects     # ADD THIS
  - ingress-openedx-lms.yaml
  - ingress-openedx-mfe.yaml
  - ingress-openedx-studio.yaml
  - ingress-aspects-superset.yaml  # ADD THIS

patches:
  - path: patches/externalsecrets-infisical.yaml
  - path: patches/domain-env.yaml
  - path: patches/single-node-recreate-strategy.yaml
  - path: patches/aspects-storage-class.yaml   # ADD THIS
```

Also add Aspects replica counts to the `replicas` section:
```yaml
replicas:
  # ... existing replicas ...
  - name: clickhouse
    count: 1
  - name: superset
    count: 1
  - name: superset-worker
    count: 1
```

- [ ] `../../base/plugins/aspects` added to `resources` in rke2-nonprod kustomization
- [ ] `ingress-aspects-superset.yaml` added to `resources`
- [ ] `patches/aspects-storage-class.yaml` added to `patches`
- [ ] Replica counts added for clickhouse, superset, superset-worker
- [ ] Changes committed and pushed to git

---

### Step 1.8 — Create Superset MySQL Database

Run once after the ESO has synced secrets (wait ~5 minutes after push, or force-refresh):

```bash
# Get the Superset DB password from the synced secret
SUPERSET_DB_PASSWORD="$(kubectl get secret aspects-secrets -n mereka-lms \
  -o jsonpath='{.data.superset-db-password}' | base64 -d)"

# Get the MySQL root password
MYSQL_ROOT_PASS="$(kubectl get secret openedx-secrets -n mereka-lms \
  -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d)"

# Create the superset database and user
kubectl exec -n mereka-lms deployment/mysql -- \
  mysql -u root -p"${MYSQL_ROOT_PASS}" -e "
    CREATE DATABASE IF NOT EXISTS superset CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS 'superset'@'%' IDENTIFIED BY '${SUPERSET_DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON superset.* TO 'superset'@'%';
    FLUSH PRIVILEGES;
  "
```

Verify:
```bash
kubectl exec -n mereka-lms deployment/mysql -- \
  mysql -u root -p"${MYSQL_ROOT_PASS}" -e "SHOW DATABASES LIKE 'superset';"
# Should show: superset
```

- [ ] `superset` MySQL database created
- [ ] `superset` MySQL user created with correct password
- [ ] Grants applied and flushed

---

### Step 1.9 — Apply and Wait for Pods

ArgoCD will detect the git change and apply automatically (wait up to 3 minutes). To check:
```bash
kubectl get pods -n mereka-lms -l app.kubernetes.io/part-of=aspects -w
```

Expected pod states after ~5 minutes:
- `clickhouse-*` — Running (1/1)
- `superset-*` — Running (1/1) — may take 2–3 minutes for pip install init container
- `superset-worker-*` — Running (1/1)

If pods are not starting, check:
```bash
kubectl describe pod -n mereka-lms -l app.kubernetes.io/part-of=aspects
kubectl logs -n mereka-lms -l app.kubernetes.io/name=clickhouse --tail=50
kubectl logs -n mereka-lms -l app.kubernetes.io/name=superset --tail=50
```

- [ ] `clickhouse` pod Running 1/1
- [ ] `superset` pod Running 1/1
- [ ] `superset-worker` pod Running 1/1
- [ ] `aspects-secrets` ExternalSecret is Ready/Synced

---

### Step 1.10 — Run Init Jobs

The init jobs must be run manually after pods are healthy:
```bash
# Run ClickHouse schema init
kubectl apply -n mereka-lms -f deploy/k8s/base/plugins/aspects/jobs.yml

# Wait for completion
kubectl wait --for=condition=complete job/clickhouse-init -n mereka-lms --timeout=120s
kubectl wait --for=condition=complete job/superset-init -n mereka-lms --timeout=300s
```

Verify ClickHouse tables were created:
```bash
CLICKHOUSE_PASSWORD="$(kubectl get secret aspects-secrets -n mereka-lms \
  -o jsonpath='{.data.clickhouse-password}' | base64 -d)"

kubectl exec -n mereka-lms deployment/clickhouse -- \
  clickhouse-client --user openedx --password "${CLICKHOUSE_PASSWORD}" \
  --query "SHOW TABLES IN openedx"
# Expected: enrollments, completions, xapi_events
```

- [ ] `clickhouse-init` Job completed successfully
- [ ] `superset-init` Job completed successfully
- [ ] ClickHouse tables (`xapi_events`, `enrollments`, `completions`) exist

---

### Step 1.11 — Verify Superset is Accessible

```bash
# Check ingress
kubectl get ingress superset -n mereka-lms
# Expected: host = analytics.academyv2.mereka.dev, TLS = superset-tls-dev

# Check cert is issued (may take up to 2 minutes)
kubectl get certificate superset-tls-dev -n mereka-lms
# Expected: READY = True

# HTTP check
curl -I https://analytics.academyv2.mereka.dev/health
# Expected: HTTP 200
```

- [ ] Superset ingress shows correct host (`analytics.academyv2.mereka.dev`)
- [ ] TLS certificate issued by Let's Encrypt
- [ ] `https://analytics.academyv2.mereka.dev/health` returns HTTP 200
- [ ] Login page accessible in browser

---

### Step 1.12 — Verify Wiring with QA Script

```bash
./scripts/qa/verify-aspects-wiring.sh
# Expected: all checks PASS (or SKIP where cluster access not available)
```

- [ ] `verify-aspects-wiring.sh` exits 0

---

## Phase 2 — Production (GKE / *.mereka.io)

**Gate conditions — all must be true before starting Phase 2**:
- [ ] Dev deployment stable for >= 2 weeks
- [ ] CTO sign-off obtained
- [ ] ClickHouse disk usage < 50% of 10Gi after 2-week dev run
- [ ] No data pipeline issues (check Superset shows expected data)
- [ ] PrometheusRules for Aspects added to `deploy/k8s/base/monitoring/`

### Pre-flight Checks (Prod)

- [ ] GCP Secret Manager secrets exist in `bbi-k8` project (created in Step 1.2)
- [ ] `external-secrets-gcp` service account has IAM bindings (created in Step 1.2)
- [ ] `analytics.academyv2.mereka.io` DNS record created in Cloudflare (gray cloud, Let's Encrypt)
- [ ] Authentik OAuth2 application `superset-analytics` created in production Authentik
  - Redirect URI: `https://analytics.academyv2.mereka.io/oauth-authorized/authentik`
  - Client secret provisioned as `MEREKA_LMS_ASPECTS_OAUTH_CLIENT_SECRET` in Infisical + GCP SM

### Step 2.1 — Add oauth-client-secret to ExternalSecret

Update the `aspects-secrets` ExternalSecret in `deploy/k8s/base/secrets/external-secrets.yaml`
to also include:
```yaml
    - secretKey: oauth-client-secret
      remoteRef:
        key: MEREKA_LMS_ASPECTS_OAUTH_CLIENT_SECRET
```

### Step 2.2 — Wire Aspects into Production Overlay

Edit `deploy/k8s/overlays/production/kustomization.yaml`:
1. Add `../../base/plugins/aspects` to `resources`
2. Add `ingress-aspects-superset.yaml` to `resources` (new file with prod hostname)
3. Add replica counts for clickhouse, superset, superset-worker

Create `deploy/k8s/overlays/production/ingress-openedx-mfe.yaml` update entry for the production analytics hostname:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: superset
  namespace: mereka-lms
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: 50m
spec:
  ingressClassName: nginx
  rules:
    - host: analytics.academyv2.mereka.io
      http:
        paths:
          - backend:
              service:
                name: superset
                port:
                  number: 8088
            path: /
            pathType: Prefix
  tls:
    - hosts:
        - analytics.academyv2.mereka.io
      secretName: superset-tls
```

Note: `storageClassName: standard-rwo` is correct for GKE — no patch needed in production.

- [ ] Production overlay updated with Aspects resources
- [ ] Production ingress file created with `analytics.academyv2.mereka.io`
- [ ] Changes committed, pushed, and ArgoCD synced

### Step 2.3 — Create Superset MySQL Database (Prod)

Same as Step 1.8 but targeting the production cluster.

```bash
# Switch kubectl context to production GKE
kubectl config use-context <prod-gke-context>

# Then run same commands as Step 1.8
```

- [ ] `superset` database and user created in production MySQL

### Step 2.4 — Run Init Jobs (Prod)

Same as Step 1.10 but in production context.

- [ ] `clickhouse-init` completed in prod
- [ ] `superset-init` completed in prod

### Step 2.5 — Verify Production

```bash
curl -I https://analytics.academyv2.mereka.io/health
# Expected: HTTP 200
```

- [ ] Production Superset accessible at `https://analytics.academyv2.mereka.io`
- [ ] OAuth2 login via Authentik works
- [ ] `verify-aspects-wiring.sh` exits 0 in production context

---

## Add Ralph (xAPI LRS) — Future Step

The current manifests do NOT include Ralph, the xAPI Learning Record Store.
Without Ralph, Open edX events do not flow into ClickHouse automatically.

This step is deferred until Aspects is stable in prod. When ready:
1. Add Ralph deployment/service to `deploy/k8s/base/plugins/aspects/`
2. Configure `EVENT_TRACKING_BACKENDS` in LMS settings to point to Ralph
3. See `docs/operations/ASPECTS_ANALYTICS_SETUP.md` → Data Pipeline section

- [ ] (FUTURE) Ralph manifests added to `deploy/k8s/base/plugins/aspects/`
- [ ] (FUTURE) LMS event routing configured

---

## Add PrometheusRules — Required Before Prod

Before Phase 2, add alerting rules to `deploy/k8s/base/monitoring/`. Reference alerts defined
in `docs/operations/ASPECTS_ANALYTICS_SETUP.md` → Monitoring section:

| Alert | Condition |
|-------|-----------|
| ClickHouseDiskPressure | PVC usage > 75% |
| ClickHouseDiskCritical | PVC usage > 85% |
| SupersetUnavailable | Superset pod not Ready > 5 min |
| ClickHouseUnavailable | `/ping` non-200 > 2 min |

- [ ] PrometheusRule resource created in `deploy/k8s/base/monitoring/`
- [ ] Alerts fire correctly in dev before prod promotion

---

## Rollback

If Aspects causes issues in dev, remove from kustomization:
1. Remove `../../base/plugins/aspects` and `ingress-aspects-superset.yaml` from
   `deploy/k8s/overlays/rke2-nonprod/kustomization.yaml`
2. Push to git and let ArgoCD reconcile
3. Data in ClickHouse PVC is preserved (PVC deletion policy: Retain)

If PVC needs cleanup:
```bash
kubectl delete pvc clickhouse-data -n mereka-lms
# WARNING: This deletes all analytics data
```

---

## References

- Manifests: `deploy/k8s/base/plugins/aspects/`
- Component overview: `docs/operations/ASPECTS_ANALYTICS_SETUP.md`
- Analytics spec: `specs/analytics-pipeline_spec.md`
- Data retention policy: `docs/operations/ANALYTICS_DATA_RETENTION.md`
- Verification script: `scripts/qa/verify-aspects-wiring.sh`
- Secrets pattern: `specs/secrets-management.md`
- rke2-nonprod overlay: `deploy/k8s/overlays/rke2-nonprod/kustomization.yaml`
- Production overlay: `deploy/k8s/overlays/production/kustomization.yaml`
