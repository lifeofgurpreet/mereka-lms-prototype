# Complete MFE List & Status
_Last updated: 2025-11-12_

## ✅ Currently Configured MFEs (12)

All these MFEs are built and available in both local and production:

1. **authn** - Authentication/Login
   - URL: `/authn/login`
   - Purpose: User login, registration, password reset

2. **account** - Account Settings
   - URL: `/account`
   - Purpose: User account management, preferences

3. **profile** - User Profile
   - URL: `/profile`
   - Purpose: User profile viewing and editing

4. **learning** - Course Content
   - URL: `/learning`
   - Purpose: Course content viewing, navigation

5. **learner-dashboard** - Dashboard
   - URL: `/learner-dashboard`
   - Purpose: Student dashboard, course overview

6. **course-authoring** - Course Creation
   - URL: `/course-authoring`
   - Purpose: Course authoring tools (Studio integration)

7. **gradebook** - Grades
   - URL: `/gradebook`
   - Purpose: Gradebook for instructors

8. **discussions** - Forums
   - URL: `/discussions`
   - Purpose: Course discussions and forums

9. **communications** - Messages
   - URL: `/communications`
   - Purpose: User-to-user messaging

10. **orders** - Order History
    - URL: `/orders`
    - Purpose: Ecommerce order history

11. **payment** - Payment Processing
    - URL: `/payment`
    - Purpose: Payment forms and processing

12. **ora-grading** - ORA Grading
    - URL: `/ora-grading`
    - Purpose: Open Response Assessment grading

## 🔍 Potentially Missing MFEs

These MFEs exist in Open edX but may not be configured:

### Library MFE
- **Status:** Not currently configured
- **Purpose:** Course library browsing
- **Note:** May be integrated into Discovery service instead

### Credentials MFE
- **Status:** Not currently configured
- **Purpose:** Credentials/badges display
- **Note:** May be part of learner-dashboard or separate

## 📋 Verification

**Check available MFEs:**
```bash
# Local
docker exec tutor_local-mfe-1 ls -la /openedx/dist/ | grep "^d"

# Production (if accessible)
kubectl exec -n mereka-lms deploy/mfe -- ls -la /openedx/dist/ | grep "^d"
```

**Check MFE config:**
```bash
# Local
curl http://localhost/api/mfe_config/v1?mfe=authn | jq .

# Production
curl https://staging.academy.mereka.io/api/mfe_config/v1?mfe=authn | jq .
```

## 🎯 Recommendations

1. **Current MFEs are comprehensive** - All major user-facing MFEs are configured
2. **Library MFE** - Consider adding if course library browsing is needed
3. **Credentials MFE** - Consider adding if badges/credentials are a key feature
4. **Monitor Open edX updates** - New MFEs may be added in future releases

## 📚 References

- Open edX MFE Documentation: https://github.com/openedx/frontend-app-learning
- Tutor MFE Plugin: https://github.com/overhangio/tutor-mfe
- Current MFE List: Check `tutor_env/env/apps/caddy/Caddyfile` for routing

---

**Status:** All essential MFEs are configured ✅

