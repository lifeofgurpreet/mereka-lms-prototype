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
  - Apply guards (environment, safety flag, email)
  - Shared library (proof_fixtures) direct tests
  - Catalog companion tool existence and behavior
  - Idempotency model (ApplySummary)
  - Enterprise link as single authoritative source
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
CATALOG_TOOL = REPO_ROOT / "scripts" / "tenants" / "bootstrap-runtime-proof-fixtures-catalog.py"

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

    def test_password_secret_paths_use_canonical_k8s_path(self, dev_manifest):
        users = dev_manifest["fixture_classes"]["synthetic_identities"]["users"]
        for user in users:
            path = user.get("password_secret_path", "")
            assert path.startswith("/k8s/mereka-lms/"), (
                f"password_secret_path must use canonical /k8s/mereka-lms/ path, got {path!r}"
            )


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
            "lms_user_profile",
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

    def test_apply_flag_exits_nonzero_without_django(self):
        """--apply must exit non-zero when Django is not available (outside LMS pod)."""
        result = subprocess.run(
            [sys.executable, str(BOOTSTRAP_TOOL), "--env", "dev", "--apply"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode != 0, (
            "--apply should exit non-zero when Django is unavailable"
        )
        # Should print an informative error to stderr.
        combined = result.stderr + result.stdout
        assert "ERROR" in combined or "error" in combined.lower() or "Django" in combined, (
            "--apply should print an error or Django-related message to stderr"
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
        pytest.importorskip("yaml")
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

    def test_validate_json_includes_mode(self):
        """JSON output must include the mode field."""
        result = subprocess.run(
            [sys.executable, str(VALIDATE_TOOL), "--env", "dev", "--json"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        output = json.loads(result.stdout)
        assert output.get("mode") == "static"


# ── Apply guards ──────────────────────────────────────────────────────────────


class TestApplyGuards:
    """Test that apply refuses unsafe configurations."""

    def test_apply_refuses_production_env(self):
        """--apply --env production must exit non-zero."""
        result = subprocess.run(
            [sys.executable, str(BOOTSTRAP_TOOL), "--env", "production", "--apply"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode != 0, (
            "--apply with env=production should exit non-zero (guard rejects non-dev env)"
        )

    def test_apply_refuses_staging_env(self):
        """--apply --env staging must exit non-zero."""
        result = subprocess.run(
            [sys.executable, str(BOOTSTRAP_TOOL), "--env", "staging", "--apply"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        # Either the manifest won't exist (FileNotFoundError → exit 1) or
        # if it exists the guard will reject it — either way non-zero.
        assert result.returncode != 0, (
            "--apply with env=staging should exit non-zero"
        )

    def test_apply_refuses_non_synthetic_email(self):
        """Manifest with real email must be rejected before any ORM write."""
        import importlib.util

        spec = importlib.util.spec_from_file_location("validate_tool", VALIDATE_TOOL)
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
                            "email": "real.user@mereka.io",  # Real domain — must be rejected.
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
        real_account_failures = [
            r
            for r in failed
            if "email" in r.name or "REAL" in r.message.upper() or "real" in r.message.lower()
        ]
        assert real_account_failures, (
            "Expected a validation failure for real-domain email @mereka.io"
        )

    def test_apply_refuses_missing_safety_flag(self):
        """Manifest without real_account_mutation_forbidden must be rejected by guards."""
        import importlib.util

        sys.path.insert(0, str(REPO_ROOT / "scripts" / "tenants"))
        spec = importlib.util.spec_from_file_location(
            "proof_fixtures_lib",
            REPO_ROOT / "scripts" / "tenants" / "lib" / "proof_fixtures.py",
        )
        mod = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
        spec.loader.exec_module(mod)  # type: ignore[union-attr]

        bad_manifest: dict[str, Any] = {
            "version": "1.0",
            "environment": "dev",
            # real_account_mutation_forbidden intentionally absent.
            "fixture_classes": {},
        }
        with pytest.raises(mod.SyntheticSafetyViolation):
            mod.run_all_guards(bad_manifest, "dev")


# ── Shared library tests ───────────────────────────────────────────────────────


class TestSharedLibrary:
    """Test the shared safety library (scripts/tenants/lib/proof_fixtures.py) directly."""

    @pytest.fixture(scope="class")
    def lib(self):
        import importlib.util
        sys.path.insert(0, str(REPO_ROOT / "scripts" / "tenants"))
        spec = importlib.util.spec_from_file_location(
            "proof_fixtures_lib",
            REPO_ROOT / "scripts" / "tenants" / "lib" / "proof_fixtures.py",
        )
        mod = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
        spec.loader.exec_module(mod)  # type: ignore[union-attr]
        return mod

    def test_validate_synthetic_email_accepts_synthetic(self, lib):
        lib.validate_synthetic_email("test@synthetic.test")  # Should not raise.

    def test_validate_synthetic_email_rejects_real(self, lib):
        with pytest.raises(lib.SyntheticSafetyViolation):
            lib.validate_synthetic_email("real@mereka.io")

    def test_validate_synthetic_email_rejects_empty(self, lib):
        with pytest.raises(lib.SyntheticSafetyViolation):
            lib.validate_synthetic_email("")

    def test_validate_environment_accepts_dev(self, lib):
        lib.validate_environment("dev")  # Should not raise.

    def test_validate_environment_rejects_production(self, lib):
        with pytest.raises(lib.SyntheticSafetyViolation):
            lib.validate_environment("production")

    def test_validate_environment_rejects_staging(self, lib):
        with pytest.raises(lib.SyntheticSafetyViolation):
            lib.validate_environment("staging")

    def test_validate_safety_flag_accepts_true(self, lib):
        lib.validate_safety_flag({"real_account_mutation_forbidden": True})  # Should not raise.

    def test_validate_safety_flag_rejects_false(self, lib):
        with pytest.raises(lib.SyntheticSafetyViolation):
            lib.validate_safety_flag({"real_account_mutation_forbidden": False})

    def test_validate_safety_flag_rejects_missing(self, lib):
        with pytest.raises(lib.SyntheticSafetyViolation):
            lib.validate_safety_flag({})

    def test_action_record_serialization(self, lib):
        rec = lib.make_action("CREATE", "User", "test@synthetic.test", "created", dry_run=True)
        d = rec.to_dict()
        assert d["action"] == "CREATE"
        assert d["model"] == "User"
        assert d["identifier"] == "test@synthetic.test"
        assert d["detail"] == "created"
        assert d["dry_run"] is True
        assert "timestamp" in d

    def test_action_record_timestamp_is_iso_format(self, lib):
        rec = lib.make_action("NOOP", "User", "x@synthetic.test", "exists", dry_run=False)
        # Should be parseable as ISO 8601.
        from datetime import datetime
        datetime.fromisoformat(rec.timestamp)

    def test_run_all_guards_passes_valid(self, lib):
        valid_manifest: dict[str, Any] = {
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
                        }
                    ]
                },
                "enterprise_catalog_service_data": {"catalogs": []},
                "waffle_flags": {},
            },
        }
        lib.run_all_guards(valid_manifest, "dev")  # Should not raise.

    def test_run_all_guards_fails_on_real_email(self, lib):
        bad_manifest: dict[str, Any] = {
            "real_account_mutation_forbidden": True,
            "fixture_classes": {
                "synthetic_identities": {
                    "users": [
                        {"username": "bad-user", "email": "bad@mereka.io", "role": "x"}
                    ]
                },
                "lms_enterprise_data": {"enterprise_customers": []},
                "enterprise_catalog_service_data": {"catalogs": []},
                "waffle_flags": {},
            },
        }
        with pytest.raises(lib.SyntheticSafetyViolation):
            lib.run_all_guards(bad_manifest, "dev")

    def test_apply_summary_to_dict(self, lib):
        rec = lib.make_action("CREATE", "User", "a@synthetic.test", "created", True)
        summary = lib.ApplySummary(
            environment="dev",
            mode="dry_run",
            real_account_mutation_forbidden=True,
        )
        summary.actions.append(rec)
        summary.created = 1
        d = summary.to_dict()
        assert d["environment"] == "dev"
        assert d["mode"] == "dry_run"
        assert d["real_account_mutation_forbidden"] is True
        assert len(d["actions"]) == 1
        assert d["created"] == 1

    def test_shared_library_file_exists(self):
        lib_path = REPO_ROOT / "scripts" / "tenants" / "lib" / "proof_fixtures.py"
        assert lib_path.exists(), f"Shared library not found: {lib_path}"

    def test_shared_library_init_exists(self):
        init_path = REPO_ROOT / "scripts" / "tenants" / "lib" / "__init__.py"
        assert init_path.exists(), f"Shared library __init__.py not found: {init_path}"


# ── Catalog companion tests ────────────────────────────────────────────────────


class TestCatalogCompanion:
    """Test the enterprise-catalog companion tool."""

    def test_catalog_tool_exists(self):
        assert CATALOG_TOOL.exists(), f"Catalog tool not found: {CATALOG_TOOL}"

    def test_catalog_tool_is_executable(self):
        assert CATALOG_TOOL.stat().st_mode & 0o111, (
            f"Catalog tool {CATALOG_TOOL} is not executable"
        )

    def test_catalog_dry_run_exits_zero(self):
        """Dry-run of catalog tool must succeed without Django."""
        result = subprocess.run(
            [sys.executable, str(CATALOG_TOOL), "--env", "dev"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode == 0, (
            f"Catalog tool dry-run exited {result.returncode}.\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )

    def test_catalog_dry_run_json_exits_zero(self):
        """Dry-run JSON mode of catalog tool must succeed."""
        result = subprocess.run(
            [sys.executable, str(CATALOG_TOOL), "--env", "dev", "--json"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode == 0
        output = json.loads(result.stdout)
        assert output.get("mode") == "dry_run"
        assert output.get("scope") == "enterprise_catalog_service_data"
        assert isinstance(output.get("actions"), list)

    def test_catalog_dry_run_produces_catalog_actions(self):
        """Catalog tool dry-run must produce catalog-related actions."""
        result = subprocess.run(
            [sys.executable, str(CATALOG_TOOL), "--env", "dev", "--json"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        output = json.loads(result.stdout)
        categories = {a["category"] for a in output["actions"]}
        assert "enterprise_catalog" in categories or "catalog_query" in categories, (
            f"Expected catalog-related action categories, got: {categories}"
        )

    def test_catalog_apply_refuses_production(self):
        """--apply --env production must exit non-zero (guard rejects non-dev)."""
        result = subprocess.run(
            [sys.executable, str(CATALOG_TOOL), "--env", "production", "--apply"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode != 0, (
            "Catalog tool --apply with env=production should exit non-zero"
        )

    def test_catalog_apply_exits_nonzero_without_django(self):
        """--apply must exit non-zero when Django is not available."""
        result = subprocess.run(
            [sys.executable, str(CATALOG_TOOL), "--env", "dev", "--apply"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode != 0, (
            "Catalog tool --apply should exit non-zero without Django"
        )


# ── Idempotency model ─────────────────────────────────────────────────────────


class TestIdempotencyModel:
    """Test that the action model supports idempotent semantics."""

    @pytest.fixture(scope="class")
    def lib(self):
        import importlib.util
        sys.path.insert(0, str(REPO_ROOT / "scripts" / "tenants"))
        spec = importlib.util.spec_from_file_location(
            "proof_fixtures_lib",
            REPO_ROOT / "scripts" / "tenants" / "lib" / "proof_fixtures.py",
        )
        mod = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
        spec.loader.exec_module(mod)  # type: ignore[union-attr]
        return mod

    def test_apply_summary_counts(self, lib):
        summary = lib.ApplySummary(
            environment="dev",
            mode="dry_run",
            real_account_mutation_forbidden=True,
        )
        summary.actions.append(
            lib.make_action("CREATE", "User", "a@synthetic.test", "created", True)
        )
        summary.actions.append(
            lib.make_action("NOOP", "User", "b@synthetic.test", "exists", True)
        )
        summary.created = 1
        summary.reused = 1
        d = summary.to_dict()
        assert d["created"] == 1
        assert d["reused"] == 1
        assert len(d["actions"]) == 2

    def test_apply_summary_all_action_types(self, lib):
        """ApplySummary must support all action types: CREATE, NOOP, SKIP, REFUSE, ERROR."""
        summary = lib.ApplySummary(
            environment="dev",
            mode="apply",
            real_account_mutation_forbidden=True,
        )
        for action_type in ("CREATE", "NOOP", "SKIP", "REFUSE", "ERROR"):
            summary.actions.append(
                lib.make_action(action_type, "User", f"id_{action_type}", "detail", False)
            )
        d = summary.to_dict()
        action_types = {a["action"] for a in d["actions"]}
        assert action_types == {"CREATE", "NOOP", "SKIP", "REFUSE", "ERROR"}

    def test_apply_summary_serializes_to_json(self, lib):
        """ApplySummary.to_dict() output must be JSON-serializable."""
        summary = lib.ApplySummary(
            environment="dev",
            mode="apply",
            real_account_mutation_forbidden=True,
        )
        summary.actions.append(
            lib.make_action("CREATE", "User", "a@synthetic.test", "created", False)
        )
        summary.created = 1
        d = summary.to_dict()
        json_str = json.dumps(d)  # Should not raise.
        parsed = json.loads(json_str)
        assert parsed["environment"] == "dev"


# ── Enterprise link as single authoritative source ────────────────────────────


class TestEnterpriseLinksAuthoritative:
    """Confirm enterprise_link remains the single authoritative source for user-enterprise linkage."""

    def test_manifest_uses_enterprise_link_not_user_links_key(self, dev_manifest):
        """The manifest must NOT use 'user_links' as a data key."""
        fixture_classes = dev_manifest.get("fixture_classes", {})
        # user_links must not appear as a key at any level of the manifest.
        # The authoritative source is synthetic_identities[].enterprise_link.
        def has_user_links_key(obj: Any) -> bool:
            if isinstance(obj, dict):
                if "user_links" in obj:
                    return True
                return any(has_user_links_key(v) for v in obj.values())
            if isinstance(obj, list):
                return any(has_user_links_key(item) for item in obj)
            return False

        assert not has_user_links_key(fixture_classes), (
            "Manifest must not use 'user_links' as a data key. "
            "enterprise_link in synthetic_identities[].users is the single authoritative source."
        )

    def test_bootstrap_reads_enterprise_link_not_user_links(self):
        """The bootstrap tool plan uses enterprise_link from synthetic_identities, not user_links."""
        result = subprocess.run(
            [sys.executable, str(BOOTSTRAP_TOOL), "--env", "dev", "--json"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode == 0
        output = json.loads(result.stdout)
        # Every lms_enterprise_user_link action must come from the enterprise_link field
        # on the user — the detail must have username and customer_slug or just username
        # (for ASSERT_ABSENT). It must NOT have a 'user_links' key.
        link_actions = [
            a for a in output["actions"]
            if a["category"] == "lms_enterprise_user_link"
        ]
        assert len(link_actions) > 0, "Must have at least one lms_enterprise_user_link action"
        for action in link_actions:
            assert "user_links" not in action.get("detail", {}), (
                f"Action detail must not reference 'user_links': {action}"
            )
            assert "username" in action.get("detail", {}), (
                f"Action detail must include 'username' (derived from enterprise_link): {action}"
            )

    def test_enterprise_link_is_source_for_all_user_actions(self, dev_manifest):
        """Each user with enterprise_link must have a corresponding CREATE_OR_NOOP action."""
        result = subprocess.run(
            [sys.executable, str(BOOTSTRAP_TOOL), "--env", "dev", "--json"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode == 0
        output = json.loads(result.stdout)

        users = (
            dev_manifest.get("fixture_classes", {})
            .get("synthetic_identities", {})
            .get("users", [])
        )
        linked_users = [u["username"] for u in users if u.get("enterprise_link")]
        unlinked_users = [u["username"] for u in users if not u.get("enterprise_link")]

        link_actions = [
            a for a in output["actions"]
            if a["category"] == "lms_enterprise_user_link"
        ]
        create_or_noop_usernames = {
            a["detail"].get("username")
            for a in link_actions
            if a["kind"] == "CREATE_OR_NOOP"
        }
        assert_absent_usernames = {
            a["detail"].get("username")
            for a in link_actions
            if a["kind"] == "ASSERT_ABSENT"
        }

        for username in linked_users:
            assert username in create_or_noop_usernames, (
                f"User {username!r} has enterprise_link but no CREATE_OR_NOOP action found"
            )
        for username in unlinked_users:
            assert username in assert_absent_usernames, (
                f"User {username!r} has no enterprise_link but no ASSERT_ABSENT action found"
            )


# ── UUID drift detection ───────────────────────────────────────────────────────


class TestCatalogUUIDValidation:
    """Tests for UUID drift detection in catalog records."""

    def test_valid_catalog_uuid_passes(self, validate_module):
        """A manifest with valid UUID format passes the UUID format check."""
        manifest = {
            "fixture_classes": {
                "enterprise_catalog_service_data": {
                    "catalogs": [
                        {
                            "enterprise_customer_slug": "test",
                            "title": "Test Catalog",
                            "enterprise_catalog_uuid": "57e324c2-e0d1-4e65-91ea-818f636c91aa",
                            "catalog_query": {"content_filter": {"content_type": "course"}},
                        }
                    ]
                }
            }
        }
        results = validate_module.check_catalog_uuid_format(manifest)
        assert len(results) == 1
        assert results[0].passed

    def test_null_catalog_uuid_fails(self, validate_module):
        """A manifest with null UUID fails the UUID format check."""
        manifest = {
            "fixture_classes": {
                "enterprise_catalog_service_data": {
                    "catalogs": [
                        {
                            "enterprise_customer_slug": "test",
                            "title": "Test Catalog",
                            "catalog_query": {"content_filter": {"content_type": "course"}},
                        }
                    ]
                }
            }
        }
        results = validate_module.check_catalog_uuid_format(manifest)
        assert len(results) == 1
        assert not results[0].passed
        assert "null" in results[0].message.lower() or "drift" in results[0].message.lower()

    def test_invalid_catalog_uuid_fails(self, validate_module):
        """A manifest with invalid UUID format fails."""
        manifest = {
            "fixture_classes": {
                "enterprise_catalog_service_data": {
                    "catalogs": [
                        {
                            "enterprise_customer_slug": "test",
                            "title": "Test Catalog",
                            "enterprise_catalog_uuid": "not-a-uuid",
                            "catalog_query": {},
                        }
                    ]
                }
            }
        }
        results = validate_module.check_catalog_uuid_format(manifest)
        assert len(results) == 1
        assert not results[0].passed

    def test_dev_manifest_has_catalog_uuid(self, dev_manifest):
        """The dev manifest must have enterprise_catalog_uuid set (not null)."""
        ecsd = dev_manifest["fixture_classes"]["enterprise_catalog_service_data"]
        for cat in ecsd["catalogs"]:
            assert cat.get("enterprise_catalog_uuid"), (
                f"Catalog {cat.get('title')!r} missing enterprise_catalog_uuid — "
                "UUID drift detection requires this field"
            )
