---
title: "Email & Notifications Pipeline - Test Plan"
source_spec: "specs/email-notifications-pipeline_spec.md"
created: "2026-02-10"
status: "draft"
---

# Test Plan: Email & Notifications Pipeline

**Source Spec**: `specs/email-notifications-pipeline_spec.md`

**Test Framework**: pytest (Python), shell scripts (verification), Agent Browser (E2E)

**Acceptance Criteria**: 45 ACs mapped to test cases

---

## Test Coverage Matrix

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| **Email Delivery Infrastructure** |
| 1 | SES domain `academyv2.mereka.io` has valid DKIM, SPF, DMARC records | manual | `scripts/infra/verify-ses-domain.sh academyv2.mereka.io` | None (live DNS check) |
| 1 | SES console shows `academyv2.mereka.io` verified | manual | AWS SES Console | None |
| 2 | SES domain `academy.biji-biji.com` has valid DKIM, SPF,DMARC records | manual | `scripts/infra/verify-ses-domain.shacademy.biji-biji.com` | None (live DNS check) |
| 2 | SES console shows `academy.biji-biji.com` verified | manual | AWS SES Console | None |
| 3 | Password reset email delivered within 30 seconds | e2e| `tests/e2e/test_email_delivery.py` | Live SES, test user account |
| 3 | Email From header shows `noreply@academyv2.mereka.io` |integration | `tests/integration/test_email_headers.py` | Mock SMTP server |
| 4 | Custom MAIL FROM domain `mail.academyv2.mereka.io` aligns envelope sender | manual | `dig MX mail.academyv2.mereka.io` | None (live DNS check) |
| 4 | DMARC alignment passes for sent email | integration | `tests/integration/test_dmarc_alignment.py` | Mock email withheaders |
| 5 | Per-tenant sender identity shows custom From display name | integration | `tests/integration/test_tenant_sender_identity.py` | Mock EnterpriseCustomer with display_name |
| 5 | Enterprise email From shows "Acme Corp via Mereka Academy" | unit | `tests/unit/test_from_display_name.py` | Mock ACE message context with org_slug |
| **ACE Channels** |
| 6 | Course announcement dispatches to email, push, in_app for user with all enabled | integration | `tests/integration/test_ace_channel_dispatch.py` | Mock ACE message, user with all channels enabled |
| 6 | ACE dispatches to all three channels simultaneously | unit | `tests/unit/test_ace_channel_routing.py` | Mock ACE channels |
| 7 | User with email disabled receives push and in_app but no email | integration | `tests/integration/test_preference_filtering.py` | Mock preferences, ACE message |
| 7 | Preference filtering logged for audit | unit | `tests/unit/test_preference_filtering_log.py` | Mock logger |
| 8 | Password reset email sent even if user disabled all channels | integration | `tests/integration/test_system_critical_bypass.py` | Mock preferences (all disabled), password_resetmessage |
| 8 | Account activation email sent even if user disabled allchannels | integration | `tests/integration/test_system_critical_bypass.py` | Mock preferences (all disabled), account_activation message |
| 9 | 100 ACE messages dispatched within 60 seconds | load |`tests/performance/test_ace_dispatch_throughput.py` | Mock Celery workers, 100 messages |
| 9 | Celery queue `edx.lms.core.default` processes messagesin order | integration | `tests/integration/test_celery_queue_processing.py` | Mock Celery broker (Redis) |
| **In-App Notifications** |
| 10 | GET /api/notifications/v1/unread-count/ returns correct count | integration | `tests/integration/test_inapp_api.py`| Pre-create 5 unread notifications |
| 10 | Unread count API p95 latency <100ms | performance | `tests/performance/test_inapp_api_latency.py` | 1000 concurrentrequests |
| 11 | GET /api/notifications/v1/?read=false returns only unread notifications | integration | `tests/integration/test_inapp_api.py` | Pre-create 30 read, 20 unread notifications |
| 11 | Notification list sorted by created_at DESC | unit | `tests/unit/test_notification_list_sorting.py` | Mock notification queryset |
| 12 | Expired notification not included in API response | integration | `tests/integration/test_inapp_api.py` | Pre-create notification with expires_at in past |
| 12 | Expired notification purge job deletes notifications older than 90 days | integration | `tests/integration/test_notification_purge.py` | Mock Celery Beat task, old notifications |
| 13 | POST /api/notifications/v1/mark-all-read/ sets all unread to read | integration | `tests/integration/test_inapp_api.py` | Pre-create 10 unread notifications |
| 13 | Unread count is 0 after mark-all-read | integration |`tests/integration/test_inapp_api.py` | Follow-up to mark-all-read test |
| 14 | User sees only notifications for their org_slug | integration | `tests/integration/test_tenant_isolation_inapp.py`| Pre-create notifications for acme and beta tenants |
| 14 | Cross-tenant notification leakage blocked | security |`tests/security/test_inapp_tenant_isolation.py` | Attempt toaccess notification from different org_slug |
| **Push Notifications** |
| 15 | Device registration via POST /api/mobile/v1/notifications/register/ creates record | integration | `tests/integration/test_device_registration.py` | Mock FCM token |
| 15 | Push notification delivered to FCM within 60 seconds |e2e | `tests/e2e/test_push_delivery.py` | Live FCM, TestFlight app |
| 16 | Device marked inactive on FCM UNREGISTERED error | integration | `tests/integration/test_push_error_handling.py` |Mock FCM error response |
| 16 | No further pushes sent to inactive device | integration | `tests/integration/test_push_inactive_device.py` | Pre-mark device inactive, trigger notification |
| 17 | DELETE /api/mobile/v1/notifications/register/ removesdevice | integration | `tests/integration/test_device_deregistration.py` | Pre-register device |
| 17 | Push not sent after device deregistration | integration | `tests/integration/test_push_after_deregister.py` | Deregister device, trigger notification |
| 18 | 1,000 push notifications batched into 2 FCM API calls(500 each) | integration | `tests/integration/test_push_batching.py` | Mock FCM API, 1000 device tokens |
| 18 | FCM batch API called with correct payload structure |unit | `tests/unit/test_fcm_batch_payload.py` | Mock FCM client |
| 19 | Push notification for org_slug=acme only sent to acmedevices | integration | `tests/integration/test_tenant_isolation_push.py` | Pre-register devices for acme and beta tenants|
| 19 | Cross-tenant push delivery blocked | security | `tests/security/test_push_tenant_isolation.py` | Attempt to send acme notification to beta device |
| **Notification Preferences** |
| 20 | New user without preferences receives defaults (all enabled except bulk_campaign email) | integration | `tests/integration/test_preferences_defaults.py` | Create new user, callGET /preferences/ |
| 20 | Default bulk_campaign email preference is disabled | unit | `tests/unit/test_preference_defaults.py` | Mock defaultpreferences |
| 21 | PUT /api/notifications/v1/preferences/ disables discussion_reply email | integration | `tests/integration/test_preference_update.py` | Update preferences, trigger discussion_reply |
| 21 | Preference update creates audit log entry | integration | `tests/integration/test_preference_audit.py` | Update preferences, query audit table |
| 22 | One-click unsubscribe link disables bulk_campaign andcourse_announcement email | integration | `tests/integration/test_unsubscribe_link.py` | Generate signed token, call unsubscribe endpoint |
| 22 | Expired unsubscribe token (>90 days) redirects to preferences page | integration | `tests/integration/test_unsubscribe_expired_token.py` | Generate expired token |
| 23 | Preference change logged with all required fields | unit | `tests/unit/test_preference_audit_fields.py` | Mock audit record |
| 23 | IP address hashed in audit log (not plaintext) | security | `tests/security/test_audit_log_pii.py` | Update preference, verify log |
| 24 | Bulk campaign email includes List-Unsubscribe and List-Unsubscribe-Post headers | integration | `tests/integration/test_rfc8058_headers.py` | Send bulk campaign email, parse headers |
| 24 | One-click unsubscribe URL in header is valid and signed | unit | `tests/unit/test_unsubscribe_url_signature.py` | Mock unsubscribe URL generation |
| **Multi-Language Templates** |
| 25 | User with language_preference=ms receives Malay email| integration | `tests/integration/test_multilang_templates.py` | Mock user with ms preference, trigger enrollment_confirmation |
| 25 | Malay template subject and body render correctly | unit | `tests/unit/test_malay_template.py` | Mock ACE context with ms language |
| 26 | User with language_preference=zh-hans receives Chineseemail | integration | `tests/integration/test_multilang_templates.py` | Mock user with zh-hans preference, trigger grade_posted |
| 26 | Chinese template subject and body render correctly | unit | `tests/unit/test_chinese_template.py` | Mock ACE context with zh-hans language |
| 27 | User with unsupported language (ja) receives English fallback | integration | `tests/integration/test_multilang_fallback.py` | Mock user with ja preference |
| 27 | Fallback to English logged | unit | `tests/unit/test_language_fallback_log.py` | Mock language selection logic |
| 28 | Email template renders tenant branding variables | integration | `tests/integration/test_tenant_branding.py` | MockEnterpriseCustomer with branding fields, render template |
| 28 | Branding variables include org_display_name, org_logo_url, org_support_email | unit | `tests/unit/test_branding_variables.py` | Mock ACE context with org_slug |
| **Bulk Messaging** |
| 29 | Bulk campaign to 10,000 recipients completes within 30minutes | performance | `tests/performance/test_bulk_campaign_throughput.py` | Mock 10,000 users, send campaign |
| 29 | Scheduled campaign begins at scheduled time | integration | `tests/integration/test_campaign_scheduling.py` | Schedule campaign, mock time |
| 30 | Pause campaign stops sending, resume continues from checkpoint | integration | `tests/integration/test_campaign_pause_resume.py` | Start campaign, pause, resume |
| 30 | Checkpoint-based processing resumes after worker crash| integration | `tests/integration/test_campaign_recovery.py` | Mock worker crash, restart |
| 31 | Campaign to 10,000 recipients with 500 opted out sends9,500, skips 500 | integration | `tests/integration/test_campaign_opt_out.py` | Mock 10,000 users, 500 opted out |
| 31 | Campaign metrics report sent count, skipped count, bounced count | integration | `tests/integration/test_campaign_metrics.py` | Send campaign, query metrics API |
| 32 | Two tenants sending simultaneously respect per-tenantrate limit (50 emails/sec) | integration | `tests/integration/test_rate_limiting_multi_tenant.py` | Mock two tenants, sendsimultaneously |
| 32 | Combined rate does not exceed SES account limit | performance | `tests/performance/test_global_rate_limit.py` | Mock SES rate limit, send from multiple tenants |
| **Bounce and Complaint Handling** |
| 33 | Hard bounce adds email to suppression list and marks user undeliverable | integration | `tests/integration/test_bounce_handling.py` | Mock SNS bounce notification (hard) |
| 33 | Suppression list blocks subsequent sends to bounced address | integration | `tests/integration/test_suppression_list_enforcement.py` | Add email to suppression list, attempt send |
| 34 | Third soft bounce within 7 days treated as hard bounce| integration | `tests/integration/test_soft_bounce_threshold.py` | Mock 3 soft bounce SNS notifications |
| 34 | Soft bounce counter resets after 7 days | unit | `tests/unit/test_soft_bounce_ttl.py` | Mock Redis counter with TTL|
| 35 | Complaint disables bulk_campaign preference and adds to suppression list | integration | `tests/integration/test_complaint_handling.py` | Mock SNS complaint notification |
| 35 | Complaint logged with user_id_hash, email_hash, complaint_type | unit | `tests/unit/test_complaint_logging.py` | Mock complaint handler |
| 36 | Bounce rate >5% fires critical alert | integration | `tests/integration/test_bounce_rate_alert.py` | Mock Prometheus alert rule, trigger alert |
| 36 | Complaint rate >0.1% fires critical alert | integration | `tests/integration/test_complaint_rate_alert.py` | Mock Prometheus alert rule, trigger alert |
| **Digests** |
| 37 | User on daily digest receives one email at 09:00 summarizing 10 replies | integration | `tests/integration/test_daily_digest.py` | Mock user with daily digest, 10 discussion_reply notifications |
| 37 | Digest groups notifications by course | unit | `tests/unit/test_digest_grouping.py` | Mock notifications for multiple courses |
| 38 | User on daily digest does not receive immediate email| integration | `tests/integration/test_digest_suppression.py` | Mock user with daily digest, trigger course_announcement|
| 38 | Push and in-app remain immediate for digest user | integration | `tests/integration/test_digest_immediate_push.py`| Mock user with daily digest, verify push sent immediately |
| 39 | 5 replies to same thread shown as "5 new replies" in digest | unit | `tests/unit/test_digest_deduplication.py` | Mock 5 discussion_reply notifications for same thread |
| 39 | Empty digest not sent | integration | `tests/integration/test_empty_digest.py` | Mock user with daily digest, no notifications in period |
| **Engagement Analytics** |
| 40 | Open tracking pixel logs open event | integration | `tests/integration/test_open_tracking.py` | Mock email open (pixel load) |
| 40 | Open event includes campaign_id, user_id, timestamp |unit | `tests/unit/test_open_event_fields.py` | Mock open tracking endpoint |
| 41 | Click tracking URL redirects to original within 200ms| performance | `tests/performance/test_click_tracking_latency.py` | Mock click tracking endpoint |
| 41 | Click event logged before redirect | integration | `tests/integration/test_click_tracking.py` | Mock click, verifyevent logged |
| 42 | Enterprise admin sees only their tenant campaign data| integration | `tests/integration/test_analytics_tenant_isolation.py` | Mock two tenants, query analytics API |
| 42 | Cross-tenant analytics leakage blocked | security | `tests/security/test_analytics_tenant_isolation.py` | Attempt to access other tenant's campaign data |
| **GDPR Compliance** |
| 43 | User without opt-in does not receive bulk_campaign email | integration | `tests/integration/test_gdpr_opt_in.py` |Mock user without consent, send bulk campaign |
| 43 | Marketing consent version recorded on opt-in | unit |`tests/unit/test_consent_version_tracking.py` | Mock preference update with consent |
| 44 | GDPR export includes notification preferences and consent records | integration | `tests/integration/test_gdpr_export_notifications.py` | Trigger GDPR export, verify notification data included |
| 44 | GDPR export does not include other users' notificationdata | security | `tests/security/test_gdpr_export_isolation.py` | Export for user A, verify no user B data |
| 45 | GDPR deletion removes all notification records for user | integration | `tests/integration/test_gdpr_deletion_notifications.py` | Trigger GDPR deletion, verify notification_store, preferences, device_registrations deleted |
| 45 | GDPR deletion preserves aggregate analytics (no user linkage) | integration | `tests/integration/test_gdpr_deletion_analytics.py` | Delete user, verify engagement metrics stillqueryable without user_id |
| **Edge Cases (Negative Tests)** |
| EC-1 | SES rate limit exceeded queues messages locally withexponential backoff | integration | `tests/integration/test_ses_rate_limit_queue.py` | Mock SES rate limit exceeded response |
| EC-2 | SES region outage queues messages, does not drop | integration | `tests/integration/test_ses_outage_queue.py` | Mock SES endpoint unreachable (5min timeout) |
| EC-3 | Invalid sender address falls back to default verified sender | integration | `tests/integration/test_invalid_sender_fallback.py` | Mock tenant with unverified sender address|
| EC-4 | Email exceeding 10MB SES limit rejected with clear error | integration | `tests/integration/test_email_size_limit.py` | Mock bulk campaign with large inline images |
| EC-5 | Admin removal from suppression list allows sending |integration | `tests/integration/test_suppression_list_removal.py` | Add to suppression list, admin removes, attempt send|
| EC-6 | Bounce storm from Kajabi data triggers alert | integration | `tests/integration/test_bounce_storm_alert.py` | Mock 100 bounces in 1 hour |
| EC-7 | SES account suspension detected, email sending paused | integration | `tests/integration/test_ses_suspension_detection.py` | Mock ACCOUNT_SENDING_PAUSED status |
| EC-8 | FCM quota exceeded queues messages with backoff | integration | `tests/integration/test_fcm_quota_exceeded.py` |Mock FCM quota limit exceeded response |
| EC-9 | iOS device token update deduplicates registration |integration | `tests/integration/test_device_token_update.py`| Register token, re-register updated token |
| EC-10 | Silent push notification includes alert payload | unit | `tests/unit/test_push_payload_validation.py` | Mock FCMpayload, verify alert field present |
| EC-11 | FCM service account key rotation graceful transition | manual | `docs/runbooks/push-notifications-runbook.md` |Document rotation procedure, test with old key during transition |
| EC-12 | Preference race condition uses last-write-wins | integration | `tests/integration/test_preference_race_condition.py` | Mock simultaneous preference updates from two tabs |
| EC-13 | Consent version migration re-prompts for updated consent | integration | `tests/integration/test_consent_version_migration.py` | Update consent version, verify re-prompt |
| EC-14 | Expired unsubscribe token redirects to preferencespage with login required | integration | `tests/integration/test_unsubscribe_expired_redirect.py` | Mock expired token (>9days) |
| EC-15 | Notification flood batches 100 replies into singlein-app notification | integration | `tests/integration/test_notification_batching.py` | Mock 100 discussion_reply events in 1 minute |
| EC-16 | Notification list API cursor-based pagination handles 10,000+ notifications | performance | `tests/performance/test_inapp_pagination.py` | Pre-create 10,000 notifications for user |
| EC-17 | Digest for user without timezone defaults to Asia/Kuala_Lumpur | unit | `tests/unit/test_digest_timezone_fallback.py` | Mock user without timezone |
| EC-18 | Empty digest not sent | integration | `tests/integration/test_empty_digest.py` | Mock user with digest, no notifications in period |
| EC-19 | Celery task retry does not duplicate notifications| integration | `tests/integration/test_celery_idempotency.py` | Mock Celery task failure, retry |
| EC-20 | SNS webhook idempotent (duplicate MessageId ignored) | integration | `tests/integration/test_sns_webhook_idempotency.py` | Send duplicate SNS notification |
| EC-21 | Preferences API rate limiting blocks 11th request in 1 minute | integration | `tests/integration/test_preferences_rate_limiting.py` | Mock 11 requests from same user |

