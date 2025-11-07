# Cloudflare DNS Checklist

Target load balancer IP: **34.126.186.80** (Caddy service in `mereka-lms` GKE cluster).

## Required Records

| Type | Name | Value | TTL | Proxy |
|------|------|-------|-----|-------|
| A | `staging` | `34.126.186.80` | Auto | Off (DNS only) |
| CNAME | `studio` | `staging.academy.mereka.io` | Auto | Off |
| CNAME | `apps` | `staging.academy.mereka.io` | Auto | Off |

> Keep Cloudflare proxy **off** (gray cloud) until HTTPS certificates are in place, otherwise ACME HTTP challenges can fail.

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
