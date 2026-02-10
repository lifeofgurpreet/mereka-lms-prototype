---
title: "Email & Notifications Pipeline"
type: "feature_spec"
status: "draft"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
links:
  related_docs:
    - "docs/runbooks/email-notifications-runbook.md"
    - "docs/operations/TROUBLESHOOTING.md"
    - "docs/architecture/notification-pipeline-overview.md"
  related_specs:
    - "specs/mobile-apps-enterprise_spec.md"
    - "specs/enterprise-microservices_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/data-privacy-gdpr-compliance_spec.md"
    - "specs/multi-tenancy-architecture_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/slo-sla-service-level-management_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

A production-grade email and notification pipeline for Mereka Academy that unifies all learner, instructor, and enterprise communications across four delivery channels: transactional email (AWS SES), bulk email (AWS SES with throttling), in-app notifications (notification tray), and push notifications (Firebase Cloud Messaging / Apple Push Notification service). The pipeline is built on Open edX's Automated Communications Engine (ACE) as the message orchestration layer, extended with a notification preferences service, multi-language template rendering (English, Malay, Chinese), enterprise bulk messaging, and comprehensive delivery analytics.

The current state is a partially configured system: AWS SES is wired via an exim relay pod (`devture/exim-relay:4.96-r1-0`) in the `mereka-lms` K8s namespace, ACE is configured to forward all messages through the `django_email` channel, and bulk email uses ACE (`BULK_EMAIL_SEND_USING_EDX_ACE = True`). There is no in-app notification tray, no push notification integration, no formal preference management, no multi-language template system, no delivery analytics, and no bounce/complaint handling automation. This spec establishes the full contract for a reliable, observable, multi-channel notification pipeline that scales across enterprise tenants.

## Why it matters

Learner engagement is directly correlated with timely, relevant communications. Without a formal notification pipeline:

- Learners miss assignment deadlines because there are no reminder notifications (email-only, and email deliverability is unmonitored)
- Enterprise clients cannot send targeted announcements to their learner cohorts without Django admin access
- Mobile app users (iOS, already in TestFlight; Android, in development per `specs/mobile-apps-enterprise_spec.md`) have no push notification support
- SES reputation is unmanaged: a single bounce spike from invalid Kajabi-migrated email addresses could land the sending domain on blocklists, affecting all transactional email including password resets and enrollment confirmations
- There is no mechanism for learners to control notification frequency, leading to unsubscribes and spam complaints that compound deliverability problems
- Enterprise clients in EU/Malaysia markets require GDPR/PDPA-compliant consent management for marketing communications, which does not exist

## Success looks like

- Transactional emails (password reset, enrollment confirmation, grade posted) deliver within 30 seconds of trigger with >= 99% delivery rate to valid addresses
- Bulk email campaigns to 10,000 recipients complete within 30 minutes with per-tenant rate limiting that keeps SES complaint rate below 0.1%
- Push notifications reach mobile devices within 60 seconds of trigger with >= 98% delivery to FCM/APNs
- In-app notification tray shows real-time notifications with read/unread state persisted per user
- Learners can configure per-channel, per-type notification preferences from a single settings page
- Multi-language email templates render correctly in EN, MS (Malay), and ZH (Chinese) based on user language preference
- Bounce rate stays below 2% through automated suppression list management
- Notification analytics dashboard shows delivery rates, open rates, click-through rates, bounce rates, and complaint rates per tenant per notification type
- A new enterprise tenant's notification configuration (sender identity, branding, consent policy) is operational within 4 hours

---

# Agent Contract

## Scope

- In scope:
  - AWS SES configuration, sending domain verification, DKIM/SPF/DMARC alignment for `academyv2.mereka.io` and `academy.biji-biji.com`
  - ACE channel configuration: `django_email`, `push`, and `in_app` channels
  - ACE message type registry for all notification types
  - Exim relay pod hardening and monitoring (existing `smtp` deployment in `mereka-lms` namespace)
  - In-app notification tray backend (REST API) and MFE integration
  - Push notification integration with Firebase Cloud Messaging (FCM) and APNs (via FCM)
  - Device token registration and lifecycle (coordinates with `specs/mobile-apps-enterprise_spec.md`)
  - Notification preferences service: per-user, per-channel, per-type opt-in/opt-out with GDPR consent tracking
  - Email template system with multi-language support (EN, MS, ZH)
  - Bulk messaging engine with per-tenant rate limiting, scheduling, and segmentation
  - Bounce handling, complaint processing, and SES suppression list automation
  - Notification scheduling, batching, and digest generation
  - Delivery analytics and engagement metrics
  - Message personalization and dynamic content interpolation
  - ExternalSecrets for SES credentials, FCM service account key
  - Observability: logs, metrics, alerts, dashboards for all channels

- Out of scope:
  - SMS/WhatsApp messaging channels (future consideration)
  - Marketing automation platform integration (HubSpot, Mailchimp)
  - Custom email editor UI for non-technical users (enterprise admins use existing bulk email tool in Studio)
  - Email archival or long-term message storage beyond 90-day delivery logs
  - Mobile app UI implementation for notification tray (covered by `specs/mobile-apps-enterprise_spec.md`)
  - Push notification payload format and deep linking (defined in `specs/mobile-apps-enterprise_spec.md`)
  - Content moderation for user-generated notification content (forum replies)
  - A/B testing of notification content or timing

## Non-goals

- Replacing ACE with a third-party notification orchestration service (OneSignal, Customer.io, etc.) -- ACE is the platform standard and switching would require forking edx-platform
- Building a real-time WebSocket notification system -- in-app notifications use polling or server-sent events, not persistent WebSocket connections
- Supporting per-tenant custom SMTP relays -- all tenants share the Mereka Academy SES infrastructure with per-tenant sender identities
- Implementing email deliverability consulting or inbox placement testing -- the spec covers infrastructure, not content optimization
- Building a notification template marketplace or sharing system between tenants

## Assumptions

- AWS SES is already partially configured: the `smtp` deployment in `mereka-lms` uses `devture/exim-relay:4.96-r1-0` relaying through `email-smtp.ap-southeast-1.amazonaws.com:587` with credentials from the `ses-smtp-credentials` K8s secret
- The sending domain `academyv2.mereka.io` has a CNAME record `mail.academyv2.mereka.io` pointing to `academyv2.mereka.io` (confirmed in `infrastructure/cloudflare/records.json`)
- ACE is enabled in production LMS settings with `ACE_ENABLED_CHANNELS = ["django_email"]`, `ACE_CHANNEL_DEFAULT_EMAIL = "django_email"`, `ACE_CHANNEL_TRANSACTIONAL_EMAIL = "django_email"`, and `BULK_EMAIL_SEND_USING_EDX_ACE = True`
- The Firebase project `mereka-academy` exists per `specs/mobile-apps-enterprise_spec.md` assumptions, configured for both iOS and Android
- Celery workers are running with Redis as the broker (`CELERY_BROKER_TRANSPORT: "redis"`) and handle ACE message dispatch
- Multi-tenancy uses `org_slug` as the tenant identifier (per `specs/multi-tenancy-architecture_spec.md`)
- User language preference is stored in the Open edX user profile (`LANGUAGE_CODE` default is `en`)
- Infisical is the secrets source of truth (per `specs/secrets-management_spec.md`), synced to GCP Secret Manager, then to K8s via ExternalSecrets