---

## Test Execution Strategy

### Unit Tests
- Run with `pytest tests/unit/`
- Mock all external dependencies (SES, FCM, Redis, MySQL, Celery)
- Fast execution (<10 minutes for full unit suite)
- Coverage target: >80% for new notification code

### Integration Tests
- Run with `pytest tests/integration/`
- Use test database and test Redis instance
- Mock external services (SES, FCM) with test servers or stubs
- Execution time: 30-60 minutes for full integration suite

### E2E Tests
- Run with Agent Browser (headless browser automation)
- Require live SES sandbox, live FCM test project, TestFlightapp
- Execution time: 60-90 minutes for full E2E suite
- Run nightly in CI

### Performance Tests
- Run with `pytest tests/performance/`
- Use production-like data volumes (10,000 users, 1,000 notifications)
- Measure latency percentiles and throughput
- Execution time: 30-60 minutes
- Run weekly in CI

### Manual Tests
- Verification scripts run as part of CI/CD pipeline
- DNS checks (DKIM, SPF, DMARC) run on every PR
- SES console checks run post-deployment
- FCM key rotation documented in runbook

---

## Test Data Requirements

### Fixtures
- Mock users (with various language preferences, org_slugs, preference configurations)
- Mock ACE messages (all 15 message types)
- Mock SNS notifications (bounce, complaint, open, click events)
- Mock FCM tokens (iOS and Android)
- Mock EnterpriseCustomer records (with branding fields)
- Mock notification records (read, unread, expired, various message types)
- Mock bulk campaigns (scheduled, sending, paused, completed)

