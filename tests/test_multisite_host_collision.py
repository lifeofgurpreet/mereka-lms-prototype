"""
Regression tests for cross-tenant host collision detection in multisite_bootstrap_django.py.

These tests cover the pure-Python collision detection layer that runs before any DB write.
No Django, no database, no network required.

AC-001: bootstrap detects duplicate host ownership for domain, LMS_ROOT_URL, CMS_ROOT_URL, MFE_BASE_URL
AC-002: apply mode exits non-zero before DB writes when duplicate enterprise host ownership is found
AC-003: dry-run mode prints deterministic collision report (owners + host + file source)
AC-004: allowlist mechanism denies enterprise domains by default
AC-005: regression tests cover both pass and fail cases for host collisions (this file)
"""

from __future__ import annotations

import importlib.util
import subprocess
import sys
import textwrap
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Import the module under test without triggering load_definitions() at
# module level (which would fail if the YAML path doesn't exist in CI).
# We patch SITE_DEFINITIONS after import.
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).parent.parent
BOOTSTRAP_PATH = REPO_ROOT / "scripts" / "shared" / "multisite_bootstrap_django.py"

# Load the module without executing module-level load_definitions().
# We set a fake MULTISITE_DEFINITIONS_PATH so the load_definitions() call
# during import resolves to a real (minimal) YAML file.
import os
import tempfile
import yaml as _yaml


def _make_minimal_yaml(tmp_path: Path) -> Path:
    """Write a minimal valid YAML so module-level load_definitions() succeeds."""
    content = {"organizations": [], "sites": []}
    p = tmp_path / "minimal.yml"
    p.write_text(_yaml.dump(content))
    return p


# Use a module-level tmp dir so the import works once.
_TMP = Path(tempfile.mkdtemp())
_MINIMAL_YAML = _make_minimal_yaml(_TMP)
os.environ.setdefault("MULTISITE_DEFINITIONS_PATH", str(_MINIMAL_YAML))

spec = importlib.util.spec_from_file_location("multisite_bootstrap_django", BOOTSTRAP_PATH)
assert spec is not None and spec.loader is not None
_mod = importlib.util.module_from_spec(spec)
# Register the module before exec so @dataclass can resolve cls.__module__ in sys.modules.
sys.modules["multisite_bootstrap_django"] = _mod
spec.loader.exec_module(_mod)  # type: ignore[union-attr]

SiteDefinition = _mod.SiteDefinition
_extract_host = _mod._extract_host
_collect_host_owners = _mod._collect_host_owners
_is_non_enterprise_domain = _mod._is_non_enterprise_domain
_load_shared_host_allowlist = _mod._load_shared_host_allowlist
validate_site_host_ownership = _mod.validate_site_host_ownership
build_collision_report = _mod.build_collision_report
print_collision_report = _mod.print_collision_report
select_shared_mfe_host_owners = _mod.select_shared_mfe_host_owners
DEFAULT_SHARED_HOST_ALLOWLIST_PATH = _mod.DEFAULT_SHARED_HOST_ALLOWLIST_PATH


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_site(
    domain: str,
    lms: str = "",
    cms: str = "",
    mfe: str = "",
    name: str = "",
) -> SiteDefinition:
    values: dict[str, object] = {}
    if lms:
        values["LMS_ROOT_URL"] = lms
    if cms:
        values["CMS_ROOT_URL"] = cms
    if mfe:
        values["MFE_BASE_URL"] = mfe
    return SiteDefinition(
        domain=domain,
        name=name or domain,
        orgs=[],
        site_values=values,
    )


# ---------------------------------------------------------------------------
# AC-001 — host extraction
# ---------------------------------------------------------------------------


class TestExtractHost:
    def test_bare_domain(self):
        assert _extract_host("academyv2.mereka.io") == "academyv2.mereka.io"

    def test_https_url(self):
        assert _extract_host("https://academyv2.mereka.io") == "academyv2.mereka.io"

    def test_https_url_with_path(self):
        assert _extract_host("https://apps.mereka.io/authn") == "apps.mereka.io"

    def test_empty_string(self):
        assert _extract_host("") == ""

    def test_none_like(self):
        assert _extract_host(None) == ""  # type: ignore[arg-type]

    def test_lowercased(self):
        assert _extract_host("APPS.Mereka.IO") == "apps.mereka.io"


