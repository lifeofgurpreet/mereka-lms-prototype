# iOS App Setup - Handoff Document

**Status**: ⏳ Waiting for App Store Connect approval  
**Last Updated**: 2026-01-13  
**Next Agent**: Continue from Step 2 once Apple approves

---

## ✅ Completed Steps

### Server-Side (DONE)
- [x] Mobile API enabled on `academyv2.mereka.io`
- [x] OAuth2 Provider enabled
- [x] OAuth Application created: `mereka-mobile-app`
- [x] Default Mobile Available: enabled (all courses visible)
- [x] GitHub Actions workflow created: `.github/workflows/build-ios-app.yml`

### Configuration Details
```yaml
OAuth Client ID: mereka-mobile-app
Redirect URI: org.openedx.app://oauth2Callback
Bundle ID: com.mereka.academy.mobile
LMS URL: https://academyv2.mereka.io
```

### Apple Developer Account
```
Name: Gurpreet Singh
Company: PERSATUAN GAYA HIDUP LESTARI BIJI BIJI KUALA LUMPUR
Email: gurpreet@biji-biji.com
Team ID: 44F7G2D7U6
```

---

## ✅ App Store Connect API Key Created

**API Key ID**: `9MUD3HJQH5`  
**Key File**: `AuthKey_9MUD3HJQH5.p8` (Windows: `c:\Users\MSAdmin\Downloads\`)  
**Status**: ✅ Created, need to get Issuer ID

### Get Issuer ID
1. Go to https://appstoreconnect.apple.com
2. **Users and Access** → **Integrations** → **App Store Connect API**
3. Find your key `9MUD3HJQH5`
4. Copy the **Issuer ID** shown at the top of the page (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

---

## 📋 Steps to Complete

### Step 1: Create Bundle ID (App ID) in Apple Developer Portal

**This is what you need to do now:**

1. Go to https://developer.apple.com/account
2. Click **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → **+** (Add button)
4. Select **App IDs** → **Continue**
5. Select **App** → **Continue**
6. Fill in:
   - **Description**: `Mereka Academy Mobile`
   - **Bundle ID**: Select **Explicit**
   - **Bundle ID**: `com.mereka.academy.mobile`
7. Scroll down to **Capabilities** and enable:
   - ✅ **Sign In with Apple**
   - (Optional) Push Notifications
8. Click **Continue** → **Register**

**Important**: Write down the Bundle ID exactly: `com.mereka.academy.mobile`

### Step 2: Create App in App Store Connect

1. Go to **My Apps** → **+** → **New App**
2. Fill in:
   - Platform: **iOS**
   - Name: `Mereka Academy`
   - Primary Language: English
   - Bundle ID: `com.mereka.academy.mobile` (register new if needed)
   - SKU: `mereka-academy-ios`
3. Click **Create**

### Step 3: On Mac - Create Certificate

```bash
# Open Keychain Access
# Keychain Access → Certificate Assistant → Request Certificate From Certificate Authority
# - Email: gurpreet@biji-biji.com
# - Common Name: Gurpreet Singh
# - Select "Saved to disk"
# Save as: CertificateSigningRequest.certSigningRequest
```

Then in Apple Developer Portal (https://developer.apple.com/account):
1. **Certificates, Identifiers & Profiles** → **Certificates** → **+**
2. Select **Apple Distribution**
3. Upload the CSR file
4. Download the certificate (.cer)
5. Double-click to install in Keychain
6. In Keychain Access, find it, right-click → **Export** as .p12
7. Set a password (remember it!)

### Step 4: On Mac - Create App ID

In Apple Developer Portal:
1. **Identifiers** → **+**
2. Select **App IDs** → **App**
3. Fill in:
   - Description: `Mereka Academy Mobile`
   - Bundle ID (Explicit): `com.mereka.academy.mobile`
4. Enable capabilities:
   - ✅ Sign In with Apple
5. Click **Register**

### Step 5: On Mac - Create Provisioning Profile

In Apple Developer Portal:
1. **Profiles** → **+**
2. Select **App Store Connect** (under Distribution)
3. Select App ID: `com.mereka.academy.mobile`
4. Select the distribution certificate you created
5. Name: `Mereka Academy Distribution`
6. Download the .mobileprovision file

### Step 6: Convert Files to Base64

On Mac Terminal:
```bash
# API Key (.p8)
base64 -i ~/Downloads/AuthKey_XXXXXX.p8 | pbcopy
# Paste into GitHub secret: APP_STORE_CONNECT_API_KEY_BASE64

# Certificate (.p12)
base64 -i ~/Downloads/certificate.p12 | pbcopy
# Paste into GitHub secret: BUILD_CERTIFICATE_BASE64

# Provisioning Profile (.mobileprovision)
base64 -i ~/Downloads/Mereka_Academy_Distribution.mobileprovision | pbcopy
# Paste into GitHub secret: BUILD_PROVISION_PROFILE_BASE64
```

### Step 7: Add GitHub Secrets

Go to: https://github.com/Biji-Biji-Initiative/mereka-lms/settings/secrets/actions

Add these secrets:

| Secret Name | Value |
|-------------|-------|
| `APPLE_TEAM_ID` | `44F7G2D7U6` |
| `APP_STORE_CONNECT_API_KEY_ID` | (from Step 1) |
| `APP_STORE_CONNECT_ISSUER_ID` | (from Step 1) |
| `APP_STORE_CONNECT_API_KEY_BASE64` | (base64 of .p8) |
| `BUILD_CERTIFICATE_BASE64` | (base64 of .p12) |
| `P12_PASSWORD` | (password you set for .p12) |
| `KEYCHAIN_PASSWORD` | `temp-keychain-password-123` |
| `BUILD_PROVISION_PROFILE_BASE64` | (base64 of .mobileprovision) |
| `PROVISIONING_PROFILE_NAME` | `Mereka Academy Distribution` |

### Step 8: Trigger the Build

Option A - Manual trigger:
1. Go to https://github.com/Biji-Biji-Initiative/mereka-lms/actions
2. Click **Build iOS App** → **Run workflow**

Option B - Push trigger:
```bash
cd /home/gurpreet/projects/mereka-lms
touch mobile/ios/.trigger
git add . && git commit -m "trigger iOS build" && git push
```

### Step 9: Install via TestFlight

1. Wait ~45 min for build + Apple processing
2. Go to App Store Connect → Your App → TestFlight
3. Click the build → **Manage Missing Compliance** → "None of the above"
4. **Internal Testing** → **+** → Add gurpreet@biji-biji.com
5. On iPhone: Install TestFlight app, accept invite, install Mereka Academy

---

## 📁 Files Reference

| File | Purpose |
|------|---------|
| `.github/workflows/build-ios-app.yml` | GitHub Actions workflow |
| `docs/IOS_APP_CI_SETUP.md` | Detailed setup guide |
| `docs/MOBILE_IOS_APP_SETUP.md` | Server + manual build guide |
| `scripts/mobile/setup-ios-app.sh` | Mac setup script (optional) |
| `scripts/infra/setup-mobile-api.sh` | Server-side setup script |

---

## 🔧 Troubleshooting

### "No signing certificate" error
- Re-export .p12 from Keychain Access
- Ensure certificate type is "Apple Distribution"
- Check certificate hasn't expired

### "Provisioning profile doesn't match"
- Bundle ID must be exactly: `com.mereka.academy.mobile`
- Profile must use the same certificate

### "Invalid API Key"
- Download a fresh .p8 (can only download once per key)
- Verify Key ID and Issuer ID match

### Build succeeds but not in TestFlight
- Wait 10-30 min for Apple processing
- Check App Store Connect → Activity tab
- Resolve any compliance questions

---

## 📞 Quick Links

- Apple Developer: https://developer.apple.com/account
- App Store Connect: https://appstoreconnect.apple.com
- GitHub Repo: https://github.com/Biji-Biji-Initiative/mereka-lms
- GitHub Actions: https://github.com/Biji-Biji-Initiative/mereka-lms/actions
- LMS (production): https://academyv2.mereka.io
