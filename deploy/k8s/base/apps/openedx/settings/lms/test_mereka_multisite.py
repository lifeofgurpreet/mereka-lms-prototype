"""
Unit tests for mereka_multisite.py

Tests the core domain resolution, cookie scoping, and login redirect logic
without requiring a running Django instance. Functions are tested in isolation
with mocked Django ORM calls where needed.
"""

import json
import os
import sys
import unittest
from unittest.mock import MagicMock, patch, PropertyMock
from dataclasses import dataclass

# The module under test lives at a non-standard path. Add it.
MODULE_DIR = os.path.dirname(os.path.abspath(__file__))
if MODULE_DIR not in sys.path:
    sys.path.insert(0, MODULE_DIR)

# Stub Django settings before importing the module
sys.modules.setdefault("django", MagicMock())
sys.modules.setdefault("django.conf", MagicMock())
sys.modules.setdefault("django.contrib", MagicMock())
sys.modules.setdefault("django.contrib.sites", MagicMock())
sys.modules.setdefault("django.contrib.sites.models", MagicMock())

import mereka_multisite as ms


class TestStripPort(unittest.TestCase):
    def test_no_port(self):
        self.assertEqual(ms._strip_port("example.com"), "example.com")

    def test_with_port(self):
        self.assertEqual(ms._strip_port("example.com:8000"), "example.com")

    def test_empty(self):
        self.assertEqual(ms._strip_port(""), "")


class TestCandidateSiteDomains(unittest.TestCase):
    """Test _candidate_site_domains — the core domain resolution function."""

    def test_lms_host_returns_self(self):
        result = ms._candidate_site_domains("academyv2.mereka.io")
        self.assertEqual(result, ["academyv2.mereka.io"])

    def test_apps_prefix_stripped(self):
        result = ms._candidate_site_domains("apps.staging.academy.biji-biji.com")
        self.assertEqual(result, [
            "apps.staging.academy.biji-biji.com",
            "staging.academy.biji-biji.com",
        ])

    def test_studio_prefix_stripped(self):
        result = ms._candidate_site_domains("studio.staging.academy.biji-biji.com")
        self.assertEqual(result, [
            "studio.staging.academy.biji-biji.com",
            "staging.academy.biji-biji.com",
        ])

    def test_admin_prefix_stripped(self):
        result = ms._candidate_site_domains("admin.academyv2.mereka.io")
        self.assertEqual(result, [
            "admin.academyv2.mereka.io",
            "academyv2.mereka.io",
        ])

    def test_staging_admin_prefix(self):
        result = ms._candidate_site_domains("staging.admin.academyv2.mereka.io")
        # "staging.admin." is not stripped — only single-level prefixes are handled
        # The host doesn't start with "admin." so no stripping occurs
        self.assertEqual(result, ["staging.admin.academyv2.mereka.io"])

    def test_preview_prefix_stripped(self):
        result = ms._candidate_site_domains("preview.academyv2.mereka.io")
        self.assertEqual(result, [
            "preview.academyv2.mereka.io",
            "academyv2.mereka.io",
        ])

    def test_port_stripped(self):
        result = ms._candidate_site_domains("apps.academyv2.mereka.io:443")
        self.assertEqual(result, [
            "apps.academyv2.mereka.io",
            "academyv2.mereka.io",
        ])

    def test_case_insensitive(self):
        result = ms._candidate_site_domains("APPS.AcademyV2.Mereka.IO")
        self.assertEqual(result, [
            "apps.academyv2.mereka.io",
            "academyv2.mereka.io",
        ])

    def test_staging_mereka_lms(self):
        result = ms._candidate_site_domains("staging.academyv2.mereka.io")
        self.assertEqual(result, ["staging.academyv2.mereka.io"])

    def test_staging_apps_mereka(self):
        result = ms._candidate_site_domains("staging.apps.academyv2.mereka.io")
        # "staging.apps." doesn't match any single prefix
        self.assertEqual(result, ["staging.apps.academyv2.mereka.io"])

    def test_biji_biji_lms(self):
        result = ms._candidate_site_domains("staging.academy.biji-biji.com")
        self.assertEqual(result, ["staging.academy.biji-biji.com"])

    def test_skillourfuture_lms(self):
        result = ms._candidate_site_domains("staging.skillourfuture.academy.mereka.io")
        self.assertEqual(result, ["staging.skillourfuture.academy.mereka.io"])

    def test_no_duplicates(self):
        """If host doesn't start with a known prefix, result has no dupe."""
        result = ms._candidate_site_domains("academyv2.mereka.io")
        self.assertEqual(len(result), len(set(result)))

    def test_empty_host(self):
        result = ms._candidate_site_domains("")
        self.assertEqual(result, [])


