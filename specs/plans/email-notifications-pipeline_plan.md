---
spec: email-notifications-pipeline_spec.md
tier: 5
status: draft
estimated_effort: "16 weeks (4 engineers)"
phases: 6
total_tasks: 62
prerequisites:
  - multi-tenancy-architecture_spec.md (Tier 4.1)
  - auth-sso-enterprise_spec.md (Tier 4.2)
  - enterprise-microservices_spec.md (Tier 4.3)
  - secrets-management_spec.md (Tier 0)
  - observability-stack_spec.md (Tier 2)
  - k8s-deployment_spec.md (Tier 1)
last_updated: "2026-02-10"
---

# Implementation Plan: Email & Notifications Pipeline

**Source Spec**: `specs/email-notifications-pipeline_spec.md`
**Tier**: 5 (Enterprise Features -- parallelizable after Tier 4)
**Estimated Effort**: 16 weeks across 4 engineers

## Summary

This plan implements a production-grade multi-channel notification pipeline for Mereka Academy. The system extends Open edX's ACE (Automated Communications Engine) with three delivery channels (email, push, in-app), a notification preferences service with GDPR consent tracking, multi-language templates (EN/MS/ZH), enterprise bulk messaging with per-tenant rate limiting, bounce/complaint handling, notification digests, and engagement analytics.

The implementation is structured in 6 phases, matching the spec's rollout plan. Each phase is independently deployable behind feature flags. No new service directories are created; all changes are LMS Django app configuration, Tutor patches, K8s manifests (ExternalSecrets, deployments), and MFE integration.

## Open Questions (Must Resolve Before Phase Start)

| # | Question | Blocks Phase | Current Status |
|---|----------|-------------|----------------|
| OQ-1 | SES account: sandbox or production mode? | Phase 1 | Unknown -- check AWS console |
| OQ-2 | Firebase project `mereka-academy` created? FCM API enabled? | Phase 4 | Depends on mobile-apps-enterprise spec |
| OQ-3 | SES sending rate limit and daily quota? | Phase 5 (bulk) | Default: 50k/day, 14/sec |
| OQ-4 | Multi-language template authoring: translator resource? | Phase 5 | No translator identified |
| OQ-5 | ClickHouse available for engagement data? | Phase 6 | Depends on analytics-pipeline spec |
| OQ-6 | Enterprise admin portal MFE has bulk email UI? | Phase 5 | Unknown -- may need building |
| OQ-7 | User profile stores timezone? | Phase 6 (digests) | Likely not -- needs profile extension |
| OQ-8 | Email list hygiene for Kajabi-migrated addresses? | Phase 5 | Recommended before bulk sends |
| OQ-9 | SES/SNS monthly budget allocation? | Phase 1 | Est. $10-15/month for 100k emails |
| OQ-10 | Email provider formally ratified as AWS SES? | Phase 1 | SES operational but not ratified |
| OQ-11 | Push provider: FCM-only or also direct APNs? | Phase 4 | Spec says FCM-only for v1 |

---

## Phase 1: Email Infrastructure Hardening (Week 1-2)

### Build

