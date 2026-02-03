# MCT API Authentication Issue - RESOLVED

## Resolution Summary (2025-12-17)

**Status: FIXED**

The MCT S2S authentication issue was resolved by creating a missing **app role assignment** in Azure AD.

### Root Cause

The whitelisted app (`caa4dce3-e49c-4c09-9160-031d51bfd2a9`) in `ServiceApplicationIds` did NOT have the `S2SAppRole` assigned to the UNDP API (`bf8331fd-17ed-4bcf-af5f-599db14ff4f4`). This caused tokens to lack the `roles` claim, which MCT requires for authentication.

### The Fix (via Azure CLI)

```bash
# 1. Get service principal IDs
WHITELISTED_SP_ID=$(az ad sp show --id caa4dce3-e49c-4c09-9160-031d51bfd2a9 --query "id" -o tsv)
UNDP_API_SP_ID=$(az ad sp show --id bf8331fd-17ed-4bcf-af5f-599db14ff4f4 --query "id" -o tsv)
S2S_ROLE_ID="7007385c-5aae-4f57-a999-381dff961d74"

# 2. Create the app role assignment
az rest --method POST \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$WHITELISTED_SP_ID/appRoleAssignments" \
  --body "{\"principalId\":\"$WHITELISTED_SP_ID\",\"resourceId\":\"$UNDP_API_SP_ID\",\"appRoleId\":\"$S2S_ROLE_ID\"}"
```

Actual values used:
- `WHITELISTED_SP_ID`: `12b69786-d5f8-4df3-89fd-9c4497f7882c`
- `UNDP_API_SP_ID`: `0746c2c8-360c-4f78-b02f-f523851c408a`
- `S2S_ROLE_ID`: `7007385c-5aae-4f57-a999-381dff961d74`

### Working Configuration

**MCT Webapp Settings (mctindonesia):**
```
ServiceAuthEnabled:     true
ServiceAuthAudience:    api://bf8331fd-17ed-4bcf-af5f-599db14ff4f4
ServiceAuthRole:        S2SAppRole
ServiceAuthTenantId:    b1aab053-6242-46ec-9cf8-bd02e63dd2da
ServiceApplicationIds:  caa4dce3-e49c-4c09-9160-031d51bfd2a9
ida:AuthClientId:       e8edea94-e86f-4dc7-857e-3c5c09bb76d3
```

### Working Credentials for Export

```bash
export MCT_BASE_URL="mctindonesia.azurewebsites.net"
export MCT_CLIENT_ID="caa4dce3-e49c-4c09-9160-031d51bfd2a9"
export MCT_CLIENT_SECRET="Mwo8Q~it.mHuXlwAKG4DPIq-~IuXMzuqkASfZcfh"
export MCT_TENANT_ID="b1aab053-6242-46ec-9cf8-bd02e63dd2da"
export MCT_API_URI="api://bf8331fd-17ed-4bcf-af5f-599db14ff4f4"

# Run export
node scripts/migrations/mct/mct-export.mjs --force
```

**Note:** A new client secret was created for the whitelisted app on 2025-12-17. The secret expires 2026-12-17.

### Verification

After the fix, the token contains the required role:
```json
{
  "aud": "api://bf8331fd-17ed-4bcf-af5f-599db14ff4f4",
  "appid": "caa4dce3-e49c-4c09-9160-031d51bfd2a9",
  "roles": ["S2SAppRole"],  // THIS WAS MISSING BEFORE
  "tid": "b1aab053-6242-46ec-9cf8-bd02e63dd2da"
}
```

### Export Results (2025-12-17)

Successfully exported:
- 46 organizations
- 69,419 users
- 1 category hierarchy
- 15 courses (81 sub-courses)
- 27 groups
- 13 learning paths

---

## Troubleshooting Guide for Future Issues

### If MCT API Returns 401 Again

1. **Check token has S2SAppRole**
   ```bash
   # Get token and decode it
   node -e "
   const https = require('https');
   const data = 'grant_type=client_credentials&client_id=caa4dce3-e49c-4c09-9160-031d51bfd2a9&scope=api://bf8331fd-17ed-4bcf-af5f-599db14ff4f4/.default&client_secret=YOUR_SECRET';
   const req = https.request({hostname:'login.microsoft.com',path:'/b1aab053-6242-46ec-9cf8-bd02e63dd2da/oauth2/v2.0/token',method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded','Content-Length':data.length}}, r=>{let b='';r.on('data',c=>b+=c);r.on('end',()=>{const token=JSON.parse(b).access_token;const payload=JSON.parse(Buffer.from(token.split('.')[1],'base64').toString());console.log('Roles:',payload.roles);});});
   req.write(data);req.end();
   "
   ```

   If `roles` is `undefined` or empty, the app role assignment is missing.

2. **Check app role assignment exists**
   ```bash
   az rest --method GET \
     --url "https://graph.microsoft.com/v1.0/servicePrincipals(appId='caa4dce3-e49c-4c09-9160-031d51bfd2a9')/appRoleAssignments" \
     -o json
   ```

   Look for assignment to `resourceDisplayName: "Automating_User_Creation_for_UNDP"` with `appRoleId: "7007385c-5aae-4f57-a999-381dff961d74"`.

