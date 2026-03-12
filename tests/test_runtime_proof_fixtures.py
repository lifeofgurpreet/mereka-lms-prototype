"""
Tests for the synthetic runtime proof fixture pack.

No Django dependency. No live cluster access. All tests run in CI without
any special environment setup beyond Python 3.10+ and PyYAML.

Covers:
  - Manifest parsing (valid YAML, required fields)
  - Required fixture class presence
  - Dry-run output stability (bootstrap tool produces expected output)
  - Negative: real-account fixture rejected
  - Negative: LMS-only catalog flagged incomplete
  - Negative: enterprise-catalog-only catalog flagged incomplete
  - validate tool returns 0 on valid manifest
"""

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = REPO_ROOT / "config" / "runtime-proof" / "dev.synthetic-proof-fixtures.yaml"
BOOTSTRAP_TOOL = REPO_ROOT / "scripts" / "tenants" / "bootstrap-runtime-proof-fixtures.py"
VALIDATE_TOOL = REPO_ROOT / "scripts" / "tenants" / "validate-runtime-proof-fixtures.py"

REQUIRED_FIXTURE_CLASSES = [
    "synthetic_identities",
    "lms_enterprise_data",
    "enterprise_catalog_service_data",
    "waffle_flags",
]

# ── Fixtures ──────────────────────────────────────────────────────────────────


@pytest.fixture(scope="module")
def dev_manifest() -> dict[str, Any]:
    """Load and return the dev synthetic proof fixture manifest."""
    yaml = pytest.importorskip("yaml", reason="PyYAML required")
    assert MANIFEST_PATH.exists(), (
        f"Manifest not found: {MANIFEST_PATH}. "
        "Run from repo root or ensure the manifest has been created."
    )
    content = yaml.safe_load(MANIFEST_PATH.read_text(encoding="utf-8"))
    assert isinstance(content, dict), "Manifest must parse as a dict"
    return content


@pytest.fixture(scope="module")
def bootstrap_module():
    """Import the bootstrap tool module (without executing main)."""
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "bootstrap_runtime_proof_fixtures", BOOTSTRAP_TOOL
    )
    assert spec is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    return mod


@pytest.fixture(scope="module")
def validate_module():
    """Import the validate tool module (without executing main)."""
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "validate_runtime_proof_fixtures", VALIDATE_TOOL
    )
    assert spec is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    return mod


# ── Manifest parsing ──────────────────────────────────────────────────────────


class TestManifestParsing:
    def test_manifest_file_exists(self):
        assert MANIFEST_PATH.exists(), f"Manifest not found: {MANIFEST_PATH}"

    def test_manifest_is_valid_yaml(self):
        yaml_mod = pytest.importorskip("yaml")
        content = MANIFEST_PATH.read_text(encoding="utf-8")
        parsed = yaml_mod.safe_load(content)
        assert parsed is not None, "Manifest parsed as None — file may be empty"
        assert isinstance(parsed, dict), "Manifest must be a YAML mapping at the top level"

    def test_manifest_version_present(self, dev_manifest):
        assert "version" in dev_manifest, "Manifest must have a 'version' field"
        assert dev_manifest["version"], "version must be non-empty"

    def test_manifest_environment_present(self, dev_manifest):
        assert "environment" in dev_manifest, "Manifest must have an 'environment' field"
        assert dev_manifest["environment"] == "dev"

    def test_manifest_contract_ref_present(self, dev_manifest):
        assert "contract_ref" in dev_manifest, "Manifest must have a 'contract_ref' field"
        contract_ref = dev_manifest["contract_ref"]
        assert "SYNTHETIC_RUNTIME_PROOF_FIXTURE_CONTRACT" in contract_ref, (
            f"contract_ref {contract_ref!r} should point to the contract doc"
        )

    def test_real_account_mutation_forbidden_flag(self, dev_manifest):
        assert dev_manifest.get("real_account_mutation_forbidden") is True, (
            "real_account_mutation_forbidden must be present and true. "
            "This is a non-negotiable safety invariant."
        )

    def test_fixture_classes_is_mapping(self, dev_manifest):
        fc = dev_manifest.get("fixture_classes")
        assert isinstance(fc, dict), "fixture_classes must be a YAML mapping"


