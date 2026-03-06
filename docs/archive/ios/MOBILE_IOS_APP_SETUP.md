# OpenEdX iOS Mobile App Setup for Mereka Academy

This guide covers how to deploy the official OpenEdX iOS app connected to your Mereka Academy LMS.

## Overview

- **App Repository**: https://github.com/openedx/openedx-app-ios
- **Your LMS**: `https://academyv2.mereka.io`
- **Deployment Method**: TestFlight (personal/team use) or App Store

## Quick Start (Mac with Xcode)

Run this one-liner to set up everything on your Mac:

```bash
curl -sL https://raw.githubusercontent.com/your-repo/mereka-lms/main/scripts/mobile/setup-ios-app.sh | bash
```

Or if you have this repo cloned locally:

```bash
# Copy the script to your Mac and run it
./scripts/mobile/setup-ios-app.sh
```

---

## Part 1: Server-Side Configuration

> ⚠️ **STATUS UNVERIFIED** (2026-02-13): Documentation claims mobile API enabled but requires runtime confirmation
> - OAuth App: `mereka-mobile-app` (claimed configured)
> - Redirect URI: `org.openedx.app://oauth2Callback` (claimed configured)
> - Mobile API: Claimed enabled (verify with: `tutor local run lms python manage.py lms shell -c "from django.conf import settings; print(settings.FEATURES.get('ENABLE_MOBILE_REST_API'))"`)
> - Default Mobile Available: Claimed enabled (verify with: `tutor local run lms python manage.py lms shell -c "from django.conf import settings; print(settings.FEATURES.get('DEFAULT_MOBILE_AVAILABLE'))"`)
>
> **Last verified**: Never (docs audit only, not runtime verification)
> **To verify**: Run the commands above in production environment

### Step 1: Enable Mobile API Features (Already Done)

Run this command to enable mobile API on your OpenEdX instance:

```bash
cd /home/gurpreet/projects/mereka-lms

# Enable mobile features in Tutor config
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate

tutor config save \
  --set ENABLE_MOBILE_REST_API=true \
  --set ENABLE_OAUTH2_PROVIDER=true

# Apply patches
./infrastructure/tutor/apply-patches.sh
```

### Step 2: Create OAuth2 Application for Mobile

Connect to your OpenEdX container and create the OAuth2 client:

**For Local Development:**
```bash
tutor local run lms ./manage.py lms create_dot_application \
  --grant-type authorization-code \
  --redirect-uris "org.openedx.app://oauth2Callback" \
  --client-id "mereka-mobile-app" \
  --scopes "openid profile email" \
  --skip-authorization \
  --public \
  "Mereka Mobile App" \
  admin
```

**For Kubernetes (Production):**
```bash
kubectl exec -it -n mereka-lms deployment/lms -- \
  ./manage.py lms create_dot_application \
    --grant-type authorization-code \
    --redirect-uris "org.openedx.app://oauth2Callback" \
    --client-id "mereka-mobile-app" \
    --scopes "openid profile email" \
    --skip-authorization \
    --public \
    "Mereka Mobile App" \
    admin
```

### Step 3: Make Courses Mobile-Available

In Studio (`studio.academyv2.mereka.io`):
1. Go to each course → Settings → Advanced Settings
2. Set `Mobile Course Available` to `true`

Or set globally via Django settings:
```python
# Add to LMS settings
FEATURES['DEFAULT_MOBILE_AVAILABLE'] = True
```

---

## Part 2: iOS App Setup

### Prerequisites

- macOS with Xcode 15+ installed
- Apple Developer Account (free account works for TestFlight personal use)
- iPhone running iOS 16+

### Step 1: Clone and Setup

```bash
cd ~/Projects  # or your preferred directory
git clone https://github.com/openedx/openedx-app-ios.git
cd openedx-app-ios
pod install
```

### Step 2: Create Configuration Directory

Create a custom configuration for Mereka Academy:

```bash
mkdir -p default_config/mereka
```

Create `default_config/mereka/config.yaml`:

```yaml
# Mereka Academy Mobile App Configuration
API_HOST_URL: "https://academyv2.mereka.io"

OAUTH_CLIENT_ID: "mereka-mobile-app"

# Discovery service (course catalog)
DISCOVERY_BASE_URL: "https://discovery.academyv2.mereka.io"

# Feature flags
FEATURES:
  PRE_LOGIN_EXPERIENCE_ENABLED: false
  COURSE_NESTED_LIST_ENABLED: true
  COURSE_UNIT_PROGRESS_ENABLED: true
  COURSE_DATES_CALENDAR_SYNC: true
  WHAT_IS_NEW_ENABLED: true
  SOCIAL_AUTH_ENABLED: true

# Social auth (if using Google OAuth)
GOOGLE:
  ENABLED: true
  CLIENT_ID: "YOUR_GOOGLE_IOS_CLIENT_ID"

# Microsoft auth (optional)
MICROSOFT:
  ENABLED: false

# Facebook auth (optional)
FACEBOOK:
  ENABLED: false

# Apple Sign In (recommended for App Store)
APPLE_SIGNIN:
  ENABLED: true

# Analytics (optional)
SEGMENT_IO:
  ENABLED: false
  
FIREBASE:
  ENABLED: false

# Braze push notifications (optional)
BRAZE:
  ENABLED: false

# Branch deep linking (optional)
BRANCH:
  ENABLED: false

# Agreement URLs
AGREEMENT_URLS:
  PRIVACY_POLICY_URL: "https://academyv2.mereka.io/privacy"
  TOS_URL: "https://academyv2.mereka.io/tos"
  EULA_URL: ""
  DATA_SELL_CONSENT_URL: ""
  SUPPORTED_LANGUAGES: []
  
# Feedback email
FEEDBACK_EMAIL: "team@mereka.io"

# App theme colors (brand customization)
THEME:
  PRIMARY_COLOR: "#1A1A2E"
  ACCENT_COLOR: "#E94560"
```

