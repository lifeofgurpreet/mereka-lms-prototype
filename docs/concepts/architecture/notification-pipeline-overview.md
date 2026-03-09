# Email & Notifications Pipeline Architecture Overview
_Audience: Engineering + Architecture • Last updated: 2026-02-10_

## System Overview

The notification pipeline unifies all learner, instructor, and enterprise communications across four delivery channels: transactional email (AWS SES), bulk email (AWS SES with throttling), in-app notifications (notification tray), and push notifications (Firebase Cloud Messaging). Built on Open edX's Automated Communications Engine (ACE), the system extends with notification preferences, multi-language templates, and comprehensive delivery analytics.

**Key differentiator**: Multi-channel orchestration with per-user, per-channel preferences and GDPR-compliant consent management.

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Notification Sources                         │
│  - LMS events (grade posted, deadline reminder)                 │
│  - Instructor-initiated (course announcements)                  │
│  - System-triggered (password reset, enrollment confirmation)   │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
         ┌──────────────────────────────┐
         │   ACE (Automated Comms Eng)  │
         │   (Open edX package)         │
         │   - Message type registry    │
         │   - Channel routing          │
         │   - Template rendering       │
         └──────────┬───────────────────┘
                    │
       ┌────────────┼────────────┬────────────┐
       ▼            ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│  Email   │ │  Push    │ │  In-App  │ │  SMS     │
│ Channel  │ │ Channel  │ │ Channel  │ │ (Future) │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └──────────┘
     │            │            │
     ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│   Exim   │ │   FCM    │ │  Redis   │
│  Relay   │ │  (APNs)  │ │  PubSub  │
│   Pod    │ │          │ │          │
└────┬─────┘ └────┬─────┘ └────┬─────┘
     │            │            │
     ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ AWS SES  │ │  Mobile  │ │  MFE     │
│          │ │  Devices │ │  (Tray)  │
└──────────┘ └──────────┘ └──────────┘

Supporting Services:
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ Preferences API  │ │ Template Manager │ │ Analytics Logger │
│ - Per-user prefs │ │ - EN/MS/ZH/VN/PH │ │ - Delivery stats │
│ - Channel opt-in │ │ - Jinja2 + i18n  │ │ - Open/click     │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

---

## Data Flow

### Transactional Email Flow (e.g., Password Reset)
1. **LMS** triggers password reset request
2. **ACE** creates message: `PasswordResetMessage`
3. **ACE** checks user preferences: is email channel enabled?
4. **ACE** renders template (`password_reset_email.html`) with user's language (EN/MS/ZH)
5. **ACE** routes to `django_email` channel
6. **Django Email** backend forwards to Exim relay pod
7. **Exim** relays to AWS SES via SMTP
8. **SES** delivers email to recipient's inbox
9. **SES** sends webhook: delivery/bounce/complaint → logged to Prometheus

### Bulk Email Flow (e.g., Course Announcement to 1000 Students)
1. **Instructor** creates announcement in Studio
2. **Bulk Email** task spawns Celery workers
3. **ACE** creates 1000 `CourseAnnouncementMessage` instances
4. **ACE** checks each user's preferences: email channel enabled?
5. **ACE** rate-limits sending: 100 emails/minute per tenant (Stripe SES limits)
6. **ACE** renders templates with per-user language preference
7. **Django Email** batches messages (100 per batch)
8. **Exim** relays batches to SES
9. **SES** throttles sending to stay under reputation limits
10. **Delivery analytics** track open/click rates (if tracking pixels enabled)

### Push Notification Flow (e.g., Assignment Due Reminder)
1. **LMS** triggers due date reminder (Celery beat cron)
2. **ACE** creates message: `AssignmentDueReminderMessage`
3. **ACE** checks user preferences: push channel enabled?
4. **ACE** queries device tokens from `PushNotificationDevice` model
5. **ACE** routes to `push` channel (custom FCM backend)
6. **FCM Backend** calls Firebase Cloud Messaging API with payload:
   ```json
   {
     "notification": {
       "title": "Assignment Due Tomorrow",
       "body": "Complete 'Intro to Python' by 2024-12-31"
     },
     "data": {
       "course_id": "course-v1:...",
       "action": "deep_link_to_assignment"
     }
   }
   ```
7. **FCM** delivers to iOS (APNs) and Android devices
8. **Mobile app** displays notification, handles deep link

### In-App Notification Flow
1. **LMS** emits event: `GRADE_POSTED`
2. **ACE** creates message: `GradePostedMessage`
3. **ACE** checks user preferences: in-app channel enabled?
4. **ACE** writes notification to `Notification` model (PostgreSQL)
5. **Redis PubSub** broadcasts to connected MFE clients: `user:{user_id}:notifications`
6. **MFE** receives WebSocket message, updates notification tray UI
7. **User** clicks notification in tray
8. **MFE** marks notification as read via API: `PATCH /api/notifications/{id}`

---

## Integration Points

### AWS SES
- **Region**: `us-east-1` (verified sender domain: `academyv2.mereka.io`)
- **Authentication**: SMTP credentials (stored in Infisical)
- **Limits**: 50,000 emails/day (quota request if needed)
- **Webhooks**: SNS → HTTP endpoint for bounce/complaint handling

