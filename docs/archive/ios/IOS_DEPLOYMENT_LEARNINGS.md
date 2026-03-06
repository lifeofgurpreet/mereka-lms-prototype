# iOS Deployment Learnings - Post-Mortem

> **Date**: 2026-01-23  
> **Duration**: ~8 hours of debugging  
> **Outcome**: Successfully deployed to TestFlight  
> **First Working Build**: Run #21274409453

This document captures ALL learnings from the initial iOS CI/CD setup to prevent future issues.

---

## Executive Summary

The iOS CI/CD pipeline for Mereka Academy (OpenEdX iOS fork) took multiple iterations to get working. The primary issues were:

1. **xcargs pollution** - Signing flags applied to all targets including frameworks
2. **Appfile override missing** - OpenEdX's default bundle ID used
3. **Capabilities not enabled** - Manual Apple Portal action required
4. **Framework signing confusion** - Frameworks don't need individual signing
5. **Build number collisions** - Fixed versions rejected by TestFlight

---

## Timeline of Failures and Fixes

### Build #21232815231 - Swift Version Mismatch
**Error**: Compiler errors with trailing comma syntax  
**Root Cause**: Xcode 15.x with Swift 6 code  
**Fix**: Pin Xcode 16.4 via `xcodes` plugin

### Build #21233231443 - Scheme Not Found
**Error**: Scheme "OpenEdX" not found  
**Root Cause**: Using wrong scheme name  
**Fix**: Use `OpenEdXProd` scheme

### Build #21240700291 - Wrong Bundle ID
**Error**: `No suitable application records found - org.openedx.app`  
**Root Cause**: `fastlane/Appfile` auto-detection  
**Fix**: Override Appfile in CI:
```bash
cat > fastlane/Appfile <<EOF
app_identifier(ENV["BUNDLE_ID"])
EOF
```

### Build #21241067209 - Framework Signing Failure
**Error**: `Dashboard.framework does not support provisioning profiles`  
**Root Cause**: `xcargs` with `CODE_SIGN_IDENTITY` applied to all targets  
**Fix**: Remove signing from xcargs, use export_options only