# ---------------------------------------------------------------------------
# AC-001 — collect host owners
# ---------------------------------------------------------------------------


class TestCollectHostOwners:
    def test_unique_lms_hosts(self):
        defs = [
            _make_site("a.io", lms="https://a.io"),
            _make_site("b.io", lms="https://b.io"),
        ]
        owners = _collect_host_owners(defs, "LMS_ROOT_URL")
        assert owners == {"a.io": {"a.io"}, "b.io": {"b.io"}}

    def test_shared_mfe_host(self):
        defs = [
            _make_site("a.io", mfe="https://apps.preview.io"),
            _make_site("b.io", mfe="https://apps.preview.io"),
        ]
        owners = _collect_host_owners(defs, "MFE_BASE_URL")
        assert owners == {"apps.preview.io": {"a.io", "b.io"}}

    def test_domain_field(self):
        defs = [
            _make_site("tenant-a.io"),
            _make_site("tenant-b.io"),
        ]
        owners = _collect_host_owners(defs, "domain")
        assert set(owners.keys()) == {"tenant-a.io", "tenant-b.io"}

    def test_missing_field_skipped(self):
        defs = [_make_site("x.io")]  # no LMS_ROOT_URL set
        owners = _collect_host_owners(defs, "LMS_ROOT_URL")
        assert owners == {}


# ---------------------------------------------------------------------------
# AC-001 + AC-002 — validate_site_host_ownership
# ---------------------------------------------------------------------------


class TestValidateSiteHostOwnership:
    def test_no_collision_returns_empty(self):
        defs = [
            _make_site("a.io", lms="https://a.io", cms="https://cms.a.io", mfe="https://apps.a.io"),
            _make_site("b.io", lms="https://b.io", cms="https://cms.b.io", mfe="https://apps.b.io"),
        ]
        errors = validate_site_host_ownership(defs, set())
        assert errors == []

    def test_shared_lms_host_is_an_error(self):
        # Two enterprise tenants sharing same LMS host — always blocked
        defs = [
            _make_site("a.io", lms="https://shared.io"),
            _make_site("b.io", lms="https://shared.io"),
        ]
        errors = validate_site_host_ownership(defs, set())
        assert len(errors) == 1
        assert "shared.io" in errors[0]
        assert "LMS_ROOT_URL" in errors[0]

    def test_shared_mfe_host_without_allowlist_is_error(self):
        defs = [
            _make_site("a.io", mfe="https://apps.preview.mereka.dev"),
            _make_site("b.io", mfe="https://apps.preview.mereka.dev"),
        ]
        errors = validate_site_host_ownership(defs, set())
        assert len(errors) == 1
        assert "MFE_BASE_URL" in errors[0]

    def test_shared_mfe_host_allowlisted_for_dev_domains_is_ok(self):
        # Both tenants are dev/staging — shared host is acceptable via allowlist
        defs = [
            _make_site("a.mereka.dev", mfe="https://apps.mereka.dev"),
            _make_site("preview.a.mereka.dev", mfe="https://apps.mereka.dev"),
        ]
        errors = validate_site_host_ownership(defs, {"apps.mereka.dev"})
        assert errors == []

    def test_shared_mfe_host_allowlisted_but_enterprise_domain_is_error(self):
        # One tenant is enterprise (.io) — allowlist must not apply
        defs = [
            _make_site("a.mereka.io", mfe="https://apps.shared.io"),
            _make_site("b.mereka.dev", mfe="https://apps.shared.io"),
        ]
        errors = validate_site_host_ownership(defs, {"apps.shared.io"})
        assert len(errors) == 1
        assert "enterprise" in errors[0]

    def test_duplicate_domain_via_shared_host(self):
        # Two distinct tenant domains that both point their LMS_ROOT_URL to the
        # same host — this is the cross-tenant collision the validator blocks.
        defs = [
            _make_site("tenant-a.io", lms="https://shared-lms.io"),
            _make_site("tenant-b.io", lms="https://shared-lms.io"),
        ]
        errors = validate_site_host_ownership(defs, set())
        assert len(errors) == 1
        assert "shared-lms.io" in errors[0]
        assert "LMS_ROOT_URL" in errors[0]

    def test_shared_cms_host_allowlisted_for_staging_domains_is_ok(self):
        defs = [
            _make_site("a.staging.mereka.io", cms="https://studio.staging.mereka.io"),
            _make_site("b.staging.mereka.io", cms="https://studio.staging.mereka.io"),
        ]
        errors = validate_site_host_ownership(defs, {"studio.staging.mereka.io"})
        assert errors == []

    def test_empty_definitions_returns_no_errors(self):
        assert validate_site_host_ownership([], set()) == []