- [ ] **[M]** Verify `academyv2.mereka.io` domain with SES: DKIM, SPF records, custom MAIL FROM domain `mail.academyv2.mereka.io` (`infrastructure/cloudflare/records.json`, AWS SES console) | AC: #1, #4 | Depends: None
- [ ] **[M]** Verify `academy.biji-biji.com` domain with SES: DKIM, SPF, DMARC records (`infrastructure/cloudflare/records.json`, AWS SES console) | AC: #2 | Depends: None
- [ ] **[S]** Configure DMARC DNS records for both domains: `v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@mereka.io; pct=100` (`infrastructure/cloudflare/records.json`) | AC: #1, #2 | Depends: None
- [ ] **[M]** Create SES configuration set `mereka-academy-production` with SNS event publishing for: send, delivery, bounce, complaint, reject, open, click (AWS SES console / Terraform) | AC: #40 | Depends: None
- [ ] **[M]** Create SNS topic `mereka-academy-ses-events` and subscription to an HTTPS endpoint in LMS for bounce/complaint notifications (`infrastructure/terraform/`) | AC: #33, #34, #35 | Depends: SES config set
- [ ] **[L]** Build SNS bounce/complaint webhook endpoint in LMS: validate SNS message signature, process hard/soft bounces, process complaints (`infrastructure/tutor/apply-patches.sh` -- LMS settings; logic via custom Django app or Tutor plugin) | AC: #33, #34, #35, #36 | Depends: SNS topic
- [ ] **[M]** Create suppression list MySQL table via Django migration: `email_hash`, `reason` (hard_bounce/complaint), `bounce_count`, `diagnostic_code`, `added_at`, `removed_at`, `removed_by` (`infrastructure/tutor/apply-patches.sh` -- custom Django model) | AC: #33, #34, #35 | Depends: None
- [ ] **[S]** Add suppression list check to ACE email dispatch: block sends to suppressed addresses, except `password_reset` and `account_activation` (`infrastructure/tutor/apply-patches.sh` -- ACE channel override) | AC: #33, #8 | Depends: Suppression table
- [ ] **[S]** Build admin API for suppression list: `GET /api/admin/v1/email/suppression-list/`, `DELETE /api/admin/v1/email/suppression-list/{email_hash}/` with `is_staff` permission (`infrastructure/tutor/apply-patches.sh`) | AC: #33 (edge case: false positive removal) | Depends: Suppression table
- [ ] **[S]** Implement daily summary email to `ops@mereka.dev`: total sends, delivery rate, bounce rate, complaint rate, new suppressions (Celery Beat task) | Req: Bounce-7 | Depends: Suppression table + SNS webhook
- [ ] **[S]** Request SES production sending mode (if currently in sandbox) (AWS SES console -- manual action) | Req: Email-10 | Depends: Domain verification

### Secrets

- [ ] **[S]** Verify `ses-smtp-credentials` K8s secret exists with `RELAY_USERNAME`, `RELAY_PASSWORD` keys; add to ExternalSecrets if not present (`deploy/k8s/base/secrets/external-secrets.yaml`) | AC: #3 | Depends: None
- [ ] **[S]** Add `MEREKA_LMS_SES_SNS_WEBHOOK_SECRET` to Infisical and ExternalSecrets for SNS signature validation (`deploy/k8s/base/secrets/external-secrets.yaml`) | AC: #33 | Depends: None

### Observability

- [ ] **[M]** Add Prometheus metrics: `notification_emails_sent_total`, `notification_emails_bounced_total`, `notification_emails_complained_total`, `notification_suppression_list_size`, `notification_ses_sending_quota_remaining` (`infrastructure/tutor/apply-patches.sh` -- Django Prometheus exporter) | Req: OBS-metrics | Depends: Bounce webhook
- [ ] **[M]** Add Grafana dashboard: "Email Overview" -- daily send volume, delivery rate, bounce rate, complaint rate, SES quota (`infrastructure/monitoring/grafana/dashboards/`) | Req: OBS-dashboards | Depends: Metrics
- [ ] **[S]** Add PrometheusRule alerts: SES bounce rate > 5%, complaint rate > 0.1%, SES quota < 10% (`infrastructure/monitoring/prometheus/rules/`) | Req: OBS-alerts | Depends: Metrics

### Test

- [ ] **[S]** Write `scripts/qa/verify-ses-domain-verification.sh`: check DKIM/SPF/DMARC via `dig` for both domains | AC: #1, #2 | Depends: Domain verification
- [ ] **[S]** Write `scripts/qa/verify-ses-configuration.sh`: check SES config set, SNS topic, MAIL FROM domain | AC: #4, #40 | Depends: SES config set
- [ ] **[S]** Write `scripts/qa/smoke-test-email-delivery.sh`: send test email, verify delivery via SES API | AC: #3 | Depends: All Phase 1 build

### Docs

- [ ] **[M]** Create `docs/runbooks/email-notifications-runbook.md`: SES credential rotation, suppression list management, bounce storm recovery, SES account suspension response | Depends: All Phase 1

---

## Phase 2: Notification Preferences Service (Week 3-4)

### Build

