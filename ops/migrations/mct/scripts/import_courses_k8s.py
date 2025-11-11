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


def import_course(namespace: str, pod: str, row: dict, package_path: Path) -> bool:
    course_id = row['mct_course_id']
    course_key = f"course-v1:{row['org']}+{row['course_number']}+{row['run']}"
    slug = Path(row['package_path']).parent.name
    
    # Copy tarball to pod
    subprocess.run(['kubectl', 'cp', str(package_path), f'{namespace}/{pod}:/tmp/course.tgz'], check=True)
    
    # Extract and import - import expects parent dir and subdir name
    course_key = f"course-v1:{row['org']}+{row['course_number']}+{row['run']}"
    cmd = f"""
set -euo pipefail
export DJANGO_SETTINGS_MODULE=tutor.production
cd /tmp
rm -rf course_import_base
mkdir -p course_import_base/{slug}
tar -xzf course.tgz -C course_import_base/{slug}
cd course_import_base/{slug}
python3 -c "from xml.etree import ElementTree as ET; tree=ET.parse('course.xml'); root=tree.getroot(); root.set('url_name', '{row['run']}'); root.set('run', '{row['run']}'); tree.write('course.xml', encoding='utf-8')"
cd /openedx/edx-platform
python manage.py cms import /tmp/course_import_base {slug} --settings=tutor.production
rm -rf /tmp/course_import_base /tmp/course.tgz
"""
    
    result = subprocess.run(['kubectl', 'exec', '-n', namespace, pod, '--', 'bash', '-c', cmd], 
                           capture_output=True, text=True)
    
    return result.returncode == 0, result.stderr


def main():
    manifest = Path('ops/migrations/mct/output/course_packages_categories/course_packages_manifest.csv')
    packages_root = Path('ops/migrations/mct/output/course_packages_categories')
    namespace = 'mereka-lms'
    
    pod = get_pod(namespace, 'cms')
    print(f"🚀 Importing courses to CMS pod: {pod}\n")
    
    with manifest.open() as f:
        reader = csv.DictReader(f)
        courses = list(reader)
    
    print(f"📚 Found {len(courses)} courses to import\n")
    
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
            
        print(f"📦 [{i}/{len(courses)}] Importing {course_id} -> {course_key}...")
        
        ok, error = import_course(namespace, pod, row, package_path)
        
        if ok:
            print(f"✅ [{i}/{len(courses)}] Imported {course_id}\n")
            success += 1
        else:
            print(f"❌ [{i}/{len(courses)}] Failed {course_id}")
            # Show last 500 chars of error (usually the actual error is at the end)
            error_lines = error.split('\n')
            print(f"   Error: {' '.join(error_lines[-10:])}\n")
            failed += 1
    
    print(f"\n✅ Import complete! Success: {success}, Failed: {failed}")


if __name__ == '__main__':
    main()