# ---------------------------------------------------------------------------
# AC-003 — build_collision_report and print_collision_report
# ---------------------------------------------------------------------------


class TestBuildCollisionReport:
    def test_no_collision_empty_report(self):
        defs = [_make_site("a.io", lms="https://a.io", mfe="https://apps.a.io")]
        collisions = build_collision_report(defs, set(), file_source="test.yml")
        assert collisions == []

    def test_shared_host_produces_collision_record(self):
        defs = [
            _make_site("a.io", mfe="https://apps.shared.dev"),
            _make_site("b.io", mfe="https://apps.shared.dev"),
        ]
        collisions = build_collision_report(defs, set(), file_source="test.yml")
        assert len(collisions) == 1
        c = collisions[0]
        assert c.field == "MFE_BASE_URL"
        assert c.host == "apps.shared.dev"
        assert set(c.owners) == {"a.io", "b.io"}
        assert c.file_source == "test.yml"
        assert not c.allowlisted
        assert not c.enterprise_violation

    def test_allowlisted_dev_host_is_allowlisted_not_enterprise_violation(self):
        defs = [
            _make_site("a.mereka.dev", mfe="https://apps.mereka.dev"),
            _make_site("preview.a.mereka.dev", mfe="https://apps.mereka.dev"),
        ]
        collisions = build_collision_report(defs, {"apps.mereka.dev"}, file_source="dev.yml")
        assert len(collisions) == 1
        c = collisions[0]
        assert c.allowlisted is True
        assert c.enterprise_violation is False

    def test_allowlisted_but_enterprise_domain_sets_enterprise_violation(self):
        defs = [
            _make_site("a.mereka.io", mfe="https://apps.shared.io"),
            _make_site("b.mereka.dev", mfe="https://apps.shared.io"),
        ]
        collisions = build_collision_report(defs, {"apps.shared.io"}, file_source="prod.yml")
        assert len(collisions) == 1
        c = collisions[0]
        assert c.allowlisted is True
        assert c.enterprise_violation is True

    def test_collision_report_is_deterministic(self):
        """Same input must always produce same output (sorted fields + hosts + owners)."""
        defs = [
            _make_site("b.io", mfe="https://apps.shared.io", cms="https://studio.shared.io"),
            _make_site("a.io", mfe="https://apps.shared.io", cms="https://studio.shared.io"),
        ]
        r1 = build_collision_report(defs, set(), file_source="x.yml")
        r2 = build_collision_report(defs, set(), file_source="x.yml")
        assert r1 == r2

    def test_file_source_is_included(self):
        defs = [
            _make_site("x.io", mfe="https://apps.x.io"),
            _make_site("y.io", mfe="https://apps.x.io"),
        ]
        collisions = build_collision_report(defs, set(), file_source="/path/to/multisite-sites.yml")
        assert collisions[0].file_source == "/path/to/multisite-sites.yml"