### Test Secrets
- Test SES SMTP credentials (for sandbox)
- Test FCM service account key (for test Firebase project)
- Test unsubscribe HMAC secret
- Test click tracking HMAC secret

### Mock Services
- Mock SES SMTP relay (captures outbound emails)
- Mock FCM API (responds to push dispatch)
- Mock SNS webhook sender (sends bounce/complaint notifications)
- Mock Redis (for Celery broker and rate limiting)

---

## Negative Test Cases

| Negative Scenario | Test Case | Type | File |
|-------------------|-----------|------|------|
| SES rate limit exceeded | Messages queued with exponentialbackoff | integration | `tests/integration/test_ses_rate_limit_queue.py` |
| SES region outage | Messages queued, not dropped | integration | `tests/integration/test_ses_outage_queue.py` |
| Invalid sender address | Fallback to default sender | integration | `tests/integration/test_invalid_sender_fallback.py`|
| Email exceeding SES 10MB limit | Rejected with clear error| integration | `tests/integration/test_email_size_limit.py`|
| Bounce storm (Kajabi data) | Alert fires, suppression listupdated | integration | `tests/integration/test_bounce_storm_alert.py` |
| SES account suspension | Detected, sending paused, alert fired | integration | `tests/integration/test_ses_suspension_detection.py` |
| FCM quota exceeded | Messages queued with backoff | integration | `tests/integration/test_fcm_quota_exceeded.py` |
| Expired unsubscribe token | Redirect to preferences with login | integration | `tests/integration/test_unsubscribe_expired_redirect.py` |
| Notification flood (100 replies/min) | Batched into singlenotification | integration | `tests/integration/test_notification_batching.py` |
| Celery task retry | No duplicate notifications | integration | `tests/integration/test_celery_idempotency.py` |
| SNS webhook retry | Idempotent (duplicate MessageId ignored) | integration | `tests/integration/test_sns_webhook_idempotency.py` |
| Preferences API abuse | Rate limiting blocks excess requests | integration | `tests/integration/test_preferences_rate_limiting.py` |
| Cross-tenant notification leakage | Blocked, security eventlogged | security | `tests/security/test_inapp_tenant_isolation.py` |
| Cross-tenant push delivery | Blocked, security event logged| security | `tests/security/test_push_tenant_isolation.py`|
| Cross-tenant analytics leakage | Blocked, security event logged | security | `tests/security/test_analytics_tenant_isolation.py` |

