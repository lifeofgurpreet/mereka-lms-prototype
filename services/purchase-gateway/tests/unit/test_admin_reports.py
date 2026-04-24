"""Unit tests for admin tenant reports endpoint."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from collections import namedtuple
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.routers.admin_reports import get_tenant_report

TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")

AggRow = namedtuple(
    "AggRow",
    [
        "order_count",
        "gross_revenue_cents",
        "refunded",
        "partially_refunded",
        "fulfillment_failed",
        "pending",
    ],
)


def _mock_agg_result(row: AggRow):
    """Mock db.execute() to return a single aggregation row."""
    result = MagicMock()
    result.one.return_value = row
    return result


@pytest.fixture
def mock_db():
    return AsyncMock(spec=AsyncSession)


def _request_no_tenant():
    request = MagicMock()
    request.state = MagicMock(spec=[])
    return request


@pytest.mark.asyncio
async def test_get_tenant_report_aggregates_metrics(mock_db):
    """Report aggregates counts, revenue, and refund rate via SQL."""
    row = AggRow(
        order_count=5,
        gross_revenue_cents=24000,
        refunded=1,
        partially_refunded=1,
        fulfillment_failed=1,
        pending=1,
    )
    mock_db.execute.return_value = _mock_agg_result(row)

    report = await get_tenant_report(
        tenant_id=TENANT_ID,
        request=_request_no_tenant(),
        db=mock_db,
    )

    assert report.order_count == 5
    assert report.gross_revenue_cents == 24000
    assert report.refunded_order_count == 1
    assert report.partially_refunded_order_count == 1
    assert report.fulfillment_failed_order_count == 1
    assert report.pending_order_count == 1
    assert report.refund_rate_percent == 40.0


@pytest.mark.asyncio
async def test_get_tenant_report_empty_tenant(mock_db):
    """Zero-order tenant returns all zeroes and 0% refund rate."""
    row = AggRow(
        order_count=0,
        gross_revenue_cents=0,
        refunded=0,
        partially_refunded=0,
        fulfillment_failed=0,
        pending=0,
    )
    mock_db.execute.return_value = _mock_agg_result(row)

    report = await get_tenant_report(
        tenant_id=TENANT_ID,
        request=_request_no_tenant(),
        db=mock_db,
    )

    assert report.order_count == 0
    assert report.gross_revenue_cents == 0
    assert report.refund_rate_percent == 0.0


@pytest.mark.asyncio
async def test_get_tenant_report_forbidden_for_mismatched_tenant_scope(mock_db):
    """If middleware tenant scope mismatches path tenant, request is forbidden."""
    request = MagicMock()
    request.state = MagicMock()
    request.state.tenant_id = uuid.UUID("00000000-0000-0000-0000-000000000099")

    with pytest.raises(HTTPException) as exc_info:
        await get_tenant_report(
            tenant_id=TENANT_ID,
            request=request,
            db=mock_db,
        )

    assert exc_info.value.status_code == 403
