# Cloudflare DNS Checklist
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2025-09-05_

Target load balancer IP: **34.126.186.80** (Caddy service in `mereka-lms` GKE cluster).

## Required Records

| Type | Name | Value | TTL | Proxy |
|------|------|-------|-----|-------|
| A | `staging` | `34.126.186.80` | Auto | Off (DNS only) |
| CNAME | `studio` | `staging.academy.mereka.io` | Auto | Off |
| CNAME | `apps` | `staging.academy.mereka.io` | Auto | Off |
| CNAME | `skillourfuture.staging` | `staging.academy.mereka.io` | Auto | Off (must stay DNS-only) |
| CNAME | `preview.staging` | `staging.academy.mereka.io` | Auto | Off |
| CNAME | `notes.staging` | `staging.academy.mereka.io` | Auto | Off |

> Keep Cloudflare proxy **off** (gray cloud) until HTTPS certificates are in place, otherwise ACME HTTP challenges can fail.

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
   ./tools/cloudflare-sync.sh           # DRY_RUN=true ./tools/cloudflare-sync.sh for a preview
   ```
   The helper now auto-detects which credential style you provided and applies the JSON in `ops/cloudflare/records.json`.
3. Commit any edits to `ops/cloudflare/records.json` (e.g., different load-balancer IP) so the entire team stays in sync.

## Baseline records

`ops/cloudflare/records.json` is the single source of truth. For staging we enforce:

- `staging.academy.mereka.io` – `A` → `34.126.186.80`, TTL `auto` (1), proxy **off** so Let’s Encrypt challenges reach Caddy directly.
- `studio.staging.academy.mereka.io` / `apps.staging.academy.mereka.io` – CNAMEs back to the staging host, also DNS-only.
- `skillourfuture.staging.academy.mereka.io` – CNAME to `staging.academy.mereka.io`, **always DNS-only**. Cloudflare’s Universal SSL covers only one wildcard level (`*.academy.mereka.io`), so this two-level hostname must present our origin certificate directly until we purchase an advanced certificate pack.
- `preview.staging.academy.mereka.io` / `notes.staging.academy.mereka.io` – DNS-only CNAMEs so Caddy can mint certificates for Studio preview + Notes without spamming ACME errors.
- `academy.mereka.io` – `CAA 0 issue "letsencrypt.org"` so only Let’s Encrypt can issue certificates for the entire sub-tree; this hardens issuance for our load balancer.

- `academy.biji-biji.com` lives in the separate `biji-biji.com` zone. Manage it with the dashboard or per-zone API token—point it at `staging.academy.mereka.io` (flattened CNAME) and feel free to keep it proxied because Cloudflare can issue apex certificates for that zone.

If you need additional records (TXT for verification, CNAMEs for future MFEs), add them to the JSON file and rerun `./tools/cloudflare-sync.sh` so the script handles creation/update instead of doing it manually.

## Zone security baseline

Run `./tools/cloudflare-harden-zone.sh` after DNS changes or when cloning the environment. It ensures:

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
cli4 name=staging.academy.mereka.io /zones/:mereka.io/dns_records          # GET
cli4 --put type=A name=staging.academy.mereka.io content=34.126.186.80 \
     ttl==1 proxied=false /zones/:mereka.io/dns_records/:staging.academy.mereka.io
```

The `:mereka.io` placeholder is converted to the correct zone identifier automatically, so you don’t have to remember the GUID.

## After Updating DNS

1. Wait for propagation (`dig +short staging.academy.mereka.io` should return `34.126.186.80`).
2. Re-enable HTTPS in Tutor:
   ```bash
   source ops/tutor-env.sh
   tutor config save --set ENABLE_HTTPS=true
   tutor k8s start
   ```
   This prompts Caddy to request Let’s Encrypt certificates for LMS, Studio, and MFEs.
3. Re-run the smoke test (`./tools/smoke-test.sh`) and manually verify browser access over HTTPS.
