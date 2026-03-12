#!/usr/bin/env python3
"""
Read-only validation tool for synthetic runtime proof fixture manifests.

Validates the manifest schema and consistency statically — no cluster access,
no Django dependency. Designed to run in CI and locally before any bootstrap step.

Exit codes:
    0  manifest is valid
    1  one or more validation errors found

Usage:
    python scripts/tenants/validate-runtime-proof-fixtures.py --env dev
    python scripts/tenants/validate-runtime-proof-fixtures.py --env dev --json
    python scripts/tenants/validate-runtime-proof-fixtures.py --env dev --live
      (--live is a placeholder; live cluster checks are not yet implemented)
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
MANIFEST_DIR = REPO_ROOT / "config" / "runtime-proof"

REQUIRED_FIXTURE_CLASSES = [
    "synthetic_identities",
    "lms_enterprise_data",
    "enterprise_catalog_service_data",
    "waffle_flags",
]

# ── Manifest loading ──────────────────────────────────────────────────────────


def find_manifest(env: str) -> Path:
    candidates = [
        MANIFEST_DIR / f"{env}.synthetic-proof-fixtures.yaml",
        Path(f"/openedx/config/runtime-proof/{env}.synthetic-proof-fixtures.yaml"),
    ]
    for path in candidates:
        if path.exists():
            return path
    tried = ", ".join(str(p) for p in candidates)
    raise FileNotFoundError(
        f"No synthetic proof fixture manifest for env={env!r}. Tried: {tried}"
    )


def load_manifest(env: str) -> tuple[dict[str, Any], str]:
    """Return (manifest dict, resolved path string)."""
    try:
        import yaml
    except ImportError as exc:
        print(
            "ERROR: PyYAML is required. Install with: pip install pyyaml",
            file=sys.stderr,
        )
        raise SystemExit(1) from exc

    path = find_manifest(env)
    manifest = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict):
        raise ValueError(f"Manifest at {path} did not parse as a dict.")
    return manifest, str(path)


# ── Validation checks ─────────────────────────────────────────────────────────


class CheckResult:
    def __init__(
        self, name: str, passed: bool, message: str, detail: str | None = None
    ) -> None:
        self.name = name
        self.passed = passed
        self.message = message
        self.detail = detail

    def to_dict(self) -> dict[str, Any]:
        d: dict[str, Any] = {"check": self.name, "passed": self.passed, "message": self.message}
        if self.detail:
            d["detail"] = self.detail
        return d


def check_safety_invariant(manifest: dict[str, Any]) -> CheckResult:
    flag = manifest.get("real_account_mutation_forbidden")
    if flag is True:
        return CheckResult(
            "safety_invariant",
            True,
            "real_account_mutation_forbidden is true",
        )
    return CheckResult(
        "safety_invariant",
        False,
        f"real_account_mutation_forbidden must be present and true, got: {flag!r}",
        detail="Without this flag the manifest cannot be used safely.",
    )


def check_required_top_level_fields(manifest: dict[str, Any]) -> list[CheckResult]:
    results = []
    for field in ("version", "environment", "contract_ref"):
        if field in manifest:
            results.append(
                CheckResult(
                    f"top_level_field:{field}",
                    True,
                    f"{field!r} present: {manifest[field]!r}",
                )
            )
        else:
            results.append(
                CheckResult(
                    f"top_level_field:{field}",
                    False,
                    f"Missing required top-level field: {field!r}",
                )
            )
    return results


def check_required_fixture_classes(manifest: dict[str, Any]) -> list[CheckResult]:
    results = []
    fixture_classes = manifest.get("fixture_classes", {})
    for cls in REQUIRED_FIXTURE_CLASSES:
        if cls in fixture_classes:
            results.append(
                CheckResult(
                    f"fixture_class:{cls}",
                    True,
                    f"Fixture class {cls!r} is present",
                )
            )
        else:
            results.append(
                CheckResult(
                    f"fixture_class:{cls}",
                    False,
                    f"Required fixture class {cls!r} is missing",
                    detail=(
                        "All four required fixture classes must be present: "
                        + ", ".join(REQUIRED_FIXTURE_CLASSES)
                    ),
                )
            )
    return results


def check_synthetic_user_emails(manifest: dict[str, Any]) -> list[CheckResult]:
    results = []
    si = manifest.get("fixture_classes", {}).get("synthetic_identities", {})
    users = si.get("users", [])
    if not users:
        results.append(
            CheckResult(
                "synthetic_identities:users_present",
                False,
                "synthetic_identities.users is empty or missing",
            )
        )
        return results

    results.append(
        CheckResult(
            "synthetic_identities:users_present",
            True,
            f"synthetic_identities.users has {len(users)} user(s)",
        )
    )

    for user in users:
        if not isinstance(user, dict):
            results.append(
                CheckResult(
                    "synthetic_identities:user_format",
                    False,
                    f"User entry is not a dict: {user!r}",
                )
            )
            continue

        email = user.get("email", "")
        username = user.get("username", "(unnamed)")
        if email.endswith("@synthetic.test"):
            results.append(
                CheckResult(
                    f"synthetic_identities:email:{username}",
                    True,
                    f"{username!r} email {email!r} uses @synthetic.test domain",
                )
            )
        else:
            results.append(
                CheckResult(
                    f"synthetic_identities:email:{username}",
                    False,
                    f"REAL ACCOUNT REJECTED: {username!r} has email {email!r} — "
                    "must use @synthetic.test domain",
                    detail=(
                        "Real-account fixture rejected. All synthetic user emails must "
                        "use the @synthetic.test domain (unroutable, cannot collide with "
                        "real operator accounts)."
                    ),
                )
            )

        for field in ("username", "email", "role"):
            if field not in user:
                results.append(
                    CheckResult(
                        f"synthetic_identities:fields:{username}",
                        False,
                        f"User {username!r} missing required field: {field!r}",
                    )
                )

    return results


def check_enterprise_customer_emails(manifest: dict[str, Any]) -> list[CheckResult]:
    results = []
    led = manifest.get("fixture_classes", {}).get("lms_enterprise_data", {})
    customers = led.get("enterprise_customers", [])
    if not customers:
        results.append(
            CheckResult(
                "lms_enterprise_data:customers_present",
                False,
                "lms_enterprise_data.enterprise_customers is empty or missing",
            )
        )
        return results

    results.append(
        CheckResult(
            "lms_enterprise_data:customers_present",
            True,
            f"lms_enterprise_data has {len(customers)} enterprise customer(s)",
        )
    )

    for ec in customers:
        slug = ec.get("slug", "(no slug)")
        email = ec.get("contact_email", "")
        if not email:
            # contact_email is optional but if provided must be synthetic.
            continue
        if email.endswith("@synthetic.test"):
            results.append(
                CheckResult(
                    f"lms_enterprise_data:contact_email:{slug}",
                    True,
                    f"Enterprise customer {slug!r} contact_email {email!r} is @synthetic.test",
                )
            )
        else:
            results.append(
                CheckResult(
                    f"lms_enterprise_data:contact_email:{slug}",
                    False,
                    f"REAL ACCOUNT REJECTED: enterprise customer {slug!r} contact_email "
                    f"{email!r} must be @synthetic.test",
                )
            )

    return results


def check_lms_enterprise_catalog_split(manifest: dict[str, Any]) -> CheckResult:
    """
    Both lms_enterprise_data (catalogs) and enterprise_catalog_service_data (catalogs)
    must be explicitly represented. An LMS-only catalog is documented as insufficient.
    """
    fixture_classes = manifest.get("fixture_classes", {})
    led = fixture_classes.get("lms_enterprise_data", {})
    ecsd = fixture_classes.get("enterprise_catalog_service_data", {})

    lms_catalogs = [
        cat
        for ec in led.get("enterprise_customers", [])
        for cat in ec.get("catalogs", [])
    ]
    catalog_service_catalogs = ecsd.get("catalogs", [])

    if lms_catalogs and catalog_service_catalogs:
        return CheckResult(
            "catalog_split:both_sides_present",
            True,
            f"Both catalog sides present: LMS has {len(lms_catalogs)}, "
            f"enterprise-catalog service has {len(catalog_service_catalogs)}",
        )
    if lms_catalogs and not catalog_service_catalogs:
        return CheckResult(
            "catalog_split:enterprise_catalog_missing",
            False,
            "LMS catalogs defined but enterprise_catalog_service_data.catalogs is missing "
            "or empty — LMS-only catalog is insufficient for learner portal proof",
            detail=(
                "The enterprise-catalog service maintains its own catalog records. "
                "Without them the learner portal shows zero courses. "
                "Add enterprise_catalog_service_data.catalogs entries to mirror the LMS catalogs."
            ),
        )
    if not lms_catalogs and catalog_service_catalogs:
        return CheckResult(
            "catalog_split:lms_catalog_missing",
            False,
            "enterprise_catalog_service_data.catalogs defined but LMS catalog entries missing — "
            "enterprise-catalog-only is also insufficient",
            detail=(
                "LMS EnterpriseCustomerCatalog records must also exist for the enterprise "
                "customer to appear in LMS admin and for enrollment to work correctly."
            ),
        )
    return CheckResult(
        "catalog_split:neither_side_present",
        False,
        "Neither LMS catalogs nor enterprise-catalog service catalogs are defined",
    )


def check_waffle_flags(manifest: dict[str, Any]) -> list[CheckResult]:
    results = []
    wf = manifest.get("fixture_classes", {}).get("waffle_flags", {})
    platform_flags = wf.get("platform_wide_flags", [])
    tenant_switches = wf.get("tenant_scoped_switches", [])

    if platform_flags:
        results.append(
            CheckResult(
                "waffle_flags:platform_wide_present",
                True,
                f"Platform-wide waffle flags present: {len(platform_flags)}",
            )
        )
    else:
        results.append(
            CheckResult(
                "waffle_flags:platform_wide_present",
                False,
                "No platform_wide_flags defined in waffle_flags",
                detail="enterprise.learner_bff_enabled must be set platform-wide.",
            )
        )

    if tenant_switches:
        results.append(
            CheckResult(
                "waffle_flags:tenant_scoped_present",
                True,
                f"Tenant-scoped waffle switches present: {len(tenant_switches)}",
            )
        )
    else:
        results.append(
            CheckResult(
                "waffle_flags:tenant_scoped_present",
                False,
                "No tenant_scoped_switches defined in waffle_flags",
            )
        )

    # Check for enterprise.learner_bff_enabled specifically.
    bff_flag = next(
        (f for f in platform_flags if f.get("name") == "enterprise.learner_bff_enabled"),
        None,
    )
    if bff_flag:
        active = bff_flag.get("active", False)
        results.append(
            CheckResult(
                "waffle_flags:learner_bff_enabled",
                active is True,
                f"enterprise.learner_bff_enabled active={active!r}",
                detail=None if active else "Must be true for learner portal API routing.",
            )
        )
    else:
        results.append(
            CheckResult(
                "waffle_flags:learner_bff_enabled",
                False,
                "enterprise.learner_bff_enabled not found in platform_wide_flags",
                detail=(
                    "This flag is required. Without it learner portal API calls return 404."
                ),
            )
        )

    return results


def run_all_checks(manifest: dict[str, Any]) -> list[CheckResult]:
    results: list[CheckResult] = []
    results.append(check_safety_invariant(manifest))
    results.extend(check_required_top_level_fields(manifest))
    results.extend(check_required_fixture_classes(manifest))
    results.extend(check_synthetic_user_emails(manifest))
    results.extend(check_enterprise_customer_emails(manifest))
    results.append(check_lms_enterprise_catalog_split(manifest))
    results.extend(check_waffle_flags(manifest))
    return results


# ── Output ────────────────────────────────────────────────────────────────────


def print_report_human(
    manifest: dict[str, Any],
    results: list[CheckResult],
    manifest_path: str,
    live: bool,
) -> None:
    env = manifest.get("environment", "?")
    passed = [r for r in results if r.passed]
    failed = [r for r in results if not r.passed]

    print()
    print("=" * 70)
    print("Synthetic Runtime Proof Fixture Validation")
    print(f"Environment : {env}")
    print(f"Manifest    : {manifest_path}")
    if live:
        print("Mode        : STATIC ONLY (--live placeholder, cluster checks not implemented)")
    else:
        print("Mode        : Static (no cluster access)")
    print(f"Checks      : {len(results)} total, {len(passed)} pass, {len(failed)} fail")
    print("=" * 70)

    if failed:
        print()
        print("FAILED CHECKS:")
        for r in failed:
            print(f"  [FAIL] {r.name}")
            print(f"         {r.message}")
            if r.detail:
                # Wrap detail at 68 chars.
                for line in r.detail.split(". "):
                    if line:
                        print(f"         Detail: {line.rstrip('.')}.")
        print()

    print("PASSED CHECKS:")
    for r in passed:
        print(f"  [PASS] {r.name}: {r.message}")

    print()
    print("=" * 70)
    if failed:
        print(f"VERDICT: INVALID — {len(failed)} check(s) failed")
    else:
        print("VERDICT: VALID — all checks passed")
    print("=" * 70)
    print()


def print_report_json(
    manifest: dict[str, Any],
    results: list[CheckResult],
    manifest_path: str,
) -> None:
    passed = [r for r in results if r.passed]
    failed = [r for r in results if not r.passed]
    output = {
        "environment": manifest.get("environment"),
        "manifest_path": manifest_path,
        "valid": len(failed) == 0,
        "total_checks": len(results),
        "passed": len(passed),
        "failed": len(failed),
        "checks": [r.to_dict() for r in results],
    }
    print(json.dumps(output, indent=2))


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Read-only validation tool for synthetic runtime proof fixture manifests. "
            "No Django dependency, no cluster access."
        )
    )
    parser.add_argument(
        "--env",
        required=True,
        help="Environment name (e.g. dev).",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        default=False,
        help="Output machine-readable JSON.",
    )
    parser.add_argument(
        "--live",
        action="store_true",
        default=False,
        help=(
            "Placeholder for future live-cluster validation. "
            "Currently falls back to static-only checks with a warning."
        ),
    )
    args = parser.parse_args()

    if args.live:
        print(
            "WARNING: --live is a placeholder. Live cluster checks are not yet implemented. "
            "Running static checks only.",
            file=sys.stderr,
        )

    try:
        manifest, manifest_path = load_manifest(args.env)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    results = run_all_checks(manifest)
    failed = [r for r in results if not r.passed]

    if args.json:
        print_report_json(manifest, results, manifest_path)
    else:
        print_report_human(manifest, results, manifest_path, live=args.live)

    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
