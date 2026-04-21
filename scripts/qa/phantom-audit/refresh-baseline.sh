#!/usr/bin/env bash
# Refresh the phantom-metric baseline snapshot from live Prometheus.
# Commit the updated baseline-metric-names.json when metrics change legitimately
# (e.g. new exporter deployed, new app instrumented).
#
# Usage:
#   scripts/qa/phantom-audit/refresh-baseline.sh [--context rke2-prod]
#
# Requires: kubectl, curl-image pull access to the cluster.
set -euo pipefail

CONTEXT="${1:-rke2-prod}"
if [ "${1:-}" = "--context" ]; then
  CONTEXT="${2:-rke2-prod}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$SCRIPT_DIR/baseline-metric-names.json"

echo "refreshing phantom-audit baseline from context=$CONTEXT"
PROBE="phantom-baseline-refresh-$$"
trap 'kubectl --context "$CONTEXT" delete pod "$PROBE" -n monitoring --ignore-not-found --force --grace-period=0 >/dev/null 2>&1 || true' EXIT

RAW=$(kubectl --context "$CONTEXT" run -n monitoring "$PROBE" \
  --rm -i --restart=Never --image=curlimages/curl:latest --quiet -- \
  sh -c 'curl -s "http://monitoring-kube-prometheus-prometheus:9090/api/v1/label/__name__/values"')

# Strip anything before the first `{` (kubectl run pod-terminated line etc.)
JSON="${RAW:$(python3 -c "import sys; s=sys.argv[1]; print(s.find('{'))" "$RAW")}"

python3 -c "
import json, sys, datetime
raw = json.loads(sys.argv[1])
out = {
    '_meta': {
        'source': 'context=$CONTEXT Prometheus /api/v1/label/__name__/values',
        'captured_at': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%MZ'),
        'refresh_note': 'Refresh quarterly, or when adding new metric families.',
        'metric_count': len(raw.get('data', [])),
        'origin': 'bead mereka-lms-33d8',
    },
    'status': raw.get('status', 'success'),
    'data': sorted(raw.get('data', [])),
}
json.dump(out, open('$OUT', 'w'), indent=2)
print(f'wrote $OUT with {len(out[\"data\"])} metrics')
" "$JSON"
