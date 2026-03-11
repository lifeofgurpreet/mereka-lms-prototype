#!/usr/bin/env python3
"""
Unit tests for enterprise tenant bootstrap spec parsing and dry-run behavior.

These tests do NOT require Django or a database — they test the YAML parsing,
validation, and dry-run logic extracted from the bootstrap tool.

Run:
    python -m pytest tests/tenants/test_bootstrap_spec.py -v
    # or
    python tests/tenants/test_bootstrap_spec.py
"""

import json
import re
import unittest
from pathlib import Path

import yaml

FIXTURES_DIR = Path(__file__).parent / "fixtures"
CONFIG_DIR = Path(__file__).parent.parent.parent / "config" / "enterprise-tenants"

# Slug validation regex: alphanumeric + hyphens/underscores, 1-63 chars
SLUG_PATTERN = re.compile(r"^[a-z0-9][a-z0-9_-]{0,62}$")


def load_spec(path: Path) -> dict:
    """Load and parse a tenant spec YAML file."""
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def validate_slug(slug: str) -> list[str]:
    """Validate a tenant slug. Returns list of error strings."""
    errors = []
    if not slug:
        errors.append("slug is empty")
    elif not SLUG_PATTERN.match(slug):
        errors.append(
            f"slug '{slug}' is invalid: must be lowercase alphanumeric "
            "with hyphens/underscores, 1-63 chars, starting with alphanumeric"
        )
    return errors


def validate_spec(spec: dict) -> list[str]:
    """Validate a full tenant spec. Returns list of error strings."""
    errors = []

    if "version" not in spec:
        errors.append("missing 'version' field")
    if "tenants" not in spec:
        errors.append("missing 'tenants' field")
        return errors

    tenants = spec["tenants"]
    if not isinstance(tenants, list):
        errors.append("'tenants' must be a list")
        return errors

    seen_slugs = set()
    seen_domains = set()

    for i, tenant in enumerate(tenants):
        prefix = f"tenant[{i}]"

        # Required fields
        if "slug" not in tenant:
            errors.append(f"{prefix}: missing 'slug'")
            continue

        slug = tenant["slug"]
        errors.extend(validate_slug(slug))

        if slug in seen_slugs:
            errors.append(f"{prefix}: duplicate slug '{slug}'")
        seen_slugs.add(slug)

        if "name" not in tenant:
            errors.append(f"{prefix} ({slug}): missing 'name'")
        if "org_code" not in tenant:
            errors.append(f"{prefix} ({slug}): missing 'org_code'")

        # Site
        site = tenant.get("site", {})
        domain = site.get("domain", "")
        if not domain:
            errors.append(f"{prefix} ({slug}): missing 'site.domain'")
        elif domain in seen_domains:
            errors.append(f"{prefix} ({slug}): duplicate domain '{domain}'")
        seen_domains.add(domain)

        # Catalogs
        for j, cat in enumerate(tenant.get("catalogs", [])):
            if "title" not in cat:
                errors.append(f"{prefix} ({slug}): catalog[{j}] missing 'title'")
            cq = cat.get("catalog_query", {})
            if not cq.get("org_filter"):
                errors.append(
                    f"{prefix} ({slug}): catalog[{j}] missing 'catalog_query.org_filter'"
                )

        # User links
        for j, link in enumerate(tenant.get("user_links", [])):
            if "email" not in link:
                errors.append(f"{prefix} ({slug}): user_links[{j}] missing 'email'")
            role = link.get("role", "learner")
            if role not in ("admin", "learner"):
                errors.append(
                    f"{prefix} ({slug}): user_links[{j}] invalid role '{role}'"
                )

    return errors


