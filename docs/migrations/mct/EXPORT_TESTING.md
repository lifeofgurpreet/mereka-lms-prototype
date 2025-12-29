# MCT Export Script Testing Guide
_Audience: QA • Owner: Migration Squad • Last verified: 2025-08-24_

## Pre-Testing Checklist

### ✅ Script Readiness
- [x] Export script created (`tools/mct-export.mjs`)
- [x] Authentication pattern matches working code
- [x] Dry-run mode implemented
- [x] Validation and error handling added
- [x] Summary reporting implemented
- [x] No linter errors

### 🔐 Authentication Setup

**Option 1: Service-to-Service Auth (Recommended)**
You'll need these credentials (available from `hubspot-webhook-mct` project):
- `MCT_BASE_URL` - Domain only: `learn.skillourfuture.org`
- `MCT_CLIENT_ID` - Service principal ID
- `MCT_CLIENT_SECRET` - Service principal secret
- `MCT_TENANT_ID` - Azure tenant ID
- `MCT_API_URI` - API scope URI (e.g., `api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3`)

**Option 2: Bearer Token (Quick Test)**
- Log into MCT portal in browser
- Extract Bearer token from DevTools Network tab
- Use `MCT_ACCESS_TOKEN` environment variable

## Testing Steps

### Step 1: Dry Run Test (No API Calls)
```bash
MCT_BASE_URL=learn.skillourfuture.org \
node tools/mct-export.mjs --dry-run
```

**Expected Output:**
- Configuration summary
- List of endpoints that would be called
- No files written
- No API authentication attempted

### Step 2: Test Authentication Only
```bash
MCT_BASE_URL=learn.skillourfuture.org \
MCT_API_URI=api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3 \
MCT_CLIENT_ID=<your-client-id> \
MCT_CLIENT_SECRET=<your-secret> \
MCT_TENANT_ID=<your-tenant-id> \
node tools/mct-export.mjs --dry-run
```

**Expected Output:**
- ✓ Successfully obtained MCT API token (if auth works)
- Or clear error message if credentials are invalid

### Step 3: Small Export Test (Single Resource, Single Page)
```bash
MCT_BASE_URL=learn.skillourfuture.org \
MCT_API_URI=api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3 \
MCT_CLIENT_ID=<your-client-id> \
MCT_CLIENT_SECRET=<your-secret> \
MCT_TENANT_ID=<your-tenant-id> \
node tools/mct-export.mjs \
  --resources organizations \
  --start-page 1 \
  --end-page 1
```

**Expected Output:**
- Authentication success
- Organizations exported to `exports/mct/organizations.ndjson`
- Summary report showing 1 file exported
- Record count and file size

### Step 4: Test Multiple Resources (Small Batch)
```bash
MCT_BASE_URL=learn.skillourfuture.org \
MCT_API_URI=api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3 \
MCT_CLIENT_ID=<your-client-id> \
MCT_CLIENT_SECRET=<your-secret> \
MCT_TENANT_ID=<your-tenant-id> \
node tools/mct-export.mjs \
  --resources organizations,users \
  --start-page 1 \
  --end-page 1 \
  --page-size 10
```

**Expected Output:**
- Both resources exported
- Summary showing 2 files
- Total record counts

### Step 5: Test Version Fallback
```bash
# Test categories (should use V3, fallback to V1 if needed)
MCT_BASE_URL=learn.skillourfuture.org \
MCT_API_URI=api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3 \
MCT_CLIENT_ID=<your-client-id> \
MCT_CLIENT_SECRET=<your-secret> \
MCT_TENANT_ID=<your-tenant-id> \
node tools/mct-export.mjs \
  --resources categories \
  --start-page 1 \
  --end-page 1
```

**Expected Output:**
- Categories exported from V3 endpoint
- Or fallback message if V3 not available

### Step 6: Test Course Content Export
```bash
# First export courses list, then content details
MCT_BASE_URL=learn.skillourfuture.org \
MCT_API_URI=api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3 \
MCT_CLIENT_ID=<your-client-id> \
MCT_CLIENT_SECRET=<your-secret> \
MCT_TENANT_ID=<your-tenant-id> \
node tools/mct-export.mjs \
  --resources courses \
  --start-page 1 \
  --end-page 1
```

**Expected Output:**
- `courses.ndjson` with course list
- `structure/course_content.ndjson` with course content
- `structure/course_metadata.ndjson` with metadata

## Troubleshooting

### Authentication Errors
- **401 Unauthorized**: Check credentials are correct
- **Token request failed**: Verify MCT_API_URI format (should be `api://...`)
- **Missing scope**: Ensure service principal has MCT API permissions

### API Errors
- **404 Not Found**: Endpoint may not exist for this API version
- **429 Too Many Requests**: Rate limiting - script will retry automatically
- **500 Server Error**: MCT API issue - check MCT portal status

### File Issues
- **File exists, skipping**: Use `--force` to overwrite
- **Permission denied**: Check write permissions on output directory
- **No files exported**: Check API responses, may need to adjust pagination

## Success Criteria

✅ **Ready for Production Export When:**
1. Dry-run works without errors
2. Authentication succeeds
3. Small test exports complete successfully
4. Summary report shows correct record counts
5. Exported NDJSON files are valid JSON
6. Course content structure exports correctly

## Next Steps After Testing

1. **Validate Export Data**
   - Check NDJSON file format
   - Verify record counts match expectations
   - Inspect sample records for completeness

2. **Full Export**
   - Run without `--end-page` limit
   - Export all resources
   - Monitor for rate limiting

3. **Data Analysis**
   - Analyze exported data structure
   - Map MCT fields to Open edX equivalents
   - Plan transformation scripts

## Notes

- The script uses the same authentication pattern as `hubspot-webhook-mct/functions/index.js`
- All API requests include `ClientType: service` header (required by MCT)
- Rate limiting: 200ms delay between requests
- Retry logic: 3 attempts with exponential backoff for 429/5xx errors

