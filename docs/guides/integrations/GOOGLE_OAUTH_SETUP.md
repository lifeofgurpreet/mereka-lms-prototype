# Google OAuth Setup Guide for Mereka Academy
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2025-08-30_

This guide walks through setting up Google Login for OpenEdX LMS sites.

## Quick checklist

1. Create or rotate the OAuth client in Google Cloud Console.
2. Store the client ID and secret in the approved secret-management flow.
3. Apply the values through Tutor config or the supported setup script.
4. Restart LMS and verify the provider is enabled in Django admin.
5. Test the login flow on the exact target domain.

## Prerequisites

- Access to Google Cloud Console with permissions to create OAuth credentials
- Access to the `mereka-lms` GCP project
- LMS sites configured and accessible

## Step 1: Create OAuth Credentials in Google Cloud Console

1. **Navigate to Google Cloud Console:**
   - Go to https://console.cloud.google.com/
   - Select the `mereka-lms` project (or create it if it doesn't exist)

2. **Configure OAuth Consent Screen:**
   - Navigate to **APIs & Services** > **OAuth consent screen**
   - Choose **External** user type and click **Create**
   - Fill in the required information:
     - **App name:** Mereka Academy
     - **User support email:** [Your support email]
     - **Developer contact information:** [Your email]
   - Click **Save and Continue**
   - On **Scopes** page, click **Save and Continue** (default scopes are fine)
   - On **Test users** page, click **Save and Continue** (skip for now)
   - Review and return to dashboard

3. **Create OAuth 2.0 Client ID:**
   - Navigate to **APIs & Services** > **Credentials**
   - Click **Create Credentials** > **OAuth client ID**
   - Choose **Web application** as the application type
   - Provide a name: `Mereka Academy LMS`
   
4. **Configure Authorized Origins and Redirect URIs:**
   
   For **academyv2.mereka.io** (production):
   - **Authorized JavaScript origins:**
     ```
     https://academyv2.mereka.io
     https://apps.academyv2.mereka.io
     ```
   
   - **Authorized redirect URIs:**
     ```
     https://academyv2.mereka.io/auth/complete/google-oauth2/
     https://apps.academyv2.mereka.io/auth/complete/google-oauth2/
     ```
   
   For **localhost** (local development):
   - **Authorized JavaScript origins:**
     ```
     http://localhost
     http://apps.localhost
     ```
   
   - **Authorized redirect URIs:**
     ```
     http://localhost/auth/complete/google-oauth2/
     http://apps.localhost/auth/complete/google-oauth2/
     ```
   
   **Note:** Add all domains where you want Google login to work. For multisite setups, add each domain's redirect URI.

5. **Save Credentials:**
   - Click **Create**
   - **IMPORTANT:** Copy the **Client ID** and **Client Secret** immediately
   - Store these securely using the secret-management flow before applying them

## Step 2: Configure OpenEdX

The configuration is done via Tutor environment variables. Update `tutor_env/config.yml` or use `tutor config save`:

```bash
source infrastructure/tutor/tutor-env.sh

# Set Google OAuth credentials
tutor config save \
  --set SOCIAL_AUTH_GOOGLE_OAUTH2_KEY="YOUR_CLIENT_ID.apps.googleusercontent.com" \
  --set SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET="YOUR_CLIENT_SECRET"
```

Alternatively, add these to `tutor_env/config.yml`:

```yaml
SOCIAL_AUTH_GOOGLE_OAUTH2_KEY: "YOUR_CLIENT_ID.apps.googleusercontent.com"
SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET: "YOUR_CLIENT_SECRET"
```

## Step 3: Verify Configuration

The LMS environment file (`tutor_env/env/apps/openedx/config/lms.env.yml`) should already have:
- `ENABLE_THIRD_PARTY_AUTH: true` ✅ (already configured)

After setting the credentials, restart the LMS:

```bash
# For local development
tutor local restart lms

# For Kubernetes
tutor k8s restart lms
```

## Step 4: Enable Google Provider in Django Admin

1. Access Django admin: `https://academyv2.mereka.io/admin/` (or `http://localhost/admin/` for local)
2. Navigate to **Third Party Authentication** > **Provider Configuration (SSO)**
3. Click **Add Provider Configuration**
4. Configure:
   - **Provider:** `Google`
   - **Name:** `Google OAuth2`
   - **Enabled:** ✓ (checked)
   - **Skip email verification:** ✓ (optional, recommended for better UX)
   - **Skip registration form:** ✓ (optional)
   - **Site:** Select your site (e.g., `academyv2.mereka.io`)
5. Click **Save**

## Step 5: Test Google Login

1. Navigate to your LMS login page: `https://academyv2.mereka.io/login`
2. You should see a **Sign in with Google** button
3. Click it and complete the OAuth flow
4. Verify that you're logged in and your account is created

## Troubleshooting

### Google Login Button Not Appearing
- Verify `ENABLE_THIRD_PARTY_AUTH: true` in `lms.env.yml`
- Check that the provider is enabled in Django admin
- Restart LMS service after configuration changes

### "Redirect URI Mismatch" Error

- Verify redirect URIs in Google Cloud Console match exactly:
  - Must include `/auth/complete/google-oauth2/` path
  - Protocol (http/https) must match
  - Domain must match exactly (no trailing slashes in origins)

### "Invalid Client" Error

- Verify Client ID and Secret are correct
- Check that OAuth consent screen is configured
- Ensure the project has the Google+ API enabled (if required)

### User Not Created After Login
- Check LMS logs: `tutor local logs lms` or `kubectl logs -n mereka-lms deploy/lms`
- Verify email domain restrictions (if any) in Google OAuth settings
- Check Django admin for any error messages

## Security Best Practices

1. **Store Credentials Securely:**
   - Use the approved secret-management flow described in `docs/guides/admin/SECRETS_MANAGEMENT_GUIDE.md`
   - Do not paste client secrets into issues, guides, or ad hoc scripts

2. **Restrict OAuth Consent Screen:**
   - Add only authorized domains
   - Limit test users during development
   - Submit for verification if making app public

3. **Monitor Usage:**
   - Check Google Cloud Console > APIs & Services > Credentials for usage metrics
   - Review OAuth consent screen activity

## Multi-Site Configuration

For multiple sites (e.g., `skillourfuture.academy.mereka.io`):

1. Add redirect URIs for each domain in Google Cloud Console
2. Create separate Provider Configuration entries in Django admin for each site
3. Each site can have different OAuth settings if needed

## References

- [OpenEdX Third-Party Authentication Documentation](https://edx.readthedocs.io/projects/edx-installing-configuring-and-running/en/latest/configuration/tpa/index.html)
- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [Django Social Auth Documentation](https://python-social-auth.readthedocs.io/)
