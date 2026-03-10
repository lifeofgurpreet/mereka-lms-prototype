# Open edX Programs Quick Reference

**Status:** Planning Phase
**Date:** 2025-12-18
**Full Documentation:** [PROGRAMS_SETUP_PLAN.md](PROGRAMS_SETUP_PLAN.md)

---

## Quick Stats

- **Total Learning Pathways:** 13
- **Total Courses:** 69
- **Programs with Certificates:** 10 (77%)
- **Programs Requiring Sequential Order:** 3
- **Ready for Implementation:** 11
- **Requiring Investigation:** 2 (QA Testing pathways)

---

## Implementation Priority

| Priority | Program | Courses | Certificate | Type |
|----------|---------|---------|-------------|------|
| 1 | Become An Entrepreneur | 8 | Yes | Professional Certificate |
| 2 | Speak with Impact | 10 | Yes | Professional Certificate |
| 3 | Embark on a Green Jobs Journey | 7 | Yes | Professional Certificate |
| 4 | Developer | 8 | Yes | Professional Certificate |
| 5 | Data Analyst | 5 | Yes | Professional Certificate |
| 6 | Project Manager | 4 | Yes | Professional Certificate |
| 7 | Digital Marketer | 5 | Yes | Professional Certificate |
| 8 | Administrative Professional | 4 | Yes | Professional Certificate |
| 9 | Employability | 7 | No | XSeries |
| 10 | Mastering Digital Tools (Vietnam) | 9 | No | XSeries |

---

## Key Files

1. **Setup Plan:** `/docs/reference/migrations/mct/PROGRAMS_SETUP_PLAN.md` (52 KB)
   - Complete implementation guide
   - Step-by-step instructions
   - API examples
   - Troubleshooting guide

2. **Mapping Data:** `/var/migrations/mct/programs_mapping.json` (38 KB)
   - Structured program definitions
   - Course mappings
   - Configuration metadata

3. **Original Notes:** `/docs/reference/migrations/mct/OPENEDX_PROGRAMS_SETUP.md`
   - Initial research and setup notes

---

## Required Services

| Service | Purpose | Status Check |
|---------|---------|--------------|
| Discovery | Program catalog & management | `kubectl get pods -n mereka-lms \| grep discovery` |
| Credentials | Certificate issuance | `kubectl get pods -n mereka-lms \| grep credentials` |

**Enable if not running:**
```bash
tutor plugins enable discovery credentials
tutor config save
./infrastructure/tutor/apply-patches.sh
tutor k8s launch
```

---

## Quick Start (When Ready to Implement)

### 1. Verify Services
```bash
# Check Discovery
kubectl get pods -n mereka-lms | grep discovery
curl -I https://discovery.academyv2.mereka.io/health/

# Check Credentials
kubectl get pods -n mereka-lms | grep credentials
curl -I https://credentials.academyv2.mereka.io/health/
```

### 2. Access Admin Interfaces
- **Discovery Admin:** https://discovery.academyv2.mereka.io/admin/
- **Credentials Admin:** https://credentials.academyv2.mereka.io/admin/
- **LMS Admin:** https://academyv2.mereka.io/admin/

For Discovery/Credentials admin access:
- Log in via SSO first: `https://<service>.academyv2.mereka.io/login/` (redirects to `/login/edx-oauth2/`)
- Then open `/admin/`

If you get a 403 in admin, ensure your account is a platform admin:
```bash
./scripts/infra/ensure-platform-admins.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
```

### 3. Create First Program (Manual)
1. Go to Discovery Admin → Course Metadata → Programs → Add
2. Fill in:
   - Title: "Become An Entrepreneur"
   - Type: Professional Certificate
   - Status: Active
   - Marketing Slug: become-entrepreneur
   - Partner: SKILLOURFUTURE
3. Add 8 courses in sequence (see mapping JSON)
4. Enable certificate
5. Save

### 4. Sync to LMS
```bash
kubectl exec -it -n mereka-lms <lms-pod> -- bash
./manage.py lms refresh_course_metadata
```

### 5. Verify Frontend
Navigate to: https://academyv2.mereka.io/programs

---

## Programs with Sequential Requirements

These require courses to be completed in order:

1. **Become An Entrepreneur** (8 modules)
2. **Speak with Impact** (10 modules)
3. **Embark on a Green Jobs Journey** (7 modules)

Set "Order Matters" = True in program configuration.

---

## Programs Needing Investigation

### QA Testing Pathways (LP 19, 20)
- **Issue:** No courses mapped via categories
- **Action Required:**
  1. Check MCT for course associations
  2. Verify if pathways are active
  3. Determine if courses need different matching logic
  4. Check if Indonesia (LP 19) and Common (LP 20) share courses

---

## Timeline Estimate

| Phase | Duration | Key Milestone |
|-------|----------|---------------|
| Service Verification | 1 week | Discovery & Credentials running |
| Course Verification | 1 week | Course mapping validated |
| Program Creation | 2 weeks | All 11 programs created |
| Certificate Configuration | 1 week | Templates configured |
| LMS Integration | 1 week | Programs visible in LMS |
| Testing | 1 week | End-to-end verification |
| **TOTAL** | **7 weeks** | Production-ready |

**Fast Track (Top 3 Priority):** 3-4 weeks

---

## Common Issues & Quick Fixes

### Programs Not Showing
```bash
# Sync programs
kubectl exec -it -n mereka-lms <lms-pod> -- bash
./manage.py lms refresh_course_metadata

# Enable in site config
# LMS Admin → Site Configuration → Add:
# {"ENABLE_PROGRAMS": true, "ENABLE_PROGRAM_CERTIFICATES": true}
```

### Certificates Not Generating
```bash
# Manual generation
kubectl exec -it -n mereka-lms <credentials-pod> -- bash
./manage.py generate_program_certificates --dry-run
./manage.py generate_program_certificates
```

---

## API Access

### Get JWT Token
```python
# See ./PROGRAMS_SETUP_PLAN.md for complete authentication code
token = get_jwt_token(
    "https://academyv2.mereka.io",
    "admin@example.com",
    "password"
)
```

### List Programs
```bash
curl https://discovery.academyv2.mereka.io/api/v1/programs/ \
  -H "Authorization: JWT <token>"
```

---

## Resources

- [Setup Discovery Sandbox - Open edX Wiki](https://openedx.atlassian.net/wiki/spaces/SUST/pages/956039272/Setup+Discovery+Sandbox)
- [Discovery Service Documentation](https://edx-discovery.readthedocs.io/)
- [Credentials Service Documentation](https://credentials.readthedocs.io/)
- [Enabling Programs Discussion](https://discuss.openedx.org/t/enabling-programs-in-open-edx/7167)
- [Course Discovery GitHub](https://github.com/openedx/course-discovery)
- [Credentials GitHub](https://github.com/openedx/credentials)

---

## Next Steps

1. Review full setup plan: `docs/reference/migrations/mct/PROGRAMS_SETUP_PLAN.md`
2. Verify Discovery and Credentials services are running
3. Update course mapping JSON with actual Open edX course keys
4. Begin implementation with Priority 1 program
5. Test end-to-end with test user account
6. Roll out remaining programs in priority order

---

**For Questions:** See full documentation in `docs/reference/migrations/mct/PROGRAMS_SETUP_PLAN.md`
