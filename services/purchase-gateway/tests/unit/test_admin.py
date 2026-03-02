"""Unit tests for admin endpoints — offerings CRUD, bulk entitlement assign, orders list."""
# @covers AC-019, AC-020, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from app.models.offering import Offering, OfferingType
from app.models.order import Order, OrderStatus
from app.routers.admin import (
    BulkAssignRequest,
    CreateOfferingRequest,
    UpdateOfferingRequest,
    bulk_assign_entitlements,
    create_offering,
    list_orders,
    update_offering,
)
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

# ---------------------------------------------------------------------------
# Fixtures / helpers
# ---------------------------------------------------------------------------


TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")
ORDER_ID = uuid.UUID("00000000-0000-0000-0000-000000000002")
LINE_ITEM_ID = uuid.UUID("00000000-0000-0000-0000-000000000003")


@pytest.fixture
def mock_db():
    db = AsyncMock(spec=AsyncSession)
    db.commit = AsyncMock()
    db.add = MagicMock()
    db.refresh = AsyncMock()
    db.rollback = AsyncMock()
    return db


def _mock_select_result(obj):
    result = MagicMock()
    result.scalar_one_or_none.return_value = obj
    return result


def _mock_scalars_result(objects):
    scalars = MagicMock()
    scalars.all.return_value = objects
    result = MagicMock()
    result.scalars.return_value = scalars
    return result


def _make_offering(**overrides) -> Offering:
    defaults = {
        "id": uuid.uuid4(),
        "tenant_id": TENANT_ID,
        "offering_type": OfferingType.course_seat,
        "title": "Test Course",
        "description": "A test offering",
        "price_cents": 9900,
        "currency": "USD",
        "stripe_price_id": "price_test_123",
        "lms_resource_id": "course-v1:Test+101+2024",
        "active": True,
        "metadata_json": None,
        "created_at": datetime(2024, 1, 1, tzinfo=UTC),
        "updated_at": datetime(2024, 1, 1, tzinfo=UTC),
    }
    defaults.update(overrides)
    return Offering(**defaults)


def _make_order(**overrides) -> Order:
    defaults = {
        "id": ORDER_ID,
        "tenant_id": TENANT_ID,
        "buyer_email": "buyer@example.com",
        "stripe_checkout_session_id": "cs_test_admin",
        "status": OrderStatus.fulfilled,
        "total_cents": 9900,
        "currency": "USD",
        "fulfilled_at": None,
        "refunded_at": None,
    }
    defaults.update(overrides)
    return Order(**defaults)


def _make_create_request(**overrides):
    defaults = {
        "offering_type": OfferingType.course_seat,
        "title": "Test Course",
        "description": "A test offering",
        "price_cents": 9900,
        "currency": "USD",
        "stripe_price_id": "price_test_123",
        "lms_resource_id": "course-v1:Test+101+2024",
        "tenant_id": TENANT_ID,
        "active": True,
        "metadata": None,
    }
    defaults.update(overrides)
    return CreateOfferingRequest(**defaults)


# ---------------------------------------------------------------------------
# create_offering
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_create_offering_persists_and_returns_offering(mock_db):
    """create_offering adds the offering to DB, commits, and refreshes."""
    request_body = _make_create_request()

    # After refresh, db.refresh sets the id on the offering
    async def _fake_refresh(obj):
        if not obj.created_at:
            obj.created_at = datetime(2024, 1, 1, tzinfo=UTC)
        if not obj.updated_at:
            obj.updated_at = datetime(2024, 1, 1, tzinfo=UTC)

    mock_db.refresh.side_effect = _fake_refresh

    result = await create_offering(request_body, mock_db)

    mock_db.add.assert_called_once()
    mock_db.commit.assert_awaited_once()
    mock_db.refresh.assert_awaited_once()
    assert result.title == "Test Course"
    assert result.price_cents == 9900
    assert result.tenant_id == TENANT_ID


@pytest.mark.asyncio
async def test_create_offering_with_zero_price_raises_422():
    """price_cents=0 fails Pydantic validation (Field gt=0)."""
    with pytest.raises(ValidationError):
        _make_create_request(price_cents=0)


@pytest.mark.asyncio
async def test_create_offering_with_negative_price_raises_422():
    """Negative price_cents fails Pydantic validation."""
    with pytest.raises(ValidationError):
        _make_create_request(price_cents=-100)