Create `default_config/mereka/config_settings.yaml`:

```yaml
# Build settings
config_directory: "mereka"
config_mapping:
  prod: "config.yaml"
  stage: "config.yaml"
  dev: "config.yaml"
```

### Step 3: Configure Xcode

1. Open `OpenEdX.xcworkspace` in Xcode
2. Select the **OpenEdX** project in the navigator
3. Go to **Build Settings** → **User-Defined**
4. Add: `CONFIG_DIRECTORY = mereka`

### Step 4: Set Bundle Identifier

1. Select the OpenEdX target
2. Go to **Signing & Capabilities**
3. Change Bundle Identifier to: `com.mereka.academy.mobile` (or your preferred ID)
4. Select your Team (your Apple Developer account)

### Step 5: Build and Test

1. Connect your iPhone via USB
2. Select your iPhone as the target device
3. Press **Cmd + R** to build and run

---

## Part 3: TestFlight Deployment (Personal Use)

### Step 1: Archive the App

1. In Xcode, select **Product → Archive**
2. Wait for the build to complete

### Step 2: Upload to App Store Connect

1. When archive completes, click **Distribute App**
2. Select **App Store Connect** → **Upload**
3. Follow the prompts

### Step 3: Set Up TestFlight

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your app → TestFlight
3. Add yourself as a tester (internal testing)
4. Wait for processing (~30 minutes)
5. Install via TestFlight app on your iPhone

---

## Part 4: Branding Customization

### App Icon

Replace the default icons in:
```
OpenEdX/Assets.xcassets/AppIcon.appiconset/
```

Use your Mereka Academy logo. Required sizes:
- 1024x1024 (App Store)
- 180x180 (@3x iPhone)
- 120x120 (@2x iPhone)
- 167x167 (iPad Pro)
- 152x152 (iPad)

### Splash Screen

Modify in:
```
OpenEdX/Assets.xcassets/SplashScreen/
```

### Colors

The theme colors are set in `config.yaml` under `THEME:`:
- `PRIMARY_COLOR`: Main brand color
- `ACCENT_COLOR`: Highlight/action color

---

## Troubleshooting

### "Courses not appearing in app"

1. Verify courses have "Mobile Course Available" = true in Studio
2. Check that your OAuth client is correctly configured
3. Verify API_HOST_URL in config.yaml is correct (no trailing slash)

### "Login fails with OAuth error"

1. Ensure `ENABLE_OAUTH2_PROVIDER=true` in Tutor config
2. Verify the OAuth application was created with `--public` flag
3. Check redirect URI matches exactly: `org.openedx.app://oauth2Callback`

### "Build fails in Xcode"

1. Run `pod install` again
2. Clean build folder: **Product → Clean Build Folder**
3. Check Xcode version compatibility (15+)

### "App rejected by App Store"

Common issues:
- Missing "Sign in with Apple" implementation
- Privacy policy URL not accessible
- App tracking without ATT prompt

---

## Quick Commands Reference

```bash
# Server-side: Enable mobile API
cd /home/gurpreet/projects/mereka-lms
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate
tutor config save --set ENABLE_MOBILE_REST_API=true --set ENABLE_OAUTH2_PROVIDER=true
./infrastructure/tutor/apply-patches.sh

# Server-side: Create OAuth app (K8s)
kubectl exec -it -n mereka-lms deployment/lms -- \
  ./manage.py lms create_dot_application \
    --grant-type authorization-code \
    --redirect-uris "org.openedx.app://oauth2Callback" \
    --client-id "mereka-mobile-app" \
    --scopes "openid profile email" \
    --skip-authorization \
    --public \
    "Mereka Mobile App" \
    admin

# iOS: Clone and setup
git clone https://github.com/openedx/openedx-app-ios.git
cd openedx-app-ios
pod install
open OpenEdX.xcworkspace
```

---

## Resources

- [OpenEdX Mobile Documentation](https://docs.openedx.org/en/latest/site_ops/install_configure_run_guide/mobile.html)
- [iOS App GitHub](https://github.com/openedx/openedx-app-ios)
- [Android App GitHub](https://github.com/openedx/openedx-app-android)
- [Apple Developer Docs](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
