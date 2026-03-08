# Blocked Epics: Unblocker Matrix

> **Bead**: mereka-lms-1nez
> **ACs**: AC-OPS-HO-A through AC-OPS-HO-D
> **Date**: 2026-02-19
> **Author**: WhiteCliff

---

## Blocker Matrix

| Epic | Status | Blocker | Blocker Type | Owner | Next Action | ETA |
|------|--------|---------|-------------|-------|-------------|-----|
| `i8lo` Proctoring (38 ACs) | EXTERNAL BLOCKED | Vendor contract not signed | Legal/Commercial | Platform Lead / Procurement | Execute contract with Examity/Respondus/Proctorio | On contract execution |
| `mci9` Mobile (37 ACs) | EXTERNAL BLOCKED | App Store onboarding | App Store Review / External | Mobile team / App Store accounts | Register developer accounts, submit for review | 2-4 weeks after submission |
| `1bdm` Video (Phase 2-5) | OPERATOR BLOCKED | Real Mux credentials not loaded into GCP SM | Secrets/Config | Platform ops | Load `MEREKA_LMS_MUX_TOKEN_ID` + `MEREKA_LMS_MUX_TOKEN_SECRET` into GCP SM `bbi-k8` | Immediate (operator action) |

---

## Detailed Blocker Analysis

### i8lo — Proctoring: Integrate Enterprise Proctoring

**Status**: EXTERNAL BLOCKED — vendor contract required

| Item | Detail |
|------|--------|
| Blocker | No signed contract with proctoring provider |
| Providers evaluated | Examity, Respondus LockDown Browser, Proctorio |
| Infrastructure | 100% ready — all 38 ACs pre-mapped, no code changes needed pre-contract |
| Credentials needed | Examity API key, Respondus LDB key, Proctorio app key (post-contract) |
| GCP SM slots ready | `MEREKA_LMS_PROCTORING_EXAMITY_KEY` etc. (empty, awaiting contract) |
| Execution doc | `docs/status/readiness/PROCTORING_IMPLEMENTATION_READINESS.md` |
| Effort post-unblock | 2–3 days |
| Contact path | Procurement / Platform Lead to execute vendor agreement |
| **Next action** | **Platform Lead: execute vendor contract** |

---

### mci9 — Mobile: Deploy Enterprise Mobile Apps

**Status**: EXTERNAL BLOCKED — App Store onboarding

| Item | Detail |
|------|--------|
| Blocker | No Apple Developer account or Google Play Developer account registered |
| Platform prep | OAuth2 app, deep-link URIs, branding endpoints documented (`docs/meta/docs-program/MOBILE_OAUTH_PREPARATION.md`) |
| OAuth2 app | NOT yet created in LMS — creation command ready in MOBILE_OAUTH_PREPARATION.md |
| LMS branding | Confirmed correct for all 3 tenants |
| Estimated App Store review | 1–3 business days (iOS), 2–7 days (Android) |
| **Next actions (in order)** | 1. Create mobile OAuth2 app (command in MOBILE_OAUTH_PREPARATION.md) |
| | 2. Register Apple Developer Program account ($99/yr) |
| | 3. Register Google Play Developer account ($25 one-time) |
| | 4. Configure Firebase project for FCM push notifications |
| | 5. Build and submit app binaries |
| Contact path | Product / Engineering Lead to set up developer accounts |

---

### 1bdm — Video: Implement Full Pipeline (Mux + XBlock + Analytics)

**Status**: OPERATOR BLOCKED — Mux credentials placeholder

| Item | Detail |
|------|--------|
| Blocker | `MEREKA_LMS_MUX_TOKEN_ID` and `MEREKA_LMS_MUX_TOKEN_SECRET` in GCP SM (`bbi-k8`) contain `PLACEHOLDER_REPLACE_ME` |
| Phase 1 | 503/833 video lessons mapped; 330 unmapped = non-video lessons (expected) |
| 3 failed Mux assets | Stuck "preparing" since Dec 29 2025 — require re-upload once creds active |
| ArgoCD drift | `mux-delivery-monitor` deployment reads wrong secret (`mereka-lms-runtime-secrets` vs repo's `openedx-secrets`) — ArgoCD sync fixes this automatically |
| Execution doc | `docs/archive/evidence/operations/evidence/1bdm1-mux-creds-mapping-cleanup.md` |
| **Next actions** | 1. Obtain real Mux API credentials from `console.mux.com` |
| | 2. `printf '%s' 'REAL_TOKEN_ID' \| gcloud secrets versions add MEREKA_LMS_MUX_TOKEN_ID --data-file=- --project=bbi-k8` |
| | 3. Same for `MEREKA_LMS_MUX_TOKEN_SECRET` |
| | 4. `kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync=$(date +%s) --overwrite` |
| | 5. `argocd app sync mereka-lms` (fixes deployment drift) |
| Contact path | Platform ops — 15 min to execute |

---

## Owner Notification Summary

| Owner | Action Item | Epic | Priority |
|-------|------------|------|---------|
| Platform Lead / Procurement | Execute proctoring vendor contract | i8lo | P4 (external timeline) |
| Platform Ops | Load real Mux API creds into GCP SM | 1bdm | **P1 — immediate** |
| Product / Engineering Lead | Register Apple + Google developer accounts | mci9 | P2 |
| Platform Engineer | Create mobile OAuth2 app in LMS | mci9 | P2 — unblocked now |

---

## References

- `docs/status/readiness/PROCTORING_IMPLEMENTATION_READINESS.md`
- `docs/meta/docs-program/MOBILE_OAUTH_PREPARATION.md`
- `docs/archive/evidence/operations/evidence/1bdm1-mux-creds-mapping-cleanup.md`
- `deploy/k8s/base/secrets/external-secrets.yaml` — ExternalSecret mappings