---

## Performance Test Cases

| Performance Requirement | Test Case | Type | File | Target|
|------------------------|-----------|------|------|--------|
| Transactional email latency | Measure p95 time from ACE enqueue to SES send | performance | `tests/performance/test_email_latency.py` | <=30s at p95 |
| Bulk email throughput | Send 10,000 emails, measure completion time | performance | `tests/performance/test_bulk_throughput.py` | <=30min total |
| In-app list API latency | Measure p95 for GET /api/notifications/v1/ | performance | `tests/performance/test_inapp_api_latency.py` | <=200ms at p95 |
| In-app unread count latency | Measure p95 for GET /unread-count/ | performance | `tests/performance/test_inapp_api_latency.py` | <=100ms at p95 |
| Push dispatch latency | Measure p95 time from event to FCMcall | performance | `tests/performance/test_push_latency.py`| <=60s at p95 |
| Preferences API latency | Measure p95 for GET/PUT /preferences/ | performance | `tests/performance/test_preferences_api_latency.py` | <=150ms at p95 |
| Digest generation time | Generate digest for 10,000 users |performance | `tests/performance/test_digest_generation.py`| <=15min total |
| Click tracking redirect latency | Measure p95 for click redirect | performance | `tests/performance/test_click_tracking_latency.py` | <=200ms at p95 |