### Exim Relay Pod
- **Image**: `devture/exim-relay:4.96-r1-0`
- **Config**: SMTP relay to SES, no local delivery
- **Deployment**: K8s Deployment in `mereka-lms` namespace
- **Monitoring**: Prometheus metrics on port 9636

### Firebase Cloud Messaging (FCM)
- **Service Account**: Stored in Infisical → ExternalSecret
- **API**: `https://fcm.googleapis.com/v1/projects/{project-id}/messages:send`
- **Device Token Registration**: `POST /api/mobile/v1/devices/`
- **APNs**: FCM forwards iOS notifications to APNs (transparent)

### ACE (Automated Communications Engine)
- **Package**: `edx-ace` (Open edX standard)
- **Configuration**: `settings.ACE_CHANNEL_DEFAULT_EMAIL = 'django_email'`
- **Message Types**: Registered in `lms.envs.common.ACE_ENABLED_POLICIES`
- **Custom Channels**: `push` (FCM), `in_app` (Redis PubSub)

---

## Key Design Decisions

### 1. Email Backend: Direct SES vs. Exim Relay
**Decision**: Exim relay pod to SES

**Rationale**:
- **Retry logic**: Exim handles transient failures, retries with exponential backoff.
- **Observability**: Exim logs provide SMTP-level debugging (vs. Django-only logs).
- **Legacy compatibility**: Existing Tutor deployments use Exim pattern.

**Trade-offs**:
- Additional pod to manage (resource overhead: 256MB RAM).
- One more failure point (Exim pod can crash).

### 2. Bulk Email: Celery vs. AWS SES Campaigns
**Decision**: Celery workers with ACE rate limiting

**Rationale**:
- **Control**: Full control over rate limiting, retry logic, and per-tenant throttling.
- **Cost**: SES API calls are free (vs. SES Marketing campaigns with per-send fees).
- **Integration**: Celery is already part of Open edX stack.

**Trade-offs**:
- Requires Redis for Celery task queue.
- Horizontal scaling requires more worker pods (vs. SES Campaign auto-scaling).

### 3. Push Notifications: FCM vs. SNS Mobile Push
**Decision**: Firebase Cloud Messaging (FCM)

**Rationale**:
- **Cross-platform**: FCM supports iOS (APNs) and Android (FCM native) via single API.
- **Features**: Rich notifications, data payloads, topics, device groups.
- **Pricing**: Free for 10M+ messages/month (vs. SNS $0.50 per million).

**Trade-offs**:
- Vendor lock-in to Google Firebase.
- Requires Firebase project setup and service account management.

### 4. In-App Notifications: WebSocket vs. Polling
**Decision**: Redis PubSub with WebSocket (via Django Channels)

**Rationale**:
- **Real-time**: Notifications appear instantly (vs. 30-60s polling latency).
- **Efficiency**: WebSocket connection is persistent (vs. repeated polling overhead).
- **Scalability**: Redis PubSub handles 10k+ concurrent connections.

**Trade-offs**:
- Requires Django Channels (async Django, additional complexity).
- WebSocket connections consume server memory (1-5KB per connection).

### 5. Multi-Language Templates: Compile-Time vs. Runtime
**Decision**: Runtime template selection based on user's language preference

**Rationale**:
- **Flexibility**: New languages can be added without redeploying.
- **Accuracy**: User's language preference is authoritative (vs. browser Accept-Language).
- **Fallback**: Falls back to English if translation missing.

**Trade-offs**:
- Template rendering is slightly slower (template selection overhead).
- Requires maintaining translations for all notification types.

---

## Notification Preferences Model

### Database Schema
```python
class NotificationPreference(models.Model):
    user = ForeignKey(User)
    notification_type = CharField(choices=NOTIFICATION_TYPES)  # e.g., 'assignment_due', 'grade_posted'
    email_enabled = BooleanField(default=True)
    push_enabled = BooleanField(default=True)
    in_app_enabled = BooleanField(default=True)
    sms_enabled = BooleanField(default=False)  # future
    frequency = CharField(choices=['immediate', 'daily_digest', 'weekly_digest'])
```

### Preference Enforcement
1. **ACE Message Send**: Before routing to channel, check `NotificationPreference`
2. **If disabled**: Skip channel, log opt-out
3. **If digest mode**: Queue message for batching (send daily/weekly summary)

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Transactional email delivery | p95 <30s |
| Bulk email campaign (10k recipients) | <30 minutes |
| Push notification delivery | p95 <60s |
| In-app notification latency | p95 <2s |
| SES bounce rate | <2% |
| SES complaint rate | <0.1% |
| Webhook processing | p95 <500ms |

---

## Related Specs and ADRs
- **Spec**: `specs/email-notifications-pipeline_spec.md`
- **Runbook**: `docs/archive/superseded/runbooks/email-notifications-runbook.md`
- **Operations**: `docs/ops/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md`
- **Multi-Tenancy**: `specs/multi-tenancy-architecture_spec.md`
- **Mobile Apps**: `specs/proposals/mobile-apps-enterprise_spec.md`
- **GDPR Compliance**: `specs/data-privacy-gdpr-compliance_spec.md`
