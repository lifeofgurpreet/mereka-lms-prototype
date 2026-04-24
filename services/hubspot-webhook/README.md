# HubSpot Webhook Service

Firebase Cloud Functions service for processing HubSpot webhooks and integrating with Microsoft Community Training (MCT).

## Overview

This service receives webhooks from HubSpot and processes them to sync data with MCT and send notifications via SendGrid.

**Status**: This service is being migrated from Firebase Cloud Functions to Kubernetes. See the related specification for migration details.

## Setup

1. Install Firebase CLI:
```bash
npm install -g firebase-tools
```

2. Login to Firebase:
```bash
firebase login
```

3. Install dependencies:
```bash
cd functions
npm install
```

4. Configure environment variables (see below)

## Environment Variables

Configure in Firebase Console → Functions → Config or using `.env` file for local development.

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `HUBSPOT_PAT` | HubSpot Private Access Token | `pat-na1-xxx...` |
| `HUBSPOT_WEBHOOK_SECRET` | HubSpot webhook signing secret (v3) | `your-webhook-secret` |
| `HUBSPOT_REGISTRATION_ENABLED` | Feature flag to enable/disable registration | `true` or `false` |
| `MCT_ENDPT` | MCT endpoint hostname | `your-mct.example.com` |
| `MCT_CLIENT_ID` | MCT OAuth client ID | `uuid` |
| `MCT_CLIENT_SECRET` | MCT OAuth client secret | `secret` |
| `MCT_API_URI` | MCT API URI | `api://uuid` |
| `MCT_TENANT_ID` | Azure tenant ID | `uuid` |
| `AZURE_TENANT_ID` | Azure AD B2C tenant ID | `uuid` |
| `AZURE_CLIENT_ID` | Azure AD B2C client ID | `uuid` |
| `AZURE_CLIENT_SECRET` | Azure AD B2C client secret | `secret` |
| `SGRID_API_KEY` | SendGrid API key | `SG.xxx...` |
| `SGRID_FROM_EMAIL` | SendGrid sender email | `team@example.com` |
| `ERROR_NOTIFICATION_EMAILS` | Comma-separated error notification recipients | `admin1@example.com,admin2@example.com` |

Copy `.env.example` to `.env` and fill in your values for local development.

## Security Features

### HubSpot Webhook Signature Verification

This service implements HubSpot webhook signature verification (v3) to ensure requests are authentic. Configure `HUBSPOT_WEBHOOK_SECRET` in your environment to enable verification.

The signature verification:
- Uses HMAC-SHA256 with your webhook secret
- Validates the `x-hubspot-signature-v3` header
- Checks request timestamp to prevent replay attacks

### Feature Flag

The service includes a feature flag `HUBSPOT_REGISTRATION_ENABLED` to control whether user registration is active. Set to `true` to enable, `false` to disable. When disabled, the webhook endpoint returns HTTP 503.

### Cryptographically Secure Password Generation

User passwords are generated using `crypto.randomBytes()` for cryptographic security, not `Math.random()`.

## Deployment

```bash
firebase deploy --only functions
```

## Local Development

```bash
cd functions
npm install
firebase emulators:start --only functions
```

## API Endpoints

### POST /api/createUser

Webhook endpoint for HubSpot contact creation events.

**Headers:**
- `x-hubspot-signature-v3` - HubSpot webhook signature (required)
- `x-hubspot-request-timestamp` - Request timestamp (required)

**Response:**
- `200` - Success
- `401` - Unauthorized (invalid signature)
- `503` - Service disabled by feature flag

## Notes

- Uses Firebase Firestore for data persistence
- Integrates with Microsoft Graph API for Azure AD B2C user creation
- Sends emails via SendGrid
- Scheduled function runs hourly to send delayed emails

