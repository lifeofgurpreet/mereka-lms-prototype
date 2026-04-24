#!/usr/bin/env bash
# Patch the stock navbar-logo-header.html to guard enterprise_learner_portal call.
# Without this, the homepage returns 500 when 'request' is Undefined in the Mako context.
# The stock Open edX template assumes request is always available, but Mako includes
# from certain paths don't pass it.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

apply_enterprise_template_guard_patch() {
  local template_file="${TUTOR_ROOT}/env/build/openedx/edx-platform/lms/templates/header/navbar-logo-header.html"

  if [[ ! -f "$template_file" ]]; then
    echo "  SKIP: stock navbar-logo-header.html not found (expected at build time)"
    return 0
  fi

  if grep -q 'try:' "$template_file" && grep -q 'enterprise_learner_portal' "$template_file"; then
    echo "  SKIP: enterprise_learner_portal already guarded"
    return 0
  fi

  # Replace the unguarded call with a try/except
  python3 -c "
import pathlib
p = pathlib.Path('$template_file')
text = p.read_text()
old = 'enterprise_customer_link = get_enterprise_learner_portal(request)'
new = '''try:
    enterprise_customer_link = get_enterprise_learner_portal(request)
except (AttributeError, TypeError):
    enterprise_customer_link = None'''
if old in text:
    text = text.replace(old, new, 1)
    p.write_text(text)
    print('  APPLIED: enterprise_learner_portal guard')
else:
    print('  SKIP: pattern not found in stock template')
"
}
