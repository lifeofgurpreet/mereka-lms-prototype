#!/usr/bin/env python3
"""
Read-only validation tool for synthetic runtime proof fixture manifests.

Validates the manifest schema and consistency statically — no cluster access,
no Django dependency. Designed to run in CI and locally before any bootstrap step.

With --mode live-readonly: performs read-only ORM queries against a live Django
environment to confirm that the expected records exist. Requires Django context
(LMS pod). No writes are performed.

Exit codes:
    0  manifest is valid
    1  one or more validation errors found

Usage:
    python scripts/tenants/validate-runtime-proof-fixtures.py --env dev
    python scripts/tenants/validate-runtime-proof-fixtures.py --env dev --json
    python scripts/tenants/validate-runtime-proof-fixtures.py --env dev --mode live-readonly
    python scripts/tenants/validate-runtime-proof-fixtures.py --env dev --live
      (--live is a deprecated alias for --mode live-readonly)
"""

import argparse
import json
import os
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
    candidates = []
    manifest_dir_override = os.environ.get("RUNTIME_PROOF_MANIFEST_DIR")
    if manifest_dir_override:
        candidates.append(Path(manifest_dir_override) / f"{env}.synthetic-proof-fixtures.yaml")
    candidates.extend(
        [
            MANIFEST_DIR / f"{env}.synthetic-proof-fixtures.yaml",
            Path(f"/openedx/config/runtime-proof/{env}.synthetic-proof-fixtures.yaml"),
        ]
    )
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


def check_catalog_uuid_format(manifest: dict[str, Any]) -> list[CheckResult]:
    """Validate that enterprise_catalog_uuid values are valid UUID format."""
    import uuid as uuid_mod

    results = []
    ecsd = manifest.get("fixture_classes", {}).get("enterprise_catalog_service_data", {})
    for cat in ecsd.get("catalogs", []):
        cat_uuid = cat.get("enterprise_catalog_uuid")
        slug = cat.get("enterprise_customer_slug", "?")
        title = cat.get("title", "?")
        if cat_uuid is None:
            results.append(
                CheckResult(
                    f"catalog_uuid_format:{slug}:{title}",
                    False,
                    f"enterprise_catalog_uuid is null for {slug!r}/{title!r} — "
                    "UUID drift cannot be detected",
                    detail=(
                        "Set enterprise_catalog_uuid to the live catalog UUID so "
                        "bootstrap can detect drift."
                    ),
                )
            )
            continue
        try:
            uuid_mod.UUID(str(cat_uuid))
            results.append(
                CheckResult(
                    f"catalog_uuid_format:{slug}:{title}",
                    True,
                    f"enterprise_catalog_uuid {cat_uuid!r} is valid UUID",
                )
            )
        except ValueError:
            results.append(
                CheckResult(
                    f"catalog_uuid_format:{slug}:{title}",
                    False,
                    f"enterprise_catalog_uuid {cat_uuid!r} is NOT valid UUID format",
                )
            )
    return results


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


