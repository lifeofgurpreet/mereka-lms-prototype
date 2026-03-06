#!/usr/bin/env python3
"""Transform MCT export data into format needed for build_course_packages.py.

This script reads the MCT export files and creates:
1. course_structure.json - courses grouped by category (ALL 178 courses from 30 categories)
2. courses.csv - metadata for each course

Strategy:
- Use courses.ndjson as the primary source (178 courses, 30 categories)
- Use structure/course_content.ndjson for detailed lesson content where available (81 courses)
- For courses without detailed content, create a placeholder lesson
"""

import csv
import json
import os
import subprocess
from pathlib import Path


def load_ndjson(filepath):
    """Load NDJSON file (one JSON object per line)."""
    with open(filepath, encoding='utf-8') as f:
        lines = f.readlines()
        return [json.loads(line) for line in lines]


def resolve_repo_root() -> Path:
    """Resolve repository root from env, git, then script-relative fallback."""
    configured = os.environ.get('MEREKA_LMS_REPO_ROOT') or os.environ.get('REPO_ROOT')
    if configured:
        return Path(configured).expanduser().resolve()
    try:
        top = subprocess.check_output(
            ['git', 'rev-parse', '--show-toplevel'],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        if top:
            return Path(top)
    except Exception:
        pass
    return Path(__file__).resolve().parents[1]


def main():
    # Paths
    repo_root = resolve_repo_root()
    exports_dir = repo_root / 'exports' / 'mct'
    output_dir = repo_root / 'var' / 'migrations' / 'mct'
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load data
    print("Loading MCT export data...")

    # Primary source: courses.ndjson (ALL courses)
    all_courses = load_ndjson(exports_dir / 'courses.ndjson')

    # Detailed lesson content (only for 81 courses)
    course_content = load_ndjson(exports_dir / 'structure' / 'course_content.ndjson')
    content_by_course = {c['courseId']: c for c in course_content}

    print(f"Found {len(all_courses)} total courses in courses.ndjson")
    print(f"Found {len(course_content)} courses with detailed content")
    print(f"Missing detailed content: {len(all_courses) - len(course_content)} courses")

    # Build course structure
    course_structure = []
    courses_csv_data = []

    courses_with_content = 0
    courses_with_placeholder = 0

    for course in all_courses:
        course_id = course['Id']
        category_id = course['ParentId']
        category_name = course.get('CategoryName', course.get('ParentNames', [{}])[0].get('Value', f'Category {category_id}'))
        course_name = course.get('Name', f'Course {course_id}')
        course_desc = course.get('Description', '')

        # Try to get detailed content
        content = content_by_course.get(course_id)

        modules = []
        if content:
            # Has detailed lesson content
            courses_with_content += 1
            lessons_data = content.get('CourseItems', [])

            if lessons_data:
                module_lessons = []
                for i, lesson in enumerate(lessons_data, 1):
                    # Skip non-lesson items
                    if lesson.get('ItemType') not in ['Lesson']:
                        continue

                    lesson_data = lesson.get('Data', {})
                    lesson_id = str(lesson_data.get('Id', f'lesson-{i}'))
                    lesson_title = lesson_data.get('Title', f'Lesson {i}')
                    lesson_desc = lesson_data.get('Description', '')

                    # Extract content URLs
                    file_type = lesson_data.get('FileType', '').lower()
                    download_url = lesson_data.get('DownloadUrl', '')
                    playback_url = lesson_data.get('PlaybackUrl', '')
                    aux_pdf = lesson_data.get('AuxPdfUrl', '')
                    aux_word = lesson_data.get('AuxWordUrl', '')

                    module_lessons.append({
                        'id': lesson_id,
                        'title': lesson_title,
                        'description': lesson_desc,
                        'content': {
                            'file_type': file_type,
                            'download_url': download_url,
                            'playback_url': playback_url,
                            'aux_pdf_url': aux_pdf,
                            'aux_word_url': aux_word
                        }
                    })

                if module_lessons:
                    modules.append({
                        'id': f'cat{category_id}-course{course_id}',
                        'title': course_name or f'Course {course_id}',
                        'lessons': module_lessons
                    })
        else:
            # No detailed content - create placeholder
            courses_with_placeholder += 1
            num_lessons = course.get('NumPublishedLessons', 1)

            # Create placeholder lessons based on NumPublishedLessons
            module_lessons = []
            for i in range(1, max(num_lessons, 1) + 1):
                module_lessons.append({
                    'id': f'course{course_id}-lesson{i}',
                    'title': f'Lesson {i}',
                    'description': f'Content for lesson {i} of {course_name}',
                    'content': {
                        'file_type': 'html',
                        'download_url': '',
                        'playback_url': '',
                        'aux_pdf_url': '',
                        'aux_word_url': ''
                    }
                })

            modules.append({
                'id': f'cat{category_id}-course{course_id}',
                'title': course_name or f'Course {course_id}',
                'lessons': module_lessons
            })

        # Add to course structure
        course_structure.append({
            'course_id': course_id,
            'category_id': category_id,
            'category_name': category_name,
            'course_name': course_name,
            'course_description': course_desc,
            'modules': modules
        })

        # Add to CSV data
        courses_csv_data.append({
            'course_id': course_id,
            'category_id': category_id,
            'category_name': category_name,
            'course_name': course_name,
            'course_description': course_desc
        })

    # Write course_structure.json
    structure_file = output_dir / 'course_structure.json'
    print(f"\nWriting course structure to {structure_file}")
    with open(structure_file, 'w', encoding='utf-8') as f:
        json.dump(course_structure, f, indent=2, ensure_ascii=False)

    # Write courses.csv
    csv_file = output_dir / 'courses.csv'
    print(f"Writing courses CSV to {csv_file}")
    with open(csv_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=[
            'course_id', 'category_id', 'category_name',
            'course_name', 'course_description'
        ])
        writer.writeheader()
        writer.writerows(courses_csv_data)

    # Print summary
    print("\n" + "="*60)
    print(f"Courses with detailed content: {courses_with_content}")
    print(f"Courses with placeholder content: {courses_with_placeholder}")

    print("\nCourse count by category:")
    category_counts = {}
    for course in course_structure:
        cat_id = course['category_id']
        cat_name = course['category_name']
        key = f"{cat_id}: {cat_name}"
        category_counts[key] = category_counts.get(key, 0) + 1

    for cat, count in sorted(category_counts.items()):
        print(f"  {cat}: {count} courses")

    print(f"\nTotal: {len(course_structure)} courses across {len(category_counts)} categories")
    print("\nFiles created:")
    print(f"  - {structure_file}")
    print(f"  - {csv_file}")


if __name__ == '__main__':
    main()
