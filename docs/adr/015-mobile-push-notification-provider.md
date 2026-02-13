# ADR-015: Mobile Push Notification Provider Selection

**Status**: Accepted
**Date**: 2026-02-13
**Deciders**: Platform Team
**Related**: [Mobile Apps Secrets Management Spec](../../specs/mobile-apps-secrets-management_spec.md)

<!-- Last verified: 2026-02-13 -->

---

## Context

Open edX mobile apps (Android/iOS) require push notifications to alert learners about new assignments, course updates, announcements, and discussion replies. Push notification delivery requires a provider to route messages from the Open edX backend to learners' devices.

### Open edX ACE Architecture

Open edX uses **ACE (Automated Communication Engine)** with a pluggable `ACE_PUSH_CHANNELS` setting. This means we are **NOT locked to any specific provider** - the system is provider-agnostic and can be switched without code changes to core Open edX.

**Supported Providers**:
- Firebase Cloud Messaging (FCM) - Google-managed, free tier
- Braze - Enterprise solution (used by 2U)
- Custom/self-hosted - Requires writing ACE push channel plugin

**Sources**: [Open edX Mobile Setup](https://docs.openedx.org/en/latest/site_ops/install_configure_run_guide/mobile.html), [ACE Documentation](https://openedx.atlassian.net/wiki/spaces/COMM/pages/4982079504/Push+Notifications+in+Mobile+Apps)

---

## Decision

**Use Firebase Cloud Messaging (FCM) as the initial push notification provider**, with the understanding that we can migrate to self-hosted infrastructure in the future if needed.

---

## Rationale

### Why Firebase (for now)

1. **Zero infrastructure management** - Google handles reliability, scaling, delivery
2. **Free tier is generous** - Unlimited messages for our expected scale (<100K notifications/month)
3. **Works out-of-box** - Open edX ACE already has FCM channel support built-in
4. **Fast time-to-value** - Configure `ACE_PUSH_CHANNELS`, add credentials, done
5. **Battle-tested** - Used by millions of mobile apps globally
6. **Low operational overhead** - No servers to manage, monitor, or scale

### Why NOT Braze

- **Expensive** - Thousands/month, overkill for our scale
- **Complex** - Enterprise features we don't need yet
- **Vendor lock-in** - Harder to migrate away than FCM

### Why NOT Self-Hosted (Yet)

**Mereka has capability** to run self-hosted push notification infrastructure on our VPS:
- Already running observability stack (Prometheus, Grafana)
- Experienced with self-hosted services
- VPS infrastructure in place

**BUT** self-hosted push notifications require:
1. **Custom ACE plugin** - 2-3 days development effort
2. **Infrastructure management** - Monitoring, scaling, uptime SLA
3. **Mobile app client changes** - APNs/FCM client library → custom client
4. **Operational overhead** - One more critical service to maintain

**Trade-off**: FCM gives us 80% of the value with 20% of the effort. Start pragmatic, optimize later if needed.

---

## Consequences

### Positive

- ✅ **Fast to implement** - FCM integration is configuration, not development
- ✅ **Reliable delivery** - Google's global infrastructure handles routing
- ✅ **Low cost** - Free tier covers our needs for foreseeable future
- ✅ **Can switch later** - ACE plugin architecture means provider is swappable

### Negative

- ❌ **Google dependency** - Adds another Google service (already use GCP for hosting)
- ❌ **Data sovereignty** - Push notification metadata goes through Google
- ❌ **Privacy considerations** - Google sees notification patterns (though not content)

### Mitigation

- **Future migration path documented** below
- **Secrets stored in Infisical** - FCM credentials treated like any other secret
- **Monitoring** - Track notification delivery rates via FCM console + Open edX logs

---

## Future Migration Path

**When to consider self-hosted**:
- Data sovereignty requirements emerge (GDPR strict interpretation)
- Notification volume exceeds free tier (unlikely: free tier is unlimited messages)
- Want to eliminate ALL Google dependencies
- VPS infrastructure already handles many services efficiently

**Self-Hosted Options** (in order of recommendation):

### 1. Gotify ⭐ Recommended
- **Type**: Self-hosted push notification server
- **Tech**: Go-based, Docker support, REST API
- **Clients**: Android/iOS native clients available
- **Effort**: 2-3 days (custom ACE plugin + server setup)
- **Cost**: VPS resources only (~$10-20/month if dedicated)
- **Sources**: [Gotify](https://github.com/gotify/server)

### 2. UnifiedPush
- **Type**: Open protocol for decentralized push notifications
- **Tech**: Multiple server implementations (ntfy, UP-NextPush)
- **Clients**: Android/iOS support via UnifiedPush specification
- **Effort**: 3-4 days (custom ACE plugin + protocol integration)
- **Cost**: VPS resources only
- **Sources**: [UnifiedPush](https://unifiedpush.org/)

### 3. AirNotifier
- **Type**: Open-source push server for mobile/desktop
- **Tech**: Python, supports APNs + Android push
- **Clients**: Generic HTTP client (mobile apps need custom implementation)
- **Effort**: 4-5 days (server setup + mobile client + ACE plugin)
- **Cost**: VPS resources only
- **Sources**: [AirNotifier](https://github.com/airnotifier/airnotifier)

### Migration Checklist (When Ready)

**Phase 1: Research & Planning** (1 week)
1. Choose self-hosted provider (Gotify recommended)
2. Design ACE push channel plugin architecture
3. Plan mobile app client changes (if needed)
4. Estimate VPS resource requirements

**Phase 2: Development** (2 weeks)
1. Deploy self-hosted push server (Gotify)
2. Write custom ACE push channel plugin
3. Test notification delivery (dev environment)
4. Update mobile app clients (if needed for custom protocol)

**Phase 3: Parallel Running** (2 weeks)
1. Configure dual-channel delivery (FCM + self-hosted)
2. Monitor delivery rates for both channels
3. Verify self-hosted reliability matches FCM

**Phase 4: Cutover** (1 week)
1. Switch `ACE_PUSH_CHANNELS` to self-hosted only
2. Monitor for issues
3. Decommission FCM after 30-day grace period

**Total migration effort**: ~6 weeks (mostly dev/testing, low risk)

---

## Alternatives Considered

### A. Use Braze (2U's Choice)

**Pros**:
- Enterprise-grade analytics
- Proven at 2U scale
- A/B testing built-in

**Cons**:
- $$$$ Expensive (thousands/month)
- Overkill for our scale (<10K active learners)
- Still vendor lock-in

**Rejected because**: Cost far exceeds value at our scale.

---

### B. Build Custom from Scratch

**Pros**:
- Full control
- Tailored to exact needs

**Cons**:
- Weeks of development effort
- Operational complexity (uptime, monitoring, scaling)
- Reinventing well-solved problem

**Rejected because**: Gotify/UnifiedPush already solve this if we go self-hosted.

---

### C. Skip Push Notifications

**Pros**:
- Zero infrastructure
- No provider dependencies

**Cons**:
- Poor learner experience (miss important updates)
- Industry standard for mobile learning apps
- Competitive disadvantage

**Rejected because**: Push notifications are table stakes for mobile apps.

---

## Implementation

### Firebase Setup (Current)

**Required secrets** (see `specs/mobile-apps-secrets-management_spec.md`):
```
MEREKA_LMS_MOBILE_FCM_SERVICE_ACCOUNT_JSON  # Firebase service account
MEREKA_LMS_MOBILE_FCM_SERVER_KEY            # Legacy API key (deprecated)
MEREKA_LMS_MOBILE_FIREBASE_PROJECT_ID       # Firebase project identifier
```

**Configuration** (LMS production.py):
```python
ACE_PUSH_CHANNELS = {
    'fcm': {
        'class': 'edx_ace.channel.push_notification.FCMPushNotificationChannel',
        'config': {
            'server_key': env('MOBILE_FCM_SERVER_KEY'),
            'service_account_json': env('MOBILE_FCM_SERVICE_ACCOUNT_JSON'),
        }
    }
}
```

**Mobile app configuration**:
- iOS: `GoogleService-Info.plist` with Firebase project config
- Android: `google-services.json` with Firebase project config

---

## Monitoring & Observability

**Metrics to track**:
- Notification delivery rate (via FCM console)
- Notification open rate (via Open edX analytics)
- Failed delivery count (via ACE logs)
- Delivery latency (timestamp diff: sent → delivered)

**Alerts**:
- Delivery rate drops below 95% → investigate FCM quota or credentials
- Failed delivery spike → check FCM service status

**Dashboard**: Grafana panel showing notification volume, delivery rate, failures over time

---

## Review & Revision

**Revisit this decision**:
- After 6 months (2026-08-13) - evaluate FCM costs and delivery reliability
- If notification volume exceeds 1M/month - reassess free tier sustainability
- If data sovereignty requirements emerge - fast-track self-hosted migration
- If VPS consolidation makes self-hosted trivial - consider opportunistic migration

---

## References

- [Open edX Mobile Setup](https://docs.openedx.org/en/latest/site_ops/install_configure_run_guide/mobile.html)
- [ACE Push Notifications](https://openedx.atlassian.net/wiki/spaces/COMM/pages/4982079504/Push+Notifications+in+Mobile+Apps)
- [FCM Alternatives](https://emteria.com/blog/fcm-alternatives)
- [15 Open-Source Push Notification Projects](https://medevel.com/15-os-push-notification/)
- [Gotify](https://github.com/gotify/server)
- [UnifiedPush](https://unifiedpush.org/)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)

---

**Last Updated**: 2026-02-13
**Decision Owner**: Platform Team
**Status**: ✅ ACCEPTED - Firebase for initial implementation, self-hosted migration path documented
