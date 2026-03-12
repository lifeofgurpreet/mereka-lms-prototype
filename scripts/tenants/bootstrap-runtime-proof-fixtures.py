#!/usr/bin/env python3
"""
Bootstrap planner for synthetic runtime proof fixtures.

Reads config/runtime-proof/<env>.synthetic-proof-fixtures.yaml and prints a
structured plan of what would be created. Does NOT depend on Django — this is
a standalone planning/documentation tool.

Default: DRY RUN (print-only).
--apply: prints a warning and exits. Mutation is not yet wired in this version.

Usage:
    python scripts/tenants/bootstrap-runtime-proof-fixtures.py --env dev
    python scripts/tenants/bootstrap-runtime-proof-fixtures.py --env dev --json
    python scripts/tenants/bootstrap-runtime-proof-fixtures.py --env dev --apply
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any

# Repository root — two levels up from this script's directory.
REPO_ROOT = Path(__file__).resolve().parent.parent.parent

MANIFEST_DIR = REPO_ROOT / "config" / "runtime-proof"


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
        f"No synthetic proof fixture manifest found for env={env!r}. Tried: {tried}"
    )


def load_manifest(env: str) -> dict[str, Any]:
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
    return manifest


# ── Manifest validation ───────────────────────────────────────────────────────

REQUIRED_FIXTURE_CLASSES = [
    "synthetic_identities",
    "lms_enterprise_data",
    "enterprise_catalog_service_data",
    "waffle_flags",
]


def validate_manifest(manifest: dict[str, Any]) -> list[str]:
    """
    Validate manifest schema and safety invariants.

    Returns a list of error strings. Empty list means valid.
    """
    errors: list[str] = []

    # Safety invariant — must be present and true.
    if not manifest.get("real_account_mutation_forbidden"):
        errors.append(
            "SAFETY: real_account_mutation_forbidden must be present and true. "
            "This manifest cannot be used safely without this flag."
        )

    # Required top-level fields.
    for field in ("version", "environment", "contract_ref"):
        if field not in manifest:
            errors.append(f"SCHEMA: missing required top-level field: {field!r}")

    fixture_classes = manifest.get("fixture_classes", {})
    if not isinstance(fixture_classes, dict):
        errors.append("SCHEMA: fixture_classes must be a mapping")
        return errors

    # Required fixture classes.
    for cls in REQUIRED_FIXTURE_CLASSES:
        if cls not in fixture_classes:
            errors.append(f"SCHEMA: required fixture class missing: {cls!r}")

    # synthetic_identities checks.
    si = fixture_classes.get("synthetic_identities", {})
    users = si.get("users", [])
    if not isinstance(users, list) or len(users) == 0:
        errors.append("SCHEMA: synthetic_identities.users must be a non-empty list")
    else:
        for user in users:
            if not isinstance(user, dict):
                errors.append("SCHEMA: each user in synthetic_identities.users must be a dict")
                continue
            email = user.get("email", "")
            if not email.endswith("@synthetic.test"):
                errors.append(
                    f"REAL_ACCOUNT: user {user.get('username')!r} has email {email!r} "
                    "which is not @synthetic.test — real account fixture rejected"
                )
            for field in ("username", "email", "role"):
                if field not in user:
                    errors.append(
                        f"SCHEMA: user entry missing required field {field!r}: {user}"
                    )

    # lms_enterprise_data: must mention enterprise customers.
    led = fixture_classes.get("lms_enterprise_data", {})
    if not led.get("enterprise_customers"):
        errors.append(
            "SCHEMA: lms_enterprise_data.enterprise_customers must be present and non-empty"
        )
    else:
        for ec in led["enterprise_customers"]:
            ec_email = ec.get("contact_email", "")
            if ec_email and not ec_email.endswith("@synthetic.test"):
                errors.append(
                    f"REAL_ACCOUNT: enterprise customer {ec.get('slug')!r} has "
                    f"contact_email {ec_email!r} which is not @synthetic.test"
                )

    # enterprise_catalog_service_data: must be present and non-empty.
    ecsd = fixture_classes.get("enterprise_catalog_service_data", {})
    if not ecsd.get("catalogs"):
        errors.append(
            "SCHEMA: enterprise_catalog_service_data.catalogs must be present and non-empty. "
            "LMS-only catalog (without enterprise-catalog records) is insufficient for "
            "learner portal proof — this split must be explicitly represented."
        )

    # waffle_flags: must have at least platform_wide_flags or tenant_scoped_switches.
    wf = fixture_classes.get("waffle_flags", {})
    if not wf.get("platform_wide_flags") and not wf.get("tenant_scoped_switches"):
        errors.append(
            "SCHEMA: waffle_flags must have at least one of: "
            "platform_wide_flags, tenant_scoped_switches"
        )

    return errors


# ── Plan generation ───────────────────────────────────────────────────────────


class Action:
    """A single planned bootstrap action."""

    def __init__(
        self,
        category: str,
        kind: str,
        description: str,
        detail: dict[str, Any] | None = None,
    ) -> None:
        self.category = category
        self.kind = kind
        self.description = description
        self.detail = detail or {}

    def to_dict(self) -> dict[str, Any]:
        return {
            "category": self.category,
            "kind": self.kind,
            "description": self.description,
            "detail": self.detail,
        }


def plan_synthetic_identities(fixture_classes: dict[str, Any]) -> list[Action]:
    actions: list[Action] = []
    si = fixture_classes.get("synthetic_identities", {})
    for user in si.get("users", []):
        actions.append(
            Action(
                category="lms_user",
                kind="CREATE_OR_NOOP",
                description=(
                    f"Ensure LMS user exists: username={user['username']!r} "
                    f"email={user['email']!r} role={user['role']!r}"
                ),
                detail={
                    "username": user["username"],
                    "email": user["email"],
                    "role": user["role"],
                    "is_staff": user.get("is_staff", False),
                    "is_superuser": user.get("is_superuser", False),
                    "password_from": user.get("password_secret_path", "(not set)"),
                },
            )
        )
        link = user.get("enterprise_link")
        if link:
            actions.append(
                Action(
                    category="lms_enterprise_user_link",
                    kind="CREATE_OR_NOOP",
                    description=(
                        f"Link {user['username']!r} to enterprise customer "
                        f"{link['customer_slug']!r} as {link['enterprise_role']!r}"
                    ),
                    detail={
                        "username": user["username"],
                        "customer_slug": link["customer_slug"],
                        "enterprise_role": link["enterprise_role"],
                    },
                )
            )
        else:
            actions.append(
                Action(
                    category="lms_enterprise_user_link",
                    kind="ASSERT_ABSENT",
                    description=(
                        f"Assert {user['username']!r} is NOT linked to any enterprise customer "
                        "(negative case guard)"
                    ),
                    detail={"username": user["username"]},
                )
            )
    return actions


def plan_lms_enterprise_data(fixture_classes: dict[str, Any]) -> list[Action]:
    actions: list[Action] = []
    led = fixture_classes.get("lms_enterprise_data", {})
    for ec in led.get("enterprise_customers", []):
        # Real-account guard.
        actions.append(
            Action(
                category="lms_real_account_guard",
                kind="ASSERT_SAFE",
                description=(
                    f"Guard: ensure no real-account contact_email for slug={ec['slug']!r}. "
                    "If a live record exists with a non-@synthetic.test contact email, "
                    "bootstrap will abort."
                ),
                detail={"slug": ec["slug"], "expected_email_suffix": "@synthetic.test"},
            )
        )
        actions.append(
            Action(
                category="lms_enterprise_customer",
                kind="CREATE_OR_NOOP",
                description=(
                    f"Ensure EnterpriseCustomer: slug={ec['slug']!r} name={ec['name']!r}"
                ),
                detail={
                    "slug": ec["slug"],
                    "name": ec["name"],
                    "contact_email": ec.get("contact_email"),
                    "country": ec.get("country"),
                    "active": ec.get("active", True),
                    "site_domain": ec.get("site", {}).get("domain"),
                },
            )
        )
        for cat in ec.get("catalogs", []):
            actions.append(
                Action(
                    category="lms_enterprise_catalog",
                    kind="CREATE_OR_NOOP",
                    description=(
                        f"Ensure EnterpriseCustomerCatalog for {ec['slug']!r}: "
                        f"title={cat['title']!r}"
                    ),
                    detail={
                        "enterprise_slug": ec["slug"],
                        "title": cat["title"],
                        "org_filter": cat.get("catalog_query", {}).get("org_filter", []),
                        "content_filter": cat.get("catalog_query", {}).get("content_filter", {}),
                    },
                )
            )
    return actions


def plan_enterprise_catalog_data(fixture_classes: dict[str, Any]) -> list[Action]:
    actions: list[Action] = []
    ecsd = fixture_classes.get("enterprise_catalog_service_data", {})
    for cat in ecsd.get("catalogs", []):
        actions.append(
            Action(
                category="enterprise_catalog_service",
                kind="CREATE_OR_NOOP",
                description=(
                    f"Ensure EnterpriseCatalog in enterprise-catalog service: "
                    f"customer={cat['enterprise_customer_slug']!r} title={cat['title']!r}"
                ),
                detail={
                    "enterprise_customer_slug": cat["enterprise_customer_slug"],
                    "title": cat["title"],
                    "enterprise_catalog_uuid": cat.get("enterprise_catalog_uuid"),
                    "content_filter": cat.get("catalog_query", {}).get("content_filter", {}),
                    "note": (
                        "enterprise-catalog UUID is null until LMS-side bootstrap assigns one. "
                        "After LMS bootstrap, retrieve the UUID and update this manifest."
                    ),
                },
            )
        )
    # Verification is a top-level property of enterprise_catalog_service_data,
    # not per-catalog. Emit it once after all catalog actions.
    verification = ecsd.get("verification", {})
    if verification:
        actions.append(
            Action(
                category="enterprise_catalog_service",
                kind="VERIFY_POST_BOOTSTRAP",
                description=(
                    "After bootstrap: verify enterprise-catalog API returns at least "
                    f"{verification.get('expected_min_courses', 1)} course(s)"
                ),
                detail={
                    "api_path_template": verification.get("api_path_template"),
                    "expected_min_courses": verification.get("expected_min_courses", 1),
                },
            )
        )
    return actions


def plan_waffle_flags(fixture_classes: dict[str, Any]) -> list[Action]:
    actions: list[Action] = []
    wf = fixture_classes.get("waffle_flags", {})
    for flag in wf.get("platform_wide_flags", []):
        actions.append(
            Action(
                category="waffle_flag",
                kind="ENSURE_ACTIVE" if flag.get("active") else "ENSURE_INACTIVE",
                description=(
                    f"Ensure platform-wide WaffleFlag: {flag['name']!r} = "
                    f"{'on' if flag.get('active') else 'off'}"
                ),
                detail={"name": flag["name"], "active": flag.get("active", False)},
            )
        )
    for switch in wf.get("tenant_scoped_switches", []):
        switch_name = f"{switch['base']}.{switch['enterprise_slug']}"
        actions.append(
            Action(
                category="waffle_switch",
                kind="ENSURE_ACTIVE" if switch.get("active") else "ENSURE_INACTIVE",
                description=(
                    f"Ensure tenant-scoped WaffleSwitch: {switch_name!r} = "
                    f"{'on' if switch.get('active') else 'off'}"
                ),
                detail={
                    "name": switch_name,
                    "base": switch["base"],
                    "enterprise_slug": switch["enterprise_slug"],
                    "active": switch.get("active", False),
                },
            )
        )
    return actions


def build_plan(manifest: dict[str, Any]) -> list[Action]:
    fixture_classes = manifest.get("fixture_classes", {})
    actions: list[Action] = []
    actions.extend(plan_synthetic_identities(fixture_classes))
    actions.extend(plan_lms_enterprise_data(fixture_classes))
    actions.extend(plan_enterprise_catalog_data(fixture_classes))
    actions.extend(plan_waffle_flags(fixture_classes))
    return actions


# ── Output ────────────────────────────────────────────────────────────────────


def print_plan_human(manifest: dict[str, Any], actions: list[Action]) -> None:
    env = manifest.get("environment", "?")
    print()
    print("=" * 70)
    print("Synthetic Runtime Proof Fixture Bootstrap [DRY RUN]")
    print(f"Environment : {env}")
    print(f"Contract    : {manifest.get('contract_ref', '?')}")
    print(f"Actions     : {len(actions)}")
    print("=" * 70)
    print()

    categories: dict[str, list[Action]] = {}
    for action in actions:
        categories.setdefault(action.category, []).append(action)

    category_labels = {
        "lms_real_account_guard": "Real-Account Guards",
        "lms_user": "LMS User Accounts",
        "lms_enterprise_user_link": "LMS Enterprise User Links",
        "lms_enterprise_customer": "LMS Enterprise Customers",
        "lms_enterprise_catalog": "LMS Enterprise Catalogs",
        "enterprise_catalog_service": "Enterprise-Catalog Service Records",
        "waffle_flag": "Waffle Flags (platform-wide)",
        "waffle_switch": "Waffle Switches (tenant-scoped)",
    }

    for cat, cat_actions in categories.items():
        label = category_labels.get(cat, cat)
        print(f"--- {label} ({len(cat_actions)}) ---")
        for a in cat_actions:
            print(f"  [DRY] [{a.kind}] {a.description}")
        print()

    print("=" * 70)
    print("This was a DRY RUN. No changes were made.")
    print()
    print("To apply changes (future — mutation not yet wired):")
    print("  python scripts/tenants/bootstrap-runtime-proof-fixtures.py "
          f"--env {env} --apply")
    print()
    print("IMPORTANT: The enterprise-catalog service records (category:")
    print("  enterprise_catalog_service) require a separate step via the")
    print("  enterprise-catalog management command or API after LMS bootstrap")
    print("  assigns catalog UUIDs. See the execution packet for details.")
    print("=" * 70)
    print()


def print_plan_json(manifest: dict[str, Any], actions: list[Action]) -> None:
    output = {
        "mode": "dry_run",
        "environment": manifest.get("environment"),
        "contract_ref": manifest.get("contract_ref"),
        "real_account_mutation_forbidden": manifest.get("real_account_mutation_forbidden"),
        "action_count": len(actions),
        "actions": [a.to_dict() for a in actions],
    }
    print(json.dumps(output, indent=2))


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Dry-run capable bootstrap planner for synthetic runtime proof fixtures. "
            "Does NOT require Django or a live cluster."
        )
    )
    parser.add_argument(
        "--env",
        required=True,
        help="Environment name (e.g. dev). Loads config/runtime-proof/<env>.synthetic-proof-fixtures.yaml.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        default=False,
        help=(
            "Apply changes to the database. "
            "In this version: prints a warning and exits — mutation is not yet wired."
        ),
    )
    parser.add_argument(
        "--json",
        action="store_true",
        default=False,
        help="Output machine-readable JSON instead of human-readable plan.",
    )
    args = parser.parse_args()

    if args.apply:
        print("=" * 70, file=sys.stderr)
        print("WARNING: --apply was requested.", file=sys.stderr)
        print(file=sys.stderr)
        print(
            "Mutation is not yet wired in this version of bootstrap-runtime-proof-fixtures.py.",
            file=sys.stderr,
        )
        print(
            "This tool is currently a dry-run planning tool only.",
            file=sys.stderr,
        )
        print(file=sys.stderr)
        print(
            "To apply synthetic fixtures, run the bootstrap tool from inside an LMS pod:",
            file=sys.stderr,
        )
        print(
            "  kubectl exec -n mereka-lms-dev deploy/lms -- python "
            "/openedx/scripts/tenants/bootstrap-runtime-proof-fixtures.py "
            f"--env {args.env} --apply",
            file=sys.stderr,
        )
        print(
            "(When mutation is wired, the LMS pod version will have Django available.)",
            file=sys.stderr,
        )
        print("=" * 70, file=sys.stderr)
        return 1

    try:
        manifest = load_manifest(args.env)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    # Validate before planning.
    errors = validate_manifest(manifest)
    if errors:
        print("ERROR: Manifest validation failed:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    actions = build_plan(manifest)

    if args.json:
        print_plan_json(manifest, actions)
    else:
        print_plan_human(manifest, actions)

    return 0


if __name__ == "__main__":
    sys.exit(main())
