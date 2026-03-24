FROM python:3.12-slim AS base

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -r gateway && useradd -r -g gateway -d /app -s /sbin/nologin gateway

WORKDIR /app

# Install dependencies first (layer caching)
COPY pyproject.toml ./
RUN python - <<'PY' > /tmp/requirements.txt
import pathlib
import tomllib

deps = tomllib.loads(pathlib.Path("pyproject.toml").read_text())["project"]["dependencies"]
print("\n".join(deps))
PY
RUN pip install --no-cache-dir -r /tmp/requirements.txt

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
