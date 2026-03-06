# Kubectl Cheatsheet - Mereka LMS

Quick reference for common kubectl operations in Mereka LMS.

---

## Context Setup

```bash
# Set GKE cluster context
kubectl config use-context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster

# Set default namespace (avoids -n flag)
kubectl config set-context --current --namespace=mereka-lms

# Verify current context
kubectl config current-context
```

---

## Pod Operations

### Viewing Pods

```bash
# List all pods
kubectl get pods

# List pods with labels
kubectl get pods --show-labels

# List pods by component
kubectl get pods -l app.kubernetes.io/name=lms
kubectl get pods -l app.kubernetes.io/name=cms

# Wide output (shows node, IP)
kubectl get pods -o wide

# Watch pod status (auto-refresh)
kubectl get pods -w
```

### Pod Logs

```bash
# Last 100 lines
kubectl logs deployment/lms --tail=100

# Follow logs (live stream)
kubectl logs -f deployment/lms

# All containers in pod
kubectl logs pod-name --all-containers

# Previous container (after crash)
kubectl logs pod-name --previous

# Filter by label
kubectl logs -l app.kubernetes.io/name=lms --tail=50
```

### Pod Shell Access

```bash
# Interactive bash shell
kubectl exec -it deployment/lms -- bash

# Run single command
kubectl exec deployment/lms -- ls /openedx/edx-platform

# Django shell
kubectl exec -it deployment/lms -- python manage.py lms shell

# Run management command
kubectl exec deployment/lms -- python manage.py lms migrate --check
```

---

## Service Debugging

### Service Status

```bash
# List all services
kubectl get svc

# Service + endpoints (critical pairing)
kubectl get svc,endpoints

# Service details
kubectl describe svc lms

# Service selector (must match pod labels)
kubectl get svc lms -o jsonpath='{.spec.selector}'
```

### Endpoint Checks (CRITICAL)

```bash
# View all endpoints
kubectl get endpoints

# Empty endpoints = no traffic routing
# Example: lms <none> means service can't find pods

# Check specific endpoint
kubectl get endpoints lms -o yaml

# Fix selector mismatches (most common issue)
/home/gurpreet/projects/k8s/mereka-lms/scripts/infra/fix-service-selectors.sh
```

### Service Connectivity Tests

```bash
# Test internal service (from temp pod)
kubectl run curl-test --rm -i --image=curlimages/curl --restart=Never \
  -- curl -I http://lms:8000

# Port forward to local machine
kubectl port-forward svc/lms 8000:8000

# Test forwarded port
curl http://localhost:8000
```

---

## Scaling & Restarts

### Manual Scaling

```bash
# Scale deployment
kubectl scale deployment/lms --replicas=3

# Scale multiple
for d in lms cms lms-worker cms-worker; do
  kubectl scale deployment/$d --replicas=2
done

# Check replica status
kubectl get deployment lms
```

### Restarts

```bash
# Restart single deployment (zero-downtime)
kubectl rollout restart deployment/lms

# Restart all Open edX services (recommended order)
for svc in lms cms discovery ecommerce notes xqueue; do
  kubectl rollout restart deployment/$svc
done

# Then restart reverse proxy
kubectl rollout restart deployment/caddy

# CRITICAL: Always verify endpoints after restart
kubectl get endpoints
```

### Rollout Management

```bash
# Watch rollout progress
kubectl rollout status deployment/lms

# Rollback to previous version
kubectl rollout undo deployment/lms

# Rollback to specific revision
kubectl rollout undo deployment/lms --to-revision=3

# View rollout history
kubectl rollout history deployment/lms
```

---

## Secrets & ConfigMaps

### Viewing Secrets

```bash
# List secrets
kubectl get secrets

# Secret details (values base64-encoded)
kubectl get secret openedx-secret -o yaml

# Decode specific key
kubectl get secret openedx-secret -o jsonpath='{.data.SECRET_KEY}' | base64 -d

# All keys decoded
kubectl get secret openedx-secret -o json | \
  jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'
```

### ConfigMaps

