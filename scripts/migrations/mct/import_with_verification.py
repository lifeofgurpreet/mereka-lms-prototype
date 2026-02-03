#!/usr/bin/env python3
"""Import MCT data with proper verification and progress tracking."""

import subprocess
import sys
import time
from pathlib import Path


def get_pod(namespace: str, service: str) -> str:
    cmd = ['kubectl', 'get', 'pod', '-n', namespace, '-l', f'app.kubernetes.io/name={service}', 
           '-o', 'jsonpath={.items[0].metadata.name}']
    return subprocess.check_output(cmd, text=True).strip()


def verify_courses(namespace: str, pod: str) -> int:
    """Verify courses are imported. Returns count."""
    cmd = [
        'kubectl', 'exec', '-n', namespace, pod, '--',
        'python', '/openedx/edx-platform/manage.py', 'cms', '--settings=tutor.production',
        'shell', '-c',
        "from xmodule.modulestore.django import modulestore; store = modulestore(); courses = [c for c in store.get_courses() if 'SKILLOURFUTURE+MCTCAT' in str(c.id)]; print(len(courses))"
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            return int(result.stdout.strip())
    except Exception as e:
        print(f"⚠️  Could not verify courses: {e}")
    return -1


def verify_users(namespace: str, pod: str) -> int:
    """Verify user count. Returns count."""
    cmd = [
        'kubectl', 'exec', '-n', namespace, pod, '--',
        'python', '/openedx/edx-platform/manage.py', 'lms', '--settings=tutor.production',
        'shell', '-c',
        "from django.contrib.auth import get_user_model; User = get_user_model(); print(User.objects.count())"
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            return int(result.stdout.strip())
    except Exception as e:
        print(f"⚠️  Could not verify users: {e}")
    return -1


def import_users_batched(namespace: str, pod: str, csv_path: Path, total: int, batch_size: int = 2000):
    """Import users in batches with progress tracking."""
    print(f"\n📊 Importing {total} users in batches of {batch_size}...\n")
    
    offset = 0
    imported = 0
    failed = 0
    
    while offset < total:
        limit = min(batch_size, total - offset)
        batch_num = (offset // batch_size) + 1
        total_batches = (total + batch_size - 1) // batch_size
        
        print(f"[{batch_num}/{total_batches}] Processing batch: offset {offset}, limit {limit}...", end=' ', flush=True)
        
        cmd = [
            'kubectl', 'exec', '-n', namespace, pod, '--',
            'python', '/tmp/openedx_bulk_import.py', 'users',
            '--csv', '/tmp/mct-users.csv',
            '--settings=lms.envs.tutor.production',
            '--offset', str(offset),
            '--limit', str(limit)
        ]
        
        start_time = time.time()
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        elapsed = time.time() - start_time
        
        if result.returncode == 0:
            # Parse output: processed=127 created=123 updated=4 skipped=0 failed=1873
            output = result.stdout.strip()
            if 'processed=' in output:
                parts = output.split()
                stats = {}
                for part in parts:
                    if '=' in part:
                        k, v = part.split('=')
                        stats[k] = int(v)
                created = stats.get('created', 0)
                updated = stats.get('updated', 0)
                skipped = stats.get('skipped', 0)
                batch_failed = stats.get('failed', 0)
                
                imported += (created + updated)
                failed += batch_failed
                print(f"✅ {created} created, {updated} updated, {skipped} skipped, {batch_failed} failed ({elapsed:.1f}s)")
            else:
                print(f"✅ Complete ({elapsed:.1f}s)")
        else:
            print(f"❌ Failed: {result.stderr[:100]}")
            failed += limit
        
        offset += limit
    
    print(f"\n📊 User import summary: {imported} imported, {failed} failed")
    return imported, failed


def import_enrollments_batched(namespace: str, pod: str, csv_path: Path, total: int, batch_size: int = 5000):
    """Import enrollments in batches with progress tracking."""
    print(f"\n📊 Importing {total} enrollments in batches of {batch_size}...\n")
    
    offset = 0
    imported = 0
    failed = 0
    
    while offset < total:
        limit = min(batch_size, total - offset)
        batch_num = (offset // batch_size) + 1
        total_batches = (total + batch_size - 1) // batch_size
        
        print(f"[{batch_num}/{total_batches}] Processing batch: offset {offset}, limit {limit}...", end=' ', flush=True)
        
        cmd = [
            'kubectl', 'exec', '-n', namespace, pod, '--',
            'python', '/tmp/openedx_bulk_import.py', 'enrollments',
            '--csv', '/tmp/mct-enrollments.csv',
            '--settings=lms.envs.tutor.production',
            '--offset', str(offset),
            '--limit', str(limit)
        ]
        
        start_time = time.time()
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        elapsed = time.time() - start_time
        
        if result.returncode == 0:
            output = result.stdout.strip()
            if 'processed=' in output:
                parts = output.split()
                stats = {}
                for part in parts:
                    if '=' in part:
                        k, v = part.split('=')
                        stats[k] = int(v)
                created = stats.get('created', 0)
                updated = stats.get('updated', 0)
                skipped = stats.get('skipped', 0)
                batch_failed = stats.get('failed', 0)
                
                imported += (created + updated)
                failed += batch_failed
                print(f"✅ {created} created, {updated} updated, {skipped} skipped, {batch_failed} failed ({elapsed:.1f}s)")
            else:
                print(f"✅ Complete ({elapsed:.1f}s)")
        else:
            print(f"❌ Failed: {result.stderr[:100]}")
            failed += limit
        
        offset += limit
    
    print(f"\n📊 Enrollment import summary: {imported} imported, {failed} failed")
    return imported, failed


def main():
    namespace = 'mereka-lms'
    
    # Get pods
    cms_pod = get_pod(namespace, 'cms')
    lms_pod = get_pod(namespace, 'lms')
    
    print("🔍 Verifying current state...")
    
    # Verify courses
    course_count = verify_courses(namespace, cms_pod)
    if course_count >= 0:
        print(f"✅ Found {course_count} MCT courses in system")
    else:
        print("⚠️  Could not verify courses")
    
    # Verify users
    user_count_before = verify_users(namespace, lms_pod)
    if user_count_before >= 0:
        print(f"✅ Current user count: {user_count_before}")
    
    # Copy scripts and CSVs
    print("\n📦 Copying import scripts and data...")
    subprocess.run(['kubectl', 'cp', 'scripts/migrations/kajabi/scripts/openedx_bulk_import.py', 
                   f'{namespace}/{lms_pod}:/tmp/openedx_bulk_import.py'], check=True)
    subprocess.run(['kubectl', 'cp', 'scripts/migrations/mct/output/openedx/users_import_sanitized.csv', 
                   f'{namespace}/{lms_pod}:/tmp/mct-users.csv'], check=True)
    subprocess.run(['kubectl', 'cp', 'scripts/migrations/mct/output/openedx/enrollments_import.csv', 
                   f'{namespace}/{lms_pod}:/tmp/mct-enrollments.csv'], check=True)
    print("✅ Files copied")
    
    # Import users
    users_imported, users_failed = import_users_batched(namespace, lms_pod, 
                                                       Path('scripts/migrations/mct/output/openedx/users_import_sanitized.csv'),
                                                       68785, batch_size=2000)
    
    # Verify users after import
    user_count_after = verify_users(namespace, lms_pod)
    if user_count_after >= 0:
        print(f"\n✅ User count after import: {user_count_after} (added: {user_count_after - user_count_before})")
    
    # Import enrollments
    enrollments_imported, enrollments_failed = import_enrollments_batched(namespace, lms_pod,
                                                                         Path('scripts/migrations/mct/output/openedx/enrollments_import.csv'),
                                                                         57483, batch_size=5000)
    
    # Final verification
    print("\n🔍 Final verification...")
    final_courses = verify_courses(namespace, cms_pod)
    final_users = verify_users(namespace, lms_pod)
    
    print(f"\n✅ Migration complete!")
    print(f"   Courses: {final_courses}")
    print(f"   Users: {final_users}")
    print(f"   Enrollments: {enrollments_imported}")


if __name__ == '__main__':
    main()

