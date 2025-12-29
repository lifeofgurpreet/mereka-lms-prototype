# Documentation Index for Local Development
_Last updated: 2025-11-12_

## 🎯 Start Here

**New to the project?** Follow this order:

1. **`AGENT_SETUP_CHECKLIST.md`** - Step-by-step setup checklist
2. **`QUICK_START_LOCAL.md`** - Fast 5-minute setup guide  
3. **`LOCAL_DEVELOPMENT_GUIDE.md`** - Complete guide with troubleshooting

## 📚 Documentation Files

### Setup Guides (Read in Order)
1. **`AGENT_SETUP_CHECKLIST.md`** ⭐ - Step-by-step checklist for new machines
2. **`QUICK_START_LOCAL.md`** ⭐ - Fast setup (copy-paste ready)
3. **`LOCAL_DEVELOPMENT_GUIDE.md`** ⭐ - Complete guide (everything you need)
4. **`onboarding/LOCAL_SETUP.md`** - Original detailed setup
5. **`onboarding/WORKFLOW_LOCAL.md`** - Daily workflow commands

### Reference Documents
- **`LOCAL_ACCESS_INFO.md`** - URLs, credentials, access info
- **`README_LOCAL.md`** - Documentation index (this file's companion)
- **`AGENTS.md`** - Repository guidelines (updated with local dev priority)

### Troubleshooting
- **`MFE_LOGIN_FIX.md`** - MFE authentication issues
- **`MFE_REBUILD_SUCCESS.md`** - MFE rebuild documentation
- **`LOCAL_WORK_REMAINING.md`** - Current local tasks
- **`operations/TROUBLESHOOTING.md`** - General troubleshooting

## 🔑 Key Documents for Agents

**Must Read:**
1. `AGENT_SETUP_CHECKLIST.md` - Setup process
2. `LOCAL_DEVELOPMENT_GUIDE.md` - Complete reference
3. `AGENTS.md` - Coding guidelines

**Quick Reference:**
- `QUICK_START_LOCAL.md` - Daily commands
- `LOCAL_ACCESS_INFO.md` - URLs and credentials

## 🎓 Learning Path

**Day 1: Setup**
- Read `AGENT_SETUP_CHECKLIST.md`
- Follow `QUICK_START_LOCAL.md`
- Verify with checklist

**Day 2: Daily Work**
- Read `LOCAL_DEVELOPMENT_GUIDE.md` → "Daily Workflow"
- Bookmark `QUICK_START_LOCAL.md` → "Daily Commands"
- Review `AGENTS.md` → "Local Development Priority"

**Ongoing:**
- Reference `LOCAL_DEVELOPMENT_GUIDE.md` → "Common Issues"
- Check `quickstart/WORKFLOW_LOCAL.md` for commands

## 📝 Quick Commands Reference

```bash
# Setup (first time)
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save --set MYSQL_HOST=mysql --set MONGODB_HOST=mongodb
./infrastructure/tutor/apply-patches.sh
tutor local start -d

# Daily use
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor local start -d    # Start
tutor local stop        # Stop

# After config changes
tutor config save --set KEY=value
./infrastructure/tutor/apply-patches.sh  # CRITICAL!
tutor local restart
```

## ✅ Verification

```bash
# Check config is local
grep MYSQL_HOST tutor_env/config.yml  # Should be "mysql"

# Check containers
docker ps --filter "name=tutor_local" | wc -l  # Should be 24

# Test services
curl -I http://localhost
curl -I http://apps.localhost/authn/login
```

---

**All documentation updated:** 2025-11-13  
**Status:** Ready for new machine setup ✅