# ---------------------------------------------------------------------------
# update_offering
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_update_offering_modifies_fields(mock_db):
    """update_offering updates title, description, price_cents, active, metadata_json."""
    existing = _make_offering()
    mock_db.execute.return_value = _mock_select_result(existing)

    request_body = UpdateOfferingRequest(
        title="Updated Title",
        description="New description",
        price_cents=4999,
        active=False,
        metadata={"key": "value"},
    )

    async def _fake_refresh(obj):
        pass

    mock_db.refresh.side_effect = _fake_refresh

    result = await update_offering(existing.id, request_body, mock_db)

    assert result.title == "Updated Title"
    assert result.description == "New description"
    assert result.price_cents == 4999
    assert result.active is False
    assert result.metadata_json == {"key": "value"}
    mock_db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_update_offering_not_found_raises_404(mock_db):
    """update_offering raises 404 when offering does not exist."""
    mock_db.execute.return_value = _mock_select_result(None)

    request_body = UpdateOfferingRequest(title="New Title")

    with pytest.raises(HTTPException) as exc_info:
        await update_offering(uuid.uuid4(), request_body, mock_db)

    assert exc_info.value.status_code == 404


@pytest.mark.asyncio
async def test_update_offering_with_zero_price_raises_422():
    """price_cents=0 in UpdateOfferingRequest fails Pydantic validation."""
    with pytest.raises(ValidationError):
        UpdateOfferingRequest(price_cents=0)


@pytest.mark.asyncio
async def test_update_offering_partial_update_only_changes_provided_fields(mock_db):
    """Providing only title in UpdateOfferingRequest does not touch other fields."""
    existing = _make_offering(price_cents=9900, active=True)
    mock_db.execute.return_value = _mock_select_result(existing)

    request_body = UpdateOfferingRequest(title="New Title Only")

    async def _fake_refresh(obj):
        pass

    mock_db.refresh.side_effect = _fake_refresh

    result = await update_offering(existing.id, request_body, mock_db)

    assert result.title == "New Title Only"
    assert result.price_cents == 9900  # unchanged
    assert result.active is True  # unchanged


# ---------------------------------------------------------------------------
# bulk_assign_entitlements
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_bulk_assign_creates_entitlements_for_new_emails(mock_db):
    """bulk_assign_entitlements creates an Entitlement record per unique email."""
    order = _make_order()

    existing_emails_result = MagicMock()
    existing_emails_result.all.return_value = []

    # First execute call: order lookup; second: existing email check
    mock_db.execute.side_effect = [
        _mock_select_result(order),
        existing_emails_result,
    ]

    request_body = BulkAssignRequest(
        order_id=ORDER_ID,
        line_item_id=LINE_ITEM_ID,
        lms_resource_id="course-v1:Test+101+2024",
        offering_type="course_seat",
        tenant_id=TENANT_ID,
        emails=["alice@example.com", "bob@example.com"],
    )

    with patch("app.routers.admin.settings") as mock_settings:
        mock_settings.ENTITLEMENT_CLAIM_EXPIRY_DAYS = 30
        result = await bulk_assign_entitlements(request_body, mock_db)

    assert result.created == 2
    assert result.skipped == 0
    assert len(result.entitlement_ids) == 2
    assert mock_db.add.call_count == 2
    mock_db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_bulk_assign_skips_already_assigned_emails(mock_db):
    """bulk_assign_entitlements skips emails that already have entitlements."""
    order = _make_order()

    existing_emails_result = MagicMock()
    existing_emails_result.all.return_value = [("alice@example.com",)]

    mock_db.execute.side_effect = [
        _mock_select_result(order),
        existing_emails_result,
    ]

    request_body = BulkAssignRequest(
        order_id=ORDER_ID,
        line_item_id=LINE_ITEM_ID,
        lms_resource_id="course-v1:Test+101+2024",
        offering_type="course_seat",
        tenant_id=TENANT_ID,
        emails=["alice@example.com", "bob@example.com"],
    )

    with patch("app.routers.admin.settings") as mock_settings:
        mock_settings.ENTITLEMENT_CLAIM_EXPIRY_DAYS = 30
        result = await bulk_assign_entitlements(request_body, mock_db)

    assert result.created == 1
    assert result.skipped == 1
    assert len(result.entitlement_ids) == 1


@pytest.mark.asyncio
async def test_bulk_assign_more_than_500_emails_returns_400(mock_db):
    """bulk_assign_entitlements returns 400 when email list exceeds 500."""
    # Provide an order so the guard check runs first
    mock_db.execute.return_value = _mock_select_result(_make_order())

    emails = [f"user{i}@example.com" for i in range(501)]
    request_body = BulkAssignRequest(
        order_id=ORDER_ID,
        line_item_id=LINE_ITEM_ID,
        lms_resource_id="course-v1:Test+101+2024",
        offering_type="course_seat",
        tenant_id=TENANT_ID,
        emails=emails,
    )

    with pytest.raises(HTTPException) as exc_info:
        await bulk_assign_entitlements(request_body, mock_db)

    assert exc_info.value.status_code == 400
    assert "500" in exc_info.value.detail