### Build #21241678497 - Missing Capabilities
**Error**: `Profile doesn't support Associated Domains and Push Notifications`  
**Root Cause**: Capabilities not enabled on App ID in Apple Portal  
**Fix**: Manual enablement in Apple Developer Portal (Fastlane CAN'T do this with API Keys)

### Build #21241967693 - Produce Requires Password
**Error**: `No value found for 'username'`  
**Root Cause**: `fastlane produce` doesn't support API Key authentication for capabilities  
**Fix**: Remove produce action, enable capabilities manually

### Build #21242654812 - Profile Still Missing Capabilities
**Error**: Same as above  
**Root Cause**: Profile not regenerated after enabling capabilities  
**Fix**: Use `match` with `force: true` and `readonly: false`

### Build #21243080191 - Framework Signing (Again)
**Error**: `No signing certificate "iOS Development" found in target 'Profile'`  
**Root Cause**: Framework targets still trying to sign  
**Fix**: Aggressive sed commands to set `CODE_SIGNING_ALLOWED = NO` for all frameworks

### Build #21273281861 - whitelabel.py Arguments
**Error**: `unrecognized arguments: --config-path`  
**Root Cause**: OpenEdX changed CLI interface  
**Fix**: Try multiple argument formats with fallback

### Build #21273667591 - IPA Verification Script Failure
**Error**: `ERROR: Bundle ID mismatch!` (false positive)  
**Root Cause**: Ruby interpolation in shell heredoc  
**Fix**: Remove the verification script (IPA was actually correct)

### Build #21274409453 - SUCCESS
**Result**: IPA built and uploaded to TestFlight successfully

---

## The Three Domains of iOS CI/CD Failure

### Domain A: Dependency/Compiler Compatibility

**Problems**:
- Swift version mismatches (Swift 5 vs Swift 6)
- Package dependencies requiring newer Xcode
- CocoaPods version conflicts

**Solution**: Pin environment:
- Xcode: 16.4 via `xcodes` plugin
- Fastlane: `>= 2.230.0` (fixes UNIVERSAL filter bug)
- Ruby: Via bundler with OpenEdX's Gemfile

### Domain B: Code Signing & CI Identity

**Problems**:
- Ephemeral CI runners can't use interactive Apple ID login
- Auto-signing requires Xcode UI
- Certificates created on runners are orphaned when runner dies

**Solution**: `fastlane match` with:
- Private git repo for cert storage
- `readonly: true` in CI (normally)
- `readonly: false` + `force: true` when capabilities change
- SSH deploy key for repo access

### Domain C: Capabilities & Entitlements

**Problems**:
- Entitlements in app don't match App ID capabilities
- Fastlane `produce` can't enable capabilities via API Key
- Profiles must be regenerated after capability changes

**Solution**:
- Enable capabilities MANUALLY in Apple Developer Portal
- NEVER remove entitlements to make builds pass
- Regenerate profiles via match after capability changes

---

## Critical Technical Details

### Why xcargs for Signing Breaks Everything

When you use:
```ruby
build_app(
  xcargs: "CODE_SIGN_IDENTITY='Apple Distribution' PROVISIONING_PROFILE_SPECIFIER='...'",
  ...
)
```

These flags apply to **EVERY target** in the build graph:
- Main app (correct)
- Framework targets (WRONG - they don't use profiles)
- SPM packages (WRONG - they don't sign)
- CocoaPods (WRONG - they don't sign)

**Correct approach**: Use `export_options` which only affects the main app during export:
```ruby
build_app(
  export_options: {
    signingStyle: "manual",
    teamID: ENV.fetch("TEAM_ID"),
    provisioningProfiles: {
      ENV.fetch("BUNDLE_ID") => "match AppStore #{ENV.fetch("BUNDLE_ID")}"
    }
  },
  xcargs: "-skipPackagePluginValidation -skipMacroValidation"  # NO signing flags!
)
```

### Why Fastlane produce Can't Enable Capabilities

`fastlane produce` uses Apple's old web session authentication, not the App Store Connect API. When you use API Keys (the correct CI approach), `produce` fails with:
```
No value found for 'username'
```

**There is no fix** - capabilities MUST be enabled manually in the Apple Developer Portal.

### Why Frameworks Must Skip Signing

iOS frameworks embedded in an app are signed **as part of the app** during the export phase. Individual framework targets in Xcode don't need:
- Provisioning profiles
- Code signing identity
- Team ID for signing

Setting these on framework targets causes:
```
Dashboard.framework does not support provisioning profiles
```

**Fix**: Set these in each framework's project.pbxproj:
```
CODE_SIGN_IDENTITY = "-";
CODE_SIGNING_ALLOWED = NO;
CODE_SIGNING_REQUIRED = NO;
PROVISIONING_PROFILE_SPECIFIER = "";
```

---

## The Correct sed Commands

### For Framework Targets

```bash
for framework_dir in WhatsNew Dashboard Course Profile Discovery Discussion Core Theme Authorization Downloads; do
  proj_path="${framework_dir}/${framework_dir}.xcodeproj/project.pbxproj"
  if [ -f "$proj_path" ]; then
    # Replace CODE_SIGN_STYLE with Manual
    sed -i '' 's/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Manual;/g' "$proj_path"
    
    # Replace CODE_SIGN_IDENTITY with "-" (don't sign)
    sed -i '' 's/CODE_SIGN_IDENTITY = "[^"]*";/CODE_SIGN_IDENTITY = "-";/g' "$proj_path"
    
    # Disable signing
    sed -i '' 's/CODE_SIGNING_REQUIRED = YES;/CODE_SIGNING_REQUIRED = NO;/g' "$proj_path"
    sed -i '' 's/CODE_SIGNING_ALLOWED = YES;/CODE_SIGNING_ALLOWED = NO;/g' "$proj_path"
    
    # Clear provisioning profile
    sed -i '' 's/PROVISIONING_PROFILE_SPECIFIER = "[^"]*";/PROVISIONING_PROFILE_SPECIFIER = "";/g' "$proj_path"
  fi
done
```

### For Main App Target

```bash
main_proj="OpenEdX.xcodeproj/project.pbxproj"

# Set manual signing
sed -i '' 's/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Manual;/g' "$main_proj"

# Set team ID
sed -i '' "s/DEVELOPMENT_TEAM = \"\";/DEVELOPMENT_TEAM = ${TEAM_ID};/g" "$main_proj"
sed -i '' "s/DEVELOPMENT_TEAM = [A-Z0-9]*;/DEVELOPMENT_TEAM = ${TEAM_ID};/g" "$main_proj"

# Inject or replace PROVISIONING_PROFILE_SPECIFIER
if ! grep -q "PROVISIONING_PROFILE_SPECIFIER" "$main_proj"; then
  sed -i '' 's/DEVELOPMENT_TEAM = [^;]*;/&\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "match AppStore '"${BUNDLE_ID}"'";/g' "$main_proj"
else
  sed -i '' 's/PROVISIONING_PROFILE_SPECIFIER = "[^"]*";/PROVISIONING_PROFILE_SPECIFIER = "match AppStore '"${BUNDLE_ID}"'";/g' "$main_proj"
fi

# Inject or replace CODE_SIGN_IDENTITY
if ! grep -q "CODE_SIGN_IDENTITY" "$main_proj"; then
  sed -i '' 's/DEVELOPMENT_TEAM = [^;]*;/&\n\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";/g' "$main_proj"
else
  sed -i '' 's/CODE_SIGN_IDENTITY = "[^"]*";/CODE_SIGN_IDENTITY = "Apple Distribution";/g' "$main_proj"
fi
```

### For xcconfig Files

```bash
for xcconfig in $(find . -name "*.xcconfig" -type f); do
  if grep -q "PRODUCT_BUNDLE_IDENTIFIER" "$xcconfig"; then
    sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = ${BUNDLE_ID}/g" "$xcconfig"
  fi
done
```

---

## Debugging Profile Entitlements

To verify a provisioning profile has the required capabilities:

```bash
for dir in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" "$HOME/Library/MobileDevice/Provisioning Profiles"; do
  if [ -d "$dir" ]; then
    for p in "$dir"/*.mobileprovision; do
      [ -f "$p" ] || continue
      security cms -D -i "$p" > /tmp/profile.plist 2>/dev/null || continue
      BID=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" /tmp/profile.plist 2>/dev/null || true)
      if echo "$BID" | grep -q "com.mereka.academy.mobile"; then
        echo "=== Profile Entitlements ==="
        /usr/libexec/PlistBuddy -c "Print :Entitlements" /tmp/profile.plist
        echo "Push: $(/usr/libexec/PlistBuddy -c 'Print :Entitlements:aps-environment' /tmp/profile.plist 2>/dev/null || echo 'NOT FOUND')"
        echo "Domains: $(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.developer.associated-domains' /tmp/profile.plist 2>/dev/null || echo 'NOT FOUND')"
        echo "Apple Sign-In: $(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.developer.applesignin' /tmp/profile.plist 2>/dev/null || echo 'NOT FOUND')"
      fi
    done
  fi
done
```

---

## What NOT to Do (Anti-Patterns)

### 1. Don't Delete Entitlements

**Wrong**:
```bash
# Removing Firebase/push/etc to make build pass
sed -i '' '/<key>aps-environment<\/key>/d' OpenEdX/OpenEdX.entitlements
```

**Why**: You'll ship an app that can't use push notifications.

### 2. Don't Brute-Force Signing in xcargs

**Wrong**:
```ruby
xcargs: "CODE_SIGN_IDENTITY='Apple Distribution' PROVISIONING_PROFILE_SPECIFIER='...'"
```

**Why**: Applies to all targets, breaks frameworks.

### 3. Don't Use fastlane produce for Capabilities

**Wrong**:
```ruby
produce(
  enable_services: {
    push_notification: "on",
    associated_domains: "on"
  }
)
```

**Why**: Requires username/password, not compatible with API Keys.

### 4. Don't Skip Appfile Override

**Wrong**:
```ruby
# Just running fastlane without overriding Appfile
bundle exec fastlane ci_testflight
```

**Why**: Uses `org.openedx.app` from OpenEdX's Appfile.

### 5. Don't Use Fixed Build Numbers

**Wrong**:
```yaml
current_project_version: '1'
```

**Why**: TestFlight rejects duplicate build numbers.

---

## Future Maintenance

### Adding New Capabilities

1. Go to Apple Developer Portal → Identifiers
2. Find `com.mereka.academy.mobile`
3. Enable the new capability
4. Trigger CI build - match will regenerate profile with `force: true`

### Certificate Rotation

When certificates expire (2027-01-22):
1. Run locally: `bundle exec fastlane match nuke distribution`
2. Run locally: `bundle exec fastlane match appstore` (creates new cert)
3. CI builds will automatically use the new cert

### Adding New Apps to Same Team

1. Create new App ID in Apple Portal
2. Enable required capabilities manually
3. Add bundle ID to `match` call in CI:
   ```ruby
   match(
     app_identifier: [ENV.fetch("BUNDLE_ID"), "com.mereka.newapp"],
     ...
   )
   ```

---

## Key Takeaways

1. **Environment first, signing second, capabilities third** - Solve in this order
2. **export_options is your friend** - All signing config goes here
3. **Capabilities are manual** - Apple's API doesn't support enabling them
4. **Frameworks don't sign** - Set `CODE_SIGNING_ALLOWED = NO`
5. **Always override Appfile** - Prevents bundle ID confusion
6. **Use GITHUB_RUN_NUMBER** - Automatic unique build numbers