- [ ] **[L]** Create notification preferences Django model and migration: `user_id`, `message_type`, `channel`, `enabled`, `updated_at`, `consent_version` + audit log table (`infrastructure/tutor/apply-patches.sh` -- custom Django app) | AC: #20, #23 | Depends: None
- [ ] **[L]** Build preferences REST API: `GET /api/notifications/v1/preferences/`, `PUT /api/notifications/v1/preferences/`, `GET /api/notifications/v1/preferences/defaults/` with rate limiting (10 req/min/user) (`infrastructure/tutor/apply-patches.sh`) | AC: #20, #21 | Depends: Preferences model
- [ ] **[M]** Implement GDPR consent tracking: `consent_version`, `consent_text_hash`, `consented_at`, `ip_address_hash` in preference records; audit log for all changes (`infrastructure/tutor/apply-patches.sh`) | AC: #23, #43 | Depends: Preferences model
- [ ] **[M]** Build one-click unsubscribe endpoint: HMAC-SHA256 signed token generation and validation, 90-day expiry, disables `bulk_campaign` + `course_announcement` email without login (`infrastructure/tutor/apply-patches.sh`) | AC: #22 | Depends: Preferences API
- [ ] **[S]** Add `List-Unsubscribe` and `List-Unsubscribe-Post` headers to `bulk_campaign` ACE email templates (`infrastructure/tutor/apply-patches.sh` -- ACE template override) | AC: #24 | Depends: Unsubscribe endpoint
- [ ] **[M]** Integrate preferences enforcement into ACE message dispatch: route messages based on user preferences per message type per channel; skip `password_reset`/`account_activation` preference check (`infrastructure/tutor/apply-patches.sh`) | AC: #7, #8, #21 | Depends: Preferences API
- [ ] **[S]** Default preferences: all channels enabled except `bulk_campaign` email (disabled by default for GDPR) | AC: #20, #43 | Depends: Preferences model
- [ ] **[S]** Add `MEREKA_LMS_UNSUBSCRIBE_HMAC_SECRET` to Infisical and ExternalSecrets (`deploy/k8s/base/secrets/external-secrets.yaml`) | AC: #22 | Depends: None

### Test

- [ ] **[S]** Write `scripts/qa/verify-notification-preferences-api.sh`: CRUD operations on preferences API, default values, audit log entries | AC: #20, #21, #23 | Depends: Preferences API
- [ ] **[S]** Write `scripts/qa/smoke-test-unsubscribe.sh`: generate signed link, click it, verify preferences updated | AC: #22, #24 | Depends: Unsubscribe endpoint

### Observability

- [ ] **[S]** Add Prometheus metric: `notification_preferences_changes_total` (labels: `message_type`, `channel`, `action`) | Req: OBS-metrics | Depends: Preferences API
- [ ] **[S]** Add Grafana dashboard panel: "Notification Preferences" -- opt-in/opt-out rates by type and channel | Req: OBS-dashboards | Depends: Preferences metrics

### Rollout

- [ ] **[S]** Add feature flag `notification_preferences_enabled` (default: off) to Tutor config / Waffle flags (`infrastructure/tutor/apply-patches.sh`) | Req: Rollout | Depends: None

---

## Phase 3: In-App Notifications (Week 5-6)

### Build

- [ ] **[L]** Create notification store MySQL model and migration: `id` (UUID), `user_id`, `message_type`, `title`, `body`, `course_id`, `org_slug`, `deep_link_url`, `read`, `created_at`, `expires_at` with cursor-based pagination support (`infrastructure/tutor/apply-patches.sh`) | AC: #10, #11, #12, #14 | Depends: None
- [ ] **[L]** Build in-app notification REST API: `GET /api/notifications/v1/` (paginated, filterable), `PATCH /api/notifications/v1/{id}/read/`, `POST /api/notifications/v1/mark-all-read/`, `GET /api/notifications/v1/unread-count/`, `DELETE /api/notifications/v1/{id}/` (`infrastructure/tutor/apply-patches.sh`) | AC: #10, #11, #12, #13, #14 | Depends: Notification store model
- [ ] **[M]** Implement ACE `in_app` channel: persist notifications to MySQL on dispatch; filter expired notifications from queries; enforce `org_slug` isolation (`infrastructure/tutor/apply-patches.sh`) | AC: #6, #12, #14 | Depends: Notification store model
- [ ] **[M]** Implement notification creation handlers: connect Open edX signals (`ENROLLMENT_CREATED`, `COURSE_GRADE_NOW_PASSED`, `CERTIFICATE_CREATED`, `FORUM_THREAD_RESPONSE_CREATED`) to ACE `in_app` channel with idempotency via `notification_id` deduplication (`infrastructure/tutor/apply-patches.sh`) | AC: #6, #9 | Depends: ACE `in_app` channel
- [ ] **[S]** Implement notification flood batching: batch 100+ forum replies in 5-minute window into single notification ("X new replies in thread Y") | Edge case: Notification flood | Depends: Notification handlers
- [ ] **[S]** Implement expired notification purge Celery Beat task: daily job, deletes notifications older than 90 days | Req: In-App-10 | Depends: Notification store model
- [ ] **[S]** Add `notification_inapp_enabled` feature flag (default: off) (`infrastructure/tutor/apply-patches.sh`) | Req: Rollout | Depends: None

