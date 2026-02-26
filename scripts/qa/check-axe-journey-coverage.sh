#!/usr/bin/env bash
# Verify that verify-ui-accessibility.sh covers all 4 required user journeys.
set -euo pipefail

SCRIPT="scripts/qa/verify-ui-accessibility.sh"

grep -q '/authn/login' "$SCRIPT"
grep -q '/learner-dashboard/' "$SCRIPT"
grep -q '/learning/' "$SCRIPT"
grep -q '/discussions/' "$SCRIPT"
echo "All 4 required axe journeys present"
