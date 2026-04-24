import enum
import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, Uuid, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TenantMixin, TimestampMixin

if TYPE_CHECKING:
    from app.models.fulfillment_job import FulfillmentJob


class OrderStatus(enum.StrEnum):
    pending = "pending"
    paid = "paid"
    fulfilling = "fulfilling"
    fulfilled = "fulfilled"
    partially_fulfilled = "partially_fulfilled"
    fulfillment_failed = "fulfillment_failed"
    refunded = "refunded"
    partially_refunded = "partially_refunded"
    disputed = "disputed"
    expired = "expired"
    canceled = "canceled"


class FulfillmentStatus(enum.StrEnum):
    pending = "pending"
    fulfilled = "fulfilled"
    failed = "failed"
    revoked = "revoked"


class Order(Base, TenantMixin, TimestampMixin):
    __tablename__ = "orders"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid.uuid4
    )
    buyer_email: Mapped[str] = mapped_column(String(320), nullable=False, index=True)
    buyer_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    stripe_checkout_session_id: Mapped[str] = mapped_column(
        String(255), unique=True, nullable=False
    )
    stripe_payment_intent_id: Mapped[str | None] = mapped_column(
        String(255), unique=True, nullable=True, index=True
    )
    stripe_customer_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[OrderStatus] = mapped_column(
        Enum(OrderStatus, native_enum=False),
        default=OrderStatus.pending,
        nullable=False,
        index=True,
    )
    total_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="USD")
    fulfilled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    refunded_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    metadata_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    line_items: Mapped[list["LineItem"]] = relationship(back_populates="order", lazy="selectin")
    fulfillment_job: Mapped["FulfillmentJob | None"] = relationship(
        back_populates="order",
        lazy="selectin",
        uselist=False,
    )


class LineItem(Base, TimestampMixin):
    __tablename__ = "line_items"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid.uuid4
    )
    order_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("orders.id"), nullable=False, index=True
    )
    offering_uuid: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    offering_type: Mapped[str] = mapped_column(String(50), nullable=False)
    lms_resource_id: Mapped[str] = mapped_column(String(255), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    unit_price_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    total_price_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    fulfillment_status: Mapped[FulfillmentStatus] = mapped_column(
        Enum(FulfillmentStatus, native_enum=False),
        default=FulfillmentStatus.pending,
        nullable=False,
    )

    order: Mapped["Order"] = relationship(back_populates="line_items")


class OrderAuditLog(Base):
    __tablename__ = "order_audit_log"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid.uuid4
    )
    order_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("orders.id"), nullable=False, index=True
    )
    old_status: Mapped[str] = mapped_column(String(50), nullable=False)
    new_status: Mapped[str] = mapped_column(String(50), nullable=False)
    triggered_by: Mapped[str] = mapped_column(String(255), nullable=False)
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    details: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
