"""Integration tests for admin endpoints — HTTP-level auth, validation, and CRUD via client."""
# @covers AC-019, AC-020, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.database import get_db
from app.main import app
from app.models.offering import Offering, OfferingType
from app.models.order import Order, OrderStatus

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


TENANT_ID = str(uuid.UUID("00000000-0000-0000-0000-000000000001"))
ORDER_ID = uuid.UUID("00000000-0000-0000-0000-000000000002")
LINE_ITEM_ID = uuid.UUID("00000000-0000-0000-0000-000000000003")

VALID_API_KEY = "test-admin-key-for-integration"
HEADERS = {"X-API-Key": VALID_API_KEY}

VALID_OFFERING_PAYLOAD = {
    "offering_type": "course_seat",
    "title": "Test Course",
    "description": "A test offering",
    "price_cents": 9900,
    "currency": "USD",
    "stripe_price_id": "price_test_123",
    "lms_resource_id": "course-v1:Test+101+2024",
    "tenant_id": TENANT_ID,
    "active": True,
}


def _make_offering(**overrides) -> Offering:
    defaults = {
        "id": uuid.uuid4(),
        "tenant_id": uuid.UUID(TENANT_ID),
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
        "tenant_id": uuid.UUID(TENANT_ID),
        "buyer_email": "buyer@example.com",
        "stripe_checkout_session_id": "cs_test_integ",
        "status": OrderStatus.fulfilled,
        "total_cents": 9900,
        "currency": "USD",
        "fulfilled_at": None,
        "refunded_at": None,
    }
    defaults.update(overrides)
    return Order(**defaults)


def _make_mock_db(*, offering=None, order=None, scalars_result=None):
    """Build an AsyncMock DB session with configurable query results."""
    mock_db = AsyncMock()
    mock_db.commit = AsyncMock()
    mock_db.add = MagicMock()

    async def _fake_refresh(obj):
        pass

    mock_db.refresh.side_effect = _fake_refresh

    def _select_result(obj):
        r = MagicMock()
        r.scalar_one_or_none.return_value = obj
        return r

    def _scalars_list(objects):
        scalars = MagicMock()
        scalars.all.return_value = objects or []
        r = MagicMock()
        r.scalars.return_value = scalars
        return r

    mock_db.execute.return_value = _select_result(offering or order)
    return mock_db


def _override_db(mock_db):
    async def _get_db_override():
        yield mock_db

    app.dependency_overrides[get_db] = _get_db_override


