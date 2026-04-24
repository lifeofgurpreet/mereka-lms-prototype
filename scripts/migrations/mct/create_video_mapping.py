#!/usr/bin/env python3
"""
Create a comprehensive video mapping for MCT to Open edX.

This script combines:
- MCT course content (with lesson IDs)
- Mux upload results (with playback IDs)

To produce a mapping file that can be used to update Open edX courses.

Output: exports/mct/video_mapping_openedx.json
"""

import json
from pathlib import Path


def main():
    base_dir = Path(__file__).parent.parent.parent.parent
    exports_dir = base_dir / 'exports' / 'mct'

    # Load Mux upload results
    mux_results_file = exports_dir / 'mux_upload_complete.json'
    with open(mux_results_file) as f:
        mux_data = json.load(f)

    # Create mapping from MCT lesson ID to Mux playback info
    mux_by_lesson = {}
    for video in mux_data['successful']:
        lesson_id = video['mct_lesson_id']
        mux_by_lesson[lesson_id] = {
            'title': video['title'],
            'mux_asset_id': video['mux_asset_id'],
            'mux_playback_id': video['mux_playback_id'],
            'mux_hls_url': f"https://stream.mux.com/{video['mux_playback_id']}.m3u8",
            'mux_thumbnail': f"https://image.mux.com/{video['mux_playback_id']}/thumbnail.jpg",
        }

    print(f"Loaded {len(mux_by_lesson)} Mux videos")

    # Load course content from structure
    content_file = exports_dir / 'structure' / 'course_content.ndjson'
    courses_data = []
    with open(content_file) as f:
        for line in f:
            if line.strip():
                courses_data.append(json.loads(line))

    print(f"Loaded {len(courses_data)} MCT courses")

    # Build mapping: Category -> Course -> Lessons with Mux URLs
    mapping = {
        'generated_at': mux_data.get('completed_at', ''),
        'statistics': {
            'total_mux_videos': len(mux_by_lesson),
            'total_mct_courses': len(courses_data),
            'videos_mapped': 0,
            'videos_not_in_mux': 0,
        },
        'categories': {},
    }

    videos_mapped = 0
    videos_not_in_mux = 0

    for course in courses_data:
        category_id = str(course['categoryId'])
        category_name = course['categoryName']
        course_id = str(course['courseId'])
        course_name = course.get('courseName', 'Unknown')

        # Initialize category if not exists
        if category_id not in mapping['categories']:
            mapping['categories'][category_id] = {
                'name': category_name,
                'openedx_course_id': f"course-v1:SKILLOURFUTURE+MCT-{category_id}+course",
                'courses': {},
            }

        # Initialize course (chapter) if not exists
        if course_id not in mapping['categories'][category_id]['courses']:
            mapping['categories'][category_id]['courses'][course_id] = {
                'name': course_name,
                'lessons': [],
            }

        # Process lessons
        for item in course.get('CourseItems', []):
            if item.get('ItemType') != 'Lesson':
                continue

            lesson_data = item.get('Data', {})
            lesson_id = lesson_data.get('Id')
            if not lesson_id:
                continue

            file_type = lesson_data.get('FileType', '').lower()

            lesson_info = {
                'mct_lesson_id': lesson_id,
                'title': lesson_data.get('Title', 'Unknown'),
                'file_type': file_type,
                'display_order': item.get('DisplayOrder', 0),
            }

            # Only look for Mux mapping for video content
            if file_type == 'video':
                if lesson_id in mux_by_lesson:
                    mux_info = mux_by_lesson[lesson_id]
                    lesson_info['mux_playback_id'] = mux_info['mux_playback_id']
                    lesson_info['mux_hls_url'] = mux_info['mux_hls_url']
                    lesson_info['mux_thumbnail'] = mux_info['mux_thumbnail']
                    lesson_info['has_mux'] = True
                    videos_mapped += 1
                else:
                    lesson_info['has_mux'] = False
                    lesson_info['original_url'] = lesson_data.get('PlaybackUrl', '')
                    videos_not_in_mux += 1
            else:
                # Non-video content (PDFs, etc.)
                lesson_info['has_mux'] = False
                lesson_info['original_url'] = lesson_data.get('Url', '')

            mapping['categories'][category_id]['courses'][course_id]['lessons'].append(lesson_info)

    mapping['statistics']['videos_mapped'] = videos_mapped
    mapping['statistics']['videos_not_in_mux'] = videos_not_in_mux

    # Save mapping
    output_file = exports_dir / 'video_mapping_openedx.json'
    with open(output_file, 'w') as f:
        json.dump(mapping, f, indent=2)

    print(f"\n{'='*60}")
    print(f"Mapping created: {output_file}")
    print(f"  Total Mux videos: {len(mux_by_lesson)}")
    print(f"  Videos mapped: {videos_mapped}")
    print(f"  Videos not in Mux: {videos_not_in_mux}")
    print(f"  Categories: {len(mapping['categories'])}")

    # Print sample
    print("\nSample mapping for first category:")
    for cat_id, cat_data in list(mapping['categories'].items())[:1]:
        print(f"  Category {cat_id}: {cat_data['name']}")
        print(f"  Open edX course: {cat_data['openedx_course_id']}")
        for course_id, course_data in list(cat_data['courses'].items())[:1]:
            print(f"    Course {course_id}: {course_data['name']}")
            for lesson in course_data['lessons'][:3]:
                if lesson.get('has_mux'):
                    print(f"      - {lesson['title'][:40]}... -> {lesson['mux_hls_url'][:50]}...")
                else:
                    print(f"      - {lesson['title'][:40]}... (no Mux)")


if __name__ == '__main__':
    main()
