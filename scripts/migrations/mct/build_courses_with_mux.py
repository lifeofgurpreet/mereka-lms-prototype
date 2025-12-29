#!/usr/bin/env python3
"""
Build Open edX course packages with Mux video content.

This script creates OLX packages with proper Video XBlocks pointing to Mux HLS URLs.
Each MCT category becomes an Open edX course with chapters (MCT courses) and
lessons containing video content.

Usage:
    python scripts/migrations/mct/build_courses_with_mux.py \
        --mapping exports/mct/video_mapping_openedx.json \
        --output-dir var/migrations/mct/course_packages_mux

After running, use import_courses_k8s.py to import the packages into Open edX.
"""

import argparse
import html
import json
import shutil
import tarfile
from pathlib import Path
from typing import List


def ensure_clean_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def escape_xml(text: str) -> str:
    """Escape text for XML attributes."""
    return html.escape(str(text), quote=True)


def build_video_xblock(lesson: dict, block_id: str) -> str:
    """Create a Video XBlock for Mux content."""
    title = escape_xml(lesson.get('title', 'Video'))
    hls_url = lesson.get('mux_hls_url', '')
    thumbnail = lesson.get('mux_thumbnail', '')

    return f'''<?xml version="1.0" encoding="UTF-8"?>
<video
    url_name="{block_id}"
    display_name="{title}"
    download_video="false"
    show_captions="true"
    sub="">
  <source src="{escape_xml(hls_url)}"/>
</video>'''


def build_html_xblock(lesson: dict, block_id: str) -> str:
    """Create an HTML XBlock for non-video content (PDFs, etc.)."""
    title = escape_xml(lesson.get('title', 'Content'))
    file_type = lesson.get('file_type', 'unknown')
    original_url = lesson.get('original_url', '')

    if file_type == 'pdf' and original_url:
        # Create an embedded PDF viewer or download link
        content = f'''<div class="lesson-content">
  <h3>{title}</h3>
  <p><a href="{escape_xml(original_url)}" target="_blank" class="btn btn-primary">
    View/Download PDF
  </a></p>
  <iframe src="{escape_xml(original_url)}" width="100%" height="600px" style="border: 1px solid #ccc;"></iframe>
</div>'''
    else:
        content = f'''<div class="lesson-content">
  <h3>{title}</h3>
  <p>Content type: {file_type}</p>
</div>'''

    return f'''<?xml version="1.0" encoding="UTF-8"?>
<html url_name="{block_id}" display_name="{title}">
{content}
</html>'''


