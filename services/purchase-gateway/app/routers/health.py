import redis.asyncio as redis
import structlog
from fastapi import APIRouter
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.config import settings
from app.database import engine

router = APIRouter()
logger = structlog.get_logger()


@router.get("/health/")
async def health_check():
    checks = {"status": "ok", "database": "ok", "redis": "ok", "stripe": "ok"}

    # Database check
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception:
        checks["database"] = "error"
        checks["status"] = "degraded"

    # Redis check
    try:
        r = redis.from_url(settings.REDIS_URL)
        await r.ping()
        await r.aclose()
    except Exception:
        checks["redis"] = "error"
        checks["status"] = "degraded"

    # Stripe key presence check (no API call — just verify key is configured)
    if not settings.STRIPE_SECRET_KEY:
        checks["stripe"] = "not_configured"
        checks["status"] = "degraded"

    status_code = 200 if checks["status"] == "ok" else 503
    return JSONResponse(content=checks, status_code=status_code)


@router.get("/ready/")
async def readiness_check():
    """Lightweight readiness probe — only checks if the process can serve."""
    return {"status": "ready"}
