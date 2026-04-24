# iOS App CI/CD Setup Guide

This guide walks through setting up GitHub Actions to automatically build the Mereka Academy iOS app and upload it to TestFlight.

## Prerequisites

- Apple Developer Account ($99/year) ✅ You have this
- GitHub repository access ✅ `Biji-Biji-Initiative/mereka-lms`

## Step 1: Create App Store Connect API Key

This key allows GitHub Actions to upload builds to TestFlight.

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **Users and Access** → **Integrations** → **App Store Connect API**
3. Click **Generate API Key**
4. Name: `GitHub Actions CI`
5. Access: **App Manager** (or Admin)
6. Click **Generate**
7. **Download the .p8 file** (you can only download once!)
8. Note down:
   - **Key ID** (e.g., `ABC123XYZ`)
   - **Issuer ID** (shown at top of page, e.g., `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

## Step 2: Create App ID in Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Click **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → **+** (Add)
4. Select **App IDs** → Continue
5. Select **App** → Continue
6. Fill in:
   - Description: `Mereka Academy Mobile`
   - Bundle ID: `com.mereka.academy.mobile` (Explicit)
7. Enable capabilities:
   - ✅ Sign In with Apple
   - ✅ Push Notifications (optional)
8. Click **Continue** → **Register**

## Step 3: Create Distribution Certificate

1. In Apple Developer Portal → **Certificates** → **+** (Add)
2. Select **Apple Distribution** → Continue
3. Follow instructions to create a CSR (Certificate Signing Request):
   - Open **Keychain Access** on a Mac (or use a cloud Mac)
   - Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority
   - Enter your email, select "Saved to disk"
4. Upload the CSR and download the certificate
5. Double-click to install in Keychain
6. Export as .p12:
   - In Keychain Access, find the certificate
   - Right-click → Export
   - Choose .p12 format
   - Set a password (remember this!)

## Step 4: Create Provisioning Profile

1. In Apple Developer Portal → **Profiles** → **+** (Add)
2. Select **App Store Connect** (under Distribution) → Continue
3. Select your App ID (`com.mereka.academy.mobile`) → Continue
4. Select your Distribution Certificate → Continue
5. Name: `Mereka Academy Distribution`
6. Click **Generate** → **Download**

## Step 5: Configure GitHub Secrets

Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `APPLE_TEAM_ID` | Your 10-character Team ID | Apple Developer Portal → Membership |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID from Step 1 | e.g., `ABC123XYZ` |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from Step 1 | e.g., `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64 of .p8 file | See below |
| `BUILD_CERTIFICATE_BASE64` | Base64 of .p12 certificate | See below |
| `P12_PASSWORD` | Password for .p12 file | The password you set in Step 3 |
| `KEYCHAIN_PASSWORD` | Any random password | e.g., `temporarykeychainpassword123` |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64 of provisioning profile | See below |
| `PROVISIONING_PROFILE_NAME` | Profile name | `Mereka Academy Distribution` |

### Converting Files to Base64

**On Windows (PowerShell):**
```powershell
# For .p8 API key
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_ABC123XYZ.p8")) | Set-Clipboard

# For .p12 certificate
[Convert]::ToBase64String([IO.File]::ReadAllBytes("certificate.p12")) | Set-Clipboard

# For .mobileprovision
[Convert]::ToBase64String([IO.File]::ReadAllBytes("profile.mobileprovision")) | Set-Clipboard
```

**On Linux/Mac:**
```bash
# For .p8 API key
base64 -i AuthKey_ABC123XYZ.p8 | pbcopy

# For .p12 certificate  
base64 -i certificate.p12 | pbcopy

# For .mobileprovision
base64 -i profile.mobileprovision | pbcopy
```

## Step 6: Create App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **+** → **New App**
2. Fill in:
   - Platform: iOS
   - Name: `Mereka Academy`
   - Primary Language: English
   - Bundle ID: `com.mereka.academy.mobile`
   - SKU: `mereka-academy-ios`
3. Click **Create**

## Step 7: Trigger the Build

Option A: **Push to trigger**
```bash
cd /home/gurpreet/projects/mereka-lms
git add .github/workflows/build-ios-app.yml
git commit -m "feat: add iOS app CI/CD workflow"
git push
```

Option B: **Manual trigger**
1. Go to GitHub repo → **Actions** → **Build iOS App**
2. Click **Run workflow** → **Run workflow**

## Step 8: Install via TestFlight

1. After the build completes (~30-45 min), go to App Store Connect
2. Navigate to your app → **TestFlight**
3. The build will appear under **iOS Builds** (may take 10-30 min for processing)
4. Click the build → **Manage Missing Compliance** → Select "None of the above"
5. Add yourself as an **Internal Tester**:
   - TestFlight → Internal Testing → **+** → Add your Apple ID
6. You'll receive an email invitation
7. Install **TestFlight** app on your iPhone
8. Open the email on your iPhone → tap to install

## Troubleshooting

### Build fails with "No signing certificate"
- Verify `BUILD_CERTIFICATE_BASE64` is correct
- Check certificate hasn't expired
- Ensure certificate type is "Apple Distribution"

### Build fails with "No provisioning profile"
- Verify `BUILD_PROVISION_PROFILE_BASE64` is correct
- Check profile hasn't expired
- Ensure Bundle ID matches exactly: `com.mereka.academy.mobile`

### Upload fails with "Invalid API Key"
- Verify `APP_STORE_CONNECT_API_KEY_BASE64` is the full .p8 file content
- Check API key hasn't been revoked
- Ensure Key ID and Issuer ID are correct

### App doesn't appear in TestFlight
- Wait 10-30 minutes for Apple processing
- Check App Store Connect → Activity for processing status
- Look for any compliance issues to resolve

## Quick Reference

```
Apple Developer Portal: https://developer.apple.com/account
App Store Connect: https://appstoreconnect.apple.com
GitHub Repo: https://github.com/Biji-Biji-Initiative/mereka-lms
Workflow: .github/workflows/build-ios-app.yml
Bundle ID: com.mereka.academy.mobile
```