### Test

- [ ] **[S]** Write `scripts/qa/verify-notification-api.sh`: list/read/mark-all-read/unread-count/delete operations, pagination, org_slug isolation, expired filtering | AC: #10, #11, #12, #13, #14 | Depends: Notification API
- [ ] **[S]** Write `scripts/qa/smoke-test-inapp-notifications.sh`: trigger enrollment, verify notification appears in API response | AC: #6 | Depends: All Phase 3 build

### Observability

- [ ] **[S]** Add Prometheus metrics: `notification_inapp_created_total`, `notification_inapp_read_total` | Req: OBS-metrics | Depends: Notification API
- [ ] **[S]** Add Grafana dashboard panel: "In-App Notifications" -- creation rate, read rate, API latency | Req: OBS-dashboards | Depends: In-app metrics

### Docs

- [ ] **[S]** Update `docs/runbooks/email-notifications-runbook.md` with in-app notification purge procedures and notification flood mitigation | Depends: All Phase 3

---

## Phase 4: Push Notifications (Week 7-8)

### Build

- [ ] **[M]** Configure ACE `push` channel in LMS settings (`infrastructure/tutor/apply-patches.sh`) | AC: #6, #15 | Depends: Phase 2 (preferences)
- [ ] **[L]** Build push notification dispatch service: FCM HTTP v1 API integration, batch sending (groups of 500), token validation, `UNREGISTERED`/`INVALID_ARGUMENT` handling (`infrastructure/tutor/apply-patches.sh` -- custom Django app) | AC: #15, #16, #18 | Depends: ACE push channel
- [ ] **[M]** Create device registration MySQL model and migration: `id`, `user_id`, `device_token`, `platform`, `app_version`, `org_slug`, `registered_at`, `last_seen_at`, `is_active` with deduplication (`infrastructure/tutor/apply-patches.sh`) | AC: #15, #16, #17 | Depends: None
- [ ] **[S]** Build device registration API: `POST /api/mobile/v1/notifications/register/`, `DELETE /api/mobile/v1/notifications/register/` (per mobile-apps-enterprise spec) | AC: #15, #17 | Depends: Device model
- [ ] **[S]** Implement `org_slug` isolation for push dispatch: only send to devices matching notification's `org_slug` | AC: #19 | Depends: Push dispatch service
- [ ] **[S]** Implement push notification grouping: iOS `threadId`, Android notification channels by course | Req: Push-7 | Depends: Push dispatch service

### Secrets

- [ ] **[S]** Add `MEREKA_LMS_FCM_SERVICE_ACCOUNT_KEY` to Infisical and ExternalSecrets (`deploy/k8s/base/secrets/external-secrets.yaml`) | AC: #15 | Depends: Firebase project (OQ-2)

### Test

- [ ] **[S]** Write `scripts/qa/verify-push-notification-config.sh`: check FCM credentials present, ACE push channel configured, device registration API responds | AC: #15 | Depends: Push dispatch service
- [ ] **[S]** Write `scripts/qa/smoke-test-push-notifications.sh`: register test device, trigger notification, verify FCM API called | AC: #15, #18 | Depends: All Phase 4 build

### Observability

