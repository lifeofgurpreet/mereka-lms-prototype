#!/usr/bin/env python3
"""Generate Open edX importable course packages from Kajabi exports.

This script consumes the normalized course metadata produced by
``transform_data.py`` and emits one ``.tar.gz`` file per course that can be
imported via Studio (CMS) or ``tutor local import``.

Example:

```
python scripts/migrations/kajabi/scripts/build_course_packages.py \
  --course-structure scripts/migrations/kajabi/output/course_structure.json \
  --courses-csv scripts/migrations/kajabi/output/courses.csv \
  --output-dir scripts/migrations/kajabi/output/course_packages \
  --org MEREKA \
  --course-prefix MEKA- \
  --run-prefix R \
  --language en
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
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path

DEFAULT_START = "2025-01-01T00:00:00Z"


def slugify(value: str, fallback: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug or fallback


@dataclass
class CourseKey:
    kajabi_id: str
    title: str
    org: str
    number: str
    run: str
    slug: str

    @property
    def package_name(self) -> str:
        return f"{self.slug}.tar.gz"


def load_course_metadata(csv_path: Path) -> dict[str, dict]:
    metadata: dict[str, dict] = {}
    with csv_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            metadata[row["course_id"]] = row
    return metadata


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
        "cert_html_view_enabled": False,
        "certificates_display_behavior": "end",
    }
    return json.dumps(policy, indent=2)


def html_block_for_lesson(lesson: dict) -> str:
    """
    Generate HTML content for a lesson, using real content if available,
    otherwise falling back to a placeholder with metadata.

    Note: content_html is used as-is (not escaped) since it's already HTML from Kajabi.
    This is safe because Kajabi is a trusted source.
    """
    content_html = lesson.get("content_html")
    body = lesson.get("body")
    video_url = lesson.get("video_url")
    download_url = lesson.get("download_url")

    # Build the HTML block
    rows = []

    # Add main content
    if content_html:
        # content_html is already HTML from Kajabi - use it directly
        rows.append(content_html)
    elif body:
        # Plain text body - convert newlines to <br> tags
        rows.append("<p>" + html.escape(body).replace("\n", "<br>\n") + "</p>")
    else:
        # Fallback: placeholder with metadata
        rows.append("<p><em>This lesson was migrated from Kajabi. Replace this placeholder with real content.</em></p>")
        attrs = {
            "Kajabi Lesson ID": lesson.get("id", ""),
            "Status": lesson.get("status", ""),
            "Publishing Option": lesson.get("publishing_option", ""),
        }
        media = lesson.get("media") or {}
        media_id = lesson.get("media_id")
        if media_id:
            attrs["Media ID"] = media_id
            media_attrs = media.get("attributes", {}) if isinstance(media, dict) else {}
            if media_attrs:
                attrs["Media Kind"] = media_attrs.get("kind", "")
                attrs["Media Duration"] = media_attrs.get("duration", "")
                attrs["Media State"] = media_attrs.get("upload_state", "")

        rows.append("<ul>")
        for key, value in attrs.items():
            if value:
                rows.append(
                    f"  <li><strong>{html.escape(key)}:</strong> {html.escape(str(value))}</li>"
                )
        rows.append("</ul>")

    # Add media/download links if available (always add these, even if we have content_html)
    if video_url:
        rows.append(f'<p><a href="{html.escape(video_url)}" target="_blank">Watch Video</a></p>')

    if download_url:
        rows.append(f'<p><a href="{html.escape(download_url)}" download>Download Content</a></p>')

    # Handle included resources (media, downloads from API)
    included_resources = lesson.get("included_resources", [])
    if included_resources:
        for resource in included_resources:
            resource_type = resource.get("type")
            resource_attrs = resource.get("attributes", {})

            if resource_type == "media":
                # Media resource - check for streaming/download URLs
                stream_url = resource_attrs.get("stream_url") or resource_attrs.get("video_url")
                if stream_url:
                    rows.append(f'<p><a href="{html.escape(stream_url)}" target="_blank">Stream Media</a></p>')

            elif resource_type == "downloads":
                # Download resource
                download_link = resource_attrs.get("download_url") or resource_attrs.get("url")
                if download_link:
                    filename = resource_attrs.get("filename", "Download")
                    rows.append(f'<p><a href="{html.escape(download_link)}" download>{html.escape(filename)}</a></p>')

    return "\n".join(rows)


def add_to_tar(tar: tarfile.TarFile, root: Path) -> None:
    for path in root.rglob("*"):
        arcname = path.relative_to(root)
        tar.add(path, arcname=str(arcname))


def create_course_package(
    course: dict,
    metadata: dict,
    key: CourseKey,
    output_dir: Path,
    language: str,
    keep_build: bool,
) -> tuple[Path, int, int]:
    course_dir = output_dir / key.slug
    build_root = course_dir / "build"
    ensure_clean_dir(build_root)

    structure = course.get("modules", [])
    total_lessons = sum(len(m.get("lessons", [])) for m in structure)

    # Directory scaffold
    base_dirs = [
        "about",
        "chapter",
        "sequential",
        "vertical",
        "html",
        f"policies/courses/{key.org}/{key.number}/{key.run}",
    ]
    for sub in base_dirs:
        (build_root / sub).mkdir(parents=True, exist_ok=True)

    course_xml_path = build_root / "course.xml"
    overview_path = build_root / "about/overview.html"
    policy_path = (
        build_root
        / f"policies/courses/{key.org}/{key.number}/{key.run}/policy.json"
    )

    course_desc = metadata.get("description", "")
    write_text(overview_path, course_desc or "<p>No description provided.</p>")
    write_text(policy_path, build_policy_json(metadata.get("title", key.title)))

    chapter_refs: list[str] = []

    modules = structure if structure else [
        {
            "id": f"{key.kajabi_id}-module",
            "title": metadata.get("title", key.title) or key.title,
            "lessons": [],
        }
    ]

    if not structure:
        # add placeholder lesson to avoid empty course imports
        modules[0]["lessons"].append(
            {
                "id": f"{key.kajabi_id}-lesson",
                "title": "Kajabi Placeholder Lesson",
                "status": "draft",
                "publishing_option": "draft",
            }
        )
        total_lessons = 1

    for module_index, module in enumerate(modules, start=1):
        chapter_url = f"module{module_index}"
        chapter_refs.append(f"  <chapter url_name=\"{chapter_url}\" />")
        sequential_refs: list[str] = []
        lessons = module.get("lessons", [])
        if not lessons:
            lessons = [
                {
                    "id": f"{module.get('id', module_index)}-placeholder",
                    "title": "Placeholder Lesson",
                    "status": "draft",
                    "publishing_option": "draft",
                }
            ]
        for lesson_index, lesson in enumerate(lessons, start=1):
            seq_url = f"module{module_index}_lesson{lesson_index}"
            vertical_url = f"{seq_url}_unit"
            html_url = f"{seq_url}_html"
            sequential_refs.append(f"  <sequential url_name=\"{seq_url}\" />")

            sequential_xml = f"""<?xml version=\"1.0\" encoding=\"utf-8\"?>
