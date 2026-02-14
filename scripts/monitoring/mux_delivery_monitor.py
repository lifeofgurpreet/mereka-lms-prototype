#!/usr/bin/env python3
"""
Mux Video Delivery Monitor — Prometheus Exporter

Polls the Mux API every MUX_POLL_INTERVAL_SECONDS (default: 6h = 21600s)
and exposes video delivery, storage, and asset health metrics on :8000/metrics.

Required env vars:
  MUX_TOKEN_ID        — Mux API access token ID
  MUX_TOKEN_SECRET    — Mux API access token secret

Optional env vars:
  MUX_POLL_INTERVAL_SECONDS — Poll interval (default: 21600 = 6 hours)
  MUX_EXPORTER_PORT         — HTTP port (default: 8000)

Covers:
  @spec: video-pipeline-delivery_spec.md
  @covers AC-VPD-019, AC-VPD-029, AC-VPD-030

Metrics exposed:
  video_delivery_minutes_monthly    — Current month delivery minutes (gauge)
  mux_storage_minutes               — Total stored video-minutes (gauge)
  mux_storage_cost_usd_monthly      — Estimated monthly storage cost (gauge)
  mux_delivery_cost_usd_monthly     — Estimated monthly delivery cost (gauge)
  video_transcode_success_rate      — % assets in ready state (gauge)
  mux_asset_processing_queue_depth  — Assets in preparing state (gauge)
  mux_asset_total                   — Total assets by status (gauge)
  mux_api_errors_total              — API call failures (counter)
  mux_poll_duration_seconds         — Time to complete a poll cycle (gauge)
  mux_poll_last_success_timestamp   — Unix timestamp of last successful poll (gauge)
"""

import http.server
import json
import logging
import os
import sys
import threading
import time
import urllib.request
import urllib.error
from base64 import b64encode
from datetime import datetime, timezone

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("mux-monitor")

# ── Configuration ───────────────────────────────────────────────
MUX_TOKEN_ID = os.environ.get("MUX_TOKEN_ID", "")
MUX_TOKEN_SECRET = os.environ.get("MUX_TOKEN_SECRET", "")
POLL_INTERVAL = int(os.environ.get("MUX_POLL_INTERVAL_SECONDS", "21600"))
EXPORTER_PORT = int(os.environ.get("MUX_EXPORTER_PORT", "8000"))
MUX_API_BASE = "https://api.mux.com"

# Mux pricing constants (Basic tier, as of 2025)
STORAGE_PRICE_PER_MIN_MONTH = 0.00055   # $/min/month (hot)
COLD_30D_DISCOUNT = 0.40                 # 40% discount after 30 days
COLD_90D_DISCOUNT = 0.60                 # 60% discount after 90 days
DELIVERY_PRICE_PER_MIN = 0.00            # Free under 100K/month
FREE_TIER_DELIVERY_MINUTES = 100_000

# ── Metrics store ───────────────────────────────────────────────
# Thread-safe dict updated by poller, read by HTTP handler.
metrics = {
    "video_delivery_minutes_monthly": 0.0,
    "mux_storage_minutes": 0.0,
    "mux_storage_cost_usd_monthly": 0.0,
    "mux_delivery_cost_usd_monthly": 0.0,
    "video_transcode_success_rate": 0.0,
    "mux_asset_processing_queue_depth": 0,
    "mux_asset_total_ready": 0,
    "mux_asset_total_errored": 0,
    "mux_asset_total_preparing": 0,
    "mux_api_errors_total": 0,
    "mux_poll_duration_seconds": 0.0,
    "mux_poll_last_success_timestamp": 0.0,
}
metrics_lock = threading.Lock()


def _auth_header() -> str:
    """Basic auth header for Mux API."""
    creds = f"{MUX_TOKEN_ID}:{MUX_TOKEN_SECRET}"
    return "Basic " + b64encode(creds.encode()).decode()


