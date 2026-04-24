#!/usr/bin/env bash
set -uo pipefail

CMS_POD=$(kubectl get pods -n mereka-lms-dev -o name | grep "^pod/cms-" | grep -v worker | head -1 | sed 's|pod/||')
echo "CMS pod: $CMS_POD"

MISSING=(
  ai-fluency-en
  basic-microsoft-en
  soft-skills
  ai-fluency-zh
  become-an-entrepreneur
  careering-as-an-administrative-professional-en
  careering-as-an-administrative-professional-id
  content-creation
  developer
  digital-marketing-digital-marketing-strategies-for-your-busi
  digital-literacy
  employability-en
  employability-vi
  gaming-garage-with-hp
  personal-branding
  personal-well-being
  productivity-with-microsoft-365-bahasa-en
  productivity-with-microsoft-365-bahasa-id
  pursuing-a-career-in-project-management
  pursuing-a-career-in-the-field-of-data-analytics
  speak-with-impact
  your-future-in-green-jobs-en
)

ok=0
for name in "${MISSING[@]}"; do
  echo -n "[$((ok + 1))/${#MISSING[@]}] $name... "

  kubectl exec -n mereka-lms-dev "$CMS_POD" -c cms -- bash -c "
    mkdir -p /tmp/reimp_${name}
    tar xzf /tmp/olx_import/${name}.tar.gz -C /tmp/reimp_${name}
    python manage.py cms import /tmp/reimp_${name} /tmp/reimp_${name} 2>&1 | tail -1
  " 2>&1 | tail -1

  ok=$((ok + 1))
  echo "DONE"
  sleep 5
done

echo "=== REIMPORTED: $ok courses ==="
