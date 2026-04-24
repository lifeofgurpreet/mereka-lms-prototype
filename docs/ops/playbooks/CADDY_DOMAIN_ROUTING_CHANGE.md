# Caddy / Domain Routing Change Playbook

_Audience: Developers, Operators · Owner: Platform Team · Status: active_

## Layer Ownership

| Layer | Owner | Artifact |
|---|---|---|
| **Source (tenant truth)** | App repo | `deploy/k8s/tenancy/tenant-registry.yaml` |
| **Source (routing)** | App repo | `deploy/k8s/base/apps/caddy/Caddyfile` |
| **Source (DNS)** | Infra | Cloudflare DNS records (`infrastructure/cloudflare/`) |
| **Promotion** | Kustomize overlays | `deploy/k8s/overlays/*/` |
| **Realization** | ArgoCD | ConfigMap → Caddy pod reload |
| **Runtime proof** | curl + smoke scripts | `scripts/qa/verify-rke2-tenant-routes.sh` |

## Before You Start

- [ ] `git status` — worktree is clean on a feature branch off `main`
- [ ] Know the exact domain(s) affected and their tenant ownership
- [ ] Read `deploy/k8s/tenancy/tenant-registry.yaml` — every domain in Ingress/Caddyfile/ALLOWED_HOSTS MUST appear here
- [ ] Confirm DNS record exists or will be created (Cloudflare)
- [ ] Confirm TLS: Caddy uses `auto_https off` — TLS terminates at ingress/tunnel, not Caddy
- [ ] Know if this is a new domain, route change, or upstream change

## Steps

### 1. Update tenant registry (if new domain)

```bash
vim deploy/k8s/tenancy/tenant-registry.yaml
# Add domain under the correct tenant
# Set status: active, auth_class, proof_priority
# Every domain in Caddyfile MUST be registered here
```

### 2. Update Caddyfile

```bash
vim deploy/k8s/base/apps/caddy/Caddyfile
# Add/modify route block
# Use the (proxy) snippet for reverse_proxy directives
# Example new domain block:
#   newdomain.example.com {
#       import proxy "lms:8000"
#   }
```

### 3. Update Django ALLOWED_HOSTS and CSRF

If the domain needs to reach LMS/CMS, update the Tutor plugin:

```bash
vim infrastructure/tutor/plugins/mereka_lms.py
# Add domain to:
#   - ALLOWED_HOSTS
#   - CSRF_TRUSTED_ORIGINS
#   - CORS_ORIGIN_WHITELIST (if API access needed)
# Then regenerate:
./scripts/infra/tutor-config-save.sh
```

### 4. Update Kustomize overlay (if environment-specific)

```bash
# Check if overlay patches Caddyfile or ConfigMap
vim deploy/k8s/overlays/rke2-nonprod/kustomization.yaml
# Render and verify
kubectl kustomize deploy/k8s/overlays/rke2-nonprod/ | grep -A20 "newdomain"
```

### 5. Create DNS record (if new domain)

```bash
# In Cloudflare dashboard or infrastructure/cloudflare/
# Point domain to cluster ingress IP or Cloudflare Tunnel
# Ensure proxy (orange cloud) is enabled for Cloudflare Tunnel domains
```

### 6. Verify Kustomize render

```bash
./scripts/qa/verify-kustomize-render.sh
./scripts/qa/verify-rke2-tenant-routes.sh
./scripts/qa/verify-domain-authority-chain.sh
```

### 7. Push, merge, wait for ArgoCD

```bash
git add deploy/k8s/tenancy/tenant-registry.yaml \
       deploy/k8s/base/apps/caddy/Caddyfile \
       infrastructure/tutor/plugins/mereka_lms.py
git commit -m "feat(routing): add <domain> to Caddy and tenant registry"
git push origin HEAD
# After merge → ArgoCD syncs new Caddyfile ConfigMap → Caddy reloads
```

### 8. Verify runtime

```bash
# Route proof — domain resolves and returns expected upstream
curl -sI https://newdomain.example.com/ | head -10
# Caddy admin API (from inside cluster)
kubectl exec -n mereka-lms-dev deploy/caddy -- \
  curl -s http://localhost:2019/config/ | python3 -m json.tool | head -30
```

## Verify

1. **Registry proof**: domain appears in `tenant-registry.yaml` with `status: active`
2. **Caddyfile proof**: `grep "newdomain" deploy/k8s/base/apps/caddy/Caddyfile` matches
3. **Kustomize proof**: `kubectl kustomize` output includes the route
4. **DNS proof**: `dig +short newdomain.example.com` returns expected IP/CNAME
5. **Route proof**: `curl -sI https://newdomain.example.com/` returns 200 (or expected redirect)
6. **Tenant proof**: `./scripts/qa/verify-rke2-tenant-routes.sh` exits 0
7. **CSRF proof**: POST request with correct `Origin` header succeeds (no 403)

## Never Do

- **Never change DNS without updating `tenant-registry.yaml`** — registry is tenant truth
- **Never change Caddyfile without runtime route proof** — a valid config ≠ a working route
- **Never add a domain to Caddyfile that isn't in `tenant-registry.yaml`** — breaks audit chain
- **Never edit the live ConfigMap in-cluster** — ArgoCD will overwrite it
- **Never assume DNS propagation is instant** — check with `dig` before declaring success
- **Never change `auto_https` in Caddy** — TLS terminates upstream (ingress/tunnel), not at Caddy
- **Never skip ALLOWED_HOSTS/CSRF updates** — Django will reject requests on the new domain

## Rollback

### Caddyfile rollback

```bash
git revert <commit-sha>
git push origin HEAD
# ArgoCD syncs reverted Caddyfile → Caddy reloads
```

### Emergency Caddy reload

```bash
# Force Caddy to reload config from ConfigMap
kubectl rollout restart deployment/caddy -n mereka-lms-dev
kubectl rollout status deployment/caddy -n mereka-lms-dev
```

### DNS rollback

```bash
# In Cloudflare: delete or update the DNS record
# DNS changes propagate within seconds when using Cloudflare proxy
```
