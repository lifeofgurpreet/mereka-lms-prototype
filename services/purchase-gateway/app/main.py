# @covers AC-029, AC-032
# @spec: ecommerce-purchase-gateway_spec.md

import asyncio
from contextlib import asynccontextmanager

import stripe
import structlog
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import make_asgi_app

from app.config import settings
from app.database import engine
from app.middleware.tenant import TenantMiddleware
from app.routers import admin, admin_entitlement_actions, admin_entitlements, admin_events, admin_offerings, admin_orders, admin_refunds, checkout, health, subscriptions, webhooks
from app.services.fulfillment_outbox import run_fulfillment_worker

logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Set Stripe API key once at startup (not per-request)
    stripe.api_key = settings.STRIPE_SECRET_KEY
    stop_event = asyncio.Event()
    app.state.fulfillment_worker_stop = stop_event
    worker_task = None
    if settings.FULFILLMENT_WORKER_ENABLED and settings.ENABLE_GATEWAY_FULFILLMENT:
        worker_task = asyncio.create_task(run_fulfillment_worker(stop_event))
        app.state.fulfillment_worker_task = worker_task
        logger.info("purchase_gateway.fulfillment_worker_enabled")

    logger.info("purchase_gateway.starting")
    yield
    stop_event.set()
    if worker_task:
        await worker_task
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
    allow_methods=["GET", "POST", "PATCH"],
    allow_headers=["*"],
)

app.add_middleware(TenantMiddleware)

# Routers
app.include_router(health.router)
app.include_router(checkout.router, prefix="/api/v1")
app.include_router(subscriptions.router, prefix="/api/v1")
app.include_router(admin.router, prefix="/api/v1")
app.include_router(admin_offerings.router, prefix="/api/v1")
app.include_router(admin_entitlement_actions.router, prefix="/api/v1")
app.include_router(admin_entitlements.router, prefix="/api/v1")
app.include_router(admin_refunds.router, prefix="/api/v1")
app.include_router(admin_events.router, prefix="/api/v1")
app.include_router(admin_orders.router, prefix="/api/v1")
app.include_router(webhooks.router)

# Prometheus metrics
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)
