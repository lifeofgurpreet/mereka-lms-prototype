# One-Click Setup Guide
_For New Developers • Start Here_

## 🚀 Quick Start

```bash
# Clone the repository
git clone <repository-url> mereka.academy
cd mereka.academy

# Run one-click setup
./scripts/shared/setup-local.sh
```

**That's it!** The script handles everything automatically.

## ⏱️ What to Expect

**First Run:** 45-60 minutes
- Most time is spent building Docker images (one-time)
- You can grab coffee ☕ while it builds

**Subsequent Runs:** < 5 minutes
- Images are cached, so it's much faster

## ✅ After Setup

**Access your local environment:**
- LMS: http://localhost
- Login: admin / admin123
- MFE: http://apps.localhost/authn/login

**Verify everything works:**
```bash
./tools/verify-setup.sh
```

## 📚 Next Steps

- Read: `docs/DEVELOPER_ONBOARDING.md`
- Reference: `docs/QUICK_REFERENCE.md`
- Status: `docs/OPERATIONAL_STATUS.md`

## 🆘 Need Help?

Run: `./tools/verify-setup.sh` to diagnose issues

---

**Ready to start?** Run `./scripts/shared/setup-local.sh` now! 🎉