---

## Security Test Cases (GDPR, Tenant Isolation, PII Protection)

| Security Control | Test Case | Type | File |
|------------------|-----------|------|------|
| Tenant isolation (in-app) | User cannot access notifications from other tenant | security | `tests/security/test_inapp_tenant_isolation.py` |
| Tenant isolation (push) | Push not sent to devices from other tenant | security | `tests/security/test_push_tenant_isolation.py` |
| Tenant isolation (analytics) | Admin cannot access other tenant's campaign data | security | `tests/security/test_analytics_tenant_isolation.py` |
| PII protection (logs) | Logs do not contain plaintext emails, tokens, session IDs | security | `tests/security/test_log_pii_redaction.py` |
| PII protection (audit) | Audit logs use hashed IP addresses, not plaintext | security | `tests/security/test_audit_log_pii.py` |
| GDPR opt-in enforcement | Marketing emails require explicitconsent | integration | `tests/integration/test_gdpr_opt_in.py` |
| GDPR data export | Export includes all notification data for user only | security | `tests/security/test_gdpr_export_isolation.py` |
| GDPR data deletion | Deletion removes all notification datafor user | integration | `tests/integration/test_gdpr_deletion_notifications.py` |
| Unsubscribe token validation | Invalid/expired token rejected | security | `tests/security/test_unsubscribe_token_security.py` |
| Click tracking token validation | Invalid signature rejected (open redirect prevention) | security | `tests/security/test_click_tracking_token_security.py` |
| SNS webhook signature validation | Invalid signature rejected (spoofing prevention) | security | `tests/security/test_sns_webhook_signature.py` |