# ── Required fixture classes ──────────────────────────────────────────────────


class TestRequiredFixtureClasses:
    @pytest.mark.parametrize("class_name", REQUIRED_FIXTURE_CLASSES)
    def test_required_class_present(self, dev_manifest, class_name):
        fc = dev_manifest.get("fixture_classes", {})
        assert class_name in fc, (
            f"Required fixture class {class_name!r} is missing from fixture_classes. "
            f"All of {REQUIRED_FIXTURE_CLASSES} must be present."
        )

    def test_synthetic_identities_has_users(self, dev_manifest):
        si = dev_manifest["fixture_classes"]["synthetic_identities"]
        users = si.get("users", [])
        assert isinstance(users, list), "synthetic_identities.users must be a list"
        assert len(users) > 0, "synthetic_identities.users must be non-empty"

    def test_lms_enterprise_data_has_customers(self, dev_manifest):
        led = dev_manifest["fixture_classes"]["lms_enterprise_data"]
        customers = led.get("enterprise_customers", [])
        assert isinstance(customers, list), "lms_enterprise_data.enterprise_customers must be a list"
        assert len(customers) > 0, "lms_enterprise_data.enterprise_customers must be non-empty"

    def test_enterprise_catalog_service_data_has_catalogs(self, dev_manifest):
        ecsd = dev_manifest["fixture_classes"]["enterprise_catalog_service_data"]
        catalogs = ecsd.get("catalogs", [])
        assert isinstance(catalogs, list), (
            "enterprise_catalog_service_data.catalogs must be a list"
        )
        assert len(catalogs) > 0, (
            "enterprise_catalog_service_data.catalogs must be non-empty. "
            "LMS-only catalog is insufficient for learner portal proof."
        )

    def test_waffle_flags_has_at_least_one_definition(self, dev_manifest):
        wf = dev_manifest["fixture_classes"]["waffle_flags"]
        has_platform = bool(wf.get("platform_wide_flags"))
        has_tenant = bool(wf.get("tenant_scoped_switches"))
        assert has_platform or has_tenant, (
            "waffle_flags must have at least one of: platform_wide_flags, tenant_scoped_switches"
        )


# ── Dry-run output stability ───────────────────────────────────────────────────


