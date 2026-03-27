# Services Directory

This directory contains standalone microservices and webhook receivers.

## Structure

```
services/
├── hubspot-webhook/    # Firebase Cloud Functions for HubSpot webhooks
└── kajabi-webhook/     # FastAPI webhook receiver for Kajabi events
```

## Service Standards

Each service should have:

- `README.md` - Service documentation, setup, and deployment
- `.env.example` - Environment variable template
- `Dockerfile` (if containerized)
- Tests (unit/integration)
- CI/CD configuration

## Usage

### HubSpot Webhook

Firebase Cloud Functions service for processing HubSpot webhooks.

```bash
cd services/hubspot-webhook
firebase deploy --only functions
```

### Kajabi Webhook

FastAPI webhook receiver for Kajabi events.

```bash
cd services/kajabi-webhook
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:APP --host 0.0.0.0 --port 8000
```

## Outputs

Service outputs (logs, outbox files) go to `var/services/` (gitignored).

