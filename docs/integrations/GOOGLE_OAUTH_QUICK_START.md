# Google OAuth Quick Start - Manual Steps
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2025-08-30_

Since the Google Cloud Console UI requires manual interaction, follow these steps:

## Step 1: Create OAuth Client in Google Cloud Console

1. Go to: https://console.cloud.google.com/apis/credentials?project=mereka-lms
2. Click **"+ CREATE CREDENTIALS"** button at the top
3. Select **"OAuth client ID"**
4. If prompted to configure OAuth consent screen first:
   - Click **"CONFIGURE CONSENT SCREEN"**
   - Choose **"External"** user type
   - Fill in:
     - App name: `Mereka Academy`
     - User support email: `gurpreet@biji-biji.com`
     - Developer contact: `gurpreet@biji-biji.com`
   - Click **"SAVE AND CONTINUE"** through all steps
   - Return to Credentials page

5. Create OAuth Client:
   - Application type: **"Web application"**
   - Name: `Mereka Academy LMS`
   
6. Add Authorized JavaScript origins:
   ```
   https://staging.academy.mereka.io
   https://apps.staging.academy.mereka.io
   http://localhost
   http://apps.localhost
   ```

7. Add Authorized redirect URIs:
   ```
   https://staging.academy.mereka.io/auth/complete/google-oauth2/
   https://apps.staging.academy.mereka.io/auth/complete/google-oauth2/
   http://localhost/auth/complete/google-oauth2/
   http://apps.localhost/auth/complete/google-oauth2/
   ```

8. Click **"CREATE"**
9. **COPY** the Client ID and Client Secret immediately (you won't see the secret again!)

## Step 2: Configure OpenEdX

Once you have the credentials, run:

```bash
source ops/tutor-env.sh
./tools/setup-google-oauth.sh --client-id "YOUR_CLIENT_ID" --client-secret "YOUR_CLIENT_SECRET"
```

Or manually:

```bash
source ops/tutor-env.sh
tutor config save \
  --set SOCIAL_AUTH_GOOGLE_OAUTH2_KEY="YOUR_CLIENT_ID.apps.googleusercontent.com" \
  --set SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET="YOUR_CLIENT_SECRET"
```

## Step 3: Restart LMS

```bash
# For local development
tutor local restart lms

# For Kubernetes
tutor k8s restart lms
```

## Step 4: Enable Provider in Django Admin

1. Go to: `http://localhost/admin/` (or `https://staging.academy.mereka.io/admin/`)
2. Navigate to: **Third Party Authentication** > **Provider Configuration (SSO)**
3. Click **"Add Provider Configuration"**
4. Configure:
   - **Provider:** `Google`
   - **Name:** `Google OAuth2`
   - **Enabled:** ✓
   - **Site:** Select your site
5. Click **"Save"**

## Step 5: Test

Visit your LMS login page and verify the "Sign in with Google" button appears!

