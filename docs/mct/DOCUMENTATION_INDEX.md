# MCT Export Documentation Index

**Quick reference guide to all MCT export documentation**

## 📚 Documentation Files

### Primary Documentation

1. **`docs/mct/EXPORT_GUIDE.md`** ⭐ **START HERE**
   - Complete guide for MCT export process
   - Authentication setup and credential management
   - API endpoints and data formats
   - Troubleshooting guide
   - Quick reference commands

2. **`docs/mct/MIGRATION_PLAN.md`**
   - Overall migration strategy
   - Phase-by-phase plan
   - Data entity mappings
   - Transformation approach

3. **`docs/mct/API_EXPLORATION.md`**
   - API version comparison (V1, V3, V4)
   - Endpoint discovery results
   - Data models identified
   - Authentication patterns

### Testing & Results

4. **`docs/mct/EXPORT_TEST_RESULTS.md`**
   - Initial test results
   - Authentication issues encountered
   - Resolution steps

5. **`docs/mct/EXPORT_SUCCESS.md`**
   - Final test results
   - Export statistics
   - Data quality verification

6. **`docs/mct/EXPORT_TESTING.md`**
   - Testing procedures
   - Step-by-step test checklist
   - Success criteria

### Reference Code

7. **`hubspot-webhook-mct/functions/index.js`**
   - Working authentication implementation
   - API usage patterns
   - Reference for credential format

8. **`tools/mct-export.mjs`**
   - Production export script
   - Handles CSV/JSON responses
   - Hierarchical data structures
   - Error handling and retries

---

## 🚀 Quick Start

### For New Agents

1. **Read:** `docs/mct/EXPORT_GUIDE.md` (complete guide)
2. **Check:** Credentials status (see Credential Management section)
3. **Test:** Run dry-run first: `node tools/mct-export.mjs --dry-run`
4. **Export:** Follow Quick Reference section in guide

### Common Tasks

**Refresh Expired Credentials:**
```bash
az ad app credential reset --id caa4dce3-e49c-4c09-9160-031d51bfd2a9 --append
```

**Test Export:**
```bash
MCT_BASE_URL=learn.skillourfuture.org \
MCT_API_URI=api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3 \
MCT_CLIENT_ID=caa4dce3-e49c-4c09-9160-031d51bfd2a9 \
MCT_CLIENT_SECRET='<secret>' \
MCT_TENANT_ID=b1aab053-6242-46ec-9cf8-bd02e63dd2da \
node tools/mct-export.mjs --resources organizations --start-page 1 --end-page 1
```

**Full Export:**
```bash
# Set environment variables, then:
node tools/mct-export.mjs
```

---

## 🔑 Key Information

### Credentials

- **App ID:** `caa4dce3-e49c-4c09-9160-031d51bfd2a9`
- **Tenant ID:** `b1aab053-6242-46ec-9cf8-bd02e63dd2da`
- **API URI:** `api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3`
- **Base URL:** `learn.skillourfuture.org`

### Important Notes

1. **Client secrets expire** - Refresh every 6-12 months using Azure CLI
2. **Reports endpoints return CSV** - Script handles this automatically
3. **Courses are hierarchical** - Categories contain courses (use `ProductId` for content)
4. **Users endpoint requires searchTerm** - Use Reports endpoint for bulk export

---

## 📊 Export Statistics

**Last Successful Export:**
- Organizations: 46 records
- Users: 68,784 records
- Categories: 1 hierarchical record
- Courses: 14 category records

**Output Location:** `exports/mct/`

---

## 🐛 Troubleshooting

See `docs/mct/EXPORT_GUIDE.md` → Troubleshooting section for:
- Authentication errors
- API errors
- Export issues
- CSV parsing problems

---

## 📝 Documentation Status

| Document | Status | Last Updated |
|----------|--------|--------------|
| EXPORT_GUIDE.md | ✅ Complete | 2025-11-07 |
| MIGRATION_PLAN.md | ✅ Complete | 2025-11-07 |
| API_EXPLORATION.md | ✅ Complete | 2025-11-07 |
| MCT_EXPORT_TEST_RESULTS.md | ✅ Complete | 2025-11-07 |
| MCT_EXPORT_SUCCESS.md | ✅ Complete | 2025-11-07 |

---

## 🔗 Related Documentation

- **Kajabi Migration:** `docs/KAJABI_MIGRATION_NOTES.md`
- **Local Setup:** `docs/LOCAL_SETUP.md`
- **Deployment:** `docs/DEPLOYMENT_RUNBOOK.md`
- **Branding:** `docs/BRANDING.md`

