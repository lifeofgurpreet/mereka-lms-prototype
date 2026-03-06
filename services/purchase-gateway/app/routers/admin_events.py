"""Admin endpoints for Stripe event inspection."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_admin_api_key
from app.database import get_db
from app.models.stripe_event import ProcessingStatus, StripeEvent

router = APIRouter(tags=["admin"], dependencies=[Depends(require_admin_api_key)])


class StripeEventSummaryResponse(BaseModel):
    id: uuid.UUID
    stripe_event_id: str
    event_type: str
    processing_status: str
    received_at: datetime
    processed_at: datetime | None
    payload_json: dict | None = None


@router.get("/admin/stripe-events/", response_model=list[StripeEventSummaryResponse])
async def list_stripe_events(
    db: AsyncSession = Depends(get_db),
    event_type: str | None = Query(default=None),
    processing_status: ProcessingStatus | None = Query(default=None),
    stripe_event_id: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    include_payload: bool = Query(default=False),
):
    """List Stripe events with optional filtering for debugging."""
    query = select(StripeEvent)

    if event_type:
        query = query.where(StripeEvent.event_type == event_type)
    if processing_status:
        query = query.where(StripeEvent.processing_status == processing_status)
    if stripe_event_id:
        query = query.where(StripeEvent.stripe_event_id == stripe_event_id)

    query = query.order_by(StripeEvent.received_at.desc()).offset(offset).limit(limit)
    result = await db.execute(query)
    events = result.scalars().all()

    return [
        StripeEventSummaryResponse(
            id=event.id,
            stripe_event_id=event.stripe_event_id,
            event_type=event.event_type,
            processing_status=event.processing_status.value,
            received_at=event.received_at,
            processed_at=event.processed_at,
            payload_json=event.payload_json if include_payload else None,
        )
        for event in events
    ]
