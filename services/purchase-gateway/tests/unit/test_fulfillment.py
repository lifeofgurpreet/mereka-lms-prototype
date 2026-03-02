"""Unit tests for the fulfillment engine — enrollment, entitlement creation, status resolution."""
# @covers AC-002, AC-003, AC-019, AC-020, AC-021

import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.order import FulfillmentStatus, LineItem, Order, OrderStatus
from app.services.fulfillment import fulfill_order

# ---------------------------------------------------------------------------
# Fixtures / helpers
# ---------------------------------------------------------------------------


@pytest.fixture
def mock_db():
    db = AsyncMock(spec=AsyncSession)
    db.commit = AsyncMock()
    db.add = MagicMock()
    return db


def _make_line_item(
    *,
    order_id: uuid.UUID,
    lms_resource_id: str = "course-v1:Test+101+2024",
    fulfillment_status: FulfillmentStatus = FulfillmentStatus.pending,
) -> LineItem:
    return LineItem(
        id=uuid.uuid4(),
        order_id=order_id,
        offering_uuid=uuid.UUID(int=10),
        offering_type="course_seat",
        lms_resource_id=lms_resource_id,
        quantity=1,
        unit_price_cents=5000,
        total_price_cents=5000,
        fulfillment_status=fulfillment_status,
    )


def _make_order(*, line_items: list | None = None) -> Order:
    oid = uuid.uuid4()
    order = Order(
        id=oid,
        tenant_id=uuid.UUID(int=1),
        buyer_email="buyer@example.com",
        stripe_checkout_session_id="cs_test",
        status=OrderStatus.paid,
        total_cents=5000,
        currency="USD",
    )
    order.line_items = line_items if line_items is not None else [_make_line_item(order_id=oid)]
    return order


# ---------------------------------------------------------------------------
# Feature flag disabled
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.services.fulfillment.settings")
@patch("app.services.fulfillment.LMSClient")
async def test_fulfill_order_skipped_when_flag_disabled(mock_lms_cls, mock_settings, mock_db):
    """fulfill_order is a no-op when ENABLE_GATEWAY_FULFILLMENT is False."""
    mock_settings.ENABLE_GATEWAY_FULFILLMENT = False

    order = _make_order()
    await fulfill_order(order, mock_db)

    mock_lms_cls.assert_not_called()
    mock_db.commit.assert_not_awaited()


# ---------------------------------------------------------------------------
# Happy path — user exists in LMS
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.services.fulfillment.settings")
@patch("app.services.fulfillment.LMSClient")
async def test_fulfill_order_enrolls_known_user(mock_lms_cls, mock_settings, mock_db):
    """When LMS user exists, fulfill_order enrolls them and marks order fulfilled."""
    mock_settings.ENABLE_GATEWAY_FULFILLMENT = True
    mock_settings.ENTITLEMENT_CLAIM_EXPIRY_DAYS = 30

    mock_lms = MagicMock()
    mock_lms.get_user_by_email = AsyncMock(return_value={"username": "testuser", "id": 42})
    mock_lms.enroll_user = AsyncMock(return_value=True)
    mock_lms_cls.return_value = mock_lms

    order = _make_order()
    await fulfill_order(order, mock_db)

    assert order.status == OrderStatus.fulfilled
    assert order.fulfilled_at is not None
    assert order.line_items[0].fulfillment_status == FulfillmentStatus.fulfilled
    mock_lms.enroll_user.assert_awaited_once_with(
        username="testuser", course_id="course-v1:Test+101+2024"
    )
    mock_db.commit.assert_awaited()


@pytest.mark.asyncio
@patch("app.services.fulfillment.settings")
@patch("app.services.fulfillment.LMSClient")
async def test_fulfill_order_sets_buyer_user_id(mock_lms_cls, mock_settings, mock_db):
    """fulfill_order saves the resolved LMS user ID on the order."""
    mock_settings.ENABLE_GATEWAY_FULFILLMENT = True
    mock_settings.ENTITLEMENT_CLAIM_EXPIRY_DAYS = 30

    mock_lms = MagicMock()
    mock_lms.get_user_by_email = AsyncMock(return_value={"username": "testuser", "id": 99})
    mock_lms.enroll_user = AsyncMock(return_value=True)
    mock_lms_cls.return_value = mock_lms

    order = _make_order()
    await fulfill_order(order, mock_db)

    assert order.buyer_user_id == 99


