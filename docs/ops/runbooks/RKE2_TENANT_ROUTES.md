# RKE2 Nonprod — Tenant Route Matrix

_Audience: Platform Engineering + Ops_
_Last updated: 2026-02-24_
_Verification script: `scripts/qa/verify-rke2-tenant-routes.sh`_

This document describes every public-facing hostname on the `rke2-nonprod` cluster and its
expected routing, auth state, and HTTP behavior. Use it as the ground-truth reference for
diagnosing 404s, 502s, TLS errors, and broken redirects in the nonprod environment.

---

## Quick Verification

```bash
# Full readiness gate (offline + online — exits 1 on any FAIL)
./scripts/qa/verify-rke2-tenant-routes.sh --readiness-gate

# Manifest-only (no cluster access required)
./scripts/qa/verify-rke2-tenant-routes.sh --offline

# Live HTTP probes (requires kubectl + cluster access)
./scripts/qa/verify-rke2-tenant-routes.sh --online

# Override context or namespace
KUBE_CONTEXT=kind-mereka ./scripts/qa/verify-rke2-tenant-routes.sh --offline
```

---

## Route Matrix

### Core Surfaces (nonprod)

| Surface | Nonprod domain | Caddy backend | Auth state | Notes |
|---------|---------------|---------------|------------|-------|
| **LMS** | `academyv2.mereka.dev` | `lms:8000` | Open edX session | Main learner site |
| **Preview LMS** | `preview.academyv2.mereka.dev` | `lms:8000` | Open edX session | Same pod as LMS — used by Studio "Preview" |
| **Studio / CMS** | `studio.academyv2.mereka.dev` | `cms:8000` | OAuth2 → LMS → Authentik | Course authoring |
| **MFE apps** | `apps.academyv2.mereka.dev` | `mfe:8002` | LMS session (cookie) | React MFEs: authn, learning, account, etc. |
| **Discovery** | `discovery.academyv2.mereka.dev` | `discovery:8000` | LMS session | Course catalog API |
| **Notes** | `notes.academyv2.mereka.dev` | `notes:8000` | LMS session | Learner annotation service |
| **Credentials** | `credentials.academyv2.mereka.dev` | `credentials:8000` | LMS session | Certificate + badge issuance |
| **Forum API** | `academyv2.mereka.dev` (LMS URL) | `lms:8000` | LMS session | Forum v2 in-process — no standalone domain |

> **Forum v2** runs integrated into the LMS process. There is no separate forum container or
> Caddy block. Discussion API endpoints (`/api/discussion/v2/`) are served by the LMS pod at
> `academyv2.mereka.dev`. The `forum.academyv2.mereka.dev` ingress rule routes to the same
> caddy → lms:8000 path as the main LMS domain.

> **Oscar ecommerce is deprecated.** Purchase Gateway handles payments. The
> `ecommerce.academyv2.mereka.dev` hostname is not probed by the verification script.

---

## Expected HTTP Behaviors (Anonymous)

The following table shows what an unauthenticated HTTP GET should return for each surface.
All checks are performed by `verify-rke2-tenant-routes.sh --online`.

| URL | Expected status | Notes |
|-----|----------------|-------|
| `https://academyv2.mereka.dev/` | 200 or 302 | LMS homepage — may redirect to login |
| `https://academyv2.mereka.dev/login` | 200 or 302 | Login page |
| `https://academyv2.mereka.dev/register` | 200 or 302 | Registration page |
| `https://academyv2.mereka.dev/dashboard` | 200 or 302 | Redirects to authn if not logged in |
| `https://academyv2.mereka.dev/heartbeat` | 200 | Health check — no auth required |
| `https://academyv2.mereka.dev/api/user/v1/me` | 401 | User API — auth required |
| `https://academyv2.mereka.dev/api/courses/v2/` | 200 or 401 | Courses API |
| `https://academyv2.mereka.dev/api/discussion/v2/courses/` | 401 or 403 | Forum API v2 — auth required |
| `https://academyv2.mereka.dev/api/discussion/v1/courses/` | 401 or 404 | Forum API v1 — deprecated |
| `https://preview.academyv2.mereka.dev/` | 200 or 302 | Same as LMS |
| `https://studio.academyv2.mereka.dev/` | 200 or 302 | Redirects to login |
| `https://apps.academyv2.mereka.dev/authn/login` | 200 | MFE login page |
| `https://apps.academyv2.mereka.dev/authn/register` | 200 | MFE registration page |
| `https://discovery.academyv2.mereka.dev/health/` | 200 | Discovery health |
| `https://notes.academyv2.mereka.dev/health` | 200 | Notes health |
| `https://credentials.academyv2.mereka.dev/health/` | 200 | Credentials health |

