# ADR-016: Android App Support Decision

**Status**: Deferred
**Date**: 2026-02-13
**Deciders**: Platform Team

<!-- Last verified: 2026-02-13 -->

## Context

The mobile apps specification (`specs/mobile-apps-enterprise_spec.md`) outlines support for both iOS and Android mobile applications. Currently:

1. **iOS app status**:
- Setup documentation exists (`docs/archive/ios/MOBILE_IOS_APP_SETUP.md`)
   - Configuration claimed complete but **UNVERIFIED in production**
   - Mobile API status: claimed enabled but requires runtime confirmation
   - OAuth app (`mereka-mobile-app`): claimed configured but not verified
   - No runtime verification has been performed

2. **Android app status**:
   - No Android-specific setup documentation
   - No signing infrastructure (no upload key, no Google Play account verified)
   - No Play Store provisioning
   - No build pipeline exists (unlike iOS which has `.github/workflows/build-ios-app.yml`)

3. **Mobile spec status**:
   - `specs/mobile-apps-enterprise_spec.md`: status = "draft"
   - Not even marked as "in_progress"
   - 37 acceptance criteria defined but none verified

4. **Resource allocation**:
   - Core platform requires hardening
   - Web responsive design covers most mobile use cases
   - No demonstrated user demand for native Android specifically
   - Team bandwidth limited for supporting two mobile platforms simultaneously

## Decision

We are **deferring** Android app development indefinitely.

**Rationale**:
- iOS app setup is unverified - must validate the existing claimed setup before adding Android
- No Android infrastructure exists (signing keys, Play Store account, build pipeline)
- Mobile spec is in draft status, indicating feature is not production-ready
- Web-responsive design provides adequate mobile experience
- Resource better spent on core platform stability and LMS feature development
- Open edX mobile apps require significant customization for branding - doubling this effort for Android without proven demand is premature

**Revisit conditions**:
1. iOS app is fully operational and verified in production
2. User demand demonstrates need for native Android experience (quantified through support requests or surveys)
3. Mobile spec reaches APPROVED status with all acceptance criteria met
4. Team has capacity for Android-specific development and maintenance

## Consequences

### Positive
- Focus engineering resources on core platform stability
- Avoid premature infrastructure investment (Play Store account, signing keys, CI/CD)
- Reduce maintenance burden (one mobile platform vs two)
- Allow iOS to serve as proof-of-concept before committing to Android
- Defer decision until user demand is validated

### Negative
- Android users cannot access native mobile app features (offline mode, push notifications)
- Potential user experience gap for Android-majority user bases
- Cannot claim feature parity across all platforms
- May delay mobile-first clients who require Android support

### Immediate Actions
1. **Remove misleading references**: Update `docs/reference/operations/CAPABILITY_MATRIX.md` to clearly mark Android app as "DEFERRED" (currently shows "DRAFT" which implies it may be built)
2. **Update mobile spec**: Add deferral notice to `specs/mobile-apps-enterprise_spec.md` indicating Android is not in scope for v1
3. **Keep mobile API enabled**: The backend mobile API should remain enabled to support potential future Android deployment and current iOS work

## Alternatives Considered

### Build both iOS and Android simultaneously
- **Rejected because**: iOS setup is unverified; building Android in parallel compounds risk
- **Rejected because**: No demonstrated Android-specific demand
- **Rejected because**: Team bandwidth insufficient for supporting both platforms

### Build Android only
- **Rejected because**: iOS work has already started (documentation exists, CI/CD exists)
- **Rejected because**: iOS app infrastructure already in place

### Use React Native for cross-platform
- **Rejected because**: Open edX maintains separate native iOS and Android apps
- **Rejected because**: Would require rewriting existing iOS app or maintaining divergent implementations

## Implementation Notes

### Documentation Updates Required
- [ ] Update `docs/reference/operations/CAPABILITY_MATRIX.md`: Change Android app status from "DRAFT" to "DEFERRED"
- [ ] Add deferral notice to `specs/mobile-apps-enterprise_spec.md` (Android section)
- [ ] Update `docs/archive/ios/MOBILE_IOS_APP_SETUP.md` to remove references suggesting Android is coming soon

### iOS Verification Checklist (prerequisite for reconsidering Android)
Before Android development begins, iOS must be verified:
- [ ] Verify mobile API enabled in production: `tutor local run lms python manage.py lms shell -c "from django.conf import settings; print(settings.FEATURES.get('ENABLE_MOBILE_REST_API'))"`
- [ ] Verify OAuth app exists: Query production database for `mereka-mobile-app` client
- [ ] Verify TestFlight deployment works
- [ ] Verify at least one course is mobile-available
- [ ] Verify login flow completes successfully on physical iOS device
- [ ] Verify course content loads in iOS app

### Future Android Requirements (when reconsidered)
If/when Android development is approved:
- Google Play Developer account ($25 one-time fee)
- Android signing key generated and stored in Infisical
- GitHub Actions workflow for Android builds
- Firebase Cloud Messaging (FCM) configuration for Android
- Android deep linking configuration (`assetlinks.json`)
- Testing devices/emulators for QA

## Related
- ADR-017: Analytics target decision (similar deferral pattern)
- `specs/mobile-apps-enterprise_spec.md` (mobile strategy)
- `docs/archive/ios/MOBILE_IOS_APP_SETUP.md` (iOS setup)
- `docs/reference/operations/CAPABILITY_MATRIX.md` (capability tracking)