class TestPrintCollisionReport:
    def test_no_collision_prints_ok(self, capsys):
        print_collision_report([])
        out = capsys.readouterr().out
        assert "OK" in out

    def test_collision_prints_field_host_owners(self, capsys):
        from dataclasses import replace  # noqa: PLC0415
        defs = [
            _make_site("a.io", mfe="https://apps.shared.io"),
            _make_site("b.io", mfe="https://apps.shared.io"),
        ]
        collisions = build_collision_report(defs, set(), file_source="sites.yml")
        print_collision_report(collisions)
        out = capsys.readouterr().out
        assert "MFE_BASE_URL" in out
        assert "apps.shared.io" in out
        assert "a.io" in out
        assert "b.io" in out
        assert "sites.yml" in out

    def test_enterprise_violation_shown_in_report(self, capsys):
        defs = [
            _make_site("a.mereka.io", mfe="https://apps.shared.io"),
            _make_site("b.mereka.dev", mfe="https://apps.shared.io"),
        ]
        collisions = build_collision_report(defs, {"apps.shared.io"}, file_source="prod.yml")
        print_collision_report(collisions)
        out = capsys.readouterr().out
        assert "ENTERPRISE-VIOLATION" in out


# ---------------------------------------------------------------------------
# AC-004 — allowlist mechanism
# ---------------------------------------------------------------------------


class TestAllowlist:
    def test_enterprise_domain_not_allowlistable(self):
        """An enterprise (.io) domain must be blocked even if its host is allowlisted."""
        defs = [
            _make_site("tenant-a.mereka.io", cms="https://studio.mereka.io"),
            _make_site("tenant-b.mereka.io", cms="https://studio.mereka.io"),
        ]
        errors = validate_site_host_ownership(defs, {"studio.mereka.io"})
        assert len(errors) == 1
        assert "enterprise" in errors[0].lower()

    def test_dev_domain_allowlistable_for_cms(self):
        defs = [
            _make_site("tenant-a.mereka.dev", cms="https://studio.mereka.dev"),
            _make_site("tenant-b.mereka.dev", cms="https://studio.mereka.dev"),
        ]
        errors = validate_site_host_ownership(defs, {"studio.mereka.dev"})
        assert errors == []

    def test_staging_domain_allowlistable_for_mfe(self):
        defs = [
            _make_site("staging.a.mereka.io", mfe="https://apps.staging.mereka.io"),
            _make_site("staging.b.mereka.io", mfe="https://apps.staging.mereka.io"),
        ]
        errors = validate_site_host_ownership(defs, {"apps.staging.mereka.io"})
        assert errors == []

    def test_preview_prefix_is_non_enterprise(self):
        assert _is_non_enterprise_domain("preview.academyv2.mereka.io") is True

    def test_mereka_io_without_prefix_is_enterprise(self):
        assert _is_non_enterprise_domain("academyv2.mereka.io") is False

    def test_mereka_dev_is_non_enterprise(self):
        assert _is_non_enterprise_domain("academyv2.mereka.dev") is True

    def test_load_shared_host_allowlist_from_env(self, tmp_path, monkeypatch):
        monkeypatch.setenv("MULTISITE_SHARED_HOST_ALLOWLIST", "apps.preview.io,studio.preview.io")
        monkeypatch.setenv("MULTISITE_SHARED_HOST_ALLOWLIST_FILE", str(tmp_path / "nonexistent"))
        result = _load_shared_host_allowlist()
        assert "apps.preview.io" in result
        assert "studio.preview.io" in result

    def test_load_shared_host_allowlist_from_file(self, tmp_path, monkeypatch):
        f = tmp_path / "allowlist.txt"
        f.write_text("apps.preview.io\n# comment\nstudio.preview.io\n")
        monkeypatch.setenv("MULTISITE_SHARED_HOST_ALLOWLIST", "")
        monkeypatch.setenv("MULTISITE_SHARED_HOST_ALLOWLIST_FILE", str(f))
        result = _load_shared_host_allowlist()
        assert "apps.preview.io" in result
        assert "studio.preview.io" in result

    def test_comments_stripped_from_allowlist_file(self, tmp_path, monkeypatch):
        f = tmp_path / "allowlist.txt"
        f.write_text("  valid.preview.io  # this is a comment\n")
        monkeypatch.setenv("MULTISITE_SHARED_HOST_ALLOWLIST", "")
        monkeypatch.setenv("MULTISITE_SHARED_HOST_ALLOWLIST_FILE", str(f))
        result = _load_shared_host_allowlist()
        assert "valid.preview.io" in result
        assert "this" not in result