<sequential display_name=\"{html.escape(lesson.get('title') or f'Lesson {lesson_index}') }\">
  <vertical url_name=\"{vertical_url}\" />
</sequential>
"""
            write_text(build_root / f"sequential/{seq_url}.xml", sequential_xml)

            vertical_xml = f"""<?xml version=\"1.0\" encoding=\"utf-8\"?>
<vertical display_name=\"{html.escape(lesson.get('title') or f'Lesson {lesson_index}') }\">
  <html url_name=\"{html_url}\" />
</vertical>
"""
            write_text(build_root / f"vertical/{vertical_url}.xml", vertical_xml)

            html_body = html_block_for_lesson(lesson)
            html_xml = f"""<?xml version=\"1.0\" encoding=\"utf-8\"?>
<html display_name=\"{html.escape(lesson.get('title') or 'Lesson')}\">
{html_body}
</html>
"""
            write_text(build_root / f"html/{html_url}.xml", html_xml)

        chapter_xml = f"""<?xml version=\"1.0\" encoding=\"utf-8\"?>
<chapter url_name=\"{chapter_url}\" display_name=\"{html.escape(module.get('title') or f'Module {module_index}') }\">
{chr(10).join(sequential_refs)}
</chapter>
"""
        write_text(build_root / f"chapter/{chapter_url}.xml", chapter_xml)

    course_xml = f"""<?xml version=\"1.0\" encoding=\"utf-8\"?>