class TestCookiePolicyForHost(unittest.TestCase):
    """Test _cookie_policy_for_host — cookie domain scoping logic."""

    def test_lms_host_gets_scoped_domain(self):
        policy = ms._cookie_policy_for_host("staging.academyv2.mereka.io")
        self.assertEqual(policy.domain, ".staging.academyv2.mereka.io")

    def test_biji_biji_gets_own_domain(self):
        """biji-biji cookies must NOT leak to mereka domain."""
        policy = ms._cookie_policy_for_host("staging.academy.biji-biji.com")
        self.assertEqual(policy.domain, ".staging.academy.biji-biji.com")

    def test_skillourfuture_gets_own_domain(self):
        policy = ms._cookie_policy_for_host("staging.skillourfuture.academy.mereka.io")
        self.assertEqual(policy.domain, ".staging.skillourfuture.academy.mereka.io")

    def test_apps_prefix_maps_to_lms_domain(self):
        """MFE host should resolve to LMS tenant's cookie domain."""
        policy = ms._cookie_policy_for_host("apps.staging.academy.biji-biji.com")
        self.assertEqual(policy.domain, ".staging.academy.biji-biji.com")

    def test_studio_prefix_maps_to_lms_domain(self):
        policy = ms._cookie_policy_for_host("studio.staging.academy.biji-biji.com")
        self.assertEqual(policy.domain, ".staging.academy.biji-biji.com")

    def test_admin_prefix_maps_to_lms_domain(self):
        policy = ms._cookie_policy_for_host("admin.academyv2.mereka.io")
        self.assertEqual(policy.domain, ".academyv2.mereka.io")

    def test_localhost_returns_none(self):
        """localhost should use host-only cookies."""
        policy = ms._cookie_policy_for_host("localhost")
        self.assertIsNone(policy.domain)

    def test_apps_localhost_returns_none(self):
        policy = ms._cookie_policy_for_host("apps.localhost")
        self.assertIsNone(policy.domain)

    def test_empty_host_returns_none(self):
        policy = ms._cookie_policy_for_host("")
        self.assertIsNone(policy.domain)

    def test_no_cross_tenant_contamination(self):
        """Each tenant must get its own cookie domain, never another tenant's."""
        tenants = {
            "staging.academyv2.mereka.io": ".staging.academyv2.mereka.io",
            "staging.academy.biji-biji.com": ".staging.academy.biji-biji.com",
            "staging.skillourfuture.academy.mereka.io": ".staging.skillourfuture.academy.mereka.io",
        }
        for host, expected_domain in tenants.items():
            with self.subTest(host=host):
                policy = ms._cookie_policy_for_host(host)
                self.assertEqual(policy.domain, expected_domain)
                # Ensure no other tenant's domain appears
                for other_host, other_domain in tenants.items():
                    if other_host != host:
                        self.assertNotEqual(policy.domain, other_domain,
                            f"{host} got {other_domain} (belongs to {other_host})")

    def test_port_stripped_before_resolution(self):
        policy = ms._cookie_policy_for_host("staging.academyv2.mereka.io:443")
        self.assertEqual(policy.domain, ".staging.academyv2.mereka.io")


class TestCookieDomainMiddleware(unittest.TestCase):
    """Test MerekaCookieDomainMiddleware behavior."""

    def _make_request(self, host):
        req = MagicMock()
        req.get_host.return_value = host
        return req

    def _make_response_with_cookies(self, cookies_dict):
        """Create a mock response with a real cookies dict."""
        from http.cookies import SimpleCookie
        response = MagicMock()
        response.cookies = SimpleCookie()
        for name, value in cookies_dict.items():
            response.cookies[name] = value
        return response

    @patch.object(ms, 'patch_sites_framework')
    def test_middleware_sets_domain_on_csrftoken(self, mock_patch):
        """When cookie policy returns a domain, csrftoken should get it."""
        def get_response(request):
            return self._make_response_with_cookies({"csrftoken": "abc123"})

        mw = ms.MerekaCookieDomainMiddleware(get_response)
        req = self._make_request("staging.academyv2.mereka.io")
        resp = mw(req)
        self.assertEqual(resp.cookies["csrftoken"]["domain"],
                        ".staging.academyv2.mereka.io")

    @patch.object(ms, 'patch_sites_framework')
    def test_middleware_sets_domain_on_sessionid(self, mock_patch):
        def get_response(request):
            return self._make_response_with_cookies({"sessionid": "xyz789"})

        mw = ms.MerekaCookieDomainMiddleware(get_response)
        req = self._make_request("staging.academy.biji-biji.com")
        resp = mw(req)
        self.assertEqual(resp.cookies["sessionid"]["domain"],
                        ".staging.academy.biji-biji.com")

    @patch.object(ms, 'patch_sites_framework')
    def test_middleware_no_cross_contamination(self, mock_patch):
        """biji-biji cookies must NOT get mereka's domain."""
        def get_response(request):
            return self._make_response_with_cookies({
                "csrftoken": "token1",
                "sessionid": "session1",
            })

        mw = ms.MerekaCookieDomainMiddleware(get_response)
        req = self._make_request("staging.academy.biji-biji.com")
        resp = mw(req)
        self.assertEqual(resp.cookies["csrftoken"]["domain"],
                        ".staging.academy.biji-biji.com")
        self.assertNotIn("mereka", resp.cookies["csrftoken"]["domain"])

    @patch.object(ms, 'patch_sites_framework')
    def test_middleware_localhost_removes_domain(self, mock_patch):
        """localhost should use host-only cookies (no Domain attribute)."""
        def get_response(request):
            resp = self._make_response_with_cookies({"csrftoken": "abc"})
            resp.cookies["csrftoken"]["domain"] = ".some-domain.com"
            return resp

        mw = ms.MerekaCookieDomainMiddleware(get_response)
        req = self._make_request("localhost")
        resp = mw(req)
        # Domain key is deleted — SimpleCookie raises KeyError
        self.assertNotIn("domain", resp.cookies["csrftoken"])


class TestDomainFromEnvValue(unittest.TestCase):
    def test_plain_domain(self):
        self.assertEqual(ms._domain_from_env_value("academyv2.mereka.io"),
                        "academyv2.mereka.io")

    def test_full_url(self):
        self.assertEqual(ms._domain_from_env_value("https://academyv2.mereka.io"),
                        "academyv2.mereka.io")

    def test_url_with_path(self):
        self.assertEqual(ms._domain_from_env_value("https://academyv2.mereka.io/path"),
                        "academyv2.mereka.io")

    def test_empty(self):
        self.assertEqual(ms._domain_from_env_value(""), "")

    def test_none(self):
        self.assertEqual(ms._domain_from_env_value(None), "")


if __name__ == "__main__":
    unittest.main()
