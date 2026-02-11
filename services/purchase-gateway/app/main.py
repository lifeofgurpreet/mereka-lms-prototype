# @covers AC-029, AC-032
# @spec: ecommerce-purchase-gateway_spec.md

import structlog
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import make_asgi_app

from app.config import settings
from app.database import engine
from app.routers import checkout, health, webhooks

logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("purchase_gateway.starting")
    yield
    await engine.dispose()
    logger.info("purchase_gateway.shutdown")


app = FastAPI(
    title="Purchase Gateway",
    description="Stripe-to-Open edX enrollment bridge",
    version="0.1.0",
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url=None,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# Routers
app.include_router(health.router)
app.include_router(checkout.router, prefix="/api/v1")
app.include_router(webhooks.router)

# Prometheus metrics
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)
