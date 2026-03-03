#!/usr/bin/env python3
"""Import 15 NEW MCT course packages to K8s CMS pod.

Existing courses (DO NOT reimport): 1, 14, 15, 16, 22, 24, 27, 30, 31, 32, 33, 35, 44, 45, 46
NEW courses to import: 4, 17, 19, 20, 21, 28, 29, 34, 36, 37, 38, 39, 40, 41, 47
"""

import csv
import subprocess
import sys
from pathlib import Path

# Courses that already exist - DO NOT REIMPORT
EXISTING_COURSES = {1, 14, 15, 16, 22, 24, 27, 30, 31, 32, 33, 35, 44, 45, 46}

# NEW courses to import
NEW_COURSES = {4, 17, 19, 20, 21, 28, 29, 34, 36, 37, 38, 39, 40, 41, 47}


def get_pod(namespace: str, service: str) -> str:
    cmd = ['kubectl', 'get', 'pod', '-n', namespace, '-l', f'app.kubernetes.io/name={service}',
           '-o', 'jsonpath={.items[0].metadata.name}']
    return subprocess.check_output(cmd, text=True).strip()


def import_course(namespace: str, pod: str, row: dict, package_path: Path) -> tuple[bool, str]:
    row['category_id']
    f"course-v1:{row['org']}+{row['course_number']}+{row['run']}"
    slug = Path(row['package_path']).parent.name

    print("   📤 Copying tarball to pod...")
    sys.stdout.flush()
    copy_result = subprocess.run(
        ['kubectl', 'cp', str(package_path), f'{namespace}/{pod}:/tmp/course.tgz'],
        capture_output=True, text=True
    )
    if copy_result.returncode != 0:
        return False, f"Failed to copy: {copy_result.stderr}"

    print("   🔧 Extracting and importing...")
    sys.stdout.flush()

    # Extract and import - import expects parent dir and subdir name
    cmd = f"""
set -euo pipefail
export DJANGO_SETTINGS_MODULE=cms.envs.tutor.production
cd /tmp
rm -rf course_import_base
mkdir -p course_import_base/{slug}
echo "Extracting tarball..."
tar -xzf course.tgz -C course_import_base/{slug}
echo "Updating course.xml..."
cd course_import_base/{slug}
python3 -c "from xml.etree import ElementTree as ET; tree=ET.parse('course.xml'); root=tree.getroot(); root.set('url_name', '{row['run']}'); root.set('run', '{row['run']}'); tree.write('course.xml', encoding='utf-8')"
echo "Running CMS import..."
cd /openedx/edx-platform
python manage.py cms import /tmp/course_import_base {slug} --settings=cms.envs.tutor.production 2>&1
echo "Cleaning up..."
rm -rf /tmp/course_import_base /tmp/course.tgz
echo "Import complete!"
"""

    result = subprocess.run(
        ['kubectl', 'exec', '-n', namespace, pod, '--', 'bash', '-c', cmd],
        capture_output=True, text=True, timeout=300
    )

    # Check for success indicators in output
    output = result.stdout + result.stderr
    success_indicators = [
        "Course run course-v1:",
        "created successfully!",
        "Seeding forum roles for course"
    ]

    # If we see success indicators, consider it successful even if exit code is non-zero
    # (Django management commands sometimes return non-zero on warnings)
    has_success = any(indicator in output for indicator in success_indicators)

    if result.returncode == 0 or has_success:
        # Print relevant output
        # Show last section of output with course creation messages
        lines = output.split('\n')
        relevant_lines = [line for line in lines if 'course-v1:' in line or 'created successfully' in line or 'Seeding' in line or 'Importing' in line]
        if relevant_lines:
            print(f"   ✓ {' '.join(relevant_lines[-3:])}")
        return True, ""
    else:
        error_msg = result.stderr or result.stdout or "Unknown error"
        return False, error_msg


def main():
    manifest = Path('/home/dev/code/mereka-lms/var/migrations/mct/course_packages_category/course_packages_manifest.csv')
    packages_root = Path('/home/dev/code/mereka-lms/var/migrations/mct/course_packages_category')
    namespace = 'mereka-lms'

    if not manifest.exists():
        print(f"❌ Manifest not found: {manifest}")
        sys.exit(1)

    pod = get_pod(namespace, 'cms')
    print(f"🚀 Importing NEW MCT courses to CMS pod: {pod}\n")

    with manifest.open() as f:
        reader = csv.DictReader(f)
        courses = list(reader)

    # Filter to only NEW courses
    new_courses = [row for row in courses if int(row['category_id']) in NEW_COURSES]

    # Sort by enrollment priority (high-enrollment courses first)
    priority_order = [20, 19, 21, 17]  # Developer, Data Analytics, Digital Marketing, PM
    def sort_key(row):
        cat_id = int(row['category_id'])
        if cat_id in priority_order:
            return priority_order.index(cat_id)
        return 100 + cat_id

    new_courses.sort(key=sort_key)

    print(f"📚 Importing {len(new_courses)} NEW courses\n")
    print("Priority courses (high enrollment):")
    for row in new_courses[:4]:
        print(f"  - {row['category_id']}: {row['title']}")
    print()

    success = 0
    failed = 0
    failed_courses = []

    for i, row in enumerate(new_courses, 1):
        course_id = row['category_id']
        course_key = f"course-v1:{row['org']}+{row['course_number']}+{row['run']}"
        package_path = packages_root / row['package_path']

        if not package_path.exists():
            print(f"⚠️  [{i}/{len(new_courses)}] Skipping {course_id}: {package_path} not found")
            failed += 1
            failed_courses.append((course_id, row['title'], "Package not found"))
            continue

        print(f"📦 [{i}/{len(new_courses)}] Importing {row['title']} (ID: {course_id}) -> {course_key}")
        sys.stdout.flush()

        ok, error = import_course(namespace, pod, row, package_path)

        if ok:
            print(f"✅ [{i}/{len(new_courses)}] Successfully imported {row['title']}\n")
            success += 1
        else:
            print(f"❌ [{i}/{len(new_courses)}] Failed to import {row['title']}")
            error_lines = error.split('\n')
            # Show last 10 lines of error
            error_summary = '\n   '.join(error_lines[-10:])
            print(f"   Error:\n   {error_summary}\n")
            failed += 1
            failed_courses.append((course_id, row['title'], error_lines[-3:]))

    print(f"\n{'='*80}")
    print(f"✅ Import complete! Success: {success}/{len(new_courses)}, Failed: {failed}/{len(new_courses)}")
    print(f"{'='*80}\n")

    if failed_courses:
        print("Failed courses:")
        for course_id, title, error in failed_courses:
            print(f"  - ID {course_id}: {title}")
            if isinstance(error, list):
                for line in error:
                    print(f"    {line}")
            else:
                print(f"    {error}")

    return 0 if failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
