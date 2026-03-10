# iOS CI/CD Reference
_Audience: Operators and release owners • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

---

## Quick Reference

| Item | Value |
|------|-------|
| **Workflow** | `.github/workflows/build-ios-app.yml` |
| **Certificates Repo** | `git@github.com:Biji-Biji-Initiative/ios-certificates.git` |
| **Scheme** | `OpenEdXProd` |
| **Team ID** | Stored in `APPLE_TEAM_ID` secret |
| **Xcode Version** | 16.4 (Swift 6) |
| **Fastlane** | Via `bundle exec fastlane` |

---

## Non-Negotiables

1. **Latest OpenEdX iOS** - Use upstream release tags; never downgrade
2. **All Features Intact** - NEVER delete Firebase/push/entitlements to make builds pass
3. **Stable Signing System** - Must not break other apps under same Apple Developer team
4. **Manual Capability Management** - Capabilities enabled in Apple Portal, not via Fastlane automation
5. **Framework Targets Skip Signing** - Frameworks are signed when embedded, not individually

---

## Failure Modes and Why They Happened

### 1. Swift Toolchain Mismatch

**Problem**: OpenEdX iOS v2.2+ uses Swift 6. Mixing Xcode 15.x with Swift 6 packages causes compiler errors.

**Solution**: Always use Xcode 16+ via `xcodes` Fastlane plugin.

### 2. Global Signing Overrides via xcargs (CRITICAL)

**Problem**: Setting `CODE_SIGN_IDENTITY` / `PROVISIONING_PROFILE_SPECIFIER` in `xcargs` applies to **ALL targets** including SPM packages, CocoaPods, and framework targets. These targets don't need (and can't use) provisioning profiles.

**Symptoms**:
- `Dashboard.framework does not support provisioning profiles`
- `No signing certificate "iOS Development" found in target 'Profile'`
- Random framework targets failing to sign

**Solution**:
- **NEVER** put signing-related flags in `xcargs`
- Use `export_options` for main app signing only
- Set framework targets to `CODE_SIGNING_ALLOWED = NO` in project files

### 3. Fastlane Appfile Auto-Detection

**Problem**: OpenEdX's `fastlane/Appfile` contains `org.openedx.app` which overrides our bundle ID during `upload_to_testflight`.

**Symptoms**:
- `No suitable application records were found. Verify your bundle identifier "org.openedx.app"`

**Solution**: Override `Appfile` in CI before running Fastlane:
```bash
cat > fastlane/Appfile <<EOF
app_identifier(ENV["BUNDLE_ID"])
EOF
```

### 4. Capabilities Mismatch (Manual Portal Action Required)

**Problem**: If the app's entitlements include Push Notifications / Associated Domains / Sign in with Apple, but the App ID doesn't have those capabilities enabled, signing fails.

**Symptoms**:
- Provisioning profile does not support the required app capabilities

**CRITICAL**: `fastlane produce` CANNOT enable capabilities via API Key - it requires username/password which is not CI-compatible.

**Solution**: 
1. Manually enable capabilities in Apple Developer Portal
2. Run `fastlane match` with `force: true` to regenerate profiles

### 5. Build Number Collisions

**Problem**: Fixed build numbers cause TestFlight rejection on re-uploads.

**Solution**: Use `GITHUB_RUN_NUMBER` as `current_project_version`:
```yaml
current_project_version: '${GITHUB_RUN_NUMBER}'
```

### 6. whitelabel.py Argument Format

**Problem**: OpenEdX's `whitelabel.py` changed its CLI interface, breaking `--config-path`.

**Solution**: Try multiple formats with fallback:
```bash
python whitelabel.py whitelabel_config.yaml || \
python whitelabel.py --config whitelabel_config.yaml || \
python whitelabel.py --config-file whitelabel_config.yaml
```

### 7. xcconfig Files Override project.pbxproj

**Problem**: OpenEdX uses `.xcconfig` files that override `PRODUCT_BUNDLE_IDENTIFIER` set in `project.pbxproj`.

**Solution**: Patch BOTH xcconfig files AND project.pbxproj:
```bash
# Patch xcconfig files
for xcconfig in $(find . -name "*.xcconfig" -type f); do
  sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = ${BUNDLE_ID}/g" "$xcconfig"
done

# Patch Info.plist if hardcoded
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" OpenEdX/Info.plist
```

---

## Correct Architecture

### Signing Repository

| Property | Value |
|----------|-------|
| **Location** | dedicated certificates repository |
| **Purpose** | Store encrypted certificates and provisioning profiles |
| **Access** | SSH deploy key in `MATCH_DEPLOY_KEY` secret |

### GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `MATCH_DEPLOY_KEY` | SSH private key for certificates repo |
| `MATCH_PASSWORD` | Encryption password for match |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect Issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64-encoded .p8 key content |

Do not record actual secret values in docs.

### CI Environment

| Component | Requirement |
|-----------|-------------|
| Runner | `macos-latest` |
| Xcode | 16.4 (via `xcodes` plugin) |
| Ruby | Via bundler with OpenEdX's Gemfile |
| Fastlane | `>= 2.230.0` (fixes UNIVERSAL filter bug) |

---

## Framework Signing Configuration

**CRITICAL**: Framework targets must NOT be signed individually. They get signed when embedded in the main app.

### Required Settings for Each Framework

```bash
CODE_SIGN_STYLE = Manual;
CODE_SIGN_IDENTITY = "-";           # "-" means "don't sign"
CODE_SIGNING_REQUIRED = NO;
CODE_SIGNING_ALLOWED = NO;
PROVISIONING_PROFILE_SPECIFIER = "";
```

