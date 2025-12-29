#!/usr/bin/env python3
"""Generate Open edX importable course packages from MCT exports.

This script consumes the normalized course metadata produced by
``transform_data.py`` and emits one ``.tar.gz`` file per course that can be
imported via Studio (CMS) or ``tutor local import``.

Example:

```
python ops/migrations/mct/scripts/build_course_packages.py \
  --course-structure ops/migrations/mct/output/course_structure.json \
  --courses-csv ops/migrations/mct/output/courses.csv \
  --output-dir ops/migrations/mct/output/course_packages \
  --org SKILLOURFUTURE \
  --course-prefix MCT- \
  --run-prefix RUN- \
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
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple


DEFAULT_START = "2025-01-01T00:00:00Z"


def slugify(value: str, fallback: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug or fallback


@dataclass
class CourseKey:
    mct_id: str
    title: str
    org: str
    number: str
    run: str
    slug: str

    @property
    def package_name(self) -> str:
        return f"{self.slug}.tar.gz"


def load_course_metadata(csv_path: Path) -> Dict[str, dict]:
    metadata: Dict[str, dict] = {}
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


def create_video_block(lesson: dict, video_url: str) -> str:
    """Create a video XBlock XML for Open edX."""
    title = html.escape(lesson.get("title", "Video Lesson"))
    description = html.escape(lesson.get("description", "") or "")
    
    # Video XBlock XML structure
    video_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<video url_name="{html.escape(lesson.get('id', 'video'))}" display_name="{title}" download_video="false" show_captions="true">
  <source src="{html.escape(video_url)}"/>
  <transcripts language="en"/>
</video>"""
    return video_xml


def create_html_block_for_content(lesson: dict, content: dict) -> str:
    """Create HTML block content for PDFs, descriptions, etc."""
    title = html.escape(lesson.get("title", "Lesson"))
    description = html.escape(lesson.get("description", "") or "")
    
    file_type = content.get("file_type", "").lower()
    download_url = content.get("download_url", "")
    aux_pdf_url = content.get("aux_pdf_url", "")
    aux_word_url = content.get("aux_word_url", "")
    
    html_parts = []
    
    if description:
        html_parts.append(f"<p>{description}</p>")
    
    # Add video link if it's a video but we're using HTML block
    playback_url = content.get("playback_url", "")
    if playback_url:
        html_parts.append(f'<p><a href="{html.escape(playback_url)}" target="_blank">Watch Video</a></p>')
    
    # Add PDF link
    if file_type == "pdf" and download_url:
        html_parts.append(f'<p><a href="{html.escape(download_url)}" target="_blank">Download PDF: {title}</a></p>')
    elif aux_pdf_url:
        html_parts.append(f'<p><a href="{html.escape(aux_pdf_url)}" target="_blank">Download PDF Resource</a></p>')
    
    # Add Word doc link
    if aux_word_url:
        html_parts.append(f'<p><a href="{html.escape(aux_word_url)}" target="_blank">Download Word Document</a></p>')
    
    if not html_parts:
        html_parts.append(f"<p>Lesson: {title}</p>")
    
    html_body = "\n".join(html_parts)
    
    html_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<html url_name="{html.escape(lesson.get('id', 'html'))}" display_name="{title}">
{html_body}
</html>"""
    return html_xml


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
) -> Tuple[Path, int, int]:
    course_dir = output_dir / key.slug
    build_root = course_dir / "build"
    ensure_clean_dir(build_root)

    structure = course.get("modules", [])
    total_lessons = sum(len(m.get("lessons", [])) for m in structure)

    # Directory scaffold - add video directory for video XBlocks
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

    course_xml_path = build_root / "course.xml"
    overview_path = build_root / "about/overview.html"
    policy_path = (
        build_root
        / f"policies/courses/{key.org}/{key.number}/{key.run}/policy.json"
    )

    course_desc = metadata.get("course_description", "") or course.get("course_description", "")
    write_text(overview_path, course_desc or "<p>No description provided.</p>")
    write_text(policy_path, build_policy_json(metadata.get("course_name", key.title) or key.title))

    chapter_refs: List[str] = []

    modules = structure if structure else [
        {
            "id": f"{key.mct_id}-module",
            "title": metadata.get("course_name", key.title) or key.title,
            "lessons": [],
        }
    ]

    if not structure:
        # add placeholder lesson to avoid empty course imports
        modules[0]["lessons"].append(
            {
                "id": f"{key.mct_id}-lesson",
                "title": "MCT Placeholder Lesson",
            }
        )
        total_lessons = 1

    for module_index, module in enumerate(modules, start=1):
        chapter_url = f"module{module_index}"
        chapter_refs.append(f"  <chapter url_name=\"{chapter_url}\" />")
        sequential_refs: List[str] = []
        lessons = module.get("lessons", [])
        if not lessons:
            lessons = [
                {
                    "id": f"{module.get('id', module_index)}-placeholder",
                    "title": "Placeholder Lesson",
                }
            ]
        for lesson_index, lesson in enumerate(lessons, start=1):
            seq_url = f"module{module_index}_lesson{lesson_index}"
            vertical_url = f"{seq_url}_unit"
            sequential_refs.append(f"  <sequential url_name=\"{seq_url}\" />")

            sequential_xml = f"""<?xml version="1.0" encoding="utf-8"?>
