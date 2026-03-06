"""Unit tests for LMS client auth retry behavior."""
# @covers AC-002, AC-021
# @spec: ecommerce-purchase-gateway_spec.md

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.lms_client import LMSClient


def _response(status_code: int, payload=None):
    response = MagicMock()
    response.status_code = status_code
    response.json.return_value = payload if payload is not None else {}
    return response


def _async_client_context(client):
    context = AsyncMock()
    context.__aenter__.return_value = client
    context.__aexit__.return_value = False
    return context


@pytest.mark.asyncio
@patch("app.services.lms_client.httpx.AsyncClient")
async def test_get_user_by_email_retries_once_on_401(mock_async_client):
    mock_client = AsyncMock()
    mock_client.request = AsyncMock(
        side_effect=[
            _response(401),
            _response(200, [{"id": 42, "username": "learner"}]),
        ]
    )
    mock_async_client.return_value = _async_client_context(mock_client)

    client = LMSClient()
    with patch.object(
        client, "_get_token", AsyncMock(side_effect=["token-1", "token-2"])
    ) as mock_get_token:
        user = await client.get_user_by_email("learner@example.com")

    assert user == {"id": 42, "username": "learner"}
    assert mock_get_token.await_count == 2
    assert mock_client.request.await_count == 2
    assert (
        mock_client.request.await_args_list[0].kwargs["headers"]["Authorization"]
        == "Bearer token-1"
    )
    assert (
        mock_client.request.await_args_list[1].kwargs["headers"]["Authorization"]
        == "Bearer token-2"
    )


@pytest.mark.asyncio
@patch("app.services.lms_client.httpx.AsyncClient")
async def test_enroll_user_does_not_retry_non_401_errors(mock_async_client):
    mock_client = AsyncMock()
    mock_client.request = AsyncMock(side_effect=[_response(500)])
    mock_async_client.return_value = _async_client_context(mock_client)

    client = LMSClient()
    with patch.object(client, "_get_token", AsyncMock(return_value="token-1")) as mock_get_token:
        success = await client.enroll_user(username="learner", course_id="course-v1:test+T101+2026")

    assert success is False
    assert mock_get_token.await_count == 1
    assert mock_client.request.await_count == 1


@pytest.mark.asyncio
@patch("app.services.lms_client.httpx.AsyncClient")
async def test_deactivate_enrollment_retries_once_on_401(mock_async_client):
    mock_client = AsyncMock()
    mock_client.request = AsyncMock(side_effect=[_response(401), _response(201)])
    mock_async_client.return_value = _async_client_context(mock_client)

    client = LMSClient()
    with patch.object(
        client, "_get_token", AsyncMock(side_effect=["token-1", "token-2"])
    ) as mock_get_token:
        success = await client.deactivate_enrollment(
            username="learner",
            course_id="course-v1:test+T101+2026",
        )

    assert success is True
    assert mock_get_token.await_count == 2
    assert mock_client.request.await_count == 2
