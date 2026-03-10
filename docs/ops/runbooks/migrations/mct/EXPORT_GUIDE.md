# MCT Export Documentation
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2026-03-10_

**Complete guide for exporting data from Microsoft Community Training (MCT) platform**

## Table of Contents

1. [Overview](#overview)
2. [Authentication Setup](#authentication-setup)
3. [Export Script Usage](#export-script-usage)
4. [API Endpoints & Data Formats](#api-endpoints--data-formats)
5. [Data Structure Notes](#data-structure-notes)
6. [Troubleshooting](#troubleshooting)
7. [Credential Management](#credential-management)

---

## Overview

The MCT export script (`scripts/migrations/mct/mct-export.mjs`) exports data from Microsoft Community Training platform to NDJSON files for transformation and import into Open edX.

**Key Features:**
- Service-to-service authentication via Azure AD
- Automatic CSV/JSON response handling
- Hierarchical data structure support
- Pagination and rate limiting
- Dry-run mode for testing
- Comprehensive error handling

**Exported Resources:**
- Organizations (46 records)
- Users (68,784+ records)
- Categories (hierarchical structure)
- Courses (with content details)
- Enrollments
- Reports

---

## Authentication Setup

### Prerequisites

1. **Azure CLI** - Must be installed and authenticated
   ```bash
   az --version  # Verify installation
   az account show  # Verify authentication
   ```

2. **Azure AD App Registration** - Service principal with MCT API permissions
   - Retrieve the app ID, tenant ID, and API URI from the team-managed secret/config source before running the export.

### Credential Refresh (IMPORTANT)

**Client secrets expire after 6-12 months.** When authentication fails with `AADSTS7000222`, refresh the secret:

```bash
# List current credentials (to see expiration)
az ad app credential list --id <mct-app-id>

# Create new client secret
az ad app credential reset --id <mct-app-id> --append

# Output will show:
# {
#   "appId": "<mct-app-id>",
#   "password": "NEW_SECRET_HERE",
#   "tenant": "<mct-tenant-id>"
# }
```

**⚠️ Security Note:** The `--append` flag keeps old secrets active. Use without `--append` to revoke old secrets immediately (only if you're sure nothing else is using them).

### Environment Variables

```bash
# Required
MCT_BASE_URL=learn.skillourfuture.org  # Domain only (no https://)
MCT_API_URI=<retrieve-from-secret-source>
MCT_CLIENT_ID=<retrieve-from-secret-source>
MCT_CLIENT_SECRET=<retrieve-from-secret-source>
MCT_TENANT_ID=<retrieve-from-secret-source>

# Optional
MCT_API_VERSION=v1  # Default: v1 (recommended)
```

---

## Export Script Usage

### Basic Export

```bash
# Export all default resources
MCT_BASE_URL=learn.skillourfuture.org \
MCT_API_URI=<retrieve-from-secret-source> \
MCT_CLIENT_ID=<retrieve-from-secret-source> \
MCT_CLIENT_SECRET='<your-secret>' \
MCT_TENANT_ID=<retrieve-from-secret-source> \
node scripts/migrations/mct/mct-export.mjs
```

### Export Specific Resources

```bash
# Export only users and organizations
node scripts/migrations/mct/mct-export.mjs --resources users,organizations

# Export with pagination limits (for testing)
node scripts/migrations/mct/mct-export.mjs --resources users --start-page 1 --end-page 10 --page-size 50
```

### Dry-Run Mode

```bash
# Test configuration without making API calls
MCT_BASE_URL=learn.skillourfuture.org \
node scripts/migrations/mct/mct-export.mjs --dry-run
```

### Force Overwrite

```bash
# Overwrite existing export files
node scripts/migrations/mct/mct-export.mjs --force
```

### Command-Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--resources` | Comma-separated list of resources | `--resources users,courses` |
| `--start-page` | Starting page number (default: 1) | `--start-page 1` |
| `--end-page` | Ending page number (default: all) | `--end-page 10` |
| `--page-size` | Records per page (1-1000, default: 100) | `--page-size 50` |
| `--out` | Output directory (default: `./exports/mct`) | `--out ./my-exports` |
| `--dry-run` | Test mode (no API calls, no files) | `--dry-run` |
| `--force` | Overwrite existing files | `--force` |

---

## API Endpoints & Data Formats

### Endpoint Mapping

| Resource | V1 Endpoint | V3 Endpoint | Response Format | Notes |
|----------|-------------|-------------|-----------------|-------|
| **organizations** | `/api/v1/organization` | ❌ | JSON array | Simple list |
| **users** | `/api/v1/Reports/Users` | `/api/v3/Reports/Users` | **CSV** | Use Reports endpoint (users endpoint requires searchTerm) |
| **categories** | `/api/v1/Category` | `/api/v3/admin/categoriesAndCourses` | JSON | V3 returns hierarchical structure |
| **courses** | `/api/v1/Courses` | `/api/v3/Courses` | JSON | Returns categories containing courses |
| **enrollments** | `/api/v1/UserEnrollment` | ❌ | JSON | |
| **reports** | `/api/v1/Reports/Users` | `/api/v3/Reports/Users` | **CSV** | Same as users endpoint |

### Important API Quirks

#### 1. CSV Responses (Reports Endpoints)

**Issue:** Reports endpoints return CSV, not JSON.

**Solution:** Script automatically detects CSV via `Content-Type` header and parses it.

**Example:**
```javascript
// Response: text/csv
"Contact,First Name,Last Name,My groups\nemail@example.com,John,Doe,Developer"
// Parsed to:
[
  {
    "Contact": "email@example.com",
    "First Name": "John",
    "Last Name": "Doe",
    "My groups": "Developer"
  }
]
```

#### 2. Hierarchical Course Structure

**Issue:** `/api/v1/Courses` returns categories containing courses, not a flat list.

**Structure:**
```json
{
  "CategoryId": 24,
  "CategoryName": "AI Fluency",
  "Courses": [
    {
      "ProductId": 279,
      "CourseName": "Module 1: Introduction to AI",
      ...
    }
  ]
}
```

**Solution:** Script extracts courses from categories and uses `ProductId` (not `courseId`) for content fetching.

#### 3. Users Endpoint Requires searchTerm

**Issue:** `/api/v1/users` requires `searchTerm` parameter (for lookup, not bulk export).

**Solution:** Use `/api/v1/Reports/Users` for bulk user export (returns CSV).

#### 4. Required Headers

All API requests must include:
- `Authorization: Bearer <token>`
- `ClientType: service` (required by MCT API)

---

## Data Structure Notes

### Organizations

**Endpoint:** `/api/v1/organization`  
**Format:** JSON array  
**Fields:**
- `id` - Organization ID
- `name` - Organization name (e.g., "Indonesia", "Vietnam")
- `description` - Description (usually null)
- `tenantId` - Tenant ID (usually null)

**Example:**
```json
{
  "id": 6,
  "name": "Indonesia",
  "description": null,
  "tenantId": null
}
```

### Users

**Endpoint:** `/api/v1/Reports/Users`  
**Format:** CSV (converted to JSON)  
**Fields:** 18 fields including:
- `Contact` - Email address
- `First Name`, `Last Name`
- `My groups` - Learning pathways (pipe-separated)
- `Nickname`
- `When were you born?` - Date of birth
- `Gender`
- `Which Country are you from?`
- `Which learning pathway are you interested in?`
- `Consent`
- `Source`
- `Created Date (Hubspot)`
- `University`
- `Referral Partner`
- And more...

**Note:** CSV parsing handles quoted fields and special characters.

### Categories

**V1 Endpoint:** `/api/v1/Category`  
**V3 Endpoint:** `/api/v3/admin/categoriesAndCourses` (recommended - hierarchical)

**V3 Structure:**
```json
{
  "categories": [
    {
      "categoryId": 24,
      "categoryName": "AI Fluency",
      "courses": [...]
    }
  ]
}
```

### Courses

**Endpoint:** `/api/v1/Courses`  
**Format:** JSON (hierarchical - categories contain courses)

**Course Fields:**
- `ProductId` - Course ID (use this for content fetching)
- `CourseName` - Course title
- `CourseDescription` - Description
- `ContentLanguage` - Language code (e.g., "EN-US", "ID-ID")
- `CourseImage` - Image URL
- `IsRegistered` - Registration status
- `CompletionPercentage` - User completion (if applicable)

**Course Content Endpoints:**
- `/api/v3/Courses/{ProductId}/Content` - Course structure/content
- `/api/v3/Courses/{ProductId}/Metadata` - Course metadata
- `/api/v3/Courses/{ProductId}/Lesson` - Course lessons

---

## Troubleshooting

### Authentication Errors

#### Error: `AADSTS7000222: The provided client secret keys are expired`

**Solution:** Refresh the client secret using Azure CLI:
```bash
az ad app credential reset --id <mct-app-id> --append
```

#### Error: `AADSTS7000215: Invalid client secret provided`

**Causes:**
- Secret copied incorrectly (extra spaces, missing characters)
- Secret expired but not yet reflected in error message
- Wrong app registration ID

**Solution:**
1. Verify secret is copied correctly (no extra spaces)
2. Create new secret: `az ad app credential reset --id <mct-app-id> --append`
3. Verify the app ID matches the team-managed MCT application registration

#### Error: `AADSTS65001: The user or administrator has not consented`

**Cause:** Azure CLI user account doesn't have permission for the API scope.

**Solution:** This is expected for service-to-service auth. Use the client secret method instead (not Azure CLI token).

### API Errors

#### Error: `HTTP 400 - searchTerm field is required`

**Cause:** Using `/api/v1/users` endpoint without searchTerm.

**Solution:** Use `/api/v1/Reports/Users` for bulk export (already configured in script).

#### Error: `Unexpected token 'C', "Contact, F"... is not valid JSON`

**Cause:** Reports endpoint returned CSV but script tried to parse as JSON.

**Solution:** Already fixed - script detects CSV via Content-Type header. If this occurs, check that `Content-Type` header is being read correctly.

#### Error: `HTTP 404` for course content endpoints

**Cause:** Course doesn't have content available via API, or ProductId is incorrect.

**Solution:** Script logs warning and continues. Check course structure in exported data.

### Export Issues

#### File exists, skipping

**Solution:** Use `--force` flag to overwrite, or delete existing file:
```bash
rm exports/mct/users.ndjson
node scripts/migrations/mct/mct-export.mjs --resources users
```

#### No records exported

**Possible Causes:**
- API returned empty result
- Pagination issue
- Endpoint not available for this API version

**Solution:**
1. Check API response manually with curl
2. Verify endpoint exists in Swagger UI
3. Try different API version (v1 vs v3)
4. Check authentication token is valid

#### CSV parsing errors

**Cause:** CSV format doesn't match expected structure (quoted fields, special characters).

**Solution:** CSV parser handles quoted fields. If issues persist, check raw CSV response:
```bash
curl -H "Authorization: Bearer <token>" \
     -H "ClientType: service" \
     "https://learn.skillourfuture.org/api/v1/Reports/Users?page=1&pageSize=5"
```

---

## Credential Management

### Current Credentials

**App Registration:**
- **App ID:** retrieve from the team-managed secret/config source
- **Tenant ID:** retrieve from the team-managed secret/config source
- **API URI:** retrieve from the team-managed secret/config source
- **Base URL:** `learn.skillourfuture.org`

### Checking Credential Expiration

```bash
# List all credentials for the app
az ad app credential list --id <mct-app-id>

# Output shows:
# - keyId
# - endDateTime (expiration date)
# - hint (first 4 characters of secret)
```

### Creating New Credentials

```bash
# Create new secret (keeps old ones active)
az ad app credential reset --id <mct-app-id> --append

# Create new secret (revokes old ones immediately)
az ad app credential reset --id <mct-app-id>
```

**⚠️ Important:** 
- Secrets expire after 6-12 months (check `endDateTime`)
- Use `--append` to keep old secrets active during transition
- Without `--append`, old secrets are immediately revoked
- Save the new secret immediately - it's only shown once

### Storing Credentials Securely

**Do NOT commit secrets to git!**

**Recommended:**
1. Retrieve values from the approved team-managed secret source
2. Export them into the current shell only for the duration of the run
3. If a local `.env` file is temporarily required, keep it out of git and delete it after use
4. Document only the retrieval process in docs, not the values themselves

**Example `.env` file:**
```bash
MCT_BASE_URL=learn.skillourfuture.org
MCT_API_URI=<retrieve-from-secret-source>
MCT_CLIENT_ID=<retrieve-from-secret-source>
MCT_CLIENT_SECRET=<your-secret-here>
MCT_TENANT_ID=<retrieve-from-secret-source>
```

Then source it:
```bash
source .env
node scripts/migrations/mct/mct-export.mjs
```

---

## Testing Checklist

### Pre-Export Testing

- [ ] Azure CLI installed and authenticated
- [ ] Client secret is valid (not expired)
- [ ] Dry-run test passes
- [ ] Authentication test succeeds
- [ ] Small export test (1 page) works

### Export Testing

- [ ] Organizations export (should get ~46 records)
- [ ] Users export (should get 60k+ records)
- [ ] Categories export (should get hierarchical structure)
- [ ] Courses export (should get categories with courses)
- [ ] Course content export (should fetch content for each course)

### Data Validation

- [ ] NDJSON files are valid JSON
- [ ] Record counts match expectations
- [ ] Required fields are present
- [ ] Data types are correct
- [ ] No duplicate records

---

## Quick Reference

### Refresh Credentials
```bash
az ad app credential reset --id <mct-app-id> --append
```

### Test Authentication
```bash
MCT_BASE_URL=learn.skillourfuture.org \
MCT_API_URI=<retrieve-from-secret-source> \
MCT_CLIENT_ID=<retrieve-from-secret-source> \
MCT_CLIENT_SECRET='<secret>' \
MCT_TENANT_ID=<retrieve-from-secret-source> \
node scripts/migrations/mct/mct-export.mjs --resources organizations --start-page 1 --end-page 1
```

### Dry-Run Test
```bash
MCT_BASE_URL=learn.skillourfuture.org \
node scripts/migrations/mct/mct-export.mjs --dry-run
```

### Full Export
```bash
# Set credentials in environment
export MCT_BASE_URL=learn.skillourfuture.org
export MCT_API_URI=<retrieve-from-secret-source>
export MCT_CLIENT_ID=<retrieve-from-secret-source>
export MCT_CLIENT_SECRET='<secret>'
export MCT_TENANT_ID=<retrieve-from-secret-source>

# Run export
node scripts/migrations/mct/mct-export.mjs
```

---

## Related Documentation

- `docs/ops/runbooks/migrations/mct/MIGRATION_PLAN.md` - Overall migration strategy
- `docs/reference/migrations/mct/API_EXPLORATION.md` - API endpoint discovery
- `docs/archive/reports/mct/EXPORT_TEST_RESULTS.md` - Test results
- `docs/archive/reports/mct/EXPORT_SUCCESS.md` - Success summary
- `reports/2025/mct/EXPORT_TESTING_GUIDE_2025-08-24.md` - Historical test procedure snapshot
- `hubspot-webhook-mct/functions/index.js` - Working authentication reference

---

## Support & Maintenance

**Last Updated:** 2025-11-07  
**Script Version:** 1.0  
**Tested With:** Node.js v24.10.0

**Known Issues:**
- None currently

**Future Improvements:**
- [ ] Add progress bar for large exports
- [ ] Add resume capability for interrupted exports
- [ ] Add data validation checks
- [ ] Add export statistics report

---

## Summary for Future Agents

### What You Need to Know

1. **Credentials Expire** - Client secrets expire every 6-12 months. Use Azure CLI to refresh:
   ```bash
   az ad app credential reset --id <mct-app-id> --append
   ```

2. **API Quirks** - Reports endpoints return CSV (not JSON). Script handles this automatically.

3. **Course Structure** - Courses are nested in categories. Use `ProductId` (not `courseId`) for content fetching.

4. **Users Export** - Use `/api/v1/Reports/Users` (not `/api/v1/users`) for bulk export.

5. **Always Test First** - Use `--dry-run` flag before real exports.

### Quick Troubleshooting

- **Auth fails?** → Refresh client secret with Azure CLI
- **CSV parsing error?** → Already handled, but check Content-Type header
- **No records exported?** → Check API response manually, verify endpoint exists
- **File exists?** → Use `--force` to overwrite

### Documentation Hierarchy

1. **Start Here:** `docs/ops/runbooks/migrations/mct/EXPORT_GUIDE.md` (this file) - Complete guide
2. **Reference:** `docs/reference/migrations/mct/DOCUMENTATION_INDEX.md` - Index of all docs
3. **Strategy:** `docs/ops/runbooks/migrations/mct/MIGRATION_PLAN.md` - Overall migration plan
4. **API Details:** `docs/reference/migrations/mct/API_EXPLORATION.md` - Endpoint discovery
5. **Code Reference:** `hubspot-webhook-mct/functions/index.js` - Working auth pattern

---

## Related Documentation

- `docs/reference/migrations/mct/DOCUMENTATION_INDEX.md` - Index of all MCT documentation
- `docs/ops/runbooks/migrations/mct/MIGRATION_PLAN.md` - Overall migration strategy
- `docs/reference/migrations/mct/API_EXPLORATION.md` - API endpoint discovery
- `docs/archive/reports/mct/EXPORT_TEST_RESULTS.md` - Test results
- `docs/archive/reports/mct/EXPORT_SUCCESS.md` - Success summary
- `reports/2025/mct/EXPORT_TESTING_GUIDE_2025-08-24.md` - Historical test procedure snapshot
- `hubspot-webhook-mct/functions/index.js` - Working authentication reference