def simulate_dry_run(spec: dict) -> list[dict]:
    """Simulate a dry run of the bootstrap tool. Returns action list per tenant."""
    results = []
    for tenant in spec.get("tenants", []):
        slug = tenant.get("slug", "unknown")
        actions = []
        errors = []

        # Site
        domain = tenant.get("site", {}).get("domain", "")
        if domain:
            actions.append(f"CREATE Site domain={domain}")

        # Enterprise Customer
        actions.append(f"CREATE EnterpriseCustomer slug={slug} name={tenant.get('name', '')}")

        # Catalogs
        for cat in tenant.get("catalogs", []):
            actions.append(f"CREATE Catalog title='{cat['title']}'")
            org_filter = cat.get("catalog_query", {}).get("org_filter", [])
            actions.append(f"CREATE CatalogQuery org_filter={org_filter}")

        # User links
        for link in tenant.get("user_links", []):
            email = link["email"]
            role = link.get("role", "learner")
            actions.append(f"CREATE EnterpriseCustomerUser email={email} role={role}")

        # Waffle switches
        for switch, active in tenant.get("waffle_switches", {}).items():
            state = "on" if active else "off"
            actions.append(f"ENSURE Waffle Switch {switch}.{slug} = {state}")

        results.append({"slug": slug, "actions": actions, "errors": errors})
    return results


class TestSpecParsing(unittest.TestCase):
    """Test YAML spec loading and structure."""

    def test_valid_spec_loads(self):
        spec = load_spec(FIXTURES_DIR / "valid-spec.yaml")
        self.assertEqual(spec["version"], "1.0")
        self.assertEqual(spec["environment"], "test")
        self.assertEqual(len(spec["tenants"]), 2)

    def test_valid_spec_tenant_fields(self):
        spec = load_spec(FIXTURES_DIR / "valid-spec.yaml")
        tenant = spec["tenants"][0]
        self.assertEqual(tenant["slug"], "acme")
        self.assertEqual(tenant["name"], "Acme Corp")
        self.assertEqual(tenant["org_code"], "ACME")
        self.assertTrue(tenant["active"])
        self.assertEqual(tenant["site"]["domain"], "test.localhost")

    def test_valid_spec_catalogs(self):
        spec = load_spec(FIXTURES_DIR / "valid-spec.yaml")
        catalogs = spec["tenants"][0]["catalogs"]
        self.assertEqual(len(catalogs), 1)
        self.assertEqual(catalogs[0]["title"], "Acme Full Catalog")
        self.assertEqual(
            catalogs[0]["catalog_query"]["org_filter"], ["ACME"]
        )

    def test_valid_spec_user_links(self):
        spec = load_spec(FIXTURES_DIR / "valid-spec.yaml")
        links = spec["tenants"][0]["user_links"]
        self.assertEqual(len(links), 1)
        self.assertEqual(links[0]["email"], "admin@acme.com")
        self.assertEqual(links[0]["role"], "admin")

    def test_shared_mereka_variant_loads(self):
        path = CONFIG_DIR / "dev.enterprise-tenants.shared-mereka.yaml"
        if not path.exists():
            self.skipTest(f"{path} not found")
        spec = load_spec(path)
        self.assertEqual(len(spec["tenants"]), 3)
        # Partner tenants include MEREKA in org_filter
        bijibiji = next(t for t in spec["tenants"] if t["slug"] == "bijibiji")
        org_filter = bijibiji["catalogs"][0]["catalog_query"]["org_filter"]
        self.assertIn("MEREKA", org_filter)
        self.assertIn("BIJIBIJI", org_filter)

    def test_partner_isolated_variant_loads(self):
        path = CONFIG_DIR / "dev.enterprise-tenants.partner-isolated.yaml"
        if not path.exists():
            self.skipTest(f"{path} not found")
        spec = load_spec(path)
        bijibiji = next(t for t in spec["tenants"] if t["slug"] == "bijibiji")
        org_filter = bijibiji["catalogs"][0]["catalog_query"]["org_filter"]
        self.assertNotIn("MEREKA", org_filter)
        self.assertEqual(org_filter, ["BIJIBIJI"])


