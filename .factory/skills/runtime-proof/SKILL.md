---
name: runtime-proof
description: Verify that a change is actually live and working. Use when validating deployments, running canaries, or checking runtime behavior across tenants and environments in Mereka LMS.
---

# Runtime Proof & Verification

## Layer Ownership

Runtime → Proof

## Proof Types

| Proof type | What it proves | Tool/script |
|---|---|---|
| Route proof | HTTP reachability + response class | `verify-rke2-tenant-routes.sh` |
| Browser canary | Login/session/dashboard journey | `verify-authenticated-sso-canary.sh` |
| Identity/session proof | Auth flow end-to-end | SSO canary + cookie/session check |
| Asset verification | Served JS/CSS matches build | `curl` response headers + source-map check |
| Forum smoke | Forum endpoint health semantics | `verify-forum-smoke.sh` |
| Credentials/notes | Auth-required API behavior | credentials/notes smoke checks |

## Mandatory Order

1. **Route proof first**: verify HTTP reachability
2. **Asset verification**: confirm served bundle matches build
3. **Browser canary last**: only after route + asset gates pass

## Steps

```bash
# 1. Route proof
./scripts/qa/verify-rke2-tenant-routes.sh

# 2. Asset verification (check served content)
curl -sI https://apps.academyv2.mereka.io/authn/login | grep -E 'HTTP|content-type|etag'

# 3. Browser canary (only after above pass)
./scripts/qa/verify-authenticated-sso-canary.sh

# 4. Forum smoke
./scripts/qa/verify-forum-smoke.sh
```

## Smoke Identity Rules

- Identity authority: Authentik + Open edX (creates the account)
- Secret authority: Infisical (stores credentials)
- CI consumers: GitHub Actions secrets (mirrors only, NOT authority)
- Registry: `deploy/k8s/tenancy/smoke-account-registry.yaml`

## False Green Traps

| Trap | How to detect |
|---|---|
| Offline-only check passes while live is broken | Always run against live URL, not local |
| Session pass with blank page | Check response body, not just status code |
| Health-only check misses function breakage | Test actual user journey, not just `/health` |
| Alias empty 200 looks healthy | Check response body content, not just status |
| Verifier green outside its lane | Each verifier proves only its contract lane |

## Never Do

- Rerun browser canary while live asset gate is red
- Trust build success as proof of served asset
- Accept verifier green outside its contract lane as launch proof
- Accept branch truth or merge truth as proved truth
- Run proof against a known-unpatched live bundle

## Required Companions

> Source: `config/skills-graph.yaml`

- **Requires**: `layer-triage`
- **Recommended**: `smoke-identity`

## References

- [RUNTIME_PROOF_VERIFICATION.md](docs/ops/playbooks/RUNTIME_PROOF_VERIFICATION.md)
- [VERIFIER_CONTRACT_CATALOG.md](docs/reference/contracts/VERIFIER_CONTRACT_CATALOG.md)