3. **Check MCT webapp config**
   ```bash
   az webapp config appsettings list \
     --name mctindonesia \
     --resource-group "mrg-microsoft-community-training-20230404012419" \
     --query "[?contains(name, 'ServiceAuth') || name=='ServiceApplicationIds'].{name:name, value:value}" \
     -o table
   ```

4. **Recreate app role assignment if missing**
   ```bash
   WHITELISTED_SP_ID="12b69786-d5f8-4df3-89fd-9c4497f7882c"
   UNDP_API_SP_ID="0746c2c8-360c-4f78-b02f-f523851c408a"
   S2S_ROLE_ID="7007385c-5aae-4f57-a999-381dff961d74"

   echo "{\"principalId\":\"$WHITELISTED_SP_ID\",\"resourceId\":\"$UNDP_API_SP_ID\",\"appRoleId\":\"$S2S_ROLE_ID\"}" > /tmp/role-body.json

   az rest --method POST \
     --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$WHITELISTED_SP_ID/appRoleAssignments" \
     --body @/tmp/role-body.json
   ```

5. **If client secret expired, create new one**
   ```bash
   az ad app credential reset \
     --id caa4dce3-e49c-4c09-9160-031d51bfd2a9 \
     --append \
     --display-name "mct-export-$(date +%Y%m%d)" \
     --years 1
   ```

---

## Azure AD Application Reference

### Whitelisted Client App (use this for API calls)
- **App Name:** Automating_User_Creation_for_SOF_S2S-Client
- **App ID (Client ID):** `caa4dce3-e49c-4c09-9160-031d51bfd2a9`
- **Service Principal ID:** `12b69786-d5f8-4df3-89fd-9c4497f7882c`
- **Has S2SAppRole on:** UNDP API + SOF API

### UNDP API App (the resource/audience)
- **App Name:** Automating_User_Creation_for_UNDP
- **App ID:** `bf8331fd-17ed-4bcf-af5f-599db14ff4f4`
- **Service Principal ID:** `0746c2c8-360c-4f78-b02f-f523851c408a`
- **Identifier URI:** `api://bf8331fd-17ed-4bcf-af5f-599db14ff4f4`
- **S2SAppRole ID:** `7007385c-5aae-4f57-a999-381dff961d74`

### SOF API App (alternative resource)
- **App Name:** Automating_User_Creation_for_SOF
- **App ID:** `e8edea94-e86f-4dc7-857e-3c5c09bb76d3`
- **Service Principal ID:** `312b1d3c-779e-4e4e-9f20-ac594ebef579`
- **Identifier URI:** `api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3`
- **S2SAppRole ID:** `6ee91680-135a-4d89-9018-6f6de3ce1c5d`

### Azure Tenant
- **Tenant ID:** `b1aab053-6242-46ec-9cf8-bd02e63dd2da`
- **Tenant Name:** `bijibiji.onmicrosoft.com`

---

## Key Learnings

1. **Azure AD app permissions ≠ app role assignments**
   - Adding an API permission via `az ad app permission add` only requests the permission
   - You must ALSO create an app role assignment via Graph API for the token to include the role

2. **ServiceApplicationIds is a whitelist**
   - Only client apps listed in `ServiceApplicationIds` are allowed to call the API
   - The listed apps MUST have the S2SAppRole assigned to the ServiceAuthAudience API

3. **Token claims are cached**
   - After creating a role assignment, Azure AD may take 1-5 minutes to include it in new tokens
   - Test with a fresh token request, not a cached one

4. **MCT requires all three to match:**
   - Token `aud` must match `ServiceAuthAudience`
   - Token `appid` must be in `ServiceApplicationIds`
   - Token `roles` must include `ServiceAuthRole` value

---

## Original Issue History

The sections below document the original troubleshooting process before the fix was found.

### Original Problem (2025-11-24)

The MCT API was returning 401 Unauthorized despite having valid OAuth2 tokens with correct audience. Multiple credential sets were tried without success.

### What Was Tried (Before Fix)
- Regenerated client secrets
- Created new app credentials
- Added ClientType: service header
- Tested different API versions
- Updated MCT webapp configuration
- Restarted webapp multiple times
- Tested different endpoints

### The Missing Piece

The whitelisted app (`caa4dce3-...`) in `ServiceApplicationIds` had the S2SAppRole assigned to the **SOF API** (`e8edea94-...`), but the `ServiceAuthAudience` was set to the **UNDP API** (`bf8331fd-...`). This mismatch meant tokens requested for the UNDP audience didn't include the S2SAppRole.

The fix was to create an app role assignment for the whitelisted app on the UNDP API, so tokens requested for that audience would include the role.

---

**Issue Resolved:** 2025-12-17
**Resolution Time:** ~2 hours of Azure CLI investigation
**Resolved By:** Claude Code AI Assistant