def _mux_get(path: str) -> dict:
    """GET request to Mux API. Returns parsed JSON or raises."""
    url = f"{MUX_API_BASE}{path}"
    req = urllib.request.Request(url, headers={
        "Authorization": _auth_header(),
        "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def _list_all_assets() -> list:
    """Paginate through all Mux assets."""
    assets = []
    page = 1
    while True:
        try:
            data = _mux_get(f"/video/v1/assets?limit=100&page={page}")
        except urllib.error.HTTPError as e:
            log.error("Mux API error listing assets page %d: %s", page, e)
            with metrics_lock:
                metrics["mux_api_errors_total"] += 1
            break
        batch = data.get("data", [])
        if not batch:
            break
        assets.extend(batch)
        page += 1
        # Rate-limit: Mux allows 5 req/s, stay conservative
        time.sleep(0.5)
    return assets


def _estimate_storage_cost(assets: list) -> tuple[float, float]:
    """
    Estimate total stored minutes and monthly cost.
    Returns (total_minutes, estimated_cost_usd).
    """
    now = datetime.now(timezone.utc)
    total_minutes = 0.0
    total_cost = 0.0
    for asset in assets:
        if asset.get("status") != "ready":
            continue
        duration_s = asset.get("duration", 0) or 0
        minutes = duration_s / 60.0
        total_minutes += minutes
        # Determine cold storage discount
        created_str = asset.get("created_at")
        discount = 0.0
        if created_str:
            try:
                created = datetime.fromisoformat(created_str.replace("Z", "+00:00"))
                age_days = (now - created).days
                if age_days >= 90:
                    discount = COLD_90D_DISCOUNT
                elif age_days >= 30:
                    discount = COLD_30D_DISCOUNT
            except (ValueError, TypeError):
                pass
        cost = minutes * STORAGE_PRICE_PER_MIN_MONTH * (1 - discount)
        total_cost += cost
    return total_minutes, total_cost


def _get_delivery_minutes() -> float:
    """
    Fetch current-month delivery minutes from Mux monitoring API.
    Falls back to 0 if the endpoint is unavailable.
    """
    now = datetime.now(timezone.utc)
    # Mux monitoring endpoint for current period usage
    try:
        timeframe_start = f"{now.year}-{now.month:02d}-01T00:00:00Z"
        data = _mux_get(
            f"/video/v1/delivery-usage"
            f"?timeframe[]={timeframe_start}"
            f"&timeframe[]={now.isoformat()}"
        )
        # Sum delivered_seconds across all assets
        total_seconds = 0.0
        for entry in data.get("data", []):
            total_seconds += entry.get("delivered_seconds", 0)
        return total_seconds / 60.0
    except urllib.error.HTTPError as e:
        log.warning("Mux delivery-usage API error: %s (may require enterprise plan)", e)
        with metrics_lock:
            metrics["mux_api_errors_total"] += 1
        return 0.0
    except Exception as e:
        log.warning("Unexpected error fetching delivery minutes: %s", e)
        with metrics_lock:
            metrics["mux_api_errors_total"] += 1
        return 0.0


def poll_mux():
    """Single poll cycle: fetch all Mux data and update metrics."""
    start = time.monotonic()
    log.info("Starting Mux API poll cycle...")

    try:
        # 1. List all assets
        assets = _list_all_assets()
        ready = sum(1 for a in assets if a.get("status") == "ready")
        errored = sum(1 for a in assets if a.get("status") == "errored")
        preparing = sum(1 for a in assets if a.get("status") == "preparing")
        total = ready + errored + preparing

        # 2. Transcode success rate
        success_rate = (ready / total * 100.0) if total > 0 else 100.0

        # 3. Storage estimate
        storage_min, storage_cost = _estimate_storage_cost(assets)

        # 4. Delivery minutes
        delivery_min = _get_delivery_minutes()

        # 5. Delivery cost (free under 100K)
        delivery_cost = 0.0
        if delivery_min > FREE_TIER_DELIVERY_MINUTES:
            overage = delivery_min - FREE_TIER_DELIVERY_MINUTES
            delivery_cost = overage * 0.00055  # Mux standard delivery rate

        duration = time.monotonic() - start
        now_ts = time.time()

        with metrics_lock:
            metrics["video_delivery_minutes_monthly"] = delivery_min
            metrics["mux_storage_minutes"] = storage_min
            metrics["mux_storage_cost_usd_monthly"] = storage_cost
            metrics["mux_delivery_cost_usd_monthly"] = delivery_cost
            metrics["video_transcode_success_rate"] = success_rate
            metrics["mux_asset_processing_queue_depth"] = preparing
            metrics["mux_asset_total_ready"] = ready
            metrics["mux_asset_total_errored"] = errored
            metrics["mux_asset_total_preparing"] = preparing
            metrics["mux_poll_duration_seconds"] = duration
            metrics["mux_poll_last_success_timestamp"] = now_ts

        log.info(
            "Poll complete in %.1fs: %d assets (%d ready, %d errored, %d preparing), "
            "%.0f delivery-min, %.1f storage-min, $%.2f storage, $%.2f delivery",
            duration, total, ready, errored, preparing,
            delivery_min, storage_min, storage_cost, delivery_cost,
        )

    except Exception as e:
        log.error("Poll cycle failed: %s", e)
        with metrics_lock:
            metrics["mux_api_errors_total"] += 1


def poller_loop():
    """Background thread that polls Mux API at POLL_INTERVAL."""
    while True:
        poll_mux()
        log.info("Next poll in %d seconds (%.1f hours)", POLL_INTERVAL, POLL_INTERVAL / 3600)
        time.sleep(POLL_INTERVAL)


# ── Prometheus metrics endpoint ─────────────────────────────────
def render_metrics() -> str:
    """Render metrics in Prometheus text exposition format."""
    with metrics_lock:
        m = dict(metrics)
    lines = []

    def gauge(name, help_text, value, labels=""):
        lines.append(f"# HELP {name} {help_text}")
        lines.append(f"# TYPE {name} gauge")
        if labels:
            lines.append(f"{name}{{{labels}}} {value}")
        else:
            lines.append(f"{name} {value}")

    def counter(name, help_text, value, labels=""):
        lines.append(f"# HELP {name} {help_text}")
        lines.append(f"# TYPE {name} counter")
        if labels:
            lines.append(f"{name}{{{labels}}} {value}")
        else:
            lines.append(f"{name} {value}")

    gauge("video_delivery_minutes_monthly",
          "Current month Mux delivery minutes consumed",
          m["video_delivery_minutes_monthly"])

    gauge("mux_storage_minutes",
          "Total video-minutes stored in Mux",
          m["mux_storage_minutes"])

    gauge("mux_storage_cost_usd_monthly",
          "Estimated monthly Mux storage cost in USD",
          f"{m['mux_storage_cost_usd_monthly']:.4f}")

    gauge("mux_delivery_cost_usd_monthly",
          "Estimated monthly Mux delivery cost in USD",
          f"{m['mux_delivery_cost_usd_monthly']:.4f}")

    gauge("video_transcode_success_rate",
          "Percentage of Mux assets in ready state",
          f"{m['video_transcode_success_rate']:.2f}")

    gauge("mux_asset_processing_queue_depth",
          "Number of Mux assets in preparing state",
          m["mux_asset_processing_queue_depth"])

    # Per-status asset counts
    lines.append("# HELP mux_asset_total Total Mux assets by status")
    lines.append("# TYPE mux_asset_total gauge")
    lines.append(f'mux_asset_total{{status="ready"}} {m["mux_asset_total_ready"]}')
    lines.append(f'mux_asset_total{{status="errored"}} {m["mux_asset_total_errored"]}')
    lines.append(f'mux_asset_total{{status="preparing"}} {m["mux_asset_total_preparing"]}')

    counter("mux_api_errors_total",
            "Total Mux API errors encountered",
            m["mux_api_errors_total"])

    gauge("mux_poll_duration_seconds",
          "Duration of last Mux API poll cycle",
          f"{m['mux_poll_duration_seconds']:.3f}")

    gauge("mux_poll_last_success_timestamp",
          "Unix timestamp of last successful Mux poll",
          f"{m['mux_poll_last_success_timestamp']:.0f}")

    return "\n".join(lines) + "\n"


class MetricsHandler(http.server.BaseHTTPRequestHandler):
    """HTTP handler for /metrics and /healthz."""

    def do_GET(self):
        if self.path == "/metrics":
            body = render_metrics().encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path in ("/healthz", "/health"):
            body = b'{"status":"ok"}\n'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Suppress noisy per-request logging from BaseHTTPRequestHandler
        pass


def main():
    if not MUX_TOKEN_ID or not MUX_TOKEN_SECRET:
        log.warning(
            "MUX_TOKEN_ID or MUX_TOKEN_SECRET not set. "
            "Exporter will run but report zero metrics until credentials are configured."
        )

    # Start background poller
    t = threading.Thread(target=poller_loop, daemon=True)
    t.start()

    # Start HTTP server
    server = http.server.HTTPServer(("0.0.0.0", EXPORTER_PORT), MetricsHandler)
    log.info("Mux delivery monitor listening on :%d/metrics", EXPORTER_PORT)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log.info("Shutting down.")
        server.shutdown()


if __name__ == "__main__":
    main()
