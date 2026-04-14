# LMS Runtime Closure Runbook
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

How to prove, close, and maintain LMS tenant runtime for staging and dev environments.

## Preconditions Before Running Proof

1. **kubectl access** to the target cluster (rke2-nonprod)
2. **Pods running**: `kubectl get pods -n <namespace>` shows LMS, CMS, MFE pods in Running state
3. **DNS resolves**: target hosts resolve to cluster IPs (check with `dig +short <host>`)
4. **TLS certs valid**: `curl -sI https://<host>` returns 200/302 without certificate errors

## How to Determine If a Fix Is Live

```bash
# Check which image is deployed
kubectl get deploy lms -n <namespace> -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check if a specific commit is in the running image
# The image tag is the git SHA or content digest
kubectl get deploy lms -n <namespace> -o jsonpath='{.spec.template.spec.containers[0].image}' | grep '<commit-sha>'

# Check if middleware ordering fix is deployed (cookie domain scoping)
kubectl exec -n <namespace> <lms-pod> -- python -c "
from django.conf import settings
mw = settings.MIDDLEWARE
cookie_idx = next(i for i,m in enumerate(mw) if 'MerekaCookieDomain' in m)
csrf_idx = next(i for i,m in enumerate(mw) if 'CsrfViewMiddleware' in m)
session_idx = next(i for i,m in enumerate(mw) if 'SessionMiddleware' in m)
print(f'Cookie MW at {cookie_idx}, CSRF at {csrf_idx}, Session at {session_idx}')
print('CORRECT' if cookie_idx < min(csrf_idx, session_idx) else 'WRONG ORDER')
"
```

## How to Run Dev Proof

```bash
# Full proof (requires cluster access)
scripts/tenants/verify-dev-runtime-proof.sh

# With custom namespace
scripts/tenants/verify-dev-runtime-proof.sh --namespace mereka-lms-dev

# Dry run (shows what would be checked without cluster access)
scripts/tenants/verify-dev-runtime-proof.sh --dry-run
```

Output: `var/proof/dev-runtime-proof.json`

## How to Run Staging Proof

```bash
# Full proof
scripts/tenants/verify-staging-runtime-proof.sh

# With custom namespace
scripts/tenants/verify-staging-runtime-proof.sh --namespace stg-mereka-lms

# Dry run
scripts/tenants/verify-staging-runtime-proof.sh --dry-run
```

Output: `var/proof/staging-runtime-proof.json`

## How to Seed/Reconcile Tenant DB State

```bash
# Dev (1 tenant: mereka)
scripts/tenants/seed-dev-sites.sh

# Staging (3 tenants: mereka, biji-biji, skillourfuture)
scripts/tenants/seed-staging-sites.sh

# Dry run (shows what would be created/updated)
scripts/tenants/seed-dev-sites.sh --dry-run
```

Seeds are idempotent — safe to re-run. They use `get_or_create` / `update_or_create`.

## Interpreting Non-Critical Failures

| Failure | Owner | Action |
|---------|-------|--------|
| `admin.*.mereka.dev → 503` | Infra (DNS/Ingress) | No LMS action. File infra ticket. |
| `admin.*.mereka.io → 000 (UNREACHABLE)` | Infra (DNS) | No LMS action. DNS record doesn't exist. |
| `MFEConfig unreachable (Caddy→LMS proxy)` | Infra (Caddy config) | No LMS action. MFE Caddy needs `/api` proxy to LMS. |
| `Cookie domain host-only` | LMS (pending deploy) | Middleware ordering fix merged but not yet in running image. Will resolve on next image build. |
| `MFEConfig BASE_URL mismatch` | DB drift | Re-run seed script to reconcile SiteConfiguration. |

## What Is App-Owned vs Infra-Owned

### App-Owned (LMS lane)

- `mereka_multisite.py` (domain resolution, cookie scoping, login redirect)
- `production.py` middleware ordering
- Site + SiteConfiguration DB state
- Unit tests (`test_mereka_multisite.py`)
- Proof scripts and seed scripts
- MFE config content correctness (values in SiteConfiguration)

### Infra-Owned (GitOps/Platform lane)

- DNS records (Cloudflare)
- TLS certificates (cert-manager)
- Ingress rules (nginx-ingress)
- Caddy reverse proxy config (deployed via GitOps)
- ArgoCD sync state
- Admin host routing
- Namespace creation and RBAC

## How to Update Coordination Spine After a Proof Run

The coordination spine lives in the shared workspace coordination area:
- `_coordination/staging-tenant-closure/`
- `_coordination/dev-runtime-closure/`

After a proof run:

1. Update `STATE.json`:
   - Set `proof.last_run` to current timestamp
   - Update `proof.pass`, `proof.fail`, `proof.fail_critical`, `proof.skip`
   - Update `proof.result` to PASS or FAIL
   - Update tenant statuses in `tenants.*` section
   - Update `lanes.lms` status

2. Update `PROOF_INDEX.json`:
   - Add or update the proof entry with new results
   - Include section-level breakdown

3. Update `HANDOFF_LMS.md`:
   - Update the proof summary table
   - Update any resolved/new blockers

## Proof Script Architecture

```
scripts/tenants/
├── env/
│   ├── staging.env          # Staging constants (3 tenants, namespace, hosts)
│   └── dev.env              # Dev constants (1 tenant, namespace, hosts)
├── lib/
│   ├── runtime-proof-common.sh    # Shared 7-section proof logic
│   └── site-reconcile-common.sh   # Shared seed/reconcile logic
├── verify-staging-runtime-proof.sh  # Thin wrapper → env + lib
├── verify-dev-runtime-proof.sh      # Thin wrapper → env + lib
├── seed-staging-sites.sh            # Thin wrapper → env + lib
└── seed-dev-sites.sh                # Thin wrapper → env + lib
```

To add a new environment (e.g., production):
1. Create `env/production.env` with tenant definitions
2. Create wrapper scripts that source it
3. No changes needed to `lib/` files
