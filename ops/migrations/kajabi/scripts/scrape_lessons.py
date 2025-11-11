#!/usr/bin/env python3
"""Playwright-based Kajabi lesson scraper.

This helper signs into the Kajabi admin, visits every lesson URL derived from
``course_structure.json`` (output of ``transform_data.py``), and saves a JSON
blob per lesson containing the captured HTML snippet. The Open edX transformer
can ingest these snapshots to replace placeholder content whenever actual
lesson bodies are available.

Usage:

    KAJABI_EMAIL=me@example.com KAJABI_PASSWORD=secret \
    python scrape_lessons.py \
        --structure ops/migrations/kajabi/output/course_structure.json \
        --output exports/kajabi/lesson_html \
        --lesson-url-template "https://academy.mereka.my/admin/sites/{site_id}/products/{course_id}/posts/{lesson_id}"

The URL template is intentionally configurable because Kajabi sites can change
their admin paths. The placeholders you can use are ``{lesson_id}``,
``{course_id}``, ``{site_id}``, and ``{base_url}``.
"""

from __future__ import annotations

import argparse
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple

from playwright.sync_api import TimeoutError as PlaywrightTimeout
from playwright.sync_api import sync_playwright


def load_structure(path: Path) -> List[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    lessons: List[dict] = []
    for course in data:
        course_id = course.get("course_id")
        for module in course.get("modules", []):
            for lesson in module.get("lessons", []):
                entry = dict(lesson)
                entry["course_id"] = course_id
                lessons.append(entry)
    return lessons


def resolve_url(template: str, lesson: dict, site_id: str, base_url: str) -> str:
    return template.format(
        lesson_id=lesson.get("id"),
        course_id=lesson.get("course_id"),
        site_id=site_id,
        base_url=base_url.rstrip("/"),
    )


def extract_lesson_html(page, selectors: Sequence[str], iframe_filters: Sequence[str]) -> Tuple[str, str]:
    for selector in selectors:
        try:
            page.wait_for_selector(selector, timeout=2000)
            content = page.eval_on_selector(
                selector, "el => el.value ?? el.innerHTML ?? ''"
            )
            if isinstance(content, str) and content.strip():
                return content, selector
        except PlaywrightTimeout:
            continue
        except Exception:
            continue

    for frame in page.frames:
        name = frame.name or ""
        if iframe_filters and not any(f in name for f in iframe_filters):
            continue
        try:
            content = frame.eval_on_selector("body", "el => el.innerHTML || ''")
            if isinstance(content, str) and content.strip():
                return content, f"iframe:{name or 'body'}"
        except Exception:
            continue

    try:
        html = page.inner_html("main")
        if isinstance(html, str) and html.strip():
            return html, "main"
    except Exception:
        pass

    return page.content(), "page.content"


def scrape_lessons(
    lessons: Iterable[dict],
    output_dir: Path,
    lesson_url_template: str,
    site_id: str,
    base_url: str,
    username: str,
    password: str,
    delay: float,
    limit: int | None,
    selectors: Sequence[str],
    iframe_filters: Sequence[str],
    ndjson_path: Path | None,
):
    output_dir.mkdir(parents=True, exist_ok=True)
    failures: Dict[str, str] = {}
    ndjson_handle = None
    if ndjson_path:
        ndjson_path.parent.mkdir(parents=True, exist_ok=True)
        ndjson_handle = ndjson_path.open("w", encoding="utf-8")

    login_url = f"{base_url.rstrip('/')}/admin/login"
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        page = context.new_page()

        page.goto(login_url)
        page.fill("input[name='email']", username)
        page.fill("input[name='password']", password)
        page.click("button[type='submit']")
        page.wait_for_load_state("networkidle", timeout=60000)

        count = 0
        for lesson in lessons:
            if limit is not None and count >= limit:
                break
            lesson_id = lesson.get("id")
            url = resolve_url(lesson_url_template, lesson, site_id, base_url)
            print(f"→ Fetching lesson {lesson_id} ({url})")
            try:
                page.goto(url, wait_until="networkidle", timeout=60000)
                time.sleep(delay)
                content_html, selector = extract_lesson_html(
                    page, selectors, iframe_filters
                )
                detail_attrs = {}
                if content_html.strip():
                    detail_attrs = {
                        "attributes": {
                            "content_html": content_html,
                            "body": content_html,
                        }
                    }
                record = {
                    "lesson_id": lesson_id,
                    "course_id": lesson.get("course_id"),
                    "url": url,
                    "selector": selector,
                    "captured_at": datetime.now(timezone.utc).isoformat(),
                    "detail": detail_attrs or {"attributes": {}},
                    "included": [],
                }
                record["detail"]["attributes"].setdefault("content_html", content_html)
                record["detail"]["attributes"].setdefault("body", content_html)

                (output_dir / f"{lesson_id}.json").write_text(
                    json.dumps(record, ensure_ascii=False, indent=2),
                    encoding="utf-8",
                )
                if ndjson_handle:
                    ndjson_handle.write(json.dumps(record, ensure_ascii=False))
                    ndjson_handle.write("\n")
                count += 1
            except PlaywrightTimeout as exc:
                print(f"  ! Timeout loading {url}: {exc}")
                failures[lesson_id] = "timeout"
            except Exception as exc:  # pragma: no cover - scrape fallback
                print(f"  ! Failed to capture lesson {lesson_id}: {exc}")
                failures[lesson_id] = str(exc)

        browser.close()

    if failures:
        failure_log = output_dir / "scrape_failures.json"
        failure_log.write_text(json.dumps(failures, indent=2), encoding="utf-8")
        print(f"⚠️  {len(failures)} lessons failed. See {failure_log}.")
    else:
        print("✅ All lessons captured.")

    if ndjson_handle:
        ndjson_handle.close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scrape Kajabi lesson HTML")
    parser.add_argument("--structure", required=True, help="Path to course_structure.json")
    parser.add_argument("--output", required=True, help="Directory to write HTML files")
    parser.add_argument(
        "--lesson-url-template",
        default="{base_url}/admin/sites/{site_id}/products/{course_id}/posts/{lesson_id}",
        help="Template for lesson URL",
    )
    parser.add_argument("--site-id", required=True, help="Kajabi site ID to inject in URLs")
    parser.add_argument(
        "--base-url",
        default="https://academy.mereka.my",
        help="Kajabi base URL (no trailing slash)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=1.5,
        help="Seconds to wait after each navigation before capturing HTML",
    )
    parser.add_argument(
        "--content-selectors",
        default="textarea[name='post[content]'],textarea[name='post[body]'],[data-testid='rich-editor']",
        help="Comma-separated list of CSS selectors to try when extracting lesson HTML",
    )
    parser.add_argument(
        "--iframe-names",
        default="post_content_ifr",
        help="Comma-separated substrings to match iframe names (used for TinyMCE editors)",
    )
    parser.add_argument(
        "--ndjson-output",
        default=None,
        help="Optional path for aggregated NDJSON output (defaults to <output>/lesson_details.ndjson)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Optional max number of lessons to scrape (for smoke tests)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    username = os.environ.get("KAJABI_EMAIL")
    password = os.environ.get("KAJABI_PASSWORD")
    if not username or not password:
        raise SystemExit("Set KAJABI_EMAIL and KAJABI_PASSWORD environment variables")

    lessons = load_structure(Path(args.structure))
    if not lessons:
        raise SystemExit("No lessons found in course_structure.json")

    selectors = [s.strip() for s in args.content_selectors.split(",") if s.strip()]
    iframe_filters = [s.strip() for s in args.iframe_names.split(",") if s.strip()]

    ndjson_path = (
        Path(args.ndjson_output)
        if args.ndjson_output
        else Path(args.output) / "lesson_details.ndjson"
    )

    scrape_lessons(
        lessons,
        Path(args.output),
        args.lesson_url_template,
        args.site_id,
        args.base_url,
        username,
        password,
        args.delay,
        args.limit,
        selectors,
        iframe_filters,
        ndjson_path,
    )


if __name__ == "__main__":
    main()