---

## Observability Verification

| Metric/Log/Alert | Verification Test | Type | File |
|------------------|-------------------|------|------|
| notification_emails_sent_total metric incremented | Triggeremail send, query Prometheus | integration | `tests/integration/test_metrics.py` |
| notification_emails_bounced_total fires alert | Trigger bounces, verify alert | integration | `tests/integration/test_bounce_rate_alert.py` |
| notification_push_sent_total metric incremented | Trigger push send, query Prometheus | integration | `tests/integration/test_metrics.py` |
| notification_inapp_created_total metric incremented | Trigger in-app notification, query Prometheus | integration | `tests/integration/test_metrics.py` |
| notification_celery_queue_depth gauge updated | Enqueue messages, query Prometheus | integration | `tests/integration/test_metrics.py` |
| Email dispatch event log contains required fields | Parse logs after email send | integration | `tests/integration/test_email_event_logging.py` |
| Push dispatch event log contains required fields | Parse logs after push send | integration | `tests/integration/test_push_event_logging.py` |
| Sensitive data not in logs | Trigger events, grep logs forPII | security | `tests/security/test_log_pii_redaction.py` |
| Grafana dashboard queries valid | Query dashboard JSON, verify PromQL syntax | unit | `tests/unit/test_dashboard_queries.py` |