---

## Requirements

### Functional

#### Email Delivery Infrastructure (AWS SES)

- The system MUST use AWS SES (ap-southeast-1 region) as the email delivery provider for all outbound email
- The system MUST verify the sending domain `academyv2.mereka.io` with SES using DKIM (1024-bit or 2048-bit RSA keys), SPF (include `amazonses.com`), and DMARC (`v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@mereka.io; pct=100`)
- The system MUST verify the sending domain `academy.biji-biji.com` with SES using the same DKIM/SPF/DMARC configuration
- The system MUST use a dedicated SES configuration set named `mereka-academy-production` for all production email
- The SES configuration set MUST enable event publishing to Amazon SNS for the following event types: `send`, `delivery`, `bounce`, `complaint`, `reject`, `open`, `click`
- The system MUST configure a custom MAIL FROM domain (`mail.academyv2.mereka.io`) to align the envelope sender with the header sender for DMARC pass
- The exim relay pod (`smtp` deployment) MUST relay through SES SMTP endpoint `email-smtp.ap-southeast-1.amazonaws.com:587` using STARTTLS
- The exim relay pod MUST authenticate using IAM credentials stored in the `ses-smtp-credentials` K8s secret (keys: `RELAY_USERNAME`, `RELAY_PASSWORD`)
- The system MUST support per-tenant sender identities: each enterprise tenant MAY configure a custom `From` display name (e.g., "Acme Corp via Mereka Academy") while sharing the verified sending domain
- The system MUST NOT send email from unverified domains or addresses
- The system SHOULD move from the SES sandbox to production sending mode before general availability

#### ACE (Automated Communications Engine) Integration

- The system MUST configure ACE with three delivery channels: `django_email` (email), `push` (push notifications), and `in_app` (in-app notification tray)
- The ACE `django_email` channel MUST remain the default for transactional email
- The ACE `push` channel MUST deliver messages via the push notification dispatch service to FCM/APNs
- The ACE `in_app` channel MUST persist notifications to the notification store (MySQL) for retrieval by the in-app notification tray API
- The system MUST route ACE messages to channels based on the message type and the user's notification preferences: if a user has disabled email for `course_announcement` but enabled push, ACE MUST send only via push
- The system MUST define the following ACE message types, each with a unique `message_type` identifier:
  - `enrollment_confirmation` -- triggered when a learner enrolls in a course
  - `course_announcement` -- triggered when an instructor publishes an announcement
  - `assignment_reminder` -- triggered 24 hours and 1 hour before an assignment deadline
  - `grade_posted` -- triggered when a grade is published for a submission
  - `discussion_reply` -- triggered when someone replies to a followed discussion thread
  - `discussion_mention` -- triggered when a user is @mentioned in a discussion post
  - `certificate_issued` -- triggered when a course certificate is generated
  - `course_start_reminder` -- triggered 7 days and 1 day before a course start date
  - `course_completion` -- triggered when a learner completes all graded components
  - `system_maintenance` -- triggered by operations for scheduled maintenance windows
  - `password_reset` -- triggered by user-initiated password reset (email-only, no preference override)
  - `account_activation` -- triggered on new account creation (email-only, no preference override)
  - `enterprise_welcome` -- triggered when an enterprise learner is provisioned
  - `license_expiry_warning` -- triggered 30 days and 7 days before enterprise license expiry
  - `bulk_campaign` -- triggered by enterprise admin bulk messaging
- The message types `password_reset` and `account_activation` MUST NOT be suppressible by user preferences (system-critical)
- The system MUST include the `org_slug` in every ACE message context to enable per-tenant template rendering and branding
- ACE message dispatch MUST be processed by Celery workers using the `edx.lms.core.default` routing key (existing configuration)
- The system SHOULD support priority queuing: `password_reset` and `account_activation` messages SHOULD use a high-priority Celery queue to avoid being delayed by bulk sends

#### In-App Notifications

- The system MUST provide a notification store backed by MySQL that persists notifications per user
- Each notification record MUST include: `id` (UUID), `user_id`, `message_type`, `title`, `body`, `course_id` (nullable), `org_slug`, `deep_link_url` (nullable), `read` (boolean, default false), `created_at` (UTC timestamp), `expires_at` (nullable UTC timestamp)
- The system MUST expose a REST API for in-app notifications:
  - `GET /api/notifications/v1/` -- list notifications for the authenticated user, paginated (default 20, max 100), sorted by `created_at` descending, filterable by `read` status and `message_type`
  - `PATCH /api/notifications/v1/{id}/read/` -- mark a single notification as read
  - `POST /api/notifications/v1/mark-all-read/` -- mark all unread notifications as read for the authenticated user
  - `GET /api/notifications/v1/unread-count/` -- return the count of unread notifications (for badge display)
  - `DELETE /api/notifications/v1/{id}/` -- delete a single notification (user-initiated)
- The notification list endpoint MUST return notifications for the user's active `org_slug` only (no cross-tenant leakage)
- Expired notifications (`expires_at < now()`) MUST NOT appear in API responses
- The system MUST purge expired notifications older than 90 days via a scheduled Celery task (daily)
- The system SHOULD integrate with the Open edX `frontend-app-learner-dashboard` MFE to render a notification bell icon with unread count badge
- The notification tray UI MUST support real-time or near-real-time updates (polling every 60 seconds is acceptable; SSE is preferred if MFE supports it)

#### Push Notifications

- The system MUST deliver push notifications via Firebase Cloud Messaging (FCM) for both iOS and Android devices
- The system MUST maintain a device registration table in MySQL with: `id`, `user_id`, `device_token`, `platform` (ios/android), `app_version`, `org_slug`, `registered_at`, `last_seen_at`, `is_active` (boolean)
- The device registration API MUST be as specified in `specs/mobile-apps-enterprise_spec.md`:
  - `POST /api/mobile/v1/notifications/register/` -- register or update a device token
  - `DELETE /api/mobile/v1/notifications/register/` -- unregister a device token