```bash
# List configmaps
kubectl get configmaps

# View configmap data
kubectl get configmap openedx-settings-lms -o yaml

# Extract specific key
kubectl get configmap openedx-settings-lms -o jsonpath='{.data.production\.py}'
```

### Apply After Changes

```bash
# After modifying ConfigMap/Secret via ExternalSecret
kubectl rollout restart deployment/lms
kubectl rollout restart deployment/cms

# Verify pods picked up changes
kubectl logs deployment/lms --tail=20 | grep -i "config"
```

---

## Resource Usage

```bash
# Pod resource usage
kubectl top pods

# Node resource usage
kubectl top nodes

# Sort by CPU
kubectl top pods --sort-by=cpu

# Sort by memory
kubectl top pods --sort-by=memory
```

---

## Troubleshooting

### 5-Command Site-Down Check

```bash
# 1. Are pods running?
kubectl get pods

# 2. Do services have endpoints? (Empty = NO TRAFFIC)
kubectl get endpoints

# 3. Check service selectors
kubectl get svc -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.selector}{"\n"}{end}'

# 4. LoadBalancer status
kubectl get svc caddy

# 5. Test internal connectivity
kubectl run curl-test --rm -i --image=curlimages/curl --restart=Never -- curl -I http://lms:8000
```

### Common Fixes

```bash
# Fix service selector mismatches (most common)
/home/gurpreet/projects/k8s/mereka-lms/scripts/infra/fix-service-selectors.sh

# Clear crash loop (force restart)
kubectl delete pod <pod-name>

# Drain node for maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon node after maintenance
kubectl uncordon <node-name>
```

### Describe Resources (Deep Debug)

```bash
# Pod details + events
kubectl describe pod <pod-name>

# Deployment details
kubectl describe deployment lms

# Service details (shows endpoint selection)
kubectl describe svc lms

# Node details (capacity, conditions)
kubectl describe node <node-name>
```

---

## Namespace Shortcuts

```bash
# All namespaces
kubectl get pods --all-namespaces
kubectl get pods -A  # short form

# Specific namespace (when not set as default)
kubectl get pods -n mereka-lms

# Create namespace
kubectl create namespace test-env

# Delete namespace (deletes all resources)
kubectl delete namespace test-env
```

---

## Image Updates

```bash
# Update image tag (triggers rolling update)
kubectl set image deployment/lms \
  lms=ghcr.io/biji-biji-initiative/mereka-lms/openedx:20240212-ulmo-abc1234

# Update via kustomization (recommended)
kubectl apply -k deploy/k8s/overlays/production

# Verify new image
kubectl get deployment lms -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## Quick Filters

### By Label

```bash
# Single label
kubectl get pods -l app.kubernetes.io/name=lms

# Multiple labels (AND)
kubectl get pods -l app.kubernetes.io/name=lms,app.kubernetes.io/component=web

# Label exists
kubectl get pods -l app.kubernetes.io/name

# Label value in set
kubectl get pods -l 'app.kubernetes.io/name in (lms,cms)'
```

### By Field

```bash
# Running pods only
kubectl get pods --field-selector=status.phase=Running

# Pending pods
kubectl get pods --field-selector=status.phase=Pending

# Pods on specific node
kubectl get pods --field-selector=spec.nodeName=node-1
```

---

## Common Service Names

| Service | Port | URL |
|---------|------|-----|
| lms | 8000 | https://academyv2.mereka.io |
| cms | 8000 | https://studio.academyv2.mereka.io |
| mfe | 8002 | https://apps.academyv2.mereka.io |
| discovery | 8381 | https://discovery.academyv2.mereka.io |
| ecommerce | 8130 | (internal) |
| caddy | 80/443 | (reverse proxy) |
| mysql | 3306 | (internal) |
| redis | 6379 | (internal) |

---

## See Also

- [Tutor Commands](./tutor-commands.md) - Tutor-specific operations
- [Verification Scripts](./verification-scripts.md) - Automated checks
- [Common Troubleshooting](./common-troubleshooting.md) - 1-page debug guide
- [K8s Operations Guide](../../guides/admin/K8S_OPERATIONS_GUIDE.md) - Full operational procedures
