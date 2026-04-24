import enum
import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TenantMixin, TimestampMixin

if TYPE_CHECKING:
    from app.models.order import Order


class FulfillmentJobStatus(enum.StrEnum):
    pending = "pending"
    processing = "processing"
    succeeded = "succeeded"
    failed = "failed"
    dead_letter = "dead_letter"


class FulfillmentJob(Base, TenantMixin, TimestampMixin):
    __tablename__ = "fulfillment_jobs"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    order_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("orders.id"),
        nullable=False,
        unique=True,
        index=True,
    )
    status: Mapped[FulfillmentJobStatus] = mapped_column(
        Enum(FulfillmentJobStatus, native_enum=False),
        nullable=False,
        default=FulfillmentJobStatus.pending,
        index=True,
    )
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    max_attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=10)
    next_attempt_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        index=True,
    )
    last_attempt_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_error: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    triggered_by: Mapped[str] = mapped_column(String(255), nullable=False, default="unknown")

    order: Mapped["Order"] = relationship(back_populates="fulfillment_job", lazy="selectin")