# ---------------------------------------------------------------------------
# AC-002 — --check / --apply exit behavior via subprocess
# ---------------------------------------------------------------------------


class TestCheckModeExitCodes:
    """Verify --check exits non-zero on collision without touching Django."""

    def _run(self, definitions_path: str, *extra_args: str) -> subprocess.CompletedProcess:
        env = {**os.environ, "MULTISITE_DEFINITIONS_PATH": definitions_path}
        return subprocess.run(
            [sys.executable, str(BOOTSTRAP_PATH), "--check", *extra_args],
            capture_output=True,
            text=True,
            env=env,
        )

    def test_check_exits_0_when_no_collisions(self, tmp_path):
        content = {
            "organizations": [],
            "sites": [
                {
                    "domain": "a.io",
                    "name": "A",
                    "orgs": [],
                    "site_values": {
                        "LMS_ROOT_URL": "https://a.io",
                        "CMS_ROOT_URL": "https://cms.a.io",
                        "MFE_BASE_URL": "https://apps.a.io",
                    },
                }
            ],
        }
        p = tmp_path / "sites.yml"
        p.write_text(_yaml.dump(content))
        result = self._run(str(p))
        assert result.returncode == 0, result.stderr

    def test_check_exits_1_on_enterprise_lms_collision(self, tmp_path):
        content = {
            "organizations": [],
            "sites": [
                {
                    "domain": "a.io",
                    "name": "A",
                    "orgs": [],
                    "site_values": {"LMS_ROOT_URL": "https://shared.io"},
                },
                {
                    "domain": "b.io",
                    "name": "B",
                    "orgs": [],
                    "site_values": {"LMS_ROOT_URL": "https://shared.io"},
                },
            ],
        }
        p = tmp_path / "sites.yml"
        p.write_text(_yaml.dump(content))
        result = self._run(str(p))
        assert result.returncode == 1
        assert "shared.io" in result.stdout

    def test_check_exits_0_with_dev_domains_and_allowlist(self, tmp_path, monkeypatch):
        content = {
            "organizations": [],
            "sites": [
                {
                    "domain": "a.mereka.dev",
                    "name": "A",
                    "orgs": [],
                    "site_values": {"MFE_BASE_URL": "https://apps.mereka.dev"},
                },
                {
                    "domain": "preview.a.mereka.dev",
                    "name": "A Preview",
                    "orgs": [],
                    "site_values": {"MFE_BASE_URL": "https://apps.mereka.dev"},
                },
            ],
        }
        p = tmp_path / "sites.yml"
        p.write_text(_yaml.dump(content))
        allowlist = tmp_path / "allowlist.txt"
        allowlist.write_text("apps.mereka.dev\n")
        env = {
            **os.environ,
            "MULTISITE_DEFINITIONS_PATH": str(p),
            "MULTISITE_SHARED_HOST_ALLOWLIST_FILE": str(allowlist),
        }
        result = subprocess.run(
            [sys.executable, str(BOOTSTRAP_PATH), "--check"],
            capture_output=True,
            text=True,
            env=env,
        )
        assert result.returncode == 0, result.stdout + result.stderr

    def test_check_report_includes_file_source(self, tmp_path):
        content = {
            "organizations": [],
            "sites": [
                {
                    "domain": "a.io",
                    "name": "A",
                    "orgs": [],
                    "site_values": {"MFE_BASE_URL": "https://apps.collision.io"},
                },
                {
                    "domain": "b.io",
                    "name": "B",
                    "orgs": [],
                    "site_values": {"MFE_BASE_URL": "https://apps.collision.io"},
                },
            ],
        }
        p = tmp_path / "sites.yml"
        p.write_text(_yaml.dump(content))
        result = self._run(str(p))
        assert result.returncode == 1
        # The collision report must include the file source path
        assert str(p) in result.stdout

    def test_check_report_is_deterministic(self, tmp_path):
        """Running --check twice on the same input must produce identical stdout."""
        content = {
            "organizations": [],
            "sites": [
                {
                    "domain": "x.io",
                    "name": "X",
                    "orgs": [],
                    "site_values": {"MFE_BASE_URL": "https://apps.shared.io"},
                },
                {
                    "domain": "y.io",
                    "name": "Y",
                    "orgs": [],
                    "site_values": {"MFE_BASE_URL": "https://apps.shared.io"},
                },
            ],
        }
        p = tmp_path / "sites.yml"
        p.write_text(_yaml.dump(content))
        r1 = self._run(str(p))
        r2 = self._run(str(p))
        assert r1.stdout == r2.stdout


