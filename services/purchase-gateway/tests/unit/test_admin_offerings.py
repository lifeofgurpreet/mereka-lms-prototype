"""Unit tests for admin offerings listing endpoint."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.offering import Offering, OfferingType
from app.routers.admin_offerings import list_offerings

TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")


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
        "stripe_price_id": f"price_{uuid.uuid4().hex[:12]}",
        "lms_resource_id": "course-v1:Test+101+2024",
        "active": True,
        "metadata_json": {"sku": "SKU-101"},
        "created_at": datetime(2024, 1, 1, tzinfo=UTC),
        "updated_at": datetime(2024, 1, 1, tzinfo=UTC),
    }
    defaults.update(overrides)
    return Offering(**defaults)


@pytest.fixture
def mock_db():
    return AsyncMock(spec=AsyncSession)


def _request_no_tenant():
    request = MagicMock()
    request.state = MagicMock(spec=[])
    return request


def _request_with_tenant(tenant_id: uuid.UUID):
    request = MagicMock()
    request.state = MagicMock()
    request.state.tenant_id = tenant_id
    return request


@pytest.mark.asyncio
async def test_list_offerings_returns_filtered_records(mock_db):
    """Returns offerings with expected type and active filter serialization."""
    offering = _make_offering(offering_type=OfferingType.program, active=True)
    mock_db.execute.return_value = _mock_scalars_result([offering])

    result = await list_offerings(
        request=_request_no_tenant(),
        db=mock_db,
        tenant_id=TENANT_ID,
        offering_type=OfferingType.program,
        active=True,
        limit=50,
        offset=0,
    )

    assert len(result) == 1
    assert result[0].offering_type == OfferingType.program
    assert result[0].active is True


@pytest.mark.asyncio
async def test_list_offerings_returns_empty_list(mock_db):
    """Returns empty list when no offerings match."""
    mock_db.execute.return_value = _mock_scalars_result([])

    result = await list_offerings(
        request=_request_no_tenant(),
        db=mock_db,
        tenant_id=None,
        offering_type=None,
        active=None,
        limit=50,
        offset=0,
    )

    assert result == []


@pytest.mark.asyncio
async def test_list_offerings_tenant_scope_mismatch_returns_403(mock_db):
    """Reject query tenant_id that does not match middleware tenant scope."""
    with pytest.raises(HTTPException) as exc_info:
        await list_offerings(
            request=_request_with_tenant(TENANT_ID),
            db=mock_db,
            tenant_id=uuid.UUID("00000000-0000-0000-0000-000000000009"),
            offering_type=None,
            active=None,
            limit=50,
            offset=0,
        )

    assert exc_info.value.status_code == 403
    assert "Tenant scope mismatch" in exc_info.value.detail
    mock_db.execute.assert_not_awaited()
