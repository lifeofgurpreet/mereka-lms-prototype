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

    async def get_user_by_email(self, email: str) -> dict | None:
        """Look up an LMS user by email. Returns user dict or None."""
        token = await self._get_token()
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/api/user/v1/accounts",
                params={"email": email},
                headers={"Authorization": f"Bearer {token}"},
                timeout=15,
            )
            if resp.status_code == 200:
                users = resp.json()
                return users[0] if users else None
            if resp.status_code == 401:
                self._invalidate_token()
            return None

    async def enroll_user(self, username: str, course_id: str) -> bool:
        """Enroll a user in a course. Returns True on success or if already enrolled."""
        token = await self._get_token()
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.base_url}/api/enrollment/v1/enrollment",
                json={
                    "user": username,
                    "course_details": {"course_id": course_id},
                    "mode": "verified",
                    "is_active": True,
                },
                headers={"Authorization": f"Bearer {token}"},
                timeout=15,
            )

            if resp.status_code in (200, 201):
                return True
            if resp.status_code == 409:
                # Already enrolled — idempotent success
                return True
            if resp.status_code == 401:
                self._invalidate_token()

            logger.error(
                "lms.enrollment_failed",
                username=username,
                course_id=course_id,
                status_code=resp.status_code,
            )
            return False

    async def deactivate_enrollment(self, username: str, course_id: str) -> bool:
        """Deactivate an enrollment (used for refund revocation)."""
        token = await self._get_token()
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.base_url}/api/enrollment/v1/enrollment",
                json={
                    "user": username,
                    "course_details": {"course_id": course_id},
                    "is_active": False,
                },
                headers={"Authorization": f"Bearer {token}"},
                timeout=15,
            )
            return resp.status_code in (200, 201)