def check_negative_cases_consistency(manifest: dict[str, Any]) -> list[CheckResult]:
    """Verify negative_cases reference valid identities with no enterprise links."""
    results: list[CheckResult] = []
    nc = manifest.get("fixture_classes", {}).get("negative_cases", {})
    cases = nc.get("cases", [])
    if not cases:
        return results

    si = manifest.get("fixture_classes", {}).get("synthetic_identities", {})
    users_by_username = {u["username"]: u for u in si.get("users", [])}

    for case in cases:
        case_id = case.get("id", "?")
        identity = case.get("identity")
        if not identity:
            continue

        user = users_by_username.get(identity)
        if not user:
            results.append(
                CheckResult(
                    f"negative_case:identity_exists:{case_id}",
                    False,
                    f"Negative case {case_id} references identity {identity!r} "
                    "which is not defined in synthetic_identities",
                )
            )
            continue

        results.append(
            CheckResult(
                f"negative_case:identity_exists:{case_id}",
                True,
                f"Negative case {case_id}: identity {identity!r} exists in manifest",
            )
        )

        # For non-linked user cases, verify enterprise_link is null.
        link = user.get("enterprise_link")
        if link is not None:
            results.append(
                CheckResult(
                    f"negative_case:no_enterprise_link:{case_id}",
                    False,
                    f"Negative case {case_id}: identity {identity!r} has "
                    f"enterprise_link={link!r} — expected null for negative case",
                )
            )
        else:
            results.append(
                CheckResult(
                    f"negative_case:no_enterprise_link:{case_id}",
                    True,
                    f"Negative case {case_id}: identity {identity!r} has no enterprise link (correct)",
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
    results.extend(check_catalog_uuid_format(manifest))
    results.extend(check_waffle_flags(manifest))
    results.extend(check_negative_cases_consistency(manifest))
    return results


# ── Live-readonly checks (Django ORM, read-only) ──────────────────────────────


def check_live_users(manifest: dict[str, Any]) -> list[CheckResult]:
    """Read-only ORM check: verify synthetic user accounts exist in the DB."""
    results: list[CheckResult] = []
    try:
        from common.djangoapps.student.models import UserProfile  # noqa: PLC0415
        from django.contrib.auth import get_user_model  # noqa: PLC0415
    except ImportError:
        results.append(
            CheckResult(
                "live:django_available",
                False,
                "Django is not available — live-readonly checks require LMS Django context",
                detail=(
                    "Run with --mode live-readonly from inside an LMS pod: "
                    "kubectl exec -n mereka-lms-dev deploy/lms -- python "
                    "/openedx/scripts/tenants/validate-runtime-proof-fixtures.py "
                    "--env dev --mode live-readonly"
                ),
            )
        )
        return results

    results.append(
        CheckResult("live:django_available", True, "Django ORM is available")
    )

    User = get_user_model()
    si = manifest.get("fixture_classes", {}).get("synthetic_identities", {})

    for user_spec in si.get("users", []):
        username = user_spec["username"]
        email = user_spec["email"]
        user = User.objects.filter(username=username, email=email).first()
        exists = user is not None
        results.append(
            CheckResult(
                f"live:user_exists:{username}",
                exists,
                f"User {username!r} ({email}) {'exists' if exists else 'NOT FOUND'} in DB",
                detail=None if exists else (
                    "Run bootstrap-runtime-proof-fixtures.py --env dev --apply "
                    "to create this user."
                ),
            )
        )
        if user is not None:
            has_profile = UserProfile.objects.filter(user=user).exists()
            results.append(
                CheckResult(
                    f"live:user_profile:{username}",
                    has_profile,
                    f"UserProfile for {username!r} is "
                    f"{'present' if has_profile else 'MISSING'}",
                    detail=None if has_profile else (
                        "Synthetic proof users should have a UserProfile to avoid login/runtime gaps."
                    ),
                )
            )

    return results


def check_live_enterprise_customers(manifest: dict[str, Any]) -> list[CheckResult]:
    """Read-only ORM check: verify enterprise customer records exist in the DB."""
    results: list[CheckResult] = []
    try:
        from enterprise.models import EnterpriseCustomer  # noqa: PLC0415
    except ImportError:
        results.append(
            CheckResult(
                "live:enterprise_models_available",
                False,
                "enterprise.models not importable — skipping enterprise customer checks",
            )
        )
        return results

    led = manifest.get("fixture_classes", {}).get("lms_enterprise_data", {})

    for ec_spec in led.get("enterprise_customers", []):
        slug = ec_spec["slug"]
        exists = EnterpriseCustomer.objects.filter(slug=slug).exists()
        results.append(
            CheckResult(
                f"live:enterprise_customer_exists:{slug}",
                exists,
                f"EnterpriseCustomer {slug!r} {'exists' if exists else 'NOT FOUND'} in DB",
                detail=None if exists else (
                    "Run bootstrap-runtime-proof-fixtures.py --env dev --apply "
                    "to create this enterprise customer."
                ),
            )
        )

    return results


def check_live_enterprise_user_links(manifest: dict[str, Any]) -> list[CheckResult]:
    """Read-only ORM check: verify EnterpriseCustomerUser links exist (or are absent) in the DB."""
    results: list[CheckResult] = []
    try:
        from django.contrib.auth import get_user_model  # noqa: PLC0415
        from enterprise.models import EnterpriseCustomerUser  # noqa: PLC0415
    except ImportError:
        results.append(
            CheckResult(
                "live:enterprise_user_links_available",
                False,
                "enterprise.models not importable — skipping enterprise user link checks",
            )
        )
        return results

    User = get_user_model()
    si = manifest.get("fixture_classes", {}).get("synthetic_identities", {})

    for user_spec in si.get("users", []):
        username = user_spec["username"]
        link = user_spec.get("enterprise_link")

        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            results.append(
                CheckResult(
                    f"live:enterprise_link:{username}",
                    False,
                    f"Cannot check enterprise link for {username!r} — user does not exist in DB",
                )
            )
            continue

        if link:
            customer_slug = link["customer_slug"]
            user_field = "user_fk" if hasattr(EnterpriseCustomerUser, "user_fk_id") else "user"
            linked = EnterpriseCustomerUser.objects.filter(
                **{
                    user_field: user,
                    "enterprise_customer__slug": customer_slug,
                }
            ).exists()
            results.append(
                CheckResult(
                    f"live:enterprise_link:{username}:{customer_slug}",
                    linked,
                    f"EnterpriseCustomerUser link {username!r} -> {customer_slug!r} "
                    f"{'exists' if linked else 'NOT FOUND'} in DB",
                )
            )
        else:
            # Negative case: assert no links.
            user_field = "user_fk" if hasattr(EnterpriseCustomerUser, "user_fk_id") else "user"
            link_count = EnterpriseCustomerUser.objects.filter(**{user_field: user}).count()
            no_links = link_count == 0
            results.append(
                CheckResult(
                    f"live:enterprise_link:absent:{username}",
                    no_links,
                    f"Negative case: {username!r} has {link_count} enterprise link(s) "
                    f"({'OK — no links' if no_links else 'FAIL — expected no links'})",
                )
            )

    return results


def check_live_enterprise_catalog(manifest: dict[str, Any]) -> list[CheckResult]:
    """Read-only ORM check: verify EnterpriseCustomerCatalog exists in the DB."""
    results: list[CheckResult] = []
    try:
        from enterprise.models import EnterpriseCustomerCatalog  # noqa: PLC0415
    except ImportError:
        results.append(
            CheckResult(
                "live:enterprise_catalog_available",
                False,
                "enterprise.models not importable — skipping enterprise catalog checks",
            )
        )
        return results

    led = manifest.get("fixture_classes", {}).get("lms_enterprise_data", {})

    for ec_spec in led.get("enterprise_customers", []):
        slug = ec_spec["slug"]
        for cat_spec in ec_spec.get("catalogs", []):
            title = cat_spec["title"]
            exists = EnterpriseCustomerCatalog.objects.filter(
                enterprise_customer__slug=slug,
                title=title,
            ).exists()
            results.append(
                CheckResult(
                    f"live:enterprise_customer_catalog:{slug}:{title}",
                    exists,
                    f"EnterpriseCustomerCatalog {title!r} for {slug!r} "
                    f"{'exists' if exists else 'NOT FOUND'} in DB",
                )
            )

    return results


def check_live_catalog_uuid_match(manifest: dict[str, Any]) -> list[CheckResult]:
    """Live check: verify enterprise catalog UUIDs match manifest."""
    results: list[CheckResult] = []
    try:
        from enterprise.models import EnterpriseCustomerCatalog  # noqa: PLC0415
    except ImportError:
        # enterprise.models not available — silently skip (already reported by
        # check_live_enterprise_catalog if needed).
        return results

    ecsd = manifest.get("fixture_classes", {}).get("enterprise_catalog_service_data", {})
    for cat_spec in ecsd.get("catalogs", []):
        expected_uuid = cat_spec.get("enterprise_catalog_uuid")
        if not expected_uuid:
            continue
        slug = cat_spec["enterprise_customer_slug"]
        title = cat_spec["title"]
        try:
            cat = EnterpriseCustomerCatalog.objects.get(
                enterprise_customer__slug=slug,
                title=title,
            )
            actual_uuid = str(cat.uuid)
            expected_str = str(expected_uuid)
            match = actual_uuid == expected_str
            results.append(
                CheckResult(
                    f"live:catalog_uuid_match:{slug}:{title}",
                    match,
                    f"EnterpriseCustomerCatalog {title!r} UUID: "
                    f"{'MATCH' if match else 'DRIFT'} "
                    f"(expected={expected_str}, actual={actual_uuid})",
                    detail=None if match else (
                        f"UUID drift detected! Update manifest enterprise_catalog_uuid "
                        f"to {actual_uuid!r} or investigate why the UUID changed."
                    ),
                )
            )
        except EnterpriseCustomerCatalog.DoesNotExist:
            results.append(
                CheckResult(
                    f"live:catalog_uuid_match:{slug}:{title}",
                    False,
                    f"EnterpriseCustomerCatalog {title!r} for {slug!r} NOT FOUND — "
                    "cannot check UUID",
                )
            )
    return results


def check_live_waffle_flags(manifest: dict[str, Any]) -> list[CheckResult]:
    """Read-only ORM check: verify waffle flags and switches exist and have the expected state."""
    results: list[CheckResult] = []
    try:
        from waffle.models import Flag, Switch  # noqa: PLC0415
    except ImportError:
        results.append(
            CheckResult(
                "live:waffle_available",
                False,
                "waffle.models not importable — skipping waffle flag checks",
            )
        )
        return results

    wf = manifest.get("fixture_classes", {}).get("waffle_flags", {})

    for flag_spec in wf.get("platform_wide_flags", []):
        name = flag_spec["name"]
        expected_active = flag_spec.get("active", False)
        try:
            flag = Flag.objects.get(name=name)
            actual_active = flag.everyone is True
            ok = actual_active == expected_active
            results.append(
                CheckResult(
                    f"live:waffle_flag:{name}",
                    ok,
                    f"WaffleFlag {name!r} exists, active={actual_active!r} "
                    f"(expected {expected_active!r})",
                    detail=None if ok else f"Expected active={expected_active}, got {actual_active}",
                )
            )
        except Flag.DoesNotExist:
            results.append(
                CheckResult(
                    f"live:waffle_flag:{name}",
                    False,
                    f"WaffleFlag {name!r} NOT FOUND in DB",
                )
            )

    for switch_spec in wf.get("tenant_scoped_switches", []):
        switch_name = f"{switch_spec['base']}.{switch_spec['enterprise_slug']}"
        expected_active = switch_spec.get("active", False)
        try:
            switch = Switch.objects.get(name=switch_name)
            ok = switch.active == expected_active
            results.append(
                CheckResult(
                    f"live:waffle_switch:{switch_name}",
                    ok,
                    f"WaffleSwitch {switch_name!r} exists, active={switch.active!r} "
                    f"(expected {expected_active!r})",
                    detail=None if ok else (
                        f"Expected active={expected_active}, got {switch.active}"
                    ),
                )
            )
        except Switch.DoesNotExist:
            results.append(
                CheckResult(
                    f"live:waffle_switch:{switch_name}",
                    False,
                    f"WaffleSwitch {switch_name!r} NOT FOUND in DB",
                )
            )

    return results


def check_live_password_usable(manifest: dict[str, Any]) -> list[CheckResult]:
    """Read-only ORM check: verify synthetic users have usable passwords set."""
    results: list[CheckResult] = []
    try:
        from django.contrib.auth import get_user_model  # noqa: PLC0415
    except ImportError:
        return results

    User = get_user_model()
    si = manifest.get("fixture_classes", {}).get("synthetic_identities", {})

    for user_spec in si.get("users", []):
        username = user_spec["username"]
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            results.append(
                CheckResult(
                    f"live:password_usable:{username}",
                    False,
                    f"Cannot check password for {username!r} — user does not exist",
                )
            )
            continue

        usable = user.has_usable_password()
        results.append(
            CheckResult(
                f"live:password_usable:{username}",
                usable,
                f"User {username!r} has {'usable' if usable else 'UNUSABLE'} password",
                detail=None if usable else (
                    "Run bootstrap --apply --set-passwords with env vars to set a password. "
                    f"Env var: {user_spec.get('password_secret_path', '').rsplit('/', 1)[-1]}"
                ),
            )
        )

    return results


def run_live_readonly_checks(manifest: dict[str, Any]) -> list[CheckResult]:
    """Run all live-readonly ORM checks. All reads, no writes."""
    results: list[CheckResult] = []
    results.extend(check_live_users(manifest))
    results.extend(check_live_enterprise_customers(manifest))
    results.extend(check_live_enterprise_user_links(manifest))
    results.extend(check_live_enterprise_catalog(manifest))
    results.extend(check_live_catalog_uuid_match(manifest))
    results.extend(check_live_waffle_flags(manifest))
    results.extend(check_live_password_usable(manifest))
    return results


# ── Output ────────────────────────────────────────────────────────────────────


def print_report_human(
    manifest: dict[str, Any],
    results: list[CheckResult],
    manifest_path: str,
    mode: str,
) -> None:
    env = manifest.get("environment", "?")
    passed = [r for r in results if r.passed]
    failed = [r for r in results if not r.passed]

    mode_label = {
        "static": "Static (no cluster access)",
        "live-readonly": "Live read-only (ORM queries, no writes)",
    }.get(mode, mode)

    print()
    print("=" * 70)
    print("Synthetic Runtime Proof Fixture Validation")
    print(f"Environment : {env}")
    print(f"Manifest    : {manifest_path}")
    print(f"Mode        : {mode_label}")
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
    mode: str,
) -> None:
    passed = [r for r in results if r.passed]
    failed = [r for r in results if not r.passed]
    output = {
        "environment": manifest.get("environment"),
        "manifest_path": manifest_path,
        "mode": mode,
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
            "Static mode: no Django dependency, no cluster access. "
            "Live-readonly mode: read-only ORM queries, requires LMS Django context."
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
        "--mode",
        choices=["static", "live-readonly"],
        default="static",
        help=(
            "Validation mode. 'static' (default): schema and consistency checks only. "
            "'live-readonly': also runs read-only ORM checks against a live LMS DB."
        ),
    )
    parser.add_argument(
        "--live",
        action="store_true",
        default=False,
        help=(
            "Deprecated alias for --mode live-readonly. "
            "Prefer --mode live-readonly for clarity."
        ),
    )
    args = parser.parse_args()

    # Resolve mode: --live is an alias for --mode live-readonly.
    mode = args.mode
    if args.live and mode == "static":
        mode = "live-readonly"

    try:
        manifest, manifest_path = load_manifest(args.env)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    # Always run static checks.
    results = run_all_checks(manifest)

    # Optionally add live-readonly checks.
    if mode == "live-readonly":
        live_results = run_live_readonly_checks(manifest)
        results.extend(live_results)

    failed = [r for r in results if not r.passed]

    if args.json:
        print_report_json(manifest, results, manifest_path, mode)
    else:
        print_report_human(manifest, results, manifest_path, mode)

    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
