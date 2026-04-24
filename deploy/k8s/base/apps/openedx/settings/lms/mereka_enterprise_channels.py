# -*- coding: utf-8 -*-
"""
Enterprise Integrated Channels configuration for Mereka LMS.

Integrated channels are part of the openedx-enterprise package (built into LMS).
They sync learner data (enrollments, completions, grades) to external LMS
platforms like Degreed and Cornerstone OnDemand (CSOD).

Loaded from production.py via:
    from lms.envs.tutor.mereka_enterprise_channels import *
"""
import os


# ── Ensure integrated_channels apps are in INSTALLED_APPS ────────────
_CHANNEL_APPS = [
    "integrated_channels.integrated_channel",
    "integrated_channels.degreed",
    "integrated_channels.degreed2",
    "integrated_channels.cornerstone",
    "integrated_channels.sap_success_factors",
    "integrated_channels.blackboard",
    "integrated_channels.canvas",
    "integrated_channels.moodle",
]
_installed_apps = globals().get("INSTALLED_APPS")
if isinstance(_installed_apps, list):
    for _app in _CHANNEL_APPS:
        if _app not in _installed_apps:
            _installed_apps.append(_app)

# ── Enterprise feature flags ─────────────────────────────────────────
_features = globals().get("FEATURES")
if isinstance(_features, dict):
    _features["ENABLE_ENTERPRISE_INTEGRATION"] = True

# ── Celery beat schedule for channel sync ────────────────────────────
# Sync learner data to external channels every 4 hours.
# Retry on failure: base 30s, max 15min, max 5 retries.
from datetime import timedelta

CELERYBEAT_SCHEDULE = globals().get("CELERYBEAT_SCHEDULE", {})

CELERYBEAT_SCHEDULE["integrated_channels_content_metadata_sync"] = {
    "task": "integrated_channels.integrated_channel.tasks.transmit_content_metadata",
    "schedule": timedelta(hours=4),
    "options": {
        "expires": 3600,
    },
}

CELERYBEAT_SCHEDULE["integrated_channels_learner_data_sync"] = {
    "task": "integrated_channels.integrated_channel.tasks.transmit_learner_data",
    "schedule": timedelta(hours=4),
    "options": {
        "expires": 3600,
    },
}

# ── Channel sync retry configuration ────────────────────────────────
INTEGRATED_CHANNELS_TASK_RETRY_KWARGS = {
    "retry_backoff": 30,
    "retry_backoff_max": 900,
    "max_retries": 5,
}

# ── Event bus: publish COURSE_COMPLETION events via Redis Streams ────
# The openedx-events framework uses EVENT_BUS_PRODUCER_CONFIG to determine
# which signals get published to the event bus.
EVENT_BUS_PRODUCER_CONFIG = globals().get("EVENT_BUS_PRODUCER_CONFIG", {})

# Publish course completion events for integrated channel consumption.
EVENT_BUS_PRODUCER_CONFIG.setdefault(
    "org.openedx.learning.course.passing.status.updated.v1", {}
).setdefault("enterprise-events", {"event_key_field": "passing_status.user.id", "enabled": True})

# Also publish enrollment events for channel sync triggers.
EVENT_BUS_PRODUCER_CONFIG.setdefault(
    "org.openedx.learning.course.enrollment.changed.v1", {}
).setdefault("enterprise-events", {"event_key_field": "enrollment.user.id", "enabled": True})

# Redis Streams event bus backend (platform-wide decision).
EVENT_BUS_REDIS_CONNECTION_URL = os.environ.get(
    "EVENT_BUS_REDIS_CONNECTION_URL",
    f"redis://{os.environ.get('REDIS_HOST', 'redis')}:{os.environ.get('REDIS_PORT', '6379')}/0",
)
EVENT_BUS_TOPIC_PREFIX = os.environ.get("EVENT_BUS_TOPIC_PREFIX", "mereka")