<course url_name=\"course\" org=\"{key.org}\" course=\"{key.number}\" run=\"{key.run}\" display_name=\"{html.escape(key.title)}\" language=\"{language}\">
{chr(10).join(chapter_refs)}
</course>
"""
    write_text(course_xml_path, course_xml)

    tar_path = course_dir / key.package_name
    if tar_path.exists():
        tar_path.unlink()
    with tarfile.open(tar_path, "w:gz") as tar:
        add_to_tar(tar, build_root)

    if not keep_build:
        shutil.rmtree(build_root)

    return tar_path, len(modules), total_lessons


def determine_course_key(
    course: dict,
    org: str,
    course_prefix: str,
    run_prefix: str,
    constant_run: str | None,
) -> CourseKey:
    course_id = str(course["course_id"])
    title = course.get("title") or f"Kajabi Course {course_id}"
    slug = slugify(title, f"course-{course_id}")[:60]
    number = f"{course_prefix}{course_id}"
    run = constant_run or f"{run_prefix}{course_id}"
    return CourseKey(
        kajabi_id=course_id,
        title=title,
        org=org,
        number=number,
        run=run,
        slug=slug,
    )


def write_manifest(path: Path, rows: Iterable[dict]) -> None:
    fieldnames = [
        "kajabi_course_id",
        "title",
        "org",
        "course_number",
        "run",
        "package_path",
        "module_count",
        "lesson_count",
    ]
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Open edX course import packages")
    parser.add_argument("--course-structure", required=True, help="Path to course_structure.json")
    parser.add_argument("--courses-csv", required=True, help="Path to courses.csv with metadata")
    parser.add_argument("--output-dir", required=True, help="Destination directory for packages")
    parser.add_argument("--org", default="MEREKA", help="Open edX organization short code")
    parser.add_argument("--course-prefix", default="MEKA-", help="Prefix for course numbers")
    parser.add_argument("--run-prefix", default="RUN-", help="Prefix for course run IDs")
    parser.add_argument(
        "--constant-run",
        default=None,
        help="If set, use this run for all courses (instead of run-prefix + ID)",
    )
    parser.add_argument("--language", default="en", help="Course language code")
    parser.add_argument(
        "--keep-build",
        action="store_true",
        help="Keep the expanded folder next to each tarball for inspection",
    )
    args = parser.parse_args()

    structure_data = json.loads(Path(args.course_structure).read_text(encoding="utf-8"))
    courses_meta = load_course_metadata(Path(args.courses_csv))
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    manifest_rows: list[dict] = []

    for course in structure_data:
        course_id = course["course_id"]
        meta = courses_meta.get(str(course_id), {})
        key = determine_course_key(meta or {"course_id": course_id, "title": course.get("title")}, args.org, args.course_prefix, args.run_prefix, args.constant_run)

        package_path, module_count, lesson_count = create_course_package(
            course,
            meta or {"title": course.get("title", "")},
            key,
            output_dir,
            args.language,
            args.keep_build,
        )

        manifest_rows.append(
            {
                "kajabi_course_id": key.kajabi_id,
                "title": key.title,
                "org": key.org,
                "course_number": key.number,
                "run": key.run,
                "package_path": str(package_path.relative_to(output_dir)),
                "module_count": module_count,
                "lesson_count": lesson_count,
            }
        )

    write_manifest(output_dir / "course_packages_manifest.csv", manifest_rows)
    print(f"Built {len(manifest_rows)} course packages in {output_dir}")


if __name__ == "__main__":
    main()
