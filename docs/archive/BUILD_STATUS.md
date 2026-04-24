# iOS App Build Status

**Status**: ✅ **SUCCESSFULLY DEPLOYED TO TESTFLIGHT**  
**First Successful Build**: Run #21274409453  
**Last Updated**: 2026-01-23

---

## Current State

| Item | Status |
|------|--------|
| CI/CD Pipeline | ✅ Working |
| TestFlight Upload | ✅ Complete |
| Certificate Management | ✅ via fastlane match |
| Provisioning Profiles | ✅ Stored in ios-certificates repo |

---

## Documentation

| Document | Purpose |
|----------|---------|
| `docs/ios-cicd-spec.md` | Complete CI/CD specification |
| `docs/IOS_DEPLOYMENT_LEARNINGS.md` | Post-mortem and lessons learned |
| `AGENTS.md` | Rules for AI agents |

---

## Triggering New Builds

### Automatic Triggers
- Push to `mobile/ios/**` on main branch
- Push to `.github/workflows/build-ios-app.yml`

### Manual Trigger
1. Go to: https://github.com/Biji-Biji-Initiative/mereka-lms/actions
2. Click **Build iOS App**
3. Click **Run workflow** → **Run workflow**

### CLI Trigger
```bash
gh workflow run "Build iOS App" --repo Biji-Biji-Initiative/mereka-lms
```

---

## Monitoring

### Watch Build Progress
```bash
gh run list --workflow="Build iOS App" --repo Biji-Biji-Initiative/mereka-lms --limit 5
gh run watch <RUN_ID> --repo Biji-Biji-Initiative/mereka-lms
```

### Check Failed Build Logs
```bash
gh run view <RUN_ID> --repo Biji-Biji-Initiative/mereka-lms --log-failed
```

---

## After Build Completes

1. Go to: https://appstoreconnect.apple.com → Mereka Academy → TestFlight
2. Click the build → **Manage Missing Compliance** → "None of the above"
3. Add Internal Testers if needed
4. Install via TestFlight app on iPhone

---

## Quick Reference

| Property | Value |
|----------|-------|
| Bundle ID | `com.mereka.academy.mobile` |
| App Name | Mereka Academy |
| Scheme | OpenEdXProd |
| Xcode | 16.4 |
| Fastlane | >= 2.230.0 |
| Certificates Repo | ios-certificates |
