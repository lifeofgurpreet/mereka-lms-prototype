# HubSpot & Mux Deployment Guide
_Audience: Platform Eng + DevOps • Owner: Platform Team • Last verified: 2026-02-12_

This guide provides step-by-step procedures for deploying the HubSpot registration service and Mux video pipeline integration.

## Status

**Current State**: Both services have:
- ✅ Specifications complete
- ✅ Source code ready
- ❌ Not deployed to production
- ❌ Secrets not configured
- ❌ Observability not set up

**Blocking**: Requires secrets and production deployment decisions.

---

## HubSpot Registration Service

### Overview

**Purpose**: External user registration via HubSpot forms → automated Open edX account creation

**Spec**: `specs/external-registration-hubspot_spec.md` (26 ACs)
**Source Code**: `services/hubspot-webhook/` (Firebase Cloud Function)
**Feature Flag**: `HUBSPOT_REGISTRATION_ENABLED=false` (disabled by default)

### Architecture

```
HubSpot Form Submission
    ↓
Webhook POST → hubspot-registration-service (K8s)
    ↓
Fetch HubSpot Contact (16 profile fields)
    ↓
Create Open edX User (LMS API)
    ↓
Send Welcome Email (SendGrid, 5 language templates)
```

### Deployment Checklist

#### Phase 1: Secrets Configuration

**Required Secrets** (6 total):

```bash
# Set in Infisical (prod environment, root path)
INFISICAL=/home/gurpreet/projects/vps/infrastructure/scripts/infisical

# HubSpot OAuth credentials
${INFISICAL} secrets set MEREKA_LMS_HUBSPOT_CLIENT_ID="<from HubSpot app settings>" \
  --domain https://secrets.mereka.io/api --env prod --path /

${INFISICAL} secrets set MEREKA_LMS_HUBSPOT_CLIENT_SECRET="<from HubSpot app settings>" \
  --domain https://secrets.mereka.io/api --env prod --path /

${INFISICAL} secrets set MEREKA_LMS_HUBSPOT_REFRESH_TOKEN="<from HubSpot OAuth flow>" \
  --domain https://secrets.mereka.io/api --env prod --path /

# SendGrid (email delivery)
${INFISICAL} secrets set MEREKA_LMS_SENDGRID_API_KEY="<from SendGrid dashboard>" \
  --domain https://secrets.mereka.io/api --env prod --path /

# Open edX service account (for user creation)
${INFISICAL} secrets set MEREKA_LMS_OPENEDX_SERVICE_ACCOUNT_USERNAME="hubspot_service" \
  --domain https://secrets.mereka.io/api --env prod --path /

${INFISICAL} secrets set MEREKA_LMS_OPENEDX_SERVICE_ACCOUNT_PASSWORD="<generate secure password>" \
  --domain https://secrets.mereka.io/api --env prod --path /
```

**Sync to GCP Secret Manager**:

```bash
for secret in HUBSPOT_CLIENT_ID HUBSPOT_CLIENT_SECRET HUBSPOT_REFRESH_TOKEN \
              SENDGRID_API_KEY OPENEDX_SERVICE_ACCOUNT_USERNAME OPENEDX_SERVICE_ACCOUNT_PASSWORD; do
  gcloud secrets create MEREKA_LMS_${secret} \
    --data-file=<(${INFISICAL} secrets get MEREKA_LMS_${secret} --plain \
      --domain https://secrets.mereka.io/api --env prod --path /)
done
```

#### Phase 2: Create K8s Manifests

**Directory**: `deploy/k8s/base/apps/hubspot-registration/`

**1. Deployment** (`deployment.yaml`):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hubspot-registration
  namespace: mereka-lms
  labels:
    app.kubernetes.io/name: hubspot-registration
    app.kubernetes.io/component: webhook-handler
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: hubspot-registration
  template:
    metadata:
      labels:
        app.kubernetes.io/name: hubspot-registration
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: hubspot-registration
        image: asia-southeast1-docker.pkg.dev/mereka-lms/services/hubspot-registration:latest
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "8080"
        - name: HUBSPOT_REGISTRATION_ENABLED
          value: "true"
        envFrom:
        - secretRef:
            name: hubspot-registration-secrets
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
```

**2. Service** (`service.yaml`):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hubspot-registration
  namespace: mereka-lms
  labels:
    app.kubernetes.io/name: hubspot-registration
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app.kubernetes.io/name: hubspot-registration
```