<sequential display_name="{html.escape(lesson.get('title') or f'Lesson {lesson_index}')}">
  <vertical url_name="{vertical_url}" />
</sequential>
"""
            write_text(build_root / f"sequential/{seq_url}.xml", sequential_xml)

            # Determine content type and create appropriate block
            content = lesson.get("content", {})
            file_type = content.get("file_type", "").lower()
            video_url = content.get("playback_url") or content.get("download_url", "")
            
            vertical_blocks: List[str] = []
            
            # Use video XBlock for videos, HTML block for everything else
            if file_type == "video" and video_url:
                video_block_id = f"{seq_url}_video"
                video_xml = create_video_block(lesson, video_url)
                write_text(build_root / f"video/{video_block_id}.xml", video_xml)
                vertical_blocks.append(f'  <video url_name="{video_block_id}" />')
            else:
                # Use HTML block for PDFs, descriptions, etc.
                html_block_id = f"{seq_url}_html"
                html_xml = create_html_block_for_content(lesson, content)
                write_text(build_root / f"html/{html_block_id}.xml", html_xml)
                vertical_blocks.append(f'  <html url_name="{html_block_id}" />')

            vertical_xml = f"""<?xml version="1.0" encoding="utf-8"?>
<vertical display_name="{html.escape(lesson.get('title') or f'Lesson {lesson_index}')}">
{chr(10).join(vertical_blocks)}
</vertical>
"""
            write_text(build_root / f"vertical/{vertical_url}.xml", vertical_xml)

        chapter_xml = f"""<?xml version="1.0" encoding="utf-8"?>
<chapter url_name="{chapter_url}" display_name="{html.escape(module.get('title') or f'Module {module_index}')}">
{chr(10).join(sequential_refs)}
</chapter>
"""
        write_text(build_root / f"chapter/{chapter_url}.xml", chapter_xml)

    course_xml = f"""<?xml version="1.0" encoding="utf-8"?>
<course url_name="course" org="{key.org}" course="{key.number}" run="{key.run}" display_name="{html.escape(key.title)}" language="{language}">
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
    title = course.get("course_name") or f"MCT Course {course_id}"
    slug = slugify(title, f"course-{course_id}")[:60]
    number = f"{course_prefix}{course_id}"
    run = constant_run or f"{run_prefix}{course_id}"
    return CourseKey(
        mct_id=course_id,
        title=title,
        org=org,
        number=number,
        run=run,
        slug=slug,
    )


def write_manifest(path: Path, rows: Iterable[dict]) -> None:
    fieldnames = [
        "mct_course_id",
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
            # Include a duplicate key to be compatible with the generic import script
            row = dict(row)
            row["kajabi_course_id"] = row.get("mct_course_id", "")
            writer.writerow(row)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Open edX course import packages from MCT")
    parser.add_argument("--course-structure", required=True, help="Path to course_structure.json")
    parser.add_argument("--courses-csv", required=True, help="Path to courses.csv with metadata")
    parser.add_argument("--output-dir", required=True, help="Destination directory for packages")
    parser.add_argument("--org", default="SKILLOURFUTURE", help="Open edX organization short code")
    parser.add_argument("--course-prefix", default="MCT-", help="Prefix for course numbers")
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

    manifest_rows: List[dict] = []

    for course in structure_data:
        course_id = course["course_id"]
        meta = courses_meta.get(str(course_id), {})
        key = determine_course_key(
            {"course_id": course_id, "course_name": course.get("course_name", "")},
            args.org,
            args.course_prefix,
            args.run_prefix,
            args.constant_run,
        )

        package_path, module_count, lesson_count = create_course_package(
            course,
            meta or {"course_name": course.get("course_name", "")},
            key,
            output_dir,
            args.language,
            args.keep_build,
        )

        manifest_rows.append(
            {
                "mct_course_id": key.mct_id,
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

