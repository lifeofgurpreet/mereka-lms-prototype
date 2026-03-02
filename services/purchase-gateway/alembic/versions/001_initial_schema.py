"""Initial schema — orders, line_items, entitlements, stripe_events, audit_log.

Revision ID: 001
Revises:
Create Date: 2026-02-11
"""

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID

from alembic import op

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Orders
    op.create_table(
        "orders",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("tenant_id", UUID(as_uuid=True), nullable=False, index=True),
        sa.Column("buyer_email", sa.String(320), nullable=False, index=True),
        sa.Column("buyer_user_id", sa.Integer, nullable=True),
        sa.Column("stripe_checkout_session_id", sa.String(255), unique=True, nullable=False),
        sa.Column("stripe_payment_intent_id", sa.String(255), unique=True, nullable=True, index=True),
        sa.Column("stripe_customer_id", sa.String(255), nullable=True),
        sa.Column("status", sa.String(50), nullable=False, default="pending", index=True),
        sa.Column("total_cents", sa.Integer, nullable=False),
        sa.Column("currency", sa.String(3), nullable=False, default="USD"),
        sa.Column("fulfilled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("refunded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("metadata_json", JSONB, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # Line Items
    op.create_table(
        "line_items",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("order_id", UUID(as_uuid=True), sa.ForeignKey("orders.id"), nullable=False, index=True),
        sa.Column("offering_uuid", UUID(as_uuid=True), nullable=False),
        sa.Column("offering_type", sa.String(50), nullable=False),
        sa.Column("lms_resource_id", sa.String(255), nullable=False),
        sa.Column("quantity", sa.Integer, nullable=False, default=1),
        sa.Column("unit_price_cents", sa.Integer, nullable=False),
        sa.Column("total_price_cents", sa.Integer, nullable=False),
        sa.Column("fulfillment_status", sa.String(50), nullable=False, default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # Entitlements
    op.create_table(
        "entitlements",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("order_id", UUID(as_uuid=True), sa.ForeignKey("orders.id"), nullable=False, index=True),
        sa.Column("line_item_id", UUID(as_uuid=True), sa.ForeignKey("line_items.id"), nullable=False),
        sa.Column("tenant_id", UUID(as_uuid=True), nullable=False, index=True),
        sa.Column("recipient_email", sa.String(320), nullable=False, index=True),
        sa.Column("lms_resource_id", sa.String(255), nullable=False),
        sa.Column("offering_type", sa.String(50), nullable=False),
        sa.Column("status", sa.String(50), nullable=False, default="pending", index=True),
        sa.Column("claim_token", sa.String(64), unique=True, nullable=False),
        sa.Column("claimed_by_user_id", sa.Integer, nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("claimed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("invitation_sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # Stripe Events
    op.create_table(
        "stripe_events",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("stripe_event_id", sa.String(255), unique=True, nullable=False, index=True),
        sa.Column("event_type", sa.String(100), nullable=False, index=True),
        sa.Column("payload_json", JSONB, nullable=False),
        sa.Column("processing_status", sa.String(50), nullable=False, default="received"),
        sa.Column("received_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
    )

    # Order Audit Log
    op.create_table(
        "order_audit_log",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("order_id", UUID(as_uuid=True), sa.ForeignKey("orders.id"), nullable=False, index=True),
        sa.Column("old_status", sa.String(50), nullable=False),
        sa.Column("new_status", sa.String(50), nullable=False),
        sa.Column("triggered_by", sa.String(255), nullable=False),
        sa.Column("timestamp", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("details", JSONB, nullable=True),
    )


def downgrade() -> None:
    op.drop_table("order_audit_log")
    op.drop_table("stripe_events")
    op.drop_table("entitlements")
    op.drop_table("line_items")
    op.drop_table("orders")