- [ ] **[S]** Add Prometheus metrics: `notification_push_sent_total`, `notification_push_dispatch_latency_seconds`, `notification_device_registrations_active` | Req: OBS-metrics | Depends: Push dispatch service
- [ ] **[S]** Add Grafana dashboard panel: "Push Notifications" -- send volume, delivery rate, failure breakdown, device registrations | Req: OBS-dashboards | Depends: Push metrics

### Rollout

- [ ] **[S]** Add feature flag `notification_push_enabled` (default: off); validate with iOS TestFlight users first (`infrastructure/tutor/apply-patches.sh`) | Req: Rollout | Depends: None

---

## Phase 5: Multi-Language Templates and Bulk Messaging (Week 9-12)

### Build

- [ ] **[L]** Create ACE message type templates for all 15 message types: `subject.txt`, `body.html`, `body.txt` in EN (`infrastructure/tutor/apply-patches.sh` -- ACE template directories) | AC: #25, #28 | Depends: Phase 2 (preferences)
- [ ] **[L]** Create MS (Malay) and ZH-Hans (Simplified Chinese) template translations for all 15 message types (`infrastructure/tutor/apply-patches.sh` -- i18n template directories) | AC: #25, #26, #27 | Depends: EN templates + translator (OQ-4)
- [ ] **[M]** Implement per-tenant branding variable injection: `org_display_name`, `org_logo_url`, `org_primary_color`, `org_accent_color`, `org_support_email`, `org_terms_url`, `org_privacy_url` in ACE template context (`infrastructure/tutor/apply-patches.sh`) | AC: #5, #28 | Depends: EN templates
- [ ] **[S]** Implement language fallback: if user's `language_preference` template does not exist, fall back to EN | AC: #27 | Depends: Multi-language templates
- [ ] **[S]** Add standard email footer: unsubscribe link, support email, physical mailing address (CAN-SPAM), Mereka logo | Req: Template-7 | Depends: EN templates
- [ ] **[L]** Build bulk campaign engine: scheduling (up to 30 days advance), pause/resume with checkpoint-based processing, recipient segmentation (course, org, status, cohort), cancellation (`infrastructure/tutor/apply-patches.sh`) | AC: #29, #30, #31 | Depends: Phase 2 (preferences)
- [ ] **[M]** Implement per-tenant rate limiting for bulk sends: default 50 emails/sec/tenant, configurable max, global SES limit enforcement via Redis token bucket (`infrastructure/tutor/apply-patches.sh`) | AC: #32 | Depends: Bulk campaign engine
- [ ] **[S]** Implement bulk campaign status tracking: draft/scheduled/sending/paused/completed/failed/cancelled with per-campaign metrics (total, sent, delivered, bounced, complained, opened, clicked, skipped) | AC: #30, #31 | Depends: Bulk campaign engine
- [ ] **[S]** Implement bulk email content sanitization: strip `<script>`, `onclick`, XSS vectors before sending | Req: Security-7 | Depends: Bulk campaign engine
- [ ] **[S]** Implement `bulk_campaign` preference enforcement: skip opted-out recipients, report skipped count | AC: #31, #43 | Depends: Preferences API + bulk engine
- [ ] **[S]** Template preview API: `POST /api/notifications/v1/templates/preview/` for enterprise admins | Req: Template-10 | Depends: Templates + branding

### Test

- [ ] **[S]** Write `scripts/qa/verify-email-templates.sh`: check all 15 message types have EN/MS/ZH-Hans templates, verify branding variables render | AC: #25, #26, #27, #28 | Depends: All templates
- [ ] **[S]** Write `scripts/qa/smoke-test-bulk-campaign.sh`: schedule campaign, verify dispatch, check rate limiting, verify opt-out skipping | AC: #29, #30, #31, #32 | Depends: Bulk campaign engine

### Observability

- [ ] **[S]** Add Prometheus metrics: `notification_bulk_campaign_status`, `notification_bulk_campaign_send_rate`, `notification_celery_queue_depth` | Req: OBS-metrics | Depends: Bulk engine
- [ ] **[S]** Add Grafana dashboard panel: "Bulk Campaigns" -- campaigns per tenant, completion time, engagement metrics | Req: OBS-dashboards | Depends: Bulk metrics
- [ ] **[S]** Add alert: `notification_celery_queue_depth` > 10,000 for 15 minutes -- page oncall | Req: OBS-alerts | Depends: Queue metrics