---

## CI/CD Integration

### Pre-merge (Pull Request)
- Run unit tests: `pytest tests/unit/`
- Run integration tests: `pytest tests/integration/`
- Run security tests: `pytest tests/security/`
- Run linting: `ruff check`, `shellcheck scripts/`

### Post-merge (Main Branch)
- Run E2E tests: `pytest tests/e2e/`
- Run performance tests: `pytest tests/performance/` (nightly)

### Post-deployment
- Run DNS verification: `scripts/infra/verify-ses-domain.sh academyv2.mereka.io`
- Verify SES console domain status
- Run smoke tests: `scripts/qa/verify-email-delivery.sh --env=prod`
- Verify observability: Check metrics in Grafana, verify alerts not firing

---

## Test Environment Setup

### Local Development
- Docker Compose with LMS, Redis, MySQL, mock SES, mock FCM
- Seed test data: users with various preferences, enterprisetenants, notifications
- Generate test secrets: unsubscribe HMAC secret, click tracking secret

### CI Environment (GitHub Actions)
- Kind cluster with LMS, Redis, MySQL, mock SES, mock FCM
- Use ephemeral test database
- Test secrets stored in GitHub Secrets

### Staging Environment
- Full GKE cluster with production-like configuration
- SES sandbox account
- FCM test project
- Run full E2E suite nightly