**3. ExternalSecret** (`deploy/k8s/base/secrets/hubspot-registration-secrets.yaml`):

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: hubspot-registration-secrets
  namespace: mereka-lms
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcpsm-secret-store
    kind: ClusterSecretStore
  target:
    name: hubspot-registration-secrets
    creationPolicy: Owner
  data:
  - secretKey: HUBSPOT_CLIENT_ID
    remoteRef:
      key: MEREKA_LMS_HUBSPOT_CLIENT_ID
  - secretKey: HUBSPOT_CLIENT_SECRET
    remoteRef:
      key: MEREKA_LMS_HUBSPOT_CLIENT_SECRET
  - secretKey: HUBSPOT_REFRESH_TOKEN
    remoteRef:
      key: MEREKA_LMS_HUBSPOT_REFRESH_TOKEN
  - secretKey: SENDGRID_API_KEY
    remoteRef:
      key: MEREKA_LMS_SENDGRID_API_KEY
  - secretKey: OPENEDX_SERVICE_ACCOUNT_USERNAME
    remoteRef:
      key: MEREKA_LMS_OPENEDX_SERVICE_ACCOUNT_USERNAME
  - secretKey: OPENEDX_SERVICE_ACCOUNT_PASSWORD
    remoteRef:
      key: MEREKA_LMS_OPENEDX_SERVICE_ACCOUNT_PASSWORD
```

**4. Kustomization** (`kustomization.yaml`):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: mereka-lms

resources:
- deployment.yaml
- service.yaml

commonLabels:
  app.kubernetes.io/part-of: mereka-lms
```

#### Phase 3: Build & Push Container Image

```bash
# Build from services/hubspot-webhook/
cd services/hubspot-webhook

# Create Dockerfile (if not exists)
cat > Dockerfile <<'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
EXPOSE 8080
USER node
CMD ["node", "index.js"]
EOF

# Build and push
docker build -t asia-southeast1-docker.pkg.dev/mereka-lms/services/hubspot-registration:latest .
docker push asia-southeast1-docker.pkg.dev/mereka-lms/services/hubspot-registration:latest
```

#### Phase 4: Observability Setup

**PrometheusRule** (`deploy/k8s/base/monitoring/prometheusrule-hubspot.yaml`):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: hubspot-registration-alerts
  namespace: mereka-lms
spec:
  groups:
  - name: hubspot-registration
    interval: 30s
    rules:
    - alert: HubSpotRegistrationHighFailureRate
      expr: |
        (
          rate(hubspot_registration_failures_total[5m])
          /
          rate(hubspot_registration_attempts_total[5m])
        ) > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "HubSpot registration failure rate > 5%"
        description: "{{ $value | humanizePercentage }} of HubSpot registrations are failing"

    - alert: HubSpotRegistrationServiceDown
      expr: |
        sum(rate(hubspot_registration_success_total[15m])) == 0
        and
        sum(rate(hubspot_registration_attempts_total[15m])) > 0
      for: 15m
      labels:
        severity: critical
      annotations:
        summary: "No successful HubSpot registrations in 15 minutes"
        description: "HubSpot registration service may be down or misconfigured"

    - alert: HubSpotSignatureVerificationSpike
      expr: |
        rate(hubspot_signature_verification_failures_total[5m]) > 10
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High rate of webhook signature verification failures"
        description: "Possible webhook configuration issue or security incident"

    - alert: HubSpotDLQBacklog
      expr: |
        hubspot_dlq_message_count > 100
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "HubSpot dead letter queue backlog growing"
        description: "{{ $value }} messages in DLQ, investigate failed registrations"

    - alert: HubSpotEmailFailureRate
      expr: |
        (
          rate(hubspot_email_send_failures_total[10m])
          /
          rate(hubspot_email_send_attempts_total[10m])
        ) > 0.10
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "HubSpot welcome email failure rate > 10%"
        description: "Email delivery issues, check SendGrid integration"
```

**ServiceMonitor** (`deploy/k8s/base/monitoring/servicemonitor-hubspot.yaml`):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: hubspot-registration
  namespace: mereka-lms
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: hubspot-registration
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

#### Phase 5: Deploy & Verify

```bash
# 1. Update kustomizations
cat >> deploy/k8s/base/kustomization.yaml <<EOF
- apps/hubspot-registration
EOF

cat >> deploy/k8s/base/secrets/kustomization.yaml <<EOF
- hubspot-registration-secrets.yaml
EOF

cat >> deploy/k8s/base/monitoring/kustomization.yaml <<EOF
- prometheusrule-hubspot.yaml
- servicemonitor-hubspot.yaml
EOF

# 2. Apply to production
kubectl apply -k deploy/k8s/overlays/production

# 3. Verify deployment
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=hubspot-registration
kubectl get externalsecrets -n mereka-lms hubspot-registration-secrets
kubectl get prometheusrules -n mereka-lms hubspot-registration-alerts