class TestSlugValidation(unittest.TestCase):
    """Test slug normalization and conflict handling."""

    def test_valid_slugs(self):
        for slug in ["mereka", "bijibiji", "skillourfuture", "acme-corp", "test_123"]:
            self.assertEqual(validate_slug(slug), [], f"slug '{slug}' should be valid")

    def test_empty_slug(self):
        errors = validate_slug("")
        self.assertTrue(any("empty" in e for e in errors))

    def test_uppercase_slug(self):
        errors = validate_slug("MEREKA")
        self.assertTrue(len(errors) > 0, "uppercase slugs should be invalid")

    def test_slug_with_spaces(self):
        errors = validate_slug("has spaces")
        self.assertTrue(len(errors) > 0)

    def test_slug_with_special_chars(self):
        errors = validate_slug("acme@corp!")
        self.assertTrue(len(errors) > 0)

    def test_slug_too_long(self):
        errors = validate_slug("a" * 64)
        self.assertTrue(len(errors) > 0, "slugs > 63 chars should be invalid")

    def test_slug_starting_with_hyphen(self):
        errors = validate_slug("-acme")
        self.assertTrue(len(errors) > 0)

    def test_hyphenated_slug_valid(self):
        """biji-biji is technically valid as a slug (hyphens allowed)."""
        errors = validate_slug("biji-biji")
        self.assertEqual(errors, [])


class TestSpecValidation(unittest.TestCase):
    """Test full spec validation."""

    def test_valid_spec_passes(self):
        spec = load_spec(FIXTURES_DIR / "valid-spec.yaml")
        errors = validate_spec(spec)
        self.assertEqual(errors, [])

    def test_missing_slug_detected(self):
        spec = load_spec(FIXTURES_DIR / "invalid-spec-missing-slug.yaml")
        errors = validate_spec(spec)
        self.assertTrue(any("missing 'slug'" in e for e in errors))

    def test_bad_slug_detected(self):
        spec = load_spec(FIXTURES_DIR / "invalid-spec-bad-slug.yaml")
        errors = validate_spec(spec)
        self.assertTrue(any("invalid" in e for e in errors))

    def test_duplicate_slugs_detected(self):
        spec = load_spec(FIXTURES_DIR / "duplicate-slugs.yaml")
        errors = validate_spec(spec)
        self.assertTrue(any("duplicate slug" in e for e in errors))

    def test_all_production_variants_valid(self):
        """Every spec file in config/enterprise-tenants/ must pass validation."""
        for path in CONFIG_DIR.glob("*.yaml"):
            spec = load_spec(path)
            errors = validate_spec(spec)
            self.assertEqual(errors, [], f"{path.name} has validation errors: {errors}")


