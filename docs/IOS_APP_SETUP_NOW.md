# iOS App Setup - Current Steps

**Status**: ✅ API Key Created (`9MUD3HJQH5`)  
**Next**: Create Bundle ID + Get Issuer ID

---

## Step 1: Create Bundle ID (Do This Now)

1. Go to **https://developer.apple.com/account**
2. Login with your Apple Developer account
3. Click **Certificates, Identifiers & Profiles**
4. Click **Identifiers** → **+** (blue button)
5. Select **App IDs** → **Continue**
6. Select **App** → **Continue**
7. Fill in:
   - **Description**: `Mereka Academy Mobile`
   - **Bundle ID**: Select **Explicit** (not Wildcard)
   - **Bundle ID**: Type exactly: `com.mereka.academy.mobile`
8. Scroll down to **Capabilities**:
   - ✅ Check **Sign In with Apple**
   - (Leave others unchecked for now)
9. Click **Continue** → **Register**

✅ **Done!** Bundle ID `com.mereka.academy.mobile` is now registered.

---

## Step 2: Get Issuer ID from App Store Connect ✅ DONE

**Issuer ID**: `47ae8cb8-bfa9-49bd-816f-bde34e76d882`

(Already retrieved from App Store Connect)

---

## Step 3: Convert .p8 File to Base64 (Windows PowerShell)

Open PowerShell on your Windows PC and run:

```powershell
# Navigate to Downloads folder
cd C:\Users\MSAdmin\Downloads

# Convert .p8 to Base64 and copy to clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_9MUD3HJQH5.p8")) | Set-Clipboard

# Verify it copied (should show base64 text)
Get-Clipboard | Select-Object -First 1
```

✅ The base64 string is now in your clipboard!

---

## Step 4: Add GitHub Secrets ✅ DONE

**All secrets have been set via GitHub CLI!**

| Secret Name | Status |
|-------------|--------|
| `APPLE_TEAM_ID` | ✅ Set |
| `APP_STORE_CONNECT_API_KEY_ID` | ✅ Set |
| `APP_STORE_CONNECT_ISSUER_ID` | ✅ Set |
| `APP_STORE_CONNECT_API_KEY_BASE64` | ✅ Set |
| `KEYCHAIN_PASSWORD` | ✅ Set |
| `PROVISIONING_PROFILE_NAME` | ✅ Set |

Verify at: https://github.com/Biji-Biji-Initiative/mereka-lms/settings/secrets/actions

**For the remaining secrets** (you'll need these after creating certificate on Mac):

| Secret Name | Value | Status |
|-------------|-------|--------|
| `BUILD_CERTIFICATE_BASE64` | (base64 of .p12) | ⏳ Need Mac |
| `P12_PASSWORD` | (password for .p12) | ⏳ Need Mac |
| `KEYCHAIN_PASSWORD` | `temp-keychain-password-123` | ✅ Can set now |
| `BUILD_PROVISION_PROFILE_BASE64` | (base64 of .mobileprovision) | ⏳ Need Mac |
| `PROVISIONING_PROFILE_NAME` | `Mereka Academy Distribution` | ✅ Can set now |

---

## Step 5: Create App in App Store Connect

1. Go to **https://appstoreconnect.apple.com**
2. Click **My Apps** → **+** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: `Mereka Academy`
   - **Primary Language**: English
   - **Bundle ID**: Select `com.mereka.academy.mobile` (from dropdown)
   - **SKU**: `mereka-academy-ios-001`
4. Click **Create**

---

## Next Steps (On Mac)

Once you have access to a Mac, you'll need to:

1. **Create Distribution Certificate** (.p12)
2. **Create Provisioning Profile** (.mobileprovision)
3. **Convert both to Base64**
4. **Add remaining GitHub secrets**
5. **Trigger the build**

See `docs/IOS_APP_HANDOFF.md` for detailed Mac steps.

---

## Quick Reference

```
API Key ID: 9MUD3HJQH5
Bundle ID: com.mereka.academy.mobile
Team ID: 44F7G2D7U6
Key File: C:\Users\MSAdmin\Downloads\AuthKey_9MUD3HJQH5.p8
```
