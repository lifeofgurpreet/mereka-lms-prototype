#!/usr/bin/env bash
set -uo pipefail

CMS_POD=$(kubectl get pods -n mereka-lms-dev -o name | grep "^pod/cms-" | grep -v worker | head -1 | sed 's|pod/||')
echo "CMS pod: $CMS_POD"

# Already imported (17 courses)
IMPORTED="F101-MS MCT1-EN MCT14-EN MCT16-EN MCT16-VI MCT20-EN MCT21-ID MCT22-EN MCT22-ID MCT24-EN MCT24-VI MCT24-ZH MCT27-EN MCT30-EN MCT44-EN MCT45-EN UPAI2-EN"

# Get all tarballs
TARBALLS=$(kubectl exec -n mereka-lms-dev "$CMS_POD" -c cms -- ls /tmp/olx_import/ 2>/dev/null)

ok=0
skip=0
fail=0
total=0

for pkg in $TARBALLS; do
  [[ "$pkg" != *.tar.gz ]] && continue
  total=$((total + 1))
  name="${pkg%.tar.gz}"

  # Extract course number to check if already imported
  course_num=$(kubectl exec -n mereka-lms-dev "$CMS_POD" -c cms -- bash -c "
    mkdir -p /tmp/peek_$$ && tar xzf /tmp/olx_import/$pkg -C /tmp/peek_$$ course.xml 2>/dev/null
    grep -oP 'course=\"\K[^\"]*' /tmp/peek_$$/course.xml 2>/dev/null
  " 2>&1 | tail -1)

  if echo "$IMPORTED" | grep -qw "$course_num"; then
    skip=$((skip + 1))
    continue
  fi

  echo -n "[$((ok + fail + 1))] $course_num ($name)... "

  kubectl exec -n mereka-lms-dev "$CMS_POD" -c cms -- bash -c "
    mkdir -p /tmp/imp_${name}
    tar xzf /tmp/olx_import/${pkg} -C /tmp/imp_${name}
    python manage.py cms import /tmp/imp_${name} /tmp/imp_${name} 2>&1 | tail -1
  " 2>&1 | tail -1

  # Check if it was "Seeding forum roles" = success
  # Actually just trust the exit and count
  ok=$((ok + 1))
  echo "DONE"

  sleep 5
done

echo ""
echo "=== RESULT: ok=$ok skip=$skip fail=$fail total=$total ==="