# ---------------------------------------------------------------------------
# Enrollment failure
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.services.fulfillment.settings")
@patch("app.services.fulfillment.LMSClient")
async def test_fulfill_order_enrollment_failure_marks_failed(mock_lms_cls, mock_settings, mock_db):
    """Enrollment failure marks line item as failed and order as fulfillment_failed."""
    mock_settings.ENABLE_GATEWAY_FULFILLMENT = True
    mock_settings.ENTITLEMENT_CLAIM_EXPIRY_DAYS = 30

    mock_lms = MagicMock()
    mock_lms.get_user_by_email = AsyncMock(return_value={"username": "testuser", "id": 42})
    mock_lms.enroll_user = AsyncMock(return_value=False)
    mock_lms_cls.return_value = mock_lms

    order = _make_order()
    await fulfill_order(order, mock_db)

    assert order.line_items[0].fulfillment_status == FulfillmentStatus.failed
    assert order.status == OrderStatus.fulfillment_failed


# ---------------------------------------------------------------------------
# No LMS user — entitlement path
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.services.fulfillment.settings")
@patch("app.services.fulfillment.LMSClient")
async def test_fulfill_order_creates_entitlement_for_unknown_user(
    mock_lms_cls, mock_settings, mock_db
):
    """When LMS user does not exist, fulfill_order creates an Entitlement record."""
    mock_settings.ENABLE_GATEWAY_FULFILLMENT = True
    mock_settings.ENTITLEMENT_CLAIM_EXPIRY_DAYS = 30

    mock_lms = MagicMock()
    mock_lms.get_user_by_email = AsyncMock(return_value=None)
    mock_lms_cls.return_value = mock_lms

    order = _make_order()
    await fulfill_order(order, mock_db)

    # One entitlement should be added to the DB
    mock_db.add.assert_called_once()
    from app.models.entitlement import Entitlement, EntitlementStatus

    added = mock_db.add.call_args[0][0]
    assert isinstance(added, Entitlement)
    assert added.recipient_email == "buyer@example.com"
    assert added.status == EntitlementStatus.pending
    assert added.claim_token  # non-empty token

    # Line item and order still marked fulfilled
    assert order.line_items[0].fulfillment_status == FulfillmentStatus.fulfilled
    assert order.status == OrderStatus.fulfilled


# ---------------------------------------------------------------------------
# Idempotency — already-fulfilled items are skipped
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.services.fulfillment.settings")
@patch("app.services.fulfillment.LMSClient")
async def test_fulfill_order_skips_already_fulfilled_items(mock_lms_cls, mock_settings, mock_db):
    """Items already marked fulfilled are not re-enrolled."""
    mock_settings.ENABLE_GATEWAY_FULFILLMENT = True
    mock_settings.ENTITLEMENT_CLAIM_EXPIRY_DAYS = 30

    mock_lms = MagicMock()
    mock_lms.get_user_by_email = AsyncMock(return_value={"username": "testuser", "id": 42})
    mock_lms.enroll_user = AsyncMock(return_value=True)
    mock_lms_cls.return_value = mock_lms

    oid = uuid.uuid4()
    already_done = _make_line_item(
        order_id=oid, fulfillment_status=FulfillmentStatus.fulfilled
    )
    order = _make_order(line_items=[already_done])

    await fulfill_order(order, mock_db)

    mock_lms.enroll_user.assert_not_awaited()


# ---------------------------------------------------------------------------
# Multiple line items — mixed outcomes
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.services.fulfillment.settings")
@patch("app.services.fulfillment.LMSClient")
async def test_fulfill_order_partial_failure(mock_lms_cls, mock_settings, mock_db):
    """Mixed success/failure across line items results in partially_fulfilled status."""
    mock_settings.ENABLE_GATEWAY_FULFILLMENT = True
    mock_settings.ENTITLEMENT_CLAIM_EXPIRY_DAYS = 30

    mock_lms = MagicMock()
    mock_lms.get_user_by_email = AsyncMock(return_value={"username": "testuser", "id": 42})
    # First enroll succeeds, second fails
    mock_lms.enroll_user = AsyncMock(side_effect=[True, False])
    mock_lms_cls.return_value = mock_lms

    oid = uuid.uuid4()
    items = [
        _make_line_item(order_id=oid, lms_resource_id="course-v1:A+1+2024"),
        _make_line_item(order_id=oid, lms_resource_id="course-v1:B+2+2024"),
    ]
    order = _make_order(line_items=items)

    await fulfill_order(order, mock_db)

    assert items[0].fulfillment_status == FulfillmentStatus.fulfilled
    assert items[1].fulfillment_status == FulfillmentStatus.failed
    assert order.status == OrderStatus.partially_fulfilled
