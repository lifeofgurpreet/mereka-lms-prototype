"""Discovery init task corrections for local container networking."""

from __future__ import annotations

from tutor import hooks

_DISCOVERY_INIT_TASK = """
make migrate

# Discovery init runs inside the docker compose network. LMS_HOST is browser-facing
# in local builds and may be "localhost"; API calls from this job must use the LMS
# service DNS name instead.

# Development partners
./manage.py create_or_update_partner  \\
  --site-id 1 \\
  --site-domain {{ DISCOVERY_HOST }}:8381 \\
  --code dev \\
  --name "Open edX - development" \\
  --lms-url="http://lms:8000" \\
  --studio-url="http://cms:8000" \\
  --courses-api-url "http://lms:8000/api/courses/v1/" \\
  --organizations-api-url "http://lms:8000/api/organizations/v1/"

# Production partner
./manage.py create_or_update_partner  \\
  --site-id 2 \\
  --site-domain {{ DISCOVERY_HOST }} \\
  --code openedx \\
  --name "Open edX" \\
  --lms-url="http://lms:8000" \\
  --studio-url="http://cms:8000" \\
  --courses-api-url "http://lms:8000/api/courses/v1/" \\
  --organizations-api-url "http://lms:8000/api/organizations/v1/"

./manage.py refresh_course_metadata --partner_code=$DEFAULT_PARTNER_CODE
./manage.py update_index --disable-change-limit
"""


@hooks.Filters.CLI_DO_INIT_TASKS.add(priority=hooks.priorities.LOW + 10)
def _replace_discovery_init_task(
    tasks: list[tuple[str, str]],
) -> list[tuple[str, str]]:
    """Replace tutor-discovery's init task with container-safe LMS API URLs."""
    replaced = False
    next_tasks: list[tuple[str, str]] = []

    for service, task in tasks:
        is_upstream_discovery_init = (
            service == "discovery"
            and "create_or_update_partner" in task
            and "refresh_course_metadata" in task
        )
        if not is_upstream_discovery_init:
            next_tasks.append((service, task))
            continue

        if not replaced:
            next_tasks.append(("discovery", _DISCOVERY_INIT_TASK))
            replaced = True

    return next_tasks