def build_course_package(category_id: str, category_data: dict, output_dir: Path) -> Path:
    """Build a single OLX course package for a category."""
    org = "SKILLOURFUTURE"
    number = f"MCT-{category_id}"
    run = "course"

    slug = f"mct-{category_id}"
    course_dir = output_dir / slug
    build_root = course_dir / "build"
    ensure_clean_dir(build_root)

    # Create directory structure
    dirs = ["about", "chapter", "sequential", "vertical", "html", "video", f"policies/{org}/{number}/{run}"]
    for d in dirs:
        (build_root / d).mkdir(parents=True, exist_ok=True)

    # Write overview
    overview_html = f"<p>{escape_xml(category_data['name'])}</p>"
    write_text(build_root / "about" / "overview.html", overview_html)

    # Write policy
    policy = {
        "display_name": category_data['name'],
        "start": "2025-01-01T00:00:00Z",
        "course_visibility": "both",
        "catalog_visibility": "both",
        "invitation_only": False,
        "cert_html_view_enabled": True,
    }
    write_text(build_root / f"policies/{org}/{number}/{run}/policy.json", json.dumps(policy, indent=2))

    chapter_refs = []
    total_videos = 0

    # Sort courses by ID
    courses = sorted(category_data['courses'].items(), key=lambda x: int(x[0]))

    for chapter_idx, (course_id, course_data) in enumerate(courses, start=1):
        chapter_url = f"chapter{chapter_idx}"
        chapter_refs.append(f'  <chapter url_name="{chapter_url}" />')

        sequential_refs = []

        # Sort lessons by display order
        lessons = sorted(course_data['lessons'], key=lambda x: x.get('display_order', 0))

        for lesson_idx, lesson in enumerate(lessons, start=1):
            seq_url = f"ch{chapter_idx}_seq{lesson_idx}"
            vert_url = f"{seq_url}_vert"

            sequential_refs.append(f'  <sequential url_name="{seq_url}" />')

            # Determine block type and create content
            blocks = []
            lesson_id = lesson.get('mct_lesson_id', lesson_idx)

            if lesson.get('has_mux') and lesson.get('mux_hls_url'):
                # Video content
                block_id = f"video_{lesson_id}"
                video_xml = build_video_xblock(lesson, block_id)
                write_text(build_root / "video" / f"{block_id}.xml", video_xml)
                blocks.append(f'  <video url_name="{block_id}" />')
                total_videos += 1
            else:
                # Non-video content (PDF, etc.)
                block_id = f"html_{lesson_id}"
                html_xml = build_html_xblock(lesson, block_id)
                write_text(build_root / "html" / f"{block_id}.xml", html_xml)
                blocks.append(f'  <html url_name="{block_id}" />')

            # Create sequential
            lesson_title = escape_xml(lesson.get('title', f'Lesson {lesson_idx}'))
            sequential_xml = f'''<?xml version="1.0" encoding="utf-8"?>
<sequential display_name="{lesson_title}">
  <vertical url_name="{vert_url}" />
</sequential>'''
            write_text(build_root / "sequential" / f"{seq_url}.xml", sequential_xml)

            # Create vertical
            vertical_xml = f'''<?xml version="1.0" encoding="utf-8"?>
<vertical display_name="{lesson_title}">
{chr(10).join(blocks)}
</vertical>'''
            write_text(build_root / "vertical" / f"{vert_url}.xml", vertical_xml)

        # Create chapter
        chapter_title = escape_xml(course_data.get('name', f'Module {chapter_idx}'))
        chapter_xml = f'''<?xml version="1.0" encoding="utf-8"?>
<chapter url_name="{chapter_url}" display_name="{chapter_title}">
{chr(10).join(sequential_refs)}
</chapter>'''
        write_text(build_root / "chapter" / f"{chapter_url}.xml", chapter_xml)

    # Create course.xml
    course_xml = f'''<?xml version="1.0" encoding="utf-8"?>
<course url_name="course" org="{org}" course="{number}" run="{run}" display_name="{escape_xml(category_data['name'])}" language="en">
{chr(10).join(chapter_refs)}
</course>'''
    write_text(build_root / "course.xml", course_xml)

    # Create tarball
    tar_path = course_dir / f"{slug}.tar.gz"
    with tarfile.open(tar_path, "w:gz") as tar:
        for path in build_root.rglob("*"):
            if path.is_file():
                arcname = path.relative_to(build_root)
                tar.add(path, arcname=str(arcname))

    # Cleanup build directory
    shutil.rmtree(build_root)

    return tar_path, len(courses), total_videos


def main():
    parser = argparse.ArgumentParser(description="Build Open edX courses with Mux videos")
    parser.add_argument("--mapping", default="exports/mct/video_mapping_openedx.json",
                        help="Path to video mapping JSON")
    parser.add_argument("--output-dir", default="var/migrations/mct/course_packages_mux",
                        help="Output directory for course packages")
    parser.add_argument("--category", help="Build only specific category ID")
    args = parser.parse_args()

    # Resolve paths relative to script location
    base_dir = Path(__file__).parent.parent.parent.parent
    mapping_path = base_dir / args.mapping
    output_dir = base_dir / args.output_dir

    # Load mapping
    with open(mapping_path, 'r') as f:
        mapping = json.load(f)

    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Building course packages with Mux videos")
    print(f"  Mapping: {mapping_path}")
    print(f"  Output: {output_dir}")
    print(f"  Categories: {len(mapping['categories'])}")
    print(f"  Total Mux videos: {mapping['statistics']['videos_mapped']}")
    print()

    packages = []
    total_chapters = 0
    total_videos = 0

    for category_id, category_data in sorted(mapping['categories'].items(), key=lambda x: int(x[0])):
        if args.category and category_id != args.category:
            continue

        print(f"Building MCT-{category_id}: {category_data['name'][:50]}...")
        tar_path, chapters, videos = build_course_package(category_id, category_data, output_dir)

        packages.append({
            'category_id': category_id,
            'name': category_data['name'],
            'package': str(tar_path),
            'chapters': chapters,
            'videos': videos,
        })
        total_chapters += chapters
        total_videos += videos
        print(f"  -> {tar_path.name} ({chapters} chapters, {videos} videos)")

    print()
    print(f"{'='*60}")
    print(f"Built {len(packages)} course packages")
    print(f"  Total chapters: {total_chapters}")
    print(f"  Total videos: {total_videos}")
    print()
    print("Next steps:")
    print("1. Import courses to Open edX:")
    print(f"   kubectl cp {output_dir} mereka-lms/cms-xxx:/tmp/courses")
    print("   kubectl exec -it cms-xxx -- bash")
    print("   for f in /tmp/courses/*.tar.gz; do")
    print("     python manage.py cms import_courseware /tmp/courses/ \\")
    print("       --course-key course-v1:SKILLOURFUTURE+MCT-XX+course")
    print("   done")


if __name__ == '__main__':
    main()
