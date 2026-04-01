#!/usr/bin/env bash
set -euo pipefail

CMS_POD=$(kubectl get pods -n mereka-lms-dev -o name | grep "^pod/cms-" | grep -v worker | head -1 | sed 's|pod/||')
echo "CMS pod: $CMS_POD"

PACKAGES=(
  basic-microsoft-vi
  become-an-entrepreneur
  boosting-sales-and-productivity-with-chatgpt
  content-creation
  employability-en
  employability-vi
  gaming-garage-with-hp
  managing-your-first-client
  mastering-digital-tools-thu-h-p-kho-ng-c-ch-s
  mobile-literacy
  personal-branding
  personal-finance
  personal-well-being
  productivity-with-microsoft-365-bahasa-en
  productivity-with-microsoft-365-bahasa-id
  professional-writing
  pursuing-a-career-in-project-management
  pursuing-a-career-in-the-field-of-data-analytics
  securing-your-first-client
  securing-your-first-job
  skills-profiling
  speak-with-impact
  thriving-in-your-job
  your-future-in-green-jobs-en
)

ok=0
fail=0

for name in "${PACKAGES[@]}"; do
  echo -n "[$((ok + fail + 1))/${#PACKAGES[@]}] $name... "

  result=$(kubectl exec -n mereka-lms-dev "$CMS_POD" -c cms -- bash -c "
    mkdir -p /tmp/fin_${name}
    tar xzf /tmp/olx_import/${name}.tar.gz -C /tmp/fin_${name}
    python manage.py cms import /tmp/fin_${name} /tmp/fin_${name} 2>&1 | grep -c 'Seeding forum'
  " 2>&1 | tail -1)

  if [ "$result" = "1" ]; then
    echo "OK"
    ok=$((ok + 1))
  else
    echo "FAIL"
    fail=$((fail + 1))
  fi

  sleep 10
done

echo ""
echo "=== DONE: ok=$ok fail=$fail ==="