### Rollout

- [ ] **[S]** Add feature flags: `notification_bulk_campaigns_enabled` (per org_slug, default: off), `notification_multilang_enabled` (default: off) | Req: Rollout | Depends: None

---

## Phase 6: Digests and Analytics (Week 13-16)

### Build

- [ ] **[L]** Implement digest generation Celery Beat task: daily (09:00 user TZ) and weekly (Monday 09:00 user TZ) digest batching, deduplication within digest window, suppress immediate email for digest-subscribed types (`infrastructure/tutor/apply-patches.sh`) | AC: #37, #38, #39 | Depends: Phase 2 (preferences), Phase 3 (in-app)
- [ ] **[M]** Build digest email templates: daily and weekly variants, grouped by course, summary with links | AC: #37, #39 | Depends: EN templates from Phase 5
- [ ] **[S]** Add digest frequency to notification preferences: `immediate` (default), `daily`, `weekly` | AC: #37 | Depends: Preferences API
- [ ] **[S]** Implement timezone fallback: default to `Asia/Kuala_Lumpur` (UTC+8) if user timezone not set; handle DST transitions | Edge case: Timezone | Depends: Digest task
- [ ] **[S]** Implement empty digest suppression: do not send digest if no notifications in period | Edge case: Empty digest | Depends: Digest task
- [ ] **[M]** Build click-tracking redirect endpoint: `GET /notifications/track/click/{tracking_id}/` with HMAC signature validation, log click event, redirect to original URL within 200ms (`infrastructure/tutor/apply-patches.sh`) | AC: #41 | Depends: None
- [ ] **[S]** Implement open tracking: transparent 1x1 pixel in email HTML body | AC: #40 | Depends: None
- [ ] **[M]** Set up engagement data storage: partitioned MySQL tables (monthly) for email events (send, delivery, bounce, open, click) -- ClickHouse if available per OQ-5 | AC: #40, #41, #42 | Depends: Click tracking + open tracking
- [ ] **[M]** Build admin analytics dashboard API: per-campaign and aggregate metrics, per-tenant filtering (`org_slug` isolation) | AC: #42 | Depends: Engagement data storage
- [ ] **[S]** Implement 12-month engagement data retention with purge job | Req: Analytics-7 | Depends: Engagement storage

### GDPR Integration

- [ ] **[S]** Include notification preferences and consent records in GDPR data export pipeline | AC: #44 | Depends: Preferences model
- [ ] **[S]** Include notification records, preferences, consent, device registrations in GDPR deletion pipeline | AC: #45 | Depends: All models

### Test

- [ ] **[S]** Write `scripts/qa/verify-digest-generation.sh`: check digest Celery task runs, verify digest email content, verify deduplication | AC: #37, #38, #39 | Depends: Digest task
- [ ] **[S]** Write `scripts/qa/verify-engagement-tracking.sh`: check open pixel, click redirect, engagement data storage, per-tenant isolation | AC: #40, #41, #42 | Depends: Analytics components
- [ ] **[S]** Write `scripts/qa/verify-gdpr-notification-data.sh`: check export includes preferences/consent, deletion removes all user notification data | AC: #44, #45 | Depends: GDPR integration

### Observability

- [ ] **[S]** Add Prometheus metrics: `notification_digest_generated_total` | Req: OBS-metrics | Depends: Digest task
- [ ] **[S]** Add Grafana dashboard panels: "Digest Analytics", "Engagement Analytics" | Req: OBS-dashboards | Depends: All Phase 6 metrics
- [ ] **[S]** Add alert: daily email volume > 50,000 -- info notification | Req: OBS-alerts | Depends: Email metrics

### Rollout

- [ ] **[S]** Add feature flags: `notification_digests_enabled` (per org_slug, default: off), `notification_click_tracking_enabled` (default: off) | Req: Rollout | Depends: None

---

## Cross-Phase: ACE Channel Registration

