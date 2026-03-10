# Fastlane Automation
_Audience: Operators and release owners • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

---

This guide covers the durable operator procedure for iOS delivery automation. Use it when you need to understand the Fastlane-driven signing flow, the one-time Apple-side prerequisites, and the safe trigger path for CI builds.

## How It Works

1. `fastlane cert` creates or downloads the distribution certificate.
2. `fastlane sigh` creates or downloads the provisioning profile.
3. GitHub Actions injects the required secrets at runtime.
4. Operators do not need a persistent workstation-specific signing setup.

---

## One-Time Apple-Side Prerequisites

### 1. Create Bundle ID (One-time)

Create the bundle identifier in Apple Developer:

- Description: `Mereka Academy Mobile`
- Bundle ID: explicit production bundle identifier for the app
- Enable: Sign In with Apple

### 2. Create App in App Store Connect (One-time)

Create the app record in App Store Connect:

- Platform: iOS
- Name: `Mereka Academy`
- Bundle ID: the same explicit production bundle identifier
- SKU: `mereka-academy-ios-001`

---

## Required GitHub Secrets

The build requires these secrets to exist in GitHub Actions or the approved secret manager flow:

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `KEYCHAIN_PASSWORD`
- `PROVISIONING_PROFILE_NAME`

Do not record actual values in docs. Retrieve and rotate them through the approved secret-management path.

---

## Trigger the Build

Once Bundle ID and App are created:

```bash
# Option 1: Manual trigger
# Go to: https://github.com/Biji-Biji-Initiative/mereka-lms/actions
# Click "Build iOS App" → "Run workflow"

# Option 2: repository-driven trigger
git add .github/workflows/build-ios-app.yml
git commit -m "docs: update iOS delivery automation"
git push
```

---

## What Happens During Build

1. ✅ Clone OpenEdX iOS app
2. ✅ Install dependencies (CocoaPods)
3. ✅ Create Mereka config
4. ✅ **Fastlane automatically creates certificate** (if needed)
5. ✅ **Fastlane automatically creates provisioning profile** (if needed)
6. ✅ Build the app
7. ✅ Upload to TestFlight

**No manual certificate/provisioning profile steps needed!**

---

## Troubleshooting

### "Bundle ID not found"
- Make sure the production bundle identifier exists in Apple Developer Portal

### "App not found in App Store Connect"
- Create the app in App Store Connect first (Step 2 above)

### "Certificate creation failed"
- Check API key has correct permissions (App Manager or Admin)
- Verify Team ID is correct

---

## Benefits

✅ **No Mac needed** - Everything runs in GitHub Actions  
✅ **No manual certificate management** - Fastlane handles it  
✅ **Automatic renewal** - Fastlane checks and updates certificates  
✅ **Team-friendly** - Certificates stored securely through the approved GitHub Actions secret flow  

## Read next

- [`../../reference/operations/IOS_CI_CD_REFERENCE.md`](../../reference/operations/IOS_CI_CD_REFERENCE.md)
- [`../../reference/operations/CI_CD_SETUP.md`](../../reference/operations/CI_CD_SETUP.md)
