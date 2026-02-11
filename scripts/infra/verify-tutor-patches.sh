#!/usr/bin/env bash
# @covers AC-001
# @spec: tutor-configuration_spec.md
# Manifest-driven verification tool for Tutor patches
# Reads patch-manifest.yml and verifies each patch is present
#
# Usage:
#   ./scripts/infra/verify-tutor-patches.sh          # Normal output
#   ./scripts/infra/verify-tutor-patches.sh --json   # JSON output
#   ./scripts/infra/verify-tutor-patches.sh --fix    # Run apply-patches.sh on failure

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TUTOR_ENV="${TUTOR_ROOT:-${REPO_ROOT}/tutor_env}"
MANIFEST_FILE="$REPO_ROOT/infrastructure/tutor/patch-manifest.yml"

# Parse command line arguments
OUTPUT_MODE="human"
AUTO_FIX=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      OUTPUT_MODE="json"
      shift
      ;;
    --fix)
      AUTO_FIX=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--json] [--fix]"
      exit 1
      ;;
  esac
done

# Check if manifest exists
if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo "ERROR: Patch manifest not found: $MANIFEST_FILE"
  exit 1
fi

# Check if tutor_env exists
if [[ ! -d "$TUTOR_ENV" ]]; then
  echo "ERROR: Tutor environment not found at $TUTOR_ENV"
  echo "Run 'tutor config save' first to initialize the environment."
  exit 1
fi

# Use Python to parse YAML and run verification
python3 - "$MANIFEST_FILE" "$TUTOR_ENV" "$OUTPUT_MODE" <<'PYTHON'
import sys
import os
import re
import subprocess
import json
from datetime import datetime
from pathlib import Path

try:
    import yaml
except ImportError:
    # Fallback if PyYAML not available - basic YAML parser
    class FallbackYAML:
        @staticmethod
        def safe_load(stream):
            # Very basic YAML parser for our specific structure
            data = {"patches": []}
            current_patch = None

            for line in stream.split('\n'):
                line = line.rstrip()
                if not line or line.strip().startswith('#'):
                    continue

                if line.strip().startswith('- id:'):
                    if current_patch:
                        data["patches"].append(current_patch)
                    current_patch = {}
                    current_patch["id"] = line.split(':', 1)[1].strip().strip('"')
                elif current_patch is not None:
                    if ':' in line:
                        key, value = line.split(':', 1)
                        key = key.strip()
                        value = value.strip().strip('"')
                        current_patch[key] = value

            if current_patch:
                data["patches"].append(current_patch)

            return data

    yaml = FallbackYAML()

manifest_file = sys.argv[1]
tutor_env = sys.argv[2]
output_mode = sys.argv[3]

# Parse manifest
with open(manifest_file, 'r') as f:
    manifest_content = f.read()
    manifest = yaml.safe_load(manifest_content)

patches = manifest.get("patches", [])

# Track results
total_checks = 0
passed_checks = 0
failed_checks = 0
skipped_checks = 0
results = []

# Verify each patch
for patch in patches:
    total_checks += 1

    patch_id = patch.get("id", "unknown")
    name = patch.get("name", "Unknown")
    category = patch.get("category", "unknown")
    description = patch.get("description", "No description")
    target_file = patch.get("target_file", "")
    verify_command = patch.get("verify_command", "")
    verify_pattern = patch.get("verify_pattern", "")
    severity = patch.get("severity", "medium")
    required = patch.get("required", True)

    # Convert string "false" to boolean
    if isinstance(required, str):
        required = required.lower() != "false"

    # Replace tutor_env placeholder with actual path
    target_file_abs = target_file.replace("tutor_env", tutor_env)
    verify_command_abs = verify_command.replace("tutor_env", tutor_env)

    status = "UNKNOWN"
    message = ""

    # Check if file exists
    if not os.path.isfile(target_file_abs):
        if not required:
            status = "SKIP"
            message = "Target file not found (optional patch)"
            skipped_checks += 1
        else:
            status = "FAIL"
            message = f"Target file not found: {target_file_abs}"
            failed_checks += 1
    else:
        # Run verification command
        try:
            result = subprocess.run(
                verify_command_abs,
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5
            )
            if result.returncode == 0:
                status = "PASS"
                message = "Patch verified"
                passed_checks += 1
            else:
                if not required:
                    status = "SKIP"
                    message = f"Pattern not found (optional patch)"
                    skipped_checks += 1
                else:
                    status = "FAIL"
                    message = f"Pattern not found: {verify_pattern}"
                    failed_checks += 1
        except subprocess.TimeoutExpired:
            status = "FAIL"
            message = "Verification command timed out"
            failed_checks += 1
        except Exception as e:
            status = "FAIL"
            message = f"Verification error: {str(e)}"
            failed_checks += 1

    results.append({
        "id": patch_id,
        "name": name,
        "category": category,
        "description": description,
        "target_file": target_file_abs,
        "severity": severity,
        "status": status,
        "message": message
    })