---

## HTTP→HTTPS Redirect Behavior

The nginx ingress controller is configured with `ssl-redirect: "true"` on all Ingress resources.
Plain HTTP (port 80) requests must return 301 or 302 to the HTTPS equivalent.

```bash
# Should return 301 or 302
curl -sI http://academyv2.mereka.dev/ | head -3
curl -sI http://studio.academyv2.mereka.dev/ | head -3
curl -sI http://apps.academyv2.mereka.dev/ | head -3
```

If port 80 is blocked at the network level in nonprod, these checks will be skipped
rather than failed.

---

## TLS Certificates

All nonprod hostnames use Let's Encrypt certificates issued by cert-manager via the
`letsencrypt-prod` ClusterIssuer. TLS is terminated at the nginx ingress controller.

| Ingress resource | Hosts covered | TLS secret |
|-----------------|---------------|-----------|
| `openedx-lms` | `academyv2.mereka.dev`, `preview.academyv2.mereka.dev`, `discovery.academyv2.mereka.dev`, `notes.academyv2.mereka.dev`, `credentials.academyv2.mereka.dev`, `forum.academyv2.mereka.dev` | `openedx-lms-tls` |
| `openedx-studio` | `studio.academyv2.mereka.dev` | `openedx-studio-tls` |
| `openedx-mfe` | `apps.academyv2.mereka.dev` | `openedx-mfe-tls` |

Verify cert issuance:
```bash
kubectl --context rke2-nonprod get certificate -n mereka-lms
kubectl --context rke2-nonprod describe certificate openedx-lms-tls -n mereka-lms
```

Check cert expiry with openssl:
```bash
echo | openssl s_client -connect academyv2.mereka.dev:443 -servername academyv2.mereka.dev 2>/dev/null \
  | openssl x509 -noout -enddate
```

---

## Ingress Architecture

```
Browser
  └── Port 443 (HTTPS)
        └── nginx Ingress Controller (rke2-nonprod node hostPort)
              └── routes by Host header
                    ├── academyv2.mereka.dev           → caddy:80 → lms:8000
                    ├── preview.academyv2.mereka.dev   → caddy:80 → lms:8000
                    ├── studio.academyv2.mereka.dev    → caddy:80 → cms:8000
                    ├── apps.academyv2.mereka.dev      → caddy:80 → mfe:8002
                    ├── discovery.academyv2.mereka.dev → caddy:80 → discovery:8000
                    ├── notes.academyv2.mereka.dev     → caddy:80 → notes:8000
                    ├── credentials.academyv2.mereka.dev → caddy:80 → credentials:8000
                    └── forum.academyv2.mereka.dev     → caddy:80 → lms:8000 (in-process)
```

TLS is terminated at nginx. Caddy receives plain HTTP from the ingress controller.
Caddy then routes by hostname to the appropriate backend pod.

---

## Forum v2 Routing Detail

Forum v2 (`openedx-forum`, Python) is integrated **into the LMS process** as of Tutor v19+.
There is no standalone forum container. Key implications:

- No separate forum Deployment or Service in Kubernetes
- No separate Caddy block for forum
- `forum.academyv2.mereka.dev` routes via Caddy to `lms:8000` — the LMS pod handles it
- Forum API endpoints are at `/api/discussion/v2/` on the LMS domain
- Meilisearch provides search (replaces Elasticsearch)

