---
title: SOF Tenant Migration — academy.mereka.io → academyv2.mereka.io
type: migration-ledger
owner: platform
status: in-progress
started: 2026-04-21
target_completion: 2026-06-30
runbook: docs/ops/runbooks/TENANT_DOMAIN_MIGRATION.md
---

# SOF Tenant Migration Ledger

Concrete application of `docs/ops/runbooks/TENANT_DOMAIN_MIGRATION.md`
to the Skill Our Future tenant.

## Migration context

SOF (`slug: skillourfuture`) was originally onboarded on the
`academy.mereka.io` tree in 2024. A partial migration to
`academyv2.mereka.io` was started in 2025 but never completed —
Studio + MFE ingress moved, LMS + Django settings + SiteConfiguration
did not. This created the D-08 drift pattern flagged in
`deploy/k8s/tenancy/tenant-registry.yaml`:

- LMS serves on `skillourfuture.academy.mereka.io`
- MFE serves on `apps.skillourfuture.academyv2.mereka.io`
- Studio serves on `studio.skillourfuture.academyv2.mereka.io`
- Cookie domain set by LMS: `.skillourfuture.academy.mereka.io`
- Cookie domain expected by MFE/Studio: `.skillourfuture.academyv2.mereka.io`

Cookies cannot cross sibling subdomains of `mereka.io`, so every SOF
auth flow is architecturally broken until unified. This ledger drives
that unification.

## Target end state

All three surfaces on a single cookie tree. Two viable endpoints:

- **Option A (chosen): unify on `academyv2`.** Matches Mereka primary,
  simpler DNS, no new cert work (cert already covers `academyv2` tree
  SANs for MFE/Studio). LMS is the moving piece.
- Option B: revert MFE+Studio to `academy.mereka.io`. Would require
  retiring the v2 cert work already shipped. Rejected 2026-04-21 per
  user direction ("charge forward").

## Surface-by-surface ledger (15 surfaces per runbook)

Legend: `OLD` = `skillourfuture.academy.mereka.io` tree; `NEW` =
`skillourfuture.academyv2.mereka.io` tree.

| # | Surface | Current | Target | Stage | PR / Evidence |
|---|---------|---------|--------|-------|---------------|
| 1 | `tenant-registry.yaml` | `site_domain=OLD` `target=NEW` | `site_domain=NEW`, OLD → deprecated | 1→4 | _pending_ |
| 2 | `configmap-tenants.yaml` | `domain=NEW` (drift — already on target, LMS not) | `domain=NEW` | 4 | _main already at NEW_ |
| 3 | LMS `production.py` ALLOWED_HOSTS | has OLD | add NEW (Stage 1), drop OLD (Stage 6) | 1 | _pending_ |
| 4 | CMS `production.py` ALLOWED_HOSTS | has OLD | add NEW (Stage 1), drop OLD (Stage 6) | 1 | _pending_ |
| 5 | `mereka_multisite.py` cookie policy | NEW returns `.OLD` | NEW returns `.NEW` | 4 | _pending_ |
| 6 | `skillourfuture-mfe-env.js` | LMS=OLD STUDIO=NEW LOGIN=OLD | all NEW | 4 | _pending_ |
| 7 | Caddyfile | _audit pending_ | — | 1 | _audit_ |
| 8 | LMS + apps SiteConfiguration rows | LMS-row=OLD, apps-row=NEW | both=NEW | 4 | _runtime step_ |
| 9 | OAuth2 Application `redirect_uris` | includes OLD + NEW | NEW primary, OLD retired in Stage 6 | 2→6 | _runtime step_ |
| 10 | K8s Ingress (bbi-infra) | OLD=lms, NEW=mfe+studio | all hosts on NEW | 1, 4 | _bbi-infra PR pending_ |
| 11 | cert-manager Certificate SANs | OLD-LMS, NEW-MFE, NEW-Studio | NEW for all 3 | 1, 4 | _bbi-infra PR pending_ |
| 12 | DNS (Cloudflare) | OLD and NEW both resolve | both during drain; OLD retired Stage 7 | 1→7 | _Cloudflare console_ |
| 13 | Authentik OIDC app | includes OLD | add NEW (Stage 2), drop OLD (Stage 6) | 2, 6 | _Authentik admin_ |
| 14 | `verify-prod-runtime-proof.sh` | probes OLD | probes NEW as primary, OLD as redirect | 4 | _pending_ |
| 15 | `docs/` SOF refs | mixed OLD/NEW | NEW across active docs; OLD in history only | 4, 7 | _pending_ |

## Execution timeline

| Stage | ETA | PR target | Responsible |
|-------|-----|-----------|-------------|
| 0 — Pre-flight audit | 2026-04-21 | _this ledger_ | platform |
| 1 — Add NEW URLs (app + infra, no cut) | 2026-04-22 | mereka-lms + bbi-infrastructure (2 PRs) | platform |
| 2 — Data-plane prep (SiteConfig, OAuth, Authentik) | 2026-04-23 | runtime (no PR) | platform |
| 3 — Soak + probe | 2026-04-23 → 2026-05-07 | — | monitor |
| 4 — Cut (flip primary) | 2026-05-08 | mereka-lms + bbi-infrastructure (2 PRs) | platform |
| 5 — Drain window | 2026-05-08 → 2026-06-07 | — | monitor |
| 6 — Retire OLD from ingress + ALLOWED_HOSTS + OAuth | 2026-06-08 | mereka-lms + bbi-infrastructure (2 PRs) | platform |
| 7 — Retire OLD DNS + cert SAN + docs cleanup | 2026-06-30 | mereka-lms (1 PR) + DNS | platform |

## Risks

| Risk | Mitigation |
|------|-----------|
| Live SOF users mid-session during cutover | Dual-active through Stage 4; their session cookie lives on OLD tree until browser close, then new login uses NEW tree. No forced logout. |
| External partner sites deep-link to OLD URLs | 301 redirect at OLD (Stage 6) holds for 90 days; monitor traffic share; escalate high-traffic partners to update. |
| OAuth2 redirect whitelist desync | Stage 2 adds NEW well before Stage 4 cut; Stage 6 removes OLD well after cut. |
| Cert-manager cert reissue failure | Ship cert change in a dedicated PR with explicit verification (`openssl s_client`); hold 24 h before merging ingress change. |
| Studio SSO redirect loop (cm9c recurrence) | Stage 2 Authentik whitelist update covers this class; runtime proof in Stage 4 exercises it. |

## Related beads

- `mereka-lms-cm9c` — STRUCTURAL SSO drift (this ledger is the execution arm)
- `mereka-lms-<pending>` — Stage 1 app-repo add-NEW PR
- `mereka-lms-<pending>` — Stage 4 cut PR
- `mereka-lms-<pending>` — Stage 6 retire PR

## Lessons to capture post-migration

1. What broke that the runbook didn't predict → add to runbook §"Failure modes".
2. What checks we wish we'd had → add to `verify-tenant-migration-readiness.sh` (to be
   created; covers the 15-surface matrix automatically).
3. How long each stage actually took → calibrate future migration ETAs.