class TestBootstrapDryRun:
    def test_bootstrap_tool_exists(self):
        assert BOOTSTRAP_TOOL.exists(), f"Bootstrap tool not found: {BOOTSTRAP_TOOL}"

    def test_bootstrap_tool_is_executable(self):
        assert BOOTSTRAP_TOOL.stat().st_mode & 0o111, (
            f"Bootstrap tool {BOOTSTRAP_TOOL} is not executable"
        )

    def test_dry_run_exits_zero(self):
        result = subprocess.run(
            [sys.executable, str(BOOTSTRAP_TOOL), "--env", "dev"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode == 0, (
            f"Bootstrap dry-run exited {result.returncode}.\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )

    def test_dry_run_json_is_parseable(self):
        result = subprocess.run(
            [sys.executable, str(BOOTSTRAP_TOOL), "--env", "dev", "--json"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode == 0, (
            f"Bootstrap dry-run --json exited {result.returncode}.\n{result.stderr}"
        )
        output = json.loads(result.stdout)
        assert isinstance(output, dict), "Dry-run JSON output must be a dict"

    def test_dry_run_json_has_expected_fields(self):
        result = subprocess.run(
            [sys.executable, str(BOOTSTRAP_TOOL), "--env", "dev", "--json"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        output = json.loads(result.stdout)
        assert output.get("mode") == "dry_run"
        assert output.get("environment") == "dev"
        assert output.get("real_account_mutation_forbidden") is True
        assert isinstance(output.get("actions"), list)
        assert len(output["actions"]) > 0, "Dry-run must produce at least one action"

    def test_dry_run_produces_expected_action_categories(self):
        result = subprocess.run(
            [sys.executable, str(BOOTSTRAP_TOOL), "--env", "dev", "--json"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        output = json.loads(result.stdout)
        categories = {a["category"] for a in output["actions"]}
        expected_categories = {
            "lms_user",
            "lms_enterprise_user_link",
            "lms_enterprise_customer",
            "lms_enterprise_catalog",
            "enterprise_catalog_service",
            "waffle_flag",
            "waffle_switch",
        }
        missing = expected_categories - categories
        assert not missing, (
            f"Dry-run output is missing expected action categories: {missing}. "
            f"Got categories: {categories}"
        )

    def test_apply_flag_exits_nonzero_with_warning(self):
        """--apply must print a warning and exit non-zero (mutation not yet wired)."""
        result = subprocess.run(
            [sys.executable, str(BOOTSTRAP_TOOL), "--env", "dev", "--apply"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode != 0, (
            "--apply should exit non-zero in this version (mutation not yet wired)"
        )
        assert "WARNING" in result.stderr or "warning" in result.stderr.lower(), (
            "--apply should print a warning to stderr"
        )


# ── Negative: real-account fixtures rejected ──────────────────────────────────


class TestNegativeRealAccountRejection:
    """
    Validate that the bootstrap and validate tools reject manifests
    containing real (non-@synthetic.test) account fixtures.
    """

    def _make_bad_manifest(self, tmp_path: Path, **overrides: Any) -> Path:
        """Write a minimal bad manifest to tmp_path and return its path."""
        yaml = pytest.importorskip("yaml")
        base: dict[str, Any] = {
            "version": "1.0",
            "environment": "dev",
            "contract_ref": "docs/stabilization/SYNTHETIC_RUNTIME_PROOF_FIXTURE_CONTRACT.md",
            "real_account_mutation_forbidden": True,
            "fixture_classes": {
                "synthetic_identities": {
                    "required": True,
                    "users": [
                        {
                            "username": "lanea-test",
                            "email": "lanea-test@synthetic.test",
                            "role": "enterprise_learner",
                        }
                    ],
                },
                "lms_enterprise_data": {
                    "required": True,
                    "enterprise_customers": [
                        {
                            "slug": "test-customer",
                            "name": "Test",
                            "contact_email": "test@synthetic.test",
                            "catalogs": [{"title": "t", "catalog_query": {}}],
                        }
                    ],
                },
                "enterprise_catalog_service_data": {
                    "required": True,
                    "catalogs": [
                        {"enterprise_customer_slug": "test-customer", "title": "t", "catalog_query": {}}
                    ],
                },
                "waffle_flags": {
                    "required": True,
                    "platform_wide_flags": [
                        {"name": "enterprise.learner_bff_enabled", "active": True}
                    ],
                    "tenant_scoped_switches": [],
                },
            },
        }
        # Apply overrides at the top level.
        for key, value in overrides.items():
            base[key] = value
        path = tmp_path / "test.synthetic-proof-fixtures.yaml"
        path.write_text(yaml.dump(base), encoding="utf-8")
        return path

    def test_real_user_email_is_rejected(self, tmp_path: Path):
        """A user with a non-@synthetic.test email must fail validation."""
        yaml = pytest.importorskip("yaml")
        import importlib.util

        spec = importlib.util.spec_from_file_location(
            "validate_tool", VALIDATE_TOOL
        )
        mod = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
        spec.loader.exec_module(mod)  # type: ignore[union-attr]

        bad_manifest: dict[str, Any] = {
            "version": "1.0",
            "environment": "dev",
            "contract_ref": "docs/stabilization/SYNTHETIC_RUNTIME_PROOF_FIXTURE_CONTRACT.md",
            "real_account_mutation_forbidden": True,
            "fixture_classes": {
                "synthetic_identities": {
                    "users": [
                        {
                            "username": "real-user",
                            "email": "real.user@mereka.io",  # REAL domain — must be rejected
                            "role": "enterprise_learner",
                        }
                    ]
                },
                "lms_enterprise_data": {
                    "enterprise_customers": [
                        {
                            "slug": "test",
                            "name": "Test",
                            "catalogs": [{"title": "t", "catalog_query": {}}],
                        }
                    ]
                },
                "enterprise_catalog_service_data": {
                    "catalogs": [{"enterprise_customer_slug": "test", "title": "t"}]
                },
                "waffle_flags": {
                    "platform_wide_flags": [
                        {"name": "enterprise.learner_bff_enabled", "active": True}
                    ]
                },
            },
        }

        results = mod.run_all_checks(bad_manifest)
        failed = [r for r in results if not r.passed]
        failed_names = [r.name for r in failed]

        # At least one check must fail flagging the real email.
        real_account_failures = [
            r
            for r in failed
            if "email" in r.name or "REAL" in r.message.upper() or "real" in r.message.lower()
        ]
        assert real_account_failures, (
            f"Expected a validation failure for real-domain email @mereka.io, "
            f"but all checks passed. Failed checks: {failed_names}"
        )

    def test_missing_real_account_mutation_flag_is_rejected(self, tmp_path: Path):
        """A manifest without real_account_mutation_forbidden: true must fail."""
        import importlib.util

        spec = importlib.util.spec_from_file_location("validate_tool", VALIDATE_TOOL)
        mod = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
        spec.loader.exec_module(mod)  # type: ignore[union-attr]

        bad_manifest: dict[str, Any] = {
            "version": "1.0",
            "environment": "dev",
            "contract_ref": "docs/stabilization/SYNTHETIC_RUNTIME_PROOF_FIXTURE_CONTRACT.md",
            # real_account_mutation_forbidden intentionally absent
            "fixture_classes": {},
        }

        results = mod.run_all_checks(bad_manifest)
        safety_check = next(
            (r for r in results if r.name == "safety_invariant"), None
        )
        assert safety_check is not None, "safety_invariant check must exist"
        assert not safety_check.passed, (
            "safety_invariant check must fail when real_account_mutation_forbidden is absent"
        )


# ── Negative: LMS-only catalog flagged ───────────────────────────────────────


class TestNegativeLMSOnlyCatalog:
    def test_lms_only_catalog_flagged_incomplete(self):
        """
        If lms_enterprise_data has catalogs but enterprise_catalog_service_data
        has no catalogs, the catalog split check must fail.
        """
        import importlib.util

        spec = importlib.util.spec_from_file_location("validate_tool", VALIDATE_TOOL)
        mod = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
        spec.loader.exec_module(mod)  # type: ignore[union-attr]

        lms_only_manifest: dict[str, Any] = {
            "version": "1.0",
            "environment": "dev",
            "contract_ref": "docs/stabilization/SYNTHETIC_RUNTIME_PROOF_FIXTURE_CONTRACT.md",
            "real_account_mutation_forbidden": True,
            "fixture_classes": {
                "synthetic_identities": {
                    "users": [
                        {"username": "lanea-test", "email": "lanea-test@synthetic.test", "role": "x"}
                    ]
                },
                "lms_enterprise_data": {
                    "enterprise_customers": [
                        {
                            "slug": "test",
                            "name": "Test",
                            "contact_email": "test@synthetic.test",
                            "catalogs": [{"title": "t", "catalog_query": {}}],
                        }
                    ]
                },
                "enterprise_catalog_service_data": {
                    # catalogs intentionally empty — LMS-only scenario
                    "catalogs": []
                },
                "waffle_flags": {
                    "platform_wide_flags": [
                        {"name": "enterprise.learner_bff_enabled", "active": True}
                    ],
                    "tenant_scoped_switches": [],
                },
            },
        }

        results = mod.run_all_checks(lms_only_manifest)
        split_check = next(
            (r for r in results if "catalog_split" in r.name), None
        )
        assert split_check is not None, "catalog_split check must exist"
        assert not split_check.passed, (
            "catalog_split check must fail when enterprise_catalog_service_data.catalogs is empty"
        )


# ── Negative: enterprise-catalog-only catalog flagged ────────────────────────


class TestNegativeEnterpriseOnlyCatalog:
    def test_enterprise_catalog_only_flagged_incomplete(self):
        """
        If enterprise_catalog_service_data has catalogs but no LMS catalog is defined,
        the catalog split check must also fail.
        """
        import importlib.util

        spec = importlib.util.spec_from_file_location("validate_tool", VALIDATE_TOOL)
        mod = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
        spec.loader.exec_module(mod)  # type: ignore[union-attr]

        catalog_only_manifest: dict[str, Any] = {
            "version": "1.0",
            "environment": "dev",
            "contract_ref": "docs/stabilization/SYNTHETIC_RUNTIME_PROOF_FIXTURE_CONTRACT.md",
            "real_account_mutation_forbidden": True,
            "fixture_classes": {
                "synthetic_identities": {
                    "users": [
                        {"username": "lanea-test", "email": "lanea-test@synthetic.test", "role": "x"}
                    ]
                },
                "lms_enterprise_data": {
                    "enterprise_customers": [
                        {
                            "slug": "test",
                            "name": "Test",
                            "contact_email": "test@synthetic.test",
                            # catalogs intentionally empty — enterprise-catalog-only scenario
                            "catalogs": [],
                        }
                    ]
                },
                "enterprise_catalog_service_data": {
                    "catalogs": [
                        {"enterprise_customer_slug": "test", "title": "t", "catalog_query": {}}
                    ]
                },
                "waffle_flags": {
                    "platform_wide_flags": [
                        {"name": "enterprise.learner_bff_enabled", "active": True}
                    ],
                    "tenant_scoped_switches": [],
                },
            },
        }

        results = mod.run_all_checks(catalog_only_manifest)
        split_check = next(
            (r for r in results if "catalog_split" in r.name), None
        )
        assert split_check is not None, "catalog_split check must exist"
        assert not split_check.passed, (
            "catalog_split check must fail when lms_enterprise_data catalogs is empty "
            "even if enterprise_catalog_service_data has catalogs"
        )


# ── Validate tool exit codes ──────────────────────────────────────────────────


class TestValidateToolExitCodes:
    def test_validate_tool_exists(self):
        assert VALIDATE_TOOL.exists(), f"Validate tool not found: {VALIDATE_TOOL}"

    def test_validate_tool_is_executable(self):
        assert VALIDATE_TOOL.stat().st_mode & 0o111, (
            f"Validate tool {VALIDATE_TOOL} is not executable"
        )

    def test_validate_exits_zero_on_valid_manifest(self):
        """The real dev manifest must pass validation with exit code 0."""
        result = subprocess.run(
            [sys.executable, str(VALIDATE_TOOL), "--env", "dev"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode == 0, (
            f"validate-runtime-proof-fixtures.py exited {result.returncode} on valid manifest.\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )

    def test_validate_json_output_is_parseable(self):
        result = subprocess.run(
            [sys.executable, str(VALIDATE_TOOL), "--env", "dev", "--json"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode == 0
        output = json.loads(result.stdout)
        assert output.get("valid") is True
        assert output.get("failed") == 0
        assert isinstance(output.get("checks"), list)
        assert len(output["checks"]) > 0

    def test_validate_json_includes_environment(self):
        result = subprocess.run(
            [sys.executable, str(VALIDATE_TOOL), "--env", "dev", "--json"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        output = json.loads(result.stdout)
        assert output.get("environment") == "dev"