Verify in-process forum:
```bash
# Should return 401 (unauthenticated) — proves the endpoint exists and LMS handles it
curl -sI https://academyv2.mereka.dev/api/discussion/v2/courses/ | head -3
```

---

## Domain Environment Variables

The `rke2-nonprod` overlay patches domain env vars on the LMS and CMS Deployments via
`deploy/k8s/overlays/rke2-nonprod/patches/domain-env.yaml`:

| Variable | Value (nonprod) |
|----------|----------------|
| `MEREKA_LMS_DOMAIN` | `academyv2.mereka.dev` |
| `MEREKA_SCHEME` | `https` |
| `MEREKA_COOKIE_DOMAIN` | `.academyv2.mereka.dev` |
| `LMS_BASE_URL` | `https://academyv2.mereka.dev` |
| `MFE_BASE_URL` | `https://apps.academyv2.mereka.dev` |

These override the base values so LMS/CMS correctly construct absolute URLs for auth
redirects, OAuth2 flows, and cookie domain scoping in nonprod.

---

## ExternalSecrets (nonprod)

Nonprod uses **Infisical** as the secrets backend (not GCP Secret Manager).
The `externalsecrets-infisical.yaml` patch switches all ExternalSecret `secretStoreRef`
entries from `gcp-secret-manager` to `infisical-secret-store`.

Prerequisites:
```bash
# ClusterSecretStore must be Ready before deploying
kubectl --context rke2-nonprod get clustersecretstore infisical-secret-store
# Expected: READY=True

# Check ExternalSecret sync status
kubectl --context rke2-nonprod get externalsecret -n mereka-lms
# Expected: STATUS=SecretSynced for all entries
```

---

## Troubleshooting

### 502 Bad Gateway on any surface

1. Check the caddy pod is Running: `kubectl --context rke2-nonprod get pods -n mereka-lms -l app.kubernetes.io/name=caddy`
2. Check caddy endpoints are populated: `kubectl --context rke2-nonprod get endpoints caddy -n mereka-lms`
3. Check the backend pod (lms, cms, etc.) is Running and has populated endpoints

### 404 on LMS or Studio

1. Verify the Ingress rule exists: `kubectl --context rke2-nonprod get ingress -n mereka-lms`
2. Verify the hostname is in the Ingress rules list
3. Check nginx ingress controller is pinned to the correct node: `kubectl get pods -n ingress-nginx -o wide`

### TLS certificate not issued

1. Check cert-manager is installed: `kubectl --context rke2-nonprod get pods -n cert-manager`
2. Check the Certificate resource status: `kubectl --context rke2-nonprod describe certificate -n mereka-lms`
3. Verify DNS records for `*.academyv2.mereka.dev` point to the rke2-nonprod ingress IP

### Auth redirect loop on Studio

Studio OAuth2 flow: Studio → LMS → Authentik → LMS → Studio.
If this loops, check:
- `SESSION_COOKIE_NAME` in Studio settings must be `"studio_session_id"` (not `"sessionid"`)
- `SESSION_COOKIE_SAMESITE` must be `"None"` (not `"Lax"`)
- Authentik OIDC provider is reachable from inside the cluster

### Empty service endpoints

Run `./scripts/infra/fix-service-selectors.sh` to repair selector mismatches.

---

## Related Documents

- **Verification script**: `scripts/qa/verify-rke2-tenant-routes.sh`
- **LMS RKE2 validation**: `docs/runbooks/operations/LMS_RKE2_VALIDATION.md`
- **Route matrix (production)**: `docs/reference/operations/ROUTE_MATRIX.md`
- **RKE2 dev readiness**: `docs/runbooks/operations/RKE2_DEV_READINESS.md`
- **Troubleshooting**: `docs/runbooks/operations/TROUBLESHOOTING.md`
- **Forum routing**: `docs/reference/operations/FORUM_MEILISEARCH.md`
- **Ingress manifests**: `deploy/k8s/overlays/rke2-nonprod/`
