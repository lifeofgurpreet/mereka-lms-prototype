# Apple Developer Account Setup Status

**Checked via API**: 2026-01-15

---

## ✅ What's Already Done

| Item | Status | Details |
|------|--------|---------|
| **Bundle ID** | ✅ **EXISTS** | `com.mereka.academy.mobile` |
| **API Key** | ✅ **CONFIGURED** | `9MUD3HJQH5` |
| **Issuer ID** | ✅ **CONFIGURED** | `47ae8cb8-bfa9-49bd-816f-bde34e76d882` |
| **Team ID** | ✅ **CONFIGURED** | `44F7G2D7U6` |
| **GitHub Secrets** | ✅ **ALL SET** | All 6 secrets configured |

---

## ⏳ What Needs Manual Step

| Item | Status | Action Required |
|------|--------|-----------------|
| **App in App Store Connect** | ❌ **NOT CREATED** | Create via web UI (API doesn't allow CREATE) |

### Create App (One-Time Manual Step)

**Note**: App Store Connect API doesn't allow creating apps programmatically. You must create it via the web UI.

1. Go to: **https://appstoreconnect.apple.com**
2. Click **My Apps** → **+** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: `Mereka Academy`
   - **Primary Language**: English
   - **Bundle ID**: Select `com.mereka.academy.mobile` (from dropdown)
   - **SKU**: `mereka-academy-ios-001`
4. Click **Create**

---

## ✅ What Happens Automatically

Once the App is created, Fastlane will automatically:

- ✅ **Create Distribution Certificate** (via `fastlane cert`)
- ✅ **Create Provisioning Profile** (via `fastlane sigh`)
- ✅ **Build the app**
- ✅ **Upload to TestFlight**

**No Mac needed!** Everything runs in GitHub Actions.

---

## Quick Check Script

Run this anytime to check status:

```bash
cd /home/gurpreet/bbi-meta/mereka-lms
python3 scripts/mobile/check_apple_setup.py
```

---

## Next Steps

1. ✅ Create App in App Store Connect (manual, ~2 minutes)
2. ✅ Trigger GitHub Actions build
3. ✅ Wait ~45 minutes for build + processing
4. ✅ Install via TestFlight on iPhone

---

## Summary

**Ready to build**: Almost! Just need to create the App in App Store Connect (can't be done via API).

**Everything else**: ✅ Automated and ready!
