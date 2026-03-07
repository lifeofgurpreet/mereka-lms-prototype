from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = "postgresql+asyncpg://payments:payments@localhost:5432/payments_gateway"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/14"

    # Stripe
    STRIPE_SECRET_KEY: str = ""
    STRIPE_WEBHOOK_SECRET: str = ""
    STRIPE_PUBLISHABLE_KEY: str = ""
    STRIPE_EVENT_STALE_PROCESSING_SECONDS: int = 900

    # Open edX LMS
    LMS_BASE_URL: str = "http://lms:8000"
    LMS_PUBLIC_URL: str = "https://academyv2.mereka.io"
    LMS_OAUTH_CLIENT_ID: str = "payments-gateway"
    LMS_OAUTH_CLIENT_SECRET: str = ""

    # Application
    SECRET_KEY: str = ""
    ADMIN_API_KEY: str = ""
    ADMIN_JWT_SECRET: str = ""
    ADMIN_JWT_ALGORITHMS: list[str] = ["HS256"]
    ADMIN_JWT_ISSUER: str | None = None
    ADMIN_JWT_AUDIENCE: str | None = None
    ADMIN_ALLOWED_ROLES: list[str] = ["payments_admin", "enterprise_admin"]
    ADMIN_REQUIRE_JWT: bool = False
    ALLOWED_ORIGINS: list[str] = [
        "https://academyv2.mereka.io",
        "https://apps.academyv2.mereka.io",
    ]
    DEBUG: bool = False

    # Feature flags
    ENABLE_GATEWAY_FULFILLMENT: bool = False
    TENANT_ISOLATION_ENABLED: bool = True
    ENABLE_ENTITLEMENT_INVITATIONS: bool = True
    ENABLE_ENTERPRISE_SUBSCRIPTIONS: bool = False
    ENABLE_AUTO_REVOKE_ON_DISPUTE: bool = False
    ENABLE_RECONCILIATION_JOB: bool = False

    # Fulfillment
    FULFILLMENT_MAX_RETRIES: int = 10
    FULFILLMENT_BASE_DELAY_SECONDS: int = 5
    FULFILLMENT_STALE_PROCESSING_SECONDS: int = 900
    FULFILLMENT_WORKER_ENABLED: bool = True
    FULFILLMENT_WORKER_POLL_SECONDS: int = 5
    FULFILLMENT_RECONCILE_INTERVAL_SECONDS: int = 300
    FULFILLMENT_RECONCILE_BATCH_SIZE: int = 100

    # Entitlements
    ENTITLEMENT_CLAIM_EXPIRY_DAYS: int = 30

    model_config = {"env_prefix": "", "case_sensitive": True}


settings = Settings()
