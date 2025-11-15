#!/usr/bin/env python3
"""Minimal FastAPI receiver for Kajabi webhooks.

The handler verifies the HMAC signature Kajabi includes in the
`X-Kajabi-Signature` header, persists each event to an NDJSON outbox, and
provides a health endpoint for monitoring. Downstream workers can tail the
outbox directory (or ship it into Pub/Sub) to perform incremental updates in
Open edX.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict

from fastapi import FastAPI, Header, HTTPException, Request, Response, status

APP = FastAPI(title="Kajabi Webhook Receiver", version="0.1.0")

WEBHOOK_SECRET = os.environ.get("KAJABI_WEBHOOK_SECRET")
OUTBOX_DIR = Path(
    os.environ.get(
        "KAJABI_WEBHOOK_OUTBOX",
        "var/services/kajabi-webhook/outbox",
    )
)
OUTBOX_DIR.mkdir(parents=True, exist_ok=True)

SIGNATURE_HEADER = "X-Kajabi-Signature"
VALID_EVENTS = {
    "purchase",
    "payment_succeeded",
    "order_created",
    "form_submission",
    "tag_added",
    "tag_removed",
}


def _compute_signature(raw_body: bytes) -> str:
    if not WEBHOOK_SECRET:
        raise RuntimeError("KAJABI_WEBHOOK_SECRET is not configured")
    digest = hmac.new(
        WEBHOOK_SECRET.encode("utf-8"), raw_body, hashlib.sha256
    ).hexdigest()
    return digest


def _normalize_header(header_value: str | None) -> str:
    if not header_value:
        return ""
    if header_value.lower().startswith("sha256="):
        return header_value.split("=", 1)[1]
    return header_value.strip()


def _append_event(event: str, payload: Dict[str, Any]) -> None:
    ts = datetime.now(timezone.utc).isoformat()
    out_path = OUTBOX_DIR / f"{event}.ndjson"
    record = {
        "received_at": ts,
        "event": event,
        "payload": payload,
    }
    with out_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, separators=(",", ":")))
        handle.write("\n")


@APP.get("/healthz")
async def healthcheck() -> dict[str, str]:
    """Simple readiness probe."""
    if not WEBHOOK_SECRET:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Missing KAJABI_WEBHOOK_SECRET",
        )
    return {"status": "ok"}


@APP.post("/webhooks/kajabi")
async def kajabi_webhook(
    request: Request,
    x_kajabi_signature: str | None = Header(None, convert_underscores=False),
) -> Response:
    raw_body = await request.body()
    header_sig = _normalize_header(x_kajabi_signature)
    computed_sig = _compute_signature(raw_body)
    if not header_sig or not hmac.compare_digest(header_sig, computed_sig):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="signature mismatch")

    try:
        payload = await request.json()
    except Exception as exc:  # pragma: no cover - FastAPI already validated JSON
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    event = None
    if isinstance(payload, dict):
        event = payload.get("event") or payload.get("type")
    if not isinstance(event, str) or not event:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="missing event key")

    if event not in VALID_EVENTS:
        # accept unknown events but tag them to separate file
        event = f"unknown__{event}"

    _append_event(event, payload)
    return Response(status_code=status.HTTP_202_ACCEPTED)


if __name__ == "__main__":  # pragma: no cover
    import uvicorn

    uvicorn.run("main:APP", host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