- [ ] **[M]** Register all 15 ACE message types with unique `message_type` identifiers in LMS settings (`infrastructure/tutor/apply-patches.sh`): `enrollment_confirmation`, `course_announcement`, `assignment_reminder`, `grade_posted`, `discussion_reply`, `discussion_mention`, `certificate_issued`, `course_start_reminder`, `course_completion`, `system_maintenance`, `password_reset`, `account_activation`, `enterprise_welcome`, `license_expiry_warning`, `bulk_campaign` | AC: #6, #7, #8, #9 | Depends: Phase 1
- [ ] **[M]** Connect Open edX event signals to ACE message types: `ENROLLMENT_CREATED` -> `enrollment_confirmation`, `COURSE_GRADE_NOW_PASSED` -> `course_completion`, `CERTIFICATE_CREATED` -> `certificate_issued`, `FORUM_THREAD_RESPONSE_CREATED` -> `discussion_reply`, etc. Ensure idempotency via `notification_id` deduplication in Redis (24-hour TTL) | AC: #9 | Depends: Phase 1
- [ ] **[M]** Implement notification scheduler Celery Beat task (every 15 minutes): scan `due_date` fields for upcoming assignment deadlines, enqueue `assignment_reminder` at 24h and 1h before deadline | AC: #29 (scheduler), Req: Scheduling-1 | Depends: Phase 2

---

## Milestones

| Milestone | Target Week | Success Criteria | Feature Flags |
|-----------|-------------|-----------------|---------------|
| M1: Email hardened | Week 2 | DKIM/SPF/DMARC pass, bounce webhook operational, suppression list active | None (infra-only) |
| M2: Preferences live | Week 4 | Preferences API functional, one-click unsubscribe works, GDPR consent tracked | `notification_preferences_enabled` |
| M3: In-app live | Week 6 | Notification tray shows real-time notifications, read/unread state persisted | `notification_inapp_enabled` |
| M4: Push live | Week 8 | Push notifications delivered to iOS TestFlight users via FCM | `notification_push_enabled` |
| M5: Bulk + i18n | Week 12 | Bulk campaigns to 10k recipients in 30 min, 3-language templates render correctly | `notification_bulk_campaigns_enabled`, `notification_multilang_enabled` |
| M6: Digests + analytics | Week 16 | Daily/weekly digests operational, engagement dashboard shows open/click rates | `notification_digests_enabled`, `notification_click_tracking_enabled` |

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| SES account suspension due to Kajabi-migrated bounce-prone addresses | Medium | Critical | Run email list hygiene before enabling bulk sends (OQ-8); set conservative rate limits; monitor bounce rate alerts |
| Firebase project not ready when Phase 4 starts | Medium | High | Decouple push dispatch behind feature flag; Phase 4 can start infra work while waiting for Firebase |
| Multi-language template authoring delays (no translator identified) | High | Medium | Ship Phase 5 with EN-only first; add MS/ZH-Hans when translations are ready; `notification_multilang_enabled` flag gates language selection |
| ClickHouse not available for engagement analytics | Medium | Low | Fall back to partitioned MySQL tables (spec allows this); migrate to ClickHouse later |
| Enterprise admin portal missing bulk email UI | Medium | Medium | Phase 5 can use Studio's existing bulk email tool for instructors; enterprise admin portal UI is a separate effort |
| User profile lacks timezone field | High | Low | Digest defaults to `Asia/Kuala_Lumpur` (UTC+8); timezone extension is a future enhancement |
| SES provider not formally ratified | Low | Medium | Architecture uses ACE's pluggable channels; if provider changes, only the channel backend needs replacement |
| ACE customizations conflict with Open edX upgrades | Medium | High | Keep patches minimal; use Tutor plugin system; test against upstream releases |

---

## Dependency Graph

```
Phase 1 (Email Infra)
    ├── Phase 2 (Preferences) ──── Phase 3 (In-App)
    │       │                          │
    │       ├── Phase 4 (Push) ────────┤
    │       │                          │
    │       └── Phase 5 (Bulk + i18n) ─┤
    │                                  │
    └──────────────────────────────────── Phase 6 (Digests + Analytics)

Cross-Phase: ACE registration spans Phases 1-3
```

Phase 1 is the foundation. Phases 2-5 depend on Phase 1. Phase 6 depends on Phases 2, 3, and 5 (templates). Within a phase, tasks are ordered by their "Depends" field.
