# Tutor Configuration Runbook
_Audience: Platform Eng • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers manual verification procedures for Tutor configuration that require a running Docker Compose or Kubernetes environment.

> **Spec**: `specs/tutor-configuration_spec.md` and `specs/tutor-configuration-resilience_spec.md`
> **Testmaps**: `specs/testmaps/tutor-configuration_spec.testmap.yml`, `specs/testmaps/tutor-configuration-resilience_spec.testmap.yml`

## Prerequisites

- `TUTOR_ROOT` set to `$(pwd)/tutor_env`
- Docker Compose running (`tutor local start`)
- Access to Tutor CLI

---

## MFE Build Verification

### Procedure
1. Verify MFE Dockerfile includes Node 18 build toolchain:
   ```bash
   grep -E "g\+\+|python3|build-essential" tutor_env/env/plugins/mfe/build/mfe/Dockerfile
   ```
2. Build MFE image and verify it completes:
   ```bash
   tutor images build mfe
   ```
3. Verify MFE containers start and serve content:
   ```bash
   curl -I http://apps.localhost/authn/login
   ```

### Acceptance
- MFE Dockerfile contains Node 18 build dependencies
- Image build completes without OOM or dependency errors
- MFE login page loads in browser

---

## MySQL Authentication Verification

### Procedure
1. Verify MySQL uses `mysql_native_password` authentication plugin:
   ```bash
   tutor local exec mysql mysql -u root -e "SELECT user, plugin FROM mysql.user WHERE user='openedx';"
   ```
2. Verify LMS can connect to MySQL:
   ```bash
   tutor local exec lms python -c "from django.db import connection; connection.ensure_connection(); print('MySQL OK')"
   ```

### Acceptance
- MySQL user `openedx` uses `mysql_native_password` plugin
- LMS Django process connects to MySQL without authentication errors
- No `caching_sha2_password` related errors in logs

---

## Visual Branding Verification

### Procedure
1. Open LMS in browser: `http://localhost`
2. Verify Mereka Academy logo appears in header
3. Verify footer contains Mereka branding
4. Navigate to login page and verify brand colors
5. Check Studio: `http://studio.localhost`

### Acceptance
- Mereka logo visible on LMS homepage
- Footer branding matches design specifications
- Login page uses correct gradient and logo placement
- Studio header shows correct branding

---

## Service Health Verification

### Procedure
1. Check all Tutor services are running:
   ```bash
   tutor local dc ps
   ```
2. Verify key services respond:
   ```bash
   curl -I http://localhost          # LMS
   curl -I http://studio.localhost   # Studio
   curl -I http://apps.localhost     # MFE
   ```
3. Check logs for errors:
   ```bash
   tutor local logs --tail=20 lms
   tutor local logs --tail=20 cms
   tutor local logs --tail=20 mfe
   ```

### Acceptance
- All containers show `Up` status
- LMS, Studio, and MFE respond with 200 status
- No ERROR-level messages in recent logs

---

## Full Configuration Apply

### Procedure
1. Run the safe config workflow:
   ```bash
   export TUTOR_ROOT="$(pwd)/tutor_env"
   ./scripts/infra/tutor-config-save.sh
   ```
2. Verify patches were applied:
   ```bash
   ./scripts/infra/verify-tutor-config.sh
   ```
3. Restart services:
   ```bash
   tutor local restart
   ```
4. Verify all services come back healthy (Service Health Verification above)

### Acceptance
- `tutor-config-save.sh` completes without errors
- `verify-tutor-config.sh` reports all patches present
- All services restart and pass health checks
- No configuration drift from expected state