- The system MUST deduplicate device tokens: if a token is re-registered, the existing record MUST be updated (not duplicated)
- The system MUST mark a device token as inactive (`is_active = false`) if FCM returns `UNREGISTERED` or `INVALID_ARGUMENT` error for that token
- The push notification dispatch service MUST send messages using the FCM HTTP v1 API (`https://fcm.googleapis.com/v1/projects/{project_id}/messages:send`)
- The FCM service account key MUST be stored in Infisical as `MEREKA_LMS_FCM_SERVICE_ACCOUNT_KEY`, synced to K8s via ExternalSecrets
- Each push notification payload MUST include: `type`, `title`, `body`, `course_id` (if applicable), `deep_link_url`, `org_slug`, `notification_id` (for deduplication on the client), `timestamp`
- The system MUST group push notifications by course on both iOS (using `threadId`) and Android (using notification channels)
- The system MUST respect per-user, per-type push notification preferences: if a user disables push for `discussion_reply`, no push MUST be sent for that type
- The system MUST NOT send push notifications to device tokens registered under a different `org_slug` than the notification's `org_slug`
- The system SHOULD batch push notifications to FCM in groups of up to 500 using the FCM batch send API to reduce API calls
- The system SHOULD support notification images (e.g., course thumbnail) via the FCM `image` field

#### Notification Preferences

- The system MUST provide a notification preferences service that stores per-user, per-channel, per-type preferences
- The preference data model MUST include: `user_id`, `message_type`, `channel` (email/push/in_app), `enabled` (boolean), `updated_at`, `consent_version` (string, for GDPR tracking)
- The system MUST provide a REST API for notification preferences:
  - `GET /api/notifications/v1/preferences/` -- return all preferences for the authenticated user, grouped by message type and channel
  - `PUT /api/notifications/v1/preferences/` -- bulk update preferences (accepts a list of `{message_type, channel, enabled}` objects)
  - `GET /api/notifications/v1/preferences/defaults/` -- return the system default preferences (for UI rendering)
- Default preferences for new users MUST be: all channels enabled for all message types except `bulk_campaign` (email: opt-out by default for GDPR compliance; push/in_app: enabled)
- The system MUST record a `consent_version` string with each preference change for GDPR audit trail (e.g., `"v1.0-2026-02-10"`)
- The system MUST support a one-click "unsubscribe from all marketing" link in every `bulk_campaign` email that disables email for `bulk_campaign` and `course_announcement` types without requiring login
- The one-click unsubscribe link MUST use a signed token (HMAC-SHA256 with a server secret) that expires after 90 days
- The system MUST support the `List-Unsubscribe` and `List-Unsubscribe-Post` email headers in every `bulk_campaign` email for RFC 8058 compliance (one-click unsubscribe in email clients)
- Enterprise tenant admins MUST NOT be able to override a learner's opt-out preference for marketing communications
- The system MUST log every preference change to an audit table: `user_id`, `message_type`, `channel`, `old_value`, `new_value`, `consent_version`, `ip_address_hash`, `timestamp`
- The preferences API MUST be integrated into the learner dashboard MFE under a "Notification Settings" section

#### Email Templates and Multi-Language Support

- The system MUST use ACE's template rendering system with Django templates for all email content
- Each message type MUST have templates for: `subject.txt`, `body.html`, and `body.txt` (plain-text fallback)
- Templates MUST support the following languages: `en` (English), `ms` (Malay), `zh-hans` (Simplified Chinese)
- The system MUST select the template language based on the recipient's `language_preference` stored in the Open edX user profile
- If a template for the user's preferred language does not exist, the system MUST fall back to `en` (English)
- Email templates MUST support per-tenant branding variables: `org_display_name`, `org_logo_url`, `org_primary_color`, `org_accent_color`, `org_support_email`, `org_terms_url`, `org_privacy_url`
- Email templates MUST include a standard footer with: unsubscribe link, support email, physical mailing address (for CAN-SPAM compliance), and the Mereka Academy logo
- The system MUST support dynamic content interpolation in templates: `{learner_name}`, `{course_name}`, `{instructor_name}`, `{deadline_date}`, `{grade_value}`, `{certificate_url}`, `{deep_link_url}`
- Email templates MUST be responsive (mobile-friendly) using inline CSS
- The system SHOULD provide a template preview API (`POST /api/notifications/v1/templates/preview/`) for enterprise admins to preview rendered emails with sample data before sending bulk campaigns

#### Bulk Messaging

- The system MUST support bulk email campaigns initiated by course instructors (via Studio) and enterprise tenant admins (via enterprise admin portal)
- Bulk email MUST be dispatched through ACE using the `bulk_campaign` message type
- The system MUST support recipient segmentation: by course enrollment, by organization (`org_slug`), by enrollment status (active/completed/expired), and by custom cohort
- The system MUST enforce per-tenant sending rate limits to protect SES reputation:
  - Default: 50 emails per second per tenant
  - Maximum: configurable up to the SES account sending rate limit
  - The global SES sending rate limit MUST NOT be exceeded across all tenants combined