class TestDryRunSimulation(unittest.TestCase):
    """Test dry-run output format and content."""

    def test_dry_run_produces_correct_actions(self):
        spec = load_spec(FIXTURES_DIR / "valid-spec.yaml")
        results = simulate_dry_run(spec)

        self.assertEqual(len(results), 2)
        self.assertEqual(results[0]["slug"], "acme")
        self.assertEqual(results[1]["slug"], "partner")

        # Acme should have: 1 site + 1 EC + 1 catalog + 1 CQ + 1 user + 2 switches = 7
        acme_actions = results[0]["actions"]
        self.assertTrue(any("Site" in a for a in acme_actions))
        self.assertTrue(any("EnterpriseCustomer" in a for a in acme_actions))
        self.assertTrue(any("Catalog" in a for a in acme_actions))
        self.assertTrue(any("CatalogQuery" in a for a in acme_actions))
        self.assertTrue(any("EnterpriseCustomerUser" in a for a in acme_actions))
        self.assertTrue(any("Waffle Switch" in a for a in acme_actions))

    def test_dry_run_no_errors_for_valid_spec(self):
        spec = load_spec(FIXTURES_DIR / "valid-spec.yaml")
        results = simulate_dry_run(spec)
        for r in results:
            self.assertEqual(r["errors"], [])

    def test_dry_run_shared_mereka_includes_mereka_org(self):
        path = CONFIG_DIR / "dev.enterprise-tenants.shared-mereka.yaml"
        if not path.exists():
            self.skipTest(f"{path} not found")
        spec = load_spec(path)
        results = simulate_dry_run(spec)

        bijibiji = next(r for r in results if r["slug"] == "bijibiji")
        cq_actions = [a for a in bijibiji["actions"] if "CatalogQuery" in a]
        self.assertTrue(any("MEREKA" in a for a in cq_actions))

    def test_dry_run_partner_isolated_excludes_mereka_org(self):
        path = CONFIG_DIR / "dev.enterprise-tenants.partner-isolated.yaml"
        if not path.exists():
            self.skipTest(f"{path} not found")
        spec = load_spec(path)
        results = simulate_dry_run(spec)

        bijibiji = next(r for r in results if r["slug"] == "bijibiji")
        cq_actions = [a for a in bijibiji["actions"] if "CatalogQuery" in a]
        self.assertFalse(any("MEREKA" in a for a in cq_actions))

    def test_dry_run_output_matches_fixture(self):
        """Dry-run output structure matches expected fixture format."""
        spec = load_spec(FIXTURES_DIR / "valid-spec.yaml")
        results = simulate_dry_run(spec)
        expected = json.loads(
            (FIXTURES_DIR / "expected-dry-run-output.json").read_text()
        )

        self.assertEqual(len(results), expected["tenants_processed"])
        for actual, exp in zip(results, expected["results"]):
            self.assertEqual(actual["slug"], exp["slug"])
            self.assertEqual(actual["errors"], exp["errors"])
            # Check action count matches
            self.assertEqual(
                len(actual["actions"]),
                len(exp["actions"]),
                f"Action count mismatch for {actual['slug']}: "
                f"got {len(actual['actions'])}, expected {len(exp['actions'])}",
            )


class TestSpecConsistency(unittest.TestCase):
    """Cross-variant consistency checks."""

    def test_all_variants_have_same_tenants(self):
        """All spec variants must define the same set of tenant slugs."""
        specs = {}
        for path in CONFIG_DIR.glob("dev.enterprise-tenants*.yaml"):
            spec = load_spec(path)
            slugs = sorted(t["slug"] for t in spec["tenants"])
            specs[path.name] = slugs

        if len(specs) < 2:
            self.skipTest("Need at least 2 variants to compare")

        first_name, first_slugs = next(iter(specs.items()))
        for name, slugs in specs.items():
            self.assertEqual(
                slugs,
                first_slugs,
                f"{name} has different tenants than {first_name}",
            )

    def test_all_variants_have_same_domains(self):
        """All spec variants must define the same site domains per tenant."""
        specs = {}
        for path in CONFIG_DIR.glob("dev.enterprise-tenants*.yaml"):
            spec = load_spec(path)
            domains = {t["slug"]: t["site"]["domain"] for t in spec["tenants"]}
            specs[path.name] = domains

        if len(specs) < 2:
            self.skipTest("Need at least 2 variants to compare")

        first_name, first_domains = next(iter(specs.items()))
        for name, domains in specs.items():
            self.assertEqual(
                domains,
                first_domains,
                f"{name} has different domains than {first_name}",
            )

    def test_mereka_is_operator_in_all_variants(self):
        """Mereka must be platform operator in all variants."""
        for path in CONFIG_DIR.glob("dev.enterprise-tenants*.yaml"):
            spec = load_spec(path)
            mereka = next(
                (t for t in spec["tenants"] if t["slug"] == "mereka"), None
            )
            self.assertIsNotNone(mereka, f"mereka tenant missing in {path.name}")
            self.assertTrue(
                mereka.get("is_platform_operator", False),
                f"mereka must be platform operator in {path.name}",
            )


if __name__ == "__main__":
    unittest.main()