# 4. Run verification scripts
./scripts/qa/verify-hubspot-k8s-security.sh
./scripts/qa/verify-hubspot-secrets.sh
./scripts/qa/verify-hubspot-alerts.sh
```

---

## Mux Video Pipeline

### Overview

**Purpose**: Video transcoding, hosting, and delivery via Mux API

**Spec**: `specs/video-pipeline-delivery_spec.md` (22 ACs)
**Integration**: Open edX XBlock for Mux video player

### Architecture

```
Course Author Uploads Video
    ↓
Open edX XBlock → Mux API (create asset)
    ↓
Mux Transcodes Video
    ↓
Webhook Notification → Open edX
    ↓
Learner Watches via Mux Player
```

### Deployment Checklist

#### Phase 1: Secrets Configuration

**Required Secrets** (2 total):

```bash
INFISICAL=/home/gurpreet/projects/vps/infrastructure/scripts/infisical

# Mux API credentials (from https://dashboard.mux.com/settings/access-tokens)
${INFISICAL} secrets set MEREKA_LMS_MUX_TOKEN_ID="<from Mux dashboard>" \
  --domain https://secrets.mereka.io/api --env prod --path /

${INFISICAL} secrets set MEREKA_LMS_MUX_TOKEN_SECRET="<from Mux dashboard>" \
  --domain https://secrets.mereka.io/api --env prod --path /
