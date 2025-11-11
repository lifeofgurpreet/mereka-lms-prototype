# Kajabi Webhook Receiver

A tiny FastAPI app that verifies Kajabi webhook signatures, persists every event as NDJSON, and responds quickly so Kajabi does not retry unnecessarily. Ship it to Cloud Run, Cloud Functions, or any container runtime you prefer.

## Features

- HMAC-SHA256 signature verification against `KAJABI_WEBHOOK_SECRET`.
- Accepts the standard event types (`purchase`, `payment_succeeded`, `order_created`, `form_submission`, `tag_added`, `tag_removed`). Unknown events are still stored but prefixed with `unknown__` so you can discover new payloads.
- Streams each event to `<outbox>/<event>.ndjson` so downstream processors can tail or sync them without blocking the HTTP request.
- Simple `/healthz` endpoint for readiness probes.

## Running locally

```bash
cd ops/migrations/kajabi/webhook_app
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
KAJABI_WEBHOOK_SECRET=devsecret \
KAJABI_WEBHOOK_OUTBOX=$(pwd)/outbox \
uvicorn main:APP --reload --host 0.0.0.0 --port 8080
```

Test with curl:

```bash
BODY='{"event":"purchase","data":{"id":123}}'
SIG=$(printf "%s" "$BODY" | openssl dgst -sha256 -hmac devsecret | awk '{print $2}')
curl -i -H "X-Kajabi-Signature=$SIG" -H "Content-Type: application/json" \
     -d "$BODY" http://localhost:8080/webhooks/kajabi
```

## Container deployment

A minimal Dockerfile is included. Build/push and run on Cloud Run (or similar):

```bash
cd ops/migrations/kajabi/webhook_app
docker build -t gcr.io/PROJECT/kajabi-webhook:latest .
docker push gcr.io/PROJECT/kajabi-webhook:latest

gcloud run deploy kajabi-webhook \
  --image gcr.io/PROJECT/kajabi-webhook:latest \
  --region asia-southeast1 \
  --set-env-vars KAJABI_WEBHOOK_SECRET=prodsecret,KAJABI_WEBHOOK_OUTBOX=/tmp/outbox \
  --allow-unauthenticated
```

Mount a Cloud Storage bucket or persistent disk if you want durable outbox files; otherwise pipe them to stdout by swapping `_append_event` with a Pub/Sub publisher.

## Wiring Kajabi

1. Deploy the service and note the HTTPS URL (e.g., `https://kajabi-webhook-xyz.a.run.app/webhooks/kajabi`).
2. Either create webhooks manually in the Kajabi UI or rerun the exporter with `--ensure-webhooks --webhook-target <URL>` so every standard event starts POSTing to the receiver.
3. Configure retries/alerts on Cloud Run (or whichever platform) so a failing receiver is detectable.
4. Point your downstream worker at `outbox/*.ndjson` (or Pub/Sub if you adapt the writer) to convert each event into the relevant Open edX actions.
