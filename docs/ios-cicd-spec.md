# iOS CI/CD Specification - Mereka Academy

> **Status**: In Progress  
> **Last Updated**: 2026-01-22  
> **App**: Mereka Academy (OpenEdX iOS fork)  
> **Bundle ID**: `com.mereka.academy.mobile`

## Overview

This document specifies the correct approach for building and deploying the Mereka Academy iOS app to TestFlight, based on learnings from multiple failed attempts and expert guidance.

---

## Non-Negotiables

1. **Latest OpenEdX iOS** - Use upstream release tags; don't downgrade
2. **All Features** - Do NOT delete Firebase/push/entitlements/etc. to make builds pass
3. **Stable Signing System** - Must not break other apps under the same Apple Developer team

---

## Root Cause Analysis (Why Previous Builds Failed)

### 1. Swift Toolchain Mismatch

**Problem**: OpenEdX iOS v2.2 (Ulmo.1) migrated to Swift 6. Mixing Xcode 15.x/Swift 5.x with Swift 6 packages causes:
- "resolve package dependencies" failures
- Compiler errors ("unexpected ',' separator" - trailing comma syntax)
- Build setting drift

**Previous Mistakes**:
- Bouncing between Xcode versions (15.4, 16.1, 16.2)
- Downgrading OpenEdX to older versions
- Trying to patch Swift versions with sed

**Correct Approach**: Use Xcode 16+ consistently with latest OpenEdX iOS

### 2. Code Signing State Management

**Problem**: Apple code signing is stateful. The private key is generated on the machine that creates the cert. If CI creates a cert and the runner disappears, you have a certificate you can never use again.

**Previous Mistakes**:
- Using `fastlane cert/sigh` to create certs on ephemeral runners
- Hit Apple's 3-distribution-cert limit
- Created duplicate certificates

**Correct Approach**: Use `fastlane match` with:
- Private git repo for cert storage
- `readonly: true` in CI (never create certs automatically)
- Manual "signing maintenance" lane for cert rotation (human-triggered only)

### 3. Global Signing Overrides

**Problem**: Setting `CODE_SIGN_IDENTITY` / profile specifiers globally via `xcargs` applies to everything in the build graph (framework targets, packages), causing cascading signing failures.

**Previous Mistakes**:
- Using `xcargs` with `CODE_SIGN_IDENTITY='Apple Distribution'`
- Using `xcargs` with `PRODUCT_BUNDLE_IDENTIFIER`
- Trying to brute-force signing from command line

**Correct Approach**: 
- Set `DEVELOPMENT_TEAM` in project settings (committed to git)
- Use `export_options` for signing configuration
- Let Xcode + export options sign the final product

### 4. Capabilities Mismatch

**Problem**: If the app's entitlements include Push Notifications / Associated Domains but the App ID / provisioning profile doesn't have those capabilities enabled, signing/export fails.

**Previous Mistakes**:
- Removing entitlements to make builds pass
- Removing Firebase/analytics SPM dependencies
- Using sed to delete capabilities from pbxproj

**Correct Approach**:
- Enable required capabilities in Apple Developer Portal
- Regenerate profiles via match after enabling capabilities
- Keep all features intact

### 5. Automatic Signing in CI

**Problem**: "Automatic signing" requires Xcode to have an Apple ID logged in interactively. GitHub runners can't do this.

**Previous Mistakes**:
- Trying to use automatic signing with `-allowProvisioningUpdates`
- Getting "No Accounts" errors

**Correct Approach**: Manual signing with match

---

## Correct Architecture

### Signing Repository

- **Location**: `git@github.com:Biji-Biji-Initiative/ios-certificates.git`
- **Purpose**: Store encrypted certificates and provisioning profiles
- **Access**: SSH deploy key stored in GitHub Secrets

### GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `MATCH_DEPLOY_KEY` | SSH private key for accessing certificates repo |
| `MATCH_PASSWORD` | Encryption password for match |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect Issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64-encoded .p8 key content |

### CI Environment

| Component | Requirement |
|-----------|-------------|
| Runner | `macos-latest` |
| Xcode | 16+ (via `xcodes` plugin in Fastfile) |
| Ruby | Via bundler with OpenEdX's Gemfile |
| Fastlane | Via `bundle exec fastlane` |

---

## Correct Fastlane Setup

### Fastfile Template

```ruby
default_platform(:ios)

require "base64"

platform :ios do
  # API Key helper
  private_lane :asc_api_key do
    key_content = Base64.decode64(ENV.fetch("ASC_KEY_P8_BASE64"))
    app_store_connect_api_key(
      key_id: ENV.fetch("ASC_KEY_ID"),
      issuer_id: ENV.fetch("ASC_ISSUER_ID"),
      key_content: key_content,
      in_house: false
    )
  end

  # Human-triggered only - for cert maintenance
  lane :signing_maint do
    api_key = asc_api_key

    match(
      type: "appstore",
      api_key: api_key,
      readonly: false,  # Can create/update certs
      app_identifier: [ENV.fetch("BUNDLE_ID")],
      git_url: ENV.fetch("MATCH_GIT_URL")
    )
  end

  # CI lane - readonly, safe
  lane :ci_testflight do
    setup_ci  # Creates temp keychain, sets match to readonly

    api_key = asc_api_key

    match(
      type: "appstore",
      api_key: api_key,
      readonly: true,  # NEVER create certs in CI
      app_identifier: [ENV.fetch("BUNDLE_ID")],
      git_url: ENV.fetch("MATCH_GIT_URL")
    )

    build_app(
      workspace: "OpenEdX.xcworkspace",
      scheme: "OpenEdXProd",
      export_method: "app-store",
      export_options: {
        signingStyle: "manual",
        teamID: ENV.fetch("TEAM_ID"),
        provisioningProfiles: {
          ENV.fetch("BUNDLE_ID") => "match AppStore #{ENV.fetch("BUNDLE_ID")}"
        }
      },
      xcargs: "DEVELOPMENT_TEAM=#{ENV.fetch("TEAM_ID")}"
    )

    upload_to_testflight(api_key: api_key)
  end
end
```

