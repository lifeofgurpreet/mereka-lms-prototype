# Local Development Access Information
_Audience: Developers • Owner: Ops Domain Owner • Last verified: 2026-03-06 • Status: supporting_

## 🔐 Admin Credentials

**Username:** `admin`
**Password:** `admin123`
**Email:** `admin@mereka.academy`
**Access Level:** Staff + Superuser

## 🌐 Local URLs

### Main Services
- **LMS (Learning Management System):** http://localhost
- **Studio (Course Authoring):** http://studio.localhost
- **MFEs (Micro-Frontends):** http://apps.localhost
- **Admin Panel:** http://localhost/admin

### Micro-Frontends (MFEs)
- **Login/Auth:** http://apps.localhost/authn/login
- **Account:** http://apps.localhost/account
- **Profile:** http://apps.localhost/profile
- **Learning Dashboard:** http://apps.localhost/learner-dashboard
- **Learning:** http://apps.localhost/learning
- **Course Authoring:** http://apps.localhost/course-authoring
- **Gradebook:** http://apps.localhost/gradebook
- **Discussions:** http://apps.localhost/discussions
- **Communications:** http://apps.localhost/communications
- **Orders:** http://apps.localhost/orders
- **Payment:** http://apps.localhost/payment
- **ORA Grading:** http://apps.localhost/ora-grading

### Other Services
- **Discovery:** http://discovery.localhost
- **Ecommerce:** http://ecommerce.localhost
  > **Note**: Legacy Oscar ecommerce, being replaced by Purchase Gateway. See `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md`.
- **Notes API:** http://notes.localhost (API only)
- **XQueue:** http://xqueue.localhost
- **Superset (Analytics):** http://superset.localhost
- **Forum:** Integrated into LMS courses

## 🧪 Testing Checklist

### ✅ Completed
- [x] Admin user created
- [x] MySQL fixed and running
- [x] All containers running (23/24)
- [x] LMS accessible
- [x] Studio accessible
- [x] MFEs accessible (12 MFEs configured)
- [x] MFE Config API working

### 🔄 Next Steps
- [ ] Login to admin panel: http://localhost/admin
- [ ] Create test course in Studio: http://studio.localhost
- [ ] Enroll in test course in LMS: http://localhost
- [ ] Test forum discussions
- [ ] Verify branding on all pages
- [ ] Test all MFE pages

## 📝 Notes

- All services use local Docker containers (`mysql`, `mongodb`, `redis`)
- Config is stored in `tutor_env/config.yml` (git-ignored)
- To restart services: `tutor local restart`
- To view logs: `tutor local logs --tail=50 <service>`
- To check parity: `./scripts/qa/check-parity.sh`

## 🔗 Related Documentation

- **Complete URL Reference:** `docs/ops/quickref/access-urls.md` (local, dev, production)
- **Parity Strategy:** [LOCAL_PRODUCTION_PARITY.md](local-production-parity.md)
- **MFE List:** [MFE_COMPLETE_LIST.md](../../concepts/architecture/MFE_COMPLETE_LIST.md)
- **Setup Guide:** [LOCAL_DEVELOPMENT_GUIDE.md](../../guides/onboarding/LOCAL_DEVELOPMENT_GUIDE.md)