@pytest.mark.asyncio
async def test_bulk_assign_order_not_found_returns_404(mock_db):
    """bulk_assign_entitlements returns 404 when the referenced order does not exist."""
    mock_db.execute.return_value = _mock_select_result(None)

    request_body = BulkAssignRequest(
        order_id=uuid.uuid4(),
        line_item_id=LINE_ITEM_ID,
        lms_resource_id="course-v1:Test+101+2024",
        offering_type="course_seat",
        tenant_id=TENANT_ID,
        emails=["user@example.com"],
    )

    with pytest.raises(HTTPException) as exc_info:
        await bulk_assign_entitlements(request_body, mock_db)

    assert exc_info.value.status_code == 404


@pytest.mark.asyncio
async def test_bulk_assign_each_entitlement_has_unique_claim_token(mock_db):
    """Each created Entitlement gets a unique claim_token."""
    order = _make_order()

    existing_emails_result = MagicMock()
    existing_emails_result.all.return_value = []

    mock_db.execute.side_effect = [
        _mock_select_result(order),
        existing_emails_result,
    ]

    request_body = BulkAssignRequest(
        order_id=ORDER_ID,
        line_item_id=LINE_ITEM_ID,
        lms_resource_id="course-v1:Test+101+2024",
        offering_type="course_seat",
        tenant_id=TENANT_ID,
        emails=["a@example.com", "b@example.com", "c@example.com"],
    )

    with patch("app.routers.admin.settings") as mock_settings:
        mock_settings.ENTITLEMENT_CLAIM_EXPIRY_DAYS = 30
        await bulk_assign_entitlements(request_body, mock_db)

    added_entitlements = [call[0][0] for call in mock_db.add.call_args_list]
    tokens = [e.claim_token for e in added_entitlements]
    assert len(tokens) == len(set(tokens)), "Claim tokens must be unique"


# ---------------------------------------------------------------------------
# list_orders
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_list_orders_returns_all_orders(mock_db):
    """list_orders returns all matching orders without filters."""
    orders = [_make_order(), _make_order(id=uuid.uuid4())]
    mock_db.execute.return_value = _mock_scalars_result(orders)

    request = MagicMock()
    request.state = MagicMock(spec=[])  # no tenant_id attribute

    result = await list_orders(
        request=request,
        db=mock_db,
        tenant_id=None,
        status=None,
        buyer_email=None,
        limit=50,
        offset=0,
    )

    assert result == orders


@pytest.mark.asyncio
async def test_list_orders_filters_by_status(mock_db):
    """list_orders passes status filter to the query."""
    paid_order = _make_order(status=OrderStatus.paid)
    mock_db.execute.return_value = _mock_scalars_result([paid_order])

    request = MagicMock()
    request.state = MagicMock(spec=[])

    result = await list_orders(
        request=request,
        db=mock_db,
        status="paid",
        tenant_id=None,
        buyer_email=None,
        limit=50,
        offset=0,
    )

    assert result == [paid_order]


@pytest.mark.asyncio
async def test_list_orders_filters_by_buyer_email(mock_db):
    """list_orders with buyer_email filter returns matching orders."""
    order = _make_order(buyer_email="specific@example.com")
    mock_db.execute.return_value = _mock_scalars_result([order])

    request = MagicMock()
    request.state = MagicMock(spec=[])

    result = await list_orders(
        request=request,
        db=mock_db,
        tenant_id=None,
        status=None,
        buyer_email="specific@example.com",
        limit=50,
        offset=0,
    )

    assert len(result) == 1
    assert result[0].buyer_email == "specific@example.com"


@pytest.mark.asyncio
async def test_list_orders_with_tenant_filter(mock_db):
    """list_orders applies tenant_id filter when provided."""
    order = _make_order()
    mock_db.execute.return_value = _mock_scalars_result([order])

    request = MagicMock()
    request.state = MagicMock(spec=[])  # no middleware tenant_id

    result = await list_orders(
        request=request,
        db=mock_db,
        tenant_id=TENANT_ID,
        status=None,
        buyer_email=None,
        limit=50,
        offset=0,
    )

    assert mock_db.execute.await_count == 1
    assert result == [order]