def _clear_overrides():
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Auth tests via HTTP — creates offering endpoint
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_create_offering_without_api_key_returns_401(mock_settings, client):
    """POST /admin/offerings/ without X-API-Key → 401."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    resp = await client.post("/api/v1/admin/offerings/", json=VALID_OFFERING_PAYLOAD)

    assert resp.status_code == 401


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_create_offering_with_wrong_api_key_returns_403(mock_settings, client):
    """POST /admin/offerings/ with wrong X-API-Key → 403."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    resp = await client.post(
        "/api/v1/admin/offerings/",
        json=VALID_OFFERING_PAYLOAD,
        headers={"X-API-Key": "wrong-key"},
    )

    assert resp.status_code == 403


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_create_offering_with_correct_api_key_reaches_handler(mock_settings, client):
    """POST /admin/offerings/ with correct X-API-Key → auth passes (not 401/403)."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    # Use a DB mock that sets timestamps on refresh so OfferingResponse validation passes
    mock_db = AsyncMock()
    mock_db.commit = AsyncMock()
    mock_db.add = MagicMock()

    async def _fake_refresh(obj):
        if not getattr(obj, "created_at", None):
            obj.created_at = datetime(2024, 1, 1, tzinfo=UTC)
        if not getattr(obj, "updated_at", None):
            obj.updated_at = datetime(2024, 1, 1, tzinfo=UTC)

    mock_db.refresh.side_effect = _fake_refresh

    _override_db(mock_db)
    try:
        resp = await client.post(
            "/api/v1/admin/offerings/",
            json=VALID_OFFERING_PAYLOAD,
            headers=HEADERS,
        )
    finally:
        _clear_overrides()

    # Auth passed — not 401/403. Handler returned 201 with valid response.
    assert resp.status_code == 201


# ---------------------------------------------------------------------------
# Validation tests via HTTP
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_create_offering_with_zero_price_returns_422(mock_settings, client):
    """POST /admin/offerings/ with price_cents=0 → 422 Unprocessable Entity."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    payload = {**VALID_OFFERING_PAYLOAD, "price_cents": 0}
    resp = await client.post(
        "/api/v1/admin/offerings/",
        json=payload,
        headers=HEADERS,
    )

    assert resp.status_code == 422


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_create_offering_with_negative_price_returns_422(mock_settings, client):
    """POST /admin/offerings/ with negative price_cents → 422."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    payload = {**VALID_OFFERING_PAYLOAD, "price_cents": -100}
    resp = await client.post(
        "/api/v1/admin/offerings/",
        json=payload,
        headers=HEADERS,
    )

    assert resp.status_code == 422


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_update_offering_with_zero_price_returns_422(mock_settings, client):
    """PATCH /admin/offerings/{id} with price_cents=0 → 422."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    resp = await client.patch(
        f"/api/v1/admin/offerings/{uuid.uuid4()}",
        json={"price_cents": 0},
        headers=HEADERS,
    )

    assert resp.status_code == 422


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_soft_delete_offering_with_valid_auth_returns_200(mock_settings, client):
    """DELETE /admin/offerings/{id} with valid API key soft-deletes offering."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    offering = _make_offering(active=True)
    mock_db = _make_mock_db(offering=offering)
    _override_db(mock_db)
    try:
        resp = await client.delete(
            f"/api/v1/admin/offerings/{offering.id}",
            headers=HEADERS,
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    assert resp.json()["id"] == str(offering.id)
    assert resp.json()["active"] is False
    mock_db.commit.assert_awaited_once()


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_soft_delete_offering_without_auth_returns_401(mock_settings, client):
    """DELETE /admin/offerings/{id} without API key is rejected."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    resp = await client.delete(f"/api/v1/admin/offerings/{uuid.uuid4()}")

    assert resp.status_code == 401


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_soft_delete_offering_not_found_returns_404(mock_settings, client):
    """DELETE /admin/offerings/{id} returns 404 when offering does not exist."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    mock_db = _make_mock_db()
    _override_db(mock_db)
    try:
        resp = await client.delete(
            f"/api/v1/admin/offerings/{uuid.uuid4()}",
            headers=HEADERS,
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# Bulk assign — >500 emails returns 400
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_bulk_assign_more_than_500_emails_returns_400(mock_settings, client):
    """POST /admin/entitlements/assign with >500 emails → 400."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    mock_db = _make_mock_db()
    _override_db(mock_db)
    try:
        payload = {
            "order_id": str(uuid.uuid4()),
            "line_item_id": str(LINE_ITEM_ID),
            "lms_resource_id": "course-v1:Test+101+2024",
            "offering_type": "course_seat",
            "tenant_id": TENANT_ID,
            "emails": [f"user{i}@example.com" for i in range(501)],
        }
        resp = await client.post(
            "/api/v1/admin/entitlements/assign",
            json=payload,
            headers=HEADERS,
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 400
    assert "500" in resp.json()["detail"]


# ---------------------------------------------------------------------------
# List orders — returns 200 with auth
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_list_orders_with_valid_auth_returns_200(mock_settings, client):
    """GET /admin/orders/ with valid API key → 200."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    scalars = MagicMock()
    scalars.all.return_value = []
    mock_result = MagicMock()
    mock_result.scalars.return_value = scalars

    mock_db = AsyncMock()
    mock_db.execute.return_value = mock_result

    _override_db(mock_db)
    try:
        resp = await client.get("/api/v1/admin/orders/", headers=HEADERS)
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_list_orders_without_auth_returns_401(mock_settings, client):
    """GET /admin/orders/ without X-API-Key → 401."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    resp = await client.get("/api/v1/admin/orders/")

    assert resp.status_code == 401


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_retry_fulfillment_with_valid_auth_returns_200(mock_settings, client):
    """POST /admin/orders/{id}/retry-fulfillment/ with valid key requeues fulfillment."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    order = _make_order(status=OrderStatus.fulfillment_failed)
    mock_db = _make_mock_db(order=order)
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    job = MagicMock()
    job.id = uuid.uuid4()
    status_obj = MagicMock()
    status_obj.value = "pending"
    job.status = status_obj
    job.attempts = 0
    job.max_attempts = 10
    job.next_attempt_at = datetime(2024, 1, 1, tzinfo=UTC)

    _override_db(mock_db)
    try:
        with patch("app.routers.admin.enqueue_fulfillment_job", new_callable=AsyncMock) as mock_enqueue:
            mock_enqueue.return_value = job
            resp = await client.post(
                f"/api/v1/admin/orders/{order.id}/retry-fulfillment/",
                headers=HEADERS,
            )
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    payload = resp.json()
    assert payload["order_id"] == str(order.id)
    assert payload["job_id"] == str(job.id)
    assert payload["job_status"] == "pending"
    mock_db.commit.assert_awaited_once()


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_retry_fulfillment_without_auth_returns_401(mock_settings, client):
    """POST /admin/orders/{id}/retry-fulfillment/ without API key is rejected."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    resp = await client.post(f"/api/v1/admin/orders/{ORDER_ID}/retry-fulfillment/")

    assert resp.status_code == 401


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_retry_fulfillment_non_retryable_status_returns_409(mock_settings, client):
    """POST /admin/orders/{id}/retry-fulfillment/ rejects non-retryable order states."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    order = _make_order(status=OrderStatus.refunded)
    mock_db = _make_mock_db(order=order)
    _override_db(mock_db)
    try:
        resp = await client.post(
            f"/api/v1/admin/orders/{order.id}/retry-fulfillment/",
            headers=HEADERS,
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 409
    assert "cannot be retried" in resp.json()["detail"]
