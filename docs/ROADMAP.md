# Mereka Academy — Platform Roadmap

> Last updated: 2026-03-02 | Status: **Production (Core)**

## Platform Health Snapshot

| Metric | Value |
|--------|-------|
| Tracker completion | 147/154 (95.5%) |
| CI pass rate | 148/162 (91.4%) |
| Specs written | 40 (1,162 ACs) |
| Services in production | 13 (LMS, CMS, 2 workers, 5 enterprise, MFE, Discovery, Forum, Notes, Ecommerce) |
| Observability | Full stack (Prometheus, Loki, Grafana, Alertmanager, GCP Monitoring) |

---

## Phase 1 — Launch Readiness (Now → 1 week)

**Goal**: Get everything merged, rebuilt, and promoted. No new features — just unblock what's already done.

| # | Task | Owner | Blocked By | Est. |
|---|------|-------|------------|------|
| 1.1 | Merge PR #123 (CI hardening, 62 commits) | Platform | — | 10 min |
| 1.2 | Rebuild openedx image from `main` | Infra | 1.1 | 1 hr |
| 1.3 | Rebuild MFE image from `main` | Infra | 1.1 | 30 min |
| 1.4 | Sync bbi-infrastructure overlay (tags + Caddyfile) | Infra | 1.2, 1.3 | 30 min |
| 1.5 | Give #110 go-ahead (staging → production promotion) | Leadership | 1.4 | Decision |
| 1.6 | Provision ARC GitHub App secret | Infra | — | 30 min |
| 1.7 | Complete CI Phase 5 (ARC runner migration) | Platform | 1.6 | 4 hrs |

**Exit criteria**: All 4 remaining CI failures resolved. Branding live in production. CI cost drops to ~$5/mo.

---

## Phase 2 — Enterprise Readiness (Weeks 2–6)

**Goal**: Activate commerce, harden enterprise services, begin SSO integration.

| # | Task | Spec | ACs | Est. |
|---|------|------|-----|------|
| 2.1 | Activate Purchase Gateway | `ecommerce-purchase-gateway_spec.md` | 33 | 2 hrs |
| | — Set real Stripe keys in GCP SM | | | |
| | — Set `ENABLE_GATEWAY_FULFILLMENT=true` | | | |
| | — Add Caddy webhook route for Stripe | | | |
| | — 7-day validation window | | | |
| 2.2 | Decommission legacy Oscar ecommerce | `ecommerce-purchase-gateway_spec.md` AC-028 | 1 | 2 hrs |
| 2.3 | Fix Enterprise MFE runtime config | — | — | 4 hrs |
| | — Inject `env.config.js` into `index.html` | | | |
| | — Or bake env vars at image build time | | | |
| 2.4 | Pin enterprise image tags (digests, not `latest`) | — | — | 1 hr |
| 2.5 | Enterprise SSO Phase 1 | `auth-sso-enterprise_spec.md` | 45 | 2–4 wks |
| | — SAML IdP integration (first tenant) | | | |
| | — OIDC federation | | | |
| | — Enrollment sync | | | |
| | — MFA enforcement | | | |
| 2.6 | Fix credentials service (tzdata) | — | — | 1 hr |

**Exit criteria**: Purchase Gateway processing live orders. First enterprise client on SSO. Oscar removed.

---

## Phase 3 — Platform Completeness (Weeks 6–14)

**Goal**: Fill functional gaps, activate analytics, complete email/video pipelines.

| # | Task | Spec | ACs | Est. |
|---|------|------|-----|------|
| 3.1 | Deploy Tempo tracing to K8s | `observability-stack_spec.md` | 8 | 1 wk |
| | — Install Tempo Helm chart | | | |
| | — Wire OpenTelemetry in LMS/CMS | | | |
| | — 10% head-based + 100% error sampling | | | |
| 3.2 | Activate analytics pipeline | `analytics-pipeline_spec.md` | 8 | 1 wk |
| | — Aspects/ClickHouse/Superset (images exist, ADR accepted) | | | |
| | — Wire Grafana datasource | | | |
| 3.3 | Complete email pipeline | `email-notifications-pipeline_spec.md` | ~30 | 2 wks |
| | — In-app notifications | | | |
| | — Push notifications (FCM) | | | |
| | — Email preferences management | | | |
| | — Multi-language templates | | | |
| | — Delivery analytics + bounce handling | | | |
| 3.4 | Complete video pipeline | `video-pipeline-delivery_spec.md` | ~23 | 2 wks |
| | — Transcoding status tracking | | | |
| | — Fallback encoding | | | |
| | — Analytics integration | | | |
| | — Offline downloads | | | |
| 3.5 | Verifiable Credentials MVP | 5 specs (approved) | TBD | 3–4 wks |
| | — Credentials Service (`did:web`, Ed25519 signing) | | | |
| | — Issuance pipeline + Learner Record MFE | | | |
| | — Open Badges 3.0 types | | | |
| | — Verification flows | | | |
| 3.6 | Frontend Phase 2 specs | 4 draft specs | ~126 | 2–3 wks |
| | — OEP-48 Brand Package (37 ACs) | | | |
| | — Paragon Design Tokens v25 migration (41 ACs) | | | |
| | — Studio Customization (28 ACs) | | | |
| | — Frontend Performance Budgets (30 ACs) | | | |