### Key Points

1. **`setup_ci`** - Creates temp keychain and sets match to readonly mode automatically
2. **`readonly: true`** - CI can NEVER create certificates
3. **`export_options`** - Signing configuration goes here, not in xcargs
4. **`xcargs`** - Only contains `DEVELOPMENT_TEAM`, nothing else

---

## Guardrails (Prevent Future Issues)

### DO NOT

- ❌ Downgrade OpenEdX to older versions
- ❌ Create certs in CI (use `readonly: true`)
- ❌ Delete entitlements to make builds pass
- ❌ Edit pbxproj files with sed/regex
- ❌ Use global signing overrides in xcargs
- ❌ Use `fastlane cert/sigh` directly in CI

### DO

- ✅ Use latest OpenEdX iOS release tags
- ✅ Use Xcode 16+ (Swift 6) consistently
- ✅ Use `setup_ci` + `match(readonly: true)` in CI
- ✅ Enable capabilities in Apple Developer Portal first
- ✅ Use `bundle exec fastlane` (not raw fastlane)
- ✅ Keep signing configuration in export_options

---

## Apple Developer Portal Setup

### Required Capabilities for Bundle ID

**CRITICAL**: The build fails with "profile doesn't support capability" until these are enabled.

Enable these in Apple Developer → Identifiers → App IDs → `com.mereka.academy.mobile`:

- [ ] **Push Notifications** (REQUIRED - app has entitlement)
- [ ] **Associated Domains** (REQUIRED - app has entitlement)
- [ ] Sign In with Apple
- [ ] (Any other capabilities in .entitlements files)

### Steps to Enable Capabilities

1. Go to https://developer.apple.com/account/resources/identifiers/list
2. Find `com.mereka.academy.mobile` (or create if it doesn't exist)
3. Click Edit
4. Enable "Push Notifications"
5. Enable "Associated Domains"
6. Save

### After Enabling Capabilities - Regenerate Profile

After enabling capabilities, the provisioning profile must be regenerated.

**Option 1**: Delete and recreate via match (recommended)
```bash
# Clone the ios-certificates repo
git clone git@github.com:Biji-Biji-Initiative/ios-certificates.git
cd ios-certificates

# Delete the old profile
rm -rf profiles/appstore/AppStore_com.mereka.academy.mobile.mobileprovision

# Commit and push
git add -A && git commit -m "Remove old profile for capability update" && git push
```

Then trigger the CI workflow - match will create a new profile with the capabilities.

**Option 2**: Run match manually with force
```bash
cd ios-app
BUNDLE_ID=com.mereka.academy.mobile \
TEAM_ID=YOUR_TEAM_ID \
ASC_KEY_ID=YOUR_KEY_ID \
ASC_ISSUER_ID=YOUR_ISSUER_ID \
ASC_KEY_P8_BASE64=$(base64 < path/to/AuthKey.p8) \
MATCH_PASSWORD=your_match_password \
bundle exec fastlane match appstore --force
```

### Current Status

- **Build Status**: Failing at signing (profile missing capabilities)
- **Blocking Issue**: Push Notifications and Associated Domains not enabled on App ID
- **Action Required**: User must enable capabilities in Apple Developer Portal

---

## Troubleshooting

### "No signing certificate found"

**Cause**: Framework targets configured for automatic signing with development certs
**Fix**: Use `update_code_signing_settings` in Fastlane to disable signing for framework targets (they don't need to be signed for app store builds)

### "Profile doesn't include X capability"

**Cause**: App ID doesn't have the capability enabled
**Fix**: Enable in Apple Developer Portal, then run `fastlane signing_maint`

### "unexpected ',' separator"

**Cause**: Swift version mismatch (code uses Swift 5.3+ syntax but target set to Swift 5.0)
**Fix**: Use Xcode 16+ which properly handles Swift 6 via `xcodes` plugin

### "The specified item could not be found in the keychain"

**Cause**: Certificate not properly installed or keychain not unlocked
**Fix**: Use `setup_ci` which handles keychain setup automatically

---

## References

- [OpenEdX iOS Releases](https://github.com/openedx/openedx-app-ios/releases)
- [Fastlane Match Documentation](https://docs.fastlane.tools/actions/match/)
- [Fastlane setup_ci Documentation](https://docs.fastlane.tools/actions/setup_ci/)
- [Apple Certificate Limits](https://stackoverflow.com/questions/38194971/how-many-ios-ad-hoc-distibution-certificates-can-be-created-limit-for-certifica)