# Output results
if output_mode == "json":
    output = {
        "manifest": manifest_file,
        "tutor_env": tutor_env,
        "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "summary": {
            "total": total_checks,
            "passed": passed_checks,
            "failed": failed_checks,
            "skipped": skipped_checks
        },
        "patches": results
    }
    print(json.dumps(output, indent=2))
else:
    # Human-readable output
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    BOLD = '\033[1m'
    NC = '\033[0m'

    print(f"{BLUE}{BOLD}=== Tutor Patch Verification ==={NC}\n")
    print(f"Manifest: {manifest_file}")
    print(f"Tutor Environment: {tutor_env}\n")

    # Group by category
    by_category = {}
    for result in results:
        cat = result["category"]
        if cat not in by_category:
            by_category[cat] = []
        by_category[cat].append(result)

    # Print results by category
    for category, patches in sorted(by_category.items()):
        print(f"{BLUE}=== {category} ==={NC}")
        for patch in patches:
            if patch["status"] == "PASS":
                print(f"{GREEN}✓{NC} {patch['name']}")
            elif patch["status"] == "FAIL":
                if patch["severity"] == "critical":
                    print(f"{RED}{BOLD}✗{NC} {BOLD}{patch['name']}{NC} (CRITICAL)")
                else:
                    print(f"{RED}✗{NC} {patch['name']}")
                print(f"  {YELLOW}→{NC} {patch['message']}")
            elif patch["status"] == "SKIP":
                print(f"{YELLOW}⊘{NC} {patch['name']} (skipped)")
        print()

    # Summary
    print(f"{BLUE}=== Summary ==={NC}")
    print(f"Total checks: {total_checks}")
    print(f"{GREEN}Passed: {passed_checks}{NC}")
    print(f"{RED}Failed: {failed_checks}{NC}")
    print(f"{YELLOW}Skipped: {skipped_checks}{NC}\n")

    # Critical failures
    critical_failures = sum(1 for r in results if r["status"] == "FAIL" and r["severity"] == "critical")
    if critical_failures > 0:
        print(f"{RED}{BOLD}⚠ CRITICAL: {critical_failures} critical patch(es) missing!{NC}\n")

    # Remediation
    if failed_checks > 0:
        print(f"{YELLOW}Remediation:{NC}")
        print("  1. Run: ./infrastructure/tutor/apply-patches.sh")
        print("  2. Re-run this verification script\n")
        print("Or use --fix flag to auto-apply patches:")
        print("  scripts/infra/verify-tutor-patches.sh --fix\n")

# Exit with appropriate code
exit_code = 1 if failed_checks > 0 else 0
sys.exit(exit_code)
PYTHON

VERIFICATION_EXIT_CODE=$?

# Auto-fix if requested and there are failures
if [[ "$AUTO_FIX" == "true" && $VERIFICATION_EXIT_CODE -ne 0 ]]; then
  echo -e "${YELLOW}Auto-fix requested. Running apply-patches.sh...${NC}"
  "$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
  echo ""
  echo -e "${GREEN}Patches applied. Re-running verification...${NC}"
  echo ""
  exec "$0"  # Re-run without --fix to show final results
fi

exit $VERIFICATION_EXIT_CODE
