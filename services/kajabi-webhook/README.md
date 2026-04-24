# Kajabi Webhook Service

FastAPI webhook receiver for Kajabi events. Verifies HMAC signatures and persists events to an outbox for downstream processing.

## Overview

This service receives webhooks from Kajabi, verifies the HMAC signature, and writes events to an NDJSON outbox file. Downstream workers can process these events to sync data with Open edX.

## Setup

1. Create virtual environment:
```bash
python3 -m venv .venv
source .venv/bin/activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

## Configuration

Set environment variables:

- `KAJABI_WEBHOOK_SECRET` - Secret key for HMAC verification (required)
- `KAJABI_WEBHOOK_OUTBOX` - Path to outbox directory (default: `var/services/kajabi-webhook/outbox`)

## Running

```bash
uvicorn main:APP --host 0.0.0.0 --port 8000
```

Or with Docker:

```bash
docker build -t kajabi-webhook .
docker run -p 8000:8000 -e KAJABI_WEBHOOK_SECRET=your-secret kajabi-webhook
```

## Endpoints

- `POST /webhook` - Receive Kajabi webhook events
- `GET /health` - Health check endpoint

## Supported Events

- `purchase`
- `payment_succeeded`
- `order_created`
- `form_submission`
- `tag_added`
- `tag_removed`

## Outbox Format

Events are written as NDJSON (newline-delimited JSON) to the outbox directory:

```json
{"event": "purchase", "timestamp": "2024-01-01T00:00:00Z", "data": {...}}
```

## Security

- HMAC signature verification using `X-Kajabi-Signature` header
- Secret key must match Kajabi webhook configuration
