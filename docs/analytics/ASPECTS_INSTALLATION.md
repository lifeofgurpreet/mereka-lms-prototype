# Aspects Analytics Installation - Step by Step
_Audience: Platform Eng • Owner: Data/Analytics • Last verified: 2025-07-25_

This document tracks the installation of Aspects Analytics for platform-wide analytics.

## Installation Status

✅ **Step 1: Plugin Installed**
- `tutor-contrib-aspects` package installed
- Plugin enabled in Tutor configuration

✅ **Step 2: Configuration Updated**
- Aspects added to `PLUGINS` list in `infrastructure/tutor/config.example.yml`
- Configuration saved to `tutor_env/config.yml`
- Patches applied

⏳ **Step 3: Docker Images (Pending)**
- Need to build Aspects Docker images
- This step requires Docker to be running

⏳ **Step 4: Initialize Services (Pending)**
- Initialize Aspects services
- Start all services

## Next Steps to Complete Installation

### For Local Development

```bash
# 1. Activate environment
source .venv/bin/activate
export TUTOR_ROOT="$(pwd)/tutor_env"
export OPENEDX_RELEASE="nightly"

# 2. Build Docker images (this will take 10-30 minutes)
tutor images build openedx --no-cache
tutor images build aspects aspects-superset

# 3. Initialize Aspects services
tutor local do init

# 4. Start all services
tutor local start -d

# 5. Verify installation
tutor local dc ps | grep aspects
```

### For Kubernetes/Staging

```bash
# 1. Activate environment
source .venv/bin/activate
export TUTOR_ROOT="$(pwd)/tutor_env"
export OPENEDX_RELEASE="nightly"

# 2. Build and push images
tutor images build openedx aspects aspects-superset
tutor images push all --repository asia-southeast1-docker.pkg.dev/mereka-lms/openedx

# 3. Generate Kubernetes config
tutor k8s quickstart

# 4. Deploy
tutor k8s init
tutor k8s start

# 5. Verify
kubectl get pods -n mereka-lms | grep aspects
```

## What Was Installed

### Plugin Package
- **Package**: `tutor-contrib-aspects` (version 2.5.0)
- **Location**: Installed in `.venv`
- **Status**: ✅ Installed and enabled

### Configuration Changes
- Added `aspects` to `PLUGINS` list in `infrastructure/tutor/config.example.yml`
- Aspects configuration auto-generated in `tutor_env/config.yml`
- Patches applied successfully

### Services That Will Be Created

Once images are built and services started, you'll have:

1. **aspects-clickhouse** - Data warehouse for storing learning events
2. **aspects-superset** - Visualization dashboard (Apache Superset)
3. **aspects-event-routing** - Event processing service

## Accessing Aspects After Installation

### Superset Dashboard
- **Local**: `http://aspects-superset.localhost`
- **Staging**: `https://aspects-superset.academyv2.mereka.io` (if configured)

**Default credentials**:
- Username: `admin`
- Password: Check with `tutor local do printroot` or reset with `tutor local do init`

### From LMS
- Navigate to any course → Instructor Dashboard
- Look for **"Reports"** link (added by Aspects)
- Access course-level or platform-wide dashboards

### Single Sign-On
- LMS users can access Superset using their LMS credentials
- SSO configured automatically

## Verification Checklist

After completing installation, verify:

- [ ] Aspects services are running (`tutor local dc ps | grep aspects`)
- [ ] Can access Superset dashboard
- [ ] "Reports" link appears in Instructor Dashboard
- [ ] Can view platform-wide analytics
- [ ] Data is being collected (may take a few minutes after first start)

## Troubleshooting

### Services Not Starting
```bash
# Check logs
tutor local logs aspects-clickhouse --tail=50
tutor local logs aspects-superset --tail=50

# Restart services
tutor local restart aspects-clickhouse aspects-superset
```

### Can't Access Superset
1. Check service is running: `tutor local dc ps | grep superset`
2. Check URL: Verify hostname configuration
3. Reset credentials: `tutor local do init`

### No Data Showing
- Data collection starts automatically
- May take a few minutes for first data to appear
- Ensure OpenEdX LMS is generating events

## Documentation

- **Full Guide**: See `docs/ASPECTS_ANALYTICS.md`
- **Main Analytics Guide**: See `docs/OPENEDX_ANALYTICS.md`
- **Official Docs**: https://docs.openedx.org/projects/openedx-aspects/

## Notes

- Building Docker images can take 10-30 minutes depending on your system
- Ensure Docker Desktop has sufficient resources (12GB+ RAM recommended)
- Aspects will start collecting data automatically once services are running
- Platform-wide analytics will be available immediately after data collection starts

