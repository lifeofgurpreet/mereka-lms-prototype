# Cloudflare DNS Checklist
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2025-09-05_

> **STALE WARNING (2026-02-27)**: This document has not been verified in 5+ months. The GKE IP, DNS records, and proxy settings may have changed. Verify against live Cloudflare dashboard before relying on this doc.

Target load balancer IP: **34.177.83.168** (GKE ingress for `academyv2.mereka.io`).

## Required Records

| Type | Name | Value | TTL | Proxy |
|------|------|-------|-----|-------|
| A | `academyv2` | `34.177.83.168` | Auto | Off (DNS only) |
| CNAME | `studio.academyv2` | `academyv2.mereka.io` | Auto | Off |
| CNAME | `apps.academyv2` | `academyv2.mereka.io` | Auto | Off |
| CNAME | `discovery.academyv2` | `academyv2.mereka.io` | Auto | Off |
| CNAME | `ecommerce.academyv2` | `academyv2.mereka.io` | Auto | Off |
| CNAME | `notes.academyv2` | `academyv2.mereka.io` | Auto | Off |
| CNAME | `analytics.academyv2` | `academyv2.mereka.io` | Auto | Off |
| CNAME | `credentials.academyv2` | `academyv2.mereka.io` | Auto | Off |
| CNAME | `preview.academyv2` | `academyv2.mereka.io` | Auto | Off |
| CNAME | `skillourfuture.academy` | `academyv2.mereka.io` | Auto | Off (must stay DNS-only) |

> Keep Cloudflare proxy **off** (gray cloud) until cert-manager has issued the ingress certificates, otherwise ACME HTTP challenges can fail.

## Automated sync

1. Choose an auth method:
   - Preferred: API token with **Zone → DNS:Edit** on the `mereka.io` zone (safer, scoped).
   - Fallback: Global API key + account email (what we used today). Rotate immediately if it leaks.
2. Export the zone id (`0f75c87585234a3b4b265a0973944736` for mereka.io) and whichever auth variables you selected:
   ```bash
   export CLOUDFLARE_ZONE_ID=0f75c87585234a3b4b265a0973944736
   export CLOUDFLARE_API_TOKEN=cf_api_token_value
   # ...or...
   export CLOUDFLARE_EMAIL=gurpreet@biji-biji.com
   export CLOUDFLARE_API_KEY=<global_api_key>
   source .venv/bin/activate
   ./scripts/infra/cloudflare-sync.sh           # DRY_RUN=true ./scripts/infra/cloudflare-sync.sh for a preview
   ```
   The helper now auto-detects which credential style you provided and applies the JSON in `infrastructure/cloudflare/records.json`.
3. Commit any edits to `infrastructure/cloudflare/records.json` (mereka.io), `infrastructure/cloudflare/records.mereka-dev.json`, or `infrastructure/cloudflare/records.biji-biji.com.json` so the entire team stays in sync.

## Baseline records

`infrastructure/cloudflare/records.json` is the single source of truth for the `mereka.io` zone. We enforce:

- `academyv2.mereka.io` – `A` → `34.177.83.168`, TTL `auto` (1), proxy **off** so Let’s Encrypt challenges reach the ingress directly.
- `studio.academyv2.mereka.io` / `apps.academyv2.mereka.io` – CNAMEs back to `academyv2.mereka.io`, also DNS-only.
- `skillourfuture.academy.mereka.io` – CNAME to `academyv2.mereka.io`, **always DNS-only**. Cloudflare’s Universal SSL covers only one wildcard level (`*.academy.mereka.io`), so this two-level hostname must present our origin certificate directly until we purchase an advanced certificate pack.
- `preview.academyv2.mereka.io` / `notes.academyv2.mereka.io` – DNS-only CNAMEs so cert-manager can complete HTTP-01 challenges for the ingress.
- `academyv2.mereka.io` – `CAA 0 issue "letsencrypt.org"` so only Let’s Encrypt can issue certificates for the entire sub-tree; this hardens issuance for our load balancer.

- `academy.biji-biji.com` lives in the separate `biji-biji.com` zone. Manage it with the dashboard or per-zone API token—point it at `academy.biji-biji.com` (A record to the same GKE ingress IP) and feel free to keep it proxied because Cloudflare can issue apex certificates for that zone.

If you need additional records (TXT for verification, CNAMEs for future MFEs), add them to the JSON file and rerun `./scripts/infra/cloudflare-sync.sh` so the script handles creation/update instead of doing it manually.

## Zone security baseline

Run `./scripts/infra/cloudflare-harden-zone.sh` after DNS changes or when cloning the environment. It ensures:

- `ssl=strict` and `min_tls_version=1.2` (older TLS handshakes rejected).
- `always_use_https` + `automatic_https_rewrites` stay enabled so HTTP gets redirected automatically.
- HSTS (max-age 365d, includeSubDomains, `nosniff`) is advertised via the Cloudflare security header toggle.
- HSTS (max-age 365d, includeSubDomains, `nosniff`) is advertised via the Cloudflare security header toggle.

The helper uses the same environment variables as the DNS sync script. The managed WAF toggle is unavailable on our current Cloudflare plan—if you upgrade, enable it directly in the dashboard or extend this script.

### Optional: spot checks with `cli4`

We ship the official Cloudflare CLI inside `.venv` (`cli4`). After activating the virtualenv and exporting `CF_API_EMAIL`/`CF_API_KEY`, you can list or edit records directly:

```bash
source .venv/bin/activate
export CF_API_EMAIL=gurpreet@biji-biji.com
export CF_API_KEY=<global_api_key>
cli4 name=academyv2.mereka.io /zones/:mereka.io/dns_records          # GET
cli4 --put type=A name=academyv2.mereka.io content=34.177.83.168 \
     ttl==1 proxied=false /zones/:mereka.io/dns_records/:academyv2.mereka.io
```

The `:mereka.io` placeholder is converted to the correct zone identifier automatically, so you don’t have to remember the GUID.

## After Updating DNS

1. Wait for propagation (`dig +short academyv2.mereka.io` should return `34.177.83.168`).
2. Re-apply the production ingress (cert-manager watches it and issues `openedx-lms-tls`):
   ```bash
   kubectl apply -k deploy/k8s/overlays/production
   kubectl get certificate openedx-lms-tls -n mereka-lms
   ```
3. Re-run the smoke test (`./scripts/qa/smoke-test.sh`) and manually verify browser access over HTTPS.
