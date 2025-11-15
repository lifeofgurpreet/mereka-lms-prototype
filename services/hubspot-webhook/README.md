# HubSpot Webhook Service

Firebase Cloud Functions service for processing HubSpot webhooks and integrating with Microsoft Community Training (MCT).

## Overview

This service receives webhooks from HubSpot and processes them to sync data with MCT and send notifications via SendGrid.

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

## Deployment

```bash
firebase deploy --only functions
```

## Environment Variables

Configure in Firebase Console → Functions → Config:

- `MCT_ENDPT` - MCT endpoint URL
- `MCT_CLIENT_ID` - MCT client ID
- `MCT_CLIENT_SECRET` - MCT client secret
- `SGRID_API_KEY` - SendGrid API key
- `SGRID_FROM_EMAIL` - SendGrid sender email

## Local Development

```bash
cd functions
npm install
firebase emulators:start --only functions
```

## Notes

- Uses Firebase Firestore for data persistence
- Integrates with Microsoft Graph API
- Sends emails via SendGrid

