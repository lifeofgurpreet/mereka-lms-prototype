#!/usr/bin/env python3
"""Import MCT course packages directly to K8s CMS pod."""

import csv
import subprocess
import sys
from pathlib import Path


def get_pod(namespace: str, service: str) -> str:
    cmd = ['kubectl', 'get', 'pod', '-n', namespace, '-l', f'app.kubernetes.io/name={service}', 
           '-o', 'jsonpath={.items[0].metadata.name}']
    return subprocess.check_output(cmd, text=True).strip()


def import_course(namespace: str, pod: str, row: dict, package_path: Path) -> tuple[bool, str]:
    course_id = row['mct_course_id']
    course_key = f"course-v1:{row['org']}+{row['course_number']}+{row['run']}"
    slug = Path(row['package_path']).parent.name
    
    print(f"   📤 Copying tarball to pod...")
    sys.stdout.flush()
    copy_result = subprocess.run(
        ['kubectl', 'cp', str(package_path), f'{namespace}/{pod}:/tmp/course.tgz'],
        capture_output=True, text=True
    )
    if copy_result.returncode != 0:
        return False, f"Failed to copy: {copy_result.stderr}"
    
    print(f"   🔧 Extracting and importing...")
    sys.stdout.flush()
    
    # Extract and import - import expects parent dir and subdir name
    cmd = f"""
set -euo pipefail
export DJANGO_SETTINGS_MODULE=tutor.production
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
python manage.py cms import /tmp/course_import_base {slug} --settings=tutor.production 2>&1
echo "Cleaning up..."
rm -rf /tmp/course_import_base /tmp/course.tgz
echo "Import complete!"
"""
    
    result = subprocess.run(
        ['kubectl', 'exec', '-n', namespace, pod, '--', 'bash', '-c', cmd],
        capture_output=True, text=True, timeout=300
    )
    
    if result.returncode == 0:
        # Print output for visibility
        if result.stdout:
            print(f"   Output: {result.stdout[-500:]}")  # Last 500 chars
        return True, ""
    else:
        error_msg = result.stderr or result.stdout or "Unknown error"
        return False, error_msg


def main():
    manifest = Path('ops/migrations/mct/output/course_packages_categories/course_packages_manifest.csv')
    packages_root = Path('ops/migrations/mct/output/course_packages_categories')
    namespace = 'mereka-lms'
    
    pod = get_pod(namespace, 'cms')
    print(f"🚀 Importing courses to CMS pod: {pod}\n")
    
    with manifest.open() as f:
        reader = csv.DictReader(f)
        courses = list(reader)
    
    # Only import first 2 courses as requested
    courses = courses[:2]
    print(f"📚 Importing {len(courses)} courses (limited to 2 for testing)\n")
    
    success = 0
    failed = 0
    
    for i, row in enumerate(courses, 1):
        course_id = row['mct_course_id']
        course_key = f"course-v1:{row['org']}+{row['course_number']}+{row['run']}"
        package_path = packages_root / row['package_path']
        
        if not package_path.exists():
            print(f"⚠️  [{i}/{len(courses)}] Skipping {course_id}: {package_path} not found")
            failed += 1
            continue
            
        print(f"📦 [{i}/{len(courses)}] Importing {row['title']} ({course_id}) -> {course_key}")
        sys.stdout.flush()
        
        ok, error = import_course(namespace, pod, row, package_path)
        
        if ok:
            print(f"✅ [{i}/{len(courses)}] Successfully imported {row['title']}\n")
            success += 1
        else:
            print(f"❌ [{i}/{len(courses)}] Failed to import {row['title']}")
            error_lines = error.split('\n')
            print(f"   Error: {' '.join(error_lines[-10:])}\n")
            failed += 1
    
    print(f"\n✅ Import complete! Success: {success}, Failed: {failed}")


if __name__ == '__main__':
    main()

