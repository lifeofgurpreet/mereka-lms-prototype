# Analytics Access Guide (Superseded)
_Audience: Everyone • Owner: Data/Analytics • Last updated: 2025-11-12 • Status: superseded_
superseded_by: docs/concepts/analytics/CURRENT_ANALYTICS_STATE.md

This document has moved to:
- `docs/concepts/analytics/CURRENT_ANALYTICS_STATE.md`

Open:
- `docs/concepts/analytics/CURRENT_ANALYTICS_STATE.md`

## 📊 Superset Analytics Dashboard

### Local Access

**URL:** http://localhost:8088

**Credentials:**
- **Username:** Check `tutor_env/config.yml` → `SUPERSET_ADMIN_USERNAME`
- **Password:** Check `tutor_env/config.yml` → `SUPERSET_ADMIN_PASSWORD`

**Quick Access:**
```bash
# Get credentials
grep SUPERSET_ADMIN tutor_env/config.yml

# Or access directly
open http://localhost:8088
```

### Production Access

**URL:** https://superset.academyv2.mereka.io (if configured)

**Note:** Superset may be behind authentication or VPN. Check with infrastructure team.

## 🔍 What You Can View

### Available Dashboards
- **User Analytics:** User registrations, activity, engagement
- **Course Analytics:** Course enrollments, completions, progress
- **Learning Analytics:** Learning paths, time spent, interactions
- **Revenue Analytics:** Ecommerce transactions, revenue (if configured)

### Data Sources
- **ClickHouse:** Event tracking, xAPI data
- **MySQL:** User data, enrollments, courses
- **MongoDB:** Forum discussions, comments

## 🛠️ Troubleshooting

### Cannot Access Superset

**Check if running:**
```bash
docker ps --filter "name=superset"
```

**Check logs:**
```bash
docker logs tutor_local-superset-1 --tail=50
```

**Restart if needed:**
```bash
tutor local restart superset
```

### Database Connection Issues

**Check ClickHouse connection:**
```bash
# Verify ClickHouse is running
docker ps --filter "name=clickhouse"

# Check config
grep ASPECTS_SUPERSET_DATABASE_HOST tutor_env/config.yml
# Should be: clickhouse (not a cloud IP)
```

**Fix if needed:**
```bash
./scripts/qa/fix-parity.sh
```

## 📈 Other Analytics Tools

### ClickHouse (Direct Access)
- **URL:** http://localhost:8123
- **Purpose:** Direct SQL queries on event data
- **Credentials:** Check `tutor_env/config.yml` → `CLICKHOUSE_ADMIN_USER/PASSWORD`

### Django Admin Analytics
- **URL:** http://localhost/admin
- **Purpose:** Basic user/course statistics
- **Access:** Admin login required

### Aspects Analytics
- **Integration:** Superset uses Aspects data
- **Data Source:** ClickHouse (xAPI events)
- **Access:** Via Superset dashboards

## 🎯 Quick Start

1. **Access Superset:**
   ```bash
   open http://localhost:8088
   ```

2. **Login with credentials from config:**
   ```bash
   grep SUPERSET_ADMIN tutor_env/config.yml
   ```

3. **Explore dashboards:**
   - Navigate to "Dashboards" menu
   - Select available dashboards
   - Customize as needed

## 📝 Notes

- **Local:** Superset connects to local ClickHouse
- **Production:** May connect to cloud ClickHouse (verify config)
- **Data:** Analytics data accumulates over time
- **Performance:** Large datasets may take time to load

---

**Status:** ✅ Superset accessible at http://localhost:8088  
**Database:** ✅ Connected to ClickHouse (local)