---

## Success Criteria

- [ ] All 45 acceptance criteria have at least one passing test case
- [ ] All edge cases have negative test coverage
- [ ] Unit test coverage >80% for new notification code
- [ ] Integration tests cover all cross-service interactions(ACE, SES, FCM, preferences)
- [ ] E2E tests cover full user flows (email delivery, push delivery, in-app notification, preferences update, bulk campaign)
- [ ] Performance tests meet latency targets (email <30s, bulk <30min, in-app <200ms, unread-count <100ms, push <60s, preferences <150ms)
- [ ] Security tests verify tenant isolation, PII protection,GDPR compliance
- [ ] All verification scripts pass in CI (verify-ses-domain.sh, verify-email-delivery.sh)
- [ ] Observability verification confirms metrics, logs, andalerts are working
- [ ] No sensitive data (emails, tokens, session IDs) found in logs

---

## Test Ownership

- **Unit Tests**: Backend engineers implementing each feature
- **Integration Tests**: Backend engineers + QA engineers
- **E2E Tests**: QA engineers + DevOps (Agent Browser setup,TestFlight coordination)
- **Performance Tests**: DevOps engineers
- **Security Tests**: Security engineers (GDPR verification,tenant isolation)
- **Verification Scripts**: DevOps engineers
- **Observability Tests**: SRE/DevOps engineers

---

## Rollback Test Cases

| Rollback Scenario | Test Case | Type | File |
|-------------------|-----------|------|------|
| Disable push notifications | Set ENABLE_NOTIFICATION_PUSH=false, verify email and in-app still work | integration | `tests/integration/test_rollback_push.py` |
| Disable in-app notifications | Set ENABLE_NOTIFICATION_INAPP=false, verify email and push still work | integration | `tests/integration/test_rollback_inapp.py` |
| Disable notification preferences | Set ENABLE_NOTIFICATION_PREFERENCES=false, verify all channels dispatch | integration| `tests/integration/test_rollback_preferences.py` |
| Disable bulk campaigns | Set ENABLE_NOTIFICATION_BULK_CAMPAIGNS=false, verify transactional email still works | integration | `tests/integration/test_rollback_bulk_campaigns.py` |
| Disable digests | Set ENABLE_NOTIFICATION_DIGESTS=false, verify immediate notifications resume | integration | `tests/integration/test_rollback_digests.py` |
| Disable click tracking | Set ENABLE_NOTIFICATION_CLICK_TRACKING=false, verify URLs not rewritten | integration | `tests/integration/test_rollback_click_tracking.py` |
| Disable multi-language templates | Set ENABLE_NOTIFICATION_MULTILANG=false, verify fallback to English | integration | `tests/integration/test_rollback_multilang.py` |

---

## Open Questions for Testing

1. **Mock FCM choice**: Use live FCM test project or build custom mock HTTP server for faster tests?
2. **Test SES keys**: Use live SES sandbox or mock SMTP server for integration tests?
3. **Live push notification testing**: How to safely test push delivery to TestFlight without disrupting beta users?
4. **Performance test load**: What is realistic notificationvolume for sizing performance tests (100k emails/day)?
5. **Bounce storm testing**: How to safely test bounce rate alerts without risking SES account reputation?

---

**Source Spec**: `specs/email-notifications-pipeline_spec.md`
