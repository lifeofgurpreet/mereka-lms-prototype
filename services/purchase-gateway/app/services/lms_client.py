"""Open edX LMS API client with OAuth2 authentication."""
# @covers AC-002, AC-021
# @spec: ecommerce-purchase-gateway_spec.md

import time

import httpx
import structlog

from app.config import settings

logger = structlog.get_logger()

# Module-level token cache (shared across all LMSClient instances)
_token_cache: dict[str, str | float] = {"token": "", "expires_at": 0.0}
_TOKEN_TTL_SECONDS = 3300  # 55 minutes (tokens typically valid for 1 hour)


class LMSClient:
    """Client for interacting with the Open edX LMS APIs."""

    def __init__(self) -> None:
        self.base_url = settings.LMS_BASE_URL

    async def _get_token(self) -> str:
        """Obtain OAuth2 access token via client credentials grant (cached with TTL)."""
        now = time.monotonic()
        if _token_cache["token"] and now < _token_cache["expires_at"]:
            return str(_token_cache["token"])

        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.base_url}/oauth2/access_token",
                data={
                    "grant_type": "client_credentials",
                    "client_id": settings.LMS_OAUTH_CLIENT_ID,
                    "client_secret": settings.LMS_OAUTH_CLIENT_SECRET,
                },
                timeout=10,
            )
            resp.raise_for_status()
            token = resp.json()["access_token"]
            _token_cache["token"] = token
            _token_cache["expires_at"] = now + _TOKEN_TTL_SECONDS
            return token

    def _invalidate_token(self) -> None:
        """Clear cached token (e.g., on 401 response)."""
        _token_cache["token"] = ""
        _token_cache["expires_at"] = 0.0

    async def _request_with_auth(
        self,
        *,
        method: str,
        path: str,
        params: dict | None = None,
        json: dict | None = None,
        timeout: int = 15,
    ) -> httpx.Response:
        """Send an authenticated LMS request with one token-refresh retry on 401."""
        url = f"{self.base_url}{path}"
        async with httpx.AsyncClient() as client:
            for attempt in (1, 2):
                token = await self._get_token()
                resp = await client.request(
                    method=method,
                    url=url,
                    params=params,
                    json=json,
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=timeout,
                )
                if resp.status_code != 401:
                    return resp

                # Token may have expired or been revoked; force refresh and retry once.
                self._invalidate_token()
                if attempt == 1:
                    logger.warning("lms.auth_401_retry", method=method, path=path)
                    continue
                return resp

        raise RuntimeError("Unreachable LMS request state")

    async def get_user_by_email(self, email: str) -> dict | None:
        """Look up an LMS user by email. Returns user dict or None."""
        resp = await self._request_with_auth(
            method="GET",
            path="/api/user/v1/accounts",
            params={"email": email},
            timeout=15,
        )
        if resp.status_code == 200:
            users = resp.json()
            return users[0] if users else None
        return None

    async def enroll_user(self, username: str, course_id: str) -> bool:
        """Enroll a user in a course. Returns True on success or if already enrolled."""
        resp = await self._request_with_auth(
            method="POST",
            path="/api/enrollment/v1/enrollment",
            json={
                "user": username,
                "course_details": {"course_id": course_id},
                "mode": "verified",
                "is_active": True,
            },
            timeout=15,
        )

        if resp.status_code in (200, 201):
            return True
        if resp.status_code == 409:
            # Already enrolled — idempotent success
            return True

        logger.error(
            "lms.enrollment_failed",
            course_id=course_id,
            status_code=resp.status_code,
        )
        return False

    async def deactivate_enrollment(self, username: str, course_id: str) -> bool:
        """Deactivate an enrollment (used for refund revocation)."""
        resp = await self._request_with_auth(
            method="POST",
            path="/api/enrollment/v1/enrollment",
            json={
                "user": username,
                "course_details": {"course_id": course_id},
                "is_active": False,
            },
            timeout=15,
        )
        return resp.status_code in (200, 201)
