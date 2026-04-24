#!/usr/bin/env python3
"""
Bootstrap planner and applier for synthetic runtime proof fixtures.

Reads config/runtime-proof/<env>.synthetic-proof-fixtures.yaml and either prints a
structured plan of what would be created (dry-run, default) or applies the changes
via Django ORM (--apply, requires Django context).

Default: DRY RUN (print-only, no Django required).
--apply: runs Django ORM mutations if Django is available; prints an error and exits
         if Django is not available (must be run from inside an LMS pod).

Usage:
    python scripts/tenants/bootstrap-runtime-proof-fixtures.py --env dev
    python scripts/tenants/bootstrap-runtime-proof-fixtures.py --env dev --json
    python scripts/tenants/bootstrap-runtime-proof-fixtures.py --env dev --apply
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

# Repository root — two levels up from this script's directory.
REPO_ROOT = Path(__file__).resolve().parent.parent.parent

MANIFEST_DIR = REPO_ROOT / "config" / "runtime-proof"


def _manifest_name_candidates(env: str) -> list[str]:
    normalized = env.strip().lower()
    aliases = {
        "prod": ["prod", "production"],
        "production": ["production", "prod"],
    }
    return aliases.get(normalized, [normalized])

# ── Shared library import ─────────────────────────────────────────────────────

sys.path.insert(0, str(REPO_ROOT / "scripts" / "tenants"))

from lib.proof_fixtures import (  # noqa: E402, I001
    SYNTHETIC_EMAIL_DOMAIN,
    ApplySummary,
    RealAccountCollisionError,
    SyntheticSafetyViolation,
    make_action,
    run_all_guards,
)


# ── Manifest loading ───────────────────────────────────────────────────────────


def find_manifest(env: str) -> Path:
    candidates = []
    manifest_dir_override = os.environ.get("RUNTIME_PROOF_MANIFEST_DIR")
    for env_name in _manifest_name_candidates(env):
        if manifest_dir_override:
            candidates.append(Path(manifest_dir_override) / f"{env_name}.synthetic-proof-fixtures.yaml")
        candidates.extend(
            [
                MANIFEST_DIR / f"{env_name}.synthetic-proof-fixtures.yaml",
                Path(f"/openedx/config/runtime-proof/{env_name}.synthetic-proof-fixtures.yaml"),
            ]
        )
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


# ── Manifest validation ────────────────────────────────────────────────────────

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


# ── Plan generation ────────────────────────────────────────────────────────────


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
                    "ensure_user_profile": True,
                    "password_from": user.get("password_secret_path", "(not set)"),
                },
            )
        )
        actions.append(
            Action(
                category="lms_user_profile",
                kind="CREATE_OR_NOOP",
                description=(
                    f"Ensure UserProfile exists for LMS user {user['username']!r}"
                ),
                detail={"username": user["username"]},
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
    print("To apply changes (run from inside an LMS pod with Django available):")
    print("  python scripts/tenants/bootstrap-runtime-proof-fixtures.py "
          f"--env {env} --apply")
    print()
    print("IMPORTANT: The enterprise-catalog service records (category:")
    print("  enterprise_catalog_service) require a separate step via the")
    print("  enterprise-catalog management command or API after LMS bootstrap")
    print("  assigns catalog UUIDs. See the execution packet for details.")
    print("  Use bootstrap-runtime-proof-fixtures-catalog.py for that step.")
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


# ── Apply path (Django ORM) ───────────────────────────────────────────────────


def apply_synthetic_identities(
    fixture_classes: dict[str, Any],
    summary: ApplySummary,
    dry_run: bool,
) -> None:
    """Apply synthetic identity users and enterprise user links via Django ORM."""
    # Deferred Django imports — only available inside LMS pod.
    try:
        from common.djangoapps.student.models import UserProfile  # noqa: PLC0415
        from django.contrib.auth import get_user_model  # noqa: PLC0415
        from enterprise.models import EnterpriseCustomer, EnterpriseCustomerUser  # noqa: PLC0415
    except ImportError as exc:
        raise RuntimeError(
            "Django ORM not available. Run --apply from inside an LMS pod: "
            "kubectl exec -n mereka-lms-dev deploy/lms -- python "
            "/openedx/scripts/tenants/bootstrap-runtime-proof-fixtures.py "
            "--env dev --apply"
        ) from exc

    User = get_user_model()
    ecu_user_field = "user_fk" if hasattr(EnterpriseCustomerUser, "user_fk_id") else "user"
    si = fixture_classes.get("synthetic_identities", {})

    for user_spec in si.get("users", []):
        email = user_spec["email"]
        username = user_spec["username"]

        # Real-account collision guard: if a user exists with this username
        # or email but a non-synthetic email, refuse.
        existing_by_username = User.objects.filter(username=username).first()
        if existing_by_username and not existing_by_username.email.endswith(SYNTHETIC_EMAIL_DOMAIN):
            rec = make_action(
                "REFUSE",
                "User",
                username,
                f"Real account collision: existing user {username!r} has non-synthetic email "
                f"{existing_by_username.email!r}. Refusing to overwrite.",
                dry_run,
            )
            summary.actions.append(rec)
            summary.refused += 1
            print(f"  [REFUSE] {rec.detail}", file=sys.stderr)
            raise RealAccountCollisionError(rec.detail)

        user, created = User.objects.get_or_create(
            username=username,
            defaults={
                "email": email,
                "is_staff": user_spec.get("is_staff", False),
                "is_superuser": user_spec.get("is_superuser", False),
            },
        )
        action_label = "CREATE" if created else "NOOP"
        rec = make_action(
            action_label,
            "User",
            username,
            f"{'Created' if created else 'Already exists'}: {username!r} ({email})",
            dry_run,
        )
        summary.actions.append(rec)
        if created:
            summary.created += 1
            # Note: password setting is deferred to runtime lane.
            # The password_secret_path in the manifest documents where to find it.
            print(
                f"  [CREATE] User {username!r} — password must be set separately "
                f"from Infisical path: {user_spec.get('password_secret_path', '(not set)')}"
            )
        else:
            summary.reused += 1
            print(f"  [NOOP] User {username!r} already exists")

        profile, profile_created = UserProfile.objects.get_or_create(
            user=user,
            defaults={"name": user.username or user.email},
        )
        profile_action = "CREATE" if profile_created else "NOOP"
        rec = make_action(
            profile_action,
            "UserProfile",
            username,
            f"{'Created' if profile_created else 'Already exists'}: UserProfile for {username!r}",
            dry_run,
        )
        summary.actions.append(rec)
        if profile_created:
            summary.created += 1
            print(f"  [CREATE] UserProfile for {username!r}")
        else:
            summary.reused += 1
            print(f"  [NOOP] UserProfile for {username!r} already exists")

        # Enterprise user link.
        link = user_spec.get("enterprise_link")
        if link:
            customer_slug = link["customer_slug"]
            try:
                ec = EnterpriseCustomer.objects.get(slug=customer_slug)
            except EnterpriseCustomer.DoesNotExist:
                rec = make_action(
                    "SKIP",
                    "EnterpriseCustomerUser",
                    f"{username}@{customer_slug}",
                    f"EnterpriseCustomer {customer_slug!r} does not exist yet — "
                    "link skipped. Run LMS enterprise data apply first.",
                    dry_run,
                )
                summary.actions.append(rec)
                summary.skipped += 1
                print(f"  [SKIP] EnterpriseCustomerUser link for {username!r}: "
                      f"customer {customer_slug!r} not found")
                continue

            ecu, ecu_created = EnterpriseCustomerUser.objects.get_or_create(
                enterprise_customer=ec,
                **{ecu_user_field: user},
            )
            ecu_action = "CREATE" if ecu_created else "NOOP"
            ecu_rec = make_action(
                ecu_action,
                "EnterpriseCustomerUser",
                f"{username}@{customer_slug}",
                f"{'Created' if ecu_created else 'Already exists'}: "
                f"{username!r} linked to {customer_slug!r}",
                dry_run,
            )
            summary.actions.append(ecu_rec)
            if ecu_created:
                summary.created += 1
                print(f"  [CREATE] EnterpriseCustomerUser: {username!r} -> {customer_slug!r}")
            else:
                summary.reused += 1
                print(f"  [NOOP] EnterpriseCustomerUser: {username!r} -> {customer_slug!r} already linked")
        else:
            # Negative case: assert no enterprise link exists.
            ecu_count = EnterpriseCustomerUser.objects.filter(
                **{ecu_user_field: user}
            ).count()
            if ecu_count > 0:
                rec = make_action(
                    "ERROR",
                    "EnterpriseCustomerUser",
                    username,
                    f"Negative case violated: {username!r} is linked to "
                    f"{ecu_count} enterprise customer(s) but enterprise_link is null in manifest.",
                    dry_run,
                )
                summary.actions.append(rec)
                summary.errors += 1
                print(f"  [ERROR] {rec.detail}", file=sys.stderr)
            else:
                rec = make_action(
                    "NOOP",
                    "EnterpriseCustomerUser",
                    username,
                    f"Negative case confirmed: {username!r} has no enterprise links",
                    dry_run,
                )
                summary.actions.append(rec)
                summary.reused += 1
                print(f"  [NOOP] Negative case OK: {username!r} has no enterprise links")


def apply_lms_enterprise_data(
    fixture_classes: dict[str, Any],
    summary: ApplySummary,
    dry_run: bool,
) -> None:
    """Apply LMS enterprise customer and catalog records via Django ORM."""
    try:
        from django.contrib.sites.models import Site  # noqa: PLC0415
        from enterprise.models import (  # noqa: PLC0415
            EnterpriseCustomer,
            EnterpriseCustomerCatalog,
        )
    except ImportError as exc:
        raise RuntimeError(
            "Django ORM not available. Run --apply from inside an LMS pod."
        ) from exc

    led = fixture_classes.get("lms_enterprise_data", {})

    for ec_spec in led.get("enterprise_customers", []):
        slug = ec_spec["slug"]
        contact_email = ec_spec.get("contact_email", "")

        # Real-account guard: if an EnterpriseCustomer exists with this slug
        # but a non-synthetic contact_email, refuse.
        existing_ec = EnterpriseCustomer.objects.filter(slug=slug).first()
        if existing_ec and existing_ec.contact_email and not existing_ec.contact_email.endswith(SYNTHETIC_EMAIL_DOMAIN):
            rec = make_action(
                "REFUSE",
                "EnterpriseCustomer",
                slug,
                f"Real account collision: EnterpriseCustomer {slug!r} has "
                f"non-synthetic contact_email {existing_ec.contact_email!r}. "
                "Refusing to overwrite real tenant record.",
                dry_run,
            )
            summary.actions.append(rec)
            summary.refused += 1
            print(f"  [REFUSE] {rec.detail}", file=sys.stderr)
            raise RealAccountCollisionError(rec.detail)

        # Resolve site for the enterprise customer.
        site_domain = ec_spec.get("site", {}).get("domain")
        site = None
        if site_domain:
            site = Site.objects.filter(domain=site_domain).first()
            if not site:
                site = Site.objects.first()  # fallback to default site

        ec, ec_created = EnterpriseCustomer.objects.get_or_create(
            slug=slug,
            defaults={
                "name": ec_spec["name"],
                "contact_email": contact_email,
                "country": ec_spec.get("country", ""),
                "active": ec_spec.get("active", True),
                **({"site": site} if site else {}),
            },
        )
        ec_action = "CREATE" if ec_created else "NOOP"
        ec_rec = make_action(
            ec_action,
            "EnterpriseCustomer",
            slug,
            f"{'Created' if ec_created else 'Already exists'}: {slug!r} ({ec_spec['name']})",
            dry_run,
        )
        summary.actions.append(ec_rec)
        if ec_created:
            summary.created += 1
            print(f"  [CREATE] EnterpriseCustomer: {slug!r}")
        else:
            summary.reused += 1
            print(f"  [NOOP] EnterpriseCustomer: {slug!r} already exists")

        # Create catalogs.
        for cat_spec in ec_spec.get("catalogs", []):
            title = cat_spec["title"]
            cat, cat_created = EnterpriseCustomerCatalog.objects.get_or_create(
                enterprise_customer=ec,
                title=title,
            )
            cat_action = "CREATE" if cat_created else "NOOP"
            cat_rec = make_action(
                cat_action,
                "EnterpriseCustomerCatalog",
                f"{slug}/{title}",
                f"{'Created' if cat_created else 'Already exists'}: catalog {title!r} "
                f"for {slug!r}",
                dry_run,
            )
            summary.actions.append(cat_rec)
            if cat_created:
                summary.created += 1
                print(f"  [CREATE] EnterpriseCustomerCatalog: {title!r} for {slug!r}")
            else:
                summary.reused += 1
                print(f"  [NOOP] EnterpriseCustomerCatalog: {title!r} for {slug!r} already exists")


def apply_waffle_flags(
    fixture_classes: dict[str, Any],
    summary: ApplySummary,
    dry_run: bool,
) -> None:
    """Apply waffle flags and switches via Django ORM."""
    try:
        from waffle.models import Flag, Switch  # noqa: PLC0415
    except ImportError as exc:
        raise RuntimeError(
            "Django ORM (waffle) not available. Run --apply from inside an LMS pod."
        ) from exc

    wf = fixture_classes.get("waffle_flags", {})

    for flag_spec in wf.get("platform_wide_flags", []):
        name = flag_spec["name"]
        active = flag_spec.get("active", False)
        flag, flag_created = Flag.objects.get_or_create(
            name=name,
            defaults={"everyone": active},
        )
        flag_action = "CREATE" if flag_created else "NOOP"
        flag_rec = make_action(
            flag_action,
            "WaffleFlag",
            name,
            f"{'Created' if flag_created else 'Already exists'}: WaffleFlag {name!r} "
            f"active={active}",
            dry_run,
        )
        summary.actions.append(flag_rec)
        if flag_created:
            summary.created += 1
            print(f"  [CREATE] WaffleFlag: {name!r} active={active}")
        else:
            summary.reused += 1
            print(f"  [NOOP] WaffleFlag: {name!r} already exists")

    for switch_spec in wf.get("tenant_scoped_switches", []):
        switch_name = f"{switch_spec['base']}.{switch_spec['enterprise_slug']}"
        active = switch_spec.get("active", False)
        switch, switch_created = Switch.objects.get_or_create(
            name=switch_name,
            defaults={"active": active},
        )
        switch_action = "CREATE" if switch_created else "NOOP"
        switch_rec = make_action(
            switch_action,
            "WaffleSwitch",
            switch_name,
            f"{'Created' if switch_created else 'Already exists'}: WaffleSwitch "
            f"{switch_name!r} active={active}",
            dry_run,
        )
        summary.actions.append(switch_rec)
        if switch_created:
            summary.created += 1
            print(f"  [CREATE] WaffleSwitch: {switch_name!r} active={active}")
        else:
            summary.reused += 1
            print(f"  [NOOP] WaffleSwitch: {switch_name!r} already exists")


def apply_passwords(
    fixture_classes: dict[str, Any],
    summary: ApplySummary,
) -> None:
    """Set passwords for synthetic users from environment variables.

    For each user in synthetic_identities, reads the password from an env var
    named after the password_secret_path basename (e.g. LANEA_PLATFORM_ADMIN_PASSWORD).
    If the env var is not set, the user is skipped with a warning.
    """
    try:
        from django.contrib.auth import get_user_model  # noqa: PLC0415
    except ImportError as exc:
        raise RuntimeError(
            "Django not available — password setting requires LMS Django context"
        ) from exc

    User = get_user_model()
    si = fixture_classes.get("synthetic_identities", {})

    for user_spec in si.get("users", []):
        username = user_spec["username"]
        secret_path = user_spec.get("password_secret_path", "")
        # Derive env var name from secret path: /runtime-proof/LANEA_X → LANEA_X
        env_var = secret_path.rsplit("/", 1)[-1] if secret_path else ""

        if not env_var:
            print(f"  [SKIP] {username!r}: no password_secret_path in manifest")
            summary.skipped += 1
            continue

        password = os.environ.get(env_var)
        if not password:
            print(
                f"  [SKIP] {username!r}: env var {env_var!r} not set "
                f"(source: {secret_path})"
            )
            summary.skipped += 1
            continue

        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            print(
                f"  [SKIP] {username!r}: user does not exist in DB — "
                "run bootstrap --apply first"
            )
            summary.skipped += 1
            continue

        user.set_password(password)
        user.save(update_fields=["password"])
        rec = make_action(
            "UPDATE",
            "User.password",
            username,
            f"Password set for {username!r} from env var {env_var!r}",
            False,
        )
        summary.actions.append(rec)
        summary.created += 1  # counts as a mutation
        print(f"  [SET] Password for {username!r} from {env_var}")


def run_apply(
    manifest: dict[str, Any],
    env: str,
    as_json: bool,
    set_passwords: bool = False,
) -> int:
    """
    Execute the apply path. Guard chain runs first; all guards must pass before
    any ORM write. Requires Django context (LMS pod).

    Returns exit code (0 = success, 1 = failure).
    """
    # Guard chain — all-or-nothing.
    try:
        run_all_guards(manifest, env)
    except SyntheticSafetyViolation as exc:
        print(f"ERROR: Guard chain failed — {exc}", file=sys.stderr)
        print("No changes were made.", file=sys.stderr)
        return 1

    summary = ApplySummary(
        environment=env,
        mode="apply",
        real_account_mutation_forbidden=manifest.get("real_account_mutation_forbidden", False),
    )

    fixture_classes = manifest.get("fixture_classes", {})

    print()
    print("=" * 70)
    print("Synthetic Runtime Proof Fixture Bootstrap [APPLY]")
    print(f"Environment : {env}")
    print(f"Contract    : {manifest.get('contract_ref', '?')}")
    print("=" * 70)
    print()

    # Apply in dependency order: enterprise data first, then users (which link to enterprise
    # customers), then waffle flags.
    try:
        print("--- LMS Enterprise Data ---")
        apply_lms_enterprise_data(fixture_classes, summary, dry_run=False)
        print()

        print("--- Synthetic Identities ---")
        apply_synthetic_identities(fixture_classes, summary, dry_run=False)
        print()

        print("--- Waffle Flags ---")
        apply_waffle_flags(fixture_classes, summary, dry_run=False)
        print()

        if set_passwords:
            print("--- Synthetic User Passwords ---")
            apply_passwords(fixture_classes, summary)
            print()

    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except RealAccountCollisionError as exc:
        print(f"ERROR: Real account collision detected — {exc}", file=sys.stderr)
        print("Bootstrap aborted. No further changes were made.", file=sys.stderr)
        return 1
    except Exception as exc:
        if exc.__class__.__module__.startswith("django") or "settings are not configured" in str(exc).lower():
            print("ERROR: Django ORM is not configured for --apply.", file=sys.stderr)
            print(
                "Run this command from inside an LMS pod with DJANGO_SETTINGS_MODULE set.",
                file=sys.stderr,
            )
            return 1
        raise

    print("=" * 70)
    print(
        f"Apply complete: created={summary.created} reused={summary.reused} "
        f"skipped={summary.skipped} refused={summary.refused} errors={summary.errors}"
    )
    print("=" * 70)
    print()
    print("NOTE: Enterprise-catalog service records are NOT handled by this tool.")
    print("      Run bootstrap-runtime-proof-fixtures-catalog.py for the catalog service step.")
    if not set_passwords:
        print("NOTE: Synthetic user passwords were NOT set.")
        print("      Use --set-passwords with env vars to set them.")

    if as_json:
        print(json.dumps(summary.to_dict(), indent=2))

    return 0 if summary.errors == 0 and summary.refused == 0 else 1


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Bootstrap planner and applier for synthetic runtime proof fixtures. "
            "Dry-run does NOT require Django. --apply requires LMS Django context."
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
            "Apply changes to the database via Django ORM. "
            "Requires running inside an LMS pod with Django available. "
            "Guard chain runs before any write — all guards must pass."
        ),
    )
    parser.add_argument(
        "--json",
        action="store_true",
        default=False,
        help="Output machine-readable JSON instead of human-readable plan.",
    )
    parser.add_argument(
        "--set-passwords",
        action="store_true",
        default=False,
        help=(
            "Set passwords for all synthetic users. Reads from environment variables "
            "matching the password_secret_path basename (e.g. LANEA_PLATFORM_ADMIN_PASSWORD). "
            "Requires --apply and Django context."
        ),
    )
    args = parser.parse_args()

    try:
        manifest = load_manifest(args.env)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    # Validate before planning or applying.
    errors = validate_manifest(manifest)
    if errors:
        print("ERROR: Manifest validation failed:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    if args.apply:
        # Check Django availability before attempting apply.
        if not os.environ.get("DJANGO_SETTINGS_MODULE"):
            print("=" * 70, file=sys.stderr)
            print("ERROR: --apply requires Django settings.", file=sys.stderr)
            print(file=sys.stderr)
            print(
                "DJANGO_SETTINGS_MODULE is not set in this environment. "
                "Run --apply from inside an LMS pod:",
                file=sys.stderr,
            )
            print(
                "  kubectl exec -n mereka-lms-dev deploy/lms -- python "
                "/openedx/scripts/tenants/bootstrap-runtime-proof-fixtures.py "
                f"--env {args.env} --apply",
                file=sys.stderr,
            )
            print("=" * 70, file=sys.stderr)
            return 1
        try:
            import django  # noqa: PLC0415, F401
        except ImportError:
            print("=" * 70, file=sys.stderr)
            print("ERROR: --apply requires Django.", file=sys.stderr)
            print(file=sys.stderr)
            print(
                "Django is not available in this environment. "
                "Run --apply from inside an LMS pod:",
                file=sys.stderr,
            )
            print(
                "  kubectl exec -n mereka-lms-dev deploy/lms -- python "
                "/openedx/scripts/tenants/bootstrap-runtime-proof-fixtures.py "
                f"--env {args.env} --apply",
                file=sys.stderr,
            )
            print("=" * 70, file=sys.stderr)
            return 1

        return run_apply(
            manifest, args.env, as_json=args.json, set_passwords=args.set_passwords
        )

    # Dry-run path.
    actions = build_plan(manifest)

    if args.json:
        print_plan_json(manifest, actions)
    else:
        print_plan_human(manifest, actions)

    return 0


if __name__ == "__main__":
    sys.exit(main())
