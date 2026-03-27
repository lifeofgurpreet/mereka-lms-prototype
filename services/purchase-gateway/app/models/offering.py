# @covers AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import enum
import uuid

from sqlalchemy import Boolean, Enum, Integer, String, Uuid
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TenantMixin, TimestampMixin


class OfferingType(enum.StrEnum):
    course_seat = "course_seat"
    program = "program"
    seat_pack = "seat_pack"


class Offering(Base, TenantMixin, TimestampMixin):
    __tablename__ = "offerings"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    offering_type: Mapped[OfferingType] = mapped_column(
        Enum(OfferingType, native_enum=False), nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    price_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="USD")
    stripe_price_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    lms_resource_id: Mapped[str] = mapped_column(String(255), nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
