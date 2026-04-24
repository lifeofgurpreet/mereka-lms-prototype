#!/usr/bin/env python3
"""
Enterprise-catalog companion bootstrap for synthetic runtime proof fixtures.

Reads config/runtime-proof/<env>.synthetic-proof-fixtures.yaml and applies
enterprise-catalog service records (CatalogQuery, EnterpriseCatalog) via Django ORM.

Must be run inside an enterprise-catalog pod with:
  DJANGO_SETTINGS_MODULE=enterprise_catalog.settings.production

Default: DRY RUN (print-only, no Django required).
--apply: runs Django ORM mutations if Django is available; prints an error and exits
         if Django is not available (must be run from inside an enterprise-catalog pod).

Note: This tool handles ONLY enterprise_catalog_service_data records.
For LMS-side records (users, enterprise customers, waffle flags), use:
  bootstrap-runtime-proof-fixtures.py

Usage:
    python scripts/tenants/bootstrap-runtime-proof-fixtures-catalog.py --env dev
    python scripts/tenants/bootstrap-runtime-proof-fixtures-catalog.py --env dev --json
    python scripts/tenants/bootstrap-runtime-proof-fixtures-catalog.py --env dev --apply
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
    ApplySummary,
    SyntheticSafetyViolation,
    make_action,
    run_all_guards,
)

# ── Django settings ───────────────────────────────────────────────────────────
# This tool runs inside the enterprise-catalog Django context.
# If DJANGO_SETTINGS_MODULE is not set, default to production settings.
_DEFAULT_SETTINGS = "enterprise_catalog.settings.production"


def _ensure_django_settings() -> None:
    if not os.environ.get("DJANGO_SETTINGS_MODULE"):
        os.environ["DJANGO_SETTINGS_MODULE"] = _DEFAULT_SETTINGS


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


# ── Plan generation (dry-run) ─────────────────────────────────────────────────


class CatalogAction:
    """A single planned enterprise-catalog bootstrap action."""

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


def plan_catalog_service_data(manifest: dict[str, Any]) -> list[CatalogAction]:
    """Build the dry-run plan for enterprise_catalog_service_data."""
    actions: list[CatalogAction] = []
    ecsd = manifest.get("fixture_classes", {}).get("enterprise_catalog_service_data", {})

    for cat in ecsd.get("catalogs", []):
        content_filter = cat.get("catalog_query", {}).get("content_filter", {})
        actions.append(
            CatalogAction(
                category="catalog_query",
                kind="CREATE_OR_NOOP",
                description=(
                    f"Ensure CatalogQuery for customer={cat['enterprise_customer_slug']!r} "
                    f"title={cat['title']!r} (idempotent by content_filter)"
                ),
                detail={
                    "enterprise_customer_slug": cat["enterprise_customer_slug"],
                    "content_filter": content_filter,
                    "include_exec_ed_2u_course_types": cat.get(
                        "include_exec_ed_2u_course_types", False
                    ),
                },
            )
        )
        actions.append(
            CatalogAction(
                category="enterprise_catalog",
                kind="CREATE_OR_NOOP",
                description=(
                    f"Ensure EnterpriseCatalog for customer={cat['enterprise_customer_slug']!r} "
                    f"title={cat['title']!r} (idempotent by enterprise_customer + title)"
                ),
                detail={
                    "enterprise_customer_slug": cat["enterprise_customer_slug"],
                    "title": cat["title"],
                    "enterprise_catalog_uuid": cat.get("enterprise_catalog_uuid"),
                    "note": (
                        "enterprise_catalog_uuid is null until LMS-side bootstrap assigns one. "
                        "After LMS bootstrap, retrieve the UUID and update this manifest."
                    ),
                },
            )
        )

    verification = ecsd.get("verification", {})
    if verification:
        actions.append(
            CatalogAction(
                category="enterprise_catalog",
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


# ── Output ────────────────────────────────────────────────────────────────────


def print_plan_human(manifest: dict[str, Any], actions: list[CatalogAction]) -> None:
    env = manifest.get("environment", "?")
    print()
    print("=" * 70)
    print("Enterprise-Catalog Companion Bootstrap [DRY RUN]")
    print(f"Environment : {env}")
    print(f"Contract    : {manifest.get('contract_ref', '?')}")
    print(f"Actions     : {len(actions)}")
    print(
        "Scope       : enterprise_catalog_service_data only (CatalogQuery, EnterpriseCatalog)"
    )
    print("=" * 70)
    print()

    categories: dict[str, list[CatalogAction]] = {}
    for action in actions:
        categories.setdefault(action.category, []).append(action)

    category_labels = {
        "catalog_query": "CatalogQuery Records",
        "enterprise_catalog": "EnterpriseCatalog Records",
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
    print("To apply changes (run from inside an enterprise-catalog pod):")
    print(
        "  python scripts/tenants/bootstrap-runtime-proof-fixtures-catalog.py "
        f"--env {env} --apply"
    )
    print()
    print("PREREQUISITE: LMS-side bootstrap must run first to assign enterprise customer UUIDs.")
    print("  See bootstrap-runtime-proof-fixtures.py for the LMS-side step.")
    print("=" * 70)
    print()


def print_plan_json(manifest: dict[str, Any], actions: list[CatalogAction]) -> None:
    output = {
        "mode": "dry_run",
        "tool": "bootstrap-runtime-proof-fixtures-catalog",
        "environment": manifest.get("environment"),
        "contract_ref": manifest.get("contract_ref"),
        "real_account_mutation_forbidden": manifest.get("real_account_mutation_forbidden"),
        "scope": "enterprise_catalog_service_data",
        "action_count": len(actions),
        "actions": [a.to_dict() for a in actions],
    }
    print(json.dumps(output, indent=2))


# ── Apply path (Django ORM) ───────────────────────────────────────────────────


def apply_catalog_service_data(
    manifest: dict[str, Any],
    summary: ApplySummary,
    dry_run: bool,
) -> None:
    """Apply CatalogQuery and EnterpriseCatalog records via enterprise-catalog Django ORM."""
    # Deferred Django imports — only available inside enterprise-catalog pod.
    try:
        import django  # noqa: PLC0415, F401
        from enterprise_catalog.apps.catalog.models import (  # noqa: PLC0415
            CatalogQuery,
            EnterpriseCatalog,
        )
    except ImportError as exc:
        raise RuntimeError(
            "Django ORM (enterprise_catalog) not available. "
            "Run --apply from inside an enterprise-catalog pod: "
            "kubectl exec -n mereka-lms-dev deploy/enterprise-catalog -- python "
            "/openedx/scripts/tenants/bootstrap-runtime-proof-fixtures-catalog.py "
            "--env dev --apply"
        ) from exc

    ecsd = manifest.get("fixture_classes", {}).get("enterprise_catalog_service_data", {})

    for cat_spec in ecsd.get("catalogs", []):
        customer_slug = cat_spec["enterprise_customer_slug"]
        title = cat_spec["title"]
        content_filter = cat_spec.get("catalog_query", {}).get("content_filter", {})
        include_exec_ed = cat_spec.get("include_exec_ed_2u_course_types", False)

        # CatalogQuery: idempotent by content_filter match.
        content_filter_json = json.dumps(content_filter, sort_keys=True)
        cq = CatalogQuery.objects.filter(
            content_filter=content_filter
        ).first()
        if cq is None:
            cq = CatalogQuery.objects.create(
                content_filter=content_filter,
                include_exec_ed_2u_course_types=include_exec_ed,
            )
            cq_action = "CREATE"
            summary.created += 1
            print(f"  [CREATE] CatalogQuery for {customer_slug!r}/{title!r}")
        else:
            cq_action = "NOOP"
            summary.reused += 1
            print(f"  [NOOP] CatalogQuery for {customer_slug!r}/{title!r} already exists")

        cq_rec = make_action(
            cq_action,
            "CatalogQuery",
            f"{customer_slug}/{title}",
            f"{'Created' if cq_action == 'CREATE' else 'Reused'} CatalogQuery "
            f"for {customer_slug!r}/{title!r} "
            f"(content_filter={content_filter_json!r})",
            dry_run,
        )
        summary.actions.append(cq_rec)

        # EnterpriseCatalog: idempotent by enterprise_customer_uuid + title.
        # Note: enterprise_customer field is a UUID from the LMS-side bootstrap.
        catalog_uuid = cat_spec.get("enterprise_catalog_uuid")

        ec_catalog, ec_catalog_created = EnterpriseCatalog.objects.get_or_create(
            enterprise_customer=customer_slug,  # stored as UUID or slug depending on model
            title=title,
            defaults={
                "catalog_query": cq,
                **({"uuid": catalog_uuid} if catalog_uuid else {}),
            },
        )

        # UUID drift detection: on NOOP, verify existing UUID matches manifest.
        if not ec_catalog_created and catalog_uuid:
            actual_uuid = str(ec_catalog.uuid)
            expected_uuid = str(catalog_uuid)
            if actual_uuid != expected_uuid:
                summary.errors += 1
                cat_rec = make_action(
                    "DRIFT",
                    "EnterpriseCatalog",
                    f"{customer_slug}/{title}",
                    f"UUID DRIFT: EnterpriseCatalog {title!r} for {customer_slug!r} "
                    f"manifest={expected_uuid} actual={actual_uuid}",
                    dry_run,
                )
                summary.actions.append(cat_rec)
                print(
                    f"  [DRIFT] EnterpriseCatalog UUID mismatch for {customer_slug!r}/{title!r}: "
                    f"manifest={expected_uuid}, actual={actual_uuid}",
                    file=sys.stderr,
                )
                continue  # Skip to next catalog — drift already recorded.

        cat_action = "CREATE" if ec_catalog_created else "NOOP"
        cat_rec = make_action(
            cat_action,
            "EnterpriseCatalog",
            f"{customer_slug}/{title}",
            f"{'Created' if ec_catalog_created else 'Already exists'}: "
            f"EnterpriseCatalog {title!r} for {customer_slug!r}",
            dry_run,
        )
        summary.actions.append(cat_rec)
        if ec_catalog_created:
            summary.created += 1
            print(f"  [CREATE] EnterpriseCatalog: {title!r} for {customer_slug!r}")
        else:
            summary.reused += 1
            print(f"  [NOOP] EnterpriseCatalog: {title!r} for {customer_slug!r} already exists")


def run_apply(manifest: dict[str, Any], env: str, as_json: bool) -> int:
    """
    Execute the apply path. Guard chain runs first; all guards must pass before
    any ORM write. Requires enterprise-catalog Django context.

    Returns exit code (0 = success, 1 = failure).
    """
    # Guard chain — all-or-nothing.
    try:
        run_all_guards(manifest, env)
    except SyntheticSafetyViolation as exc:
        print(f"ERROR: Guard chain failed — {exc}", file=sys.stderr)
        print("No changes were made.", file=sys.stderr)
        return 1

    _ensure_django_settings()

    summary = ApplySummary(
        environment=env,
        mode="apply",
        real_account_mutation_forbidden=manifest.get("real_account_mutation_forbidden", False),
    )

    print()
    print("=" * 70)
    print("Enterprise-Catalog Companion Bootstrap [APPLY]")
    print(f"Environment : {env}")
    print(f"Contract    : {manifest.get('contract_ref', '?')}")
    print("Scope       : enterprise_catalog_service_data only")
    print("=" * 70)
    print()

    try:
        print("--- Enterprise-Catalog Service Data ---")
        apply_catalog_service_data(manifest, summary, dry_run=False)
        print()
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print("=" * 70)
    print(
        f"Apply complete: created={summary.created} reused={summary.reused} "
        f"skipped={summary.skipped} refused={summary.refused} errors={summary.errors}"
    )
    print("=" * 70)
    print()
    print("NOTE: LMS-side records (users, enterprise customers, waffle flags) are")
    print("      NOT handled by this tool. Use bootstrap-runtime-proof-fixtures.py.")

    if as_json:
        print(json.dumps(summary.to_dict(), indent=2))

    return 0 if summary.errors == 0 and summary.refused == 0 else 1


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Enterprise-catalog companion bootstrap for synthetic runtime proof fixtures. "
            "Handles enterprise_catalog_service_data only (CatalogQuery, EnterpriseCatalog). "
            "Dry-run does NOT require Django. --apply requires enterprise-catalog Django context."
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
            "Apply changes to the enterprise-catalog database via Django ORM. "
            "Requires running inside an enterprise-catalog pod. "
            "Guard chain runs before any write — all guards must pass."
        ),
    )
    parser.add_argument(
        "--json",
        action="store_true",
        default=False,
        help="Output machine-readable JSON instead of human-readable plan.",
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

    if args.apply:
        # Check Django availability before attempting apply.
        try:
            import django  # noqa: PLC0415, F401
        except ImportError:
            print("=" * 70, file=sys.stderr)
            print("ERROR: --apply requires Django (enterprise-catalog).", file=sys.stderr)
            print(file=sys.stderr)
            print(
                "Django is not available in this environment. "
                "Run --apply from inside an enterprise-catalog pod:",
                file=sys.stderr,
            )
            print(
                "  kubectl exec -n mereka-lms-dev deploy/enterprise-catalog -- python "
                "/openedx/scripts/tenants/bootstrap-runtime-proof-fixtures-catalog.py "
                f"--env {args.env} --apply",
                file=sys.stderr,
            )
            print("=" * 70, file=sys.stderr)
            return 1

        return run_apply(manifest, args.env, as_json=args.json)

    # Dry-run path.
    actions = plan_catalog_service_data(manifest)

    if args.json:
        print_plan_json(manifest, actions)
    else:
        print_plan_human(manifest, actions)

    return 0


if __name__ == "__main__":
    sys.exit(main())
