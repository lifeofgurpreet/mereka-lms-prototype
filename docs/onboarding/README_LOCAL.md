# Local Development Documentation Index
_Quick reference for coding agents and developers_

## 🚀 Getting Started

**New to the project?** Start here:
1. **Quick Start:** [`QUICK_START_LOCAL.md`](QUICK_START_LOCAL.md) - 5-minute setup guide
2. **Complete Guide:** [`LOCAL_DEVELOPMENT_GUIDE.md`](LOCAL_DEVELOPMENT_GUIDE.md) - Full instructions with troubleshooting
3. **Daily Workflow:** [`quickstart/WORKFLOW_LOCAL.md`](quickstart/WORKFLOW_LOCAL.md) - Day-to-day commands

## 📚 Documentation Files

### Setup & Configuration
- **`LOCAL_DEVELOPMENT_GUIDE.md`** - Complete setup guide (NEW - comprehensive)
- **`QUICK_START_LOCAL.md`** - Fast setup for new machines (NEW - 5 min guide)
- **`quickstart/LOCAL_SETUP.md`** - Original detailed setup instructions
- **`quickstart/WORKFLOW_LOCAL.md`** - Daily workflow cheat sheet

### Reference
- **`LOCAL_ACCESS_INFO.md`** - Access URLs and credentials
- **`LOCAL_WORK_REMAINING.md`** - Current local development tasks
- **`MFE_LOGIN_FIX.md`** - MFE authentication troubleshooting
- **`MFE_REBUILD_SUCCESS.md`** - MFE rebuild documentation

### Agent Guidelines
- **`AGENTS.md`** - Repository guidelines (updated with local dev priority)
- **`../ops/TROUBLESHOOTING.md`** - General troubleshooting guide

## 🎯 Key Principles

1. **Always work locally first** - Never touch cloud instances until local is verified
2. **Always set `TUTOR_ROOT`** - `export TUTOR_ROOT="$(pwd)/tutor_env"`
3. **Always use local Docker services** - `mysql`, `mongodb`, `redis` (NOT cloud IPs)
4. **Always run patches** - `./infrastructure/tutor/apply-patches.sh` after config changes

## 🔍 Quick Verification

```bash
# Check config is local
grep -E "MYSQL_HOST|MONGODB_HOST" tutor_env/config.yml
# Should show: mysql, mongodb (NOT 10.97.0.2)

# Check containers
docker ps --filter "name=tutor_local" | wc -l
# Should show: 24

# Test services
curl -I http://localhost
curl -I http://apps.localhost/authn/login
```

## 🆘 Need Help?

1. Check `LOCAL_DEVELOPMENT_GUIDE.md` → "Common Issues & Fixes"
2. Check `quickstart/WORKFLOW_LOCAL.md` → "Troubleshooting Highlights"
3. Check logs: `tutor local logs --tail=50 <service>`
4. Verify config: `grep MYSQL_HOST tutor_env/config.yml`

---

**Last Updated:** 2025-11-12  
**Status:** All documentation updated for local-first development