**Exit criteria**: Full observability (metrics + logs + traces). Analytics dashboards live. Email/video pipelines feature-complete. Verifiable Credentials issuing.

---

## Phase 4 — Advanced Features (Weeks 14–24)

**Goal**: Build out advanced learning features, assessment, and content management.

| # | Task | Spec | ACs | Est. |
|---|------|------|-----|------|
| 4.1 | Advanced Assessment | `advanced-assessment-xqueue_spec.md` | 39 | 3–4 wks |
| | — ORA2 (Open Response Assessment) | | | |
| | — XQueue + CodeJail sandbox | | | |
| | — Peer assessment workflows | | | |
| 4.2 | Badges & Credentials Enterprise | `badges-credentials-enterprise_spec.md` | 33 | 2–3 wks |
| | — Open Badges 3.0 issuer management | | | |
| | — Badge pathway design | | | |
| | — Enterprise credential templates | | | |
| 4.3 | Content Libraries v2 | `content-libraries-v2_spec.md` | 33 | 2–3 wks |
| | — CLX library management | | | |
| | — Enterprise content sharing | | | |
| | — Version control + publishing workflows | | | |
| 4.4 | Enterprise SSO Phase 2 | `auth-sso-enterprise_spec.md` | remaining | 2 wks |
| | — SCIM user provisioning | | | |
| | — SSO audit trail | | | |
| | — Session management | | | |
| | — Enterprise consent flows | | | |

**Exit criteria**: Full assessment suite. Badges issuing. Content libraries operational. Enterprise SSO complete.

---

## Deferred — No Timeline Pressure

These have specs but are explicitly deferred. They'll be picked up when there's a business trigger.

| Feature | Spec | ACs | Trigger | ADR |
|---------|------|-----|---------|-----|
| **Proctoring** | `proctoring-integration_spec.md` | 38 | Client demand (2027+) | ADR-015 |
| **Android Mobile** | `mobile-apps-enterprise_spec.md` | 37 | Resource availability (iOS first) | ADR-016 |
| **Data Privacy/GDPR** | `data-privacy-gdpr-compliance_spec.md` | 93 | Regulatory requirement | — |

---

## Dependency Graph

```
Phase 1 (Launch Readiness)
  ├── PR #123 merge
  │   ├── Image rebuilds (openedx + MFE)
  │   │   └── bbi-infrastructure sync
  │   │       └── #110 promotion go-ahead
  │   └── ARC secret provisioning
  │       └── CI Phase 5 migration
  │
Phase 2 (Enterprise Readiness)
  ├── Purchase Gateway activation (no deps)
  ├── Oscar decommission (← Purchase Gateway + 7 days)
  ├── Enterprise MFE fix (no deps)
  ├── Enterprise SSO Phase 1 (← multi-tenancy DONE)
  │
Phase 3 (Platform Completeness)
  ├── Tempo tracing (no deps)
  ├── Analytics pipeline (no deps)
  ├── Email pipeline (no deps)
  ├── Video pipeline (no deps)
  ├── Verifiable Credentials (← Credentials Service build)
  ├── Frontend Phase 2 (← Phase 1 branding live)
  │
Phase 4 (Advanced Features)
  ├── Advanced Assessment (no deps)
  ├── Badges & Credentials (← Verifiable Credentials MVP)
  ├── Content Libraries v2 (no deps)
  └── Enterprise SSO Phase 2 (← Phase 1 SSO)
```

---

## Risk Register

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Stripe integration issues on Purchase Gateway activation | Revenue | Medium | Dark launch validated, all 33 ACs automated |
| Enterprise SSO complexity (multi-IdP, SAML quirks) | Timeline | High | Phase 0 foundation done, spec has 45 ACs with clear acceptance criteria |
| Image rebuild breaks production | Availability | Low | GitOps + ArgoCD rollback, staging promotion gate |
| ARC runners don't scale under load | CI velocity | Medium | PVC caching, scale bounds tested |
| Tempo instrumentation impacts LMS latency | Performance | Low | 10% sampling rate, error-only full capture |

---

## Metrics to Track

| Metric | Current | Phase 1 Target | Phase 3 Target |
|--------|---------|----------------|----------------|
| CI pass rate | 148/162 (91%) | 158/162 (98%) | 160/162 (99%) |
| CI monthly cost | ~$56 | ~$15 | ~$5 |
| Production services | 13 | 13 | 16 (+ analytics, tempo, credentials) |
| Specs completed | 18/40 | 18/40 | 28/40 |
| Enterprise SSO ACs | 0/45 | 0/45 | 30/45 |
| SLO availability | TBD | 99.5% measured | 99.5% enforced |
