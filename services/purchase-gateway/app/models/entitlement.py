import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TenantMixin, TimestampMixin


class EntitlementStatus(str, enum.Enum):
    pending = "pending"
    claimed = "claimed"
    expired = "expired"
    revoked = "revoked"


class Entitlement(Base, TenantMixin, TimestampMixin):
    __tablename__ = "entitlements"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid.uuid4
    )
    order_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("orders.id"), nullable=False, index=True
    )
    line_item_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("line_items.id"), nullable=False
    )
    recipient_email: Mapped[str] = mapped_column(String(320), nullable=False, index=True)
    lms_resource_id: Mapped[str] = mapped_column(String(255), nullable=False)
    offering_type: Mapped[str] = mapped_column(String(50), nullable=False)
    status: Mapped[EntitlementStatus] = mapped_column(
        Enum(EntitlementStatus, native_enum=False),
        default=EntitlementStatus.pending,
        nullable=False,
        index=True,
    )
    claim_token: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    claimed_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    claimed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    invitation_sent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
