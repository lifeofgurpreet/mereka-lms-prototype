# Aspects Analytics - Access Guide
_Audience: Platform Eng • Owner: Data/Analytics • Last verified: 2025-07-25_

Aspects Analytics is now installed and running! Here's how to access it.

## Services Status

✅ **Aspects Services Running:**
- `clickhouse` - Data warehouse (port 8123, 9006)
- `superset` - Visualization dashboard (port 8088)
- `superset-worker` - Background worker
- `superset-worker-beat` - Scheduled tasks worker

## Accessing Superset Dashboard

### URL
- **Local**: http://localhost:8088
- **Direct**: http://aspects-superset.localhost (if configured)

### Default Credentials

**Username**: `admin`  
**Password**: `admin` (or check with `tutor local do printroot`)

To reset password:
```bash
source .venv/bin/activate
export TUTOR_ROOT="$(pwd)/tutor_env"
export OPENEDX_RELEASE="nightly"
tutor local exec superset bash -c "superset fab reset-password --username admin --password YOUR_NEW_PASSWORD"
```

## Accessing Analytics from LMS

### Instructor Dashboard Integration

1. **Log into LMS**: http://localhost
2. **Navigate to any course**
3. **Click "Instructor"** in the top navigation
4. **Look for "Reports" link** - This is added by Aspects
5. **Click "Reports"** to access course analytics

### Direct Superset Access

1. Go to http://localhost:8088
2. Log in with credentials above
3. Navigate to **Dashboards** menu
4. Access platform-wide or course-specific dashboards

## What You Can See

### Platform-Wide Analytics

Once data starts collecting (may take a few minutes), you'll see:

- **Total Enrollments** across all courses
- **Completion Rates** by course
- **Certificates Issued** platform-wide
- **Enrollment Trends** over time
- **Course Performance** metrics
- **Learner Engagement** statistics

### Course-Specific Analytics

- Enrollment count per course
- Completion rates
- Learner progress
- At-risk learners
- Problem-level analytics

## Data Collection

Aspects automatically starts collecting data once services are running. Data may take a few minutes to appear:

1. **Events are captured** from OpenEdX LMS
2. **Processed by Ralph** (event routing service)
3. **Stored in ClickHouse** (data warehouse)
4. **Visualized in Superset** (dashboards)

## Troubleshooting

### Can't Access Superset

1. **Check service is running**:
   ```bash
   tutor local dc ps | grep superset
   ```

2. **Check logs**:
   ```bash
   tutor local logs superset --tail=50
   ```

3. **Restart if needed**:
   ```bash
   tutor local restart superset
   ```

### No Data Showing

- **Wait a few minutes** - Data collection starts automatically
- **Generate some activity** - Enroll in a course, complete content
- **Check ClickHouse** - Verify data is being stored:
  ```bash
  tutor local exec clickhouse clickhouse-client --query "SHOW TABLES"
  ```

### Reset Superset Admin Password

```bash
source .venv/bin/activate
export TUTOR_ROOT="$(pwd)/tutor_env"
export OPENEDX_RELEASE="nightly"
tutor local exec superset bash -c "superset fab reset-password --username admin --password YOUR_PASSWORD"
```

## Next Steps

1. ✅ **Access Superset** at http://localhost:8088
2. ✅ **Log in** with admin credentials
3. ✅ **Explore dashboards** (may need to wait for data)
4. ✅ **Access from LMS** via Instructor Dashboard → Reports
5. ✅ **Create custom dashboards** as needed

## Useful Commands

```bash
# Check Aspects services status
tutor local dc ps | grep -E "(aspects|superset|clickhouse)"

# View Superset logs
tutor local logs superset --tail=50

# View ClickHouse logs
tutor local logs clickhouse --tail=50

# Restart Aspects services
tutor local restart superset clickhouse

# Access ClickHouse directly
tutor local exec clickhouse clickhouse-client
```

## Documentation

- **Full Guide**: `docs/ASPECTS_ANALYTICS.md`
- **Installation**: `docs/ASPECTS_INSTALLATION.md`
- **Comparison**: `docs/ASPECTS_VS_PANORAMA.md`