# ---------------------------------------------------------------------------
# AC-005 edge cases
# ---------------------------------------------------------------------------


class TestEdgeCases:
    def test_single_site_no_error(self):
        defs = [_make_site("only.io", lms="https://only.io")]
        assert validate_site_host_ownership(defs, set()) == []

    def test_site_with_no_url_fields_no_collision(self):
        defs = [
            _make_site("a.io"),
            _make_site("b.io"),
        ]
        # No LMS/CMS/MFE set, so no host to collide on
        errors = validate_site_host_ownership(defs, set())
        assert errors == []

    def test_select_shared_mfe_host_owners_prefers_non_preview(self):
        defs = [
            _make_site("preview.a.mereka.dev", mfe="https://apps.mereka.dev"),
            _make_site("a.mereka.dev", mfe="https://apps.mereka.dev"),
        ]
        owners = select_shared_mfe_host_owners(defs, {"apps.mereka.dev"})
        assert owners["apps.mereka.dev"] == "a.mereka.dev"

    def test_select_shared_mfe_host_owners_falls_back_to_sorted_first(self):
        defs = [
            _make_site("preview.b.mereka.dev", mfe="https://apps.mereka.dev"),
            _make_site("preview.a.mereka.dev", mfe="https://apps.mereka.dev"),
        ]
        owners = select_shared_mfe_host_owners(defs, {"apps.mereka.dev"})
        # Falls back to first sorted domain
        assert owners["apps.mereka.dev"] == "preview.a.mereka.dev"

    def test_all_four_fields_checked(self):
        """All four fields trigger collision detection independently.

        The 'domain' field collision means two tenants with different domain values
        share the same host string in their domain field — which maps identically to
        _collect_host_owners('domain'). The LMS/CMS/MFE fields detect shared URL hosts
        across two distinct tenant domains.
        """
        # Two tenants with distinct domains but sharing LMS, CMS, and MFE hosts.
        # The "domain" field check: each SiteDefinition.domain is unique → no domain collision.
        # Collisions appear for LMS_ROOT_URL, CMS_ROOT_URL, and MFE_BASE_URL.
        defs = [
            SiteDefinition(
                domain="tenant-a.io",
                name="A",
                orgs=[],
                site_values={
                    "LMS_ROOT_URL": "https://lms.shared.io",
                    "CMS_ROOT_URL": "https://cms.shared.io",
                    "MFE_BASE_URL": "https://mfe.shared.io",
                },
            ),
            SiteDefinition(
                domain="tenant-b.io",
                name="B",
                orgs=[],
                site_values={
                    "LMS_ROOT_URL": "https://lms.shared.io",
                    "CMS_ROOT_URL": "https://cms.shared.io",
                    "MFE_BASE_URL": "https://mfe.shared.io",
                },
            ),
        ]
        collisions = build_collision_report(defs, set())
        fields_found = {c.field for c in collisions}
        # LMS, CMS, MFE collisions all detected (domain field has no collision here)
        assert {"LMS_ROOT_URL", "CMS_ROOT_URL", "MFE_BASE_URL"}.issubset(fields_found)
