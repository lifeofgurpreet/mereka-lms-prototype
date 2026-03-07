#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

docs/qa/verify-docs-policy.sh --help >/tmp/verify_docs_policy_help.out 2>&1
grep -q "Usage: verify-docs-policy.sh" /tmp/verify_docs_policy_help.out
grep -q -- "--range <git-diff-range>" /tmp/verify_docs_policy_help.out

if docs/qa/verify-docs-policy.sh --unknown >/tmp/verify_docs_policy_unknown.out 2>&1; then
  echo "expected unknown option failure"
  exit 1
fi
grep -q "Unknown option: --unknown" /tmp/verify_docs_policy_unknown.out

DOCS_POLICY_RANGE="HEAD~1...HEAD" \
  docs/qa/verify-docs-policy.sh --range "HEAD...HEAD" >/tmp/verify_docs_policy_range.out 2>&1
grep -q "Docs policy range: HEAD...HEAD" /tmp/verify_docs_policy_range.out

echo "verify-docs-policy self-test: OK"
