# Fastlane Automation Setup ✅

**Status**: Automated certificate and provisioning profile creation via Fastlane

---

## What Changed

Instead of manually creating certificates and provisioning profiles on Mac, **Fastlane automatically creates them** using the App Store Connect API during the GitHub Actions build.

### How It Works

1. **Fastlane `cert`** - Automatically creates/downloads the distribution certificate
2. **Fastlane `sigh`** - Automatically creates/downloads the provisioning profile
3. Both use your App Store Connect API key (already configured)
4. No manual Mac steps needed!

---

## What You Still Need to Do

### 1. Create Bundle ID (One-time)

Go to: https://developer.apple.com/account → **Identifiers** → **+**

- Description: `Mereka Academy Mobile`
- Bundle ID: `com.mereka.academy.mobile` (Explicit)
- Enable: Sign In with Apple
- Click **Register**

### 2. Create App in App Store Connect (One-time)

Go to: https://appstoreconnect.apple.com → **My Apps** → **+** → **New App**

- Platform: iOS
- Name: `Mereka Academy`
- Bundle ID: `com.mereka.academy.mobile`
- SKU: `mereka-academy-ios-001`

---

## GitHub Secrets (Already Set ✅)

All required secrets are configured:

- ✅ `APPLE_TEAM_ID`: `44F7G2D7U6`
- ✅ `APP_STORE_CONNECT_API_KEY_ID`: `9MUD3HJQH5`
- ✅ `APP_STORE_CONNECT_ISSUER_ID`: `47ae8cb8-bfa9-49bd-816f-bde34e76d882`
- ✅ `APP_STORE_CONNECT_API_KEY_BASE64`: (set)
- ✅ `KEYCHAIN_PASSWORD`: `temp-keychain-password-123`
- ✅ `PROVISIONING_PROFILE_NAME`: `Mereka Academy Distribution`

**No more secrets needed!** Fastlane creates certificates automatically.

---

## Trigger the Build

Once Bundle ID and App are created:

```bash
# Option 1: Manual trigger
# Go to: https://github.com/Biji-Biji-Initiative/mereka-lms/actions
# Click "Build iOS App" → "Run workflow"

# Option 2: Push trigger
cd /home/gurpreet/bbi-meta/mereka-lms
git add .github/workflows/build-ios-app.yml
git commit -m "feat: enable Fastlane auto-certificate creation"
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
- Make sure you created `com.mereka.academy.mobile` in Apple Developer Portal

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
✅ **Team-friendly** - Certificates stored securely in GitHub Actions  
