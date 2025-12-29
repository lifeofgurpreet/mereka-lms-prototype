# Aspects Analytics - Quick Start Guide
_Audience: Platform Eng • Owner: Data/Analytics • Last verified: 2025-07-25_

✅ **Aspects Analytics is installed and running!**

## Access Superset Dashboard

**URL**: http://localhost:8088

**Default Credentials**:
- Username: `admin`
- Password: `admin` (or check with `tutor local do printroot`)

## What's Running

All Aspects services are up:
- ✅ **ClickHouse** - Data warehouse (ports 8123, 9006)
- ✅ **Superset** - Analytics dashboard (port 8088)
- ✅ **Superset Workers** - Background processing

## Access Analytics

### Option 1: Direct Superset Access

1. Open http://localhost:8088
2. Log in with admin credentials
3. Navigate to **Dashboards** menu
4. View platform-wide analytics

### Option 2: From LMS Instructor Dashboard

1. Log into LMS: http://localhost
2. Go to any course
3. Click **"Instructor"** in navigation
4. Look for **"Reports"** link (added by Aspects)
5. Click to access course analytics

## What You'll See

Once data starts collecting (may take a few minutes):

- **Platform Overview**: All courses, enrollments, completions
- **Course Dashboards**: Per-course analytics
- **Enrollment Trends**: Over time
- **Completion Rates**: By course
- **Certificates Issued**: Platform-wide
- **At-Risk Learners**: Identified automatically

## Troubleshooting

### Superset Not Loading

If you see database errors, the database was just created. Wait 30 seconds and refresh.

### No Data Showing

- Data collection starts automatically
- Generate some activity (enroll in a course, view content)
- Wait a few minutes for data to appear

### Reset Password

```bash
source .venv/bin/activate
export TUTOR_ROOT="$(pwd)/tutor_env"
export OPENEDX_RELEASE="nightly"
tutor local exec superset bash -c "superset fab reset-password --username admin --password YOUR_PASSWORD"
```

## Next Steps

1. ✅ **Access Superset** at http://localhost:8088
2. ✅ **Explore dashboards** (may need to wait for data)
3. ✅ **Access from LMS** via Instructor Dashboard → Reports
4. ✅ **Create custom reports** as needed

## Documentation

- **Access Guide**: `docs/ASPECTS_ACCESS.md`
- **Full Guide**: `docs/ASPECTS_ANALYTICS.md`
- **Installation**: `docs/ASPECTS_INSTALLATION.md`

---

**You now have platform-wide analytics!** 🎉

