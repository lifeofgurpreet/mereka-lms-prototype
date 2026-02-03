# Developer Onboarding Guide
_One-Click Setup for New Developers • Last updated: 2025-11-12_

## 🚀 Quick Start (One Command)

```bash
./scripts/shared/setup-local.sh
```

That's it! The script will:
1. ✅ Check prerequisites (Docker, Python)
2. ✅ Create Python virtual environment
3. ✅ Install Tutor and dependencies
4. ✅ Configure Tutor for local development
5. ✅ Build Docker images (if needed)
6. ✅ Initialize database
7. ✅ Start all services
8. ✅ Configure multi-site (organizations, sites)
9. ✅ Create admin user
10. ✅ Verify everything works

**Time:** ~45-60 minutes (mostly waiting for image builds on first run)

## 📋 Prerequisites

Before running the setup script, ensure you have:

- **Docker Desktop** installed and running
  - macOS: Download from docker.com
  - Configure: Settings → Resources → Advanced
    - RAM: 12 GB minimum (16 GB recommended)
    - Swap: 2-4 GB
    - Disk: 100 GB+

- **Python 3.12+** installed
  - Check: `python3 --version`
  - macOS: Usually pre-installed, or `brew install python3`

- **Git** (for cloning the repo)
  - Usually pre-installed

- **At least 40 GB free disk space**

## 🎯 After Setup

### Verify Setup
```bash
./tools/verify-setup.sh
```

### Access Your Local Environment
- **LMS:** http://localhost
- **Studio:** http://studio.localhost
- **MFE Login:** http://apps.localhost/authn/login
- **Admin Panel:** http://localhost/admin

**Credentials:**
- Username: `admin`
- Password: `admin123`

### Run Tests
```bash
./tools/comprehensive-test.sh
```

## 🔄 Daily Workflow

### Start Your Day
```bash
cd /path/to/mereka.academy
source ops/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor local start -d
```

### Stop Services
```bash
tutor local stop
```

### After Config Changes
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate
tutor config save --set KEY=value
./infrastructure/tutor/apply-patches.sh
tutor local restart
```

## 🆘 Troubleshooting

### Setup Failed?

**Check prerequisites:**
```bash
docker --version
python3 --version
docker info | grep "Total Memory"
```

**Re-run setup:**
```bash
./scripts/shared/setup-local.sh
```

**Check logs:**
```bash
tutor local logs --tail=50 <service-name>
```

### Common Issues

**"Docker out of memory"**
- Increase Docker Desktop RAM to 16 GB
- Restart Docker Desktop

**"Can't connect to MySQL"**
```bash
./tools/fix-parity.sh
tutor local restart mysql
```

**"Too many login attempts"**
```bash
./tools/fix-admin-login.sh
```

**"Config has cloud IPs"**
```bash
./tools/fix-parity.sh
```

## 📚 Documentation

- **Quick Reference:** `docs/QUICK_REFERENCE.md`
- **Complete Guide:** `docs/LOCAL_DEVELOPMENT_GUIDE.md`
- **Setup Checklist:** `docs/AGENT_SETUP_CHECKLIST.md`
- **Operational Status:** `docs/OPERATIONAL_STATUS.md`

## 🔍 Verify Production Parity

To compare local with production:

```bash
# Sync production config (read-only)
./tools/sync-production-config.sh

# Analyze local data
./scripts/qa/analyze-local-data.sh

# Check parity
./scripts/qa/check-parity.sh
```

## 🎓 Learning Path

### Day 1: Setup
1. Run `./scripts/shared/setup-local.sh`
2. Verify with `./tools/verify-setup.sh`
3. Access LMS and explore

### Day 2: Development
1. Read `docs/LOCAL_DEVELOPMENT_GUIDE.md`
2. Bookmark `docs/QUICK_REFERENCE.md`
3. Start making changes

### Ongoing
1. Use `docs/QUICK_REFERENCE.md` for daily commands
2. Check `docs/OPERATIONAL_STATUS.md` for system status
3. Run `./tools/comprehensive-test.sh` before committing

## ✅ Success Checklist

After setup, you should be able to:
- [ ] Access http://localhost
- [ ] Access http://apps.localhost/authn/login
- [ ] Login with admin/admin123
- [ ] Access Studio at http://studio.localhost
- [ ] Run `./tools/verify-setup.sh` with all checks passing
- [ ] Run `./tools/comprehensive-test.sh` successfully

## 🚨 Important Notes

1. **Always work locally first** - Never touch production until local is verified
2. **Always set TUTOR_ROOT** - `export TUTOR_ROOT="$(pwd)/tutor_env"`
3. **Always run patches** - `./infrastructure/tutor/apply-patches.sh` after config changes
4. **Never commit secrets** - `tutor_env/config.yml` is git-ignored

## 📞 Getting Help

1. Check `docs/` directory for guides
2. Run `./tools/verify-setup.sh` to diagnose issues
3. Check logs: `tutor local logs --tail=50 <service>`
4. Review `docs/ops/TROUBLESHOOTING.md`

---

**Welcome to the team!** 🎉  
**Questions?** Check the documentation or ask the team.