```

**Sync to GCP Secret Manager**:

```bash
gcloud secrets create MEREKA_LMS_MUX_TOKEN_ID \
  --data-file=<(${INFISICAL} secrets get MEREKA_LMS_MUX_TOKEN_ID --plain \
    --domain https://secrets.mereka.io/api --env prod --path /)

gcloud secrets create MEREKA_LMS_MUX_TOKEN_SECRET \
  --data-file=<(${INFISICAL} secrets get MEREKA_LMS_MUX_TOKEN_SECRET --plain \
    --domain https://secrets.mereka.io/api --env prod --path /)
```

#### Phase 2: Update ExternalSecrets

**Edit**: `deploy/k8s/base/secrets/external-secrets.yaml`

Add to the `openedx-secrets` ExternalSecret:

```yaml
  data:
  # ... existing secrets ...
  - secretKey: MUX_TOKEN_ID
    remoteRef:
      key: MEREKA_LMS_MUX_TOKEN_ID
  - secretKey: MUX_TOKEN_SECRET
    remoteRef:
      key: MEREKA_LMS_MUX_TOKEN_SECRET
```

#### Phase 3: Configure Open edX Settings

**Edit**: `infrastructure/tutor/plugins/mereka_lms.py` or `apply-patches.sh`

Add to LMS/CMS production settings:

```python
# Mux Video Pipeline
MUX_TOKEN_ID = os.environ.get('MUX_TOKEN_ID', '')
MUX_TOKEN_SECRET = os.environ.get('MUX_TOKEN_SECRET', '')
MUX_ENABLED = bool(MUX_TOKEN_ID and MUX_TOKEN_SECRET)
```

#### Phase 4: Observability Setup

**PrometheusRule** (`deploy/k8s/base/monitoring/prometheusrule-mux.yaml`):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mux-video-alerts
  namespace: mereka-lms
spec:
  groups:
  - name: mux-video
    interval: 1h
    rules:
    - alert: MuxDeliveryMinutesWarning
      expr: |
        mux_delivery_minutes_monthly > 80000
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "Mux delivery minutes > 80% of 100k limit"
        description: "{{ $value }} minutes used this month, approaching limit"

    - alert: MuxDeliveryMinutesCritical
      expr: |
        mux_delivery_minutes_monthly > 95000
      for: 1h
      labels:
        severity: critical
      annotations:
        summary: "Mux delivery minutes > 95% of 100k limit"
        description: "{{ $value }} minutes used, take action to prevent overage"

    - alert: MuxAssetErrored
      expr: |
        mux_asset_status{status="errored"} > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Mux asset in error state"
        description: "Asset {{ $labels.asset_id }} failed processing"

    - alert: MuxSecretSyncFailed
      expr: |
        externalsecret_sync_status{secret="openedx-secrets",key=~"MUX_.*"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Mux secret sync failed"
        description: "ExternalSecret for {{ $labels.key }} not syncing"
```

#### Phase 5: Deploy & Verify

```bash
# 1. Apply secrets
kubectl apply -f deploy/k8s/base/secrets/external-secrets.yaml

# 2. Verify secret sync
kubectl get externalsecrets -n mereka-lms openedx-secrets -o jsonpath='{.status.conditions[0].status}'
# Should show: True

kubectl get secret -n mereka-lms openedx-secrets -o jsonpath='{.data}' | grep MUX
# Should show: MUX_TOKEN_ID and MUX_TOKEN_SECRET

# 3. Restart pods to pick up new secrets
kubectl rollout restart deployment -n mereka-lms lms cms

# 4. Verify configuration
kubectl exec -n mereka-lms deployment/lms -- python manage.py lms shell -c "
import os
print('MUX_ENABLED:', bool(os.environ.get('MUX_TOKEN_ID')))
"
# Should show: MUX_ENABLED: True

# 5. Run verification scripts
./scripts/qa/verify-mux-secrets.sh
./scripts/qa/verify-mux-alerts.sh
```

---

## Post-Deployment Verification

### HubSpot Service

```bash
# 1. Service health
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=hubspot-registration
# Should show: 2/2 Running

curl https://hubspot.mereka.io/health
# Should show: {"status":"healthy"}

# 2. Test webhook (from HubSpot dashboard)
# Send test webhook, check logs:
kubectl logs -n mereka-lms -l app.kubernetes.io/name=hubspot-registration --tail=50

# 3. Verify Prometheus metrics
kubectl port-forward -n mereka-lms svc/hubspot-registration 8080:80
curl http://localhost:8080/metrics | grep hubspot_registration
```

### Mux Integration

```bash
# 1. Check secrets loaded
kubectl exec -n mereka-lms deployment/lms -- env | grep MUX_TOKEN
# Should show: MUX_TOKEN_ID and MUX_TOKEN_SECRET (masked)

# 2. Test Mux API connection
kubectl exec -n mereka-lms deployment/lms -- python -c "
import requests
import os
token_id = os.environ['MUX_TOKEN_ID']
token_secret = os.environ['MUX_TOKEN_SECRET']
resp = requests.get('https://api.mux.com/video/v1/assets', auth=(token_id, token_secret))
print('Status:', resp.status_code)
"
# Should show: Status: 200

# 3. Verify monitoring
kubectl get prometheusrules -n mereka-lms mux-video-alerts
```

---

## Rollback Procedures

### HubSpot Service

```bash
# 1. Disable service (keep deployment)
kubectl scale deployment -n mereka-lms hubspot-registration --replicas=0

# 2. Remove from routing (if exposed via Ingress)
kubectl delete ingress -n mereka-lms hubspot-registration

# 3. Full removal
kubectl delete -k deploy/k8s/base/apps/hubspot-registration
```

### Mux Integration

```bash
# 1. Disable in Open edX settings
kubectl set env deployment -n mereka-lms lms cms \
  MUX_TOKEN_ID="" MUX_TOKEN_SECRET=""

# 2. Remove secrets from ExternalSecret
# Edit deploy/k8s/base/secrets/external-secrets.yaml, remove MUX entries
kubectl apply -f deploy/k8s/base/secrets/external-secrets.yaml
```

---

## Cost Considerations

### HubSpot Service

- **Compute**: ~$36/month (2 pods × n2-standard-4 node fraction)
- **Network**: Minimal (webhooks are small)
- **SendGrid**: $14.95/month (Essentials plan, 50k emails)

### Mux Integration

- **Delivery**: $1.60 per 1,000 delivered minutes
- **Storage**: $0.05 per GB-month
- **Expected**: ~$150-200/month for 100k delivery minutes

---

## Troubleshooting

### HubSpot Service Issues

**Problem**: Webhook signature verification fails
**Solution**: Verify `HUBSPOT_CLIENT_SECRET` matches HubSpot app settings

**Problem**: User creation fails with 401
**Solution**: Check Open edX service account credentials, ensure account exists and has permissions

**Problem**: Email delivery fails
**Solution**: Check SendGrid API key, verify domain authentication

### Mux Integration Issues

**Problem**: Video upload fails with 401
**Solution**: Verify Mux API credentials, check token has correct permissions

**Problem**: Videos not transcoding
**Solution**: Check Mux dashboard for asset status, verify webhook endpoint

**Problem**: Delivery minutes spike unexpectedly
**Solution**: Check for video loop attacks, verify caching is enabled

---

## Related Documentation

- **Specs**:
  - `specs/external-registration-hubspot_spec.md` (HubSpot)
  - `specs/video-pipeline-delivery_spec.md` (Mux)
- **Runbooks**:
  - `docs/operations/runbooks/emergency-rollback.md` (Rollback procedures)
  - `docs/operations/runbooks/database-issues.md` (If user creation fails)
- **Guides**:
  - `docs/operations/guides/SECRETS_MANAGEMENT_GUIDE.md` (Secret management)
  - `docs/operations/guides/OBSERVABILITY_GUIDE.md` (Monitoring setup)

---

**Last Updated**: 2026-02-12
**Owner**: Platform Team
**Status**: Documentation complete, awaiting deployment approval
