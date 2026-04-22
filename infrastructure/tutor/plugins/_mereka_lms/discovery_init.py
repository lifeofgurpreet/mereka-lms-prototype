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

_DISCOVERY_INIT_MATCH_MARKERS = (
    "create_or_update_partner",
    "refresh_course_metadata",
    "update_index",
)

_LMS_HOST_TEMPLATE = "{{ " + "LMS_HOST" + " }}"
_BROWSER_FACING_LMS_API_URL_MARKERS = tuple(
    f"http://{host}{port}{api_path}"
    for host in (_LMS_HOST_TEMPLATE, "localhost")
    for port in (":8000", "")
    for api_path in (
        "/api/courses/v1/",
        "/api/organizations/v1/",
    )
)


def _is_discovery_init_candidate(service: str, task: str) -> bool:
    return service == "discovery" and "create_or_update_partner" in task


def _is_supported_discovery_init_task(service: str, task: str) -> bool:
    return _is_discovery_init_candidate(service, task) and all(
        marker in task for marker in _DISCOVERY_INIT_MATCH_MARKERS
    )


def _uses_browser_facing_lms_api(task: str) -> bool:
    return any(marker in task for marker in _BROWSER_FACING_LMS_API_URL_MARKERS)


def replace_discovery_init_tasks(
    tasks: list[tuple[str, str]],
) -> list[tuple[str, str]]:
    """Replace the Discovery partner init task and fail loud on selector drift."""
    candidate_indices = [
        index
        for index, (service, task) in enumerate(tasks)
        if _is_discovery_init_candidate(service, task)
    ]
    supported_indices = [
        index
        for index, (service, task) in enumerate(tasks)
        if _is_supported_discovery_init_task(service, task)
    ]

    if not supported_indices:
        browser_api_indices = [
            index
            for index, (service, task) in enumerate(tasks)
            if service == "discovery" and _uses_browser_facing_lms_api(task)
        ]
        if candidate_indices or browser_api_indices:
            raise RuntimeError(
                "Discovery init task selector drift: expected exactly one "
                "supported upstream Discovery init partner task, found "
                f"{len(supported_indices)} supported and "
                f"{len(candidate_indices)} candidate task(s); "
                f"{len(browser_api_indices)} browser-facing API task(s) remain."
            )
        return list(tasks)

    if len(supported_indices) != 1 or len(candidate_indices) != 1:
        raise RuntimeError(
            "Discovery init task selector drift: expected exactly one "
            "supported upstream Discovery init partner task, found "
            f"{len(supported_indices)} supported and "
            f"{len(candidate_indices)} candidate task(s)."
        )

    next_tasks = list(tasks)
    next_tasks[supported_indices[0]] = ("discovery", _DISCOVERY_INIT_TASK)

    leftover_browser_api_indices = [
        index
        for index, (service, task) in enumerate(next_tasks)
        if service == "discovery" and _uses_browser_facing_lms_api(task)
    ]
    if leftover_browser_api_indices:
        raise RuntimeError(
            "Discovery init task selector drift: browser-facing LMS API URLs "
            "remain after replacement."
        )

    canonical_count = sum(
        1 for service, task in next_tasks if service == "discovery" and task == _DISCOVERY_INIT_TASK
    )
    if canonical_count != 1:
        raise RuntimeError(
            "Discovery init task selector drift: expected exactly one canonical "
            f"Discovery init task after replacement, found {canonical_count}."
        )

    return next_tasks


@hooks.Filters.CLI_DO_INIT_TASKS.add(priority=hooks.priorities.LOW + 10)
def _replace_discovery_init_task(
    tasks: list[tuple[str, str]],
) -> list[tuple[str, str]]:
    """Replace tutor-discovery's init task with container-safe LMS API URLs."""
    return replace_discovery_init_tasks(tasks)