- Bulk email campaigns MUST support scheduling: an admin MUST be able to specify a send date/time (in the tenant's timezone) up to 30 days in advance
- Scheduled campaigns MUST be cancellable before the scheduled send time
- The system MUST provide bulk campaign status tracking: `draft`, `scheduled`, `sending`, `paused`, `completed`, `failed`, `cancelled`
- The system MUST report per-campaign metrics: total recipients, sent count, delivered count, bounced count, complained count, opened count, clicked count
- The system MUST support campaign pause and resume: an admin MUST be able to pause a sending campaign and resume it later without re-sending to already-sent recipients
- The system MUST enforce the `bulk_campaign` preference: recipients who have opted out MUST NOT receive the email, and the "skipped" count MUST be reported in campaign metrics
- Bulk email content MUST pass through a profanity/content filter before sending (basic check for known spam trigger words)
- The system SHOULD support HTML email composition with a rich-text editor in the enterprise admin portal

#### Bounce and Complaint Handling

- The system MUST process SES bounce notifications delivered via SNS to an HTTPS endpoint in the LMS backend
- The system MUST maintain a suppression list (MySQL table) of email addresses that have hard-bounced or complained
- On receiving a hard bounce (`bounce.bounceType = "Permanent"`), the system MUST:
  1. Add the email address to the suppression list with reason `hard_bounce` and timestamp
  2. Mark the corresponding user's email as `undeliverable` in the user profile
  3. Log the event with `user_id`, `email_hash` (not full email), `bounce_type`, `bounce_subtype`, `diagnostic_code`
- On receiving a soft bounce (`bounce.bounceType = "Transient"`), the system MUST:
  1. Increment a soft bounce counter for the email address
  2. If the soft bounce count exceeds 3 within a 7-day window, treat it as a hard bounce and add to the suppression list
- On receiving a complaint (`complaint.complaintFeedbackType`), the system MUST:
  1. Add the email address to the suppression list with reason `complaint` and timestamp
  2. Disable the `bulk_campaign` email preference for the user
  3. Log the event with `user_id`, `email_hash`, `complaint_type`, `feedback_id`
- The system MUST NOT send email to any address on the suppression list
- The system MUST provide an admin API to view the suppression list and manually remove entries (for false positives): `GET /api/admin/v1/email/suppression-list/` and `DELETE /api/admin/v1/email/suppression-list/{email_hash}/`
- The system MUST send a daily summary report to `ops@mereka.dev` with: total sends, delivery rate, bounce rate, complaint rate, new suppressions
- The system MUST alert if the SES account bounce rate exceeds 5% or complaint rate exceeds 0.1% (SES enforcement thresholds are 10% bounce and 0.5% complaint)

#### Notification Scheduling, Batching, and Digests

- The system MUST support notification scheduling: assignment reminders MUST be sent at 24 hours and 1 hour before the deadline based on the assignment's `due_date`
- The system MUST implement a notification scheduler as a periodic Celery Beat task that runs every 15 minutes, scans for upcoming deadlines, and enqueues reminder notifications for users who have not yet submitted
- The system MUST support notification digests: users SHOULD be able to opt into a daily or weekly digest that batches non-urgent notifications (`course_announcement`, `discussion_reply`, `discussion_mention`) into a single email
- Digest frequency options MUST be: `immediate` (default), `daily` (sent at 09:00 in user's timezone), `weekly` (sent Monday 09:00 in user's timezone)
- The digest MUST group notifications by course and show a summary with links to each notification's target
- The system MUST deduplicate notifications within a digest window: if a user receives 5 `discussion_reply` notifications for the same thread within one digest period, the digest MUST show one entry with "(5 new replies)"
- The system MUST NOT send both the immediate notification and the digest for the same event: if a user is on daily digest for a message type, the immediate email MUST be suppressed (push and in-app MAY still be immediate)

#### Email Analytics and Engagement Tracking

- The system MUST track the following per-email events via SES event publishing: `send`, `delivery`, `bounce`, `complaint`, `open`, `click`, `reject`
- Open tracking MUST use a transparent 1x1 tracking pixel embedded in the email HTML body
- Click tracking MUST rewrite URLs in the email body to pass through a redirect endpoint (`https://academyv2.mereka.io/notifications/track/click/{tracking_id}/`) that logs the click and redirects to the original URL
- The system MUST store email engagement data in a time-series format suitable for analytics queries (ClickHouse if available per analytics pipeline spec, otherwise MySQL with partitioning by month)
- The system MUST provide an admin dashboard showing per-campaign and aggregate metrics: send volume, delivery rate, open rate, click-through rate, bounce rate, complaint rate, unsubscribe rate
- The system MUST support per-tenant analytics: enterprise tenant admins MUST see only their own tenant's email performance metrics
- The system MUST retain engagement data for 12 months, then archive or purge per data retention policy
- The system SHOULD provide a webhook endpoint for real-time engagement event streaming to external analytics systems (future integration point)

#### Integration with Open edX Course Events

- The system MUST subscribe to the following Open edX signals/events to trigger notifications:
  - `ENROLLMENT_CREATED` signal -- triggers `enrollment_confirmation`
  - `COURSE_GRADE_NOW_PASSED` signal -- triggers `course_completion`
  - `CERTIFICATE_CREATED` signal -- triggers `certificate_issued`
  - `FORUM_THREAD_RESPONSE_CREATED` event -- triggers `discussion_reply`
  - Instructor bulk email action in Studio -- triggers `bulk_campaign` via ACE
  - Course announcement publish action -- triggers `course_announcement`
  - Assignment due date approach (scheduler scans `due_date` fields) -- triggers `assignment_reminder`
  - Grade publish action -- triggers `grade_posted`
  - System maintenance schedule entry (admin action) -- triggers `system_maintenance`
- The system MUST use the Open edX event bus (Django signals for in-process events; Redis Streams or Kafka for cross-service events) for event propagation
- Each event handler MUST be idempotent: processing the same event twice MUST NOT result in duplicate notifications
- Event handlers MUST include the `org_slug` derived from the course's owning organization to ensure correct tenant routing

#### GDPR-Compliant Preference Management

- The system MUST record explicit consent for marketing communications (`bulk_campaign` type) per the GDPR "opt-in" requirement
- Consent MUST be version-tracked: each consent record MUST include `consent_version`, `consent_text_hash` (SHA-256 of the consent text shown to the user), `consented_at`, and `ip_address_hash`
- The system MUST support consent withdrawal: a user MUST be able to withdraw marketing consent at any time via the preferences API or the one-click unsubscribe link, effective immediately
- The system MUST include marketing consent records in the GDPR data export pipeline (per `specs/data-privacy-gdpr-compliance_spec.md`)
- The system MUST include notification preference records in the GDPR data deletion pipeline: on user deletion, all preference and consent records MUST be anonymized or deleted
- The system MUST NOT send marketing communications to users who have not explicitly opted in (consent recorded) or who have withdrawn consent
- The system MUST support per-tenant consent policies: each enterprise tenant MAY define a custom consent text that is shown to learners during preference configuration

### Non-Functional Requirements

#### Performance

- Transactional email dispatch latency (ACE message enqueue to SES `send` event) MUST be <= 30 seconds at p95
- Bulk email throughput MUST sustain >= 50 emails per second per tenant, and >= 200 emails per second globally
- In-app notification list API (`GET /api/notifications/v1/`) p95 latency MUST be <= 200ms
- In-app notification unread count API p95 latency MUST be <= 100ms
- Push notification dispatch latency (event trigger to FCM `send` call) MUST be <= 60 seconds at p95
- Notification preferences API p95 latency MUST be <= 150ms
- Digest generation for 10,000 users MUST complete within 15 minutes

#### Reliability

- Email delivery rate to valid addresses (not on suppression list) MUST be >= 99%
- Push notification delivery rate to FCM/APNs MUST be >= 98%
- In-app notification store MUST have zero data loss (backed by MySQL with replication)
- The notification scheduler (Celery Beat) MUST have exactly-once execution guarantee (using distributed locking via Redis)
- Bulk email campaigns MUST resume from the last sent recipient after a worker crash (checkpoint-based processing)

#### Security

- Email content MUST NOT include sensitive PII (passwords, full credit card numbers, SSN) in the body or subject
- The SES SNS bounce/complaint webhook endpoint MUST validate the SNS message signature to prevent spoofing
- The click-tracking redirect endpoint MUST validate the tracking ID signature to prevent open redirect attacks
- The one-click unsubscribe endpoint MUST validate the HMAC-SHA256 token to prevent unauthorized preference changes
- FCM service account credentials MUST be stored in Infisical and synced via ExternalSecrets; they MUST NOT be committed to source control
- SES SMTP credentials MUST be rotated every 90 days; rotation MUST be documented in the runbook
- Bulk email content MUST be sanitized to prevent XSS in the email body (strip `<script>`, `onclick`, etc.)
- Admin-only APIs (`/api/admin/v1/email/*`) MUST require `is_staff` or `enterprise_admin` permission

#### Availability

- The email delivery pipeline (exim relay + SES) MUST have >= 99.9% availability
- The notification preferences API MUST have >= 99.9% availability
- The in-app notification API MUST have >= 99.5% availability
- Push notification dispatch SHOULD have >= 99.5% availability (FCM is a third-party dependency)

#### Cost

- SES cost SHOULD remain below $0.10 per 1,000 emails (current SES pricing is $0.10/1k)
- FCM push notifications are free; the cost constraint is API call volume which SHOULD be minimized via batching
- Notification data storage (MySQL) SHOULD be bounded by the 90-day purge policy to prevent unbounded growth

---

## Acceptance Criteria

### Email Delivery

- [ ] AC-001: Given the sending domain `academyv2.mereka.io`, when SES domain verification is checked, then DKIM, SPF, and DMARC all pass verification (verified via `dig` and SES console)
- [ ] AC-002: Given the sending domain `academy.biji-biji.com`, when SES domain verification is checked, then DKIM, SPF, and DMARC all pass verification
- [ ] AC-003: Given a learner triggers a password reset, when ACE dispatches the email, then the email is delivered via SES within 30 seconds and the `From` header shows `noreply@academyv2.mereka.io`
- [ ] AC-004: Given the custom MAIL FROM domain `mail.academyv2.mereka.io`, when an email is sent, then the envelope sender aligns with the header sender (DMARC alignment pass)
- [ ] AC-005: Given an enterprise tenant with `org_slug=acme`, when a course announcement email is sent, then the `From` display name shows "Acme Corp via Mereka Academy" and the sender address is `noreply@academyv2.mereka.io`

### ACE Channels

- [ ] AC-006: Given ACE configuration with channels `["django_email", "push", "in_app"]`, when a `course_announcement` notification is triggered, then ACE dispatches to all three channels for users with all channels enabled
- [ ] AC-007: Given a user who has disabled email for `course_announcement` but enabled push and in_app, when a course announcement is published, then the user receives push and in-app notifications but no email
- [ ] AC-008: Given a `password_reset` message type, when the user has disabled all notification channels, then the email is still sent (system-critical, non-suppressible)
- [ ] AC-009: Given Celery workers processing the `edx.lms.core.default` queue, when 100 ACE messages are enqueued simultaneously, then all 100 are dispatched within 60 seconds

### In-App Notifications

- [ ] AC-010: Given a learner with 5 unread notifications, when they call `GET /api/notifications/v1/unread-count/`, then the response is `{"unread_count": 5}` with p95 latency <= 100ms
- [ ] AC-011: Given 50 notifications for a user (30 read, 20 unread), when they call `GET /api/notifications/v1/?read=false`, then only the 20 unread notifications are returned, sorted by `created_at` descending
- [ ] AC-012: Given a notification with `expires_at` in the past, when the notification list is queried, then the expired notification is not included in the response
- [ ] AC-013: Given a user calls `POST /api/notifications/v1/mark-all-read/`, when the operation completes, then `GET /api/notifications/v1/unread-count/` returns `{"unread_count": 0}`
- [ ] AC-014: Given a user under `org_slug=acme`, when they query the notification list, then they see only notifications with `org_slug=acme` (no cross-tenant leakage)

### Push Notifications

- [ ] AC-015: Given a device registers via `POST /api/mobile/v1/notifications/register/` with a valid FCM token, when a `grade_posted` notification is triggered, then the push notification is delivered to FCM within 60 seconds
- [ ] AC-016: Given a device token that FCM reports as `UNREGISTERED`, when a push notification fails for that token, then the device record is marked `is_active=false` and no further pushes are attempted
- [ ] AC-017: Given a user logs out and calls `DELETE /api/mobile/v1/notifications/register/`, when a notification is subsequently triggered, then no push notification is sent to the deregistered device
- [ ] AC-018: Given 1,000 push notifications queued for dispatch, when the batch sender runs, then FCM receives batches of up to 500 messages each (2 API calls, not 1,000)
- [ ] AC-019: Given a notification for `org_slug=acme`, when dispatch occurs, then only devices with `org_slug=acme` receive the push (no cross-tenant delivery)

### Notification Preferences

- [ ] AC-020: Given a new user with no preference records, when they call `GET /api/notifications/v1/preferences/`, then default preferences are returned (all enabled except `bulk_campaign` email which is disabled)
- [ ] AC-021: Given a user updates preferences via `PUT /api/notifications/v1/preferences/` with `[{"message_type": "discussion_reply", "channel": "email", "enabled": false}]`, when a discussion reply notification is triggered, then no email is sent but push and in-app are sent
- [ ] AC-022: Given a user clicks a one-click unsubscribe link in a `bulk_campaign` email, when the signed token is valid and not expired, then `bulk_campaign` and `course_announcement` email preferences are set to disabled without requiring login
- [ ] AC-023: Given a preference change, when the audit log is queried, then it contains the `user_id`, `old_value`, `new_value`, `consent_version`, `ip_address_hash`, and `timestamp`
- [ ] AC-024: Given a `bulk_campaign` email, when the email headers are inspected, then `List-Unsubscribe` and `List-Unsubscribe-Post` headers are present with a valid one-click unsubscribe URL

### Multi-Language Templates

- [ ] AC-025: Given a user with `language_preference=ms`, when an `enrollment_confirmation` email is sent, then the subject and body are rendered in Malay
- [ ] AC-026: Given a user with `language_preference=zh-hans`, when a `grade_posted` email is sent, then the subject and body are rendered in Simplified Chinese
- [ ] AC-027: Given a user with `language_preference=ja` (unsupported), when an email is sent, then the template falls back to English (`en`)
- [ ] AC-028: Given a tenant `org_slug=acme` with `org_display_name="Acme Corp"`, when an email template renders, then the branding variables show "Acme Corp" as the organization name and the tenant's logo URL

### Bulk Messaging

- [ ] AC-029: Given an enterprise admin schedules a bulk campaign for 10,000 recipients at 2026-02-15 09:00 UTC, when the scheduled time arrives, then the campaign begins sending and completes within 30 minutes
- [ ] AC-030: Given a bulk campaign in `sending` status, when the admin clicks "Pause", then sending stops and the campaign status changes to `paused`; when resumed, sending continues from the next unsent recipient
- [ ] AC-031: Given a bulk campaign to 10,000 recipients where 500 have opted out of `bulk_campaign` email, when the campaign completes, then 9,500 emails are sent and the campaign metrics report 500 skipped
- [ ] AC-032: Given two tenants sending bulk campaigns simultaneously, when both campaigns are active, then neither tenant exceeds 50 emails per second and the combined rate does not exceed the SES account limit

### Bounce and Complaint Handling

- [ ] AC-033: Given SES reports a hard bounce for `user@example.com`, when the bounce webhook processes the event, then `user@example.com` is added to the suppression list and subsequent sends to that address are blocked
- [ ] AC-034: Given an email address with 3 soft bounces within 7 days, when the third soft bounce is processed, then the address is added to the suppression list as a hard bounce
- [ ] AC-035: Given SES reports a complaint for a `bulk_campaign` email, when the complaint webhook processes the event, then the user's `bulk_campaign` email preference is disabled and the address is added to the suppression list
- [ ] AC-036: Given the SES account bounce rate is 6% (above 5% threshold), when the alert fires, then the ops team receives a critical alert via the configured notification channel

### Digests

- [ ] AC-037: Given a user with digest preference set to `daily` for `discussion_reply`, when they receive 10 discussion replies throughout the day, then at 09:00 in their timezone they receive one digest email summarizing all 10 replies grouped by course
- [ ] AC-038: Given a user on daily digest for `course_announcement`, when a course announcement is published, then no immediate email is sent (push and in-app may still be immediate), and the announcement appears in the next digest
- [ ] AC-039: Given 5 replies to the same discussion thread within one digest period, when the digest renders, then one entry shows the thread title with "(5 new replies)" instead of 5 separate entries

### Engagement Analytics

- [ ] AC-040: Given a `bulk_campaign` email is sent with open tracking enabled, when the recipient opens the email, then an `open` event is recorded in the engagement store with `campaign_id`, `user_id`, `timestamp`
- [ ] AC-041: Given a `bulk_campaign` email contains a tracked URL, when the recipient clicks it, then a `click` event is recorded and the user is redirected to the original URL within 200ms
- [ ] AC-042: Given an enterprise admin views the campaign analytics dashboard for tenant `acme`, when they query campaign metrics, then they see only `acme` campaign data (no cross-tenant analytics leakage)

### GDPR Compliance

- [ ] AC-043: Given a user has not explicitly opted into marketing communications, when a `bulk_campaign` is sent, then the user does NOT receive the email
- [ ] AC-044: Given a user exercises their right to data export, when the export is generated, then notification preferences and consent records are included in the export archive
- [ ] AC-045: Given a user exercises their right to deletion, when the deletion pipeline runs, then all notification records, preference records, consent records, and device registrations for that user are deleted or anonymized

---

## Edge Cases

### Email Delivery Edge Cases

- **SES sending limit exceeded**: If the SES account sending rate limit is reached, the exim relay MUST queue messages locally and retry with exponential backoff (base: 5s, max: 300s). The system MUST alert if the local queue depth exceeds 1,000 messages.
- **SES region outage**: If the `ap-southeast-1` SES endpoint is unreachable for more than 5 minutes, the system SHOULD fail open (queue messages) rather than drop them. There is no automatic failover to another SES region (listed as non-goal for v1).
- **Invalid sender address**: If a per-tenant sender identity configuration references an unverified address, the system MUST fall back to the default verified sender (`noreply@academyv2.mereka.io`) and log a warning.
- **Email body exceeds SES size limit**: SES has a 10 MB message size limit. If a bulk campaign email with inline images exceeds this, the system MUST reject the campaign with a clear error message before sending begins.

### Bounce Handling Edge Cases

- **Suppression list false positive**: If an admin removes an address from the suppression list, the system MUST allow sending to that address again. The removal MUST be logged in the audit trail with the admin's user ID.
- **Bounce storm from migration data**: Kajabi-migrated email addresses may have high bounce rates. Before any bulk campaign to migrated users, the system SHOULD perform a list hygiene check (verify addresses against the suppression list and optionally against SES's account-level suppression list).
- **SES account suspension**: If SES suspends the account due to bounce/complaint rate violations, the system MUST detect the `ACCOUNT_SENDING_PAUSED` status and alert the ops team immediately. All email sending MUST be paused, and a recovery plan MUST be in the runbook.

### Push Notification Edge Cases

- **FCM quota exceeded**: FCM has a per-project message limit (currently ~240,000 messages/minute for the HTTP v1 API). If the limit is approached, the system MUST queue excess messages and retry with backoff.
- **APNs token refresh**: iOS device tokens can change when the OS updates or the app is reinstalled. The system MUST handle token updates via the registration endpoint and deduplicate to prevent orphaned registrations.
- **Silent notification throttling**: iOS throttles silent/background push notifications. The system MUST NOT use silent push for any user-facing notification; all notifications MUST include an alert payload.
- **FCM service account key rotation**: When the FCM key is rotated in Infisical, the K8s ExternalSecret syncs within 1 hour. During the rotation window, the old key MUST remain valid. The rotation procedure MUST be documented in the runbook.

### Notification Preferences Edge Cases

- **Preference race condition**: If a user updates preferences in two browser tabs simultaneously, the system MUST use last-write-wins semantics with `updated_at` timestamp comparison.
- **Consent version migration**: When the consent text changes (new privacy policy version), the system MUST re-prompt users to accept the updated consent before sending marketing emails under the new version. Users who have not re-consented MUST NOT receive marketing emails.
- **Unsubscribe link token expiry**: If a user clicks an unsubscribe link with an expired token (> 90 days), the system MUST redirect to the preferences page in the MFE and require login for manual preference management.

### In-App Notification Edge Cases

- **Notification flood**: If a forum thread generates 100 replies in 1 minute, the system MUST batch these into a single in-app notification ("100 new replies in thread X") rather than creating 100 individual notifications. The batching window MUST be configurable (default: 5 minutes).
- **Database purge during read**: If the purge job deletes a notification that the user is currently viewing, the API MUST handle the 404 gracefully and not crash.
- **User with 10,000+ notifications**: The notification list API MUST use cursor-based pagination (not offset-based) to maintain consistent performance regardless of total notification count.

### Digest Edge Cases

- **Timezone ambiguity**: If a user's timezone is not set, the digest MUST default to `Asia/Kuala_Lumpur` (UTC+8, Malaysia Standard Time).
- **Daylight saving transitions**: For users in DST-observant timezones, the digest MUST use the correct local time even during spring-forward/fall-back transitions.
- **Empty digest**: If a user is subscribed to daily digest but has no notifications in the period, the system MUST NOT send an empty digest email.

### Retry and Idempotency

- **Celery task retry**: All notification dispatch tasks MUST be idempotent. Retrying a task MUST NOT result in duplicate emails, push notifications, or in-app notifications. Idempotency MUST be enforced using a unique `notification_id` as a deduplication key with a 24-hour TTL in Redis.
- **SES SNS webhook retry**: AWS SNS retries webhook delivery on failure. The bounce/complaint processing endpoint MUST be idempotent using the SNS `MessageId` as a deduplication key.
- **Rate limiting on preference API**: The preferences API MUST enforce rate limiting of 10 requests per minute per user to prevent abuse.

---

## Observability

### Logs

- **Email dispatch**: Every email sent MUST log: `notification_id`, `message_type`, `user_id`, `org_slug`, `recipient_email_hash` (SHA-256, not plaintext), `ses_message_id`, `channel`, `template_language`, `timestamp`
- **Push dispatch**: Every push notification sent MUST log: `notification_id`, `message_type`, `user_id`, `org_slug`, `platform`, `device_token_hash`, `fcm_message_id`, `timestamp`
- **In-app notification created**: Every in-app notification MUST log: `notification_id`, `message_type`, `user_id`, `org_slug`, `timestamp`
- **Bounce/complaint processing**: Every bounce/complaint event MUST log: `ses_message_id`, `bounce_type`/`complaint_type`, `email_hash`, `user_id` (if resolvable), `org_slug`, `timestamp`
- **Preference changes**: Every preference update MUST log: `user_id`, `message_type`, `channel`, `old_value`, `new_value`, `consent_version`, `source` (api/unsubscribe_link/admin), `timestamp`
- **Bulk campaign lifecycle**: Campaign events MUST log: `campaign_id`, `org_slug`, `status_change` (from -> to), `total_recipients`, `sent_count`, `admin_user_id`, `timestamp`
- All logs MUST be structured JSON format and shipped to Loki via Promtail (per `specs/observability-stack_spec.md`)
- Logs MUST NOT contain plaintext email addresses, device tokens, or PII -- use hashed values only

### Metrics (Prometheus)

- `notification_emails_sent_total` (labels: `message_type`, `org_slug`, `template_language`, `outcome`) -- counter
- `notification_emails_delivery_latency_seconds` (labels: `message_type`) -- histogram
- `notification_emails_bounced_total` (labels: `bounce_type`, `org_slug`) -- counter
- `notification_emails_complained_total` (labels: `org_slug`) -- counter
- `notification_push_sent_total` (labels: `message_type`, `org_slug`, `platform`, `outcome`) -- counter
- `notification_push_dispatch_latency_seconds` (labels: `message_type`, `platform`) -- histogram
- `notification_inapp_created_total` (labels: `message_type`, `org_slug`) -- counter
- `notification_inapp_read_total` (labels: `message_type`, `org_slug`) -- counter
- `notification_preferences_changes_total` (labels: `message_type`, `channel`, `action`) -- counter (action: enable/disable)
- `notification_suppression_list_size` (labels: `reason`) -- gauge
- `notification_bulk_campaign_status` (labels: `org_slug`, `status`) -- gauge
- `notification_bulk_campaign_send_rate` (labels: `org_slug`) -- gauge (emails per second)
- `notification_digest_generated_total` (labels: `frequency`, `org_slug`) -- counter
- `notification_celery_queue_depth` (labels: `queue_name`) -- gauge
- `notification_ses_sending_quota_remaining` -- gauge
- `notification_device_registrations_active` (labels: `platform`, `org_slug`) -- gauge

### Alerts

- **Critical**: SES account bounce rate exceeds 5% over 1 hour -- page oncall (SES account suspension threshold is 10%)
- **Critical**: SES account complaint rate exceeds 0.1% over 1 hour -- page oncall (SES suspension threshold is 0.5%)
- **Critical**: `notification_celery_queue_depth` exceeds 10,000 for any queue for 15 minutes -- page oncall (backpressure indicates worker failure)
- **Critical**: `notification_ses_sending_quota_remaining` drops below 10% -- page oncall
- **Warning**: Email delivery latency p95 exceeds 60 seconds over 10 minutes -- notify channel
- **Warning**: Push notification dispatch failure rate exceeds 5% over 15 minutes -- notify channel
- **Warning**: SES SMTP credential expiry within 30 days -- notify channel weekly
- **Warning**: FCM service account key last rotation exceeds 90 days -- notify channel weekly
- **Warning**: Suppression list grows by more than 100 addresses in 24 hours -- notify channel (possible list hygiene issue)
- **Info**: Daily email volume exceeds 50,000 -- notify channel (cost tracking)
- **Info**: Bulk campaign completion for any tenant -- notify channel with campaign metrics summary

### Dashboards

- **Email Overview**: daily/weekly send volume, delivery rate trend, bounce rate trend, complaint rate trend, SES quota utilization
- **Push Notifications**: send volume by platform, delivery rate, failure breakdown by error code, active device registrations
- **In-App Notifications**: creation rate, read rate, average time-to-read, notification tray API latency percentiles
- **Notification Preferences**: opt-in/opt-out rates by message type and channel, one-click unsubscribe usage
- **Bulk Campaigns**: campaigns per tenant, average completion time, recipient volume, engagement metrics (open/click rates)
- **Bounce & Reputation**: bounce rate by type (hard/soft), complaint rate, suppression list size trend, domain reputation indicators
- **Per-Tenant View**: send volume, delivery rate, bounce rate, complaint rate, active devices, preference distribution -- filterable by `org_slug`
- **Digest Analytics**: digest generation time, digest email volume, digest open rates vs. immediate email open rates

---

## Rollout & Rollback

### Rollout Plan

#### Phase 1: Email Infrastructure Hardening (Week 1-2)
1. Verify `academyv2.mereka.io` and `academy.biji-biji.com` domains with SES (DKIM, SPF, DMARC)
2. Configure custom MAIL FROM domain `mail.academyv2.mereka.io`
3. Set up SES configuration set `mereka-academy-production` with SNS event publishing
4. Deploy SNS bounce/complaint webhook endpoint in LMS
5. Create suppression list table and bounce/complaint processing logic
6. Set up email delivery monitoring dashboard and alerts
7. Move SES account out of sandbox (if still in sandbox)

#### Phase 2: Notification Preferences Service (Week 3-4)
1. Create notification preferences data model and migration
2. Build preferences REST API with GDPR consent tracking
3. Build one-click unsubscribe endpoint with HMAC token validation
4. Add `List-Unsubscribe` / `List-Unsubscribe-Post` headers to ACE email templates
5. Integrate preferences into learner dashboard MFE
6. Enable preferences enforcement in ACE message dispatch

#### Phase 3: In-App Notifications (Week 5-6)
1. Create notification store data model and migration
2. Build in-app notification REST API
3. Implement notification creation handlers for all message types
4. Build notification bell icon and tray component in learner dashboard MFE
5. Implement notification purge Celery task
6. Deploy and validate with internal users

#### Phase 4: Push Notifications (Week 7-8)
1. Configure ACE `push` channel
2. Build push notification dispatch service using FCM HTTP v1 API
3. Store FCM service account key in Infisical and configure ExternalSecret
4. Implement device token lifecycle management (coordinates with mobile app team)
5. Implement batch sending (groups of 500)
6. Deploy behind `notification_push_enabled` feature flag
7. Validate with iOS TestFlight users first, then enable globally

#### Phase 5: Multi-Language Templates and Bulk Messaging (Week 9-12)
1. Create EN/MS/ZH-Hans templates for all message types
2. Implement per-tenant branding variable injection in templates
3. Build bulk campaign engine with scheduling, pause/resume, and segmentation
4. Implement per-tenant rate limiting for bulk sends
5. Build campaign analytics reporting
6. Deploy behind `notification_bulk_campaigns_enabled` feature flag
7. Pilot with 2 enterprise tenants

#### Phase 6: Digests and Analytics (Week 13-16)
1. Implement digest generation Celery task
2. Build digest templates (daily and weekly variants)
3. Implement click tracking redirect endpoint
4. Set up engagement data storage (ClickHouse or partitioned MySQL)
5. Build admin analytics dashboard
6. Deploy digests behind `notification_digests_enabled` feature flag

### Feature Flags

- `notification_push_enabled` -- gate push notification dispatch globally (default: off)
- `notification_inapp_enabled` -- gate in-app notification creation (default: off)
- `notification_preferences_enabled` -- gate preferences UI and enforcement (default: off)
- `notification_bulk_campaigns_enabled` -- gate bulk campaign features per org_slug (default: off)
- `notification_digests_enabled` -- gate digest generation per org_slug (default: off)
- `notification_click_tracking_enabled` -- gate URL rewriting for click tracking (default: off)
- `notification_multilang_enabled` -- gate multi-language template selection (default: off, falls back to EN)

### Backward Compatibility

- The existing ACE `django_email` channel MUST continue to work unchanged during rollout -- no breaking changes to existing email delivery
- The existing `BULK_EMAIL_SEND_USING_EDX_ACE = True` configuration MUST remain functional; the new bulk campaign engine is additive
- New notification APIs (`/api/notifications/v1/*`) are additive and do not modify existing API endpoints
- The suppression list MUST NOT block `password_reset` or `account_activation` emails even if the address is on the list (system-critical messages bypass suppression)
- Feature flags MUST be off by default so deployment does not change behavior until explicitly enabled
- The notification preferences table MUST have a migration that backfills default preferences for existing users on first API access (lazy migration), not a bulk migration that locks the users table

### Rollback Steps

#### Email Infrastructure Rollback
1. If SES domain verification breaks email delivery, revert DNS records to previous state; exim relay will continue queueing until SES connectivity is restored
2. If bounce webhook processing causes issues, disable the SNS subscription in the AWS console (immediate effect, no deployment needed)
3. If suppression list incorrectly blocks valid addresses, truncate the suppression list table and disable bounce processing temporarily

#### Notification Preferences Rollback
1. Disable `notification_preferences_enabled` feature flag (preferences API returns defaults for all users; ACE dispatches to all channels)
2. No database rollback needed; preference records are harmless when the feature flag is off

#### In-App Notifications Rollback
1. Disable `notification_inapp_enabled` feature flag (notification creation handlers skip in-app channel; API returns empty lists)
2. If the notification table causes database performance issues, the purge job can be run immediately with a 0-day retention override

#### Push Notifications Rollback
1. Disable `notification_push_enabled` feature flag (push dispatch service stops sending; messages are silently dropped)
2. If FCM credentials are compromised, revoke the service account key in Google Cloud Console and rotate in Infisical
3. Stale device tokens expire naturally; no manual cleanup needed

#### Bulk Campaign Rollback
1. Disable `notification_bulk_campaigns_enabled` feature flag (campaign creation UI is hidden; any in-progress campaigns are paused)
2. If a campaign sends incorrect content, pause the campaign immediately (campaign status -> `paused`) and issue a correction email

#### Full Rollback (Nuclear Option)
1. Revert ACE configuration to `ACE_ENABLED_CHANNELS = ["django_email"]` only
2. Disable all notification feature flags
3. The system returns to the pre-spec state: email-only via ACE `django_email` channel, no push, no in-app, no preferences

---

## Open Questions

1. **SES account status**: Is the AWS SES account for `email-smtp.ap-southeast-1.amazonaws.com` currently in sandbox mode or production mode? Sandbox mode limits sending to verified addresses only and caps at 200 messages/day. If in sandbox, production access must be requested before bulk email can be enabled.

2. **Firebase project readiness**: The `specs/mobile-apps-enterprise_spec.md` assumes a Firebase project `mereka-academy` exists. Has the Firebase project been created? Is the FCM API enabled? Is there a service account key generated? This is a prerequisite for push notification dispatch.

3. **SES sending limits**: What is the current SES sending rate limit and daily sending quota for the account? This determines the global rate ceiling for bulk email. Default production SES accounts start at 50,000 messages/day and 14 emails/second; higher limits require a request.

4. **Multi-language content authoring**: Who will author the Malay (MS) and Chinese (ZH-Hans) email templates? Is there a translation vendor or internal resource? The spec mandates three languages but does not cover the translation workflow.

5. **ClickHouse availability**: The analytics pipeline spec (`specs/analytics-pipeline_spec.md`) references ClickHouse for event data. Is ClickHouse deployed and available for notification engagement data, or should engagement data be stored in partitioned MySQL tables as a fallback?

6. **Push notification provider preference**: The spec aligns with `specs/mobile-apps-enterprise_spec.md` in using FCM for both platforms. Should the backend also integrate directly with APNs for iOS (bypassing FCM) for lower latency and higher reliability, or is FCM-only acceptable for v1?

7. **Existing email list hygiene**: How many of the Kajabi-migrated and MCT-migrated user accounts have valid email addresses? A bulk email to unverified addresses could damage SES reputation. Should a one-time email verification campaign be run before enabling bulk messaging?

8. **Digest timezone data**: Does the Open edX user profile store timezone information? If not, the digest scheduler cannot determine "09:00 in user's timezone" and must fall back to `Asia/Kuala_Lumpur`. Timezone storage may need a user profile extension.

9. **Enterprise admin portal for bulk campaigns**: Does the enterprise admin portal MFE (`frontend-app-admin-portal`) already include a bulk email composition interface, or does this need to be built? The scope states enterprise admins initiate campaigns "via enterprise admin portal" but the portal may not have this feature.

10. **Budget for SES and SNS**: What is the monthly budget allocation for email infrastructure? SES charges $0.10/1k emails, SNS charges per notification. For 100k emails/month with tracking, the estimated cost is approximately $10-15/month for SES + $1-2/month for SNS, but this should be confirmed.

11. **Email provider commitment**: This spec assumes AWS SES as the email provider (already configured via exim relay). Is this a firm commitment, or should the architecture support swapping to SendGrid/Mailgun/Postmark in the future? If SES is confirmed, the exim relay approach is appropriate. If provider flexibility is needed, ACE's pluggable channel architecture should be leveraged to abstract the provider. **Current status: AWS SES is operational but this decision has not been formally ratified.**
