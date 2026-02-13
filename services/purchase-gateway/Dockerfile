FROM python:3.12-slim AS base

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -r gateway && useradd -r -g gateway -d /app -s /sbin/nologin gateway

WORKDIR /app

# Install dependencies first (layer caching)
COPY pyproject.toml ./
RUN pip install --no-cache-dir \
    'fastapi>=0.115,<1' 'uvicorn[standard]>=0.34,<1' 'gunicorn>=23,<24' \
    'sqlalchemy[asyncio]>=2.0,<3' 'asyncpg>=0.30,<1' 'psycopg2-binary>=2.9,<3' \
    'alembic>=1.14,<2' \
    'pydantic[email]>=2.10,<3' 'pydantic-settings>=2.7,<3' 'stripe>=12,<13' \
    'redis>=5,<6' 'httpx>=0.28,<1' 'structlog>=24,<25' 'prometheus-client>=0.21,<1'

# Copy application source
COPY alembic.ini ./
COPY alembic/ ./alembic/
COPY app/ ./app/

RUN chown -R gateway:gateway /app
USER gateway

EXPOSE 8080

CMD ["gunicorn", "app.main:app", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--bind", "0.0.0.0:8080", \
     "--workers", "2", \
     "--timeout", "30", \
     "--access-logfile", "-"]
