#!/usr/bin/env python3
"""Generate Open edX course packages from MCT categories (not individual courses).

This script creates ONE Open edX course per MCT category, where:
- MCT Category → Open edX Course (31 total)
- MCT "Course" → Open edX Chapter/Section within the category course
- MCT Lesson → Open edX Unit within the section

Example:
    AI Fluency (Category 24) becomes ONE course with chapters:
    - Chapter 1: MCT Course 279 "Module 1: Introduction to AI..."
    - Chapter 2: MCT Course 281 "Nhập môn 1: AI..." (Vietnamese)
    - Chapter 3: MCT Course 356 "模块1: 人工智能介绍" (Chinese)

Usage:
```
python scripts/migrations/mct/scripts/build_category_packages.py \
  --categories exports/mct/categories.ndjson \
  --courses exports/mct/courses.ndjson \
  --lessons var/migrations/mct/transformed/lessons.ndjson \
  --output-dir var/migrations/mct/course_packages_category \
  --org SKILLOURFUTURE
```
"""

from __future__ import annotations

import argparse
import csv
import html
import json
import re
import shutil
import tarfile
from collections import defaultdict
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path

DEFAULT_START = "2025-01-01T00:00:00Z"


def slugify(value: str, fallback: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug or fallback


@dataclass
class CourseKey:
    category_id: str
    title: str
    org: str
    number: str
    run: str
    slug: str

    @property
    def package_name(self) -> str:
        return f"{self.slug}.tar.gz"


def load_categories(path: Path) -> dict:
    """Load categories from NDJSON file."""
    categories = {}
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
        for offer in data.get("Offers", []):
            category_id = str(offer["Id"])
            # Get the English name or first available name
            names = offer.get("Names", [])
            name = "Unknown Category"
            for n in names:
                if n.get("LanguageCode") == "en-US":
                    name = n["Value"]
                    break
            if name == "Unknown Category" and names:
                name = names[0]["Value"]

            categories[category_id] = {
                "id": category_id,
                "name": name.strip(),
                "logo": offer.get("Logo", ""),
                "default_language": offer.get("DefaultLanguageCode", "en-US"),
            }
    return categories


def load_courses_by_category(path: Path) -> dict[str, list[dict]]:
    """Load courses grouped by CategoryId from NDJSON file."""
    courses_by_category = defaultdict(list)
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            course = json.loads(line)
            category_id = str(course.get("CategoryId", ""))
            if category_id:
                courses_by_category[category_id].append(course)

    # Sort courses by Id within each category
    for category_id in courses_by_category:
        courses_by_category[category_id].sort(key=lambda c: c.get("Id", 0))

    return dict(courses_by_category)


def generate_placeholder_lessons(course: dict) -> list[dict]:
    """Generate placeholder lessons based on NumPublishedLessons in course data."""
    num_lessons = course.get("NumPublishedLessons", 0)
    if num_lessons == 0:
        num_lessons = 1  # Always have at least one lesson

    lessons = []
    for i in range(num_lessons):
        lessons.append({
            "Id": f"{course.get('Id', '')}-lesson-{i+1}",
            "Name": f"Lesson {i+1}",
            "Description": f"Lesson {i+1} from {course.get('Name', 'course')}",
        })
    return lessons


def ensure_clean_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def build_policy_json(title: str, start: str = DEFAULT_START) -> str:
    policy = {
        "display_name": title,
        "start": start,
        "end": None,
        "enrollment_start": start,
        "enrollment_end": None,
        "course_visibility": "both",
        "catalog_visibility": "both",
        "invitation_only": False,
        "max_student_enrollments_allowed": None,
        "cert_html_view_enabled": True,
        "certificates_display_behavior": "end",
    }
    return json.dumps(policy, indent=2)


def create_video_block(lesson: dict, video_url: str) -> str:
    """Create a video XBlock XML for Open edX."""
    title = html.escape(lesson.get("Name", "Video Lesson"))
    lesson_id = str(lesson.get("Id", "video"))

    video_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<video url_name="video_{lesson_id}" display_name="{title}" download_video="true" show_captions="true">
  <source src="{html.escape(video_url)}"/>
</video>"""
    return video_xml


def create_html_block_for_lesson(lesson: dict) -> str:
    """Create HTML block content for lessons."""
    title = html.escape(lesson.get("Name", "Lesson"))
    description = html.escape(lesson.get("Description", "") or "")
    lesson_id = str(lesson.get("Id", "html"))

    html_parts = []

    if description:
        html_parts.append(f"<p>{description}</p>")

    # Check for media content
    media_content = lesson.get("MediaContent", {})
    if isinstance(media_content, dict):
        playback_url = media_content.get("PlaybackUrl", "")
        download_url = media_content.get("DownloadUrl", "")

        if playback_url:
            html_parts.append(f'<p><a href="{html.escape(playback_url)}" target="_blank">Watch Video</a></p>')
        elif download_url:
            html_parts.append(f'<p><a href="{html.escape(download_url)}" target="_blank">Download Content</a></p>')

    # Check for attachments
    attachments = lesson.get("Attachments", [])
    if isinstance(attachments, list):
        for att in attachments:
            if isinstance(att, dict):
                att_url = att.get("Url", "")
                att_name = att.get("Name", "Attachment")
                if att_url:
                    html_parts.append(f'<p><a href="{html.escape(att_url)}" target="_blank">{html.escape(att_name)}</a></p>')

    if not html_parts:
        html_parts.append(f"<p>Lesson: {title}</p>")

    html_body = "\n".join(html_parts)

    html_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<html url_name="html_{lesson_id}" display_name="{title}">
{html_body}
</html>"""
    return html_xml


def add_to_tar(tar: tarfile.TarFile, root: Path) -> None:
    for path in root.rglob("*"):
        arcname = path.relative_to(root)
        tar.add(path, arcname=str(arcname))


def create_course_package(
    category: dict,
    courses: list[dict],
    key: CourseKey,
    output_dir: Path,
    keep_build: bool,
) -> tuple[Path, int, int]:
    """Create a single OLX course package for a category."""
    course_dir = output_dir / key.slug
    build_root = course_dir / "build"
    ensure_clean_dir(build_root)

    # Directory scaffold
    base_dirs = [
        "about",
        "chapter",
        "sequential",
        "vertical",
        "html",
        "video",
        f"policies/courses/{key.org}/{key.number}/{key.run}",
    ]
    for sub in base_dirs:
        (build_root / sub).mkdir(parents=True, exist_ok=True)

    # Course metadata
    course_xml_path = build_root / "course.xml"
    overview_path = build_root / "about/overview.html"
    policy_path = (
        build_root
        / f"policies/courses/{key.org}/{key.number}/{key.run}/policy.json"
    )

    overview_html = f"<p>{html.escape(category['name'])}</p>"
    write_text(overview_path, overview_html)
    write_text(policy_path, build_policy_json(category["name"]))

    chapter_refs: list[str] = []
    total_lessons = 0

    # Each MCT course becomes a chapter
    for chapter_index, course in enumerate(courses, start=1):
        str(course.get("Id", ""))
        course_name = course.get("Name", f"Module {chapter_index}")
        chapter_url = f"chapter{chapter_index}"
        chapter_refs.append(f'  <chapter url_name="{chapter_url}" />')

        # Generate placeholder lessons based on NumPublishedLessons
        lessons = generate_placeholder_lessons(course)
        total_lessons += len(lessons)
        sequential_refs: list[str] = []

        # Each lesson becomes a sequential/vertical
        for lesson_index, lesson in enumerate(lessons, start=1):
            lesson_id = str(lesson.get("Id", f"{lesson_index}"))
            lesson_name = lesson.get("Name", f"Lesson {lesson_index}")
            seq_url = f"ch{chapter_index}_seq{lesson_index}"
            vertical_url = f"{seq_url}_vert"
            sequential_refs.append(f'  <sequential url_name="{seq_url}" />')

            # Create sequential
            sequential_xml = f"""<?xml version="1.0" encoding="utf-8"?>
<sequential display_name="{html.escape(lesson_name)}">
  <vertical url_name="{vertical_url}" />
</sequential>
"""
            write_text(build_root / f"sequential/{seq_url}.xml", sequential_xml)

            # Create HTML block for placeholder lesson
            vertical_blocks: list[str] = []
            html_block_id = f"html_{lesson_id}"
            html_xml = create_html_block_for_lesson(lesson)
            write_text(build_root / f"html/{html_block_id}.xml", html_xml)
            vertical_blocks.append(f'  <html url_name="{html_block_id}" />')

            # Create vertical
            vertical_xml = f"""<?xml version="1.0" encoding="utf-8"?>
<vertical display_name="{html.escape(lesson_name)}">
{chr(10).join(vertical_blocks)}
</vertical>
"""
            write_text(build_root / f"vertical/{vertical_url}.xml", vertical_xml)

        # Create chapter XML
        chapter_xml = f"""<?xml version="1.0" encoding="utf-8"?>
<chapter url_name="{chapter_url}" display_name="{html.escape(course_name)}">
{chr(10).join(sequential_refs)}
</chapter>
"""
        write_text(build_root / f"chapter/{chapter_url}.xml", chapter_xml)

    # Create course.xml
    course_xml = f"""<?xml version="1.0" encoding="utf-8"?>
<course url_name="course" org="{key.org}" course="{key.number}" run="{key.run}" display_name="{html.escape(key.title)}" language="en">
{chr(10).join(chapter_refs)}
</course>
"""
    write_text(course_xml_path, course_xml)

    # Create tarball
    tar_path = course_dir / key.package_name
    if tar_path.exists():
        tar_path.unlink()
    with tarfile.open(tar_path, "w:gz") as tar:
        add_to_tar(tar, build_root)

    if not keep_build:
        shutil.rmtree(build_root)

    return tar_path, len(courses), total_lessons


def write_manifest(path: Path, rows: Iterable[dict]) -> None:
    fieldnames = [
        "category_id",
        "title",
        "org",
        "course_number",
        "run",
        "package_path",
        "chapter_count",
        "lesson_count",
    ]
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build category-level Open edX course packages from MCT data"
    )
    parser.add_argument("--categories", required=True, help="Path to categories.ndjson")
    parser.add_argument("--courses", required=True, help="Path to courses.ndjson")
    parser.add_argument("--output-dir", required=True, help="Destination directory for packages")
    parser.add_argument("--org", default="SKILLOURFUTURE", help="Open edX organization short code")
    parser.add_argument(
        "--keep-build",
        action="store_true",
        help="Keep the expanded folder next to each tarball for inspection",
    )
    args = parser.parse_args()

    # Load data
    categories = load_categories(Path(args.categories))
    courses_by_category = load_courses_by_category(Path(args.courses))

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    manifest_rows: list[dict] = []

    print(f"Found {len(categories)} categories")
    print(f"Found {sum(len(c) for c in courses_by_category.values())} courses across categories")

    # Build one package per category
    for category_id, category in sorted(categories.items()):
        courses = courses_by_category.get(category_id, [])

        if not courses:
            print(f"Skipping category {category_id} ({category['name']}): no courses")
            continue

        # Create course key
        slug = slugify(category["name"], f"category-{category_id}")[:60]
        key = CourseKey(
            category_id=category_id,
            title=category["name"],
            org=args.org,
            number=f"MCT-{category_id}",
            run="course",  # Use "course" as the run (matching existing pattern)
            slug=slug,
        )

        print(f"Building category {category_id}: {category['name']} ({len(courses)} chapters)...")

        package_path, chapter_count, lesson_count = create_course_package(
            category,
            courses,
            key,
            output_dir,
            args.keep_build,
        )

        manifest_rows.append({
            "category_id": category_id,
            "title": category["name"],
            "org": key.org,
            "course_number": key.number,
            "run": key.run,
            "package_path": str(package_path.relative_to(output_dir)),
            "chapter_count": chapter_count,
            "lesson_count": lesson_count,
        })

    write_manifest(output_dir / "course_packages_manifest.csv", manifest_rows)
    print(f"\nBuilt {len(manifest_rows)} category-level course packages in {output_dir}")


if __name__ == "__main__":
    main()
