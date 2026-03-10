# Domain Management Runbook
_Audience: Platform Eng + SRE • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers operational procedures for multi-site domain management.

> **Spec**: `specs/multi-site-domains_spec.md`
> **Testmap**: `specs/_generated/testmaps/multi-site-domains_spec.testmap.yml`

## Production Domains

| Service | Domain | Notes |
|---------|--------|-------|
| LMS | `academyv2.mereka.io` | Primary learner-facing |
| Studio | `studio.academyv2.mereka.io` | Course authoring |
| MFE | `apps.academyv2.mereka.io` | Micro-frontends |
| Alt domain | `academy.biji-biji.com` | Alternative branding |

## Prerequisites

- Cloudflare DNS access for mereka.io and biji-biji.com
- Access to production GKE cluster
- Understanding of multi-level subdomain SSL constraints (see `docs/ops/runbooks/DOMAIN_MANAGEMENT.md`)

---

## Verification > Profile Image Upload

### Procedure
1. Log in to LMS as a test user
2. Navigate to profile settings
3. Upload a profile image (JPEG/PNG, < 1MB)
4. Verify image appears on the profile page
5. Verify image is accessible from all configured domains:
   ```bash
   curl -I https://academyv2.mereka.io/static/profile-images/<user_id>.jpg
   curl -I https://academy.biji-biji.com/static/profile-images/<user_id>.jpg
   ```

### Acceptance
- Profile image uploads successfully from browser
- Image is served correctly from all configured domains
- CORS headers allow image loading across domains
- Image upload rejects files > 1MB with a user-friendly message

---

## Adding a New Domain

### Procedure
1. Create DNS record in Cloudflare (DNS-only mode for multi-level subdomains)
2. Add domain to Tutor configuration:
   ```bash
   ./scripts/infra/tutor-config-save.sh --set EXTRA_DOMAINS=<new_domain>
   ```
3. Update Caddy configuration (via apply-patches.sh)
4. Update CSRF trusted origins and allowed hosts
5. Restart services and verify

### Acceptance
- New domain resolves to the correct IP
- SSL certificate is issued (Let's Encrypt via cert-manager)
- LMS responds on the new domain
- CSRF protection works for the new domain
