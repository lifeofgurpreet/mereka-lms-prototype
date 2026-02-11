"""Open edX LMS API client with OAuth2 authentication."""

import structlog
import httpx

from app.config import settings

logger = structlog.get_logger()


class LMSClient:
    """Client for interacting with the Open edX LMS APIs."""

    def __init__(self) -> None:
        self.base_url = settings.LMS_BASE_URL
        self._token: str | None = None

    async def _get_token(self) -> str:
        """Obtain OAuth2 access token via client credentials grant."""
        if self._token:
            return self._token

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
            self._token = resp.json()["access_token"]
            return self._token

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
                self._token = None  # Refresh on next call
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