### Frameworks to Configure

- WhatsNew
- Dashboard
- Course
- Profile
- Discovery
- Discussion
- Core
- Theme
- Authorization
- Downloads

### Main App Settings

```bash
CODE_SIGN_STYLE = Manual;
CODE_SIGN_IDENTITY = "Apple Distribution";
PROVISIONING_PROFILE_SPECIFIER = "match AppStore com.mereka.academy.mobile";
DEVELOPMENT_TEAM = <YOUR_TEAM_ID>;
```

---

## Correct Fastlane Configuration

### Key Points

1. **NO `setup_ci`** - We create our own keychain (setup_ci can conflict)
2. **`readonly: false` + `force: true`** - Allow profile regeneration after capability changes
3. **`export_options` only** - All signing config goes here, NOT in xcargs
4. **Minimal `xcargs`** - Only `-skipPackagePluginValidation`, `-skipMacroValidation`, `CONFIG_DIRECTORY`

### Working build_app Configuration

```ruby
build_app(
  workspace: "OpenEdX.xcworkspace",
  scheme: "OpenEdXProd",
  export_method: "app-store",
  output_directory: "./build",
  output_name: "MerekaAcademy.ipa",
  clean: true,
  export_options: {
    signingStyle: "manual",
    teamID: ENV.fetch("TEAM_ID"),
    provisioningProfiles: {
      ENV.fetch("BUNDLE_ID") => "match AppStore #{ENV.fetch("BUNDLE_ID")}"
    },
    compileBitcode: false,
  },
  # ONLY non-signing xcargs - DO NOT add CODE_SIGN_* here!
  xcargs: [
    "-skipPackagePluginValidation",
    "-skipMacroValidation",
    "CONFIG_DIRECTORY=mereka",
  ].join(" ")
)
```

---

## Apple Developer Portal Setup

### Required Capabilities for com.mereka.academy.mobile

**CRITICAL**: These must be enabled MANUALLY - Fastlane cannot do it via API Key.

Go to: https://developer.apple.com/account/resources/identifiers/list

| Capability | Status | Notes |
|------------|--------|-------|
| Push Notifications | ENABLED | Required by app entitlements |
| Associated Domains | ENABLED | Required for deep linking |
| Sign In with Apple | ENABLED | Required for Apple auth |

### After Enabling Capabilities

1. Run CI workflow - `match` with `force: true` will regenerate the profile
2. Or manually: `bundle exec fastlane match appstore --force`

---

## Guardrails (Prevent Future Issues)

### NEVER DO

| Action | Consequence |
|--------|-------------|
| ❌ Put signing flags in `xcargs` | Breaks framework targets |
| ❌ Use `fastlane produce` for capabilities | Requires username/password, not API Key |
| ❌ Delete entitlements to make builds pass | Breaks features in production |
| ❌ Downgrade OpenEdX version | Swift version mismatches |
| ❌ Use `sed` to randomly edit pbxproj | State corruption |
| ❌ Skip overriding `Appfile` | Uses wrong bundle ID |

### ALWAYS DO

| Action | Reason |
|--------|--------|
| ✅ Override `fastlane/Appfile` in CI | Prevents org.openedx.app bundle ID |
| ✅ Disable signing for framework targets | They don't support provisioning profiles |
| ✅ Use `export_options` for signing | Only affects main app |
| ✅ Enable capabilities in Portal manually | Fastlane can't do it with API Keys |
| ✅ Use `GITHUB_RUN_NUMBER` for build number | Prevents TestFlight collisions |
| ✅ Patch xcconfig files AND pbxproj | xcconfig overrides pbxproj |

---

## Troubleshooting

### "Framework does not support provisioning profiles"

**Cause**: Signing `xcargs` leaking to framework targets  
**Fix**: Remove all signing flags from `xcargs`, use `export_options` only

### "No suitable application records found - org.openedx.app"

**Cause**: `fastlane/Appfile` not overridden  
**Fix**: Override Appfile before running Fastlane

### "Profile doesn't support capability X"

**Cause**: Capability not enabled on App ID  
**Fix**: Enable manually in Apple Developer Portal, run match with `force: true`

### "No signing certificate found" for framework target

**Cause**: Framework configured for development signing  
**Fix**: Set `CODE_SIGNING_ALLOWED = NO` for all framework targets

### Build number collision

**Cause**: Fixed `current_project_version`  
**Fix**: Use `${GITHUB_RUN_NUMBER}` as build number

### whitelabel.py argument error

**Cause**: CLI interface changed  
**Fix**: Try positional arg, `--config`, then `--config-file`

---

## Signing Inventory

### Current Apps

| App | Bundle ID | Team | Profile Type | Capabilities |
|-----|-----------|------|--------------|--------------|
| Mereka Academy | com.mereka.academy.mobile | BBI | AppStore | Push, Domains, Apple Sign-In |

### Certificates in ios-certificates Repo

| Type | Name | Expiry |
|------|------|--------|
| Distribution | Apple Distribution (BBI) | 2027-01-22 |

---

## References

- [OpenEdX iOS Releases](https://github.com/openedx/openedx-app-ios/releases)
- [Fastlane Match Documentation](https://docs.fastlane.tools/actions/match/)
- [Apple Code Signing Guide](https://developer.apple.com/documentation/xcode/code-signing-guide)
- [GitHub Actions macOS Runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners)
